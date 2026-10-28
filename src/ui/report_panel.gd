class_name ReportPanel
extends PanelContainer
## What happened tonight, shown after the night's battles (GameScreen calls
## show_report): the raid, takeovers, the MegaBean raid or Audit, theft,
## income, recharging and level-ups. The next shift waits (paused) until the
## player presses Start.

var _lines := VBoxContainer.new()
var _title := UiTheme.label("", 28, UiTheme.PANEL_BORDER)
var _start := Button.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(760, 0)
	visible = false
	var column := VBoxContainer.new()
	add_child(column)
	column.add_child(_title)
	column.add_child(_lines)
	_start.custom_minimum_size = Vector2(0, 50)
	_start.pressed.connect(_close)
	column.add_child(_start)


func show_report(report: NightOps.Report) -> void:
	for child: Node in _lines.get_children():
		child.queue_free()
	var state := Session.state
	var night := state.day - 1
	_title.text = tr("ui.report_title") % night
	for line: Array in lines(report):
		_lines.add_child(UiTheme.label(line[0], 18, line[1]))
	_start.text = tr("ui.continue_day") % state.day
	Session.paused = true
	visible = true
	reset_size()
	position = (get_parent_area_size() - size) * 0.5


## [text, colour] for each line of the report.
static func lines(report: NightOps.Report) -> Array[Array]:
	var state := Session.state
	var data := Session.data
	var result: Array[Array] = []
	if report.raid != null:
		if report.raid.attackers_won:
			result.append([TranslationServer.translate("ui.report_raid_won") % [UiText.name(report.raid_target),
				report.loot_coins, report.loot_cores, report.influence_gained], UiTheme.GOOD])
			if report.loot_scrap > 0 or report.loot_chips > 0:
				result.append([TranslationServer.translate("ui.report_materials") % [report.loot_scrap, report.loot_chips], UiTheme.GOOD])
			for uid: String in report.loot_items:
				var item := Items.in_inventory(state, uid)
				if item != null:
					result.append([TranslationServer.translate("ui.report_item") % [UiText.item_name(item),
						UiText.item_effect(item, data.items)], UiTheme.ACCENT])
			if report.loot_bottle != "":
				result.append([TranslationServer.translate("ui.report_bottle") % UiText.name(report.loot_bottle), UiTheme.ACCENT])
		else:
			result.append([TranslationServer.translate("ui.report_raid_lost") % UiText.name(report.raid_target), UiTheme.BAD])
	if report.district_taken != "":
		result.append([TranslationServer.translate("ui.report_takeover") % [UiText.name(report.district_taken),
			data.districts[report.district_taken].income], UiTheme.ACCENT])
		if report.next_district != "":
			result.append([TranslationServer.translate("ui.report_next") % UiText.name(report.next_district), UiTheme.TEXT])
		else:
			result.append([TranslationServer.translate("ui.report_city"), UiTheme.ACCENT])
	if report.defense != null:
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
	if result.is_empty():
		result.append([TranslationServer.translate("ui.report_quiet"), UiTheme.TEXT_DIM])
	for synth_id: String in report.stolen:
		var synth := state.synth_by_id(synth_id)
		result.append([TranslationServer.translate("ui.report_stolen") % [Session.synth_name(synth) if synth != null else synth_id,
			report.stolen[synth_id]], UiTheme.WARN])
	if report.income > 0:
		result.append([TranslationServer.translate("ui.report_income") % report.income, UiTheme.GOOD])
	result.append([TranslationServer.translate("ui.report_power") % roundi(report.power_used), UiTheme.TEXT_DIM])
	if not report.not_in_pod.is_empty():
		result.append([TranslationServer.translate("ui.report_not_in_pod") % report.not_in_pod.size(), UiTheme.WARN])
	if not report.undercharged.is_empty():
		result.append([TranslationServer.translate("ui.report_undercharged") % report.undercharged.size(), UiTheme.WARN])
	for synth_id: String in report.level_ups:
		var synth := state.synth_by_id(synth_id)
		if synth != null:
			result.append([TranslationServer.translate("ui.report_level") % [Session.synth_name(synth), report.level_ups[synth_id]],
				UiTheme.PANEL_BORDER])
	return result


func _close() -> void:
	visible = false
	Session.paused = false
