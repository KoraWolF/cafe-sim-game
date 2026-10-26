class_name Tutorial
extends RefCounted
## The guided first day: a short list of steps, each with a tip and a goal the
## player has to reach (cook a dish, watch a delivery, convert a starred
## customer, open a Synth card, set the menu, plan a raid, end the night).
## Steps without a goal wait for "Next"; any step can be skipped. A shift step
## still open when the night starts is passed over, so the night steps follow.
## No drawing here: the TutorialBox shows the current step.

## Things the UI reports that the state does not show.
const OPENED_CARD: String = "opened_card"
const SAW_MENU: String = "saw_menu"

var step: int = 0
var finished: bool = false
## Flags the UI sets (OPENED_CARD, SAW_MENU).
var seen: Dictionary[String, bool] = {}
## Each: {"key": text key, "goal": Callable(state, day_log) -> bool or null (wait
## for Next), "when": Callable(state) -> bool or null (show only then), "shift": true
## for steps that only make sense during the shift}.
var _steps: Array[Dictionary] = []


func _init() -> void:
	var has_star := func(state: GameState) -> bool:
		return state.customers.any(func(c: Customer) -> bool: return c.stage == Customer.Stage.STAR)
	var at_night := func(state: GameState) -> bool: return state.phase == GameState.Phase.NIGHT
	_steps = [
		{"key": "tutorial.welcome", "shift": true},
		{"key": "tutorial.cook", "shift": true, "goal": func(state: GameState, _log: Variant) -> bool:
			return state.stoves.any(func(stove: Stove) -> bool: return not stove.is_idle()) \
				or state.counter.values().any(func(count: int) -> bool: return count > 0)},
		{"key": "tutorial.deliver", "shift": true, "goal": func(_state: GameState, log: Variant) -> bool: return log.served > 0},
		{"key": "tutorial.convert", "shift": true, "when": has_star,
			"goal": func(_state: GameState, log: Variant) -> bool: return log.conversions > 0},
		{"key": "tutorial.card", "shift": true,
			"goal": func(_state: GameState, _log: Variant) -> bool: return seen.get(OPENED_CARD, false)},
		{"key": "tutorial.night", "when": at_night},
		{"key": "tutorial.menu", "when": at_night,
			"goal": func(_state: GameState, _log: Variant) -> bool: return seen.get(SAW_MENU, false)},
		{"key": "tutorial.raid", "when": at_night,
			"goal": func(state: GameState, _log: Variant) -> bool: return state.raid_target != ""},
		{"key": "tutorial.end_night", "goal": func(state: GameState, _log: Variant) -> bool: return state.day >= 2},
		{"key": "tutorial.done"},
	]


func step_count() -> int:
	return _steps.size()


## The current tip's translation key, or "" when nothing should show now.
func text_key(state: GameState) -> String:
	if finished:
		return ""
	var when: Variant = _steps[step].get("when")
	if when != null and not (when as Callable).call(state):
		return ""
	return _steps[step]["key"]


## True when the current step waits for the player to press Next.
func waits_for_next() -> bool:
	return not finished and _steps[step].get("goal") == null


## Moves on past every reached goal (and missed shift steps at night).
## Returns true if the step changed.
func update(state: GameState, day_log: Variant) -> bool:
	var moved := false
	while not finished:
		var current := _steps[step]
		var missed: bool = current.get("shift", false) and state.phase == GameState.Phase.NIGHT
		var goal: Variant = current.get("goal")
		var reached: bool = goal != null and text_key(state) != "" and (goal as Callable).call(state, day_log)
		if not missed and not reached:
			break
		_advance()
		moved = true
	return moved


## "Next" on a step without a goal, or skipping one the player doesn't want to do.
func next() -> void:
	if not finished:
		_advance()


func skip_all() -> void:
	finished = true


func _advance() -> void:
	step += 1
	if step >= _steps.size():
		finished = true
		step = _steps.size() - 1
