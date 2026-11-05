class_name Walls
extends RefCounted
## The bar's two back walls as a small grid: one column per floor tile along
## each wall ("L3": the left wall beside row 3; "R2": the right wall above
## column 2), each ROWS cells high (row 0 at the bottom).
##
## A wall style (Piece.WALL_STYLE) is a 1 x ROWS panel: placing it paints the whole
## column, and the panel that was there goes back to storage (the bar's cracked
## concrete is what's under them all). Wall décor (Piece.WALL_DECOR) sits on the
## grid and takes `height` cells, and like floor décor adds its Vibe to seats
## within decor_range of that wall tile; so does a panel, a little.
## state.walls keeps only changed columns: key -> {"style": id, "cells": [ids]}
## where a piece taller than one cell fills the cells above it with ABOVE.

const ROWS: int = 3
## The style every wall starts with (not a piece: it can't be bought or stored).
const BARE: String = "wall_cracked"
## A cell taken by the piece below it.
const ABOVE: String = "^"


static func key(left: bool, index: int) -> String:
	return ("L" if left else "R") + str(index)


## Every column of the bar's walls.
static func columns(state: GameState) -> Array[String]:
	var result: Array[String] = []
	for y: int in state.floor_rows:
		result.append(key(true, y))
	for x: int in state.floor_width:
		result.append(key(false, x))
	return result


static func is_left(column: String) -> bool:
	return column.begins_with("L")


static func index(column: String) -> int:
	return int(column.substr(1))


## The floor tile beside a wall column.
static func tile(column: String) -> Vector2i:
	return Vector2i(0, index(column)) if is_left(column) else Vector2i(index(column), 0)


static func is_wall_piece(piece: Piece) -> bool:
	return piece != null and (piece.kind == Piece.WALL_DECOR or piece.kind == Piece.WALL_STYLE)


## The style showing on a column.
static func style(state: GameState, column: String) -> String:
	var entry: Dictionary = state.walls.get(column, {})
	return str(entry.get("style", "")) if str(entry.get("style", "")) != "" else BARE


## What stands on a cell: a piece id, ABOVE, or "".
static func cell(state: GameState, column: String, row: int) -> String:
	var cells: Array = state.walls.get(column, {}).get("cells", [])
	return str(cells[row]) if row >= 0 and row < cells.size() else ""


## Puts a stored wall piece up: a style on the whole column, décor from `row` up.
static func place(state: GameState, piece_id: String, column: String, row: int, data: GameData) -> String:
	var piece: Piece = data.pieces.get(piece_id)
	if not is_wall_piece(piece):
		return GameLoop.UNKNOWN_PIECE
	if state.storage.get(piece_id, 0) <= 0:
		return GameLoop.NONE_STORED
	if not columns(state).has(column):
		return GameLoop.OUT_OF_BOUNDS
	if piece.kind == Piece.WALL_STYLE:
		var old := style(state, column)
		if old == piece_id:
			return GameLoop.OVERLAP
		if old != BARE:
			state.storage[old] = state.storage.get(old, 0) + 1
		_entry(state, column)["style"] = piece_id
	else:
		if row < 0 or row + piece.height > ROWS:
			return GameLoop.OUT_OF_BOUNDS
		for i: int in piece.height:
			if cell(state, column, row + i) != "":
				return GameLoop.OVERLAP
		var cells: Array = _entry(state, column)["cells"]
		cells[row] = piece_id
		for i: int in range(1, piece.height):
			cells[row + i] = ABOVE
	Layout.take_from_storage(state, piece_id)
	Layout.refresh(state, data)
	return GameLoop.OK


## Takes the décor on a cell back to storage; returns its id ("" if there is none).
static func take(state: GameState, column: String, row: int, data: GameData) -> String:
	var base := row
	while base > 0 and cell(state, column, base) == ABOVE:
		base -= 1
	var piece_id := cell(state, column, base)
	if piece_id == "" or piece_id == ABOVE:
		return ""
	var cells: Array = _entry(state, column)["cells"]
	cells[base] = ""
	var above := base + 1
	while above < ROWS and str(cells[above]) == ABOVE:
		cells[above] = ""
		above += 1
	state.storage[piece_id] = state.storage.get(piece_id, 0) + 1
	Layout.refresh(state, data)
	return piece_id


## The Vibe the walls give a seat at `seat_cell`: every panel and piece within range.
static func vibe_at(state: GameState, seat_cell: Vector2i, data: GameData) -> float:
	var total := 0.0
	for column: String in state.walls:
		var beside := tile(column)
		if maxi(absi(beside.x - seat_cell.x), absi(beside.y - seat_cell.y)) > data.balance.decor_range:
			continue
		var panel: Piece = data.pieces.get(style(state, column))
		if panel != null:
			total += panel.vibe
		for row: int in ROWS:
			var piece: Piece = data.pieces.get(cell(state, column, row))
			if piece != null:
				total += piece.vibe
	return total


## What's wrong with state.walls (for SaveSystem.validate): every column on the
## bar's walls, ROWS cells, known pieces of the right kind, tall pieces whole.
static func check(state: GameState, data: GameData) -> PackedStringArray:
	var errors: PackedStringArray = []
	var known := columns(state)
	for column: String in state.walls:
		var entry: Dictionary = state.walls[column]
		var cells: Variant = entry.get("cells")
		if not known.has(column) or not cells is Array or cells.size() != ROWS:
			errors.append("bad wall column '%s'" % column)
			continue
		var panel: Piece = data.pieces.get(str(entry.get("style", "")))
		if str(entry.get("style", "")) != "" and (panel == null or panel.kind != Piece.WALL_STYLE):
			errors.append("wall column '%s': bad panel '%s'" % [column, entry.get("style")])
		var row := 0
		while row < ROWS:
			var piece_id := str(cells[row])
			row += 1
			if piece_id == "":
				continue
			var piece: Piece = data.pieces.get(piece_id)
			if piece == null or piece.kind != Piece.WALL_DECOR:
				errors.append("wall column '%s': bad piece '%s'" % [column, piece_id])
				continue
			for i: int in piece.height - 1:
				if row >= ROWS or str(cells[row]) != ABOVE:
					errors.append("wall column '%s': '%s' is cut short" % [column, piece_id])
				row += 1
	return errors


## How many of a piece are up on the walls.
static func count(state: GameState, piece_id: String) -> int:
	var total := 0
	for column: String in state.walls:
		if style(state, column) == piece_id:
			total += 1
		for row: int in ROWS:
			if cell(state, column, row) == piece_id:
				total += 1
	return total


## A column's entry, made if it's still bare.
static func _entry(state: GameState, column: String) -> Dictionary:
	if not state.walls.has(column):
		var cells: Array = []
		cells.resize(ROWS)
		cells.fill("")
		state.walls[column] = {"style": "", "cells": cells}
	return state.walls[column]
