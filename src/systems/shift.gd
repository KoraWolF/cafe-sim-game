class_name Shift
extends RefCounted
## The café open for business, one game second at a time.
##
## Each second, in order: stoves cook (base speed 1 + chefs' cook), customers
## arrive (greeters shorten the gap), queued customers take free seats and
## order from the menu (favourites more often), servers carry ready servings to tables, customers wait / eat / leave,
## and on-duty Synths drain battery. Vibe (décor) slows satisfaction loss
## and adds to every served dish. When the shift time is up, customers
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
	## Pay and tips, in coins.
	var coins_earned: int = 0
	## Customer id -> what they paid, tip included (for pop-ups).
	var payments: Dictionary[String, int] = {}
	var tips_earned: int = 0
	## Recipe id per finished batch.
	var dishes_ready: Array[String] = []
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


## What customers can order now: the menu's unlocked recipes, or every unlocked
## recipe if none of the menu is (an empty menu, or a lost Xeno's recipe).
static func order_menu(state: GameState, data: GameData) -> Array[Recipe]:
	var unlocked := unlocked_recipes(state, data)
	var result := unlocked.filter(func(recipe: Recipe) -> bool: return state.menu.has(recipe.id))
	return unlocked if result.is_empty() else result


## Total appeal of working greeters; the arrival gap is divided by 1 + this.
static func greeter_appeal(state: GameState, data: GameData) -> float:
	var total := 0.0
	for synth: Synth in state.synths:
		if synth.role == Synth.GREETER:
			total += maxf(SynthStats.stat(synth, "appeal", data), 0.0) * SynthStats.work_factor(synth, state, data)
	return total


## How many times faster than the base gap customers arrive: greeters plus extra seats.
static func arrival_rate(state: GameState, data: GameData) -> float:
	var extra_seats := maxi(state.seats - data.balance.start_seats, 0)
	return 1.0 + greeter_appeal(state, data) + data.balance.arrival_per_extra_seat * extra_seats


static func seated_count(state: GameState) -> int:
	return state.customers.filter(func(customer: Customer) -> bool: return customer.is_seated()).size()


static func queued_count(state: GameState) -> int:
	return state.customers.filter(func(customer: Customer) -> bool:
		return customer.stage == Customer.Stage.QUEUED).size()


static func _tick(state: GameState, data: GameData, rng: RandomNumberGenerator, events: Events) -> void:
	_cook(state, data, rng, events)
	_arrive(state, data, rng, events)
	_seat(state, data, rng)
	_serve(state, data, rng, events)
	_update_customers(state, data, events)
	_drain(state, data)
	state.shift_time += 1


static func _cook(state: GameState, data: GameData, rng: RandomNumberGenerator, events: Events) -> void:
	if state.stoves.all(func(stove: Stove) -> bool: return stove.is_idle()):
		return
	var rate := 1.0
	var cooking: Array[Synth] = []
	for synth: Synth in state.synths:
		if synth.role != Synth.CHEF:
			continue
		var factor := SynthStats.work_factor(synth, state, data)
		if factor <= 0.0:
			continue
		if rng.randf() < SynthStats.stat(synth, "glitch_chance", data):
			events.glitches += 1
			continue
		rate += maxf(SynthStats.stat(synth, "cook", data), 0.0) * factor
		cooking.append(synth)
	for stove: Stove in state.stoves:
		if stove.is_idle():
			continue
		stove.remaining -= rate
		if stove.remaining <= 0.0:
			var recipe := data.recipes[stove.recipe_id]
			state.counter[recipe.id] = state.counter.get(recipe.id, 0) + recipe.servings
			events.dishes_ready.append(recipe.id)
			Leveling.share(cooking, data.balance.xp_per_batch, data.balance, events.level_ups)
			stove.recipe_id = ""
			stove.remaining = 0.0


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
	state.customers.append(customer)
	events.arrived.append(customer.id)
	var greeting: Array[Synth] = []
	for synth: Synth in state.synths:
		if synth.role == Synth.GREETER and SynthStats.work_factor(synth, state, data) > 0.0:
			greeting.append(synth)
	Leveling.share(greeting, b.xp_per_arrival, b, events.level_ups)


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


