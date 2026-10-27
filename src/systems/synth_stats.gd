class_name SynthStats
extends RefCounted
## A Synth's effective numbers: species stat + trait modifier, and how well it
## works right now (battery, late shift).


## Species base (or 0 for trait-only stats), grown by level, plus the trait's
## modifier. Max battery starts from the unit's own rolled max.
static func stat(synth: Synth, stat_name: String, data: GameData) -> float:
	var base: float = data.species[synth.species_id].stats.get(stat_name, 0.0)
	if stat_name == "battery_max" and synth.battery_max > 0:
		base = synth.battery_max
	var value: float = base * Leveling.stat_multiplier(synth, stat_name, data.balance)
	if synth.trait_id != "":
		value += data.traits[synth.trait_id].modifiers.get(stat_name, 0.0)
	return value


## Server speed, never below 0.1 so a slow trait cannot stall deliveries.
static func speed(synth: Synth, data: GameData) -> float:
	return maxf(stat(synth, "speed", data), 0.1)


## Battery factor alone: 0 when empty, low_battery_factor when low, else 1.
static func battery_factor(synth: Synth, data: GameData) -> float:
	if synth.battery <= 0.0:
		return 0.0
	if synth.battery < stat(synth, "battery_max", data) * data.balance.low_battery_share:
		return data.balance.low_battery_factor
	return 1.0


## How much of its stats a Synth on duty uses this second (0 = not working).
static func work_factor(synth: Synth, state: GameState, data: GameData) -> float:
	var factor := battery_factor(synth, data)
	if state.shift_time >= data.balance.shift_seconds * data.balance.late_shift_start:
		factor *= maxf(1.0 - stat(synth, "late_shift_slowdown", data), 0.1)
	return factor


## Battery as a whole percentage of max (0..100).
static func battery_percent(synth: Synth, data: GameData) -> int:
	var most := stat(synth, "battery_max", data)
	return clampi(roundi(synth.battery / most * 100.0), 0, 100) if most > 0.0 else 0


static func on_duty(synth: Synth) -> bool:
	return synth.role != Synth.REST
