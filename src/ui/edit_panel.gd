class_name EditPanel
extends PanelContainer
## The side panel while arranging the floor: Vibe and floor size, what is in
## hand with Rotate / Store / Sell / Cancel, Select several (store or sell many
## at once), the storage list, and Done. Storing and selling ask first.

signal done
## A button changed what is held (rotate, put back, store, sell).
signal changed

const WIDTH: float = 380.0

var editor: FloorEditor = null
var _summary := UiTheme.label("", 18)
var _holding := UiTheme.label("", 18, UiTheme.PANEL_BORDER)
var _rotate := UiTheme.button(tr("ui.edit_rotate"), _do.bind("rotate"))
var _store := UiTheme.button(tr("ui.edit_store"), _ask.bind("store"))
var _sell := UiTheme.button("", _ask.bind("sell"))
var _cancel := UiTheme.button(tr("ui.edit_cancel"), _do.bind("cancel"))
var _storage := VBoxContainer.new()
var _select := Button.new()
var _selected := UiTheme.label("", 16)
var _store_selected := UiTheme.button(tr("ui.edit_store_selected"), _ask.bind("store_selected"))
var _sell_selected := UiTheme.button("", _ask.bind("sell_selected"))
var _confirm := ConfirmModal.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -WIDTH - 12
	offset_top = UiTheme.TOP_BAR_HEIGHT + 12
	offset_right = -12
	offset_bottom = -12
	visible = false
	var column := VBoxContainer.new()
	add_child(column)
	column.add_child(UiTheme.label(tr("ui.edit_title"), 26, UiTheme.PANEL_BORDER))
	var hint := UiTheme.label(tr("ui.edit_hint"), 15, UiTheme.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(WIDTH - 40, 0)
	column.add_child(hint)
	column.add_child(_summary)
	column.add_child(HSeparator.new())
	column.add_child(_holding)
	var actions := GridContainer.new()
	actions.columns = 2
	for button: Button in [_rotate, _cancel, _store, _sell]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	column.add_child(actions)
	_select.text = tr("ui.edit_select")
	_select.toggle_mode = true
	_select.toggled.connect(func(on: bool) -> void:
		editor.set_selecting(on)
		refresh()
		changed.emit())
	column.add_child(_select)
	column.add_child(_selected)
	var many := HBoxContainer.new()
	for button: Button in [_store_selected, _sell_selected]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		many.add_child(button)
	column.add_child(many)
	column.add_child(HSeparator.new())
	column.add_child(UiTheme.label(tr("ui.edit_storage"), 20, UiTheme.PANEL_BORDER))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_storage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_storage)
	column.add_child(scroll)
	var finish := UiTheme.button(tr("ui.edit_done"), done.emit)
	finish.custom_minimum_size = Vector2(0, 50)
	column.add_child(finish)
	# Beside the panel, not inside it: a container would squeeze the full-screen modal.
	get_parent().add_child.call_deferred(_confirm)
	Session.state_changed.connect(refresh)


func open(with_editor: FloorEditor) -> void:
	editor = with_editor
	visible = true
	refresh()


func refresh() -> void:
	if not visible or editor == null:
		return
	var state := Session.state
	var data := Session.data
	_summary.text = tr("ui.floor_line") % [state.floor_width, state.floor_rows, roundi(state.vibe)]
	var holding := editor.is_holding()
	if holding:
		var key := "ui.edit_holding_rotated" if editor.rotated else "ui.edit_holding"
		_holding.text = tr(key) % UiText.name(editor.held_piece)
	else:
		_holding.text = tr("ui.edit_nothing")
	var piece: Piece = data.pieces.get(editor.held_piece)
	_rotate.disabled = not holding
	_cancel.disabled = not holding
	_store.disabled = editor.held_uid == ""
	_sell.disabled = piece == null or piece.price <= 0
	_sell.text = tr("ui.edit_sell") % (Layout.refund(piece, data.balance) if piece != null else 0)
	_select.set_pressed_no_signal(editor.selecting)
	_selected.visible = editor.selecting
	_selected.text = tr("ui.edit_selected") % editor.selected.size()
	for button: Button in [_store_selected, _sell_selected]:
		button.visible = editor.selecting
		button.disabled = editor.selected.is_empty()
	_sell_selected.text = tr("ui.edit_sell") % editor.selected_refund(state, data)
	for child: Node in _storage.get_children():
		_storage.remove_child(child)
		child.queue_free()
	if state.storage.is_empty():
		_storage.add_child(UiTheme.label(tr("ui.edit_storage_empty"), 16, UiTheme.TEXT_DIM))
	for piece_id: String in state.storage:
		var take := UiTheme.button(tr("ui.edit_take") % [UiText.name(piece_id), state.storage[piece_id]], _take.bind(piece_id))
		take.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_storage.add_child(take)


func _take(piece_id: String) -> void:
	Session.act(editor.hold_stored(Session.state, piece_id))
	refresh()


## Store and Sell ask first, saying what goes and for how much.
func _ask(action: String) -> void:
	var state := Session.state
	var data := Session.data
	var names: Array[String] = []
	var coins := 0
	match action:
		"store", "sell":
			names = [UiText.name(editor.held_piece)]
			var piece: Piece = data.pieces.get(editor.held_piece)
			coins = Layout.refund(piece, data.balance) if piece != null else 0
		_:
			for uid: String in editor.selected:
				var placed := Layout.placed_by_uid(state, uid)
				if placed != null:
					names.append(UiText.name(placed.piece_id))
			coins = editor.selected_refund(state, data)
	var selling := action.begins_with("sell")
	_confirm.ask(tr("ui.confirm_sell" if selling else "ui.confirm_store") % names.size(), ", ".join(names)
		+ ("\n" + tr("ui.confirm_sell_coins") % coins if selling else ""),
		tr("ui.edit_sell_yes" if selling else "ui.edit_store"), _do.bind(action))


func _do(action: String) -> void:
	match action:
		"rotate":
			editor.rotate()
		"cancel":
			editor.cancel()
		"store":
			Session.act(editor.store(Session.state, Session.data))
		"sell":
			Session.act(editor.sell(Session.state, Session.data))
		"store_selected":
			Session.act(editor.store_selected(Session.state, Session.data))
		"sell_selected":
			Session.act(editor.store_selected(Session.state, Session.data, true))
	refresh()
	changed.emit()
