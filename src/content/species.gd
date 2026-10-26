class_name Species
extends RefCounted
## A Synth species: base stats and the role a new Synth of it starts in.

## Stat names and their value when a species leaves them out.
## speed: server delivery speed; cook: added to kitchen speed as chef; appeal:
## greeter arrival bonus; power/hp: combat; drain: battery per second on duty;
## break_chance: per delivery; glitch_chance: per second as chef;
## late_shift_slowdown: speed lost late in the shift (negative = faster);
## recharge_multiplier: Power cost of recharging.
const STAT_DEFAULTS: Dictionary[String, float] = {
	"speed": 1.0, "cook": 0.0, "appeal": 0.0, "power": 0.0, "hp": 1.0, "battery_max": 100.0, "drain": 0.0,
	"break_chance": 0.0, "glitch_chance": 0.0, "late_shift_slowdown": 0.0, "recharge_multiplier": 1.0,
}

var id: String = ""
var best_role: String = Synth.SERVER
var stats: Dictionary[String, float] = {}


static func from_dict(values: Dictionary) -> Species:
	var species := Species.new()
	species.id = values.get("id", "")
	species.best_role = values.get("best_role", Synth.SERVER)
	species.stats = STAT_DEFAULTS.duplicate()
	var given: Dictionary = values.get("stats", {})
	for stat: String in given:
		if STAT_DEFAULTS.has(stat):
			species.stats[stat] = float(given[stat])
		else:
			push_error("Species %s: unknown stat '%s'" % [species.id, stat])
	return species
