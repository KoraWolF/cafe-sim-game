class_name GameLoop
extends RefCounted
## Every action the player can take, plus time. No UI and no files: the UI
## calls these and shows the returned events and reports.
##
## A day: the shift runs through advance() until it closes (phase NIGHT). At
## night the player sets tomorrow's menu and plans a raid; then end_night()
## resolves Night Ops and opens the next shift. Building (upgrades, décor,
## arranging the floor), brewing, buying Energy and roles work at any time.
## Actions return OK ("") or an error code.

const OK: String = ""
const WRONG_PHASE: String = "wrong_phase"
const UNKNOWN_STOVE: String = "unknown_stove"
const STOVE_BUSY: String = "stove_busy"
const UNKNOWN_RECIPE: String = "unknown_recipe"
const RECIPE_LOCKED: String = "recipe_locked"
const NOT_ENOUGH_COINS: String = "not_enough_coins"
const NOT_ENOUGH_CORES: String = "not_enough_cores"
const UNKNOWN_CUSTOMER: String = "unknown_customer"
const NO_STAR: String = "no_star"
const NO_NANOBREW: String = "no_nanobrew"
const NO_FREE_POD: String = "no_free_pod"
const UNKNOWN_SYNTH: String = "unknown_synth"
const UNKNOWN_ROLE: String = "unknown_role"
const SYNTH_BUSY: String = "synth_busy"
const BAD_AMOUNT: String = "bad_amount"
const UNKNOWN_TARGET: String = "unknown_target"
const TARGET_COOLDOWN: String = "target_cooldown"
const EMPTY_SQUAD: String = "empty_squad"
const SQUAD_TOO_BIG: String = "squad_too_big"
const NO_BATTERY: String = "no_battery"
const FLAGSHIP_LOCKED: String = "flagship_locked"
const NOT_COOKING: String = "not_cooking"
const UNKNOWN_UPGRADE: String = "unknown_upgrade"
const NO_ROOM: String = "no_room"
const UNKNOWN_PIECE: String = "unknown_piece"
const NOT_FOR_SALE: String = "not_for_sale"
const NONE_STORED: String = "none_stored"
const OUT_OF_BOUNDS: String = "out_of_bounds"
const OVERLAP: String = "overlap"
const UNKNOWN_PLACED: String = "unknown_placed"
const COUNTER_NEEDED: String = "counter_needed"
const COUNTER_BUSY: String = "counter_busy"
const SEAT_BUSY: String = "seat_busy"
const NO_JOB_THERE: String = "no_job_there"
const REGISTER_NEEDED: String = "register_needed"
const EMPTY_NAME: String = "empty_name"
const NAME_TOO_LONG: String = "name_too_long"
const MAXED: String = "maxed"
const NOTHING_TO_THROW: String = "nothing_to_throw"
const NO_BIN: String = "no_bin"
const BATCH_ON_THE_WAY: String = "batch_on_the_way"
const AUTO_LOCKED: String = "auto_locked"
const UNKNOWN_ITEM: String = "unknown_item"
const NOTHING_WORN: String = "nothing_worn"
const UNKNOWN_CRAFT: String = "unknown_craft"
const NOT_ENOUGH_MATERIALS: String = "not_enough_materials"
const NONE_LEFT: String = "none_left"
const UNKNOWN_QUEST: String = "unknown_quest"
const NOT_DONE: String = "not_done"
const ALREADY_CLAIMED: String = "already_claimed"


## Passes shift time. Returns empty events outside a shift. A shift shut by a
## lost Corporate Audit closes at once (events.closed).
static func advance(state: GameState, seconds: int, data: GameData) -> Shift.Events:
	var events := Shift.run(state, seconds, data)
	Quests.record_shift(state, events)
	return events


## Starts a batch on an idle stove (any phase; it cooks only during shifts).
static func start_cooking(state: GameState, stove_index: int, recipe_id: String, data: GameData) -> String:
	if stove_index < 0 or stove_index >= state.stoves.size():
		return UNKNOWN_STOVE
	var stove := state.stoves[stove_index]
	if not stove.is_idle():
		return STOVE_BUSY
	var recipe: Recipe = data.recipes.get(recipe_id)
	if recipe == null:
		return UNKNOWN_RECIPE
	if not Shift.unlocked_recipes(state, data).has(recipe):
		return RECIPE_LOCKED
	if state.coins < recipe.cost:
		return NOT_ENOUGH_COINS
	state.coins -= recipe.cost
	stove.recipe_id = recipe.id
	stove.remaining = recipe.cook_seconds
	return OK


