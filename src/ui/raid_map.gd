class_name RaidMap
extends Control
## The town map, opened from Night Ops: a neon town about two screens wide
## that the player drags around to look for a MegaBean bar to raid. Streets,
## blocks of buildings and signs are drawn in code, the same on every visit
## (seeded by the town). Each bar stands at its spot (data: "spot"): a
## red-signed building; the boss bar a taller tower with a crown; beaten bars
## carry a green check; the player's own bar (the first town's "home") a cyan sign.
##
## Click a bar (a press and release without dragging) to see its card: guards
## and their level, loot, and whether it can be raided tonight (already raided,
## cooling down, or the boss still locked until every bar in town is beaten).
## The card's Raid button plans the raid (RaidSetup). A minimap in the corner
## shows every bar and what is on screen; clicking it jumps there.
##
## Tabs along the top show the towns: the current one, the ones taken (to look
## at; raids happen in the current town), and the next ones locked.

signal closed
## A bar to raid was picked.
signal target_picked(rival_id: String)

## The town map's size (world px).
const TOWN_SIZE := Vector2(3400, 1900)
## A street every this many px, both ways.
const BLOCK: float = 340.0
const STREET: float = 70.0
## A bar's building on the map (its footprint) and how near a click must be.
const BAR_SIZE := Vector2(150, 110)
const BOSS_SIZE := Vector2(220, 170)
## Moves smaller than this (px) between press and release count as a click.
const DRAG_SLOP: float = 8.0

## The town on show (the current one when opened).
var town_id: String = ""
## The bar whose card is open ("" = none).
var selected: String = ""
## Where the map's top-left corner is on screen (dragging changes it).
var offset: Vector2 = Vector2.ZERO
var _title := UiTheme.label("", 30, UiTheme.PANEL_BORDER)
var _hint := UiTheme.label("", 16, UiTheme.TEXT_DIM)
var _tabs := HBoxContainer.new()
var _card := PanelContainer.new()
var _card_text := UiTheme.label("", 16)
var _raid := UiTheme.button(tr("ui.map_raid"), func() -> void: target_picked.emit(selected))
var _press: Vector2 = Vector2(-1, -1)
var _dragged: bool = false
## Seeded scenery for the town on show: [rect, colour] buildings and [rect, colour] signs.
var _blocks: Array[Array] = []
var _signs: Array[Array] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var top := VBoxContainer.new()
	top.position = Vector2(30, 20)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_title)
	top.add_child(_hint)
	top.add_child(_tabs)
	add_child(top)
	_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_card.position = Vector2(30, -250)
	_card.custom_minimum_size = Vector2(380, 0)
	var column := VBoxContainer.new()
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size = Vector2(350, 0)
	column.add_child(_card_text)
	_raid.custom_minimum_size = Vector2(0, 48)
	column.add_child(_raid)
	_card.add_child(column)
	_card.visible = false
	add_child(_card)
	var close := UiTheme.button(tr("ui.close"), close_map)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.position = Vector2(-150, 24)
	close.custom_minimum_size = Vector2(120, 46)
	add_child(close)
	resized.connect(func() -> void: _clamp())


## Opens on the current town, centred on its bars.
func open() -> void:
	visible = true
	move_to_front()
	show_town(Session.state.district_id)


func close_map() -> void:
	visible = false
	closed.emit()


## Shows a town (one the player has reached), scrolled to the middle of its bars.
func show_town(district_id: String) -> void:
	town_id = district_id
	selected = ""
	_build_scenery()
	offset = size * 0.5 - TOWN_SIZE * 0.5
	_clamp()
	refresh()


func refresh() -> void:
	if not visible or not Session.has_game():
		return
	var state := Session.state
	var data := Session.data
	var town := data.districts[town_id]
	_title.text = tr("ui.map_title") % [UiText.name(town.id), NightOps.bars_beaten(state, town), town.rivals.size()]
	_hint.text = tr("ui.map_drag") if town_id == state.district_id else tr("ui.map_view_only") % UiText.name(state.district_id)
	for child: Node in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	var previous := ""
	for district_id: String in data.district_order:
		var reached := state.owned_districts.has(district_id) or district_id == state.district_id
		var tab := UiTheme.button(("✓ " if state.owned_districts.has(district_id) else "") + UiText.name(district_id) if reached
			else "🔒 " + UiText.name(district_id), show_town.bind(district_id))
		tab.toggle_mode = true
		tab.button_pressed = district_id == town_id
		tab.disabled = not reached
		tab.tooltip_text = "" if reached else tr("ui.map_town_locked") % UiText.name(previous)
		tab.add_theme_font_size_override("font_size", 15)
		_tabs.add_child(tab)
		previous = district_id
	_fill_card(state, data, town)
	queue_redraw()


