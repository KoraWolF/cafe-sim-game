class_name Leveling
extends RefCounted
## Synth XP and levels. Levels raise LEVELED_STATS by stat_growth_per_level of
## the species' base per level above 1 (see SynthStats.stat).

## Stats that grow with level. Weaknesses, drain and battery do not.
const LEVELED_STATS: Array[String] = ["speed", "cook", "appeal", "power", "hp"]


## XP needed to go from this level to the next.
static func xp_to_next(level: int, b: BalanceConfig) -> int:
	return b.xp_per_level * level


static func stat_multiplier(synth: Synth, stat_name: String, b: BalanceConfig) -> float:
	if not LEVELED_STATS.has(stat_name):
		return 1.0
	return 1.0 + b.stat_growth_per_level * (synth.level - 1)


## Adds XP and levels up as far as it reaches. At max level XP stops counting.
## Records each level gained in level_ups (synth id -> new level).
static func add_xp(synth: Synth, amount: int, b: BalanceConfig, level_ups: Dictionary[String, int]) -> void:
	if amount <= 0 or synth.level >= b.max_synth_level:
		return
	synth.xp += amount
	while synth.level < b.max_synth_level and synth.xp >= xp_to_next(synth.level, b):
		synth.xp -= xp_to_next(synth.level, b)
		synth.level += 1
		level_ups[synth.id] = synth.level
	if synth.level >= b.max_synth_level:
		synth.xp = 0


## Splits amount between synths (rounded down, at least 1 each).
static func share(synths: Array[Synth], amount: int, b: BalanceConfig, level_ups: Dictionary[String, int]) -> void:
	if synths.is_empty():
		return
	var each := maxi(amount / synths.size(), 1)
	for synth: Synth in synths:
		add_xp(synth, each, b, level_ups)
