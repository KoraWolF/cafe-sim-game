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
var shop := ShopPanel.new()
var quests := QuestPanel.new()
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
	root.add_child(shop)
	root.add_child(quests)
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
	cafe.counter_clicked.connect(hud.confirm_throw)
	cafe.synth_clicked.connect(hud.open_synth_card)
	cafe.customer_clicked.connect(hud.confirm_convert)
	cafe.customer_hovered.connect(hud.show_customer_card)
	cafe.editor_changed.connect(edit_panel.refresh)
	cafe.edit_exit_requested.connect(exit_edit)
	hud.shop_requested.connect(open_shop)
	hud.quests_requested.connect(open_quests)
	quests.closed.connect(_layout)
	hud.arrange_requested.connect(enter_edit)
	shop.arrange_requested.connect(enter_edit)
	shop.closed.connect(_layout)
	edit_panel.done.connect(exit_edit)
	hud.quit_to_menu.connect(func() -> void:
		exit_edit()
		SaveSystem.autosave(Session.state)
		quit_to_menu.emit())
	Session.phase_changed.connect(_layout)


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
	if Session.auto_running and _battles.is_empty():
		# A quiet night on Auto: no report, the next shift just carries on.
		Session.toast.emit(tr("ui.auto_night_done") % night_report.income if night_report.income > 0 else tr("ui.auto_night_done_plain"))
		Sfx.music_for_phase()
		return
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


## Arranging the floor, at any time (the café keeps running in a shift): the
## shop or night hub steps aside for the edit panel.
func enter_edit() -> void:
	if cafe.editor != null:
		return
	shop.visible = false
	quests.visible = false
	Session.editing = true
	cafe.editor = FloorEditor.new()
	edit_panel.open(cafe.editor)
	_layout()


func exit_edit() -> void:
	if cafe.editor == null:
		return
	cafe.editor = null
	Session.editing = false
	edit_panel.visible = false
	night.refresh()
	_layout()


## The shop, at any time; toggles from the top bar.
func open_shop() -> void:
	if shop.visible:
		shop.close()
		return
	exit_edit()
	quests.visible = false
	shop.open()
	_layout()


## Quests, at any time; toggles from the top bar.
func open_quests() -> void:
	if quests.visible:
		quests.close()
		return
	exit_edit()
	shop.visible = false
	quests.open()
	_layout()


## One panel on the right at a time: the edit panel, else the shop or quests,
## else the night hub at night. The camera fits the café beside it.
func _layout() -> void:
	night.visible = Session.state.phase == GameState.Phase.NIGHT and cafe.editor == null and not shop.visible \
		and not quests.visible
	if night.visible:
		night.refresh()
	var panel := 0.0
	if cafe.editor != null:
		panel = EditPanel.WIDTH + 30.0
	elif shop.visible:
		panel = ShopPanel.WIDTH + 30.0
	elif quests.visible:
		panel = QuestPanel.WIDTH + 30.0
	elif night.visible:
		panel = CafeView.NIGHT_PANEL
	cafe.fit_camera(panel)
	hud.set_right_inset(panel)
