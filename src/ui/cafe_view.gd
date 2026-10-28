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
## customers at the seat the game gave them, the queue outside the entrance, servers
## walking from the counter to the table as their delivery progresses.

signal stove_clicked(stove_index: int, screen_position: Vector2)
## A counter was clicked (to throw its food away).
signal counter_clicked(counter_uid: String)
## With a worker selected: a placed piece (its job) or the Pod bay ("") was clicked.
signal job_clicked(uid: String, screen_position: Vector2)
## A click that hit nothing (closes the worker card).
signal blank_clicked
signal synth_clicked(synth_id: String)
signal customer_clicked(customer_id: String)
## The mouse moved onto a customer ("" when it left them), with the screen position.
signal customer_hovered(customer_id: String, screen_position: Vector2)
## Floor editing: the held piece or the floor changed (the edit panel refreshes).
signal editor_changed
## Esc pressed while editing with nothing in hand.
signal edit_exit_requested

const HEIGHTS: Dictionary[String, float] = {"seat": 14.0, "table": 24.0, "stove": 30.0, "pod": 56.0, "counter": 26.0,
	"bin": 24.0, "register": 28.0, "decor": 22.0}
const KIND_COLORS: Dictionary[String, Color] = {
	"seat": Color("8a6a4a"), "stove": Color("8c95a8"), "pod": Color("5a6a9a"), "counter": Color("c9a27a"),
	"bin": Color("4f6b5a"), "table": Color("b08a5a"), "register": Color("5b6bd0"),
}
const HEAD_HIT_RADIUS: float = 30.0
const DRAG_THRESHOLD: float = 8.0
## Tiles between Pods in the Pod bay.
const BAY_SPACING: float = 1.1
## The walkway (tiles) between the café's front wall and the Pod bay.
const BAY_GAP: float = 1.0
## Customers walk this many tiles per second at 1x.
const WALK_SPEED: float = 3.0
## Screen space taken by the HUD's top bar and the night hub.
const TOP_BAR: float = UiTheme.TOP_BAR_HEIGHT
const NIGHT_PANEL: float = 790.0

## The worker picked to get a job: the next click on a stove, counter, table,
## register or the Pod bay gives it that job ("" = none).
var selected_synth: String = ""
## Set while arranging the floor; null otherwise.
var editor: FloorEditor = null
var _hover := Vector2i(-100, -100)
## The mouse in world space (for picking pieces by their drawn shape).
var _hover_world := Vector2(-10000, -10000)
## Where each customer is drawn (cell units); they walk toward where the game puts them.
var _walk: Dictionary[String, Vector2] = {}
## Customers who left the café, still walking out: id -> {"at", "type_id", "angry"}.
var _leaving: Dictionary[String, Dictionary] = {}
var _walk_delta: float = 0.0
var _walk_types: Dictionary[String, String] = {}
## Customers who left angry (they stomp out with a red mark).
var _angry: Dictionary[String, bool] = {}
## New Synths still walking from where they were converted to their Pod.
var _to_pod: Dictionary[String, bool] = {}
## Walking routes round the furniture (see FloorPaths).
var paths := FloorPaths.new()
## Where each Synth is drawn (cell units); they walk to where their job puts them.
var _synth_at: Dictionary[String, Vector2] = {}
## Walker id -> {"to": target, "key": floor version, "points": route, "next": index}.
var _routes: Dictionary[String, Dictionary] = {}
## Synth id -> the route of its current trip {"key": trip, "points": route}.
var _trips: Dictionary[String, Dictionary] = {}
## Short-lived feedback drawn over the café: {"kind", "at", "age", "life", "text", "color"}.
var _effects: Array[Dictionary] = []
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
	Session.shift_advanced.connect(_on_shift_advanced)
	Session.converted.connect(_on_converted)
	Session.night_resolved.connect(func(report: NightOps.Report) -> void: _level_up_effects(report.level_ups))


func _process(delta: float) -> void:
	_time += delta
	_walk_delta = delta
	for effect: Dictionary in _effects:
		effect["age"] += delta
	_effects = _effects.filter(func(effect: Dictionary) -> bool: return effect["age"] < effect["life"])
	queue_redraw()


