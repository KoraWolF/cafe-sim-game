class_name UnitDetails
extends PanelContainer
## A Synth's details in a window the player can drag by its title: Work (best
## role, speed, cooking, appeal), Fight (power, HP, strength now), Trait
## (trait and species), Fashion and Equipment.
## Each number comes with a line on what it does. Fashion and Equipment wear
## and take off pieces; EXP bottles are drunk from the Equipment tab.

var synth_id: String = ""
var _title := UiTheme.label("", 22, UiTheme.PANEL_BORDER)
var _header := HBoxContainer.new()
var _tabs := TabContainer.new()
var _pages: Dictionary[String, VBoxContainer] = {}
var _dragging := false


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(520, 420)
	position = Vector2(420, 140)
	var column := VBoxContainer.new()
	add_child(column)
	_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_header.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_header.tooltip_text = tr("ui.details_drag")
	_header.gui_input.connect(_drag)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(_title)
	_header.add_child(UiTheme.button(tr("ui.close"), func() -> void: visible = false))
	column.add_child(_header)
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
	_fill_slots(_clear("fashion"), synth, Item.FASHION_SLOTS, Item.FASHION)
	var gear := _clear("gear")
	_fill_slots(gear, synth, Item.EQUIPMENT_SLOTS, Item.EQUIPMENT)
	gear.add_child(HSeparator.new())
	gear.add_child(UiTheme.label(tr("ui.bottles_title"), 18, UiTheme.PANEL_BORDER))
	if Session.state.bottles.is_empty():
		gear.add_child(_line("", tr("ui.bottles_none")))
	for bottle_id: String in Session.state.bottles:
		var use := UiTheme.button(tr("ui.bottle_use") % [UiText.name(bottle_id), data.items.bottles[bottle_id]["xp"],
			Session.state.bottles[bottle_id]], func() -> void:
				var level_ups: Dictionary[String, int] = {}
				if Session.act(GameLoop.use_bottle(Session.state, synth_id, bottle_id, Session.data, level_ups)) and level_ups.has(synth_id):
					Session.toast.emit(tr("ui.level_up") % [Session.synth_name(synth), level_ups[synth_id]]))
		gear.add_child(use)


## Each slot: what is worn (and Take off), then the inventory pieces for it (Wear).
func _fill_slots(page: VBoxContainer, synth: Synth, slots: Array[String], kind: String) -> void:
	var data := Session.data
	var state := Session.state
	for slot: String in slots:
		var row := HBoxContainer.new()
		var worn := Items.worn(synth, slot, data)
		var text := "%s: %s" % [tr("slot." + slot), UiText.item_name(worn) + " (" + UiText.item_effect(worn, data.items) + ")"
			if worn != null else tr("ui.slot_empty")]
		var label := UiTheme.label(text, 17)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if worn != null:
			row.add_child(UiTheme.button(tr("ui.take_off"), func() -> void:
				Session.act(GameLoop.unequip_item(Session.state, synth_id, slot, Session.data))))
		page.add_child(row)
		for item: Item in state.inventory:
			if item.kind != kind or item.slot(data.items) != slot:
				continue
			var option := HBoxContainer.new()
			var name := UiTheme.label("    %s — %s" % [UiText.item_name(item), UiText.item_effect(item, data.items)], 15, UiTheme.TEXT_DIM)
			name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			option.add_child(name)
			option.add_child(UiTheme.button(tr("ui.wear"), func() -> void:
				Session.act(GameLoop.equip_item(Session.state, synth_id, item.uid, Session.data))))
			page.add_child(option)
	if not state.inventory.any(func(item: Item) -> bool: return item.kind == kind):
		page.add_child(_line("", tr("ui.nothing_to_wear_" + kind)))


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
