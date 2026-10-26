class_name CafeView
extends Node2D
## The café drawn in isometric placeholder shapes: the floor grid, furniture and
## décor as raised blocks, customers and Synths as chibi silhouettes with icons
## above their heads (order, satisfaction, star, battery). Clicking a starred
## customer, a Synth or a stove emits a signal; the HUD decides what happens.
## Mouse wheel zooms; right/middle drag (or left drag) pans.
##
## With an editor set (arranging the floor at night), clicks pick up and drop
## pieces instead: the held piece follows the mouse as a green or red ghost
## with its Vibe change, and the pieces it would combine with are outlined.
##
## The logic has no positions for people, so they are placed here: seated
## customers at their SeatMap seat, the queue outside the entrance, servers
## walking from the counter to the table as their delivery progresses.

signal stove_clicked(stove_index: int, screen_position: Vector2)
signal synth_clicked(synth_id: String)
signal customer_clicked(customer_id: String)
## Floor editing: the held piece or the floor changed (the edit panel refreshes).
signal editor_changed
## Esc pressed while editing with nothing in hand.
signal edit_exit_requested

const HEIGHTS: Dictionary[String, float] = {"seat": 14.0, "stove": 30.0, "pod": 56.0, "decor": 22.0}
const KIND_COLORS: Dictionary[String, Color] = {
	"seat": Color("8a6a4a"), "stove": Color("8c95a8"), "pod": Color("5a6a9a"),
}
const HEAD_HIT_RADIUS: float = 30.0
const DRAG_THRESHOLD: float = 8.0
## Screen space taken by the HUD's top bar and the night hub.
const TOP_BAR: float = 50.0
const NIGHT_PANEL: float = 790.0

## Set while arranging the floor; null otherwise.
var editor: FloorEditor = null
var seats := SeatMap.new()
var _hover := Vector2i(-100, -100)
var camera := Camera2D.new()
var _time: float = 0.0
var _drag_from := Vector2.ZERO
var _dragging := false
var _pressed := false
## Person id -> head world position, from the last draw (for clicks).
var _heads: Dictionary[String, Vector2] = {}


func _ready() -> void:
	add_child(camera)
	camera.make_current()
	fit_camera()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Fits the whole floor into the free part of the screen: below the top bar,
## and left of the panel on the right (the night hub at night by default).
func fit_camera(right_panel := -1.0) -> void:
	if not Session.has_game():
		return
	var rect := floor_rect()
	var view := get_viewport_rect().size
	if right_panel < 0.0:
		right_panel = NIGHT_PANEL if Session.state.phase == GameState.Phase.NIGHT else 0.0
	var free := Rect2(0, TOP_BAR, view.x - right_panel, view.y - TOP_BAR)
	var scale := minf(free.size.x * 0.92 / rect.size.x, free.size.y * 0.92 / rect.size.y)
	camera.zoom = Vector2.ONE * clampf(scale, 0.3, 2.5)
	# The camera looks at the screen centre; shift so the floor sits in the free area.
	camera.position = rect.get_center() - (free.get_center() - view * 0.5) / camera.zoom


## World rectangle covering the floor and the queue outside.
func floor_rect() -> Rect2:
	var size := Vector2(Session.data.balance.floor_width, Session.state.floor_rows)
	var points := [Iso.to_world(Vector2.ZERO), Iso.to_world(Vector2(size.x, 0)), Iso.to_world(size),
		Iso.to_world(Vector2(0, size.y)), Iso.to_world(Vector2(size.x + 5, size.y))]
	var rect := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	return rect.grow_individual(20, 90, 20, 30)


