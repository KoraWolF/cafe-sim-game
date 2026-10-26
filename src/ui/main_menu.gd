class_name MainMenu
extends Control
## Title screen: new game, continue (the autosave), load a slot, quit.

signal start_game

var _error := UiTheme.label("", 16, UiTheme.BAD)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.shared()
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(460, 0)
	centre.add_child(column)
	var title := UiTheme.label(tr("ui.title"), 64, UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var subtitle := UiTheme.label(tr("ui.subtitle"), 18, UiTheme.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	column.add_child(HSeparator.new())
	var new_game := UiTheme.button(tr("ui.new_game"), func() -> void:
		Session.new_game()
		start_game.emit())
	column.add_child(new_game)
	var resume := UiTheme.button(tr("ui.continue"), _load.bind(-1))
	resume.disabled = not SaveSystem.has_save(SaveSystem.autosave_path())
	column.add_child(resume)
	for slot: int in SaveSystem.SLOTS:
		var has := SaveSystem.has_save(SaveSystem.slot_path(slot))
		var load := UiTheme.button(tr("ui.load_slot") % (slot + 1) if has else tr("ui.empty_slot") % (slot + 1), _load.bind(slot))
		load.disabled = not has
		column.add_child(load)
	var settings := SettingsPanel.new()
	column.add_child(UiTheme.button(tr("ui.settings"), settings.open))
	column.add_child(UiTheme.button(tr("ui.quit"), get_tree().quit))
	column.add_child(_error)
	add_child(settings)
	(resume if not resume.disabled else new_game).grab_focus()
	Sfx.music("night")


func _load(slot: int) -> void:
	var errors := Session.load_game(slot)
	if errors.is_empty():
		start_game.emit()
	else:
		_error.text = tr("ui.load_failed") % ", ".join(errors)
