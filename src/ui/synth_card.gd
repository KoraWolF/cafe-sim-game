class_name SynthCard
extends PanelContainer
## A Synth's details (species, trait, level, XP, battery) and its role buttons.

var synth_id: String = ""
var _title := UiTheme.label("", 22, UiTheme.PANEL_BORDER)
var _details := UiTheme.label("", 16)
var _xp := ProgressBar.new()
var _battery := ProgressBar.new()
var _roles: Dictionary[String, Button] = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	position.x -= 340
	custom_minimum_size = Vector2(320, 0)
	var column := VBoxContainer.new()
	add_child(column)
	column.add_child(_title)
	column.add_child(_details)
	for bar: ProgressBar in [_xp, _battery]:
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
	column.add_child(_xp)
	column.add_child(_battery)
	column.add_child(UiTheme.label(tr("ui.card_role"), 16, UiTheme.TEXT_DIM))
	var roles := HBoxContainer.new()
	column.add_child(roles)
	for role: String in Synth.ROLES:
		var button := UiTheme.button(UiText.role(role), _set_role.bind(role))
		button.toggle_mode = true
		button.tooltip_text = tr("tip.role." + role)
		_roles[role] = button
		roles.add_child(button)
	column.add_child(UiTheme.button(tr("ui.close"), func() -> void: visible = false))


func refresh() -> void:
	var synth := Session.state.synth_by_id(synth_id)
	if synth == null:
		visible = false
		return
	var data := Session.data
	var b := data.balance
	var battery_max := SynthStats.stat(synth, "battery_max", data)
	_title.text = Session.synth_name(synth)
	var trait_text := tr("ui.card_trait") % UiText.name(synth.trait_id) if synth.trait_id != "" else tr("ui.card_no_trait")
	var xp_text := tr("ui.card_xp") % [synth.xp, Leveling.xp_to_next(synth.level, b)] \
		if synth.level < b.max_synth_level else tr("ui.card_xp_max")
	_details.text = "%s\n%s\n%s   %s\n%s" % [UiText.name(synth.species_id), trait_text, tr("ui.card_level") % synth.level,
		xp_text, tr("ui.card_battery") % [roundi(synth.battery), roundi(battery_max)]]
	_xp.max_value = Leveling.xp_to_next(synth.level, b)
	_xp.value = synth.xp if synth.level < b.max_synth_level else _xp.max_value
	_battery.max_value = battery_max
	_battery.value = synth.battery
	for role: String in _roles:
		_roles[role].set_pressed_no_signal(role == synth.role)


func _set_role(role: String) -> void:
	Session.act(GameLoop.assign_role(Session.state, synth_id, role))
	refresh()
