class_name ShopPanel
extends PanelContainer
## The shop (buying only), open at any time from the top bar: Furniture and
## Décor by the piece, as many as fit (Buy puts it in your hand in Arrange;
## Store keeps it in storage for later), café Upgrades, and Energy.
## Items you own live in the Bag. Rebuilds after every action.

signal closed
signal arrange_requested
## Bought with "Buy": arrange it now, holding piece_id.
signal place_requested(piece_id: String)

const WIDTH: float = 600.0
const TABS: Array[String] = ["furniture", "decor", "upgrades", "energy"]

var tabs := TabContainer.new()
var _pages: Dictionary[String, VBoxContainer] = {}


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -WIDTH - 12
	offset_top = UiTheme.TOP_BAR_HEIGHT + 12
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
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	for key: String in TABS:
		var scroll := ScrollContainer.new()
		scroll.name = tr("ui.shop_tab_" + key)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 8)
		scroll.add_child(page)
		tabs.add_child(scroll)
		_pages[key] = page
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
	var state := Session.state
	var data := Session.data
	for key: String in TABS:
		var page := _clear(key)
		page.add_child(_wrap(tr("ui.coins_line") % state.coins, 20, UiTheme.WARN))
	_pages["furniture"].add_child(_wrap(tr("ui.furniture_note"), 14, UiTheme.TEXT_DIM))
	_pages["decor"].add_child(_wrap(tr("ui.floor_line") % [state.floor_width, state.floor_rows, roundi(state.vibe)], 16,
		UiTheme.TEXT_DIM))
	for piece: Piece in data.pieces.values():
		if piece.price <= 0:
			continue
		var decor := piece.kind == Piece.DECOR
		var about := tr("ui.decor_line") % [UiText.name(piece.id), piece.size.x, piece.size.y, roundi(piece.vibe), ", ".join(piece.tags)] \
			if decor else tr("ui.furniture_line") % [UiText.name(piece.id), piece.size.x, piece.size.y]
		_pages["decor" if decor else "furniture"].add_child(_piece_row(piece, about,
			"" if decor else tr("tip.piece." + piece.id)))
	for upgrade_id: String in Upgrade.IDS:
		var upgrade := data.upgrades[upgrade_id]
		var row := HBoxContainer.new()
		var name := _wrap(tr("ui.upgrade_line") % [UiText.name(upgrade_id), state.upgrades.get(upgrade_id, 0), upgrade.max_level])
		row.add_child(name)
		var cost := GameLoop.upgrade_cost(state, upgrade_id, data)
		var buy := UiTheme.button(tr("ui.buy") % cost if cost >= 0 else tr("ui.maxed"), func() -> void:
			Session.act(GameLoop.buy_upgrade(Session.state, upgrade_id, Session.data)))
		buy.disabled = cost < 0 or state.coins < cost
		row.add_child(buy)
		_pages["upgrades"].add_child(row)
		_pages["upgrades"].add_child(_indent(_wrap(tr("tip.upgrade." + upgrade_id), 14, UiTheme.TEXT_DIM)))
	var energy := _pages["energy"]
	energy.add_child(_wrap(tr("ui.power_line") % [roundi(state.power), ceili(NightOps.recharge_cost(state, data))]))
	energy.add_child(_wrap(tr("info.stat.battery"), 14, UiTheme.TEXT_DIM))
	var row := HBoxContainer.new()
	for amount: int in [10, 50, 200]:
		var price := amount * data.balance.power_price
		var buy := UiTheme.button(tr("ui.buy_power") % [amount, price], func() -> void:
			Session.act(GameLoop.buy_power(Session.state, amount, Session.data)))
		buy.disabled = state.coins < price
		row.add_child(buy)
	energy.add_child(row)


## A piece for sale: what it is, how many you have, Buy (and place now) and Store.
func _piece_row(piece: Piece, about: String, help: String) -> Control:
	var state := Session.state
	var box := VBoxContainer.new()
	var row := HBoxContainer.new()
	var placed := Layout.count_placed_id(state, piece.id)
	var stored: int = state.storage.get(piece.id, 0)
	row.add_child(_wrap(about + "   " + tr("ui.piece_owned") % [placed, stored], 16))
	var buy := UiTheme.button(tr("ui.buy_place") % piece.price, func() -> void:
		if Session.act(GameLoop.buy_piece(Session.state, piece.id, Session.data)):
			# After this click is done, so its mouse release can't land on the floor in Arrange.
			place_requested.emit.call_deferred(piece.id))
	var store := UiTheme.button(tr("ui.buy_store"), func() -> void:
		if Session.act(GameLoop.buy_piece(Session.state, piece.id, Session.data)):
			Session.toast.emit(tr("ui.stored") % [UiText.name(piece.id), Session.state.storage.get(piece.id, 0)]))
	buy.tooltip_text = tr("tip.buy_place")
	store.tooltip_text = tr("tip.buy_store")
	for button: Button in [buy, store]:
		button.disabled = state.coins < piece.price
		row.add_child(button)
	box.add_child(row)
	if help != "":
		box.add_child(_indent(_wrap(help, 14, UiTheme.TEXT_DIM)))
	return box


func _clear(key: String) -> VBoxContainer:
	var page := _pages[key]
	for child: Node in page.get_children():
		page.remove_child(child)
		child.queue_free()
	return page


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
