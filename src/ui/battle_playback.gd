class_name BattlePlayback
extends RefCounted
## Replays a Battle.Report at any moment of its timeline. Battle.run leaves each
## fighter at its final HP; this rebuilds every unit's state from the events, so
## the view can show any time and always ends where the recorded result did.
##
## unit_state() is the hook for art: it says where a unit stands, its HP, mana
## and shield, which animation it is in ("idle", "move", "attack", "cast",
## "hurt", "down") and for how long, and which way it faces. Placeholder shapes
## draw from it today; sprites or models can read the same fields later.

## How long each one-off animation lasts (seconds of battle time).
const ANIM_SECONDS: Dictionary[String, float] = {"attack": 0.35, "cast": 0.6, "hurt": 0.25}
## How long a damage or heal number floats after it lands.
const NUMBER_SECONDS: float = 0.8

var report: Battle.Report
## Events per unit: key "a3" / "d0" -> that unit's events, in time order.
var _by_unit: Dictionary[String, Array] = {}


func _init(battle: Battle.Report) -> void:
	report = battle
	for event: Battle.Event in report.events:
		var key := _key(event.side, event.index)
		if not _by_unit.has(key):
			_by_unit[key] = []
		_by_unit[key].append(event)


func duration() -> float:
	return report.duration


func is_finished(time: float) -> bool:
	return time >= report.duration


## Everything about one unit at a moment of the battle:
## {"pos": board position (cells, fractional while walking), "hp", "max_hp",
## "mana", "max_mana", "shield", "anim", "anim_time", "facing": direction on the
## board, "stunned": bool}.
func unit_state(side: bool, index: int, time: float) -> Dictionary:
	var fighter := report.fighter(side, index)
	var state := {"pos": Vector2(fighter.cell), "hp": fighter.max_hp, "max_hp": fighter.max_hp, "mana": 0.0,
		"max_mana": 0.0, "shield": 0.0, "anim": "idle", "anim_time": time, "facing": Vector2(0, -1 if side else 1),
		"stunned": false}
	state["max_mana"] = fighter.max_mana
	var last_one_off: Battle.Event = null
	var stunned_until := -1.0
	for event: Battle.Event in _by_unit.get(_key(side, index), []):
		if event.time > time:
			break
		match event.kind:
			Battle.Event.MOVE:
				var share := clampf((time - event.time) / maxf(event.amount, 0.01), 0.0, 1.0)
				state["pos"] = Vector2(event.from).lerp(Vector2(event.to), share)
				state["facing"] = Vector2(event.to - event.from).normalized()
				if share < 1.0:
					state["anim"] = "move"
					state["anim_time"] = time - event.time
			Battle.Event.HIT:
				state["hp"] = maxf(float(state["hp"]) - event.amount, 0.0)
				state["shield"] = maxf(float(state["shield"]) - event.absorbed, 0.0)
				last_one_off = event
			Battle.Event.HEAL:
				state["hp"] = minf(float(state["hp"]) + event.amount, fighter.max_hp)
			Battle.Event.SHIELD:
				state["shield"] = event.amount
			Battle.Event.STUN:
				stunned_until = event.time + event.amount
			Battle.Event.ATTACK, Battle.Event.CAST:
				last_one_off = event
				if event.other_index >= 0:
					var target := unit_position(event.other_side, event.other_index, event.time)
					var towards := target - Vector2(state["pos"])
					if towards.length() > 0.01:
						state["facing"] = towards.normalized()
			Battle.Event.DOWN:
				state["anim"] = "down"
				state["anim_time"] = time - event.time
				return state
		if event.kind != Battle.Event.HIT and event.kind != Battle.Event.MOVE:
			state["mana"] = event.mana
	state["stunned"] = time < stunned_until
	if last_one_off != null:
		var anim := {Battle.Event.ATTACK: "attack", Battle.Event.CAST: "cast", Battle.Event.HIT: "hurt"}[last_one_off.kind] as String
		if time - last_one_off.time < ANIM_SECONDS[anim] and state["anim"] != "move":
			state["anim"] = anim
			state["anim_time"] = time - last_one_off.time
	return state


## Where a unit stands at a moment (board cells).
func unit_position(side: bool, index: int, time: float) -> Vector2:
	var at := Vector2(report.fighter(side, index).cell)
	for event: Battle.Event in _by_unit.get(_key(side, index), []):
		if event.time > time:
			break
		if event.kind == Battle.Event.MOVE:
			at = Vector2(event.from).lerp(Vector2(event.to), clampf((time - event.time) / maxf(event.amount, 0.01), 0.0, 1.0))
	return at


## Damage and healing numbers still floating at a moment: [event, seconds since].
func numbers(time: float) -> Array[Array]:
	var result: Array[Array] = []
	for event: Battle.Event in report.events:
		if event.time > time:
			break
		if (event.kind == Battle.Event.HIT or event.kind == Battle.Event.HEAL) and time - event.time < NUMBER_SECONDS:
			result.append([event, time - event.time])
	return result


## Attacks in flight at a moment (for ranged shots): [attack event, share of the flight 0..1].
func shots(time: float, flight: float) -> Array[Array]:
	var result: Array[Array] = []
	for event: Battle.Event in report.events:
		if event.time > time:
			break
		if event.kind == Battle.Event.ATTACK and time - event.time < flight:
			result.append([event, (time - event.time) / flight])
	return result


## Events between two moments (from excluded), for sounds.
func events_between(from: float, to: float) -> Array[Battle.Event]:
	var result: Array[Battle.Event] = []
	for event: Battle.Event in report.events:
		if event.time > to:
			break
		if event.time > from:
			result.append(event)
	return result


static func _key(side: bool, index: int) -> String:
	return ("a" if side else "d") + str(index)
