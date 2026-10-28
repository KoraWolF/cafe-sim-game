class_name Hud
extends Control
## The always-on overlay: resources and day on top, speed, Shop, Arrange and
## Auto buttons, toasts, an
## event feed, the stove recipe picker, the Synth card and the pause menu.

signal quit_to_menu
signal settings_requested
signal shop_requested
signal quests_requested
signal bag_requested
## The worker card was closed (the café drops its job selection).
signal card_closed
signal arrange_requested

const FEED_LINES: int = 6
const TOAST_SECONDS: float = 3.0
const MAX_TOASTS: int = 3

var bar := PanelContainer.new()
var _top := Label.new()
var _resources := Label.new()
var _shift_bar := ProgressBar.new()
var _speed_box := HBoxContainer.new()
var _speed_buttons: Dictionary[int, Button] = {}
var _auto := Button.new()
var shop_button := UiTheme.button(tr("ui.shop_button"), shop_requested.emit)
var arrange_button := UiTheme.button(tr("ui.arrange_button"), arrange_requested.emit)
var _toasts := VBoxContainer.new()
var _feed := VBoxContainer.new()
var _recipe_menu := PopupMenu.new()
var _save_buttons: Array[Button] = []
## The recipe menu's "cancel this batch" item.
const CANCEL_COOKING: int = 1000
var _recipe_stove: int = -1
var _card := SynthCard.new()
var _pause := Modal.new()
var confirm := ConfirmModal.new()
var customer_card := CustomerCard.new()
var details := UnitDetails.new()
var info := InfoPanel.new()
var info_button := UiTheme.button(tr("ui.info_button"), func() -> void: info.open())
var quests_button := UiTheme.button(tr("ui.quests_button"), quests_requested.emit)
var bag_button := UiTheme.button(tr("ui.bag_button"), bag_requested.emit)
## Today's daily quests, small, under the top bar; a finished one has Claim.
var _tracker := VBoxContainer.new()
## What the tracker shows now (rebuilt only when it changes, so a click lands).
var _tracker_key: String = ""
## Starred customers who paid and left: pick one to convert (until closing).
var stars := MenuButton.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar()
	_tracker.position = Vector2(16, UiTheme.TOP_BAR_HEIGHT + 8)
	_tracker.add_theme_constant_override("separation", 2)
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE  # only its Claim buttons take clicks
	add_child(_tracker)
	stars.flat = false
	add_child(stars)
	stars.get_popup().id_pressed.connect(func(index: int) -> void:
		if index < Session.state.star_list.size():
			confirm_convert(Session.state.star_list[index].id))
	_toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-300, UiTheme.TOP_BAR_HEIGHT + 30)
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
	_card.details_requested.connect(details.open)
	_card.closed.connect(card_closed.emit)
	add_child(details)
	add_child(customer_card)
	_build_pause_menu()
	Session.toast.connect(show_toast)
	Session.state_changed.connect(refresh)
	Session.phase_changed.connect(func() -> void:
		_card.visible = false
		refresh())
	Session.shift_advanced.connect(_on_shift_advanced)
	refresh()


func _build_top_bar() -> void:
	# Two rows: day, shift and resources on top; speed and the buttons below.
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, UiTheme.TOP_BAR_HEIGHT)
	add_child(bar)
	var rows := VBoxContainer.new()
	bar.add_child(rows)
	var row := HBoxContainer.new()
	rows.add_child(row)
	_top.add_theme_font_size_override("font_size", 22)
	row.add_child(_top)
	_shift_bar.custom_minimum_size = Vector2(180, 20)
	_shift_bar.show_percentage = false
	_shift_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_shift_bar)
	_resources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resources.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_resources)
	row = HBoxContainer.new()
	rows.add_child(row)
	row.add_child(_speed_box)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	for speed: int in GameState.SPEEDS:
		var label := tr("ui.speed_pause") if speed == 0 else "%d×" % speed
		var button := UiTheme.button(label, Session.set_speed.bind(speed))
		button.toggle_mode = true
		_speed_buttons[speed] = button
		_speed_box.add_child(button)
	row.add_child(info_button)
	row.add_child(quests_button)
	row.add_child(bag_button)
	row.add_child(shop_button)
	row.add_child(arrange_button)
	_auto.text = tr("ui.auto")
	_auto.toggle_mode = true
	_auto.toggled.connect(func(on: bool) -> void:
		if Session.act(GameLoop.set_auto(Session.state, on, Session.data)) and on:
			show_toast(tr("ui.auto_on"))
			Session.auto_night())
	row.add_child(_auto)
	row.add_child(UiTheme.button(tr("ui.menu_button"), toggle_pause))


