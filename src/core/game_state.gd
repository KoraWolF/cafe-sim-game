class_name GameState
extends Resource
## Everything that changes during a game, in one saveable object. Content
## lives in GameData and is not saved.

enum Phase {
	SHIFT, ## The café is open; time passes through GameLoop.advance.
	NIGHT, ## Time is stopped; the player plans Night Ops, then ends the night.
}

## Speeds the player can pick (0 = paused).
const SPEEDS: Array[int] = [0, 1, 2, 4]

@export var day: int = 1
@export var phase: Phase = Phase.SHIFT
## Seconds since this shift opened.
@export var shift_time: int = 0
## Shift second at which the next customer arrives.
@export var next_arrival: int = 0
@export var speed: int = 1

@export var coins: int = 0
@export var nanobrew: int = 0
## Nano Cores: the rare raid ingredient NanoBrew is brewed from.
@export var cores: int = 0
## Energy (shown as "Energy"; not a Synth's fight power): recharges batteries at night.
@export var power: float = 0.0

## Working seats, each beside its own table (kept up to date by Layout.refresh) and Sync Pods
## in the Pod bay outside (one per Synth: the staff cap).
@export var seats: int = 0
@export var pods: int = 0
## Floor size in tiles: across and deep.
@export var floor_width: int = 0
@export var floor_rows: int = 0
@export var placed: Array[PlacedPiece] = []
## Pieces owned but not on the floor: piece id -> count.
@export var storage: Dictionary[String, int] = {}
## From the layout (Layout.refresh); not saved. vibe is the total over seats.
var vibe: float = 0.0
var seat_vibe: Dictionary[String, float] = {}
## Working seat uid -> the table uid it faces (derived from the floor, not saved).
var seat_table: Dictionary[String, String] = {}
## Extra HP for each home defender.
@export var security: float = 0.0
@export var stoves: Array[Stove] = []
## Upgrade id -> times bought.
@export var upgrades: Dictionary[String, int] = {}
## Ready servings on the counters: recipe id -> count (see Counters).
@export var counter: Dictionary[String, int] = {}
## Items not worn by anyone (equipment and fashion), EXP bottles by id, and
## raid materials for crafting.
@export var inventory: Array[Item] = []
@export var bottles: Dictionary[String, int] = {}
@export var scrap: int = 0
@export var chips: int = 0
## Lifetime counters for quests (served, stars, coins_earned, batches,
## conversions, raids_won, clean_days), today's daily quests and the real-world
## date they were rolled, the story step, and claimed achievement ids.
@export var stats: Dictionary[String, int] = {}
@export var daily_quests: Array[Dictionary] = []
@export var daily_date: String = ""
@export var story_index: int = 0
@export var achievements: Array[String] = []
## Starred customers who paid and left this shift: convertible until closing.
@export var star_list: Array[Customer] = []
## Auto on: each night passes by itself with no raid
## (see Session.auto_night). Unlocks on auto_unlock_day.
@export var auto_night: bool = false
## Placed counters and stoves whose food the player asked to throw away; an
## idle server takes it all to the nearest bin (no refund).
@export var discard: Array[String] = []
## Counter piece uid -> the dish on it, and how many servings.
@export var counter_dish: Dictionary[String, String] = {}
@export var counter_count: Dictionary[String, int] = {}

@export var customers: Array[Customer] = []
@export var synths: Array[Synth] = []

## The district being contested: where raids happen and Suspicion builds.
@export var district_id: String = ""
## Day the current district opened (rival guards grow from then).
@export var district_started_day: int = 1
## Districts taken over; each pays its income every night.
@export var owned_districts: Array[String] = []
## District id -> Influence earned there by winning raids.
@export var influence: Dictionary[String, int] = {}
## District id -> 0..100.
@export var suspicion: Dictionary[String, float] = {}
## True for a shift the café is shut after a lost Corporate Audit.
@export var closed: bool = false
## Rival id -> first day it can be raided again.
@export var raid_cooldowns: Dictionary[String, int] = {}
## Tonight's raid: "" = none.
@export var raid_target: String = ""
@export var raid_squad: Array[String] = []

@export var next_id: int = 1
## Random number generator state, so a loaded game continues the same way.
@export var rng_seed: int = 0
@export var rng_state: int = 0


