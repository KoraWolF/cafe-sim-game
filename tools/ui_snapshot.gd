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
	await _frames(2)
	print("CHECK cooking -> tutorial moves to the delivery step: ", game.tutorial_box._text.text == tr("tutorial.deliver"))
	_session.advance(70)
	await _frames(2)
	_shot("02_shift_with_pops")
	var view_width: float = game.hud.get_viewport_rect().size.x
	var buttons_fit: bool = game.hud.bar.find_children("*", "Button", true, false).all(func(b: Button) -> bool:
		return b.get_global_rect().end.x <= view_width + 0.5)
	print("CHECK top bar fits: two rows within %d px, every button on screen: %s" % [UiTheme.TOP_BAR_HEIGHT,
		game.hud.bar.size.y <= UiTheme.TOP_BAR_HEIGHT + 0.5 and buttons_fit])

	# Real clicks through the window, as a player would make them.
	var canvas: Transform2D = game.cafe.get_viewport().get_canvas_transform()
	await _click(canvas * game.cafe._heads[state.synths[0].id])
	print("CHECK click Synth -> card open: ", game.hud._card.visible)
	_shot("03_synth_card")
	# Rename: the name is locked until the pencil is clicked, then type, as a player would.
	print("CHECK name locked before the pencil: ", not game.hud._card._title.editable)
	await _click(_centre_of(game.hud._card._edit))
	await _type("Barista\n")
	print("CHECK typing a name -> Synth renamed: ", state.synths[0].name == "Barista")
	# Details: a real click opens the window; dragging its title moves it; tabs work.
	await _click(_centre_of(game.hud._card.find_children("*", "Button", true, false).filter(
		func(b: Button) -> bool: return b.text == tr("ui.details"))[0]))
	print("CHECK Details -> window open: ", game.hud.details.visible and game.hud.details.synth_id == state.synths[0].id)
	_shot("03b_details_work")
	var before: Vector2 = game.hud.details.position
	await _drag_by(_centre_of(game.hud.details._title), Vector2(-150, 60))
	print("CHECK drag the title -> window moved: ", game.hud.details.position.distance_to(before + Vector2(-150, 60)) < 2.0)
	game.hud.details._tabs.current_tab = 1
	await _frames(2)
	_shot("03c_details_fight")
	game.hud.details.visible = false
	await _click(_centre_of(game.hud.info_button))
	print("CHECK Info button -> info open: ", game.hud.info.visible)
	_shot("03d_info")
	game.hud.info.hide_modal()
	# Jobs by place: with the worker picked (its card open), click a stove, then a counter.
	var picked: Synth = state.synths[0]
	print("CHECK clicking a worker picks it for a job: ", game.cafe.selected_synth == picked.id)
	while picked.is_busy():
		_session.advance(1)  # a worker mid-trip finishes it before changing jobs
	await _frames(2)
	var canvas_job: Transform2D = game.cafe.get_viewport().get_canvas_transform()
	var the_stove := Layout.placed_by_uid(state, state.stoves[0].piece_uid)
	state.stoves[0].recipe_id = ""
	state.stoves[0].ready = 0
	# Click the stove's top face (pieces are clicked by their drawn shape).
	await _click(canvas_job * (Iso.centre(the_stove.cell, Vector2i.ONE) - Vector2(0, game.cafe.HEIGHTS["stove"])))
	print("CHECK then a stove's top -> Chef at that stove: ", picked.role == Synth.CHEF and picked.station_uid == the_stove.uid)
	print("CHECK an idle stove opens its dish menu: ", game.hud._recipe_menu.visible)
	_shot("03a_job_chef")
	game.hud._recipe_menu.hide()
	await _frames(2)
	var a_counter: PlacedPiece = state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "counter")[0]
	await _click(canvas_job * Iso.centre(a_counter.cell, Vector2i.ONE))
	print("CHECK then a counter -> Server again: ", picked.role == Synth.SERVER)
	# Another worker's head switches to them; empty floor closes the card.
	var other: Synth = state.synths[1]
	await _frames(2)
	await _click(canvas_job * game.cafe._heads[other.id])
	print("CHECK click another worker -> switched: ", game.cafe.selected_synth == other.id and game.hud._card.synth_id == other.id)
	var empty := Vector2i(-1, -1)
	for y: int in state.floor_rows:
		for x: int in state.floor_width:
			if empty.x < 0 and Layout.piece_at(state, Vector2i(x, y), data) == null and y > 2 and game.cafe.piece_at_point(
					Iso.centre(Vector2i(x, y), Vector2i.ONE)) == null:
				empty = Vector2i(x, y)
	await _click(canvas_job * Iso.centre(empty, Vector2i.ONE))
	print("CHECK click empty floor -> card closed: ", not game.hud._card.visible and game.cafe.selected_synth == "")
	await _frames(2)
	# Bag: click the Neon Cap's card, Wear on the first worker; a Details slot opens its picker;
	# craft in the Workshop (the new piece is selected) and sell it from its detail box.
	var worker: Synth = state.synths[0]
	await _click(_centre_of(game.hud.bag_button))
	game.bag.tabs.current_tab = 1
	await _frames(2)
	await _click(_centre_of(_button_with(game.bag, UiText.item_name(state.inventory.filter(
		func(i: Item) -> bool: return i.type_id == "neon_cap")[0]))))
	print("CHECK Bag card -> detail with Wear: ", game.bag.selected != "" and _button_with(game.bag, tr("ui.bag_wear_on")) != null)
	await _click(_centre_of(_button_with(game.bag, tr("ui.bag_wear_on"))))
	print("CHECK Wear on -> hat on the first worker: ", Items.worn(worker, "hat", data) != null)
	_shot("03e_bag_fashion")
	state.scrap = 10
	game.bag.close()
	await _click(_centre_of(game.hud.shop_button))
	game.shop.tabs.current_tab = game.shop.TABS.find("workshop")
	await _frames(2)
	var owned := state.inventory.size()
	await _click(_centre_of(_button_with(game.shop, tr("ui.craft"))))
	await _frames(2)
	var crafted: Item = state.inventory[-1]
	print("CHECK Shop Workshop Craft -> new piece in the Bag: ", state.inventory.size() == owned + 1 and state.scrap == 5)
	_shot("03f_shop_workshop")
	game.shop.close()
	await _click(_centre_of(game.hud.bag_button))
	game.bag.tabs.current_tab = 0
	await _frames(2)
	await _click(_centre_of(_button_with(game.bag, UiText.item_name(crafted))))
	var coins_before := state.coins
	await _click(_centre_of(_button_with(game.bag, tr("ui.sell") % int(data.items.tiers[crafted.tier]["sell"]))))
	print("CHECK Sell -> coins for its tier: ", state.coins == coins_before + int(data.items.tiers[crafted.tier]["sell"]))
	game.bag.close()
	game.hud.details.open(worker.id)
	game.hud.details._tabs.current_tab = 3
	await _frames(2)
	await _click(_centre_of(game.hud.details.slot_boxes["hat"]))
	print("CHECK Details slot -> picker open: ", game.hud.details._picker.visible)
	_shot("03g_slot_picker")
	game.hud.details._picker.hide()
	game.hud.details.visible = false
	await _frames(2)
	# A finished daily quest is claimed from the tracker at the top left.
	# Finish the LAST daily that can be finished, so claiming the wrong one (the first) fails the check.
	var daily: Dictionary = {}
	for quest: Dictionary in state.daily_quests:
		var start: Variant = quest["start"]
		quest["start"] = -100000  # counts as done (a Vibe quest does not use it)
		if Quests.daily_progress(state, quest, data)[0] >= int(quest["target"]):
			daily = quest
		quest["start"] = start
	daily["start"] = -100000
	_session.state_changed.emit()
	await _frames(2)
	var coins_daily := state.coins
	await _click(_centre_of(_button_with(game.hud._tracker, tr("ui.quests_claim"))))
	print("CHECK Claim on the top-left tracker -> daily claimed: ", daily["claimed"])
	_shot("03g0_tracker_claim")
	# Quests from the top bar, mid-shift: three dailies; a finished achievement is claimed by a real click.
	state.stats["served"] = 100
	_session.state_changed.emit()
	await _click(_centre_of(game.hud.quests_button))
	print("CHECK Quests button mid-shift -> panel open with 3 dailies: ", game.quests.visible
		and state.daily_quests.size() == 3 and state.phase == GameState.Phase.SHIFT)
	_shot("03g_quests_daily")
	game.quests.tabs.current_tab = 2
	await _frames(2)
	var coins_now := state.coins
	await _click(_centre_of(_button_with(game.quests, tr("ui.quests_claim"))))
	print("CHECK Claim -> achievement reward: ", state.achievements.has("served_100") and state.coins == coins_now + 100)
	_shot("03h_quests_achievements")
	game.quests.close()
	await _frames(2)
	# Nobody walks through furniture: watch a few seconds of walking at 4x.
	_session.set_speed(4)
	var through := 0
	for frame: int in 180:
		await _frames(1)
		for customer: Customer in state.customers:
			if not game.cafe._walk.has(customer.id):
				continue
			var at: Vector2 = game.cafe._walk[customer.id]
			var piece := Layout.piece_at(state, Vector2i(floori(at.x), floori(at.y)), data)
			if piece != null and piece.uid != customer.seat_uid:
				through += 1
	_session.set_speed(0)
	print("CHECK customers walk round the furniture (%d frames on a piece): %s" % [through, through == 0])
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
	await _click(game.cafe.get_viewport().get_canvas_transform() * (Iso.centre(stove.cell, Vector2i.ONE) - Vector2(0, game.cafe.HEIGHTS["stove"])))
	print("CHECK click stove -> recipe menu open: ", game.hud._recipe_menu.visible)
	_shot("04_recipe_menu")
	game.hud._recipe_menu.hide()

	# Any customer converts: wait for one who is seated, then click them.
	while state.customers.all(func(c: Customer) -> bool: return not c.is_seated()):
		_session.advance(1)
	state.nanobrew = 1
	var star: Customer = state.customers.filter(func(c: Customer) -> bool: return c.is_seated())[0]
	await _frames(90)  # let them walk to their seat
	var synths_before := state.synths.size()
	await _click(game.cafe.get_viewport().get_canvas_transform() * game.cafe._heads[star.id])
	print("CHECK click a seated customer (no star) -> NanoBrew confirmation shown: ", game.hud.confirm.visible)
	_shot("04b_confirm_nanobrew")
	await _click(_centre_of(game.hud.confirm._yes))
	print("CHECK confirm -> converted: ", state.synths.size() == synths_before + 1,
		" (star stage now %s, pods %d, synths %d, nanobrew %d)" % [star.stage, state.pods, state.synths.size(), state.nanobrew])
	var newcomer: Synth = state.synths[-1]
	print("CHECK new Synth rests at 70%% battery and walks to its Pod: ", newcomer.role == Synth.REST
		and SynthStats.battery_percent(newcomer, data) == 70 and game.cafe._to_pod.has(newcomer.id))
	# Walking from the pay line or the street round the front takes a few seconds.
	for wait: int in 60:
		if not game.cafe._to_pod.has(newcomer.id):
			break
		await _frames(20)
	print("CHECK ...and reaches it: ", not game.cafe._to_pod.has(newcomer.id))
	_shot("04c_new_synth_in_pod")
	print("CHECK Auto locked on day 1: ", game.hud._auto.disabled)
	# A customer walking out can still be clicked on the way.
	while state.leaving.is_empty() and state.phase == GameState.Phase.SHIFT:
		_session.advance(1)
	await _frames(20)
	var leaver: Customer = state.leaving[0]
	state.nanobrew = 1
	state.pods = state.synths.size() + 1
	if game.cafe._heads.has(leaver.id):
		await _click(game.cafe.get_viewport().get_canvas_transform() * game.cafe._heads[leaver.id])
	print("CHECK click a customer walking out -> NanoBrew confirmation shown: ", game.hud.confirm.visible)
	_shot("04c2_convert_leaver")
	game.hud.confirm._answer(false)
	await _frames(2)

	# Throwing food away: click a counter with food, confirm, a server takes it to the bin.
	var full: PlacedPiece = null
	for placed: PlacedPiece in state.placed:
		if state.counter_count.get(placed.uid, 0) > 0:
			full = placed
	if full == null:
		full = state.placed.filter(func(p: PlacedPiece) -> bool: return p.piece_id == "counter")[0]
		Counters.put(state, full.uid, "coffee", 2)
	await _click(game.cafe.get_viewport().get_canvas_transform() * (Iso.centre(full.cell, Vector2i.ONE) - Vector2(0, game.cafe.HEIGHTS["counter"])))
	print("CHECK click counter -> throw-away confirmation shown: ", game.hud.confirm.visible)
	_shot("04d_confirm_throw")
	await _click(_centre_of(game.hud.confirm._yes))
	print("CHECK confirm -> marked for the bin: ", state.discard.has(full.uid))
	for second: int in 10:
		if state.counter_count.get(full.uid, 0) == 0:
			break
		_session.advance(1)
	print("CHECK a server emptied it: ", state.counter_count.get(full.uid, 0) == 0 and not state.discard.has(full.uid))

	# Building mid-shift: the round Shop button and Arrange on the top bar work while the café runs.
	state.coins = 2000
	await _click(_centre_of(game.hud.shop_button))
	print("CHECK Shop button mid-shift -> shop open: ", game.shop.visible and state.phase == GameState.Phase.SHIFT)
	game.shop.tabs.current_tab = 0
	await _frames(2)
	_shot("04e_shop_mid_shift")
	# Furniture: Buy puts it in your hand in Arrange; Store keeps it for later.
	var stored_seats: int = state.storage.get("seat", 0)
	await _click(_centre_of(_button_with(game.shop, tr("ui.buy_store"))))
	print("CHECK Store (the first piece, a seat) -> in storage: ", state.storage.get("seat", 0) == stored_seats + 1)
	var seat_row_buy: Button = null
	for button: Button in game.shop.find_children("*", "Button", true, false):
		var card := button.get_parent().get_parent()  # a card: swatch, name, details, buttons
		if button.is_visible_in_tree() and button.text == tr("ui.buy_place") % data.pieces["seat"].price 				and card.get_child_count() > 1 and card.get_child(1) is Label and (card.get_child(1) as Label).text == UiText.name("seat"):
			seat_row_buy = button
	await _click(_centre_of(seat_row_buy))
	await _frames(2)
	print("CHECK the Buy click doesn't also land on the floor: ", not game.hud._toasts.get_children().any(
		func(n: Node) -> bool: return n is Label and [UiText.error(GameLoop.OVERLAP), UiText.error(GameLoop.OUT_OF_BOUNDS)].has((n as Label).text)))
	print("CHECK Buy a seat mid-shift -> Arrange opens holding it: ", game.cafe.editor != null
		and game.cafe.editor.held_piece == "seat" and not game.shop.visible)
	_shot("04f_buy_holding_seat")
	var seat_spot := Layout.find_spot(state, "seat", data)
	var seats_placed := Layout.count_placed_id(state, "seat")
	await _click(game.cafe.get_viewport().get_canvas_transform() * Iso.centre(seat_spot["cell"], Vector2i.ONE))
	await _frames(3)
	print("CHECK place the bought seat -> back in the Shop: ", Layout.count_placed_id(state, "seat") == seats_placed + 1
		and game.cafe.editor == null and game.shop.visible)
	await _click(_centre_of(game.hud.arrange_button))
	print("CHECK Arrange mid-shift -> editing, shop closed: ", game.cafe.editor != null and not game.shop.visible)
	game.edit_panel.done.emit()
	await _frames(3)
	print("CHECK Done mid-shift -> no night hub: ", game.cafe.editor == null and not game.night.visible)

	# Play the rest of the shift, cooking for demand and converting stars.
	while state.phase == GameState.Phase.SHIFT:
		for i: int in state.stoves.size():
			if state.stoves[i].is_idle():
				GameLoop.start_cooking(state, i, ["coffee", "toast"][i % 2], data)
		var events: Shift.Events = _session.advance(1)
		for customer_id: String in events.starred:
			if state.convertible_by_id(customer_id) != null:
				_session.convert_customer(customer_id)
		if state.shift_time == 300:
			await _frames(3)
			_shot("05_busy_shift")
	await _frames(5)
	for tab: int in game.night._tabs.get_tab_count():
		game.night._tabs.current_tab = tab
		await _frames(3)
		_shot("06_night_tab_%d" % tab)

	# Arranging the floor with real mouse input.
	state.coins = 1000
	GameLoop.buy_piece(state, "potted_fern", data)
	_session.auto_place("potted_fern")
	GameLoop.buy_piece(state, "bubble_lamp", data)
	_session.state_changed.emit()
	game.enter_edit()
	await _frames(3)
	_shot("09_edit_mode")
	var fern: PlacedPiece = state.placed[-1]
	var canvas_edit: Transform2D = game.cafe.get_viewport().get_canvas_transform()
	# Its top, as a player sees it (a taller counter beside it hides part of its floor tile).
	await _click(canvas_edit * (Iso.centre(fern.cell, Vector2i.ONE) - Vector2(0, game.cafe.HEIGHTS["decor"] + 4)))
	print("CHECK click fern -> holding it: ", game.cafe.editor.held_uid == fern.uid)
	await _move(canvas_edit * Iso.centre(Vector2i(4, 5), Vector2i.ONE))
	_shot("10_moving_fern")
	await _click(canvas_edit * Iso.centre(Vector2i(4, 5), Vector2i.ONE))
	print("CHECK drop fern -> moved to (4, 5): ", fern.cell == Vector2i(4, 5))
	game.edit_panel._take("bubble_lamp")
	await _move(canvas_edit * Iso.centre(Vector2i(3, 5), Vector2i.ONE))
	_shot("11_lamp_next_to_fern")
	var vibe_before := state.vibe
	var promised: float = game.cafe.editor.preview(state, Vector2i(3, 5), data)["delta"]
	await _click(canvas_edit * Iso.centre(Vector2i(3, 5), Vector2i.ONE))
	print("CHECK drop lamp beside fern -> Vibe change %+d, as the ghost showed (%+d): %s" % [
		roundi(state.vibe - vibe_before), roundi(promised), state.vibe - vibe_before == promised])
	# Cancel puts back what is held.
	print("CHECK Arrange has a Cancel button: ", game.edit_panel._cancel.text == tr("ui.edit_cancel") and tr("ui.edit_cancel") == "Cancel")
	# Select several: click the fern and the lamp, Store selected, confirm -> both in storage.
	await _click(_centre_of(game.edit_panel._select))
	var lamp: PlacedPiece = state.placed[-1]
	for piece: PlacedPiece in [fern, lamp]:
		await _click(canvas_edit * (Iso.centre(piece.cell, Vector2i.ONE) - Vector2(0, game.cafe.HEIGHTS["decor"] + 4)))
	print("CHECK Select several -> 2 pieces selected: ", game.cafe.editor.selected.size() == 2)
	_shot("11c_select_several")
	await _click(_centre_of(game.edit_panel._store_selected))
	print("CHECK Store selected asks first: ", game.edit_panel._confirm.visible)
	await _click(_centre_of(game.edit_panel._confirm._yes))
	print("CHECK confirm -> both stored: ", state.storage.get("potted_fern", 0) >= 1 and state.storage.get("bubble_lamp", 0) >= 1
		and game.cafe.editor.selected.is_empty())
	await _click(_centre_of(game.edit_panel._select))
	await _move(canvas_edit * Iso.centre(Vector2i(0, 0), Vector2i.ONE))
	game.edit_panel.done.emit()
	await _frames(3)
	print("CHECK Done -> back to the night hub: ", game.night.visible and not game.edit_panel.visible)

	var raider := state.synths[-1]
	GameLoop.plan_raid(state, "megabean_kiosk", [raider.id] as Array[String], data)
	_session.state_changed.emit()
	game.night._tabs.current_tab = 2
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


