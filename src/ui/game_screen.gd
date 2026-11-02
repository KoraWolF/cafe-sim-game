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
var bag := BagPanel.new()
var report := ReportPanel.new()
## The warning before a MegaBean raid on the café, and each battle's results.
var notice := NoticePanel.new()
var battle := BattleView.new()
var tutorial_box := TutorialBox.new()
var settings := SettingsPanel.new()
## Battles still to play tonight, then the report.
var _battles: Array[Dictionary] = []
var _night_report: NightOps.Report = null
## The battle playing now (an entry of _battles), and what Continue on the notice does next.
var _current_battle: Dictionary = {}
var _after_notice: Callable
## Arrange was opened by "Buy": go back to the Shop when the piece is placed.
var _back_to_shop := false
## [piece id, how many were placed] when it was bought.
var _bought: Array = []


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
	root.add_child(bag)
	root.add_child(hud)
	root.add_child(report)
	root.add_child(battle)
	root.add_child(tutorial_box)
	root.add_child(notice)
	root.add_child(settings)
	hud.settings_requested.connect(settings.open)
	if Session.state.day == 1 and Session.state.shift_time == 0 and not Settings.tutorial_done():
		tutorial_box.start(Tutorial.new())
	cafe.synth_clicked.connect(func(_synth_id: String) -> void: _tutorial_saw(Tutorial.OPENED_CARD))
	battle.finished.connect(_show_result)
	notice.continued.connect(func() -> void:
		if _after_notice.is_valid():
			_after_notice.call())
	Session.night_resolved.connect(_on_night_resolved)
	cafe.stove_clicked.connect(hud.open_recipe_menu)
	cafe.counter_clicked.connect(hud.confirm_throw)
	cafe.synth_clicked.connect(func(synth_id: String) -> void:
		cafe.selected_synth = synth_id
		hud.open_synth_card(synth_id))
	cafe.job_clicked.connect(_give_job)
	cafe.swap_clicked.connect(_swap_jobs)
	hud.workers.picked.connect(func(synth_id: String) -> void:
		var picked := Session.state.synth_by_id(cafe.selected_synth)
		var other := Session.state.synth_by_id(synth_id)
		# Same as in the café: one working and one resting swap, else pick this one.
		if picked != null and picked != other and (picked.role == Synth.REST) != (other.role == Synth.REST):
			_swap_jobs(picked.id, synth_id)
			return
		cafe.selected_synth = synth_id
		hud.open_synth_card(synth_id))
	cafe.blank_clicked.connect(hud.close_synth_card)
	hud.card_closed.connect(func() -> void: cafe.selected_synth = "")
	cafe.customer_clicked.connect(hud.confirm_convert)
	cafe.customer_hovered.connect(hud.show_customer_card)
	cafe.editor_changed.connect(_on_editor_changed)
	edit_panel.changed.connect(_on_editor_changed)
	cafe.edit_exit_requested.connect(exit_edit)
	hud.shop_requested.connect(open_shop)
	hud.quests_requested.connect(open_quests)
	hud.bag_requested.connect(open_bag)
	bag.closed.connect(_layout)
	quests.closed.connect(_layout)
	hud.arrange_requested.connect(enter_edit)
	shop.arrange_requested.connect(enter_edit)
	shop.place_requested.connect(place_bought)
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
			night_report.raid.defenders.size()), "title": tr("ui.battle_raid") % UiText.name(night_report.raid_target),
			"kind": "raid"})
	if night_report.defense != null:
		var home: Array[String] = []
		for fighter: Battle.Fighter in night_report.defense.defenders:
			home.append(_synth_label(fighter.synth_id))
		_battles.append({"battle": night_report.defense, "attacks": false, "mine": home,
			"theirs": _numbered("ui.battle_auditor" if night_report.audit else "ui.battle_raider", night_report.defense.attackers.size()),
			"title": tr("ui.battle_audit") if night_report.audit else tr("ui.battle_defense"),
			"kind": "audit" if night_report.audit else "defense"})
	if Session.auto_running and _battles.is_empty():
		# A quiet night on Auto: no report, the next shift just carries on.
		Session.toast.emit(tr("ui.auto_night_done") % night_report.income if night_report.income > 0 else tr("ui.auto_night_done_plain"))
		Sfx.music_for_phase()
		return
	Session.paused = true
	_play_next_battle()


## The next battle tonight (a raid on the café is announced first), else the report.
func _play_next_battle() -> void:
	if _battles.is_empty():
		Sfx.music_for_phase()
		report.show_report(_night_report)
		return
	_current_battle = _battles.pop_front()
	if _current_battle["kind"] == "raid":
		_start_battle()
		return
	# MegaBean is coming: say who defends before the fight.
	var lines: Array[Array] = [[tr("ui.warn_attackers") % (_current_battle["theirs"] as Array).size(), UiTheme.BAD]]
	var home: Array[String] = _current_battle["mine"]
	lines.append([tr("ui.warn_defenders") % ", ".join(home) if not home.is_empty() else tr("ui.warn_nobody"),
		UiTheme.TEXT if not home.is_empty() else UiTheme.WARN])
	_after_notice = _start_battle
	notice.show_notice(_current_battle["title"], UiTheme.BAD, lines)
	Sfx.play("alarm")


