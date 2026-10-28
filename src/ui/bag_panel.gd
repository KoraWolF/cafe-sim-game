class_name BagPanel
extends PanelContainer
## The Bag, open at any time from the top bar: everything you own, in a strip
## along the bottom of the screen (like the Menu). Equipment and Fashion show a
## row of cards (scroll it sideways with the mouse wheel) (border colour = tier, a
## badge for who wears it); click one for its detail box with every action
## (Wear on a worker, Take off, Sell). Bottles: Use on a worker. Crafting is in
## the Shop's Workshop.

signal closed

## Height of the strip at the bottom (the camera keeps the café above it).
const HEIGHT: float = 330.0
const TABS: Array[String] = ["equipment", "fashion", "bottles"]
## Card border by tier.
const TIER_COLORS: Dictionary[String, Color] = {"common": Color("9aa3b8"), "magic": Color("4fb3ff"),
	"rare": Color("ffd34d"), "epic": Color("b36bff"), "legendary": Color("ff8a3d")}

var tabs := TabContainer.new()
## Selected card: an item uid, or a bottle id on the Bottles tab.
var selected: String = ""
var _grids: Dictionary[String, GridContainer] = {}
var _details: Dictionary[String, VBoxContainer] = {}


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_left = 12
	offset_right = -12
	offset_top = -HEIGHT - 12
	offset_bottom = -12
	grow_vertical = Control.GROW_DIRECTION_BEGIN  # if it ever needs more room, it grows up, never off the screen
	var column := VBoxContainer.new()
	add_child(column)
	var header := HBoxContainer.new()
	var title := UiTheme.label(tr("ui.bag_title"), 26, UiTheme.PANEL_BORDER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiTheme.button(tr("ui.close"), close))
	column.add_child(header)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	for key: String in TABS:
		var split := HBoxContainer.new()
		split.name = tr("ui.bag_tab_" + key)
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		UiTheme.wheel_scrolls_sideways(scroll)
		var grid := GridContainer.new()
		grid.columns = 999  # one row, scrolling sideways
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		scroll.add_child(grid)
		split.add_child(scroll)
		var detail := VBoxContainer.new()
		detail.custom_minimum_size = Vector2(320, 0)
		detail.add_theme_constant_override("separation", 4)
		split.add_child(detail)
		tabs.add_child(split)
		_grids[key] = grid
		_details[key] = detail
	tabs.tab_changed.connect(func(_index: int) -> void:
		selected = ""
		refresh())
	Session.state_changed.connect(refresh)


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


## Every owned piece of a kind: [item, wearer or null], inventory first.
func owned(kind: String) -> Array[Array]:
	var result: Array[Array] = []
	var state := Session.state
	for item: Item in state.inventory:
		if item.kind == kind:
			result.append([item, null])
	for synth: Synth in state.synths:
		for item: Item in synth.items:
			if item.kind == kind:
				result.append([item, synth])
	return result


func refresh() -> void:
	if not visible or not Session.has_game():
		return
	for key: String in _grids:
		_clear(_grids[key])
		_clear(_details[key])
	for kind: String in [Item.EQUIPMENT, Item.FASHION]:
		var key := "equipment" if kind == Item.EQUIPMENT else "fashion"
		var pieces := owned(kind)
		if pieces.is_empty():
			_details[key].add_child(_note(tr("ui.nothing_to_wear_" + kind)))
		for entry: Array in pieces:
			_grids[key].add_child(_item_card(entry[0], entry[1]))
		_fill_item_detail(_details[key], pieces)
	_fill_bottles()


## A card: tier and name, what it does, and who wears it.
func _item_card(item: Item, wearer: Synth) -> Button:
	var data := Session.data
	var lines: Array[String] = [UiText.item_name(item), UiText.item_effect(item, data.items)]
	lines.append(tr("ui.bag_worn_by") % Session.synth_name(wearer) if wearer != null else tr("ui.bag_spare"))
	var color: Color = TIER_COLORS.get(item.tier, Color.WHITE) if item.kind == Item.EQUIPMENT \
		else Color(data.items.fashion[item.type_id]["color"])
	return _card("\n".join(lines), color, item.uid)