## Day 1, shift just opened: the starting stoves, Pods and seats laid out on
## the floor, and the two starters (one at the register) at full battery.
static func new_game(seed_value: int, data: GameData) -> GameState:
	var b := data.balance
	var state := GameState.new()
	state.coins = b.start_coins
	state.nanobrew = b.start_nanobrew
	state.cores = b.start_cores
	state.power = b.start_power
	state.security = b.start_security
	state.floor_width = b.start_floor_width
	state.floor_rows = b.start_floor_rows
	state.pods = b.start_pods
	# Kind by kind (stoves, counters, tables, seats, bins): the start layout's spots first,
	# then the first free spot (seats and tables next to each other where they can).
	var wanted: Dictionary[String, int] = {Piece.STOVE: b.start_stoves, Piece.COUNTER: b.start_counters,
		Piece.TABLE: b.start_tables, Piece.SEAT: b.start_seats, Piece.BIN: b.start_bins, Piece.REGISTER: b.start_registers}
	for piece_id: String in wanted:
		for entry: Variant in b.start_layout:
			if wanted[piece_id] <= 0 or not entry is Dictionary or str(entry.get("piece", "")) != piece_id:
				continue
			var spot: Variant = entry.get("cell", [])
			var rotated := bool(entry.get("rotated", false))
			if spot is Array and spot.size() == 2:
				var cell := Vector2i(int(spot[0]), int(spot[1]))
				if Layout.check_spot(state, piece_id, cell, rotated, data) == GameLoop.OK:
					Layout.place_new(state, piece_id, cell, rotated, data)
					wanted[piece_id] -= 1
		for i: int in wanted[piece_id]:
			if not Layout.auto_place(state, piece_id, data):
				push_error("GameState: the starting furniture does not fit the floor")
	state.district_id = b.start_district
	state.suspicion[b.start_district] = 0.0
	state.next_arrival = b.first_arrival_seconds
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state.rng_seed = rng.seed
	state.rng_state = rng.state
	var starter := state.add_synth(b.starter_species, "", data, data.species[b.starter_species].roll_battery_max(rng))
	state.store_rng(rng)
	starter.battery = SynthStats.stat(starter, "battery_max", data)
	starter.name = b.starter_name
	starter.role = Synth.SERVER
	if b.starter_cashier_species != "":
		var cashier := state.add_starter_cashier(data)
		# Either starter may be the one at the register.
		var generator := state.rng()
		if generator.randi_range(0, 1) == 0:
			cashier.role = Synth.SERVER
			cashier.station_uid = ""
			starter.role = Synth.CASHIER
			Roles.bind_free(state, data)
		state.store_rng(generator)
	for fashion_id: String in data.items.starter_fashion:
		state.inventory.append(Items.make(state, Item.FASHION, fashion_id))
	return state


## Adds the starting Cashier (a full-battery starter_cashier_species at the register).
func add_starter_cashier(data: GameData) -> Synth:
	var b := data.balance
	var generator := rng()
	var cashier := add_synth(b.starter_cashier_species, "", data, data.species[b.starter_cashier_species].roll_battery_max(generator))
	store_rng(generator)
	cashier.battery = SynthStats.stat(cashier, "battery_max", data)
	cashier.name = b.starter_cashier_name
	cashier.role = Synth.CASHIER
	Roles.bind_free(self, data)
	return cashier


## The generator at the saved state; call store_rng after using it.
func rng() -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = rng_seed
	generator.state = rng_state
	return generator


func store_rng(generator: RandomNumberGenerator) -> void:
	rng_state = generator.state


func new_id(prefix: String) -> String:
	var id := "%s_%d" % [prefix, next_id]
	next_id += 1
	return id


## Adds a Synth at full battery in its species' best role. Does not check pods.
## battery_max 0 = the species' battery_max.
func add_synth(species_id: String, trait_id: String, data: GameData, battery_max := 0) -> Synth:
	var synth := Synth.new()
	synth.id = new_id("synth")
	synth.species_id = species_id
	synth.trait_id = trait_id
	synth.battery_max = battery_max
	synth.role = data.species[species_id].best_role
	synth.battery = SynthStats.stat(synth, "battery_max", data)
	synths.append(synth)
	return synth


func synth_by_id(synth_id: String) -> Synth:
	for synth: Synth in synths:
		if synth.id == synth_id:
			return synth
	return null


func customer_by_id(customer_id: String) -> Customer:
	for customer: Customer in customers:
		if customer.id == customer_id:
			return customer
	return null


## A customer in the café or on the starred list.
func convertible_by_id(customer_id: String) -> Customer:
	for customer: Customer in star_list:
		if customer.id == customer_id:
			return customer
	return customer_by_id(customer_id)


func has_species(species_id: String) -> bool:
	return synths.any(func(synth: Synth) -> bool: return synth.species_id == species_id)


func current_suspicion() -> float:
	return suspicion.get(district_id, 0.0)


func current_influence() -> int:
	return influence.get(district_id, 0)


## True once every district is taken over.
func owns_city(data: GameData) -> bool:
	return data.district_order.all(func(id: String) -> bool: return owned_districts.has(id))


func add_suspicion(amount: float) -> void:
	suspicion[district_id] = clampf(current_suspicion() + amount, 0.0, 100.0)