## Stops a batch that is still cooking (a wrong pick) and refunds its cost.
static func cancel_cooking(state: GameState, stove_index: int, data: GameData) -> String:
	if stove_index < 0 or stove_index >= state.stoves.size():
		return UNKNOWN_STOVE
	var stove := state.stoves[stove_index]
	if stove.is_idle() or stove.has_batch():
		return NOT_COOKING
	state.coins += data.recipes[stove.recipe_id].cost
	stove.recipe_id = ""
	stove.remaining = 0.0
	return OK


## Turns a starred customer (paying or leaving) into a Synth: 1 NanoBrew, a
## free Pod, +Suspicion. One still in the pay line pays first.
## The Synth gets the trait and max battery the customer arrived with, starts
## Resting in its Pod and loses conversion_battery_loss of its battery.
## The new Synth is returned through out_synth when given.
static func convert_customer(state: GameState, customer_id: String, data: GameData,
		out_synth: Array[Synth] = []) -> String:
	if state.phase != GameState.Phase.SHIFT:
		return WRONG_PHASE
	var customer := state.convertible_by_id(customer_id)
	if customer == null:
		return UNKNOWN_CUSTOMER
	if not customer.can_convert():
		return NO_STAR
	if state.nanobrew <= 0:
		return NO_NANOBREW
	if state.synths.size() >= state.pods:
		return NO_FREE_POD
	var type := data.customer_types[customer.type_id]
	var trait_id := customer.trait_id
	var battery_max := customer.battery_max
	if (trait_id == "" and not type.trait_pool.is_empty()) or battery_max <= 0:
		# Customers from saves made before traits and batteries were rolled on arrival.
		var rng := state.rng()
		if trait_id == "" and not type.trait_pool.is_empty():
			trait_id = type.trait_pool[rng.randi_range(0, type.trait_pool.size() - 1)]
		if battery_max <= 0:
			battery_max = data.species[type.synth_species].roll_battery_max(rng)
		state.store_rng(rng)
	state.nanobrew -= 1
	if customer.stage == Customer.Stage.PAYING:
		state.coins += customer.bill + customer.tip
	state.customers.erase(customer)
	state.star_list.erase(customer)
	state.add_suspicion(data.balance.conversion_suspicion)
	var synth := state.add_synth(type.synth_species, trait_id, data, battery_max)
	state.stats["conversions"] = state.stats.get("conversions", 0) + 1
	synth.role = Synth.REST
	synth.battery *= 1.0 - data.balance.conversion_battery_loss
	out_synth.append(synth)
	return OK


## Asks a server to throw away all the food on a counter, or a stove's waiting
## batch, into the nearest bin. No refund. Any phase: at night the servers do
## it first thing next shift.
static func throw_away(state: GameState, uid: String, data: GameData) -> String:
	var error := throw_away_error(state, uid, data)
	if error == OK and not state.discard.has(uid):
		state.discard.append(uid)
	return error


## Why throw_away would fail for this piece (OK if it would work). Changes nothing.
static func throw_away_error(state: GameState, uid: String, data: GameData) -> String:
	var placed := Layout.placed_by_uid(state, uid)
	if placed == null:
		return UNKNOWN_PLACED
	match data.pieces[placed.piece_id].kind:
		Piece.COUNTER:
			if state.counter_count.get(uid, 0) <= 0:
				return NOTHING_TO_THROW
		Piece.STOVE:
			var stove := Layout.stove_of(state, uid)
			if not stove.has_batch():
				return NOTHING_TO_THROW
			if stove.carrier != "":
				return BATCH_ON_THE_WAY
		_:
			return NOTHING_TO_THROW
	if Layout.count_placed(state, Piece.BIN, data) == 0:
		return NO_BIN
	return OK


