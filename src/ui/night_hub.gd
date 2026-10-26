class_name NightHub
extends PanelContainer
## The night screen, on the right so the café stays visible: Summary, Menu,
## Upgrades & Décor, Staff and Night Ops tabs, then "End Night". Tabs rebuild
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
	offset_top = 70
	offset_right = -12
	offset_bottom = -12
	var column := VBoxContainer.new()
	add_child(column)
	column.add_child(_title)
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	for key: String in ["summary", "menu", "upgrades", "staff", "ops"]:
		var scroll := ScrollContainer.new()
		scroll.name = tr("ui.tab_" + key)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(page)
		_tabs.add_child(scroll)
		_pages[key] = page
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
	_fill_menu(_clear("menu"))
	_fill_upgrades(_clear("upgrades"))
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


func _fill_menu(page: VBoxContainer) -> void:
	var state := Session.state
	var data := Session.data
	page.add_child(_wrap(tr("ui.menu_slots") % [state.menu.size(), state.menu_slots], 18, UiTheme.TEXT_DIM))
	for recipe: Recipe in Shift.unlocked_recipes(state, data):
		var row := VBoxContainer.new()
		var check := CheckBox.new()
		check.text = UiText.name(recipe.id)
		check.button_pressed = state.menu.has(recipe.id)
		check.toggled.connect(_toggle_dish.bind(recipe.id))
		row.add_child(check)
		var fans: Array[String] = []
		for type: CustomerType in data.customer_types.values():
			if type.favorites.has(recipe.id):
				fans.append(UiText.name(type.id))
		var fans_text := tr("ui.menu_fans") % ", ".join(fans) if not fans.is_empty() else tr("ui.menu_no_fans")
		var details := tr("ui.menu_dish") % [UiText.name(recipe.id), recipe.price, recipe.cost, recipe.servings, recipe.cook_seconds]
		row.add_child(_indent(_wrap(details + "\n" + fans_text, 15, UiTheme.TEXT_DIM)))
		page.add_child(row)


func _toggle_dish(on: bool, recipe_id: String) -> void:
	var menu := Session.state.menu.duplicate()
	if on:
		menu.append(recipe_id)
	else:
		menu.erase(recipe_id)
	if not Session.act(GameLoop.set_menu(Session.state, menu, Session.data)):
		refresh()


func _fill_upgrades(page: VBoxContainer) -> void:
	var state := Session.state
	var data := Session.data
	for upgrade_id: String in Upgrade.IDS:
		var upgrade := data.upgrades[upgrade_id]
		var row := HBoxContainer.new()
		var name := _wrap(tr("ui.upgrade_line") % [UiText.name(upgrade_id), state.upgrades.get(upgrade_id, 0), upgrade.max_level])
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var cost := GameLoop.upgrade_cost(state, upgrade_id, data)
		var buy := UiTheme.button(tr("ui.buy") % cost if cost >= 0 else tr("ui.maxed"), _buy_upgrade.bind(upgrade_id))
		buy.disabled = cost < 0 or state.coins < cost
		row.add_child(buy)
		page.add_child(row)
	page.add_child(HSeparator.new())
	page.add_child(_wrap(tr("ui.decor_title"), 22, UiTheme.PANEL_BORDER))
	page.add_child(_wrap(tr("ui.floor_line") % [data.balance.floor_width, state.floor_rows, roundi(state.vibe)], 16, UiTheme.TEXT_DIM))
	page.add_child(_wrap(tr("ui.decor_note"), 14, UiTheme.TEXT_DIM))
	for piece: Piece in data.pieces.values():
		if piece.kind != Piece.DECOR:
			continue
		var row := HBoxContainer.new()
		var text := tr("ui.decor_line") % [UiText.name(piece.id), piece.size.x, piece.size.y, roundi(piece.vibe), ", ".join(piece.tags)]
		if state.storage.get(piece.id, 0) > 0:
			text += "   " + tr("ui.decor_owned") % state.storage[piece.id]
		var name := _wrap(text, 16)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var buy := UiTheme.button(tr("ui.buy") % piece.price, _buy_decor.bind(piece.id))
		buy.disabled = state.coins < piece.price
		row.add_child(buy)
		page.add_child(row)


func _buy_upgrade(upgrade_id: String) -> void:
	if Session.act(GameLoop.buy_upgrade(Session.state, upgrade_id, Session.data)) \
			and [Upgrade.STOVE, Upgrade.SEAT, Upgrade.POD].has(upgrade_id):
		Session.auto_place(upgrade_id)
		Session.state_changed.emit()


func _buy_decor(piece_id: String) -> void:
	if Session.act(GameLoop.buy_decor(Session.state, piece_id, Session.data)):
		if not Session.auto_place(piece_id):
			Session.toast.emit(tr("ui.no_room_stored"))
		Session.state_changed.emit()


func _fill_staff(page: VBoxContainer) -> void:
	var state := Session.state
	var data := Session.data
	var b := data.balance
	for synth: Synth in state.synths:
		var row := HBoxContainer.new()
		var trait_text := ", " + UiText.name(synth.trait_id) if synth.trait_id != "" else ""
		var name := _wrap(tr("ui.staff_line") % [Session.synth_name(synth), UiText.name(synth.species_id), trait_text,
			synth.level, roundi(synth.battery), roundi(SynthStats.stat(synth, "battery_max", data))], 16)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)
		var roles := OptionButton.new()
		for i: int in Synth.ROLES.size():
			roles.add_item(UiText.role(Synth.ROLES[i]), i)
		roles.selected = Synth.ROLES.find(synth.role)
		roles.item_selected.connect(func(index: int) -> void:
			Session.act(GameLoop.assign_role(state, synth.id, Synth.ROLES[index])))
		row.add_child(roles)
		page.add_child(row)
	page.add_child(HSeparator.new())
	page.add_child(_wrap(tr("ui.nanobrew_count") % [state.nanobrew, state.cores]))
	var brew := UiTheme.button(tr("ui.brew") % [b.brew_core_cost, b.brew_coin_cost], func() -> void:
		Session.act(GameLoop.brew_nanobrew(state, data)))
	brew.disabled = state.cores < b.brew_core_cost or state.coins < b.brew_coin_cost
	page.add_child(brew)
	page.add_child(HSeparator.new())
	page.add_child(_wrap(tr("ui.power_line") % [roundi(state.power), ceili(NightOps.recharge_cost(state, data))]))
	var row := HBoxContainer.new()
	for amount: int in [10, 50]:
		var buy := UiTheme.button(tr("ui.buy_power") % [amount, amount * b.power_price], func() -> void:
			Session.act(GameLoop.buy_power(state, amount, data)))
		buy.disabled = state.coins < amount * b.power_price
		row.add_child(buy)
	page.add_child(row)


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
			roundi(SynthStats.stat(synth, "hp", data)), roundi(synth.battery)]
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
