class_name UnitDetails
extends PanelContainer
## A Synth's details in a window the player can drag by its title: Work (best
## role, speed, cooking, appeal), Fight (power, HP, strength now), Trait
## (trait and species), Fashion and Equipment.
## Each number comes with a line on what it does. Fashion and Equipment show a
## box per slot; click one to wear a spare piece or take it off.

var synth_id: String = ""
var _title := UiTheme.label("", 22, UiTheme.PANEL_BORDER)
var _header := HBoxContainer.new()
var _tabs := TabContainer.new()
var _pages: Dictionary[String, VBoxContainer] = {}
var _dragging := false
## Slot boxes on the Fashion and Equipment tabs (by slot), and their picker.
var slot_boxes: Dictionary[String, Button] = {}
var _picker := PopupMenu.new()
var _picker_actions: Array[Array] = []


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(520, 420)
	position = Vector2(420, 140)
	var column := VBoxContainer.new()
	add_child(column)
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_header.gui_input.connect(_drag)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_title)
	_header.add_child(UiTheme.button(tr("ui.close"), func() -> void: visible = false))
	column.add_child(_header)
	add_child(_picker)
	_picker.index_pressed.connect(_on_pick)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	for key: String in ["work", "fight", "trait", "fashion", "gear"]:
		var page := VBoxContainer.new()
		page.name = tr("ui.tab_" + key)
		_tabs.add_child(page)
		_pages[key] = page


func open(id: String) -> void:
	synth_id = id
	visible = true
	move_to_front()
	refresh()


func refresh() -> void:
	var synth := Session.state.synth_by_id(synth_id)
	if synth == null:
		visible = false
		return
	var data := Session.data
	_title.text = tr("ui.details_title") % Session.synth_name(synth)
	var best := data.species[synth.species_id].best_role
	var work := _clear("work")
	work.add_child(_line(tr("ui.details_best_role") % UiText.role(best), tr("tip.role." + best)))
	work.add_child(_line(tr("ui.details_role_now") % UiText.role(synth.role), tr("tip.role." + synth.role)))
	work.add_child(HSeparator.new())
	work.add_child(_line(tr("ui.details_speed") % SynthStats.speed(synth, data), tr("info.stat.speed")))
	work.add_child(_line(tr("ui.details_cook") % roundi(100.0 * SynthStats.stat(synth, "cook", data)), tr("info.stat.cook")))
	work.add_child(_line(tr("ui.details_appeal") % roundi(100.0 * SynthStats.stat(synth, "appeal", data)), tr("info.stat.appeal")))
	var fight := _clear("fight")
	fight.add_child(_line(tr("ui.details_power") % roundi(SynthStats.stat(synth, "power", data)), tr("ui.card_power_help")))
	fight.add_child(_line(tr("ui.details_hp") % roundi(SynthStats.stat(synth, "hp", data)), tr("info.stat.hp")))
	fight.add_child(_line(tr("ui.details_strength") % [roundi(100.0 * SynthStats.battery_factor(synth, data)),
		SynthStats.battery_percent(synth, data)], tr("info.stat.battery")))
	fight.add_child(_line("", tr("ui.details_no_speed")))
	var traits := _clear("trait")
	if synth.trait_id != "":
		traits.add_child(_line(UiText.name(synth.trait_id), tr("trait.%s.desc" % synth.trait_id)))
	else:
		traits.add_child(_line(tr("ui.card_no_trait"), ""))
	traits.add_child(HSeparator.new())
	traits.add_child(_line(tr("ui.details_species") + ": " + UiText.name(synth.species_id), tr("species.%s.desc" % synth.species_id)))
	_fill_slots(_clear("fashion"), synth, Item.FASHION_SLOTS)
	_fill_slots(_clear("gear"), synth, Item.EQUIPMENT_SLOTS)


## One box per slot showing what is worn; clicking it opens a short list of the
## spare pieces that fit (and Take off). Everything else is in the Bag.
func _fill_slots(page: VBoxContainer, synth: Synth, slots: Array[String]) -> void:
	var data := Session.data
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	page.add_child(grid)
	for slot: String in slots:
		var worn := Items.worn(synth, slot, data)
		var box := Button.new()
		box.custom_minimum_size = Vector2(150, 84)
		box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.text = "%s\n%s" % [tr("slot." + slot), UiText.item_name(worn) + "\n" + UiText.item_effect(worn, data.items)
			if worn != null else tr("ui.slot_empty")]
		var color: Color = UiTheme.TEXT_DIM
		if worn != null:
			color = BagPanel.TIER_COLORS.get(worn.tier, Color.WHITE) if worn.kind == Item.EQUIPMENT \
				else Color(data.items.fashion[worn.type_id]["color"])
		var style := StyleBoxFlat.new()
		style.bg_color = Color(color, 0.12)
		style.border_color = color
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(6)
		box.add_theme_stylebox_override("normal", style)
		box.pressed.connect(_open_picker.bind(box, slot))
		slot_boxes[slot] = box
		grid.add_child(box)
	page.add_child(_line("", tr("ui.slots_note")))


## The spare pieces for a slot (and Take off) under its box.
func _open_picker(box: Button, slot: String) -> void:
	var data := Session.data
	var synth := Session.state.synth_by_id(synth_id)
	_picker.clear()
	_picker_actions.clear()
	if Items.worn(synth, slot, data) != null:
		_picker.add_item(tr("ui.take_off"))
		_picker_actions.append(["off", slot])
	for item: Item in Session.state.inventory:
		if item.slot(data.items) == slot:
			_picker.add_item("%s — %s" % [UiText.item_name(item), UiText.item_effect(item, data.items)])
			_picker_actions.append(["wear", item.uid])
	if _picker_actions.is_empty():
		_picker.add_item(tr("ui.slot_nothing_spare"))
		_picker.set_item_disabled(0, true)
	_picker.position = Vector2i(box.get_screen_position() + Vector2(0, box.size.y))
	_picker.reset_size()
	_picker.popup()


func _on_pick(index: int) -> void:
	if index < 0 or index >= _picker_actions.size():
		return
	var action: Array = _picker_actions[index]
	if action[0] == "off":
		Session.act(GameLoop.unequip_item(Session.state, synth_id, action[1], Session.data))
	else:
		Session.act(GameLoop.equip_item(Session.state, synth_id, action[1], Session.data))


## A bold value and, under it, what it means.
func _line(value: String, meaning: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	if value != "":
		box.add_child(UiTheme.label(value, 18))
	if meaning != "":
		var help := UiTheme.label(meaning, 14, UiTheme.TEXT_DIM)
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help.custom_minimum_size = Vector2(470, 0)
		box.add_child(help)
	return box


func _clear(key: String) -> VBoxContainer:
	var page := _pages[key]
	for child: Node in page.get_children():
		page.remove_child(child)
		child.queue_free()
	return page


## Dragging the title bar moves the window, kept on screen.
func _drag(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var area := get_parent_area_size()
		position = (position + event.relative).clamp(Vector2.ZERO, (area - size).max(Vector2.ZERO))