static func brew_nanobrew(state: GameState, data: GameData) -> String:
	var b := data.balance
	if state.cores < b.brew_core_cost:
		return NOT_ENOUGH_CORES
	if state.coins < b.brew_coin_cost:
		return NOT_ENOUGH_COINS
	state.cores -= b.brew_core_cost
	state.coins -= b.brew_coin_cost
	state.nanobrew += 1
	return OK


static func buy_power(state: GameState, amount: int, data: GameData) -> String:
	if amount <= 0:
		return BAD_AMOUNT
	var price := amount * data.balance.power_price
	if state.coins < price:
		return NOT_ENOUGH_COINS
	state.coins -= price
	state.power += amount
	return OK


## Coins the next purchase of this upgrade costs, or -1 if it is maxed or unknown.
static func upgrade_cost(state: GameState, upgrade_id: String, data: GameData) -> int:
	var upgrade: Upgrade = data.upgrades.get(upgrade_id)
	if upgrade == null:
		return -1
	var level: int = state.upgrades.get(upgrade_id, 0)
	return -1 if level >= upgrade.max_level else upgrade.cost_at(level)


## Buys one level of an upgrade (Pods, floor, security), at any time.
static func buy_upgrade(state: GameState, upgrade_id: String, data: GameData) -> String:
	var upgrade: Upgrade = data.upgrades.get(upgrade_id)
	if upgrade == null:
		return UNKNOWN_UPGRADE
	var cost := upgrade_cost(state, upgrade_id, data)
	if cost < 0:
		return MAXED
	if state.coins < cost:
		return NOT_ENOUGH_COINS
	state.coins -= cost
	state.upgrades[upgrade_id] = state.upgrades.get(upgrade_id, 0) + 1
	match upgrade_id:
		Upgrade.POD:
			state.pods += roundi(upgrade.step)
		Upgrade.FLOOR:
			var size: int = upgrade.sizes[state.upgrades[upgrade_id] - 1] if not upgrade.sizes.is_empty() \
				else state.floor_rows + roundi(upgrade.step)
			state.floor_width = maxi(state.floor_width, size)
			state.floor_rows = maxi(state.floor_rows, size)
			Layout.refresh(state, data)
		Upgrade.SECURITY:
			state.security += upgrade.step
	return OK


## Buys a piece of furniture or décor into storage, as many as you like (the
## floor is the limit). Any time, like every floor change below (in a shift,
## pieces in use stay put: see Layout).
static func buy_piece(state: GameState, piece_id: String, data: GameData) -> String:
	return Layout.buy(state, piece_id, data)


## Places a stored piece with its top-left tile on cell.
static func place_piece(state: GameState, piece_id: String, cell: Vector2i, rotated: bool, data: GameData) -> String:
	return Layout.place(state, piece_id, cell, rotated, data)


## Moves (and/or rotates) a placed piece. Free.
static func move_piece(state: GameState, uid: String, cell: Vector2i, rotated: bool, data: GameData) -> String:
	return Layout.move(state, uid, cell, rotated, data)


## Puts a placed piece back in storage.
static func pick_up_piece(state: GameState, uid: String, data: GameData) -> String:
	return Layout.pick_up(state, uid, data)


## Sells a placed piece for sell_refund of its price (not one in use, nor the
## last counter or register).
static func sell_piece(state: GameState, uid: String, data: GameData) -> String:
	return Layout.sell_placed(state, uid, data)


## Sells one stored piece for sell_refund of its price.
static func sell_stored_piece(state: GameState, piece_id: String, data: GameData) -> String:
	return Layout.sell_stored(state, piece_id, data)


## Turns Auto on or off. It unlocks on balance.auto_unlock_day.
static func set_auto(state: GameState, on: bool, data: GameData) -> String:
	if on and state.day < data.balance.auto_unlock_day:
		return AUTO_LOCKED
	state.auto_night = on
	return OK


## Why Auto would not pass tonight by itself ("" = it can): a Corporate Audit
## is coming, so the player decides.
static func auto_stop_reason(state: GameState, data: GameData) -> String:
	if state.current_suspicion() >= data.balance.audit_suspicion:
		return "audit"
	return ""


