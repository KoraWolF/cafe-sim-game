class_name GameScreen
extends Node
## One running game: the café view, the HUD, the night hub and the night report.
## Passes frame time to the Session and routes café clicks to the HUD.

signal quit_to_menu

var cafe := CafeView.new()
var hud := Hud.new()
var night := NightHub.new()
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
	root.add_child(hud)
	root.add_child(report)
	cafe.stove_clicked.connect(hud.open_recipe_menu)
	cafe.synth_clicked.connect(hud.open_synth_card)
	cafe.customer_clicked.connect(Session.convert_customer)
	hud.quit_to_menu.connect(func() -> void:
		SaveSystem.autosave(Session.state)
		quit_to_menu.emit())
	Session.phase_changed.connect(cafe.fit_camera)


func _process(delta: float) -> void:
	Session.tick(delta)