func _unhandled_input(event: InputEvent) -> void:
	if not Session.has_game():
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_zoom(1.1 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				if button.pressed:
					_pressed = true
					_dragging = button.button_index != MOUSE_BUTTON_LEFT
					_drag_from = button.position
				else:
					# The event's own position, not the cursor's (they differ for injected input).
					var world := get_canvas_transform().affine_inverse() * button.position
					if not _dragging:
						if editor != null:
							_edit_click(button.button_index, world)
						elif button.button_index == MOUSE_BUTTON_LEFT:
							_click(world, button.position)
					_pressed = false
					_dragging = false
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_hover = Iso.tile_at(get_canvas_transform().affine_inverse() * motion.position)
		if not _pressed:
			return
		if not _dragging and motion.position.distance_to(_drag_from) > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			camera.position -= motion.relative / camera.zoom


func _unhandled_key_input(event: InputEvent) -> void:
	if editor == null or not event.is_pressed() or event.is_echo():
		return
	match (event as InputEventKey).keycode:
		KEY_R:
			editor.rotate()
		KEY_ESCAPE:
			if editor.is_holding():
				editor.cancel()
			else:
				edit_exit_requested.emit()
		_:
			return
	editor_changed.emit()
	get_viewport().set_input_as_handled()


## Left click drops the held piece (or picks up the piece under the mouse);
## right click puts the held piece down where it was.
func _edit_click(button: MouseButton, world: Vector2) -> void:
	var state := Session.state
	var tile := Iso.tile_at(world)
	if button == MOUSE_BUTTON_RIGHT:
		editor.cancel()
	elif button == MOUSE_BUTTON_LEFT:
		if editor.is_holding():
			Session.act(editor.drop(state, ghost_cell(tile), Session.data))
		else:
			var placed := Layout.piece_at(state, tile, Session.data)
			if placed != null:
				editor.hold_placed(state, placed.uid)
	editor_changed.emit()


## Top-left cell of the held piece when the mouse is over tile (the piece is centred on it).
func ghost_cell(tile: Vector2i) -> Vector2i:
	var size := Session.data.pieces[editor.held_piece].footprint(editor.rotated)
	return tile - Vector2i((size.x - 1) / 2, (size.y - 1) / 2)


func _zoom(factor: float) -> void:
	camera.zoom = (camera.zoom * factor).clamp(Vector2.ONE * 0.3, Vector2.ONE * 3.0)


func _click(world: Vector2, screen: Vector2) -> void:
	var state := Session.state
	for customer: Customer in state.customers:
		if customer.stage == Customer.Stage.STAR and _hit(customer.id, world):
			customer_clicked.emit(customer.id)
			return
	for synth: Synth in state.synths:
		if _hit(synth.id, world):
			synth_clicked.emit(synth.id)
			return
	var tile := Iso.tile_at(world)
	for i: int in state.stoves.size():
		var placed := Layout.placed_by_uid(state, state.stoves[i].piece_uid)
		if placed != null and Layout.cells(placed, Session.data).has(tile):
			stove_clicked.emit(i, screen)
			return


func _hit(person_id: String, world: Vector2) -> bool:
	return _heads.has(person_id) and _heads[person_id].distance_to(world) <= HEAD_HIT_RADIUS


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	if not Session.has_game():
		return
	var state := Session.state
	var data := Session.data
	seats.update(state, data)
	_heads.clear()
	_draw_floor(state, data)
	# Everything standing on the floor, far to near.
	var drawables: Array[Array] = []
	for placed: PlacedPiece in state.placed:
		var size := data.pieces[placed.piece_id].footprint(placed.rotated)
		drawables.append([Iso.depth(Vector2(placed.cell) + Vector2(size) * 0.5), _draw_piece.bind(placed)])
	for entry: Array in _people(state, data):
		drawables.append([Iso.depth(entry[1]) + 0.3, entry[0]])
	drawables.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry: Array in drawables:
		entry[1].call()
	_draw_counter(state, data)
	if editor != null:
		_draw_editing(state, data)


func _draw_floor(state: GameState, data: GameData) -> void:
	var width := data.balance.floor_width
	# Back walls along the far edges.
	var wall := Vector2(0, -70)
	var top := Iso.to_world(Vector2.ZERO)
	var right := Iso.to_world(Vector2(width, 0))
	var left := Iso.to_world(Vector2(0, state.floor_rows))
	draw_colored_polygon(PackedVector2Array([top, right, right + wall, top + wall]), UiTheme.WALL)
	draw_colored_polygon(PackedVector2Array([left, top, top + wall, left + wall]), UiTheme.WALL.lightened(0.08))
	for y: int in state.floor_rows:
		for x: int in width:
			var cell := Vector2(x, y)
			var tile := PackedVector2Array([Iso.to_world(cell), Iso.to_world(cell + Vector2(1, 0)),
				Iso.to_world(cell + Vector2(1, 1)), Iso.to_world(cell + Vector2(0, 1))])
			draw_colored_polygon(tile, UiTheme.FLOOR_A if (x + y) % 2 == 0 else UiTheme.FLOOR_B)
	# Entrance mat on the right edge, where the queue forms.
	var door := Vector2(width, state.floor_rows - 1)
	draw_colored_polygon(PackedVector2Array([Iso.to_world(door), Iso.to_world(door + Vector2(0.6, 0)),
		Iso.to_world(door + Vector2(0.6, 1)), Iso.to_world(door + Vector2(0, 1))]), UiTheme.ACCENT.darkened(0.4))


func _draw_piece(placed: PlacedPiece) -> void:
	var data := Session.data
	var piece := data.pieces[placed.piece_id]
	var size := Vector2(piece.footprint(placed.rotated))
	var color := piece_color(piece)
	if editor != null and placed.uid == editor.held_uid:
		color.a = 0.3  # being moved: the ghost shows where it goes
	_draw_block(Vector2(placed.cell), size, HEIGHTS.get(piece.kind, 20.0), color)
	var label_at := Iso.centre(placed.cell, Vector2i(size)) - Vector2(0, HEIGHTS.get(piece.kind, 20.0) + 6)
	if piece.kind == Piece.STOVE:
		var stove := Layout.stove_of(Session.state, placed.uid)
		if stove != null and not stove.is_idle():
			var recipe := data.recipes[stove.recipe_id]
			_draw_bar(label_at + Vector2(0, -10), 60, 1.0 - stove.remaining / recipe.cook_seconds, UiTheme.WARN)
			_text(label_at + Vector2(0, -20), UiText.name(recipe.id), 14, UiTheme.TEXT)
	elif piece.kind == Piece.DECOR:
		_text(label_at, UiText.name(piece.id), 12, UiTheme.TEXT_DIM)


static func piece_color(piece: Piece) -> Color:
	return KIND_COLORS.get(piece.kind, UiTheme.TAG_COLORS.get(piece.tags[0] if not piece.tags.is_empty() else "", Color.GRAY))


## The held piece's ghost with its Vibe change and the neighbours it combines
## with, or an outline on the piece under the mouse when nothing is held.
func _draw_editing(state: GameState, data: GameData) -> void:
	if not editor.is_holding():
		var under := Layout.piece_at(state, _hover, data)
		if under != null:
			_outline(under, UiTheme.PANEL_BORDER)
		return
	if _hover.x < -50:
		return
	var cell := ghost_cell(_hover)
	var preview := editor.preview(state, cell, data)
	var ok: bool = preview["error"] == GameLoop.OK
	var piece := data.pieces[editor.held_piece]
	var size := Vector2(piece.footprint(editor.rotated))
	var color := UiTheme.GOOD if ok else UiTheme.BAD
	color.a = 0.55
	_draw_block(Vector2(cell), size, HEIGHTS.get(piece.kind, 20.0), color)
	for uid: String in preview["matches"]:
		_outline(Layout.placed_by_uid(state, uid), UiTheme.WARN)
	var label_at := Iso.centre(cell, Vector2i(size)) - Vector2(0, HEIGHTS.get(piece.kind, 20.0) + 14)
	var text: String = tr("ui.edit_vibe_delta") % roundi(preview["delta"]) if ok else UiText.error(preview["error"])
	var text_color := (UiTheme.GOOD if preview["delta"] >= 0.0 else UiTheme.WARN) if ok else UiTheme.BAD
	_text(label_at, text, 16, text_color)


## Outlines the top of a placed piece.
func _outline(placed: PlacedPiece, color: Color) -> void:
	var piece := Session.data.pieces[placed.piece_id]
	var size := Vector2(piece.footprint(placed.rotated))
	var lift := Vector2(0, -HEIGHTS.get(piece.kind, 20.0))
	var cell := Vector2(placed.cell)
	draw_polyline(PackedVector2Array([Iso.to_world(cell) + lift, Iso.to_world(cell + Vector2(size.x, 0)) + lift,
		Iso.to_world(cell + size) + lift, Iso.to_world(cell + Vector2(0, size.y)) + lift, Iso.to_world(cell) + lift]),
		color, 3.0)


## An isometric box on the floor.
func _draw_block(cell: Vector2, size: Vector2, height: float, color: Color) -> void:
	var lift := Vector2(0, -height)
	var a := Iso.to_world(cell)
	var b := Iso.to_world(cell + Vector2(size.x, 0))
	var c := Iso.to_world(cell + size)
	var d := Iso.to_world(cell + Vector2(0, size.y))
	draw_colored_polygon(PackedVector2Array([d, c, c + lift, d + lift]), color.darkened(0.35))
	draw_colored_polygon(PackedVector2Array([c, b, b + lift, c + lift]), color.darkened(0.2))
	var top := PackedVector2Array([a + lift, b + lift, c + lift, d + lift])
	draw_colored_polygon(top, color)
	top.append(a + lift)
	draw_polyline(top, color.darkened(0.55), 2.0)


## [draw callable, cell position] for every customer and Synth.
func _people(state: GameState, data: GameData) -> Array[Array]:
	var result: Array[Array] = []
	var width := float(data.balance.floor_width)
	var rows := float(state.floor_rows)
	var queue_index := 0
	var star_index := 0
	for customer: Customer in state.customers:
		var at: Vector2
		match customer.stage:
			Customer.Stage.QUEUED:
				at = Vector2(width + 0.6 + queue_index * 0.8, rows - 0.5)
				queue_index += 1
			Customer.Stage.STAR:
				at = Vector2(width - 0.6 - star_index * 0.8, rows - 0.35)
				star_index += 1
			_:
				at = _seat_position(customer.id, state, data)
		result.append([_draw_customer.bind(customer, at), at])
	var pass_point := _pass_point(state, data)
	var counts: Dictionary[String, int] = {}
	var pod_cells: Array[Vector2] = []
	for placed: PlacedPiece in state.placed:
		if data.pieces[placed.piece_id].kind == Piece.POD:
			pod_cells.append(Vector2(placed.cell) + Vector2(data.pieces["pod"].footprint(placed.rotated)) * 0.5)
	var rest_index := 0
	for synth: Synth in state.synths:
		var index: int = counts.get(synth.role, 0)
		counts[synth.role] = index + 1
		var at: Vector2
		match synth.role:
			Synth.SERVER:
				at = pass_point + Vector2(0.7 * index, 0.4)
				if synth.is_delivering():
					var progress := clampf(1.0 - synth.task_remaining / data.balance.delivery_seconds, 0.0, 1.0)
					at = at.lerp(_seat_position(synth.task_customer_id, state, data) + Vector2(0.3, 0.3), progress)
			Synth.CHEF:
				at = _stove_front(index, state, data)
			Synth.GREETER:
				at = Vector2(width - 0.5, rows - 1.6 - index * 0.7)
			_:
				at = pod_cells[rest_index] if rest_index < pod_cells.size() else Vector2(0.5, rows - 0.5)
				rest_index += 1
		result.append([_draw_synth.bind(synth, at), at])
	return result


func _seat_position(customer_id: String, state: GameState, data: GameData) -> Vector2:
	var placed := Layout.placed_by_uid(state, seats.seat_of.get(customer_id, ""))
	if placed == null:
		return Vector2(data.balance.floor_width - 1, state.floor_rows - 1)
	return Vector2(placed.cell) + Vector2(0.5, 0.5)


## Where servers pick up dishes: in front of the first stove.
func _pass_point(state: GameState, data: GameData) -> Vector2:
	if state.stoves.is_empty():
		return Vector2(1, 1)
	return _stove_front(0, state, data) + Vector2(0.4, 0.5)


func _stove_front(index: int, state: GameState, data: GameData) -> Vector2:
	if state.stoves.is_empty():
		return Vector2(1, 1)
	var placed := Layout.placed_by_uid(state, state.stoves[index % state.stoves.size()].piece_uid)
	var size := Vector2(data.pieces["stove"].footprint(placed.rotated))
	return Vector2(placed.cell) + Vector2(size.x * 0.5, size.y + 0.35)


func _draw_customer(customer: Customer, at: Vector2) -> void:
	var color: Color = UiTheme.CUSTOMER_COLORS.get(customer.type_id, Color.GRAY)
	var head := _draw_body(at, color, Color("ffd9b8"), customer.id)
	var above := head + Vector2(0, -30)
	match customer.stage:
		Customer.Stage.QUEUED, Customer.Stage.WAITING_FOOD:
			_draw_bar(above + Vector2(0, 8), 34, customer.satisfaction / 100.0, _mood_color(customer.satisfaction))
			if customer.stage == Customer.Stage.WAITING_FOOD:
				draw_circle(above + Vector2(0, -8), 15, Color.WHITE)
				_text(above + Vector2(0, -2), UiText.name(customer.recipe_id).left(2), 14, Color.BLACK)
		Customer.Stage.EATING:
			_draw_bar(above + Vector2(0, 8), 34, 1.0 - float(customer.timer) / Session.data.balance.eat_seconds, UiTheme.GOOD)
		Customer.Stage.STAR:
			var pulse := 1.0 + 0.12 * sin(_time * 6.0)
			_draw_star(above + Vector2(0, -6), 16.0 * pulse, UiTheme.WARN)


func _draw_synth(synth: Synth, at: Vector2) -> void:
	var glow: Color = UiTheme.SPECIES_GLOW.get(synth.species_id, Color.CYAN)
	draw_circle(Iso.to_world(at), 22, Color(glow, 0.18))
	var head := _draw_body(at, Color("9aa3b8"), glow, synth.id, true)
	var above := head + Vector2(0, -28)
	var data := Session.data
	_draw_bar(above + Vector2(0, 6), 34, synth.battery / SynthStats.stat(synth, "battery_max", data), _battery_color(synth, data))
	_text(above + Vector2(0, -4), "Lv%d" % synth.level, 13, glow)
	if synth.is_delivering():
		draw_circle(head + Vector2(16, 18), 7, Color.WHITE)


## Shadow, body and head of a chibi; returns the head position. Synths get a visor.
func _draw_body(at: Vector2, body: Color, head_color: Color, person_id: String, visor := false) -> Vector2:
	var feet := Iso.to_world(at)
	draw_set_transform(feet, 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 16, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	var body_rect := Rect2(feet + Vector2(-11, -30), Vector2(22, 28))
	draw_rect(body_rect, body)
	draw_rect(body_rect, body.darkened(0.6), false, 2.0)
	var head := feet + Vector2(0, -44)
	draw_circle(head, 15, Color("ffd9b8") if visor else head_color)
	if visor:
		draw_rect(Rect2(head + Vector2(-12, -5), Vector2(24, 9)), head_color)
	draw_arc(head, 15, 0, TAU, 24, Color("1a1428"), 2.0)
	_heads[person_id] = head
	return head


func _draw_counter(state: GameState, data: GameData) -> void:
	var at := Iso.to_world(_pass_point(state, data)) + Vector2(-150, 10)
	var lines: Array[String] = []
	for recipe_id: String in state.counter:
		if state.counter[recipe_id] > 0:
			lines.append("%s ×%d" % [UiText.name(recipe_id), state.counter[recipe_id]])
	if lines.is_empty():
		return
	_text(at, tr("ui.counter"), 13, UiTheme.TEXT_DIM)
	for i: int in lines.size():
		_text(at + Vector2(0, 16 * (i + 1)), lines[i], 14, UiTheme.TEXT)


func _draw_bar(centre: Vector2, width: float, value: float, color: Color) -> void:
	var rect := Rect2(centre - Vector2(width * 0.5, 3), Vector2(width, 6))
	draw_rect(rect, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(rect.position, Vector2(width * clampf(value, 0.0, 1.0), 6)), color)


func _draw_star(centre: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in 10:
		var angle := -PI / 2 + i * PI / 5
		points.append(centre + Vector2.from_angle(angle) * (radius if i % 2 == 0 else radius * 0.45))
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, color.darkened(0.5), 2.0)


func _text(centre: Vector2, text: String, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, centre - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _mood_color(satisfaction: float) -> Color:
	return UiTheme.GOOD if satisfaction >= Session.data.balance.star_threshold else (UiTheme.WARN if satisfaction >= 40.0 else UiTheme.BAD)


func _battery_color(synth: Synth, data: GameData) -> Color:
	var factor := SynthStats.battery_factor(synth, data)
	return UiTheme.GOOD if factor >= 1.0 else (UiTheme.WARN if factor > 0.0 else UiTheme.BAD)
