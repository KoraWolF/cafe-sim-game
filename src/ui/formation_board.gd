class_name FormationBoard
extends Control
## The player's half of the battle board, seen from above, front row at the top
## (facing the enemy). Each Synth stands on its spot (or the one its class
## gets: tanks and fighters in front, fragile units behind, ranged at the back).
## Click a Synth, then a tile, to move it there; one already there swaps.
## The raid squad has a gold ring. Spots count in raids and when defending.

const CELL: float = 66.0
## A one-letter mark per class.
const CLASS_MARK: Dictionary[String, String] = {"tank": "T", "fighter": "F", "ranged": "R", "fragile": "X"}

## Synth ids raiding tonight (drawn with a gold ring).
var squad: Array[String] = []
var _selected: String = ""
## Synth id -> spot shown.
var _spots: Dictionary[String, Vector2i] = {}


func _ready() -> void:
	var combat := Session.data.combat
	custom_minimum_size = Vector2(combat.board.x * CELL, combat.half() * CELL)
	mouse_filter = Control.MOUSE_FILTER_STOP
	refresh()


func refresh() -> void:
	var state := Session.state
	var data := Session.data
	var fighters: Array[Battle.Fighter] = []
	for synth: Synth in state.synths:
		fighters.append(NightOps.synth_fighter(synth, 0.0, data, state))
	var spots := Battle.formation_spots(fighters, data.combat)
	_spots.clear()
	for i: int in state.synths.size():
		_spots[state.synths[i].id] = spots[i]
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var spot := Vector2i(floori(click.position.x / CELL), floori(click.position.y / CELL))
	var here := ""
	for synth_id: String in _spots:
		if _spots[synth_id] == spot:
			here = synth_id
	if _selected == "" or here == _selected:
		_selected = here if here != _selected else ""
		queue_redraw()
	else:
		# Keep everyone where they are shown, then move the picked one.
		for synth_id: String in _spots:
			if not Session.state.formation.has(synth_id) and _spots[synth_id].x >= 0:
				Session.state.formation[synth_id] = _spots[synth_id]
		var mover := _selected
		_selected = ""
		Session.act(GameLoop.set_formation(Session.state, mover, spot, Session.data))
		refresh()
	accept_event()


func _draw() -> void:
	var combat := Session.data.combat
	for y: int in combat.half():
		for x: int in combat.board.x:
			var rect := Rect2(Vector2(x, y) * CELL, Vector2(CELL, CELL)).grow(-2)
			draw_rect(rect, Color(UiTheme.PANEL_BORDER, 0.16 if y == 0 else 0.08))
			draw_rect(rect, Color(UiTheme.PANEL_BORDER, 0.35), false, 1.0)
	var font := ThemeDB.fallback_font
	for synth_id: String in _spots:
		var spot := _spots[synth_id]
		if spot.x < 0:
			continue
		var synth := Session.state.synth_by_id(synth_id)
		var centre := (Vector2(spot) + Vector2(0.5, 0.5)) * CELL
		var glow: Color = UiTheme.SPECIES_GLOW.get(synth.species_id, Color.CYAN)
		draw_circle(centre, CELL * 0.36, Color(glow, 0.35))
		draw_arc(centre, CELL * 0.36, 0, TAU, 32, glow, 2.0)
		if squad.has(synth_id):
			draw_arc(centre, CELL * 0.44, 0, TAU, 32, UiTheme.WARN, 3.0)
		if synth_id == _selected:
			draw_arc(centre, CELL * 0.48, 0, TAU, 32, UiTheme.TEXT, 3.0)
		var name := Session.synth_name(synth).left(6)
		var mark: String = CLASS_MARK.get(Session.data.species[synth.species_id].combat_class, "?")
		for line: Array in [[name, Vector2(0, -2), 13], [mark, Vector2(0, 16), 15]]:
			var width := font.get_string_size(line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[2]).x
			draw_string(font, centre + line[1] - Vector2(width * 0.5, 0), line[0], HORIZONTAL_ALIGNMENT_LEFT, -1, line[2], UiTheme.TEXT)