func _build_pause_menu() -> void:
	add_child(_pause)
	add_child(confirm)
	add_child(info)
	_pause.panel.custom_minimum_size = Vector2(360, 0)
	var column := _pause.content
	column.add_child(UiTheme.label(tr("ui.paused"), 28, UiTheme.PANEL_BORDER))
	column.add_child(UiTheme.button(tr("ui.resume"), toggle_pause))
	for slot: int in SaveSystem.SLOTS:
		var save := UiTheme.button("", func() -> void:
			Session.save_game(slot)
			_label_save_buttons())
		_save_buttons.append(save)
		column.add_child(save)
	column.add_child(UiTheme.button(tr("ui.settings"), settings_requested.emit))
	column.add_child(UiTheme.button(tr("ui.main_menu"), func() -> void:
		toggle_pause()
		quit_to_menu.emit()))


func toggle_pause() -> void:
	if _pause.visible:
		_pause.hide_modal()
	else:
		_label_save_buttons()
		_pause.show_modal()
	Session.paused = _pause.visible


## One line per unclaimed daily quest; a finished one gets a Claim button.
func _fill_tracker(state: GameState, data: GameData) -> void:
	var rows: Array[Array] = []
	for quest: Dictionary in state.daily_quests:
		if not quest["claimed"]:
			var done := Quests.daily_progress(state, quest, data)
			rows.append([quest["id"], "%s %s %d/%d" % ["✓" if done[0] >= done[1] else "•",
				tr("quest.daily." + quest["id"]) % quest["target"], done[0], done[1]], done[0] >= done[1]])
	var key := str(rows)
	if key == _tracker_key:
		return
	_tracker_key = key
	for child: Node in _tracker.get_children():
		_tracker.remove_child(child)
		child.queue_free()
	for entry: Array in rows:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(UiTheme.label(entry[1], 15, UiTheme.GOOD if entry[2] else UiTheme.TEXT_DIM))
		if entry[2]:
			var quest_id: String = entry[0]
			var claim := UiTheme.button(tr("ui.quests_claim"), func() -> void:
				var given: Array[Dictionary] = []
				if Session.act(GameLoop.claim_quest(Session.state, Quests.DAILY, quest_id, Session.data, given)):
					Session.toast.emit(tr("ui.quests_got") % UiText.reward(given[0])))
			claim.add_theme_font_size_override("font_size", 14)
			row.add_child(claim)
		_tracker.add_child(row)


## Each save button says what it would overwrite.
func _label_save_buttons() -> void:
	for slot: int in _save_buttons.size():
		var info := SaveSystem.summary(SaveSystem.slot_path(slot))
		_save_buttons[slot].text = tr("ui.save_slot") % (slot + 1) if info.is_empty() 			else tr("ui.save_over") % [slot + 1, info["day"], UiText.name(info["district_id"])]


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
	var ready := Quests.claimable(state, data)
	quests_button.text = tr("ui.quests_button") + (" (%d)" % ready if ready > 0 else "")
	_fill_tracker(state, data)
	_tracker.visible = _tracker.get_child_count() > 0
	# The starred list, under the tracker.
	stars.visible = in_shift and not state.star_list.is_empty()
	stars.text = tr("ui.stars_button") % state.star_list.size()
	stars.position = Vector2(16, UiTheme.TOP_BAR_HEIGHT + 12 + (_tracker.get_combined_minimum_size().y + 6 if _tracker.visible else 0))
	var popup := stars.get_popup()
	popup.clear()
	for i: int in state.star_list.size():
		var customer := state.star_list[i]
		var type := data.customer_types[customer.type_id]
		popup.add_item(tr("ui.star_line") % [UiText.name(customer.type_id), UiText.name(type.synth_species),
			UiText.name(customer.trait_id) if customer.trait_id != "" else tr("ui.card_no_trait"), customer.battery_max], i)
	var unlocked := state.day >= data.balance.auto_unlock_day
	_auto.disabled = not unlocked
	_auto.set_pressed_no_signal(state.auto_night)
	if _card.visible:
		_card.refresh()
	if details.visible:
		details.refresh()
	if customer_card.visible:
		customer_card.refresh()


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
	if state.stoves[stove_index].has_batch():
		confirm_throw(state.stoves[stove_index].piece_uid)
		return
	_recipe_stove = stove_index
	_recipe_menu.clear()
	# A batch still cooking can be cancelled (refunded), or swapped for another dish.
	var cooking := state.stoves[stove_index].recipe_id
	var refund: int = data.recipes[cooking].cost if cooking != "" else 0
	_recipe_menu.add_separator(tr("ui.cook_title") % (stove_index + 1))
	if cooking != "":
		_recipe_menu.add_item(tr("ui.cook_cancel") % [UiText.name(cooking), refund], CANCEL_COOKING)
	var unlocked := Shift.unlocked_recipes(state, data)
	for i: int in unlocked.size():
		var recipe := unlocked[i]
		_recipe_menu.add_item(tr("ui.cook_item") % [UiText.name(recipe.id), recipe.cost, recipe.servings, recipe.cook_seconds], i)
		_recipe_menu.set_item_metadata(_recipe_menu.get_item_index(i), recipe.id)
		_recipe_menu.set_item_disabled(_recipe_menu.get_item_index(i), recipe.id == cooking or state.coins + refund < recipe.cost)
	_recipe_menu.position = Vector2i(at)  # popups are embedded: game-window coordinates
	_recipe_menu.reset_size()
	_recipe_menu.popup()


