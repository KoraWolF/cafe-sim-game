class_name TutorialBox
extends PanelContainer
## Shows the guided first day's current tip above the bottom of the screen,
## with Next (steps without a goal), Skip step and Skip tutorial. Checks the
## goals every frame; finishing or skipping marks the tutorial done.

var tutorial: Tutorial = null
## Height of a strip open at the bottom (the Menu, Bag or Arrange): the box sits above it.
var bottom_inset: float = 0.0
var _text := UiTheme.label("", 20)
var _counter := UiTheme.label("", 14, UiTheme.TEXT_DIM)
var _next := UiTheme.button(tr("tutorial.next"), _on_next)
var _skip_step := UiTheme.button(tr("tutorial.skip_step"), _on_next)
var _skip_all := UiTheme.button(tr("tutorial.skip_all"), _on_skip_all)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	custom_minimum_size = Vector2(640, 0)
	visible = false
	var column := VBoxContainer.new()
	add_child(column)
	var header := HBoxContainer.new()
	var title := UiTheme.label(tr("tutorial.title"), 16, UiTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_counter)
	column.add_child(header)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(600, 0)
	column.add_child(_text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	for button: Button in [_skip_all, _skip_step, _next]:
		buttons.add_child(button)
	column.add_child(buttons)


func start(with_tutorial: Tutorial) -> void:
	tutorial = with_tutorial


func _process(_delta: float) -> void:
	var session := get_node_or_null("/root/Session")
	if tutorial == null or session == null or not session.has_game():
		visible = false
		return
	if tutorial.update(session.state, session.day_log):
		Sfx.play("star")
	if tutorial.finished:
		Settings.set_tutorial_done(true)
		tutorial = null
		visible = false
		return
	var key := tutorial.text_key(session.state)
	visible = key != "" and not session.editing
	if not visible:
		return
	_text.text = tr(key)
	_counter.text = "%d / %d" % [tutorial.step + 1, tutorial.step_count()]
	_next.visible = tutorial.waits_for_next()
	_skip_step.visible = not tutorial.waits_for_next()
	reset_size()
	# Centred in the space left free: left of the night hub, above a strip at the bottom.
	var area := get_parent_area_size()
	var width := area.x - (CafeView.NIGHT_PANEL if session.state.phase == GameState.Phase.NIGHT else 0.0)
	position = Vector2((width - size.x) * 0.5, area.y - size.y - 24 - bottom_inset)


func _on_next() -> void:
	tutorial.next()


func _on_skip_all() -> void:
	tutorial.skip_all()
