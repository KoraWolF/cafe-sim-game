class_name UnitDetails
extends PanelContainer
## A Synth's details in a window the player can drag by its title: Work (best
## role, speed, cooking, appeal), Fight (power, HP, strength now), Trait
## (trait and species), and Fashion and Equipment (filled by the items update).
## Each number comes with a line on what it does.

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
	for key: String in ["fashion", "gear"]:
		_clear(key).add_child(_line("", tr("ui.gear_soon")))


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