## Coin pop-ups over paying customers and level-up rings. Heads are from the
## last frame, so a customer who just left can still be found.
func _on_shift_advanced(events: Shift.Events) -> void:
	for customer_id: String in events.left_angry:
		_angry[customer_id] = true
	for customer_id: String in events.payments:
		if _heads.has(customer_id):
			_effects.append({"kind": "pop", "at": _heads[customer_id] + Vector2(0, -50), "age": 0.0, "life": 1.2,
				"text": "+%d" % events.payments[customer_id], "color": UiTheme.WARN})
	_level_up_effects(events.level_ups)


func _level_up_effects(level_ups: Dictionary[String, int]) -> void:
	for synth_id: String in level_ups:
		if _heads.has(synth_id):
			_effects.append({"kind": "ring", "at": _heads[synth_id], "age": 0.0, "life": 1.4,
				"text": tr("ui.fx_level_up"), "color": UiTheme.PANEL_BORDER})


func _on_converted(customer_id: String, synth: Synth) -> void:
	if _walk.has(customer_id):
		# The customer becomes the Synth and walks round the front of the café into a free Pod.
		_synth_at[synth.id] = _walk[customer_id]
		_to_pod[synth.id] = true
		_walk.erase(customer_id)
		_walk_types.erase(customer_id)
	if not _heads.has(customer_id):
		return
	var glow: Color = UiTheme.SPECIES_GLOW.get(synth.species_id, Color.CYAN)
	_effects.append({"kind": "burst", "at": _heads[customer_id], "age": 0.0, "life": 1.6,
		"text": tr("ui.fx_new_synth"), "color": glow})


func _draw_effects() -> void:
	for effect: Dictionary in _effects:
		var t: float = effect["age"] / effect["life"]
		var at: Vector2 = effect["at"]
		var color: Color = effect["color"]
		var fade := Color(color, 1.0 - t)
		match effect["kind"]:
			"pop":
				_text(at + Vector2(0, -40 * t), effect["text"], 20, fade)
			"ring":
				draw_arc(at, 20 + 40 * t, 0, TAU, 32, fade, 4.0)
				_text(at + Vector2(0, -50 - 20 * t), effect["text"], 18, fade)
			"burst":
				draw_circle(at, 30 + 90 * t, Color(color, 0.35 * (1.0 - t)))
				for i: int in 10:
					var direction := Vector2.from_angle(TAU * i / 10.0 + t)
					draw_circle(at + direction * (20 + 110 * t), 5 * (1.0 - t) + 1, fade)
				_text(at + Vector2(0, -60 - 30 * t), effect["text"], 22, fade)


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
		Iso.to_world(Vector2(0, size.y)), Iso.to_world(Vector2(size.x + 5, size.y)), Iso.to_world(Vector2(size.x + 2, 0)),
		Iso.to_world(Vector2(0, size.y + 2.6)), Iso.to_world(Vector2(size.x, size.y + 2.6))]
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
		_hover_world = get_canvas_transform().affine_inverse() * motion.position
		_hover = Iso.tile_at(_hover_world)
		_update_customer_hover(get_canvas_transform().affine_inverse() * motion.position, motion.position)
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
			var placed := piece_at_point(world)
			if placed != null:
				editor.hold_placed(state, placed.uid)
	editor_changed.emit()


## Top-left cell of the held piece when the mouse is over tile (the piece is centred on it).
func ghost_cell(tile: Vector2i) -> Vector2i:
	var size := Session.data.pieces[editor.held_piece].footprint(editor.rotated)
	return tile - Vector2i((size.x - 1) / 2, (size.y - 1) / 2)


var _hovered_customer: String = ""


func _update_customer_hover(world: Vector2, screen: Vector2) -> void:
	var found := ""
	if editor == null:
		for customer: Customer in Session.state.customers:
			if _hit(customer.id, world):
				found = customer.id
				break
	if found != _hovered_customer or found != "":
		_hovered_customer = found
		customer_hovered.emit(found, screen)


func _zoom(factor: float) -> void:
	camera.zoom = (camera.zoom * factor).clamp(Vector2.ONE * 0.3, Vector2.ONE * 3.0)


