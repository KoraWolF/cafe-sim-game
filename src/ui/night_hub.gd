class_name NightHub
extends PanelContainer

## A tab was opened: "summary", "staff" or "ops".
## Night Ops' Open map was pressed.
signal map_requested
## The window's Close was pressed (the round Night button opens it again).
signal closed

const WIDTH: float = 720.0
const HEIGHT: float = 760.0
signal tab_shown(key: String)
## The night screen, on the right so the café stays visible: Summary, Menu,
## Staff and Night Ops tabs, then "End Night". (The Shop and Arrange Floor are
## on the top bar, open at any time.) Tabs rebuild
## from the state after every action, so they always show what is true.

var _title := UiTheme.label("", 26, UiTheme.PANEL_BORDER)
var _tabs := TabContainer.new()
var _pages: Dictionary[String, VBoxContainer] = {}
## Night Ops picks, kept while the player edits them.


func _ready() -> void:
	# A window in the middle of the screen (the round Night button opens and closes it).
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = -HEIGHT * 0.5 + UiTheme.TOP_BAR_HEIGHT * 0.5
	offset_bottom = HEIGHT * 0.5 + UiTheme.TOP_BAR_HEIGHT * 0.5
	var column := VBoxContainer.new()
	add_child(column)
	var header := HBoxContainer.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	header.add_child(UiTheme.button(tr("ui.close"), closed.emit))
	column.add_child(header)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	for key: String in ["summary", "staff", "ops"]:
		var scroll := ScrollContainer.new()
		scroll.name = tr("ui.tab_" + key)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(page)
		_tabs.add_child(scroll)
		_pages[key] = page
	# Connected after the tabs exist: adding the first tab already changes the tab.
	_tabs.tab_changed.connect(func(index: int) -> void: tab_shown.emit(_pages.keys()[index]))
	var end := UiTheme.button(tr("ui.end_night"), _end_night)
	end.custom_minimum_size = Vector2(0, 54)
	end.add_theme_font_size_override("font_size", 20)
	column.add_child(end)
	Session.state_changed.connect(refresh)
	Session.phase_changed.connect(_on_phase_changed)
	_on_phase_changed()


## Hidden by day; at night GameScreen shows it (unless the player closed it).
func _on_phase_changed() -> void:
	if not Session.has_game() or Session.state.phase != GameState.Phase.NIGHT:
		visible = false
	else:
		_tabs.current_tab = 0
		refresh()


func refresh() -> void:
	if not visible:
		return
	var state := Session.state
	_title.text = tr("ui.night_title") % [state.day, UiText.name(state.district_id)]
	_fill_summary(_clear("summary"))
	_fill_staff(_clear("staff"))
	_fill_ops(_clear("ops"))


## A label that wraps inside the hub instead of widening it.
func _wrap(text: String, size := 16, color := UiTheme.TEXT) -> Label:
	var label := UiTheme.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(200, 0)
	return label


