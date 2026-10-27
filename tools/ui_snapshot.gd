extends SceneTree
## Plays a scripted day through the real UI and saves a screenshot of each
## screen, for checking the layout without clicking through by hand.
## Usage (needs a window, not --headless):
##   godot --path . --resolution 1920x1080 -s res://tools/ui_snapshot.gd -- <output folder>

var _out: String = "user://snapshots"
var _session: Node
var _main: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	_session = root.get_node("Session")
	# Silent while it runs; the player's own settings are put back at the end.
	AudioServer.set_bus_mute(0, true)
	var tutorial_was_done := Settings.tutorial_done()
	var music_volume := Settings.volume("Music")
	Settings.set_tutorial_done(false)
	_main = load("res://src/ui/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(10)
	_shot("01_main_menu")

	_session.new_game(7)
	_main.show_game()
	# Time only moves through _session.advance, so checks don't race the clock.
	_session.set_speed(0)
	await _frames(5)
	var game = _main.get_child(0)  # untyped: GameScreen needs the Session autoload, which -s scripts compile before
	var state: GameState = _session.state
	var data: GameData = _session.data
	print("CHECK new game -> guided first day shows its welcome: ",
		game.tutorial_box.visible and game.tutorial_box._text.text == tr("tutorial.welcome"))
	_shot("01b_tutorial_welcome")
	await _click(_centre_of(game.tutorial_box._next))
	await _frames(2)
	print("CHECK Next -> cook step: ", game.tutorial_box._text.text == tr("tutorial.cook"))
	GameLoop.start_cooking(state, 0, "coffee", data)
	GameLoop.start_cooking(state, 1, "toast", data)
	await _frames(2)
	print("CHECK cooking -> tutorial moves to the delivery step: ", game.tutorial_box._text.text == tr("tutorial.deliver"))
	_session.advance(70)
	await _frames(2)
	_shot("02_shift_with_pops")

	# Real clicks through the window, as a player would make them.
	var canvas: Transform2D = game.cafe.get_viewport().get_canvas_transform()
	await _click(canvas * game.cafe._heads[state.synths[0].id])
	print("CHECK click Synth -> card open: ", game.hud._card.visible)
	_shot("03_synth_card")
	# Rename by clicking the name and typing, as a player would.
	await _click(_centre_of(game.hud._card._title))
	game.hud._card._title.select_all()
	await _type("Barista\n")
	print("CHECK typing a name -> Synth renamed: ", state.synths[0].name == "Barista")
	# Customers walk in through the door: give them a few seconds, then everyone seated is at their seat.
	await _frames(300)
	var stuck := 0
	for customer: Customer in state.customers:
		if customer.is_seated() and game.cafe._walk.has(customer.id):
			var seat: PlacedPiece = Layout.placed_by_uid(state, customer.seat_uid)
			if seat != null and game.cafe._walk[customer.id].distance_to(Vector2(seat.cell) + Vector2(0.5, 0.5)) > 0.1:
				stuck += 1
	print("CHECK seated customers walked in to their seats (%d not there): %s" % [stuck, stuck == 0])

	var stove: PlacedPiece = Layout.placed_by_uid(state, state.stoves[0].piece_uid)
	state.stoves[0].recipe_id = ""
	state.stoves[0].ready = 0
	await _click(canvas * Iso.centre(stove.cell, Vector2i(2, 1)))
	print("CHECK click stove -> recipe menu open: ", game.hud._recipe_menu.visible)
	_shot("04_recipe_menu")
	game.hud._recipe_menu.hide()

	while state.customers.all(func(c: Customer) -> bool: return c.stage != Customer.Stage.STAR):
		_session.advance(1)
	await _frames(2)
	state.nanobrew = 1
	var star: Customer = state.customers.filter(func(c: Customer) -> bool: return c.stage == Customer.Stage.STAR)[0]
	var synths_before := state.synths.size()
	await _click(game.cafe.get_viewport().get_canvas_transform() * game.cafe._heads[star.id])
	print("CHECK click starred customer -> NanoBrew confirmation shown: ", game.hud.confirm.visible)
	_shot("04b_confirm_nanobrew")
	await _click(_centre_of(game.hud.confirm._yes))
	print("CHECK confirm -> converted: ", state.synths.size() == synths_before + 1,
		" (star stage now %s, pods %d, synths %d, nanobrew %d)" % [star.stage, state.pods, state.synths.size(), state.nanobrew])

	# Play the rest of the shift, cooking for demand and converting stars.
	while state.phase == GameState.Phase.SHIFT:
		for i: int in state.stoves.size():
			if state.stoves[i].is_idle():
				GameLoop.start_cooking(state, i, state.menu[i % state.menu.size()], data)
		var events: Shift.Events = _session.advance(1)
		for customer_id: String in events.starred:
			_session.convert_customer(customer_id)
		if state.shift_time == 300:
			await _frames(3)
			_shot("05_busy_shift")
	await _frames(5)
	for tab: int in 5:
		game.night._tabs.current_tab = tab
		await _frames(3)
		_shot("06_night_tab_%d" % tab)

	# Arranging the floor with real mouse input.
	state.coins = 1000
	GameLoop.buy_decor(state, "potted_fern", data)
	_session.auto_place("potted_fern")
	GameLoop.buy_decor(state, "bubble_lamp", data)
	_session.state_changed.emit()
	game.enter_edit()
	await _frames(3)
	_shot("09_edit_mode")
	var fern: PlacedPiece = state.placed[-1]
	var canvas_edit: Transform2D = game.cafe.get_viewport().get_canvas_transform()
	await _click(canvas_edit * Iso.centre(fern.cell, Vector2i.ONE))
	print("CHECK click fern -> holding it: ", game.cafe.editor.held_uid == fern.uid)
	await _move(canvas_edit * Iso.centre(Vector2i(5, 4), Vector2i.ONE))
	_shot("10_moving_fern")
	await _click(canvas_edit * Iso.centre(Vector2i(5, 4), Vector2i.ONE))
	print("CHECK drop fern -> moved to (5, 4): ", fern.cell == Vector2i(5, 4))
	game.edit_panel._take("bubble_lamp")
	await _move(canvas_edit * Iso.centre(Vector2i(4, 4), Vector2i.ONE))
	_shot("11_lamp_next_to_fern")
	var vibe_before := state.vibe
	var promised: float = game.cafe.editor.preview(state, Vector2i(4, 4), data)["delta"]
	await _click(canvas_edit * Iso.centre(Vector2i(4, 4), Vector2i.ONE))
	print("CHECK drop lamp beside fern -> Vibe change %+d, as the ghost showed (%+d): %s" % [
		roundi(state.vibe - vibe_before), roundi(promised), state.vibe - vibe_before == promised])
	await _move(canvas_edit * Iso.centre(Vector2i(0, 0), Vector2i.ONE))
	game.edit_panel.done.emit()
	await _frames(3)
	print("CHECK Done -> back to the night hub: ", game.night.visible and not game.edit_panel.visible)

	var raider := state.synths[-1]
	GameLoop.plan_raid(state, "megabean_kiosk", [raider.id] as Array[String], data)
	_session.state_changed.emit()
	game.night._tabs.current_tab = 4
	await _frames(3)
	_shot("07_night_ops_planned")
	# Settings: a real click on the Music slider's left end turns music down, and it is saved.
	game.hud.settings_requested.emit()
	await _frames(2)
	var slider: HSlider = game.settings._sliders["Music"]
	var rect := slider.get_global_rect()
	await _click(Vector2(rect.position.x + 4, rect.get_center().y))
	Settings._config = null
	print("CHECK settings slider -> Music volume saved low: ", Settings.volume("Music") < 0.2)
	_shot("11b_settings")
	Settings.set_volume("Music", music_volume)
	game.settings.close()

	# Suspicion past the Audit line: tonight has a raid and an Audit to watch.
	state.add_suspicion(95.0)
	_session.end_night()
	await _frames(45)
	print("CHECK End Night -> raid battle playing: ", game.battle.visible and not game.report.visible)
	_shot("12_battle_raid")
	await _click(_centre_of(game.battle._skip))
	await _frames(3)
	print("CHECK Skip -> raid finished, Continue shown: ", game.battle.playback.is_finished() and game.battle._continue.visible)
	_shot("13_battle_raid_end")
	await _click(_centre_of(game.battle._continue))
	await _frames(45)
	print("CHECK Continue -> Audit battle playing: ", game.battle.visible and game.battle._title.text == tr("ui.battle_audit"))
	_shot("14_battle_audit")
	await _click(_centre_of(game.battle._skip))
	await _frames(3)
	await _click(_centre_of(game.battle._continue))
	await _frames(5)
	print("CHECK last Continue -> night report shown: ", game.report.visible and not game.battle.visible)
	_shot("15_report")
	Settings.set_tutorial_done(tutorial_was_done)
	quit()


func _centre_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## A left click at a screen position, through the window's input.
func _click(at: Vector2) -> void:
	# Press and release in the same frame: a real mouse move from the OS cursor
	# landing in between would turn the click into a drag (or move it off a button).
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event)
	await _frames(3)


## Types text into whatever has keyboard focus (a line break presses Enter).
func _type(text: String) -> void:
	for character: String in text:
		var event := InputEventKey.new()
		event.pressed = true
		if character == "\n":
			event.keycode = KEY_ENTER
		else:
			event.unicode = character.unicode_at(0)
		root.push_input(event)
		var release := event.duplicate()
		release.pressed = false
		root.push_input(release)
	await _frames(2)


func _move(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = to
	event.global_position = to
	root.push_input(event)
	await _frames(2)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _shot(name: String) -> void:
	var path := _out.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
