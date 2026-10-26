class_name GameScreen
extends Node
## One running game: the café view, the HUD, the night hub, the floor edit
## panel and the night report. Passes frame time to the Session and routes
## café clicks to the HUD.

signal quit_to_menu

var cafe := CafeView.new()
var hud := Hud.new()
var night := NightHub.new()
var edit_panel := EditPanel.new()
var report := ReportPanel.new()


func _ready() -> void:
	add_child(cafe)
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.shared()
	layer.add_child(root)
	root.add_child(night)
	root.add_child(edit_panel)
	root.add_child(hud)
	root.add_child(report)
	cafe.stove_clicked.connect(hud.open_recipe_menu)
	cafe.synth_clicked.connect(hud.open_synth_card)
	cafe.customer_clicked.connect(Session.convert_customer)
	cafe.editor_changed.connect(edit_panel.refresh)
	cafe.edit_exit_requested.connect(exit_edit)
	night.arrange_requested.connect(enter_edit)
	edit_panel.done.connect(exit_edit)
	hud.quit_to_menu.connect(func() -> void:
		exit_edit()
		SaveSystem.autosave(Session.state)
		quit_to_menu.emit())
	Session.phase_changed.connect(cafe.fit_camera)


func _process(delta: float) -> void:
	Session.tick(delta)


## Arranging the floor (night only): the hub steps aside for the edit panel.
func enter_edit() -> void:
	if Session.state.phase != GameState.Phase.NIGHT:
		return
	Session.editing = true
	cafe.editor = FloorEditor.new()
	night.visible = false
	edit_panel.open(cafe.editor)
	cafe.fit_camera(EditPanel.WIDTH + 30.0)


func exit_edit() -> void:
	if cafe.editor == null:
		return
	cafe.editor = null
	Session.editing = false
	edit_panel.visible = false
	night.visible = Session.state.phase == GameState.Phase.NIGHT
	night.refresh()
	cafe.fit_camera()
