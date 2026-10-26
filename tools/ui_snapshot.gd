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
	GameLoop.start_cooking(state, 0, "coffee", data)
	GameLoop.start_cooking(state, 1, "toast", data)
	_session.advance(70)
	await _frames(5)
	_shot("02_shift")

	# Real clicks through the window, as a player would make them.
	var canvas: Transform2D = game.cafe.get_viewport().get_canvas_transform()
	await _click(canvas * game.cafe._heads[state.synths[0].id])
	print("CHECK click Synth -> card open: ", game.hud._card.visible)
	_shot("03_synth_card")

	var stove: PlacedPiece = Layout.placed_by_uid(state, state.stoves[0].piece_uid)
	state.stoves[0].recipe_id = ""
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
	print("CHECK click starred customer -> converted: ", state.synths.size() == synths_before + 1,
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
	_session.end_night()
	await _frames(5)
	_shot("08_report")
	quit()


## A left click at a screen position, through the window's input.
func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event)
		await _frames(1)
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