func _click(world: Vector2, screen: Vector2) -> void:
	var state := Session.state
	var data := Session.data
	for customer: Customer in state.customers:
		if customer.can_convert() and _hit(customer.id, world):
			customer_clicked.emit(customer.id)
			return
	# A worker's head first: clicking another worker switches to it.
	for synth: Synth in state.synths:
		if _hit(synth.id, world):
			synth_clicked.emit(synth.id)
			return
	var piece := piece_at_point(world)
	var kind: String = data.pieces[piece.piece_id].kind if piece != null else ""
	if selected_synth != "":
		if [Piece.STOVE, Piece.COUNTER, Piece.TABLE, Piece.BIN, Piece.REGISTER].has(kind):
			job_clicked.emit(piece.uid, screen)
			return
		var tile := Iso.tile_at(world)
		if piece == null and tile.y >= state.floor_rows and tile.x >= 0 and tile.x < data.balance.floor_width:
			job_clicked.emit("", screen)  # the Pod bay
			return
	match kind:
		Piece.STOVE:
			stove_clicked.emit(state.stoves.find(Layout.stove_of(state, piece.uid)), screen)
		Piece.COUNTER:
			counter_clicked.emit(piece.uid)
		"":
			blank_clicked.emit()


## The placed piece drawn under a point (its top and sides count, not just
## the floor tile), the nearest one first; null if none.
func piece_at_point(world: Vector2) -> PlacedPiece:
	var data := Session.data
	var best: PlacedPiece = null
	var best_depth := -INF
	for placed: PlacedPiece in Session.state.placed:
		var piece := data.pieces[placed.piece_id]
		var size := Vector2(piece.footprint(placed.rotated))
		var cell := Vector2(placed.cell)
		var lift := Vector2(0, -HEIGHTS.get(piece.kind, 20.0))
		var a := Iso.to_world(cell)
		var b := Iso.to_world(cell + Vector2(size.x, 0))
		var c := Iso.to_world(cell + size)
		var d := Iso.to_world(cell + Vector2(0, size.y))
		var outline := PackedVector2Array([a + lift, b + lift, b, c, d, d + lift])
		var depth := Iso.depth(cell + size * 0.5)
		if depth > best_depth and Geometry2D.is_point_in_polygon(world, outline):
			best = placed
			best_depth = depth
	return best


func _hit(person_id: String, world: Vector2) -> bool:
	return _heads.has(person_id) and _heads[person_id].distance_to(world) <= HEAD_HIT_RADIUS


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	if not Session.has_game():
		return
	var state := Session.state
	var data := Session.data
	_heads.clear()
	_draw_floor(state, data)
	# Everything standing on the floor, far to near.
	var drawables: Array[Array] = []
	for placed: PlacedPiece in state.placed:
		var size := data.pieces[placed.piece_id].footprint(placed.rotated)
		drawables.append([Iso.depth(Vector2(placed.cell) + Vector2(size) * 0.5), _draw_piece.bind(placed)])
	for i: int in state.pods:
		var slot := _bay_slot(i, state, data)
		drawables.append([Iso.depth(slot), _draw_pod.bind(Iso.to_world(slot))])
	for entry: Array in _people(state, data):
		drawables.append([Iso.depth(entry[1]) + 0.3, entry[0]])
	# The door stands on the front-right edge, sorted like everything else.
	var door := Vector2(data.balance.floor_width, state.floor_rows - 1)
	drawables.append([Iso.depth(door + Vector2(0, 1)), _draw_door.bind(door)])
	drawables.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry: Array in drawables:
		entry[1].call()
	_draw_counter(state, data)
	if editor != null:
		_draw_editing(state, data)
	_draw_effects()


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
	_draw_pod_bay(state, data)


## The café door: a frame on the front-right edge with a neon OPEN sign.
func _draw_door(door: Vector2) -> void:
	var up := Vector2(0, -78)
	var a := Iso.to_world(door)
	var b := Iso.to_world(door + Vector2(0, 1))
	for post: Vector2 in [a, b]:
		draw_line(post, post + up, Color("8a6a4a"), 6.0)
	draw_line(a + up, b + up, Color("8a6a4a"), 8.0)
	var sign_at := (a + b) * 0.5 + up + Vector2(0, -14)
	draw_rect(Rect2(sign_at - Vector2(30, 11), Vector2(60, 20)), Color("1a1428"))
	var on := UiTheme.ACCENT if Session.state.phase == GameState.Phase.SHIFT else UiTheme.TEXT_DIM
	_text(sign_at + Vector2(0, 6), tr("ui.door_open") if on == UiTheme.ACCENT else tr("ui.door_closed"), 14, on)


