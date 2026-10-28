class_name ShopPanel
extends PanelContainer
## The Menu (the shop), opened from the round Menu button at the bottom right:
## a strip along the bottom of the screen with category tabs (Furniture, Décor,
## Upgrades, Energy, Workshop with crafting and NanoBrew) over a row of cards
## that scrolls sideways (arrows or the mouse wheel). Furniture
## and décor cards have Buy (puts it in your hand in Arrange) and Store (keeps it
## for later); Sync Pods are bought up to the café's side. The café keeps
## running. Items you own live in the Bag. Rebuilds after every action.

signal closed
signal arrange_requested
## Bought with "Buy": arrange it now, holding piece_id.
signal place_requested(piece_id: String)

## Height of the strip at the bottom (the camera keeps the café above it).
const HEIGHT: float = 330.0
const CARD_SIZE: Vector2 = Vector2(210, 220)
## Pixels one press of an arrow scrolls the row.
const SCROLL_STEP: float = 440.0
const TABS: Array[String] = ["furniture", "decor", "upgrades", "energy", "workshop"]

var tabs := TabBar.new()
var _coins := UiTheme.label("", 20, UiTheme.WARN)
var _note := UiTheme.label("", 15, UiTheme.TEXT_DIM)
var _scroll := ScrollContainer.new()
var _row := HBoxContainer.new()


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 12
	offset_right = -12
	offset_top = -HEIGHT - 12
	offset_bottom = -12
	var column := VBoxContainer.new()
	add_child(column)
	var header := HBoxContainer.new()
	header.add_child(UiTheme.label(tr("ui.shop_title"), 24, UiTheme.PANEL_BORDER))
	for key: String in TABS:
		tabs.add_tab(tr("ui.shop_tab_" + key))
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.tab_changed.connect(func(_index: int) -> void:
		_scroll.scroll_horizontal = 0
		refresh())
	header.add_child(tabs)
	header.add_child(_coins)
	header.add_child(UiTheme.button(tr("ui.arrange"), arrange_requested.emit))
	header.add_child(UiTheme.button(tr("ui.close"), close))
	column.add_child(header)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_note)
	var carousel := HBoxContainer.new()
	carousel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel.add_child(_arrow("◀", -1))
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_row.add_theme_constant_override("separation", 12)
	_scroll.add_child(_row)
	UiTheme.wheel_scrolls_sideways(_scroll)
	carousel.add_child(_scroll)
	carousel.add_child(_arrow("▶", 1))
	column.add_child(carousel)
	Session.state_changed.connect(refresh)


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


## The key of the tab showing now.
func current() -> String:
	return TABS[tabs.current_tab]


func refresh() -> void:
	if not visible or not Session.has_game():
		return
	var state := Session.state
	var data := Session.data
	_coins.text = tr("ui.coins_line") % state.coins
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	match current():
		"furniture":
			_note.text = tr("ui.furniture_note")
			_row.add_child(_pod_card(state, data))
			for piece: Piece in data.pieces.values():
				if piece.price > 0 and piece.kind != Piece.DECOR:
					_row.add_child(_piece_card(piece, tr("tip.piece." + piece.id)))
		"decor":
			_note.text = tr("ui.floor_line") % [state.floor_width, state.floor_rows, roundi(state.vibe)]
			for piece: Piece in data.pieces.values():
				if piece.price > 0 and piece.kind == Piece.DECOR:
					_row.add_child(_piece_card(piece, tr("ui.decor_card") % [roundi(piece.vibe), ", ".join(piece.tags)]))
		"upgrades":
			_note.text = ""
			for upgrade_id: String in Upgrade.IDS:
				_row.add_child(_upgrade_card(upgrade_id, state, data))
		"energy":
			_note.text = tr("ui.power_line") % [roundi(state.power), ceili(NightOps.recharge_cost(state, data))] \
				+ "   " + tr("info.stat.battery")
			for amount: int in [10, 50, 200]:
				var price := amount * data.balance.power_price
				var buy := UiTheme.button(tr("ui.buy") % price, func() -> void:
					Session.act(GameLoop.buy_power(Session.state, amount, Session.data)))
				buy.disabled = state.coins < price
				_row.add_child(_card(tr("ui.energy_card") % amount, "", UiTheme.WARN, [buy]))
		"workshop":
			_note.text = tr("ui.materials") % [state.scrap, state.chips] + "   " + tr("ui.workshop_note")
			var b := data.balance
			var brew := UiTheme.button(tr("ui.brew_short") % [b.brew_core_cost, b.brew_coin_cost], func() -> void:
				Session.act(GameLoop.brew_nanobrew(Session.state, Session.data)))
			brew.disabled = state.cores < b.brew_core_cost or state.coins < b.brew_coin_cost
			_row.add_child(_card(tr("ui.brew_title"), tr("ui.nanobrew_count") % [state.nanobrew, state.cores] + "\n"
				+ tr("ui.brew_note"), UiTheme.PANEL_BORDER, [brew]))
			for craft_id: String in data.items.crafts:
				var recipe: Dictionary = data.items.crafts[craft_id]
				var costs: Array = [recipe["scrap"], recipe["chips"]] if recipe["chips"] > 0 else [recipe["scrap"]]
				var make := UiTheme.button(tr("ui.craft"), func() -> void:
					var made: Array[Item] = []
					if Session.act(GameLoop.craft_item(Session.state, craft_id, Session.data, made)):
						Session.toast.emit(tr("ui.crafted") % [UiText.item_name(made[0]), UiText.item_effect(made[0], Session.data.items)]))
				make.disabled = state.scrap < recipe["scrap"] or state.chips < recipe["chips"]
				_row.add_child(_card(tr("ui.craft_title_" + craft_id), tr("ui.craft_" + craft_id) % costs, UiTheme.ACCENT, [make]))


