class_name RaidSetup
extends Control
## Planning a raid in front of the rival café: the café as it is (its tables,
## counters and décor; its guards where they will stand) and the player's 3
## rows on the street before it. Drag a worker from the list on the left onto a
## tile in your rows (or pick it, then click the tile): it joins the squad there.
## Drag a squad member to another tile (one already there swaps), or back onto
## the list to take it out; clicking its tile with nobody picked does that too.
## Start Raid fights at once; Back returns to the map.

signal back
## The raid was fought: its night report.
signal raided(report: NightOps.Report)

var rival_id: String = ""
## The squad: Synth id -> spot (column, row from the front).
var squad: Dictionary[String, Vector2i] = {}
var _picked: String = ""
var _title := UiTheme.label("", 28, UiTheme.PANEL_BORDER)
var _info := UiTheme.label("", 16, UiTheme.TEXT_DIM)
var _roster := VBoxContainer.new()
var _board := BattleView.new()
var _start := UiTheme.button(tr("ui.raid_start"), _start_raid)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(UiTheme.BACKGROUND, 0.99)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	add_child(_board)
	_board.cell_clicked.connect(_on_cell)
	_board.set_drag_forwarding(_drag_from_board, _can_drop_on_board, _drop_on_board)
	var top := VBoxContainer.new()
	top.position = Vector2(30, 20)
	top.add_child(_title)
	top.add_child(_info)
	add_child(top)
	var side := PanelContainer.new()
	side.position = Vector2(20, 130)
	side.custom_minimum_size = Vector2(300, 0)
	var column := VBoxContainer.new()
	column.add_child(UiTheme.label(tr("ui.raid_roster"), 18, UiTheme.PANEL_BORDER))
	column.add_child(_roster)
	side.add_child(column)
	add_child(side)
	# Dropping a squad member back on the list takes it out.
	side.set_drag_forwarding(Callable(), func(_at: Vector2, held: Variant) -> bool: return held is Dictionary 		and held.has("raid_synth"), func(_at: Vector2, held: Variant) -> void:
			squad.erase(held["raid_synth"])
			refresh())
	var buttons := HBoxContainer.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.position = Vector2(-220, -80)
	buttons.custom_minimum_size = Vector2(440, 52)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var back_button := UiTheme.button(tr("ui.raid_back"), func() -> void:
		visible = false
		back.emit())
	for button: Button in [back_button, _start]:
		button.custom_minimum_size = Vector2(200, 52)
		buttons.add_child(button)
	add_child(buttons)


## Opens the plan for a raid on rival_id; the squad starts from last time's spots.
func open(target: String) -> void:
	rival_id = target
	squad.clear()
	_picked = ""
	visible = true
	move_to_front()
	refresh()


func refresh() -> void:
	var state := Session.state
	var data := Session.data
	var rival := data.districts[state.district_id].rival_by_id(rival_id)
	_title.text = tr("ui.raid_title") % UiText.name(rival_id)
	_info.text = tr("ui.raid_info") % [rival.defenders.size(), NightOps.average_level(state, rival, data), rival.loot_coins,
		rival.loot_cores, squad.size(), data.balance.raid_squad_max]
	_start.disabled = squad.is_empty()
	for child: Node in _roster.get_children():
		_roster.remove_child(child)
		child.queue_free()
	for synth: Synth in state.synths:
		var species := data.species[synth.species_id]
		var text := tr("ui.raid_member") % [Session.synth_name(synth), tr("class." + species.combat_class), synth.level,
			SynthStats.battery_percent(synth, data)]
		var pick := UiTheme.button(("✓ " if squad.has(synth.id) else "") + text, _pick.bind(synth.id))
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.toggle_mode = true
		pick.button_pressed = synth.id == _picked
		pick.disabled = synth.battery <= 0.0
		pick.add_theme_font_size_override("font_size", 14)
		if synth.battery > 0.0:
			var synth_id := synth.id
			pick.set_drag_forwarding(func(_at: Vector2) -> Variant: return _drag_data(synth_id), Callable(), Callable())
		_roster.add_child(pick)
	_show_board(state, data, rival)


## The board: the café with its guards, and the squad on its spots.
func _show_board(state: GameState, data: GameData, rival: RivalCafe) -> void:
	var fighters: Array[Battle.Fighter] = []
	var names: Array[String] = []
	for synth_id: String in squad:
		var fighter := NightOps.synth_fighter(state.synth_by_id(synth_id), 0.0, data)
		fighter.cell = squad[synth_id]
		fighters.append(fighter)
		names.append(Session.synth_name(state.synth_by_id(synth_id)))
	var guards := NightOps.guards_for(state, rival, data)
	var guard_names: Array[String] = []
	for i: int in guards.size():
		guard_names.append(tr("ui.raid_guard") % NightOps.guard_level(state, rival, rival.defenders[i], data))
	var field := RaidField.for_rival(rival, data.districts[state.district_id].is_flagship(rival.id), data)
	_board.preview(Battle.setup(fighters, guards, data, field), names, guard_names)


## What a drag carries: the worker, with its name under the mouse.
func _drag_data(synth_id: String) -> Dictionary:
	var label := UiTheme.label(Session.synth_name(Session.state.synth_by_id(synth_id)), 18, UiTheme.PANEL_BORDER)
	set_drag_preview(label)
	return {"raid_synth": synth_id}


## Dragging a squad member off its tile.
func _drag_from_board(at: Vector2) -> Variant:
	var field := _board.playback.report.field
	var cell := _board.cell_at(at)
	var spot := Vector2i(cell.x, cell.y - field.split)
	for synth_id: String in squad:
		if squad[synth_id] == spot:
			return _drag_data(synth_id)
	return null


func _can_drop_on_board(at: Vector2, held: Variant) -> bool:
	if not (held is Dictionary and held.has("raid_synth")):
		return false
	var field := _board.playback.report.field
	var cell := _board.cell_at(at)
	return cell.x >= 0 and cell.x < field.board.x and cell.y >= field.split and cell.y < field.board.y


func _drop_on_board(at: Vector2, held: Variant) -> void:
	_picked = held["raid_synth"]
	_on_cell(_board.cell_at(at))


func _pick(synth_id: String) -> void:
	_picked = "" if _picked == synth_id else synth_id
	refresh()


## A tile clicked: put the picked worker there (swapping), or take a squad member out.
func _on_cell(cell: Vector2i) -> void:
	var field := _board.playback.report.field
	var spot := Vector2i(cell.x, cell.y - field.split)
	if cell.x < 0 or cell.x >= field.board.x or spot.y < 0 or spot.y >= field.rows(true):
		return  # not one of your rows
	var here := ""
	for synth_id: String in squad:
		if squad[synth_id] == spot:
			here = synth_id
	if _picked == "":
		if here != "":
			squad.erase(here)
		refresh()
		return
	if not squad.has(_picked) and squad.size() >= Session.data.balance.raid_squad_max:
		Session.toast.emit(UiText.error(GameLoop.SQUAD_TOO_BIG))
		return
	if here != "" and here != _picked:
		if squad.has(_picked):
			squad[here] = squad[_picked]
		else:
			squad.erase(here)
	squad[_picked] = spot
	_picked = ""
	refresh()


func _start_raid() -> void:
	var state := Session.state
	var ids: Array[String] = []
	for synth_id: String in squad:
		ids.append(synth_id)
		state.formation[synth_id] = squad[synth_id]
	var out: Array[NightOps.Report] = []
	if Session.act(GameLoop.raid_now(state, rival_id, ids, Session.data, out)):
		visible = false
		raided.emit(out[0])