## Where Pod i stands in the Pod bay, outside the front-left wall (cell units).
func _bay_slot(i: int, state: GameState, data: GameData) -> Vector2:
	var per_row := maxi(int(data.balance.floor_width / BAY_SPACING), 1)
	return Vector2(0.6 + (i % per_row) * BAY_SPACING, state.floor_rows + BAY_GAP + 0.9 + (i / per_row) * 1.2)


## The Pod bay: a platform outside the front-left wall, a walkway away from it
## (its glass Pods are drawn with everything else, far to near).
func _draw_pod_bay(state: GameState, data: GameData) -> void:
	var rows := float(state.floor_rows) + BAY_GAP
	var deep := 0.3 + ceilf(float(state.pods) / maxi(int(data.balance.floor_width / BAY_SPACING), 1)) * 1.2
	var corners := PackedVector2Array([Iso.to_world(Vector2(0, rows + 0.25)), Iso.to_world(Vector2(data.balance.floor_width, rows + 0.25)),
		Iso.to_world(Vector2(data.balance.floor_width, rows + 0.25 + deep)), Iso.to_world(Vector2(0, rows + 0.25 + deep))])
	draw_colored_polygon(corners, Color("252046"))
	corners.append(corners[0])
	draw_polyline(corners, Color(UiTheme.PANEL_BORDER, 0.5), 2.0)
	_text(Iso.to_world(Vector2(0.2, rows + 0.25 + deep)) + Vector2(-30, 26), tr("ui.pod_bay") % [state.synths.size(), state.pods],
		14, UiTheme.PANEL_BORDER)


## One glass Sync Pod standing at base (world).
func _draw_pod(base: Vector2) -> void:
	draw_set_transform(base, 0, Vector2(1, 0.45))
	draw_circle(Vector2.ZERO, 22, Color("3a4a7a"))
	draw_set_transform(Vector2.ZERO)
	var glass := Rect2(base + Vector2(-17, -70), Vector2(34, 66))
	draw_rect(glass, Color(UiTheme.PANEL_BORDER, 0.14))
	draw_rect(glass, Color(UiTheme.PANEL_BORDER, 0.7), false, 2.0)
	draw_rect(Rect2(base + Vector2(-20, -76), Vector2(40, 8)), Color("5a6a9a"))


## Street and door, in cell units.
func _street(width: float, rows: float) -> Vector2:
	return Vector2(width + 5.0, rows - 0.5)


func _door_point(width: float, rows: float) -> Vector2:
	return Vector2(width + 0.1, rows - 0.5)


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
		if stove != null and stove.has_batch():
			# Waiting for a server to carry it to a counter.
			_draw_cups(label_at + Vector2(0, 6), stove.recipe_id, stove.ready, true)
		elif stove != null and not stove.is_idle():
			var recipe := data.recipes[stove.recipe_id]
			_draw_bar(label_at + Vector2(0, -10), 60, 1.0 - stove.remaining / recipe.cook_seconds, UiTheme.WARN)
			_text(label_at + Vector2(0, -20), UiText.name(recipe.id), 14, UiTheme.TEXT)
	elif piece.kind == Piece.DECOR:
		_text(label_at, UiText.name(piece.id), 12, UiTheme.TEXT_DIM)
	elif piece.kind == Piece.COUNTER:
		var state := Session.state
		_draw_cups(Iso.centre(placed.cell, Vector2i(size)) - Vector2(0, HEIGHTS["counter"]),
			state.counter_dish.get(placed.uid, ""), state.counter_count.get(placed.uid, 0), false)
	elif piece.kind == Piece.SEAT:
		var state := Session.state
		var table := Layout.placed_by_uid(state, state.seat_table.get(placed.uid, ""))
		if table != null:
			# A backrest on the side away from its table: the seat faces the table.
			var facing := table.cell - placed.cell
			var back := Vector2(placed.cell) + Vector2(maxf(-facing.x, 0.0) * 0.8, maxf(-facing.y, 0.0) * 0.8)
			var thin := Vector2(0.2, 1.0) if facing.x != 0 else Vector2(1.0, 0.2)
			_draw_block(back, thin, 34.0, color.darkened(0.1))
		else:
			# Works only beside a table.
			_text(label_at, tr("ui.seat_no_table"), 12, UiTheme.BAD)
			if editor != null:
				_outline(placed, UiTheme.BAD)
	elif piece.kind == Piece.TABLE:
		# The dish of the customer eating at this table's seat.
		var state := Session.state
		var seat_uid: String = state.seat_table.find_key(placed.uid) if state.seat_table.values().has(placed.uid) else ""
		for customer: Customer in state.customers:
			if seat_uid != "" and customer.seat_uid == seat_uid and customer.stage == Customer.Stage.EATING:
				var top := Iso.centre(placed.cell, Vector2i.ONE) - Vector2(0, HEIGHTS["table"])
				var dish := Color.from_hsv(fmod(customer.recipe_id.hash() * 0.618, 1.0), 0.55, 0.95)
				draw_set_transform(top, 0, Vector2(1, 0.5))
				draw_circle(Vector2.ZERO, 13, Color.WHITE)
				draw_circle(Vector2.ZERO, 8, dish)
				draw_set_transform(Vector2.ZERO)
	elif piece.kind == Piece.REGISTER:
		# A glowing screen on top.
		var top := Iso.centre(placed.cell, Vector2i.ONE) - Vector2(0, HEIGHTS["register"])
		draw_rect(Rect2(top + Vector2(-12, -18), Vector2(24, 14)), Color("1b1838"))
		draw_rect(Rect2(top + Vector2(-10, -16), Vector2(20, 10)), UiTheme.GOOD)
		_text(label_at + Vector2(0, -22), tr("ui.register_label"), 12, UiTheme.TEXT_DIM)
	elif piece.kind == Piece.BIN:
		# A lid on top.
		var top := Iso.centre(placed.cell, Vector2i(size)) - Vector2(0, HEIGHTS["bin"])
		draw_rect(Rect2(top + Vector2(-16, -4), Vector2(32, 6)), color.lightened(0.3))
		draw_rect(Rect2(top + Vector2(-5, -9), Vector2(10, 5)), color.lightened(0.3))
	if Session.state.discard.has(placed.uid):
		# Waiting for a server to take it to the bin.
		_text(label_at + Vector2(0, -34), tr("ui.throw_marked"), 13, UiTheme.BAD)