## Items, any time (see Items).
static func equip_item(state: GameState, synth_id: String, uid: String, data: GameData) -> String:
	return Items.equip(state, synth_id, uid, data)


static func unequip_item(state: GameState, synth_id: String, slot: String, data: GameData) -> String:
	return Items.unequip(state, synth_id, slot, data)


static func sell_item(state: GameState, uid: String, data: GameData) -> String:
	return Items.sell(state, uid, data)


static func craft_item(state: GameState, craft_id: String, data: GameData, out_item: Array[Item] = []) -> String:
	return Items.craft(state, craft_id, data, out_item)


static func use_bottle(state: GameState, synth_id: String, bottle_id: String, data: GameData,
		level_ups: Dictionary[String, int] = {}) -> String:
	return Items.use_bottle(state, synth_id, bottle_id, data, level_ups)


## Claims a finished quest's reward (see Quests.claim). Any time.
static func claim_quest(state: GameState, kind: String, key: String, data: GameData,
		out_reward: Array[Dictionary] = []) -> String:
	return Quests.claim(state, kind, key, data, out_reward)


## Longest Synth name.
const MAX_NAME_LENGTH: int = 20


## Gives a Synth a name (spaces at the ends are dropped). Any time.
static func rename_synth(state: GameState, synth_id: String, new_name: String) -> String:
	var synth := state.synth_by_id(synth_id)
	if synth == null:
		return UNKNOWN_SYNTH
	var clean := new_name.strip_edges()
	if clean.is_empty():
		return EMPTY_NAME
	if clean.length() > MAX_NAME_LENGTH:
		return NAME_TOO_LONG
	synth.name = clean
	return OK


## A job by place: click a worker, then a stove (Chef), counter or table
## (Server), register (Cashier). See Roles.
static func assign_to(state: GameState, synth_id: String, uid: String, data: GameData) -> String:
	return Roles.assign_to(state, synth_id, uid, data)


## Clicking the Pod bay: the worker rests.
static func send_to_rest(state: GameState, synth_id: String) -> String:
	return Roles.rest(state, synth_id)


## Sets a role directly (Chefs and Cashiers then take a free station). A
## server carrying a dish or a batch has to finish the trip first.
static func assign_role(state: GameState, synth_id: String, role: String) -> String:
	var synth := state.synth_by_id(synth_id)
	if synth == null:
		return UNKNOWN_SYNTH
	if not Synth.ROLES.has(role):
		return UNKNOWN_ROLE
	if synth.is_busy():
		return SYNTH_BUSY
	synth.role = role
	return OK


## Plans tonight's raid; replaces any earlier plan.
static func plan_raid(state: GameState, rival_id: String, synth_ids: Array[String], data: GameData) -> String:
	if state.phase != GameState.Phase.NIGHT:
		return WRONG_PHASE
	var district := data.districts[state.district_id]
	if district.rival_by_id(rival_id) == null:
		return UNKNOWN_TARGET
	if district.is_flagship(rival_id) and not NightOps.flagship_unlocked(state, data):
		return FLAGSHIP_LOCKED
	if state.raid_cooldowns.get(rival_id, 0) > state.day:
		return TARGET_COOLDOWN
	var squad: Array[String] = []
	for synth_id: String in synth_ids:
		if not squad.has(synth_id):
			squad.append(synth_id)
	if squad.is_empty():
		return EMPTY_SQUAD
	if squad.size() > data.balance.raid_squad_max:
		return SQUAD_TOO_BIG
	for synth_id: String in squad:
		var synth := state.synth_by_id(synth_id)
		if synth == null:
			return UNKNOWN_SYNTH
		if synth.battery <= 0.0:
			return NO_BATTERY
	state.raid_target = rival_id
	state.raid_squad = squad
	return OK


static func cancel_raid(state: GameState) -> void:
	state.raid_target = ""
	state.raid_squad.clear()


## Resolves Night Ops and opens the next shift. Returns null outside the night.
static func end_night(state: GameState, data: GameData) -> NightOps.Report:
	if state.phase != GameState.Phase.NIGHT:
		return null
	var report := NightOps.resolve(state, data)
	Quests.record_night(state, report)
	return report