func _card(text: String, color: Color, key: String) -> Button:
	var card := Button.new()
	card.text = text
	card.custom_minimum_size = Vector2(150, 92)
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.toggle_mode = true
	card.button_pressed = key == selected
	for state_name: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(color, 0.28 if state_name.contains("pressed") else 0.12)
		box.border_color = color
		box.set_border_width_all(4 if state_name.contains("pressed") else 2)
		box.set_corner_radius_all(8)
		box.set_content_margin_all(6)
		card.add_theme_stylebox_override(state_name, box)
	card.pressed.connect(func() -> void:
		selected = key
		refresh())
	return card


## The selected piece: what it is, who wears it, Wear on, Take off, Sell.
func _fill_item_detail(detail: VBoxContainer, pieces: Array[Array]) -> void:
	var data := Session.data
	var entry: Array = []
	for one: Array in pieces:
		if (one[0] as Item).uid == selected:
			entry = one
	if entry.is_empty():
		if not pieces.is_empty():
			detail.add_child(_note(tr("ui.bag_pick")))
		return
	var item: Item = entry[0]
	var wearer: Synth = entry[1]
	detail.add_child(UiTheme.label(UiText.item_name(item), 20, UiTheme.PANEL_BORDER))
	detail.add_child(UiTheme.label("%s · %s" % [tr("slot." + item.slot(data.items)), UiText.item_effect(item, data.items)], 16))
	detail.add_child(_note(tr("ui.bag_worn_by") % Session.synth_name(wearer) if wearer != null else tr("ui.bag_spare")))
	var picker := _worker_picker(wearer)
	detail.add_child(picker)
	var wear := UiTheme.button(tr("ui.bag_wear_on"), func() -> void:
		var target: String = picker.get_item_metadata(picker.selected)
		if wearer != null:
			Session.act(GameLoop.unequip_item(Session.state, wearer.id, item.slot(data.items), data))
		Session.act(GameLoop.equip_item(Session.state, target, item.uid, data)))
	detail.add_child(wear)
	if wearer != null:
		detail.add_child(UiTheme.button(tr("ui.take_off"), func() -> void:
			Session.act(GameLoop.unequip_item(Session.state, wearer.id, item.slot(data.items), data))))
	if item.kind == Item.EQUIPMENT:
		var sell := UiTheme.button(tr("ui.sell") % int(data.items.tiers[item.tier]["sell"]), func() -> void:
			if Session.act(GameLoop.sell_item(Session.state, item.uid, data)):
				selected = "")
		sell.disabled = wearer != null
		detail.add_child(sell)
		if wearer != null:
			detail.add_child(_note(tr("ui.bag_sell_worn")))


## A dropdown of workers (metadata = Synth id), the current wearer skipped.
func _worker_picker(skip: Synth) -> OptionButton:
	var picker := OptionButton.new()
	for synth: Synth in Session.state.synths:
		if synth == skip:
			continue
		picker.add_item(Session.synth_name(synth))
		picker.set_item_metadata(picker.item_count - 1, synth.id)
	return picker


func _fill_bottles() -> void:
	var state := Session.state
	var data := Session.data
	var grid := _grids["bottles"]
	var detail := _details["bottles"]
	if state.bottles.is_empty():
		detail.add_child(_note(tr("ui.bottles_none")))
		return
	for bottle_id: String in state.bottles:
		grid.add_child(_card(tr("ui.bottle_card") % [UiText.name(bottle_id), data.items.bottles[bottle_id]["xp"],
			state.bottles[bottle_id]], UiTheme.GOOD, bottle_id))
	if not state.bottles.has(selected):
		detail.add_child(_note(tr("ui.bag_pick")))
		return
	var bottle_id := selected
	detail.add_child(UiTheme.label(UiText.name(bottle_id), 20, UiTheme.PANEL_BORDER))
	detail.add_child(UiTheme.label(tr("ui.bottle_xp") % data.items.bottles[bottle_id]["xp"], 16))
	var picker := _worker_picker(null)
	detail.add_child(picker)
	detail.add_child(UiTheme.button(tr("ui.bag_use_on"), func() -> void:
		var target: String = picker.get_item_metadata(picker.selected)
		var level_ups: Dictionary[String, int] = {}
		if Session.act(GameLoop.use_bottle(Session.state, target, bottle_id, data, level_ups)) and level_ups.has(target):
			Session.toast.emit(tr("ui.level_up") % [Session.synth_name(Session.state.synth_by_id(target)), level_ups[target]])))


func _note(text: String) -> Label:
	var label := UiTheme.label(text, 14, UiTheme.TEXT_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(230, 0)
	return label


func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
