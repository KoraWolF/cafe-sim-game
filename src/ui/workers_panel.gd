class_name WorkersPanel
extends PanelContainer
## The Workers list on the left, under the quests: each worker's name, job and
## battery. Click a name to pick the worker (as clicking it in the café does:
## then click a place for its job); or choose a job from its menu (a Chef or
## Cashier takes a free stove or register). The header folds the list away.

## A worker's name was clicked.
signal picked(synth_id: String)

const WIDTH: float = 330.0

var _header := Button.new()
var _rows := VBoxContainer.new()
var _open: bool = true
## What the rows show now (rebuilt only when it changes, so a click lands).
var _key: String = ""
var _battery: Dictionary[String, Label] = {}


func _ready() -> void:
	custom_minimum_size = Vector2(WIDTH, 0)
	var column := VBoxContainer.new()
	add_child(column)
	_header.flat = true
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.add_theme_font_size_override("font_size", 15)
	_header.pressed.connect(func() -> void:
		_open = not _open
		_key = ""
		refresh())
	column.add_child(_header)
	_rows.add_theme_constant_override("separation", 2)
	column.add_child(_rows)
	Session.state_changed.connect(refresh)


func refresh() -> void:
	if not Session.has_game():
		return
	var state := Session.state
	var data := Session.data
	_header.text = tr("ui.workers_title") % state.synths.size() + (" ▾" if _open else " ▸")
	var key := str(_open) + ":" + ",".join(state.synths.map(func(synth: Synth) -> String:
		return synth.id + synth.role + synth.name))
	if key != _key:
		_key = key
		_build(state)
	for synth: Synth in state.synths:
		if _battery.has(synth.id):
			_battery[synth.id].text = "%d%%" % SynthStats.battery_percent(synth, data) if synth.ko_left <= 0 \
				else tr("ui.workers_ko") % UiText.clock(synth.ko_left)


func _build(state: GameState) -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_battery.clear()
	_rows.visible = _open
	if not _open:
		return
	for synth: Synth in state.synths:
		var row := HBoxContainer.new()
		var name := UiTheme.button(Session.synth_name(synth), picked.emit.bind(synth.id))
		name.flat = true
		name.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.add_theme_font_size_override("font_size", 14)
		name.add_theme_color_override("font_color", UiTheme.SPECIES_GLOW.get(synth.species_id, UiTheme.TEXT))
		row.add_child(name)
		var job := OptionButton.new()
		job.add_theme_font_size_override("font_size", 13)
		for role: String in Synth.ROLES:
			job.add_item(UiText.role(role))
			job.set_item_metadata(job.item_count - 1, role)
		job.select(Synth.ROLES.find(synth.role))
		job.disabled = synth.ko_left > 0
		job.item_selected.connect(_set_job.bind(synth.id))
		row.add_child(job)
		var battery := UiTheme.label("", 13, UiTheme.TEXT_DIM)
		battery.custom_minimum_size = Vector2(44, 0)
		battery.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_battery[synth.id] = battery
		row.add_child(battery)
		_rows.add_child(row)


func _set_job(index: int, synth_id: String) -> void:
	var role: String = Synth.ROLES[index]
	if Session.act(GameLoop.assign_role(Session.state, synth_id, role, Session.data)):
		var synth := Session.state.synth_by_id(synth_id)
		Session.toast.emit(tr("ui.job_now") % [Session.synth_name(synth), UiText.role(synth.role)])
	else:
		_key = ""  # put the menu back to the job it has
		refresh()