## The first visible button under a control whose text starts with text.
func _button_with(under: Node, text: String) -> Button:
	for button: Button in under.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.text.begins_with(text):
			return button
	push_error("no button '%s'" % text)
	return null


func _centre_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## A left click at a screen position, through the window's input.
func _click(at: Vector2) -> void:
	# Press and release in the same frame: a real mouse move from the OS cursor
	# landing in between would turn the click into a drag (or move it off a button).
	# at is in game (viewport) pixels; input arrives in window pixels, which differ
	# when the window is scaled to fit the screen.
	var window_at := root.get_final_transform() * at
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = window_at
		event.global_position = window_at
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


## Presses at from, moves by delta in two steps, releases (a real mouse drag).
func _drag_by(from: Vector2, delta: Vector2) -> void:
	var transform := root.get_final_transform()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = transform * from
	press.global_position = press.position
	root.push_input(press)
	await _frames(1)
	for step: int in 2:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = transform * (from + delta * (step + 1) / 2.0)
		motion.global_position = motion.position
		motion.relative = transform.basis_xform(delta / 2.0)
		root.push_input(motion)
		await _frames(1)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.position = transform * (from + delta)
	release.global_position = release.position
	root.push_input(release)
	await _frames(2)


func _move(to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform() * to
	event.global_position = event.position
	root.push_input(event)
	await _frames(2)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _shot(name: String) -> void:
	var path := _out.path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