## A furniture or décor card: its colour, name and size, what you own, Buy and Store.
func _piece_card(piece: Piece, about: String) -> Control:
	var state := Session.state
	var details := "%dx%d · %s\n%s" % [piece.size.x, piece.size.y, tr("ui.piece_owned") % [Layout.count_placed_id(state, piece.id),
		state.storage.get(piece.id, 0)], about]
	var buy := UiTheme.button(tr("ui.buy_place") % piece.price, func() -> void:
		if Session.act(GameLoop.buy_piece(Session.state, piece.id, Session.data)):
			# After this click is done, so its mouse release can't land on the floor in Arrange.
			place_requested.emit.call_deferred(piece.id))
	var store := UiTheme.button(tr("ui.buy_store"), func() -> void:
		if Session.act(GameLoop.buy_piece(Session.state, piece.id, Session.data)):
			Session.toast.emit(tr("ui.stored") % [UiText.name(piece.id), Session.state.storage.get(piece.id, 0)]))
	for button: Button in [buy, store]:
		button.disabled = state.coins < piece.price
	return _card(UiText.name(piece.id), details, CafeView.piece_color(piece), [buy, store])


## Sync Pods: room for one more Synth each, up to the café's side.
func _pod_card(state: GameState, data: GameData) -> Control:
	var buy := UiTheme.button(tr("ui.buy_place") % data.balance.pod_price, func() -> void:
		Session.act(GameLoop.buy_pod(Session.state, Session.data)))
	buy.disabled = state.pods >= GameLoop.pod_cap(state) or state.coins < data.balance.pod_price
	return _card(tr("ui.pod_name"), tr("ui.pod_card") % [state.pods, GameLoop.pod_cap(state)], UiTheme.PANEL_BORDER, [buy])


func _upgrade_card(upgrade_id: String, state: GameState, data: GameData) -> Control:
	var upgrade := data.upgrades[upgrade_id]
	var cost := GameLoop.upgrade_cost(state, upgrade_id, data)
	var buy := UiTheme.button(tr("ui.buy") % cost if cost >= 0 else tr("ui.maxed"), func() -> void:
		Session.act(GameLoop.buy_upgrade(Session.state, upgrade_id, Session.data)))
	buy.disabled = cost < 0 or state.coins < cost
	return _card(UiText.name(upgrade_id), tr("ui.upgrade_card") % [state.upgrades.get(upgrade_id, 0), upgrade.max_level]
		+ "\n" + tr("tip.upgrade." + upgrade_id), UiTheme.GOOD, [buy])


## One card in the row: a colour swatch, a title, a few lines and its buttons.
func _card(title: String, text: String, color: Color, buttons: Array[Button]) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.PANEL.darkened(0.25)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	card.add_child(column)
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(0, 34)
	column.add_child(swatch)
	var heading := UiTheme.label(title, 18)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	var about := UiTheme.label(text, 13, UiTheme.TEXT_DIM)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.size_flags_vertical = Control.SIZE_EXPAND_FILL
	about.custom_minimum_size = Vector2(CARD_SIZE.x - 24, 0)
	column.add_child(about)
	var row := HBoxContainer.new()
	for button: Button in buttons:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	column.add_child(row)
	return card


func _arrow(text: String, direction: int) -> Button:
	var arrow := UiTheme.button(text, func() -> void:
		create_tween().tween_property(_scroll, "scroll_horizontal", _scroll.scroll_horizontal + direction * SCROLL_STEP, 0.25))
	arrow.custom_minimum_size = Vector2(44, 0)
	return arrow
