class_name EditPanel
extends PanelContainer
## The side panel while arranging the floor: Vibe and floor size, what is in
## hand with Rotate / Store / Sell / Put back, the storage list, and Done.

signal done

const WIDTH: float = 380.0

var editor: FloorEditor = null
var _summary := UiTheme.label("", 18)
var _holding := UiTheme.label("", 18, UiTheme.PANEL_BORDER)
var _rotate := UiTheme.button(tr("ui.edit_rotate"), _do.bind("rotate"))
var _store := UiTheme.button(tr("ui.edit_store"), _do.bind("store"))
var _sell := UiTheme.button("", _do.bind("sell"))
var _cancel := UiTheme.button(tr("ui.edit_cancel"), _do.bind("cancel"))
var _storage := VBoxContainer.new()


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
	_summary.text = tr("ui.floor_line") % [data.balance.floor_width, state.floor_rows, roundi(state.vibe)]
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
	refresh()