## Wraps a control with a left margin (details under a checkbox).
func _indent(control: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_child(control)
	return margin


func _clear(key: String) -> VBoxContainer:
	var page := _pages[key]
	for child: Node in page.get_children():
		page.remove_child(child)
		child.queue_free()
	return page


func _fill_summary(page: VBoxContainer) -> void:
	var log := Session.day_log
	var seated := maxi(log.served + log.angry, 1)
	page.add_child(_wrap(tr("ui.summary_line") % [log.served, log.stars, roundi(100.0 * log.stars / seated),
		log.angry, log.turned_away]))
	page.add_child(_wrap(tr("ui.summary_money") % [log.coins, log.tips, Session.state.coins]))
	page.add_child(_wrap(tr("ui.summary_staff") % [log.conversions, log.broken, log.glitches]))


func _fill_staff(page: VBoxContainer) -> void:
	var state := Session.state
	var data := Session.data
	var b := data.balance
	for synth: Synth in state.synths:
		var row := HBoxContainer.new()
		var trait_text := ", " + UiText.name(synth.trait_id) if synth.trait_id != "" else ""
		var name := _wrap(tr("ui.staff_line") % [Session.synth_name(synth), UiText.name(synth.species_id), trait_text,
			synth.level, SynthStats.battery_percent(synth, data), roundi(SynthStats.stat(synth, "battery_max", data))], 16)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		row.add_child(_wrap(UiText.role(synth.role), 16, UiTheme.PANEL_BORDER))
		page.add_child(row)
	page.add_child(HSeparator.new())
	page.add_child(_wrap(tr("ui.nanobrew_count") % [state.nanobrew, state.cores]))
	page.add_child(_wrap(tr("ui.brew_in_menu"), 14, UiTheme.TEXT_DIM))
	page.add_child(HSeparator.new())
	# Tonight's recharge; Energy is bought in the Shop.
	page.add_child(_wrap(tr("ui.power_line") % [roundi(state.power), ceili(NightOps.recharge_cost(state, data))]))
	page.add_child(_wrap(tr("ui.energy_in_shop"), 14, UiTheme.TEXT_DIM))


func _fill_ops(page: VBoxContainer) -> void:
	var state := Session.state
	var data := Session.data
	var b := data.balance
	var district := data.districts[state.district_id]
	page.add_child(_wrap(tr("ui.ops_district") % [UiText.name(district.id), NightOps.bars_beaten(state, district),
		district.rivals.size(), roundi(state.current_suspicion())], 20))
	if state.owned_districts.is_empty():
		page.add_child(_wrap(tr("ui.ops_none_owned"), 16, UiTheme.TEXT_DIM))
	else:
		page.add_child(_wrap(tr("ui.ops_owned") % [", ".join(state.owned_districts.map(UiText.name)),
			NightOps.daily_income(state, data)], 16, UiTheme.GOOD))
	if state.current_suspicion() >= b.audit_suspicion:
		page.add_child(_wrap(tr("ui.ops_audit") % roundi(b.audit_suspicion), 18, UiTheme.BAD))
	else:
		page.add_child(_wrap(tr("ui.ops_defense") % roundi(100.0 * NightOps.defense_chance(state, b)), 16, UiTheme.WARN))
	page.add_child(_wrap(tr("ui.ops_security") % [state.upgrades.get(Upgrade.SECURITY, 0), roundi(state.security)], 15, UiTheme.TEXT_DIM))
	page.add_child(HSeparator.new())
	var open_map := UiTheme.button(tr("ui.ops_open_map"), map_requested.emit)
	open_map.custom_minimum_size = Vector2(0, 60)
	open_map.add_theme_font_size_override("font_size", 22)
	page.add_child(open_map)
	page.add_child(_wrap(tr("ui.ops_raided") if state.last_raid_day == state.day else tr("ui.ops_map_hint"), 15,
		UiTheme.TEXT_DIM))
	page.add_child(HSeparator.new())
	# Who defends the café if MegaBean comes (those who fight recharge only half).
	page.add_child(_wrap(tr("ui.ops_defenders"), 18))
	page.add_child(_wrap(tr("ui.ops_defenders_help"), 14, UiTheme.TEXT_DIM))
	for synth: Synth in state.synths:
		var pick := CheckBox.new()
		pick.text = tr("ui.ops_defender") % [Session.synth_name(synth), tr("class." + data.species[synth.species_id].combat_class),
			synth.level, SynthStats.battery_percent(synth, data), roundi(SynthStats.hp_now(synth, data)),
			roundi(SynthStats.stat(synth, "hp", data))]
		pick.button_pressed = state.defenders.has(synth.id)
		pick.disabled = not SynthStats.can_fight(synth, data)
		var synth_id := synth.id
		pick.toggled.connect(func(on: bool) -> void: GameLoop.set_defender(Session.state, synth_id, on))
		page.add_child(pick)


func _end_night() -> void:
	Session.end_night()
