class_name NightHub
extends PanelContainer

## A tab was opened: "summary", "staff" or "ops".
signal tab_shown(key: String)
## The night screen, on the right so the café stays visible: Summary, Menu,
## Staff and Night Ops tabs, then "End Night". (The Shop and Arrange Floor are
## on the top bar, open at any time.) Tabs rebuild
## from the state after every action, so they always show what is true.

var _title := UiTheme.label("", 26, UiTheme.PANEL_BORDER)
var _tabs := TabContainer.new()
var _pages: Dictionary[String, VBoxContainer] = {}
## Night Ops picks, kept while the player edits them.
var _target: String = ""
var _squad: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	custom_minimum_size = Vector2(760, 0)
	offset_left = -780
	offset_top = UiTheme.TOP_BAR_HEIGHT + 12
	offset_right = -12
	offset_bottom = -12
	var column := VBoxContainer.new()
	add_child(column)
	var header := HBoxContainer.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
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
	end.add_theme_font_size_override("font_size", 24)
	column.add_child(end)
	Session.state_changed.connect(refresh)
	Session.phase_changed.connect(_on_phase_changed)
	_on_phase_changed()


func _on_phase_changed() -> void:
	visible = Session.has_game() and Session.state.phase == GameState.Phase.NIGHT
	if visible:
		_target = Session.state.raid_target
		_squad = Session.state.raid_squad.duplicate()
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
func _wrap(text: String, size := 18, color := UiTheme.TEXT) -> Label:
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
	var brew := UiTheme.button(tr("ui.brew") % [b.brew_core_cost, b.brew_coin_cost], func() -> void:
		Session.act(GameLoop.brew_nanobrew(state, data)))
	brew.disabled = state.cores < b.brew_core_cost or state.coins < b.brew_coin_cost
	page.add_child(brew)
	page.add_child(HSeparator.new())
	# Tonight's recharge; Energy is bought in the Shop.
	page.add_child(_wrap(tr("ui.power_line") % [roundi(state.power), ceili(NightOps.recharge_cost(state, data))]))
	page.add_child(_wrap(tr("ui.energy_in_shop"), 14, UiTheme.TEXT_DIM))


func _fill_ops(page: VBoxContainer) -> void:
	var state := Session.state
	var data := Session.data
	var b := data.balance
	var district := data.districts[state.district_id]
	page.add_child(_wrap(tr("ui.ops_district") % [UiText.name(district.id), state.current_influence(),
		district.influence_required, roundi(state.current_suspicion())], 20))
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
	var targets := NightOps.raid_targets(state, data)
	if targets.is_empty():
		page.add_child(_wrap(tr("ui.ops_no_targets"), 16, UiTheme.TEXT_DIM))
	var group := ButtonGroup.new()
	for rival: RivalCafe in targets:
		var guards := NightOps.guards_for(state, rival, data)
		var power := 0.0
		var hp := 0.0
		for guard: Battle.Fighter in guards:
			power += guard.power
			hp += guard.hp
		var pick := CheckBox.new()
		pick.button_group = group
		pick.text = UiText.name(rival.id)
		pick.button_pressed = rival.id == _target
		pick.toggled.connect(func(on: bool) -> void:
			if on:
				_target = rival.id)
		page.add_child(pick)
		page.add_child(_indent(_wrap(tr("ui.ops_target") % [UiText.name(rival.id), guards.size(), roundi(power), roundi(hp),
			rival.loot_coins, rival.loot_cores, rival.influence], 15, UiTheme.TEXT_DIM)))
		if district.is_flagship(rival.id):
			page.add_child(_indent(_wrap(tr("ui.ops_flagship"), 15, UiTheme.ACCENT)))
	page.add_child(HSeparator.new())
	page.add_child(_wrap(tr("ui.ops_squad") % b.raid_squad_max, 18))
	for synth: Synth in state.synths:
		var pick := CheckBox.new()
		pick.text = tr("ui.ops_member") % [Session.synth_name(synth), roundi(SynthStats.stat(synth, "power", data)),
			roundi(SynthStats.stat(synth, "hp", data)), SynthStats.battery_percent(synth, data)]
		pick.button_pressed = _squad.has(synth.id)
		pick.disabled = synth.battery <= 0.0
		pick.toggled.connect(func(on: bool) -> void:
			if on and not _squad.has(synth.id):
				_squad.append(synth.id)
			elif not on:
				_squad.erase(synth.id))
		page.add_child(pick)
	var row := HBoxContainer.new()
	row.add_child(UiTheme.button(tr("ui.ops_plan"), func() -> void:
		Session.act(GameLoop.plan_raid(state, _target, _squad, data))))
	row.add_child(UiTheme.button(tr("ui.ops_cancel"), func() -> void:
		GameLoop.cancel_raid(state)
		_target = ""
		_squad.clear()
		Session.state_changed.emit()))
	page.add_child(row)
	var plan := tr("ui.ops_planned") % [UiText.name(state.raid_target), state.raid_squad.size()] \
		if state.raid_target != "" else tr("ui.ops_no_plan")
	page.add_child(_wrap(plan, 18, UiTheme.PANEL_BORDER))


func _end_night() -> void:
	Session.end_night()