func _start_battle() -> void:
	var mine: Array[String] = _current_battle["mine"]
	var theirs: Array[String] = _current_battle["theirs"]
	if _current_battle["kind"] == "raid":
		battle.play(_current_battle["battle"], _current_battle["title"], true, mine, theirs)
	else:
		battle.play(_current_battle["battle"], _current_battle["title"], false, theirs, mine)


## After a battle: won or lost, loot or losses, and the XP each fighter earned.
func _show_result() -> void:
	var fight: Battle.Report = _current_battle["battle"]
	var raid: bool = _current_battle["kind"] == "raid"
	var won := fight.attackers_won == raid
	var lines: Array[Array] = ReportPanel.raid_lines(_night_report) if raid else ReportPanel.defense_lines(_night_report)
	var data := Session.data
	var xp := (data.balance.xp_raid_win if won else data.balance.xp_raid_loss) if raid else data.balance.xp_defense
	var fighters := fight.attackers if raid else fight.defenders
	var names: Array[String] = []
	for fighter: Battle.Fighter in fighters:
		var synth := Session.state.synth_by_id(fighter.synth_id)
		if synth == null:
			continue
		var level: int = _night_report.level_ups.get(synth.id, 0)
		names.append(Session.synth_name(synth) + (tr("ui.result_level") % level if level > 0 else ""))
	if not names.is_empty():
		lines.append([tr("ui.result_xp") % [xp, ", ".join(names)], UiTheme.PANEL_BORDER])
	_after_notice = _play_next_battle
	notice.show_notice(tr("ui.battle_victory") if won else tr("ui.battle_defeat"), UiTheme.GOOD if won else UiTheme.BAD, lines)


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
	bag.visible = false
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
	if _back_to_shop:
		_back_to_shop = false
		shop.open()
		_layout()


## A piece just bought with "Buy": straight into Arrange, held to place. Once
## it is placed (or put back into storage), the Shop comes back.
func place_bought(piece_id: String) -> void:
	enter_edit()
	edit_panel._take(piece_id)
	_back_to_shop = true
	_bought = [piece_id, Layout.count_placed_id(Session.state, piece_id)]


## Back to the Shop once the bought piece is on the floor (or put back).
func _on_editor_changed() -> void:
	edit_panel.refresh()
	if not _back_to_shop or cafe.editor == null:
		return
	if not cafe.editor.is_holding() or Layout.count_placed_id(Session.state, _bought[0]) > _bought[1]:
		cafe.editor.cancel()
		exit_edit()


## The selected worker takes the job of what was clicked ("" = the Pod bay:
## Rest). A Chef put at an idle stove gets its dish menu straight away.
func _give_job(uid: String, at: Vector2) -> void:
	var state := Session.state
	var code := GameLoop.send_to_rest(state, cafe.selected_synth) if uid == "" \
		else GameLoop.assign_to(state, cafe.selected_synth, uid, Session.data)
	if Session.act(code):
		var synth := state.synth_by_id(cafe.selected_synth)
		Session.toast.emit(tr("ui.job_now") % [Session.synth_name(synth), UiText.role(synth.role)])
		Sfx.play("ui_click")
		var stove := Layout.stove_of(state, uid)
		if stove != null and stove.is_idle():
			hud.open_recipe_menu(state.stoves.find(stove), at)


## A worker in the café and one in the Pod bay trade places.
func _swap_jobs(first_id: String, second_id: String) -> void:
	var state := Session.state
	if Session.act(GameLoop.swap_jobs(state, first_id, second_id)):
		var first := state.synth_by_id(first_id)
		var second := state.synth_by_id(second_id)
		Session.toast.emit(tr("ui.swapped") % [Session.synth_name(first), UiText.role(first.role),
			Session.synth_name(second), UiText.role(second.role)])
		Sfx.play("ui_click")
		hud.close_synth_card()


## The shop, at any time; toggles from the top bar.
func open_shop() -> void:
	if shop.visible:
		shop.close()
		return
	exit_edit()
	quests.visible = false
	bag.visible = false
	shop.open()
	_layout()


## The Bag, at any time; toggles from the top bar.
func open_bag() -> void:
	if bag.visible:
		bag.close()
		return
	exit_edit()
	shop.visible = false
	quests.visible = false
	bag.open()
	_layout()


## Quests, at any time; toggles from the top bar.
func open_quests() -> void:
	if quests.visible:
		quests.close()
		return
	exit_edit()
	shop.visible = false
	bag.visible = false
	quests.open()
	_layout()


## One panel on the right at a time: the edit panel, else the shop or quests,
## else the night hub at night. The camera fits the café beside it.
func _layout() -> void:
	night.visible = Session.state.phase == GameState.Phase.NIGHT and cafe.editor == null and not shop.visible \
		and not quests.visible and not bag.visible
	if night.visible:
		night.refresh()
	var panel := 0.0
	var bottom := 0.0
	if cafe.editor != null:
		bottom = EditPanel.HEIGHT + 24.0
	elif shop.visible:
		bottom = ShopPanel.HEIGHT + 24.0
	elif quests.visible:
		panel = QuestPanel.WIDTH + 30.0
	elif bag.visible:
		bottom = BagPanel.HEIGHT + 24.0
	elif night.visible:
		panel = CafeView.NIGHT_PANEL
	cafe.fit_camera(panel, bottom)
	hud.set_right_inset(panel, bottom)
	hud.show_shop_button(bottom == 0.0, panel)
	tutorial_box.bottom_inset = bottom