func _on_recipe_chosen(id: int) -> void:
	var state := Session.state
	var cooking := not state.stoves[_recipe_stove].is_idle()
	if id == CANCEL_COOKING:
		if Session.act(GameLoop.cancel_cooking(state, _recipe_stove, Session.data)):
			Sfx.play("ui_click")
		return
	var recipe_id: String = _recipe_menu.get_item_metadata(_recipe_menu.get_item_index(id))
	if cooking and not Session.act(GameLoop.cancel_cooking(state, _recipe_stove, Session.data)):
		return
	if Session.act(GameLoop.start_cooking(state, _recipe_stove, recipe_id, Session.data)):
		Sfx.play("cook")


func show_customer_card(customer_id: String, at: Vector2) -> void:
	customer_card.show_for(customer_id, at)


## Clicking a starred customer: say why it can't happen, or ask before spending NanoBrew.
## Asks before a server throws a counter's food, or a stove's waiting batch, into the bin.
func confirm_throw(uid: String) -> void:
	var state := Session.state
	var stove := Layout.stove_of(state, uid)
	var recipe_id: String = stove.recipe_id if stove != null else state.counter_dish.get(uid, "")
	var count: int = stove.ready if stove != null else state.counter_count.get(uid, 0)
	var error := GameLoop.throw_away_error(state, uid, Session.data)
	if error != GameLoop.OK:
		show_toast(UiText.error(error))
		return
	confirm.ask(tr("ui.confirm_throw") % [count, UiText.name(recipe_id)], tr("ui.confirm_throw_details"),
		tr("ui.confirm_throw_yes"), func() -> void: Session.act(GameLoop.throw_away(Session.state, uid, Session.data)))


func confirm_convert(customer_id: String) -> void:
	var state := Session.state
	var customer := state.convertible_by_id(customer_id)
	if customer == null:
		return
	if state.nanobrew <= 0:
		show_toast(UiText.error(GameLoop.NO_NANOBREW))
		return
	if state.synths.size() >= state.pods:
		show_toast(UiText.error(GameLoop.NO_FREE_POD))
		return
	var type := Session.data.customer_types[customer.type_id]
	var trait_text := UiText.name(customer.trait_id) if customer.trait_id != "" else tr("ui.card_no_trait")
	confirm.ask(tr("ui.confirm_convert") % [UiText.name(customer.type_id), UiText.name(type.synth_species), trait_text],
		tr("ui.confirm_convert_details") % [state.nanobrew, state.nanobrew - 1, state.synths.size() + 1, state.pods],
		tr("ui.confirm_convert_yes"), Session.convert_customer.bind(customer_id))


## Keeps the Synth card clear of a panel this wide on the right (0 = none).
func set_right_inset(width: float) -> void:
	_card.offset_right = -20.0 - width
	_card.offset_left = _card.offset_right


func close_synth_card() -> void:
	if _card.visible:
		_card.visible = false
		card_closed.emit()


func open_synth_card(synth_id: String) -> void:
	_card.synth_id = synth_id
	_card.visible = true
	_card.refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or not Session.has_game() or Session.editing:
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
