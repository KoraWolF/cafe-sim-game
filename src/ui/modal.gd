class_name Modal
extends Control
## A pop-up over the whole screen: a dark mask that blocks clicks to the game
## behind it, and a centred panel. Subclasses fill `content`.

const MASK := Color(0.03, 0.02, 0.08, 0.72)

## Put the pop-up's controls in here.
var content := VBoxContainer.new()
var panel := PanelContainer.new()


func _init() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var mask := ColorRect.new()
	mask.color = MASK
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mask)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	centre.add_child(panel)
	panel.add_child(content)


func _ready() -> void:
	# Fill the parent even when added after the parent was laid out.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func show_modal() -> void:
	visible = true
	move_to_front()


func hide_modal() -> void:
	visible = false
