class_name Hud
extends Control
## The always-on overlay: resources and day on top, speed buttons, toasts, an
## event feed, the stove recipe picker, the Synth card and the pause menu.

signal quit_to_menu

const FEED_LINES: int = 6
const TOAST_SECONDS: float = 3.0
const MAX_TOASTS: int = 3

var _top := Label.new()
var _resources := Label.new()
var _shift_bar := ProgressBar.new()
var _speed_box := HBoxContainer.new()
var _speed_buttons: Dictionary[int, Button] = {}
var _toasts := VBoxContainer.new()
var _feed := VBoxContainer.new()
var _recipe_menu := PopupMenu.new()
var _recipe_stove: int = -1
var _card := SynthCard.new()
var _pause := PanelContainer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar()
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-300, 90)
	_toasts.custom_minimum_size = Vector2(600, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toasts)
	_feed.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_feed.position = Vector2(16, -200)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)
	add_child(_recipe_menu)
	_recipe_menu.id_pressed.connect(_on_recipe_chosen)
	_card.visible = false
	add_child(_card)
	_build_pause_menu()
	Session.toast.connect(show_toast)
	Session.state_changed.connect(refresh)
	Session.phase_changed.connect(func() -> void:
		_card.visible = false
		refresh())
	Session.shift_advanced.connect(_on_shift_advanced)
	refresh()


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(bar)
	var row := HBoxContainer.new()
	bar.add_child(row)
	_top.add_theme_font_size_override("font_size", 22)
	row.add_child(_top)
	_shift_bar.custom_minimum_size = Vector2(180, 20)
	_shift_bar.show_percentage = false
	_shift_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_shift_bar)
	_resources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_resources)
	row.add_child(_speed_box)
	for speed: int in GameState.SPEEDS:
		var label := tr("ui.speed_pause") if speed == 0 else "%d×" % speed
		var button := UiTheme.button(label, Session.set_speed.bind(speed))
		button.toggle_mode = true
		_speed_buttons[speed] = button
		_speed_box.add_child(button)
	row.add_child(UiTheme.button(tr("ui.menu_button"), toggle_pause))


func _build_pause_menu() -> void:
	_pause.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause.visible = false
	add_child(_pause)
	var column := VBoxContainer.new()
	_pause.add_child(column)
	column.add_child(UiTheme.label(tr("ui.paused"), 28, UiTheme.PANEL_BORDER))
	column.add_child(UiTheme.button(tr("ui.resume"), toggle_pause))
	for slot: int in SaveSystem.SLOTS:
		column.add_child(UiTheme.button(tr("ui.save_slot") % (slot + 1), Session.save_game.bind(slot)))
	column.add_child(UiTheme.button(tr("ui.main_menu"), func() -> void:
		toggle_pause()
		quit_to_menu.emit()))


func toggle_pause() -> void:
	_pause.visible = not _pause.visible
	Session.paused = _pause.visible
	if _pause.visible:
		_pause.reset_size()
		_pause.position = (size - _pause.size) * 0.5


func refresh() -> void:
	if not Session.has_game():
		return
	var state := Session.state
	var data := Session.data
	var shift := data.balance.shift_seconds
	_top.text = "%s   %s" % [tr("ui.day") % state.day, tr("ui.shift_time") % [UiText.clock(state.shift_time), UiText.clock(shift)]]
	_shift_bar.max_value = shift
	_shift_bar.value = state.shift_time
	var district := data.districts[state.district_id]
	_resources.text = "   %s %d   %s %d   %s %d   %s %d   %s %d%%   %s   %s" % [
		tr("ui.coins"), state.coins, tr("ui.nanobrew"), state.nanobrew, tr("ui.cores"), state.cores,
		tr("ui.power"), roundi(state.power), tr("ui.suspicion"), roundi(state.current_suspicion()),
		UiText.name(district.id), tr("ui.influence") % [state.current_influence(), district.influence_required]]
	var in_shift := state.phase == GameState.Phase.SHIFT
	_speed_box.visible = in_shift
	for speed: int in _speed_buttons:
		_speed_buttons[speed].set_pressed_no_signal(speed == state.speed)
	if _card.visible:
		_card.refresh()


func show_toast(text: String) -> void:
	for shown: Node in _toasts.get_children():
		if (shown as Label).text == text:
			return
	var label := UiTheme.label(text, 20, UiTheme.TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	_toasts.add_child(label)
	while _toasts.get_child_count() > MAX_TOASTS:
		var oldest := _toasts.get_child(0)
		_toasts.remove_child(oldest)
		oldest.queue_free()
	var tween := label.create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)


func _on_shift_advanced(events: Shift.Events) -> void:
	refresh()
	if events.coins_earned + events.tips_earned > 0:
		_feed_line(tr("ui.tip") % [events.coins_earned + events.tips_earned, events.tips_earned], UiTheme.WARN)
	for i: int in events.dishes_broken:
		_feed_line(tr("ui.broke_dish"), UiTheme.BAD)
	for i: int in events.left_angry.size():
		_feed_line(tr("ui.left_angry"), UiTheme.BAD)
	if events.turned_away > 0:
		_feed_line(tr("ui.turned_away"), UiTheme.TEXT_DIM)


func _feed_line(text: String, color: Color) -> void:
	_feed.add_child(UiTheme.label(text, 16, color))
	while _feed.get_child_count() > FEED_LINES:
		var oldest := _feed.get_child(0)
		_feed.remove_child(oldest)
		oldest.queue_free()


## Opens the recipe picker for a stove at a screen position.
func open_recipe_menu(stove_index: int, at: Vector2) -> void:
	var state := Session.state
	var data := Session.data
	if not state.stoves[stove_index].is_idle():
		show_toast(UiText.error(GameLoop.STOVE_BUSY))
		return
	_recipe_stove = stove_index
	_recipe_menu.clear()
	var unlocked := Shift.unlocked_recipes(state, data)
	# Menu dishes first: those are what customers order today.
	unlocked.sort_custom(func(a: Recipe, b: Recipe) -> bool: return state.menu.has(a.id) and not state.menu.has(b.id))
	_recipe_menu.add_separator(tr("ui.cook_title") % (stove_index + 1))
	for i: int in unlocked.size():
		var recipe := unlocked[i]
		_recipe_menu.add_item(tr("ui.cook_item") % [UiText.name(recipe.id), recipe.cost, recipe.servings, recipe.cook_seconds], i)
		_recipe_menu.set_item_metadata(_recipe_menu.get_item_index(i), recipe.id)
		_recipe_menu.set_item_disabled(_recipe_menu.get_item_index(i), state.coins < recipe.cost)
	_recipe_menu.position = Vector2i(at)  # popups are embedded: game-window coordinates
	_recipe_menu.reset_size()
	_recipe_menu.popup()


func _on_recipe_chosen(id: int) -> void:
	var recipe_id: String = _recipe_menu.get_item_metadata(_recipe_menu.get_item_index(id))
	Session.act(GameLoop.start_cooking(Session.state, _recipe_stove, recipe_id, Session.data))


func open_synth_card(synth_id: String) -> void:
	_card.synth_id = synth_id
	_card.visible = true
	_card.refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or not Session.has_game():
		return
	var key := (event as InputEventKey).keycode
	match key:
		KEY_ESCAPE:
			toggle_pause()
		KEY_SPACE:
			Session.set_speed(0 if Session.state.speed != 0 else 1)
		KEY_1, KEY_2, KEY_3:
			Session.set_speed([1, 2, 4][key - KEY_1])
		_:
			return
	get_viewport().set_input_as_handled()
