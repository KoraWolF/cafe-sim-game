class_name GameScreen
extends Node
## One running game: the café view, the HUD, the night hub, the floor edit
## panel, the battle scenes and the night report. Passes frame time to the
## Session and routes café clicks to the HUD. After "End Night" the night's
## battles play first (the raid, then a MegaBean raid or Audit), then the report.

signal quit_to_menu

var cafe := CafeView.new()
var hud := Hud.new()
var night := NightHub.new()
var edit_panel := EditPanel.new()
var report := ReportPanel.new()
var battle := BattleView.new()
var tutorial_box := TutorialBox.new()
var settings := SettingsPanel.new()
## Battles still to play tonight, then the report.
var _battles: Array[Dictionary] = []
var _night_report: NightOps.Report = null


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
	root.add_child(battle)
	root.add_child(tutorial_box)
	root.add_child(settings)
	hud.settings_requested.connect(settings.open)
	if Session.state.day == 1 and Session.state.shift_time == 0 and not Settings.tutorial_done():
		tutorial_box.start(Tutorial.new())
	cafe.synth_clicked.connect(func(_synth_id: String) -> void: _tutorial_saw(Tutorial.OPENED_CARD))
	night.tab_shown.connect(func(key: String) -> void:
		if key == "menu":
			_tutorial_saw(Tutorial.SAW_MENU))
	battle.finished.connect(_play_next_battle)
	Session.night_resolved.connect(_on_night_resolved)
	cafe.stove_clicked.connect(hud.open_recipe_menu)
	cafe.synth_clicked.connect(hud.open_synth_card)
	cafe.customer_clicked.connect(hud.confirm_convert)
	cafe.customer_hovered.connect(hud.show_customer_card)
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


func _enter_tree() -> void:
	Sfx.music_for_phase()


func _tutorial_saw(flag: String) -> void:
	if tutorial_box.tutorial != null:
		tutorial_box.tutorial.seen[flag] = true


func _on_night_resolved(night_report: NightOps.Report) -> void:
	_night_report = night_report
	_battles.clear()
	if night_report.raid != null:
		var squad: Array[String] = []
		for fighter: Battle.Fighter in night_report.raid.attackers:
			squad.append(_synth_label(fighter.synth_id))
		_battles.append({"battle": night_report.raid, "attacks": true, "mine": squad, "theirs": _numbered("ui.battle_guard",
			night_report.raid.defenders.size()), "title": tr("ui.battle_raid") % UiText.name(night_report.raid_target)})
	if night_report.defense != null:
		var home: Array[String] = []
		for fighter: Battle.Fighter in night_report.defense.defenders:
			home.append(_synth_label(fighter.synth_id))
		_battles.append({"battle": night_report.defense, "attacks": false, "mine": home,
			"theirs": _numbered("ui.battle_auditor" if night_report.audit else "ui.battle_raider", night_report.defense.attackers.size()),
			"title": tr("ui.battle_audit") if night_report.audit else tr("ui.battle_defense")})
	Session.paused = true
	_play_next_battle()


func _play_next_battle() -> void:
	if _battles.is_empty():
		Sfx.music_for_phase()
		report.show_report(_night_report)
		return
	var next: Dictionary = _battles.pop_front()
	var mine: Array[String] = next["mine"]
	var theirs: Array[String] = next["theirs"]
	if next["attacks"]:
		battle.play(next["battle"], next["title"], true, mine, theirs)
	else:
		battle.play(next["battle"], next["title"], false, theirs, mine)


func _synth_label(synth_id: String) -> String:
	return Session.synth_names.get(synth_id, tr("ui.battle_gone"))


func _numbered(key: String, count: int) -> Array[String]:
	var names: Array[String] = []
	for i: int in count:
		names.append(tr(key) % (i + 1))
	return names


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
