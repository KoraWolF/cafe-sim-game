extends Node
## Autoload "Session": the running game as the UI sees it. Holds the content
## and the GameState, passes real time to GameLoop.advance at the chosen speed,
## autosaves on safe boundaries, and turns action results into signals and
## toasts. Screens call act() with a GameLoop result so errors show the same way.


class DayLog:
	extends RefCounted
	var served: int = 0
	var stars: int = 0
	var angry: int = 0
	var turned_away: int = 0
	var coins: int = 0
	var tips: int = 0
	var conversions: int = 0
	var broken: int = 0
	var glitches: int = 0

	func add(events: Shift.Events) -> void:
		served += events.served.size()
		stars += events.starred.size()
		angry += events.left_angry.size()
		turned_away += events.turned_away
		coins += events.coins_earned + events.tips_earned
		tips += events.tips_earned
		broken += events.dishes_broken
		glitches += events.glitches


## Something in the state changed outside of time passing (an action).
signal state_changed
## Time passed in a shift.
signal shift_advanced(events: Shift.Events)
## Shift or night ended; check state.phase.
signal phase_changed
signal night_resolved(report: NightOps.Report)
## A short message for the player (errors, events).
signal toast(text: String)
## A starred customer became a Synth (for the burst effect and sound).
signal converted(customer_id: String, synth: Synth)

var data: GameData
var state: GameState
var day_log := DayLog.new()
## Pause menu open: time stops without touching state.speed.
var paused: bool = false
## Arranging the floor: keys go to the floor editor, not the HUD.
var editing: bool = false
## True while a night is being passed by Auto (the game screen skips the report
## unless there was a fight).
var auto_running: bool = false
## Synth id -> name, taken just before the night resolves, so a Synth the
## Audit takes can still be named in the battle scene.
var synth_names: Dictionary[String, String] = {}
var _carry: float = 0.0


func _ready() -> void:
	data = GameData.load_default()
	RenderingServer.set_default_clear_color(UiTheme.BACKGROUND)


func has_game() -> bool:
	return state != null


func new_game(seed_value := -1) -> void:
	state = GameState.new_game(seed_value if seed_value >= 0 else randi(), data)
	refresh_quests()
	day_log = DayLog.new()
	_carry = 0.0
	paused = false
	phase_changed.emit()


## Loads a save (or the autosave for slot -1). Returns the reasons it failed, empty on success.
func load_game(slot: int) -> PackedStringArray:
	var errors: PackedStringArray = []
	var path := SaveSystem.autosave_path() if slot < 0 else SaveSystem.slot_path(slot)
	var loaded := SaveSystem.load_file(path, data, errors)
	if loaded != null:
		state = loaded
		refresh_quests()
		day_log = DayLog.new()
		_carry = 0.0
		paused = false
		phase_changed.emit()
	return errors


## New daily quests when the real-world date has changed.
func refresh_quests() -> void:
	if state != null and Quests.refresh(state, Time.get_date_string_from_system(), data):
		state_changed.emit()


func save_game(slot: int) -> void:
	var error := SaveSystem.save_slot(state, slot)
	toast.emit(tr("ui.saved") % (slot + 1) if error == OK else tr("ui.save_failed") % error)


func set_speed(speed: int) -> void:
	if GameState.SPEEDS.has(speed):
		state.speed = speed
		state_changed.emit()


## Called every frame by the game screen.
func tick(delta: float) -> void:
	if state == null or paused or state.phase != GameState.Phase.SHIFT:
		return
	_carry += delta * state.speed
	var seconds := int(_carry)
	if seconds <= 0:
		return
	_carry -= seconds
	advance(seconds)


## Passes shift seconds (also used by tools and tests).
func advance(seconds: int) -> Shift.Events:
	var events := GameLoop.advance(state, seconds, data)
	day_log.add(events)
	shift_advanced.emit(events)
	for synth_id: String in events.level_ups:
		var synth := state.synth_by_id(synth_id)
		if synth != null:
			toast.emit(tr("ui.level_up") % [synth_name(synth), events.level_ups[synth_id]])
	if events.shift_ended:
		refresh_quests()
		toast.emit(tr("ui.closed_today") if events.closed else tr("ui.shift_over"))
		SaveSystem.autosave(state)
		phase_changed.emit()
		if state.auto_night:
			auto_night.call_deferred()
	return events


## Auto: the night passes by itself with the same menu, no raid and whatever
## recharge the Energy covers (warns when it runs short). Stops for the player
## when a Corporate Audit is coming.
func auto_night() -> void:
	if state == null or state.phase != GameState.Phase.NIGHT or not state.auto_night:
		return
	if GameLoop.auto_stop_reason(state, data) != "":
		toast.emit(tr("ui.auto_stopped_audit"))
		return
	if state.power < NightOps.recharge_cost(state, data):
		toast.emit(tr("ui.auto_low_energy") % [roundi(state.power), ceili(NightOps.recharge_cost(state, data))])
	GameLoop.cancel_raid(state)
	auto_running = true
	end_night()
	auto_running = false


func end_night() -> NightOps.Report:
	synth_names.clear()
	for synth: Synth in state.synths:
		synth_names[synth.id] = synth_name(synth)
	var report := GameLoop.end_night(state, data)
	if report == null:
		return null
	day_log = DayLog.new()
	_carry = 0.0
	SaveSystem.autosave(state)
	night_resolved.emit(report)
	phase_changed.emit()
	return report


## Shows the error of a GameLoop result, or announces the change. True on success.
func act(code: String) -> bool:
	if code != GameLoop.OK:
		toast.emit(UiText.error(code))
		return false
	state_changed.emit()
	return true


func convert_customer(customer_id: String) -> void:
	var created: Array[Synth] = []
	if act(GameLoop.convert_customer(state, customer_id, data, created)):
		day_log.conversions += 1
		converted.emit(customer_id, created[0])
		toast.emit(tr("ui.converted") % [tr("ui.customer"), UiText.name(created[0].species_id)])


## Places a stored piece on the first free spot. False if the floor is full.
func auto_place(piece_id: String) -> bool:
	var spot := Layout.find_spot(state, piece_id, data)
	if spot.is_empty():
		return false
	return GameLoop.place_piece(state, piece_id, spot["cell"], spot["rotated"], data) == GameLoop.OK


func synth_name(synth: Synth) -> String:
	return synth.name if synth.name != "" else "%s #%s" % [UiText.name(synth.species_id), synth.id.get_slice("_", 1)]
