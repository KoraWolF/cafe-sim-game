class_name Shift
extends RefCounted
## The café open for business, one game second at a time.
##
## Each second, in order: stoves cook (base speed 1 + chefs' cook; a finished
## batch waits on its stove for a server to carry it to a counter), customers
## arrive (Cashiers' appeal shortens the gap), queued customers take free seats
## (nobody orders: a server brings whatever dish stands on the counter nearest
## the seat, and that is what they pay for), servers carry servings to tables, customers wait / eat / leave,
## and on-duty Synths drain battery. Customers who finish eating line up at the
## registers; each Cashier takes the next one (pay_seconds, star_pay_seconds
## for a starred customer, at the Cashier's speed) and the coins come in then. The Vibe at a customer's seat (décor in
## range) slows their satisfaction loss and adds to their dish. When the shift time is up, customers
## still eating pay and everyone leaves; the phase becomes NIGHT. A shift shut
## by a lost Corporate Audit goes straight to NIGHT.


class Events:
	extends RefCounted
	var arrived: Array[String] = []
	## Customers who found the queue full.
	var turned_away: int = 0
	var left_angry: Array[String] = []
	## Customers who finished a meal (and paid), starred or not.
	var served: Array[String] = []
	var starred: Array[String] = []
	var star_expired: Array[String] = []
	## Customers who got angry in the pay line (they pay, but no tip).
	var angry_in_line: Array[String] = []
	## Pay and tips, in coins.
	var coins_earned: int = 0
	## Customer id -> what they paid, tip included (for pop-ups).
	var payments: Dictionary[String, int] = {}
	var tips_earned: int = 0
	## Recipe id per finished batch.
	var dishes_ready: Array[String] = []
	## Servings thrown into a bin.
	var thrown_away: int = 0
	var dishes_broken: int = 0
	var glitches: int = 0
	var shift_ended: bool = false
	## True when the café was shut for this shift (lost Corporate Audit).
	var closed: bool = false
	## Synth id -> level reached.
	var level_ups: Dictionary[String, int] = {}


## Passes up to seconds of shift time. Does nothing outside the SHIFT phase.
static func run(state: GameState, seconds: int, data: GameData) -> Events:
	var events := Events.new()
	if state.phase != GameState.Phase.SHIFT:
		return events
	if state.closed:
		# Shut for the day: straight to night, nobody works or drains.
		state.closed = false
		state.shift_time = data.balance.shift_seconds
		events.closed = true
		_close(state, data, events)
		return events
	Roles.bind_free(state, data)
	var rng := state.rng()
	for i: int in maxi(seconds, 0):
		_tick(state, data, rng, events)
		if state.shift_time >= data.balance.shift_seconds:
			_close(state, data, events)
			break
	state.store_rng(rng)
	return events


## Recipes customers can order: those with no unlock species, or one the player has.
static func unlocked_recipes(state: GameState, data: GameData) -> Array[Recipe]:
	var result: Array[Recipe] = []
	for recipe: Recipe in data.recipes.values():
		if recipe.unlock_species == "" or state.has_species(recipe.unlock_species):
			result.append(recipe)
	return result


## Total appeal of working Cashiers; the arrival gap is divided by 1 + this.
static func cashier_appeal(state: GameState, data: GameData) -> float:
	var total := 0.0
	for synth: Synth in active_cashiers(state, data):
		total += maxf(SynthStats.stat(synth, "appeal", data), 0.0) * SynthStats.work_factor(synth, state, data)
	return total


## How many times faster than the base gap customers arrive: the café's size
## (its average side over arrival_reference_size: a small café gets fewer) times
## 1 + the Cashiers' appeal.
static func arrival_rate(state: GameState, data: GameData) -> float:
	var side := (state.floor_width + state.floor_rows) * 0.5
	return side / maxf(data.balance.arrival_reference_size, 1.0) * (1.0 + cashier_appeal(state, data))


static func seated_count(state: GameState) -> int:
	return state.customers.filter(func(customer: Customer) -> bool: return customer.is_seated()).size()


