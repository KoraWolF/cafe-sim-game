class_name GameLoop
extends RefCounted
## Every action the player can take, plus time. No UI and no files: the UI
## calls these and shows the returned events and reports.
##
## A day: the shift runs through advance() until it closes (phase NIGHT). At
## night the player may set tomorrow's menu, plan a raid, brew, buy Power,
## upgrades and décor, arrange the floor and change roles; then
## end_night() resolves Night Ops and opens the next shift.
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
const EMPTY_MENU: String = "empty_menu"
const MENU_TOO_LONG: String = "menu_too_long"
const UNKNOWN_UPGRADE: String = "unknown_upgrade"
const NO_ROOM: String = "no_room"
const UNKNOWN_PIECE: String = "unknown_piece"
const NOT_FOR_SALE: String = "not_for_sale"
const NONE_STORED: String = "none_stored"
const OUT_OF_BOUNDS: String = "out_of_bounds"
const OVERLAP: String = "overlap"
const UNKNOWN_PLACED: String = "unknown_placed"
const POD_IN_USE: String = "pod_in_use"
const MAXED: String = "maxed"


## Passes shift time. Returns empty events outside a shift. A shift shut by a
## lost Corporate Audit closes at once (events.closed).
static func advance(state: GameState, seconds: int, data: GameData) -> Shift.Events:
	return Shift.run(state, seconds, data)


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


## Turns a starred customer into a Synth: 1 NanoBrew, a free Pod, +Suspicion.
## The Synth gets the trait the customer arrived with.
## The new Synth is returned through out_synth when given.
static func convert_customer(state: GameState, customer_id: String, data: GameData,
		out_synth: Array[Synth] = []) -> String:
	if state.phase != GameState.Phase.SHIFT:
		return WRONG_PHASE
	var customer := state.customer_by_id(customer_id)
	if customer == null:
		return UNKNOWN_CUSTOMER
	if customer.stage != Customer.Stage.STAR:
		return NO_STAR
	if state.nanobrew <= 0:
		return NO_NANOBREW
	if state.synths.size() >= state.pods:
		return NO_FREE_POD
	var type := data.customer_types[customer.type_id]
	var trait_id := customer.trait_id
	if trait_id == "" and not type.trait_pool.is_empty():
		# Customers from saves made before traits were rolled on arrival.
		var rng := state.rng()
		trait_id = type.trait_pool[rng.randi_range(0, type.trait_pool.size() - 1)]
		state.store_rng(rng)
	state.nanobrew -= 1
	state.customers.erase(customer)
	state.add_suspicion(data.balance.conversion_suspicion)
	out_synth.append(state.add_synth(type.synth_species, trait_id, data))
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


## Sets the next shift's menu (duplicates dropped). Only at night.
static func set_menu(state: GameState, recipe_ids: Array[String], data: GameData) -> String:
	if state.phase != GameState.Phase.NIGHT:
		return WRONG_PHASE
	var menu: Array[String] = []
	for recipe_id: String in recipe_ids:
		if not menu.has(recipe_id):
			menu.append(recipe_id)
	if menu.is_empty():
		return EMPTY_MENU
	if menu.size() > state.menu_slots:
		return MENU_TOO_LONG
	var unlocked := Shift.unlocked_recipes(state, data)
	for recipe_id: String in menu:
		var recipe: Recipe = data.recipes.get(recipe_id)
		if recipe == null:
			return UNKNOWN_RECIPE
		if not unlocked.has(recipe):
			return RECIPE_LOCKED
	state.menu = menu
	return OK


## Coins the next purchase of this upgrade costs, or -1 if it is maxed or unknown.
static func upgrade_cost(state: GameState, upgrade_id: String, data: GameData) -> int:
	var upgrade: Upgrade = data.upgrades.get(upgrade_id)
	if upgrade == null:
		return -1
	var level: int = state.upgrades.get(upgrade_id, 0)
	return -1 if level >= upgrade.max_level else upgrade.cost_at(level)


## Buys one level of an upgrade. Only at night, while the café is closed.
## Stove, seat and Pod upgrades put the piece in storage to be placed, and need
## a free spot for it on the floor (expand the floor first).
static func buy_upgrade(state: GameState, upgrade_id: String, data: GameData) -> String:
	if state.phase != GameState.Phase.NIGHT:
		return WRONG_PHASE
	var upgrade: Upgrade = data.upgrades.get(upgrade_id)
	if upgrade == null:
		return UNKNOWN_UPGRADE
	var cost := upgrade_cost(state, upgrade_id, data)
	if cost < 0:
		return MAXED
	if state.coins < cost:
		return NOT_ENOUGH_COINS
	var furniture := [Upgrade.STOVE, Upgrade.SEAT, Upgrade.POD].has(upgrade_id)
	if furniture and Layout.find_spot(state, upgrade_id, data).is_empty():
		return NO_ROOM
	state.coins -= cost
	state.upgrades[upgrade_id] = state.upgrades.get(upgrade_id, 0) + 1
	if furniture:
		state.storage[upgrade_id] = state.storage.get(upgrade_id, 0) + roundi(upgrade.step)
	match upgrade_id:
		Upgrade.FLOOR:
			state.floor_rows += roundi(upgrade.step)
			Layout.refresh(state, data)
		Upgrade.MENU_SLOT:
			state.menu_slots += roundi(upgrade.step)
		Upgrade.SECURITY:
			state.security += upgrade.step
	return OK


## Buys a décor piece into storage. Night only, like every floor change below.
static func buy_decor(state: GameState, piece_id: String, data: GameData) -> String:
	return Layout.buy(state, piece_id, data) if state.phase == GameState.Phase.NIGHT else WRONG_PHASE


## Places a stored piece with its top-left tile on cell.
static func place_piece(state: GameState, piece_id: String, cell: Vector2i, rotated: bool, data: GameData) -> String:
	return Layout.place(state, piece_id, cell, rotated, data) if state.phase == GameState.Phase.NIGHT else WRONG_PHASE


## Moves (and/or rotates) a placed piece. Free.
static func move_piece(state: GameState, uid: String, cell: Vector2i, rotated: bool, data: GameData) -> String:
	return Layout.move(state, uid, cell, rotated, data) if state.phase == GameState.Phase.NIGHT else WRONG_PHASE


## Puts a placed piece back in storage.
static func pick_up_piece(state: GameState, uid: String, data: GameData) -> String:
	return Layout.pick_up(state, uid, data) if state.phase == GameState.Phase.NIGHT else WRONG_PHASE


## Sells a placed décor piece for sell_refund of its price.
static func sell_piece(state: GameState, uid: String, data: GameData) -> String:
	return Layout.sell_placed(state, uid, data) if state.phase == GameState.Phase.NIGHT else WRONG_PHASE


## Sells one stored décor piece for sell_refund of its price.
static func sell_stored_piece(state: GameState, piece_id: String, data: GameData) -> String:
	return Layout.sell_stored(state, piece_id, data) if state.phase == GameState.Phase.NIGHT else WRONG_PHASE


## A server carrying a dish has to finish the delivery first.
static func assign_role(state: GameState, synth_id: String, role: String) -> String:
	var synth := state.synth_by_id(synth_id)
	if synth == null:
		return UNKNOWN_SYNTH
	if not Synth.ROLES.has(role):
		return UNKNOWN_ROLE
	if synth.is_delivering():
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
	return NightOps.resolve(state, data)