## A stack of cups (one per serving, up to 6) with the dish name and count above;
## on a stove the label reads "Ready ×N".
func _draw_cups(at: Vector2, recipe_id: String, count: int, on_stove: bool) -> void:
	if recipe_id == "" or count <= 0:
		return
	var color := Color.from_hsv(fmod(recipe_id.hash() * 0.618, 1.0), 0.55, 0.95)
	for cup: int in mini(count, 6):
		var spot := at + Vector2(0, -cup * 6.0)
		draw_rect(Rect2(spot + Vector2(-8, -8), Vector2(16, 8)), color)
		draw_rect(Rect2(spot + Vector2(-8, -8), Vector2(16, 8)), color.darkened(0.5), false, 1.5)
	var label := tr("ui.stove_ready") % count if on_stove else "%s %d" % [UiText.name(recipe_id).left(7), count]
	_text(at + Vector2(0, -mini(count, 6) * 6.0 - 14), label, 12, UiTheme.WARN if on_stove else UiTheme.TEXT)


static func piece_color(piece: Piece) -> Color:
	return KIND_COLORS.get(piece.kind, UiTheme.TAG_COLORS.get(piece.tags[0] if not piece.tags.is_empty() else "", Color.GRAY))


## The held piece's ghost with its Vibe change and the neighbours it combines
## with, or an outline on the piece under the mouse when nothing is held.
func _draw_editing(state: GameState, data: GameData) -> void:
	if not editor.is_holding():
		var under := piece_at_point(_hover_world)
		if under != null:
			if data.pieces[under.piece_id].kind == Piece.DECOR:
				_draw_range(under.cell, data.pieces[under.piece_id].footprint(under.rotated), state, data)
				for seat_uid: String in Layout.seats_in_range(state, under.piece_id, under.cell, under.rotated, data, under.uid):
					_outline(Layout.placed_by_uid(state, seat_uid), UiTheme.GOOD)
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
	if piece.kind == Piece.DECOR:
		_draw_range(cell, Vector2i(size), state, data)
		for seat_uid: String in preview["seats"]:
			_outline(Layout.placed_by_uid(state, seat_uid), UiTheme.GOOD)
	_draw_block(Vector2(cell), size, HEIGHTS.get(piece.kind, 20.0), color)
	for uid: String in preview["matches"]:
		_outline(Layout.placed_by_uid(state, uid), UiTheme.WARN)
	var label_at := Iso.centre(cell, Vector2i(size)) - Vector2(0, HEIGHTS.get(piece.kind, 20.0) + 14)
	var text: String = tr("ui.edit_vibe_delta") % roundi(preview["delta"]) if ok else UiText.error(preview["error"])
	var text_color := (UiTheme.GOOD if preview["delta"] >= 0.0 else UiTheme.WARN) if ok else UiTheme.BAD
	_text(label_at, text, 16, text_color)


