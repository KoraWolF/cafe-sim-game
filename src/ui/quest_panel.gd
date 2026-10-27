class_name QuestPanel
extends PanelContainer
## Quests, open at any time from the top bar: today's Daily quests, the
## Story step, and Achievements. Each shows its progress and reward, with Claim
## once done. Rebuilds after every action.

signal closed

const WIDTH: float = 560.0

var tabs := TabContainer.new()
var _pages: Dictionary[String, VBoxContainer] = {}


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_left = -WIDTH - 12
	offset_top = 70
	offset_right = -12
	offset_bottom = -12
	var column := VBoxContainer.new()
	add_child(column)
	var header := HBoxContainer.new()
	var title := UiTheme.label(tr("ui.quests_title"), 26, UiTheme.PANEL_BORDER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(UiTheme.button(tr("ui.close"), close))
	column.add_child(header)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	for key: String in ["daily", "story", "achievements"]:
		var scroll := ScrollContainer.new()
		scroll.name = tr("ui.quests_tab_" + key)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 10)
		scroll.add_child(page)
		tabs.add_child(scroll)
		_pages[key] = page
	Session.state_changed.connect(refresh)
	Session.shift_advanced.connect(func(_events: Shift.Events) -> void: refresh())


func open() -> void:
	Session.refresh_quests()
	visible = true
	refresh()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func refresh() -> void:
	if not visible or not Session.has_game():
		return
	var state := Session.state
	var data := Session.data
	var daily := _clear("daily")
	daily.add_child(_note(tr("ui.quests_daily_note")))
	for i: int in state.daily_quests.size():
		var quest := state.daily_quests[i]
		var done := Quests.daily_progress(state, quest, data)
		daily.add_child(_row(tr("quest.daily." + quest["id"]) % quest["target"], done, quest["reward"],
			quest["claimed"], Quests.DAILY, str(i)))
	var story := _clear("story")
	var step := Quests.story_quest(state, data)
	if step.is_empty():
		story.add_child(_note(tr("ui.quests_story_done")))
	else:
		story.add_child(_note(tr("ui.quests_story_step") % [state.story_index + 1, data.quests["story"].size()]))
		story.add_child(_row(tr("quest.story." + step["id"]), Quests.progress(state, step, data), step["reward"], false,
			Quests.STORY, ""))
	var achievements := _clear("achievements")
	achievements.add_child(_note(tr("ui.quests_achievements_note") % [state.achievements.size(),
		data.quests.get("achievements", []).size()]))
	for entry: Dictionary in data.quests.get("achievements", []):
		achievements.add_child(_row(tr("quest.ach." + entry["id"]), Quests.progress(state, entry, data), entry["reward"],
			state.achievements.has(entry["id"]), Quests.ACHIEVEMENT, entry["id"]))


## One quest: what to do, progress, reward, and Claim (or Claimed).
func _row(text: String, done: Array[int], reward: Dictionary, claimed: bool, kind: String, key: String) -> Control:
	var row := HBoxContainer.new()
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UiTheme.label("%s   %d / %d" % [text, done[0], done[1]], 17, UiTheme.GOOD if done[0] >= done[1] else UiTheme.TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(380, 0)
	column.add_child(title)
	column.add_child(UiTheme.label(tr("ui.quests_reward") % UiText.reward(reward), 14, UiTheme.WARN))
	row.add_child(column)
	var claim := UiTheme.button(tr("ui.quests_claimed") if claimed else tr("ui.quests_claim"), func() -> void:
		var given: Array[Dictionary] = []
		if Session.act(GameLoop.claim_quest(Session.state, kind, key, Session.data, given)):
			Session.toast.emit(tr("ui.quests_got") % UiText.reward(given[0])))
	claim.disabled = claimed or done[0] < done[1]
	row.add_child(claim)
	return row


func _note(text: String) -> Label:
	var label := UiTheme.label(text, 14, UiTheme.TEXT_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(500, 0)
	return label


func _clear(key: String) -> VBoxContainer:
	var page := _pages[key]
	for child: Node in page.get_children():
		page.remove_child(child)
		child.queue_free()
	return page