static func queued_count(state: GameState) -> int:
	return state.customers.filter(func(customer: Customer) -> bool:
		return customer.stage == Customer.Stage.QUEUED).size()


static func _tick(state: GameState, data: GameData, rng: RandomNumberGenerator, events: Events) -> void:
	_cook(state, data, rng, events)
	_arrive(state, data, rng, events)
	_seat(state, data)
	_serve(state, data, rng, events)
	_update_customers(state, data, events)
	_cashiers(state, data, events)
	_drain(state, data)
	state.shift_time += 1


static func _cook(state: GameState, data: GameData, rng: RandomNumberGenerator, events: Events) -> void:
	if state.stoves.all(func(stove: Stove) -> bool: return stove.is_idle() or stove.has_batch()):
		return
	var counters := Counters.in_use(state, data)
	for stove: Stove in state.stoves:
		if stove.is_idle() or stove.has_batch():
			continue
		# Base speed 1, plus the cooking of the Chef at this stove (if working and not glitching).
		var rate := 1.0
		var cooking: Array[Synth] = []
		var chef := Roles.at_station(state, stove.piece_uid)
		if chef != null and chef.role == Synth.CHEF and SynthStats.work_factor(chef, state, data) > 0.0:
			if rng.randf() < SynthStats.stat(chef, "glitch_chance", data):
				events.glitches += 1
			else:
				rate += maxf(SynthStats.stat(chef, "cook", data), 0.0) * SynthStats.work_factor(chef, state, data)
				cooking.append(chef)
		stove.remaining -= rate
		if stove.remaining <= 0.0:
			var recipe := data.recipes[stove.recipe_id]
			events.dishes_ready.append(recipe.id)
			Leveling.share(cooking, data.balance.xp_per_batch, data.balance, events.level_ups)
			stove.remaining = 0.0
			if counters:
				# Waits on the stove until a server carries it to a counter.
				stove.ready = recipe.servings
			else:
				state.counter[recipe.id] = state.counter.get(recipe.id, 0) + recipe.servings
				stove.recipe_id = ""


static func _arrive(state: GameState, data: GameData, rng: RandomNumberGenerator, events: Events) -> void:
	var b := data.balance
	if state.shift_time < state.next_arrival or state.shift_time >= b.shift_seconds - b.spawn_stop_before_end:
		return
	var gap := rng.randi_range(b.arrival_min_seconds, b.arrival_max_seconds) / arrival_rate(state, data)
	state.next_arrival = state.shift_time + maxi(roundi(gap), 1)
	var type_id := _pick_type(data, rng)
	if queued_count(state) >= b.max_queue:
		events.turned_away += 1
		return
	var customer := Customer.new()
	customer.id = state.new_id("customer")
	customer.type_id = type_id
	var pool := data.customer_types[type_id].trait_pool
	if not pool.is_empty():
		customer.trait_id = pool[rng.randi_range(0, pool.size() - 1)]
	customer.battery_max = data.species[data.customer_types[type_id].synth_species].roll_battery_max(rng)
	state.customers.append(customer)
	events.arrived.append(customer.id)
	Leveling.share(active_cashiers(state, data), b.xp_per_arrival, b, events.level_ups)