## The open card: the selected bar's name, guards, loot and status, and the Raid button.
func _fill_card(state: GameState, data: GameData, town: District) -> void:
	var rival := town.rival_by_id(selected) if selected != "" else null
	_card.visible = rival != null
	if rival == null:
		return
	var boss := town.is_flagship(rival.id)
	var lines: Array[String] = [UiText.name(rival.id) + (tr("ui.map_flagship") if boss else "")]
	lines.append(tr("ui.map_guards") % [rival.defenders.size(), NightOps.average_level(state, rival, data)])
	lines.append(tr("ui.map_loot") % [rival.loot_coins, rival.loot_cores])
	if state.beaten.has(rival.id):
		lines.append(tr("ui.map_beaten"))
	var why := _why_not(rival, state, data, town)
	if why != "":
		lines.append(why)
	_card_text.text = "\n".join(lines)
	_raid.disabled = why != ""
	_card.reset_size()
	_card.position = Vector2(30, size.y - _card.size.y - 30)


## Why a bar can't be raided tonight ("" = it can).
func _why_not(rival: RivalCafe, state: GameState, data: GameData, town: District) -> String:
	if town.id != state.district_id:
		return tr("ui.map_taken") if state.owned_districts.has(town.id) else tr("ui.map_town_locked") % UiText.name(state.district_id)
	if state.last_raid_day == state.day:
		return tr("ui.map_raided")
	if town.is_flagship(rival.id) and not NightOps.flagship_unlocked(state, data):
		return tr("ui.map_boss_locked") % [NightOps.bars_beaten(state, town), town.rivals.size()]
	if state.raid_cooldowns.get(rival.id, 0) > state.day:
		return tr("ui.map_cooldown") % (state.raid_cooldowns[rival.id] - state.day)
	return ""


