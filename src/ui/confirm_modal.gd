class_name ConfirmModal
extends Modal
## A yes/no question over a masked, paused game (e.g. spending NanoBrew).

var _question := UiTheme.label("", 20)
var _details := UiTheme.label("", 16, UiTheme.TEXT_DIM)
var _yes := UiTheme.button("", _answer.bind(true))
var _no := UiTheme.button(tr("ui.cancel"), _answer.bind(false))
var _on_yes: Callable
var _was_paused := false


func _ready() -> void:
	super._ready()
	panel.custom_minimum_size = Vector2(560, 0)
	for label: Label in [_question, _details]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(520, 0)
		content.add_child(label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	for button: Button in [_no, _yes]:
		button.custom_minimum_size = Vector2(150, 46)
		buttons.add_child(button)
	content.add_child(buttons)


## Shows the question; on_yes runs only if the player confirms. Time stops meanwhile.
func ask(question: String, details: String, yes_text: String, on_yes: Callable) -> void:
	_question.text = question
	_details.text = details
	_yes.text = yes_text
	_on_yes = on_yes
	var session := get_node_or_null("/root/Session")
	_was_paused = session.paused if session != null else false
	if session != null:
		session.paused = true
	show_modal()
	_yes.grab_focus()


func _answer(yes: bool) -> void:
	hide_modal()
	var session := get_node_or_null("/root/Session")
	if session != null:
		session.paused = _was_paused
	if yes and _on_yes.is_valid():
		_on_yes.call()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and (event as InputEventKey).keycode == KEY_ESCAPE:
		_answer(false)
		get_viewport().set_input_as_handled()
