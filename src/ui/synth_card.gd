class_name SynthCard
extends PanelContainer
## A Synth's details (species, trait, level, XP, battery) and its role buttons.

var synth_id: String = ""
## The name; editable only after clicking the pencil next to it.
var _title := LineEdit.new()
var _edit := Button.new()
var _details := UiTheme.label("", 16)
var _xp := ProgressBar.new()
var _battery := ProgressBar.new()
var _roles: Dictionary[String, Button] = {}
var _role_help := UiTheme.label("", 14, UiTheme.TEXT_DIM)
var _about := UiTheme.label("", 14, UiTheme.TEXT_DIM)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	# Grows to the left from 20 px off the right edge, however wide it gets.
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -20
	offset_left = -20
	custom_minimum_size = Vector2(360, 0)
	var column := VBoxContainer.new()
	add_child(column)
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", UiTheme.PANEL_BORDER)
	_title.max_length = GameLoop.MAX_NAME_LENGTH
	_title.placeholder_text = tr("ui.card_rename_hint")
	_title.tooltip_text = tr("ui.card_rename_hint")
	_title.editable = false
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.text_submitted.connect(_rename)
	_title.focus_exited.connect(func() -> void: _rename(_title.text))
	_edit.custom_minimum_size = Vector2(36, 36)
	_edit.tooltip_text = tr("ui.card_rename_hint")
	_edit.focus_mode = Control.FOCUS_NONE
	_edit.pressed.connect(_start_rename)
	_edit.draw.connect(_draw_pencil)
	var name_row := HBoxContainer.new()
	name_row.add_child(_title)
	name_row.add_child(_edit)
	column.add_child(name_row)
	column.add_child(_details)
	for bar: ProgressBar in [_xp, _battery]:
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
	column.add_child(_xp)
	column.add_child(_battery)
	for help: Label in [_about, _role_help]:
		help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help.custom_minimum_size = Vector2(320, 0)
	column.add_child(_about)
	column.add_child(UiTheme.label(tr("ui.card_role"), 16, UiTheme.TEXT_DIM))
	var roles := HBoxContainer.new()
	column.add_child(roles)
	for role: String in Synth.ROLES:
		var button := UiTheme.button(UiText.role(role), _set_role.bind(role))
		button.toggle_mode = true
		button.tooltip_text = tr("tip.role." + role)
		_roles[role] = button
		roles.add_child(button)
	column.add_child(_role_help)
	column.add_child(UiTheme.button(tr("ui.close"), func() -> void: visible = false))


func refresh() -> void:
	var synth := Session.state.synth_by_id(synth_id)
	if synth == null:
		visible = false
		return
	var data := Session.data
	var b := data.balance
	var battery_max := SynthStats.stat(synth, "battery_max", data)
	if not _title.has_focus():
		_title.text = Session.synth_name(synth)
		_title.editable = false
	var trait_text := tr("ui.card_trait") % UiText.name(synth.trait_id) if synth.trait_id != "" else tr("ui.card_no_trait")
	var xp_text := tr("ui.card_xp") % [synth.xp, Leveling.xp_to_next(synth.level, b)] \
		if synth.level < b.max_synth_level else tr("ui.card_xp_max")
	_details.text = "%s\n%s\n%s   %s\n%s" % [UiText.name(synth.species_id), trait_text, tr("ui.card_level") % synth.level,
		xp_text, tr("ui.card_battery") % [SynthStats.battery_percent(synth, data), roundi(battery_max)]]
	_xp.max_value = Leveling.xp_to_next(synth.level, b)
	_xp.value = synth.xp if synth.level < b.max_synth_level else _xp.max_value
	_battery.max_value = battery_max
	_battery.value = synth.battery
	for role: String in _roles:
		_roles[role].set_pressed_no_signal(role == synth.role)
	_role_help.text = tr("ui.card_role_now") % [UiText.role(synth.role), tr("tip.role." + synth.role)]
	var about: Array[String] = [tr("species.%s.desc" % synth.species_id)]
	if synth.trait_id != "":
		about.append(tr("trait.%s.desc" % synth.trait_id))
	about.append(tr("ui.card_stats") % [SynthStats.speed(synth, data), roundi(100.0 * SynthStats.stat(synth, "cook", data)),
		roundi(100.0 * SynthStats.stat(synth, "appeal", data)), roundi(SynthStats.stat(synth, "power", data)),
		roundi(SynthStats.stat(synth, "hp", data))])
	_about.text = "\n".join(about)
	_about.tooltip_text = tr("ui.card_power_help")
	_about.mouse_filter = Control.MOUSE_FILTER_PASS


func _start_rename() -> void:
	_title.editable = true
	_title.grab_focus()
	_title.edit()  # focus alone does not start typing
	_title.select_all()


func _rename(new_name: String) -> void:
	var synth := Session.state.synth_by_id(synth_id)
	if synth == null or not _title.editable:
		return
	if new_name.strip_edges() == Session.synth_name(synth) or Session.act(GameLoop.rename_synth(Session.state, synth_id, new_name)):
		_title.editable = false
		_title.release_focus()
	refresh()


## A pencil drawn on the edit button.
func _draw_pencil() -> void:
	var centre := _edit.size * 0.5
	var along := Vector2(1, -1).normalized()
	var across := Vector2(1, 1).normalized()
	var tip := centre - along * 10.0
	var back := centre + along * 9.0
	var color := UiTheme.PANEL_BORDER
	_edit.draw_colored_polygon(PackedVector2Array([tip, tip + along * 5.0 + across * 3.5, tip + along * 5.0 - across * 3.5]), color)
	_edit.draw_line(tip + along * 5.0, back, color, 7.0)
	_edit.draw_line(back, back + along * 3.0, Color(color, 0.5), 7.0)


func _set_role(role: String) -> void:
	Session.act(GameLoop.assign_role(Session.state, synth_id, role))
	refresh()