# --- Dragging and clicking ---------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if button.pressed and _minimap_rect().has_point(button.position):
			# A click on the minimap jumps there.
			var share := (button.position - _minimap_rect().position) / _minimap_rect().size
			offset = size * 0.5 - TOWN_SIZE * share
			_clamp()
			queue_redraw()
			_press = Vector2(-1, -1)
			accept_event()
			return
		if button.pressed:
			_press = button.position
			_dragged = false
		else:
			if not _dragged and button.button_index == MOUSE_BUTTON_LEFT and _press.x >= 0.0:
				select(bar_at(button.position - offset))
			_press = Vector2(-1, -1)
		accept_event()
		return
	if button != null and button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		# The wheel scrolls up and down (with Shift: sideways).
		var step := 90.0 * (1.0 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
		pan(Vector2(step, 0) if button.shift_pressed else Vector2(0, step))
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _press.x >= 0.0 and motion.button_mask != 0:
		if _dragged or motion.position.distance_to(_press) > DRAG_SLOP:
			_dragged = true
			pan(motion.relative)
		accept_event()


## Moves the map by delta (screen px), kept inside the town.
func pan(delta: Vector2) -> void:
	offset += delta
	_clamp()
	queue_redraw()


## Opens the card of a bar of the town on show ("" closes it).
func select(rival_id: String) -> void:
	selected = rival_id
	if Session.has_game():
		_fill_card(Session.state, Session.data, Session.data.districts[town_id])
	queue_redraw()


## The bar whose building is under a map point, or "".
func bar_at(point: Vector2) -> String:
	var town := Session.data.districts[town_id]
	for rival: RivalCafe in town.rivals + [town.flagship]:
		if _bar_rect(town, rival).grow(10.0).has_point(point):
			return rival.id
	return ""


## Where a bar is on screen (its building's centre), for tests and tools.
func bar_screen_position(rival_id: String) -> Vector2:
	var town := Session.data.districts[town_id]
	return offset + _bar_rect(town, town.rival_by_id(rival_id)).get_center()


func _clamp() -> void:
	var low := Vector2(minf(size.x - TOWN_SIZE.x, 0.0), minf(size.y - TOWN_SIZE.y, 0.0))
	offset = Vector2(clampf(offset.x, low.x, maxf(0.0, (size.x - TOWN_SIZE.x) * 0.5)),
		clampf(offset.y, low.y, maxf(0.0, (size.y - TOWN_SIZE.y) * 0.5)))


## A bar's building on the town map: at its spot, or placed round the middle if it has none.
func _bar_rect(town: District, rival: RivalCafe) -> Rect2:
	var boss := town.is_flagship(rival.id)
	var footprint := BOSS_SIZE if boss else BAR_SIZE
	var spot := rival.spot
	if spot.x < 0.0:
		var index := town.rivals.find(rival)
		var angle := TAU * float(index) / maxf(float(town.rivals.size()), 1.0)
		spot = Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * 0.35 if not boss else Vector2(0.5, 0.15)
	return Rect2(TOWN_SIZE * spot - footprint * 0.5, footprint)


# --- Drawing -----------------------------------------------------------------

## The town's scenery, the same every visit: blocks of buildings between the streets, some signs.
func _build_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(town_id)
	_blocks.clear()
	_signs.clear()
	var palette: Array[Color] = [Color("ff2fb4"), Color("19f0ff"), Color("b6ff3b"), Color("ffb03b")]
	var y := STREET
	while y < TOWN_SIZE.y:
		var x := STREET
		while x < TOWN_SIZE.x:
			var cell := Rect2(x, y, BLOCK - STREET, BLOCK - STREET)
			# Each block holds a few buildings.
			var cols := rng.randi_range(2, 3)
			var rows := rng.randi_range(1, 2)
			for c: int in cols:
				for r: int in rows:
					var w := cell.size.x / cols
					var h := cell.size.y / rows
					var building := Rect2(cell.position + Vector2(c * w + 6, r * h + 6), Vector2(w - 12, h - 12))
					_blocks.append([building, Color("1a1428").lerp(Color("241a3a"), rng.randf())])
					if rng.randf() < 0.22:
						var sign_rect := Rect2(building.position + Vector2(rng.randf_range(6.0, building.size.x - 40.0), 8),
							Vector2(rng.randf_range(24.0, 40.0), 10))
						_signs.append([sign_rect, palette[rng.randi_range(0, 3)]])
			x += BLOCK
		y += BLOCK


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.BACKGROUND)
	if not Session.has_game() or town_id == "":
		return
	var state := Session.state
	var town := Session.data.districts[town_id]
	draw_set_transform(offset)
	# Asphalt and streets with neon lane lines.
	draw_rect(Rect2(Vector2.ZERO, TOWN_SIZE), Color("0f0c18"))
	var x := 0.0
	while x <= TOWN_SIZE.x:
		draw_rect(Rect2(x, 0, STREET, TOWN_SIZE.y), Color("16121f"))
		draw_dashed_line(Vector2(x + STREET * 0.5, 0), Vector2(x + STREET * 0.5, TOWN_SIZE.y), Color("19f0ff", 0.18), 2.0, 18.0)
		x += BLOCK
	var y := 0.0
	while y <= TOWN_SIZE.y:
		draw_rect(Rect2(0, y, TOWN_SIZE.x, STREET), Color("16121f"))
		draw_dashed_line(Vector2(0, y + STREET * 0.5), Vector2(TOWN_SIZE.x, y + STREET * 0.5), Color("ff2fb4", 0.16), 2.0, 18.0)
		y += BLOCK
	# Buildings (left out where a bar stands) and their signs.
	var bars: Array[Rect2] = []
	for rival: RivalCafe in town.rivals + [town.flagship]:
		bars.append(_bar_rect(town, rival).grow(30.0))
	if town.home.x >= 0.0:
		bars.append(Rect2(TOWN_SIZE * town.home - BAR_SIZE * 0.5, BAR_SIZE).grow(30.0))
	for block: Array in _blocks:
		var rect: Rect2 = block[0]
		if bars.any(func(bar: Rect2) -> bool: return bar.intersects(rect)):
			continue
		draw_rect(rect, block[1])
		draw_rect(rect, Color("2a2238"), false, 2.0)
		for wy in range(int(rect.position.y + 24), int(rect.end.y - 8), 18):
			for wx in range(int(rect.position.x + 10), int(rect.end.x - 8), 16):
				if (wx * 7 + wy * 13) % 5 == 0:
					draw_rect(Rect2(wx, wy, 6, 7), Color("ffd9a0", 0.35))
	for sign_entry: Array in _signs:
		draw_rect(sign_entry[0], Color(sign_entry[1], 0.8))
		draw_rect((sign_entry[0] as Rect2).grow(5.0), Color(sign_entry[1], 0.12))
	if town.home.x >= 0.0:
		_draw_building(Rect2(TOWN_SIZE * town.home - BAR_SIZE * 0.5, BAR_SIZE), UiTheme.PANEL_BORDER, tr("ui.map_home"), false,
			false, false)
	for rival: RivalCafe in town.rivals + [town.flagship]:
		var boss := town.is_flagship(rival.id)
		var open := _why_not(rival, state, Session.data, town) == ""
		_draw_building(_bar_rect(town, rival), UiTheme.BAD if open or state.beaten.has(rival.id) else UiTheme.TEXT_DIM,
			UiText.name(rival.id), boss, state.beaten.has(rival.id), rival.id == selected)
	draw_set_transform(Vector2.ZERO)
	_draw_minimap(town, state)


