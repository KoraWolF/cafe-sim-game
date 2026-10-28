class_name MainMenu
extends Control
## Title screen: new game, continue (the autosave), load a slot (each shows
## what is in it and can be deleted), settings, quit.

signal start_game

var _error := UiTheme.label("", 16, UiTheme.BAD)
var _saves := VBoxContainer.new()
var _confirm := ConfirmModal.new()


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
	column.add_child(_saves)
	_fill_saves()
	var settings := SettingsPanel.new()
	column.add_child(UiTheme.button(tr("ui.settings"), settings.open))
	column.add_child(UiTheme.button(tr("ui.quit"), get_tree().quit))
	column.add_child(_error)
	add_child(settings)
	add_child(_confirm)
	var resume: Button = _saves.get_child(0).get_child(0).get_child(0)
	(resume if not resume.disabled else new_game).grab_focus()
	Sfx.music("night")


## The autosave (Continue) and each slot: a load button, a delete button and
## what the save holds.
func _fill_saves() -> void:
	for child: Node in _saves.get_children():
		_saves.remove_child(child)
		child.queue_free()
	for slot: int in range(-1, SaveSystem.SLOTS):
		var path := SaveSystem.autosave_path() if slot < 0 else SaveSystem.slot_path(slot)
		var info := SaveSystem.summary(path)
		var has := SaveSystem.has_save(path)
		var title := tr("ui.continue") if slot < 0 else (tr("ui.load_slot") % (slot + 1) if has else tr("ui.empty_slot") % (slot + 1))
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)
		var row := HBoxContainer.new()
		var load_button := UiTheme.button(title, _load.bind(slot))
		load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		load_button.disabled = not has
		row.add_child(load_button)
		var delete := UiTheme.button(tr("ui.delete_save"), _ask_delete.bind(slot, path))
		delete.disabled = not has
		row.add_child(delete)
		entry.add_child(row)
		if not info.is_empty():
			entry.add_child(UiTheme.label(save_line(info), 15, UiTheme.TEXT_DIM))
		elif has:
			entry.add_child(UiTheme.label(tr("ui.save_unreadable"), 15, UiTheme.BAD))
		_saves.add_child(entry)


## "Day 5 · Alley · 1234 coins · 4 staff · saved 2026-10-28 14:02" (local time).
static func save_line(info: Dictionary) -> String:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0)
	var saved := Time.get_datetime_string_from_unix_time(int(info["saved_at"]) + bias * 60, true).left(16)
	return TranslationServer.translate("ui.save_details") % [info["day"], UiText.name(info["district_id"]), info["coins"],
		info["staff"], saved]


func _ask_delete(slot: int, path: String) -> void:
	var which := tr("ui.autosave") if slot < 0 else tr("ui.slot_name") % (slot + 1)
	_confirm.ask(tr("ui.confirm_delete_save") % which, tr("ui.confirm_delete_save_details"), tr("ui.delete_save"),
		func() -> void:
			SaveSystem.delete_save(path)
			_fill_saves())


func _load(slot: int) -> void:
	var errors := Session.load_game(slot)
	if errors.is_empty():
		start_game.emit()
	else:
		_error.text = tr("ui.load_failed") % ", ".join(errors)
