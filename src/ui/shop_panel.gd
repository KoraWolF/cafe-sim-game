class_name ShopPanel
extends PanelContainer
## The shop, open at any time from the top bar: Energy, café upgrades and
## décor. Bought furniture and décor go straight onto the first free spot (or
## storage); "Arrange Floor" moves them. Rebuilds after every action.

signal closed
signal arrange_requested

const WIDTH: float = 560.0

var _page := VBoxContainer.new()


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -WIDTH - 12
	offset_top = 70
	offset_right = -12
	offset_bottom = -12
	var column := VBoxContainer.new()
	add_child(column)
	var header := HBoxContainer.new()
	var title := UiTheme.label(tr("ui.shop_title"), 26, UiTheme.PANEL_BORDER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiTheme.button(tr("ui.arrange"), arrange_requested.emit))
	header.add_child(UiTheme.button(tr("ui.close"), close))
	column.add_child(header)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_page)
	column.add_child(scroll)
	Session.state_changed.connect(refresh)


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func refresh() -> void:
	if not visible or not Session.has_game():
		return
	for child: Node in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	var state := Session.state
	var data := Session.data
	var b := data.balance
	_page.add_child(_wrap(tr("ui.coins_line") % state.coins, 20, UiTheme.WARN))
	# Energy for tonight's recharge.
	_page.add_child(_wrap(tr("ui.power_line") % [roundi(state.power), ceili(NightOps.recharge_cost(state, data))]))
	var energy := HBoxContainer.new()
	for amount: int in [10, 50]:
		var buy := UiTheme.button(tr("ui.buy_power") % [amount, amount * b.power_price], func() -> void:
			Session.act(GameLoop.buy_power(state, amount, data)))
		buy.disabled = state.coins < amount * b.power_price
		energy.add_child(buy)
	_page.add_child(energy)
	_page.add_child(HSeparator.new())
	_page.add_child(_wrap(tr("ui.upgrades_title"), 22, UiTheme.PANEL_BORDER))
	for upgrade_id: String in Upgrade.IDS:
		var upgrade := data.upgrades[upgrade_id]
		var row := HBoxContainer.new()
		var name := _wrap(tr("ui.upgrade_line") % [UiText.name(upgrade_id), state.upgrades.get(upgrade_id, 0), upgrade.max_level])
		name.tooltip_text = tr("tip.upgrade." + upgrade_id)
		name.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(name)
		var cost := GameLoop.upgrade_cost(state, upgrade_id, data)
		var buy := UiTheme.button(tr("ui.buy") % cost if cost >= 0 else tr("ui.maxed"), _buy_upgrade.bind(upgrade_id))
		buy.disabled = cost < 0 or state.coins < cost
		row.add_child(buy)
		_page.add_child(row)
		_page.add_child(_indent(_wrap(tr("tip.upgrade." + upgrade_id), 14, UiTheme.TEXT_DIM)))
	_page.add_child(HSeparator.new())
	_page.add_child(_wrap(tr("ui.decor_title"), 22, UiTheme.PANEL_BORDER))
	_page.add_child(_wrap(tr("ui.floor_line") % [b.floor_width, state.floor_rows, roundi(state.vibe)], 16, UiTheme.TEXT_DIM))
	_page.add_child(_wrap(tr("ui.decor_note"), 14, UiTheme.TEXT_DIM))
	for piece: Piece in data.pieces.values():
		if piece.kind != Piece.DECOR:
			continue
		var row := HBoxContainer.new()
		var text := tr("ui.decor_line") % [UiText.name(piece.id), piece.size.x, piece.size.y, roundi(piece.vibe), ", ".join(piece.tags)]
		if state.storage.get(piece.id, 0) > 0:
			text += "   " + tr("ui.decor_owned") % state.storage[piece.id]
		row.add_child(_wrap(text, 16))
		var buy := UiTheme.button(tr("ui.buy") % piece.price, _buy_decor.bind(piece.id))
		buy.disabled = state.coins < piece.price
		row.add_child(buy)
		_page.add_child(row)


func _buy_upgrade(upgrade_id: String) -> void:
	if Session.act(GameLoop.buy_upgrade(Session.state, upgrade_id, Session.data)) \
			and Upgrade.FURNITURE.has(upgrade_id):
		Session.auto_place(upgrade_id)
		Session.state_changed.emit()


func _buy_decor(piece_id: String) -> void:
	if Session.act(GameLoop.buy_decor(Session.state, piece_id, Session.data)):
		if not Session.auto_place(piece_id):
			Session.toast.emit(tr("ui.no_room_stored"))
		Session.state_changed.emit()


func _wrap(text: String, size := 18, color := UiTheme.TEXT) -> Label:
	var label := UiTheme.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(200, 0)
	return label


func _indent(control: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_child(control)
	return margin
