class_name Species
extends RefCounted
## A Synth species: base stats, the role a new Synth of it starts in and the
## range its max battery is rolled in.


## Stat names and their value when a species leaves them out.
## speed: server delivery speed; cook: added to kitchen speed as chef; appeal:
## Cashier arrival bonus; power/hp: combat; drain: battery per second on duty;
## break_chance: per delivery; glitch_chance: per second as chef;
## late_shift_slowdown: speed lost late in the shift (negative = faster);
## recharge_multiplier: Energy cost of recharging; battery_max: only for Synths
## from saves made before each unit rolled its own max (see battery_range).
const STAT_DEFAULTS: Dictionary[String, float] = {
	"speed": 1.0, "cook": 0.0, "appeal": 0.0, "power": 0.0, "hp": 1.0, "battery_max": 100.0, "drain": 0.0,
	"break_chance": 0.0, "glitch_chance": 0.0, "late_shift_slowdown": 0.0, "recharge_multiplier": 1.0,
}

var id: String = ""
var best_role: String = Synth.SERVER
## Each new unit of this species rolls its max battery in [x, y].
var battery_range: Vector2i = Vector2i(70, 200)
var stats: Dictionary[String, float] = {}


static func from_dict(values: Dictionary) -> Species:
	var species := Species.new()
	species.id = values.get("id", "")
	species.best_role = values.get("best_role", Synth.SERVER)
	var range_values: Variant = values.get("battery_range", [])
	if range_values is Array and range_values.size() == 2:
		species.battery_range = Vector2i(int(range_values[0]), int(range_values[1]))
	species.stats = STAT_DEFAULTS.duplicate()
	var given: Dictionary = values.get("stats", {})
	for stat: String in given:
		if STAT_DEFAULTS.has(stat):
			species.stats[stat] = float(given[stat])
		else:
			push_error("Species %s: unknown stat '%s'" % [species.id, stat])
	return species


## Rolls a max battery for a new unit of this species.
func roll_battery_max(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(battery_range.x, battery_range.y)