static func _seat(state: GameState, data: GameData, rng: RandomNumberGenerator) -> void:
	var free := state.seats - seated_count(state)
	if free <= 0:
		return
	var menu := order_menu(state, data)
	for customer: Customer in state.customers:
		if free <= 0:
			return
		if customer.stage != Customer.Stage.QUEUED:
			continue
		customer.stage = Customer.Stage.WAITING_FOOD
		customer.waited = 0
		customer.recipe_id = _pick_order(data.customer_types[customer.type_id], menu, data.balance, rng)
		free -= 1


## A menu dish, favourites weighted by favorite_weight.
static func _pick_order(type: CustomerType, menu: Array[Recipe], b: BalanceConfig, rng: RandomNumberGenerator) -> String:
	var weights: Array[float] = []
	var total := 0.0
	for recipe: Recipe in menu:
		var weight := b.favorite_weight if type.favorites.has(recipe.id) else 1.0
		weights.append(weight)
		total += weight
	var roll := rng.randf() * total
	for i: int in menu.size():
		roll -= weights[i]
		if roll < 0.0:
			return menu[i].id
	return menu[-1].id


static func _serve(state: GameState, data: GameData, rng: RandomNumberGenerator, events: Events) -> void:
	for synth: Synth in state.synths:
		if synth.role != Synth.SERVER:
			continue
		var factor := SynthStats.work_factor(synth, state, data)
		if factor <= 0.0:
			continue
		if not synth.is_delivering():
			_take_order(state, synth, data)
			continue
		synth.task_remaining -= SynthStats.speed(synth, data) * factor
		if synth.task_remaining <= 0.0:
			_deliver(state, synth, data, rng, events)


## Picks up a serving for the longest-seated customer whose dish is ready.
static func _take_order(state: GameState, synth: Synth, data: GameData) -> void:
	for customer: Customer in state.customers:
		if customer.stage != Customer.Stage.WAITING_FOOD or customer.served_by != "":
			continue
		if state.counter.get(customer.recipe_id, 0) <= 0:
			continue
		state.counter[customer.recipe_id] -= 1
		customer.served_by = synth.id
		synth.task_customer_id = customer.id
		synth.task_recipe_id = customer.recipe_id
		synth.task_remaining = data.balance.delivery_seconds
		return


static func _deliver(state: GameState, synth: Synth, data: GameData, rng: RandomNumberGenerator,
		events: Events) -> void:
	var customer := state.customer_by_id(synth.task_customer_id)
	_clear_task(synth)
	if customer == null:
		return
	customer.served_by = ""
	if rng.randf() < SynthStats.stat(synth, "break_chance", data):
		events.dishes_broken += 1
		customer.satisfaction = maxf(customer.satisfaction - data.balance.break_satisfaction_penalty, 0.0)
		return
	customer.stage = Customer.Stage.EATING
	customer.timer = data.balance.eat_seconds
	var bonus := SynthStats.stat(synth, "satisfaction", data) \
		+ minf(state.vibe * data.balance.vibe_meal_bonus, data.balance.vibe_meal_bonus_max)
	if data.customer_types[customer.type_id].favorites.has(customer.recipe_id):
		bonus += data.balance.favorite_satisfaction
	customer.satisfaction = clampf(customer.satisfaction + bonus, 0.0, 100.0)
	customer.tip_bonus = SynthStats.stat(synth, "tip", data)
	Leveling.add_xp(synth, data.balance.xp_per_delivery, data.balance, events.level_ups)