## The floor tiles a décor piece at cell reaches (its range), softly lit.
func _draw_range(cell: Vector2i, size: Vector2i, state: GameState, data: GameData) -> void:
	var reach := data.balance.decor_range
	var glow := Color(UiTheme.PANEL_BORDER, 0.13)
	for y: int in range(maxi(cell.y - reach, 0), mini(cell.y + size.y + reach, state.floor_rows)):
		for x: int in range(maxi(cell.x - reach, 0), mini(cell.x + size.x + reach, data.balance.floor_width)):
			var tile := Vector2(x, y)
			draw_colored_polygon(PackedVector2Array([Iso.to_world(tile), Iso.to_world(tile + Vector2(1, 0)),
				Iso.to_world(tile + Vector2(1, 1)), Iso.to_world(tile + Vector2(0, 1))]), glow)


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
	paths.update(state, data)
	var result: Array[Array] = []
	var width := float(data.balance.floor_width)
	var rows := float(state.floor_rows)
	var queue_index := 0
	var line_index := 0
	var registers := _registers(state, data)
	var cashier_at := _cashier_registers(state, data, registers)
	var present: Dictionary[String, bool] = {}
	for customer: Customer in state.customers:
		var target: Vector2
		match customer.stage:
			Customer.Stage.QUEUED:
				target = Vector2(width + 0.6 + queue_index * 0.8, rows - 0.5)
				queue_index += 1
			Customer.Stage.PAYING:
				if customer.cashier_id != "" and cashier_at.has(customer.cashier_id):
					target = _piece_front(cashier_at[customer.cashier_id], state, data, Vector2.ZERO)
				elif not registers.is_empty():
					# In line in front of the first register.
					target = _piece_front(registers[0], state, data, Vector2.ZERO) + Vector2(0.15, 0.7 * (line_index + 1))
					line_index += 1
				else:
					target = _street(width, rows)
			_:
				target = _seat_position(customer.id, state, data)
		present[customer.id] = true
		var at := _walk_on(customer.id, _walk.get(customer.id, _street(width, rows)), target)
		_walk[customer.id] = at
		result.append([_draw_customer.bind(customer, at), at])
	# Whoever left the game's list walks out through the door to the street.
	for customer_id: String in _walk.keys():
		if not present.has(customer_id):
			_leaving[customer_id] = {"at": _walk[customer_id], "type_id": _walk_types.get(customer_id, ""),
				"angry": _angry.has(customer_id)}
			_walk.erase(customer_id)
			_routes.erase(customer_id)
	for customer: Customer in state.customers:
		_walk_types[customer.id] = customer.type_id
	for customer_id: String in _leaving.keys():
		var leaver := _leaving[customer_id]
		leaver["at"] = _walk_on("leaving_" + customer_id, leaver["at"], _street(width, rows))
		if (leaver["at"] as Vector2).distance_to(_street(width, rows)) < 0.05:
			_leaving.erase(customer_id)
			_walk_types.erase(customer_id)
			_angry.erase(customer_id)
			_routes.erase("leaving_" + customer_id)
			continue
		result.append([_draw_leaver.bind(leaver), leaver["at"]])
	var pass_point := _pass_point(state, data)
	var counts: Dictionary[String, int] = {}
	var rest_index := 0
	for synth: Synth in state.synths:
		var index: int = counts.get(synth.role, 0)
		counts[synth.role] = index + 1
		var target: Vector2
		var trip := PackedVector2Array()
		var progress := 0.0
		match synth.role:
			Synth.SERVER:
				target = pass_point + Vector2(0.7 * index, 0.4)
				if synth.is_delivering():
					# From the counter the dish came from to the customer's seat.
					progress = 1.0 - synth.task_remaining / data.balance.delivery_seconds
					trip = _trip(synth, _piece_front(synth.task_counter_uid, state, data, target),
						_seat_position(synth.task_customer_id, state, data) + Vector2(0.3, 0.3))
				elif synth.is_discarding():
					# From the counter or stove to the bin, with the food to throw away.
					progress = 1.0 - synth.task_remaining / data.balance.carry_seconds
					trip = _trip(synth, _piece_front(synth.task_counter_uid, state, data, target),
						_piece_front(synth.task_bin_uid, state, data, target))
				elif synth.is_carrying():
					# From the stove to the counter, carrying the batch.
					progress = 1.0 - synth.task_remaining / data.balance.carry_seconds
					trip = _trip(synth, _piece_front(synth.task_stove_uid, state, data, target),
						_piece_front(synth.task_counter_uid, state, data, target))
			Synth.CHEF:
				# At the front of its own stove (a Chef without a stove waits by the kitchen).
				target = _piece_front(synth.station_uid, state, data, pass_point + Vector2(-0.8, 0))
			Synth.CASHIER:
				# Behind its register; a Cashier without a register waits beside the first.
				var spot := Layout.placed_by_uid(state, synth.station_uid)
				target = Vector2(spot.cell) + Vector2(0.5, -0.2) if spot != null \
					else _piece_front(registers[0] if not registers.is_empty() else "", state, data, pass_point) + Vector2(0.8, 0)
			_:
				# Resting in a Sync Pod in the Pod bay (every Synth has one).
				target = _bay_slot(rest_index, state, data) + Vector2(0, 0.05)
				rest_index += 1
		var at: Vector2
		if not trip.is_empty():
			# A timed trip: drawn along its route as far as the work has got.
			at = FloorPaths.point_at(trip, clampf(progress, 0.0, 1.0))
			_routes.erase(synth.id)
		else:
			_trips.erase(synth.id)
			at = _walk_on(synth.id, _synth_at.get(synth.id, target), target)
		_synth_at[synth.id] = at
		if synth.role != Synth.REST or at.distance_to(target) < 0.02:
			_to_pod.erase(synth.id)
		result.append([_draw_synth.bind(synth, at), at])
	return result


