class_name SynthTrait
extends RefCounted
## A trait rolled at conversion: amounts added to the species' stats.

## Trait-only stats (all 0 without a trait). tip: added to the tip multiplier
## of dishes this Synth serves; satisfaction: added when this Synth serves;
## raid_loot: added to the raid loot multiplier; steal_chance: nightly chance
## to pocket steal_coins.
const EXTRA_STATS: Array[String] = ["tip", "satisfaction", "raid_loot", "steal_chance"]

var id: String = ""
var modifiers: Dictionary[String, float] = {}


static func from_dict(values: Dictionary) -> SynthTrait:
	var synth_trait := SynthTrait.new()
	synth_trait.id = values.get("id", "")
	var given: Dictionary = values.get("modifiers", {})
	for stat: String in given:
		if Species.STAT_DEFAULTS.has(stat) or EXTRA_STATS.has(stat):
			synth_trait.modifiers[stat] = float(given[stat])
		else:
			push_error("SynthTrait %s: unknown stat '%s'" % [synth_trait.id, stat])
	return synth_trait
