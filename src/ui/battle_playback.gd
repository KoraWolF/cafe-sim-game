class_name BattlePlayback
extends RefCounted
## Replays a Battle.Report hit by hit. Battle.run leaves each fighter at its
## final HP; this rebuilds the fight from full HP so the view can show every
## step, and always ends exactly where the recorded result did.

## Seconds per hit at 1x speed.
const HIT_SECONDS: float = 0.55

var report: Battle.Report
## HP after the hits applied so far; same order as report.attackers / defenders.
var attacker_hp: Array[float] = []
var defender_hp: Array[float] = []
## Hits applied so far.
var applied: int = 0


func _init(battle: Battle.Report) -> void:
	report = battle
	reset()


func reset() -> void:
	attacker_hp.assign(report.attackers.map(func(fighter: Battle.Fighter) -> float: return fighter.max_hp))
	defender_hp.assign(report.defenders.map(func(fighter: Battle.Fighter) -> float: return fighter.max_hp))
	applied = 0


func hit_count() -> int:
	return report.hits.size()


func is_finished() -> bool:
	return applied >= hit_count()


func duration() -> float:
	return hit_count() * HIT_SECONDS


## Applies hits until `count` have been applied (it never goes back).
func advance_to(count: int) -> void:
	count = mini(count, hit_count())
	while applied < count:
		var hit := report.hits[applied]
		var targets := defender_hp if hit.attacker_side else attacker_hp
		targets[hit.target_index] = maxf(targets[hit.target_index] - hit.damage, 0.0)
		applied += 1


## Applies the hits that fit in `seconds` of playback.
func advance_time(seconds: float) -> void:
	advance_to(floori(seconds / HIT_SECONDS))


func finish() -> void:
	advance_to(hit_count())


## The hit being played at `seconds` and how far through it (0..1), or {} when done.
func current(seconds: float) -> Dictionary:
	var index := floori(seconds / HIT_SECONDS)
	if index >= hit_count():
		return {}
	return {"hit": report.hits[index], "progress": fmod(seconds, HIT_SECONDS) / HIT_SECONDS}


func round_at(seconds: float) -> int:
	var index := mini(floori(seconds / HIT_SECONDS), hit_count() - 1)
	return report.hits[index].round_number if index >= 0 else 0
