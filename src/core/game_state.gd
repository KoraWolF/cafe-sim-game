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
@export var power: float = 0.0

@export var seats: int = 0
## Sync Pods: one per Synth, so this is the staff cap.
@export var pods: int = 0
## Extra HP for each home defender.
@export var security: float = 0.0
@export var stoves: Array[Stove] = []
## Upgrade id -> times bought.
@export var upgrades: Dictionary[String, int] = {}
## Ready servings: recipe id -> count.
@export var counter: Dictionary[String, int] = {}

@export var customers: Array[Customer] = []
@export var synths: Array[Synth] = []

@export var district_id: String = ""
## District id -> 0..100.
@export var suspicion: Dictionary[String, float] = {}
## Rival id -> first day it can be raided again.
@export var raid_cooldowns: Dictionary[String, int] = {}
## Tonight's raid: "" = none.
@export var raid_target: String = ""
@export var raid_squad: Array[String] = []

@export var next_id: int = 1
## Random number generator state, so a loaded game continues the same way.
@export var rng_seed: int = 0
@export var rng_state: int = 0


## Day 1, shift just opened, with the starter Synth on its pod at full battery.
static func new_game(seed_value: int, data: GameData) -> GameState:
	var b := data.balance
	var state := GameState.new()
	state.coins = b.start_coins
	state.nanobrew = b.start_nanobrew
	state.cores = b.start_cores
	state.power = b.start_power
	state.seats = b.start_seats
	state.pods = b.start_pods
	state.security = b.start_security
	for i: int in b.start_stoves:
		state.stoves.append(Stove.new())
	state.district_id = b.start_district
	state.suspicion[b.start_district] = 0.0
	state.next_arrival = b.first_arrival_seconds
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	state.rng_seed = rng.seed
	state.rng_state = rng.state
	var starter := state.add_synth(b.starter_species, "", data)
	starter.name = b.starter_name
	starter.role = Synth.SERVER
	return state


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
func add_synth(species_id: String, trait_id: String, data: GameData) -> Synth:
	var synth := Synth.new()
	synth.id = new_id("synth")
	synth.species_id = species_id
	synth.trait_id = trait_id
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


func has_species(species_id: String) -> bool:
	return synths.any(func(synth: Synth) -> bool: return synth.species_id == species_id)


func current_suspicion() -> float:
	return suspicion.get(district_id, 0.0)


func add_suspicion(amount: float) -> void:
	suspicion[district_id] = clampf(current_suspicion() + amount, 0.0, 100.0)