## Moves a walker along its route round the furniture toward target (a new
## route when the target or the floor changes); returns where it is now.
func _walk_on(id: String, at: Vector2, target: Vector2) -> Vector2:
	var route: Dictionary = _routes.get(id, {})
	if route.is_empty() or (route["to"] as Vector2).distance_to(target) > 0.01 or route["key"] != paths.key():
		route = {"to": target, "key": paths.key(), "points": paths.route(at, target), "next": 1}
		_routes[id] = route
	var left := (0.0 if Session.paused else WALK_SPEED * maxf(Session.state.speed, 1.0)) * _walk_delta
	var points: PackedVector2Array = route["points"]
	while left > 0.0 and route["next"] < points.size():
		var next: Vector2 = points[route["next"]]
		var step := at.distance_to(next)
		if step <= left:
			at = next
			left -= step
			route["next"] += 1
		else:
			at = at.move_toward(next, left)
			left = 0.0
	return at


## The route of a Synth's timed trip from one point to another (kept while
## the trip lasts).
func _trip(synth: Synth, from: Vector2, to: Vector2) -> PackedVector2Array:
	var key := "%s>%s|%s" % [from, to, paths.key()]
	var trip: Dictionary = _trips.get(synth.id, {})
	if trip.get("key", "") != key:
		# Walks from where it stands to the pick-up, then on to the drop-off (never jumps).
		var points := paths.route(_synth_at.get(synth.id, from), from)
		var rest := paths.route(from, to)
		rest.remove_at(0)
		points.append_array(rest)
		trip = {"key": key, "points": points}
		_trips[synth.id] = trip
	return trip["points"]


## Placed register uids in floor order.
func _registers(state: GameState, data: GameData) -> Array[String]:
	var result: Array[String] = []
	for placed: PlacedPiece in state.placed:
		if data.pieces[placed.piece_id].kind == Piece.REGISTER:
			result.append(placed.uid)
	return result


## Working Cashier id -> the register uid they stand at.
func _cashier_registers(state: GameState, data: GameData, _registers: Array[String]) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for cashier: Synth in Shift.active_cashiers(state, data):
		result[cashier.id] = cashier.station_uid
	return result


func _seat_position(customer_id: String, state: GameState, data: GameData) -> Vector2:
	var customer := state.customer_by_id(customer_id)
	var placed := Layout.placed_by_uid(state, customer.seat_uid if customer != null else "")
	if placed == null:
		return Vector2(data.balance.floor_width - 1, state.floor_rows - 1)
	return Vector2(placed.cell) + Vector2(0.5, 0.5)