## The whole town small in the top-right corner: every bar as a dot (gold: the
## boss, green: beaten), your bar in cyan, and a frame round what is on screen.
func _draw_minimap(town: District, state: GameState) -> void:
	var box := _minimap_rect()
	var to_box := box.size / TOWN_SIZE
	draw_rect(box.grow(4.0), Color(UiTheme.BACKGROUND, 0.9))
	draw_rect(box, Color("16121f"))
	draw_rect(box, Color(UiTheme.PANEL_BORDER, 0.8), false, 2.0)
	if town.home.x >= 0.0:
		draw_circle(box.position + TOWN_SIZE * town.home * to_box, 5, UiTheme.PANEL_BORDER)
	for rival: RivalCafe in town.rivals + [town.flagship]:
		var color := UiTheme.WARN if town.is_flagship(rival.id) else (UiTheme.GOOD if state.beaten.has(rival.id) else UiTheme.BAD)
		draw_circle(box.position + _bar_rect(town, rival).get_center() * to_box, 6 if town.is_flagship(rival.id) else 4.5, color)
	var view := Rect2(-offset * to_box, size * to_box).intersection(Rect2(Vector2.ZERO, box.size))
	draw_rect(Rect2(box.position + view.position, view.size), Color.WHITE, false, 1.5)


## Where the minimap sits on screen (top right, under the Close button).
func _minimap_rect() -> Rect2:
	var width := 260.0
	return Rect2(Vector2(size.x - width - 30.0, 90.0), Vector2(width, width * TOWN_SIZE.y / TOWN_SIZE.x))


## A building on the map: a dark block with a neon sign, a crown for the boss,
## a check when beaten, a bright frame when selected.
func _draw_building(rect: Rect2, sign_color: Color, label: String, boss: bool, beaten: bool, chosen: bool) -> void:
	draw_rect(rect.grow(18.0), Color(sign_color, 0.10))
	draw_rect(rect, Color("1c1428"))
	draw_rect(rect, Color(sign_color, 0.9), false, 3.0)
	for wy in range(int(rect.position.y + 40), int(rect.end.y - 10), 20):
		for wx in range(int(rect.position.x + 14), int(rect.end.x - 12), 22):
			draw_rect(Rect2(wx, wy, 9, 9), Color(sign_color, 0.35))
	var sign_rect := Rect2(rect.position + Vector2(10, 8), Vector2(rect.size.x - 20, 22))
	draw_rect(sign_rect, Color("0a0812"))
	draw_rect(sign_rect, sign_color, false, 2.0)
	var font := ThemeDB.fallback_font
	var font_size := 15 if not boss else 18
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(rect.get_center().x - width * 0.5, rect.end.y + 24), label, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, UiTheme.TEXT)
	draw_circle(sign_rect.get_center(), 7, sign_color)
	if boss:
		var top := Vector2(rect.get_center().x, rect.position.y - 8)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-30, 0), top + Vector2(-30, -26), top + Vector2(-15, -12),
			top + Vector2(0, -32), top + Vector2(15, -12), top + Vector2(30, -26), top + Vector2(30, 0)]), UiTheme.WARN)
	if beaten:
		var mark := rect.position + Vector2(rect.size.x - 6, -6)
		draw_circle(mark, 16, UiTheme.GOOD)
		draw_polyline(PackedVector2Array([mark + Vector2(-8, 0), mark + Vector2(-2, 7), mark + Vector2(9, -7)]), Color("0a0812"), 4.0)
	if chosen:
		draw_rect(rect.grow(8.0), Color.WHITE, false, 3.0)