static func _pick_type(data: GameData, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for type: CustomerType in data.customer_types.values():
		total += maxf(type.weight, 0.0)
	var roll := rng.randf() * total
	var last := ""
	for type: CustomerType in data.customer_types.values():
		if type.weight <= 0.0:
			continue
		last = type.id
		roll -= type.weight
		if roll < 0.0:
			return type.id
	return last


## The first working seat (one with its table) nobody sits at ("" if none).
static func _free_seat(state: GameState, data: GameData) -> String:
	var taken: Dictionary[String, bool] = {}
	for customer: Customer in state.customers:
		if customer.is_seated() and customer.seat_uid != "":
			taken[customer.seat_uid] = true
	for placed: PlacedPiece in state.placed:
		if state.seat_table.has(placed.uid) and not taken.has(placed.uid):
			return placed.uid
	return ""


static func _seat(state: GameState, data: GameData) -> void:
	# Seated customers from older saves get a seat first.
	for customer: Customer in state.customers:
		if customer.is_seated() and Layout.placed_by_uid(state, customer.seat_uid) == null:
			customer.seat_uid = _free_seat(state, data)
	# Customers sitting at a seat that lost its table (moved mid-meal) still count.
	var free := state.seats - state.customers.filter(func(customer: Customer) -> bool:
		return customer.is_seated() and state.seat_table.has(customer.seat_uid)).size()
	if free <= 0:
		return
	for customer: Customer in state.customers:
		if free <= 0:
			return
		if customer.stage != Customer.Stage.QUEUED:
			continue
		customer.stage = Customer.Stage.WAITING_FOOD
		customer.seat_uid = _free_seat(state, data)
		customer.waited = 0
		customer.recipe_id = ""
		free -= 1


static func _serve(state: GameState, data: GameData, rng: RandomNumberGenerator, events: Events) -> void:
	for synth: Synth in state.synths:
		if synth.role != Synth.SERVER:
			continue
		var factor := SynthStats.work_factor(synth, state, data)
		if factor <= 0.0:
			continue
		if not synth.is_busy():
			# The player's throw-away orders come first, then serving waiting customers,
			# then carrying finished batches.
			if not _take_discard(state, synth, data, events) and not _take_order(state, synth, data):
				_take_batch(state, synth, data)
			continue
		synth.task_remaining -= SynthStats.speed(synth, data) * factor
		if synth.task_remaining <= 0.0:
			if synth.is_delivering():
				_deliver(state, synth, data, rng, events)
			elif synth.is_discarding():
				synth.spot_uid = synth.task_bin_uid
				_clear_task(synth)
			else:
				_finish_carry(state, synth, data, events)


## Picks up a serving for the longest-seated customer: whatever dish stands
## on the counter nearest their seat.
static func _take_order(state: GameState, synth: Synth, data: GameData) -> bool:
	for customer: Customer in state.customers:
		if customer.stage != Customer.Stage.WAITING_FOOD or customer.served_by != "":
			continue
		var taken := Counters.take_nearest(state, customer.seat_uid, data)
		if taken.is_empty():
			return false  # nothing ready anywhere
		synth.task_counter_uid = taken[0]
		customer.served_by = synth.id
		synth.task_customer_id = customer.id
		synth.task_recipe_id = taken[1]
		_start_trip(state, synth, taken[0], customer.seat_uid, data.balance.delivery_seconds, data)
		return true
	return false


## Picks up all the food on the first counter or stove marked to throw away
## and heads for the nearest bin. Marks with nothing left to take are dropped.
static func _take_discard(state: GameState, synth: Synth, data: GameData, events: Events) -> bool:
	for uid: String in state.discard.duplicate():
		var placed := Layout.placed_by_uid(state, uid)
		var stove := Layout.stove_of(state, uid)
		var count: int = stove.ready if stove != null else state.counter_count.get(uid, 0)
		if placed == null or count <= 0:
			state.discard.erase(uid)
			continue
		if stove != null and stove.carrier != "":
			continue
		var bin := _nearest(state, Piece.BIN, placed, data)
		if bin == "":
			return false
		if stove != null:
			synth.task_recipe_id = stove.recipe_id
			stove.ready = 0
			stove.recipe_id = ""
		else:
			synth.task_recipe_id = state.counter_dish.get(uid, "")
			state.counter[synth.task_recipe_id] = maxi(state.counter.get(synth.task_recipe_id, 0) - count, 0)
			state.counter_dish.erase(uid)
			state.counter_count.erase(uid)
		state.discard.erase(uid)
		synth.task_counter_uid = uid
		synth.task_bin_uid = bin
		_start_trip(state, synth, uid, bin, data.balance.carry_seconds, data)
		events.thrown_away += count
		return true
	return false


## A trip's length: walking from where the Server stands to the pick-up and
## on to the drop-off (walk_tiles_per_second), plus handling seconds. It ends
## standing at the drop-off.
static func _start_trip(state: GameState, synth: Synth, from_uid: String, to_uid: String, handling: float,
		data: GameData) -> void:
	var tiles := _tiles(state, synth.spot_uid, from_uid, data) + _tiles(state, from_uid, to_uid, data)
	synth.task_total = snappedf(handling + tiles / maxf(data.balance.walk_tiles_per_second, 0.1), 0.1)
	synth.task_remaining = synth.task_total


## Tiles walked between two placed pieces (2 if either is unknown).
static func _tiles(state: GameState, from_uid: String, to_uid: String, data: GameData) -> float:
	var a := Layout.placed_by_uid(state, from_uid)
	var b := Layout.placed_by_uid(state, to_uid)
	return 2.0 if a == null or b == null else Layout.distance(a, b, data) + 1.0


## The uid of the placed piece of a kind closest to from ("" if none).
static func _nearest(state: GameState, kind: String, from: PlacedPiece, data: GameData) -> String:
	var best := ""
	var best_distance := 1 << 30
	for placed: PlacedPiece in state.placed:
		if data.pieces[placed.piece_id].kind == kind and Layout.distance(from, placed, data) < best_distance:
			best = placed.uid
			best_distance = Layout.distance(from, placed, data)
	return best


## Picks up a finished batch from a stove, bound for the nearest free counter.
static func _take_batch(state: GameState, synth: Synth, data: GameData) -> bool:
	for stove: Stove in state.stoves:
		if not stove.has_batch() or stove.carrier != "":
			continue
		var counter_uid := Counters.free_counter(state, stove.recipe_id, stove.piece_uid, data)
		if counter_uid == "":
			continue
		stove.carrier = synth.id
		synth.task_stove_uid = stove.piece_uid
		synth.task_counter_uid = counter_uid
		synth.task_recipe_id = stove.recipe_id
		_start_trip(state, synth, stove.piece_uid, counter_uid, data.balance.carry_seconds, data)
		return true
	return false


## Puts the carried batch on its counter (or another free one; if none, it
## stays on the stove) and frees the stove.
static func _finish_carry(state: GameState, synth: Synth, data: GameData, events: Events) -> void:
	var stove := Layout.stove_of(state, synth.task_stove_uid)
	var counter_uid := synth.task_counter_uid
	var recipe_id := synth.task_recipe_id
	synth.spot_uid = counter_uid
	_clear_task(synth)
	if stove == null or not stove.has_batch():
		return
	stove.carrier = ""
	var dish := Counters.dish_on(state, counter_uid)
	if Layout.placed_by_uid(state, counter_uid) == null or (dish != "" and dish != recipe_id):
		counter_uid = Counters.free_counter(state, recipe_id, stove.piece_uid, data)
		if counter_uid == "":
			return
	Counters.put(state, counter_uid, recipe_id, stove.ready)
	stove.ready = 0
	stove.recipe_id = ""
	Leveling.add_xp(synth, data.balance.xp_per_delivery, data.balance, events.level_ups)


static func _deliver(state: GameState, synth: Synth, data: GameData, rng: RandomNumberGenerator,
		events: Events) -> void:
	var customer := state.customer_by_id(synth.task_customer_id)
	var recipe_id := synth.task_recipe_id
	if customer != null:
		synth.spot_uid = customer.seat_uid
	_clear_task(synth)
	if customer == null:
		return
	customer.served_by = ""
	if rng.randf() < SynthStats.stat(synth, "break_chance", data):
		events.dishes_broken += 1
		customer.satisfaction = maxf(customer.satisfaction - data.balance.break_satisfaction_penalty, 0.0)
		return
	customer.stage = Customer.Stage.EATING
	customer.recipe_id = recipe_id
	customer.timer = data.balance.eat_seconds
	var bonus := SynthStats.stat(synth, "satisfaction", data) \
		+ minf(state.seat_vibe.get(customer.seat_uid, 0.0) * data.balance.vibe_meal_bonus, data.balance.vibe_meal_bonus_max)
	customer.satisfaction = clampf(customer.satisfaction + bonus, 0.0, 100.0)
	customer.tip_bonus = SynthStats.stat(synth, "tip", data)
	Leveling.add_xp(synth, data.balance.xp_per_delivery, data.balance, events.level_ups)


static func _update_customers(state: GameState, data: GameData, events: Events) -> void:
	var b := data.balance
	for customer: Customer in state.customers.duplicate():
		var type := data.customer_types[customer.type_id]
		match customer.stage:
			Customer.Stage.QUEUED:
				_wait(customer, type, b, 0.0)  # outside, no décor
				if customer.waited >= roundi(b.queue_patience_seconds * type.patience):
					_leave_angry(state, customer, data, events)
			Customer.Stage.WAITING_FOOD:
				_wait(customer, type, b, state.seat_vibe.get(customer.seat_uid, 0.0))
				if customer.satisfaction <= 0.0:
					_leave_angry(state, customer, data, events)
			Customer.Stage.EATING:
				customer.timer -= 1
				if customer.timer <= 0:
					_finish_meal(state, customer, data, events)
			Customer.Stage.PAYING:
				if customer.timer > 0:
					customer.timer -= 1  # still walking to the register
				elif customer.cashier_id == "":
					# Waiting in line: an angry customer still pays, but no tip.
					_wait(customer, type, b, 0.0)
					if customer.satisfaction <= 0.0 and customer.tip > 0:
						customer.tip = 0
						events.angry_in_line.append(customer.id)


static func _wait(customer: Customer, type: CustomerType, b: BalanceConfig, vibe: float) -> void:
	customer.waited += 1
	if customer.waited > b.wait_grace_seconds:
		var loss := b.satisfaction_decay_per_second / maxf(type.patience, 0.1) / (1.0 + maxf(vibe, 0.0) * b.vibe_decay_per_point)
		customer.satisfaction = maxf(customer.satisfaction - loss, 0.0)


## The bill (and a tip, with a star, if satisfied enough). With registers the
## customer lines up to pay; without (test cafés) they pay at once. A starred
## customer can be converted until they leave, unless can_star is false (closing).
static func _finish_meal(state: GameState, customer: Customer, data: GameData, events: Events,
		can_star := true) -> void:
	var b := data.balance
	var recipe := data.recipes[customer.recipe_id]
	customer.bill = roundi(recipe.price * (b.min_pay_share + (1.0 - b.min_pay_share) * customer.satisfaction / 100.0))
	customer.tip = 0
	customer.starred = customer.satisfaction >= b.star_threshold
	if customer.starred:
		var type := data.customer_types[customer.type_id]
		customer.tip = roundi(recipe.price * b.tip_rate * type.tip * (1.0 + customer.tip_bonus))
		if can_star:
			events.starred.append(customer.id)
		else:
			customer.starred = false
	if Layout.count_placed(state, Piece.REGISTER, data) > 0:
		customer.stage = Customer.Stage.PAYING
		customer.cashier_id = ""
		customer.waited = 0
		# Walking from the seat to the registers first (timer: seconds left to get there).
		var register := _nearest(state, Piece.REGISTER, Layout.placed_by_uid(state, customer.seat_uid), data) \
			if Layout.placed_by_uid(state, customer.seat_uid) != null else ""
		customer.timer = roundi(_tiles(state, customer.seat_uid, register, data) / maxf(b.walk_tiles_per_second, 0.1))
		return
	_pay(state, customer, data, events)


## Takes the bill and tip; everyone leaves. A starred customer goes to the
## starred list (convertible until the café closes).
static func _pay(state: GameState, customer: Customer, data: GameData, events: Events) -> void:
	state.coins += customer.bill + customer.tip
	events.coins_earned += customer.bill
	events.tips_earned += customer.tip
	events.served.append(customer.id)
	events.payments[customer.id] = customer.bill + customer.tip
	customer.cashier_id = ""
	state.customers.erase(customer)
	if customer.starred:
		# Gone from the café, but can be converted from the starred list until closing.
		customer.stage = Customer.Stage.STAR
		state.star_list.append(customer)


## Each register's Cashier (working Cashiers paired with registers in floor
## order) takes the next customer in line and finishes their payment.
static func _cashiers(state: GameState, data: GameData, events: Events) -> void:
	var working: Dictionary[String, Synth] = {}
	for synth: Synth in active_cashiers(state, data):
		working[synth.id] = synth
	for customer: Customer in state.customers:
		if customer.stage == Customer.Stage.PAYING and customer.cashier_id != "" and not working.has(customer.cashier_id):
			customer.cashier_id = ""  # their Cashier stopped: back in line
	for synth: Synth in working.values():
		var current: Customer = null
		for customer: Customer in state.customers:
			if customer.stage == Customer.Stage.PAYING and customer.cashier_id == synth.id:
				current = customer
				break
		if current == null:
			for customer: Customer in state.customers:
				if customer.stage == Customer.Stage.PAYING and customer.cashier_id == "" and customer.timer <= 0:
					current = customer
					current.cashier_id = synth.id
					current.pay_left = data.balance.star_pay_seconds if current.starred else data.balance.pay_seconds
					break
		if current == null:
			continue
		current.pay_left -= SynthStats.speed(synth, data) * SynthStats.work_factor(synth, state, data)
		if current.pay_left <= 0.0:
			_pay(state, current, data, events)
			Leveling.add_xp(synth, data.balance.xp_per_delivery, data.balance, events.level_ups)


## Cashiers working now: each at its own register (see Roles).
static func active_cashiers(state: GameState, data: GameData) -> Array[Synth]:
	var result: Array[Synth] = []
	for synth: Synth in state.synths:
		var register := Layout.placed_by_uid(state, synth.station_uid)
		if synth.role == Synth.CASHIER and register != null and data.pieces[register.piece_id].kind == Piece.REGISTER \
				and SynthStats.work_factor(synth, state, data) > 0.0:
			result.append(synth)
	return result


## Leaves without paying; a dish already on its way goes back to the counter.
static func _leave_angry(state: GameState, customer: Customer, data: GameData, events: Events) -> void:
	if customer.served_by != "":
		var synth := state.synth_by_id(customer.served_by)
		if synth != null:
			_return_dish(state, synth, data)
	state.customers.erase(customer)
	events.left_angry.append(customer.id)


static func _drain(state: GameState, data: GameData) -> void:
	for synth: Synth in state.synths:
		if SynthStats.on_duty(synth):
			synth.battery = maxf(synth.battery - maxf(SynthStats.stat(synth, "drain", data), 0.0), 0.0)


## Customers eating or in the pay line pay (if a Cashier is working) and leave,
## the rest just leave; dishes in hand go back.
static func _close(state: GameState, data: GameData, events: Events) -> void:
	var can_pay := Layout.count_placed(state, Piece.REGISTER, data) == 0 or not active_cashiers(state, data).is_empty()
	for customer: Customer in state.customers.duplicate():
		if customer.stage == Customer.Stage.EATING:
			_finish_meal(state, customer, data, events, false)
		if customer.stage == Customer.Stage.PAYING and can_pay:
			customer.starred = false
			_pay(state, customer, data, events)
	for synth: Synth in state.synths:
		if synth.is_delivering():
			_return_dish(state, synth, data)
		elif synth.is_discarding():
			# The food is already out of the counter: it is thrown away.
			_clear_task(synth)
		elif synth.is_carrying():
			# The batch stays on its stove for tomorrow.
			var stove := Layout.stove_of(state, synth.task_stove_uid)
			if stove != null:
				stove.carrier = ""
			_clear_task(synth)
	state.customers.clear()
	for customer: Customer in state.star_list:
		events.star_expired.append(customer.id)
	state.star_list.clear()
	state.phase = GameState.Phase.NIGHT
	events.shift_ended = true


static func _return_dish(state: GameState, synth: Synth, data: GameData) -> void:
	Counters.give_back(state, synth.task_counter_uid, synth.task_recipe_id, data)
	_clear_task(synth)


static func _clear_task(synth: Synth) -> void:
	synth.task_customer_id = ""
	synth.task_recipe_id = ""
	synth.task_remaining = 0.0
	synth.task_total = 0.0
	synth.task_stove_uid = ""
	synth.task_counter_uid = ""
	synth.task_bin_uid = ""
