class_name SynthCard
extends PanelContainer
## A worker at a glance: name (pencil to rename), species and best role, trait,
## level and XP, HP, battery and max battery, role buttons, and Details (the
## Work, Fight, Trait and gear tabs). Explanations live in the Details window
## and the Info button.

signal details_requested(synth_id: String)

var synth_id: String = ""
## The name; editable only after clicking the pencil next to it.
var _title := LineEdit.new()
var _edit := Button.new()
var _core := UiTheme.label("", 16)
var _level := UiTheme.label("", 16)
var _xp := ProgressBar.new()
var _hp := UiTheme.label("", 16)
var _battery_text := UiTheme.label("", 16)
var _battery := ProgressBar.new()
var _roles: Dictionary[String, Button] = {}


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
	for bar: ProgressBar in [_xp, _battery]:
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
	for control: Control in [_core, _level, _xp, _hp, _battery_text, _battery]:
		column.add_child(control)
	column.add_child(UiTheme.label(tr("ui.card_role"), 16, UiTheme.TEXT_DIM))
	var roles := HBoxContainer.new()
	column.add_child(roles)
	for role: String in Synth.ROLES:
		var button := UiTheme.button(UiText.role(role), _set_role.bind(role))
		button.toggle_mode = true
		button.tooltip_text = tr("tip.role." + role)
		_roles[role] = button
		roles.add_child(button)
	var buttons := HBoxContainer.new()
	var details := UiTheme.button(tr("ui.details"), func() -> void: details_requested.emit(synth_id))
	var close := UiTheme.button(tr("ui.close"), func() -> void: visible = false)
	for button: Button in [details, close]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(button)
	column.add_child(buttons)


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
	var trait_text := UiText.name(synth.trait_id) if synth.trait_id != "" else tr("ui.card_no_trait")
	_core.text = tr("ui.card_core") % [UiText.name(synth.species_id), UiText.role(data.species[synth.species_id].best_role), trait_text]
	var xp_text := tr("ui.card_xp") % [synth.xp, Leveling.xp_to_next(synth.level, b)] \
		if synth.level < b.max_synth_level else tr("ui.card_xp_max")
	_level.text = "%s   %s" % [tr("ui.card_level") % synth.level, xp_text]
	_hp.text = tr("ui.card_hp") % roundi(SynthStats.stat(synth, "hp", data))
	_battery_text.text = tr("ui.card_battery") % [SynthStats.battery_percent(synth, data), roundi(battery_max)]
	_xp.max_value = Leveling.xp_to_next(synth.level, b)
	_xp.value = synth.xp if synth.level < b.max_synth_level else _xp.max_value
	_battery.max_value = battery_max
	_battery.value = synth.battery
	for role: String in _roles:
		_roles[role].set_pressed_no_signal(role == synth.role)


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
