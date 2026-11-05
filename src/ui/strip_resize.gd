class_name StripResize
extends RefCounted
## Lets the player drag the top edge of a bottom menu (Shop, Bag, Arrange) to
## change its height: never below MIN_SHARE of the screen, nor above MAX_SHARE.
## A small grip is drawn on the edge. Each menu keeps its own height.

const MIN_SHARE: float = 0.2
const MAX_SHARE: float = 0.75
## How tall the grabbable edge is (px).
const GRIP: float = 12.0

## The menu's height now.
var height: float = 0.0
var _panel: Control = null
var _on_change: Callable
var _dragging: bool = false


## Attaches to a bottom menu with its starting height; on_change runs after every resize.
static func attach(panel: Control, start_height: float, on_change: Callable) -> StripResize:
	var resize := StripResize.new()
	resize.height = start_height
	resize._panel = panel
	resize._on_change = on_change
	panel.gui_input.connect(resize._on_input)
	panel.draw.connect(resize._draw_grip)
	panel.mouse_default_cursor_shape = Control.CURSOR_ARROW
	return resize


## Sets the height, kept between the limits, and moves the menu's top edge.
func set_height(value: float) -> void:
	var screen := _panel.get_viewport_rect().size.y
	height = clampf(value, screen * MIN_SHARE, screen * MAX_SHARE)
	_panel.offset_top = -height - 12.0
	_on_change.call()


func _on_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed and button.position.y <= GRIP:
			_dragging = true
			_panel.accept_event()
		elif not button.pressed and _dragging:
			_dragging = false
			_panel.accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_panel.mouse_default_cursor_shape = Control.CURSOR_VSIZE if motion.position.y <= GRIP or _dragging else Control.CURSOR_ARROW
		if _dragging:
			set_height(height - motion.relative.y)
			_panel.accept_event()


func _draw_grip() -> void:
	var middle := _panel.size.x * 0.5
	_panel.draw_line(Vector2(middle - 36, 5), Vector2(middle + 36, 5), Color(UiTheme.PANEL_BORDER, 0.7), 3.0)