## Where servers pick up dishes: in front of the first counter (or the first
## stove in a café without one).
func _pass_point(state: GameState, data: GameData) -> Vector2:
	var counter := _first_counter(state, data)
	if counter != null:
		var size := Vector2(data.pieces[counter.piece_id].footprint(counter.rotated))
		return Vector2(counter.cell) + Vector2(size.x * 0.5, size.y + 0.4)
	if state.stoves.is_empty():
		return Vector2(1, 1)
	return _stove_front(0, state, data) + Vector2(0.4, 0.5)


## The floor point in front of a placed piece (or fallback if it is gone).
func _piece_front(uid: String, state: GameState, data: GameData, fallback: Vector2) -> Vector2:
	var placed := Layout.placed_by_uid(state, uid)
	if placed == null:
		return fallback
	var size := Vector2(data.pieces[placed.piece_id].footprint(placed.rotated))
	return Vector2(placed.cell) + Vector2(size.x * 0.5, size.y + 0.35)


func _first_counter(state: GameState, data: GameData) -> PlacedPiece:
	for placed: PlacedPiece in state.placed:
		if data.pieces[placed.piece_id].kind == Piece.COUNTER:
			return placed
	return null


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
		Customer.Stage.PAYING:
			_draw_bar(above + Vector2(0, 8), 34, customer.satisfaction / 100.0, _mood_color(customer.satisfaction))
			if not customer.starred:
				_text(above + Vector2(0, -4), "$", 18, UiTheme.WARN)
	if customer.starred and (customer.stage == Customer.Stage.PAYING or customer.stage == Customer.Stage.STAR):
		var pulse := 1.0 + 0.12 * sin(_time * 6.0)
		_draw_star(above + Vector2(0, -6), 16.0 * pulse, UiTheme.WARN)


func _draw_leaver(leaver: Dictionary) -> void:
	var color: Color = UiTheme.CUSTOMER_COLORS.get(leaver["type_id"], Color.GRAY)
	var head := _draw_body(leaver["at"], color, Color("ffd9b8"), "")
	if leaver["angry"]:
		_text(head + Vector2(0, -26), "!", 24, UiTheme.BAD)


func _draw_synth(synth: Synth, at: Vector2) -> void:
	var glow: Color = UiTheme.SPECIES_GLOW.get(synth.species_id, Color.CYAN)
	draw_circle(Iso.to_world(at), 22, Color(glow, 0.18))
	if synth.id == selected_synth:
		# Picked to get a job: a pulsing ring at its feet.
		draw_set_transform(Iso.to_world(at), 0, Vector2(1, 0.5))
		draw_arc(Vector2.ZERO, 30 + 4 * sin(_time * 6.0), 0, TAU, 32, UiTheme.WARN, 4.0)
		draw_set_transform(Vector2.ZERO)
	var data := Session.data
	var outfit := Items.worn(synth, "outfit", data)
	var body := Color(data.items.fashion[outfit.type_id]["color"]) if outfit != null else Color("9aa3b8")
	var head := _draw_body(at, body, glow, synth.id, true)
	var hat := Items.worn(synth, "hat", data)
	if hat != null:
		var hat_color := Color(data.items.fashion[hat.type_id]["color"])
		draw_rect(Rect2(head + Vector2(-13, -20), Vector2(26, 9)), hat_color)
		draw_rect(Rect2(head + Vector2(-8, -27), Vector2(16, 8)), hat_color)
		draw_rect(Rect2(head + Vector2(-13, -20), Vector2(26, 9)), hat_color.darkened(0.5), false, 1.5)
	var above := head + Vector2(0, -38 if hat != null else -28)
	_draw_bar(above + Vector2(0, 6), 34, synth.battery / SynthStats.stat(synth, "battery_max", data), _battery_color(synth, data))
	_text(above + Vector2(0, -4), "Lv%d" % synth.level, 13, glow)
	if synth.is_busy():
		draw_circle(head + Vector2(16, 18), 7, Color.WHITE)
		if synth.is_carrying():
			draw_circle(head + Vector2(20, 12), 6, Color.WHITE)


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
	if person_id != "":
		_heads[person_id] = head
	return head


## Ready dishes as text, only for a café without a counter piece (the counter draws them).
func _draw_counter(state: GameState, data: GameData) -> void:
	if _first_counter(state, data) != null:
		return
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
