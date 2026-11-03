class_name ReportPanel
extends PanelContainer
## What happened tonight, shown after the night's battles (GameScreen calls
## show_report) as notes at the top right that fade after a while: the raid,
## takeovers, the MegaBean raid or Audit, theft, income, recharging and
## level-ups. The next day starts at once. The × closes them early.

const WIDTH: float = 460.0
## Seconds the notes stay up.
const SHOW_SECONDS: float = 12.0

var _lines := VBoxContainer.new()
var _title := UiTheme.label("", 20, UiTheme.PANEL_BORDER)
## Seconds left before the notes fade away.
var _left: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	position = Vector2(-WIDTH - 24, UiTheme.TOP_BAR_HEIGHT + 12)
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	var close := UiTheme.button("×", func() -> void: visible = false)
	close.tooltip_text = tr("ui.report_close")
	close.custom_minimum_size = Vector2(36, 32)
	top.add_child(close)
	column.add_child(top)
	column.add_child(_lines)


## Shows tonight's results as notes at the top right; the day is already running.
func show_report(report: NightOps.Report) -> void:
	for child: Node in _lines.get_children():
		child.queue_free()
	var state := Session.state
	_title.text = tr("ui.report_title") % (state.day - 1)
	for line: Array in lines(report):
		var label := UiTheme.label(line[0], 15, line[1])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(WIDTH - 20, 0)
		_lines.add_child(label)
	_left = SHOW_SECONDS
	modulate.a = 1.0
	visible = true
	reset_size()
	position = Vector2(get_parent_area_size().x - size.x - 24, UiTheme.TOP_BAR_HEIGHT + 12)


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	modulate.a = clampf(_left, 0.0, 1.0)  # fades in the last second
	if _left <= 0.0:
		visible = false


## [text, colour] for each line of the report.
static func lines(report: NightOps.Report) -> Array[Array]:
	var state := Session.state
	var result: Array[Array] = raid_lines(report) + defense_lines(report)
	if result.is_empty():
		result.append([TranslationServer.translate("ui.report_quiet"), UiTheme.TEXT_DIM])
	for synth_id: String in report.stolen:
		var synth := state.synth_by_id(synth_id)
		result.append([TranslationServer.translate("ui.report_stolen") % [Session.synth_name(synth) if synth != null else synth_id,
			report.stolen[synth_id]], UiTheme.WARN])
	if report.income > 0:
		result.append([TranslationServer.translate("ui.report_income") % report.income, UiTheme.GOOD])
	result.append([TranslationServer.translate("ui.report_power") % roundi(report.power_used), UiTheme.TEXT_DIM])
	if not report.undercharged.is_empty():
		result.append([TranslationServer.translate("ui.report_undercharged") % report.undercharged.size(), UiTheme.WARN])
	for synth_id: String in report.level_ups:
		var synth := state.synth_by_id(synth_id)
		if synth != null:
			result.append([TranslationServer.translate("ui.report_level") % [Session.synth_name(synth), report.level_ups[synth_id]],
				UiTheme.PANEL_BORDER])
	return result


## The raid's result: won (loot, materials, items, a new dish, a district taken) or lost.
static func raid_lines(report: NightOps.Report) -> Array[Array]:
	var state := Session.state
	var data := Session.data
	var result: Array[Array] = []
	if report.raid == null:
		return result
	if report.raid.attackers_won:
		result.append([TranslationServer.translate("ui.report_raid_won") % [UiText.name(report.raid_target),
			report.loot_coins, report.loot_cores], UiTheme.GOOD])
		var town := data.districts.get(report.district_taken if report.district_taken != "" else Session.state.district_id) as District
		if report.first_win and town != null and not town.is_flagship(report.raid_target):
			result.append([TranslationServer.translate("ui.report_first_win") % [UiText.name(report.raid_target),
				NightOps.bars_beaten(Session.state, town), town.rivals.size(), UiText.name(town.id)], UiTheme.PANEL_BORDER])
		if report.boss_opened and town != null:
			result.append([TranslationServer.translate("ui.report_boss_open") % UiText.name(town.flagship.id), UiTheme.WARN])
		if report.loot_scrap > 0 or report.loot_chips > 0:
			result.append([TranslationServer.translate("ui.report_materials") % [report.loot_scrap, report.loot_chips], UiTheme.GOOD])
		for uid: String in report.loot_items:
			var item := Items.in_inventory(state, uid)
			if item != null:
				result.append([TranslationServer.translate("ui.report_item") % [UiText.item_name(item),
					UiText.item_effect(item, data.items)], UiTheme.ACCENT])
		if report.loot_bottle != "":
			result.append([TranslationServer.translate("ui.report_bottle") % UiText.name(report.loot_bottle), UiTheme.ACCENT])
		if report.new_dish != "" and report.defense == null:
			result.append([TranslationServer.translate("ui.report_dish") % UiText.name(report.new_dish), UiTheme.ACCENT])
		if report.district_taken != "":
			result.append([TranslationServer.translate("ui.report_takeover") % [UiText.name(report.district_taken),
				data.districts[report.district_taken].income], UiTheme.ACCENT])
			if report.next_district != "":
				result.append([TranslationServer.translate("ui.report_next") % UiText.name(report.next_district), UiTheme.TEXT])
			else:
				result.append([TranslationServer.translate("ui.report_city"), UiTheme.ACCENT])
	else:
		result.append([TranslationServer.translate("ui.report_raid_lost") % UiText.name(report.raid_target), UiTheme.BAD])
	return result


## A MegaBean raid on the café, or the Audit: held, or what it took.
static func defense_lines(report: NightOps.Report) -> Array[Array]:
	var result: Array[Array] = []
	if report.defense == null:
		return result
	var lost := report.defense.attackers_won
	if report.audit:
		if not lost:
			result.append([TranslationServer.translate("ui.report_audit_held"), UiTheme.GOOD])
		elif report.synth_lost != "":
			result.append([TranslationServer.translate("ui.report_audit_lost") % report.coins_lost, UiTheme.BAD])
		else:
			result.append([TranslationServer.translate("ui.report_audit_lost_none") % report.coins_lost, UiTheme.BAD])
	elif lost:
		result.append([TranslationServer.translate("ui.report_defense_lost") % [report.coins_lost, report.cores_lost], UiTheme.BAD])
	else:
		result.append([TranslationServer.translate("ui.report_defense_held"), UiTheme.GOOD])
		if report.new_dish != "":
			result.append([TranslationServer.translate("ui.report_dish") % UiText.name(report.new_dish), UiTheme.ACCENT])
	return result


