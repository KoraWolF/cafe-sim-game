class_name NoticePanel
extends Modal
## A one-button screen over the game: a title, a few coloured lines and
## Continue. Used before a MegaBean raid on the café (who defends) and after
## every battle (the result, loot or losses, XP).

signal continued

var _title := UiTheme.label("", 30, UiTheme.PANEL_BORDER)
var _lines := VBoxContainer.new()
var _continue := UiTheme.button(tr("ui.battle_continue"), _on_continue)


func _ready() -> void:
	super._ready()
	panel.custom_minimum_size = Vector2(620, 0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	content.add_child(HSeparator.new())
	_lines.add_theme_constant_override("separation", 8)
	content.add_child(_lines)
	_continue.custom_minimum_size = Vector2(0, 50)
	content.add_child(_continue)


## Shows title and lines ([text, colour] each); Continue emits continued.
func show_notice(title: String, title_color: Color, lines: Array[Array]) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", title_color)
	for child: Node in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	for line: Array in lines:
		var label := UiTheme.label(line[0], 18, line[1])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(580, 0)
		_lines.add_child(label)
	show_modal()
	_continue.grab_focus()


func _on_continue() -> void:
	hide_modal()
	continued.emit()
