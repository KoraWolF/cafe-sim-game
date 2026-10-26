class_name SettingsPanel
extends PanelContainer
## Volume sliders (Master, Music, SFX, UI) saved as they move, and a button
## to replay the guided first day on the next new game.

signal closed

var _sliders: Dictionary[String, HSlider] = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(520, 0)
	visible = false
	var column := VBoxContainer.new()
	add_child(column)
	column.add_child(UiTheme.label(tr("ui.settings"), 28, UiTheme.PANEL_BORDER))
	var grid := GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	for bus: String in Settings.BUSES:
		grid.add_child(UiTheme.label(tr("ui.volume_" + bus.to_lower())))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.custom_minimum_size = Vector2(300, 28)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(func(value: float) -> void: Settings.set_volume(bus, value))
		slider.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("ui_click"))
		_sliders[bus] = slider
		grid.add_child(slider)
	column.add_child(HSeparator.new())
	column.add_child(UiTheme.button(tr("ui.replay_tutorial"), func() -> void:
		Settings.set_tutorial_done(false)
		var session := get_node_or_null("/root/Session")
		if session != null:
			session.toast.emit(tr("ui.tutorial_next_game"))))
	column.add_child(UiTheme.button(tr("ui.close"), close))


func open() -> void:
	for bus: String in _sliders:
		_sliders[bus].set_value_no_signal(Settings.volume(bus))
	visible = true
	reset_size()
	position = (get_parent_area_size() - size) * 0.5


func close() -> void:
	visible = false
	closed.emit()
