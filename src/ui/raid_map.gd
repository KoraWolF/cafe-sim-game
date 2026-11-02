class_name RaidMap
extends Control
## The district map, opened from Night Ops: your café and the district's
## MegaBean cafés as pins along the streets. Each pin says the café's guards
## (how many, their average level), its loot, and whether it can be raided
## tonight (cooling down, the flagship locked until there is enough Influence,
## or a raid already made tonight). Click a café to plan the raid in front of
## it (RaidSetup). Taken districts are listed greyed under the title.

signal closed
## A café to raid was picked.
signal target_picked(rival_id: String)

## Pin spots on the map, as shares of its size (your café is the last).
const SPOTS: Array[Vector2] = [Vector2(0.2, 0.3), Vector2(0.5, 0.22), Vector2(0.8, 0.32), Vector2(0.3, 0.62),
	Vector2(0.72, 0.62), Vector2(0.5, 0.45)]
const HOME: Vector2 = Vector2(0.5, 0.86)
const PIN_SIZE: Vector2 = Vector2(260, 120)

var _title := UiTheme.label("", 30, UiTheme.PANEL_BORDER)
var _owned := UiTheme.label("", 16, UiTheme.TEXT_DIM)
var _pins := Control.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var top := VBoxContainer.new()
	top.position = Vector2(30, 20)
	top.add_child(_title)
	top.add_child(_owned)
	add_child(top)
	_pins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pins)
	var close := UiTheme.button(tr("ui.close"), close_map)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.position = Vector2(-150, 24)
	close.custom_minimum_size = Vector2(120, 46)
	add_child(close)
	resized.connect(refresh)


func open() -> void:
	visible = true
	move_to_front()
	refresh()


func close_map() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	if not visible or not Session.has_game():
		return
	var state := Session.state
	var data := Session.data
	var district := data.districts[state.district_id]
	_title.text = tr("ui.map_title") % [UiText.name(district.id), state.current_influence(), district.influence_required]
	_owned.text = tr("ui.map_owned") % ", ".join(state.owned_districts.map(UiText.name)) if not state.owned_districts.is_empty() \
		else tr("ui.map_hint")
	for child: Node in _pins.get_children():
		_pins.remove_child(child)
		child.queue_free()
	var cafes: Array[RivalCafe] = district.rivals.duplicate()
	cafes.append(district.flagship)
	for i: int in cafes.size():
		_pins.add_child(_pin(cafes[i], SPOTS[i % SPOTS.size()], state, data))
	var home := UiTheme.label(tr("ui.map_home"), 18, UiTheme.GOOD)
	home.position = size * HOME + Vector2(-44, 22)
	_pins.add_child(home)
	queue_redraw()


## One café's pin: name, guards and level, loot, and why it can't be raided (if so).
func _pin(rival: RivalCafe, spot: Vector2, state: GameState, data: GameData) -> Button:
	var district := data.districts[state.district_id]
	var flagship := district.is_flagship(rival.id)
	var lines: Array[String] = [UiText.name(rival.id) + (tr("ui.map_flagship") if flagship else "")]
	lines.append(tr("ui.map_guards") % [rival.defenders.size(), NightOps.average_level(state, rival, data)])
	lines.append(tr("ui.map_loot") % [rival.loot_coins, rival.loot_cores] + (tr("ui.map_influence") % rival.influence
		if rival.influence > 0 else ""))
	var why := ""
	if state.last_raid_day == state.day:
		why = tr("ui.map_raided")
	elif flagship and not NightOps.flagship_unlocked(state, data):
		why = tr("ui.map_locked") % district.influence_required
	elif state.raid_cooldowns.get(rival.id, 0) > state.day:
		why = tr("ui.map_cooldown") % (state.raid_cooldowns[rival.id] - state.day)
	if why != "":
		lines.append(why)
	var pin := UiTheme.button("\n".join(lines), target_picked.emit.bind(rival.id))
	pin.custom_minimum_size = PIN_SIZE
	pin.size = PIN_SIZE
	pin.position = size * spot - PIN_SIZE * 0.5
	pin.disabled = why != ""
	pin.add_theme_font_size_override("font_size", 15)
	return pin


## Streets: a dark map with roads from your café to every pin.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BACKGROUND)
	for x: int in range(0, int(size.x), 120):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(UiTheme.PANEL_BORDER, 0.04), 1.0)
	for y: int in range(0, int(size.y), 120):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(UiTheme.PANEL_BORDER, 0.04), 1.0)
	if not Session.has_game():
		return
	var district := Session.data.districts[Session.state.district_id]
	var home := size * HOME
	draw_circle(home, 16, UiTheme.GOOD)
	for i: int in district.rivals.size() + 1:
		var at := size * SPOTS[i % SPOTS.size()]
		var bend := Vector2(at.x, home.y - 60)
		draw_polyline(PackedVector2Array([home, bend, at]), Color(UiTheme.TEXT_DIM, 0.35), 6.0)
		draw_circle(at, 10, UiTheme.BAD)