static func _update_customers(state: GameState, data: GameData, events: Events) -> void:
	var b := data.balance
	for customer: Customer in state.customers.duplicate():
		var type := data.customer_types[customer.type_id]
		match customer.stage:
			Customer.Stage.QUEUED:
				_wait(customer, type, b, state.vibe)
				if customer.waited >= roundi(b.queue_patience_seconds * type.patience):
					_leave_angry(state, customer, events)
			Customer.Stage.WAITING_FOOD:
				_wait(customer, type, b, state.vibe)
				if customer.satisfaction <= 0.0:
					_leave_angry(state, customer, events)
			Customer.Stage.EATING:
				customer.timer -= 1
				if customer.timer <= 0:
					_finish_meal(state, customer, data, events)
			Customer.Stage.STAR:
				customer.timer -= 1
				if customer.timer <= 0:
					state.customers.erase(customer)
					events.star_expired.append(customer.id)


static func _wait(customer: Customer, type: CustomerType, b: BalanceConfig, vibe: float) -> void:
	customer.waited += 1
	if customer.waited > b.wait_grace_seconds:
		var loss := b.satisfaction_decay_per_second / maxf(type.patience, 0.1) / (1.0 + maxf(vibe, 0.0) * b.vibe_decay_per_point)
		customer.satisfaction = maxf(customer.satisfaction - loss, 0.0)


## Pays, and tips if satisfied enough for a star. A starred customer stays for
## the star window unless can_star is false (the café is closing).
static func _finish_meal(state: GameState, customer: Customer, data: GameData, events: Events,
		can_star := true) -> void:
	var b := data.balance
	var recipe := data.recipes[customer.recipe_id]
	var pay := roundi(recipe.price * (b.min_pay_share + (1.0 - b.min_pay_share) * customer.satisfaction / 100.0))
	state.coins += pay
	events.coins_earned += pay
	events.served.append(customer.id)
	events.payments[customer.id] = pay
	if customer.satisfaction < b.star_threshold:
		state.customers.erase(customer)
		return
	var type := data.customer_types[customer.type_id]
	var tip := roundi(recipe.price * b.tip_rate * type.tip * (1.0 + customer.tip_bonus))
	state.coins += tip
	events.tips_earned += tip
	events.payments[customer.id] += tip
	if not can_star:
		state.customers.erase(customer)
		return
	customer.stage = Customer.Stage.STAR
	customer.timer = b.star_window_seconds
	events.starred.append(customer.id)


## Leaves without paying; a dish already on its way goes back to the counter.
static func _leave_angry(state: GameState, customer: Customer, events: Events) -> void:
	if customer.served_by != "":
		var synth := state.synth_by_id(customer.served_by)
		if synth != null:
			_return_dish(state, synth)
	state.customers.erase(customer)
	events.left_angry.append(customer.id)


static func _drain(state: GameState, data: GameData) -> void:
	for synth: Synth in state.synths:
		if SynthStats.on_duty(synth):
			synth.battery = maxf(synth.battery - maxf(SynthStats.stat(synth, "drain", data), 0.0), 0.0)


## Customers eating pay and leave, the rest just leave; dishes in hand go back.
static func _close(state: GameState, data: GameData, events: Events) -> void:
	for customer: Customer in state.customers.duplicate():
		if customer.stage == Customer.Stage.EATING:
			_finish_meal(state, customer, data, events, false)
	for synth: Synth in state.synths:
		if synth.is_delivering():
			_return_dish(state, synth)
	state.customers.clear()
	state.phase = GameState.Phase.NIGHT
	events.shift_ended = true


static func _return_dish(state: GameState, synth: Synth) -> void:
	state.counter[synth.task_recipe_id] = state.counter.get(synth.task_recipe_id, 0) + 1
	_clear_task(synth)


static func _clear_task(synth: Synth) -> void:
	synth.task_customer_id = ""
	synth.task_recipe_id = ""
	synth.task_remaining = 0.0
