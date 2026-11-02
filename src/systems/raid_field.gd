class_name RaidField
extends RefCounted
## The rival café a raid is fought in: its floor (as wide as the battle board,
## `rows` deep) with its furniture, and in front of it the player's 3 rows on
## the street. Hand-made when the café has a "layout" in districts.json:
##   "layout": {"rows": 4, "pieces": [{"piece": "counter", "cell": [2, 0]},
##     {"piece": "table", "cell": [3, 2], "rotated": false}, ...]}
## (piece ids from pieces.json; row 0 is the back wall, the last row the door).
## Otherwise generated from the café's id, so it is the same on every visit:
## counters and a stove along the back, tables with their seats, a little décor,
## the front row kept clear, every free tile reachable from the door.

## Rows of a generated café (a flagship is deeper and busier).
const ROWS: int = 4
const FLAGSHIP_ROWS: int = 5


## The battle field for a raid on rival.
static func for_rival(rival: RivalCafe, flagship: bool, data: GameData) -> Battle.Field:
	var width := data.combat.board.x
	var rows := rival.layout_rows if rival.layout_rows > 0 else (FLAGSHIP_ROWS if flagship else ROWS)
	var pieces: Array[Dictionary] = rival.layout_pieces if rival.layout_rows > 0 \
		else generate(rival.id, width, rows, flagship, data)
	var field := Battle.Field.new()
	field.board = Vector2i(width, rows + data.combat.half())
	field.split = rows
	for entry: Dictionary in pieces:
		if not data.pieces.has(entry["piece_id"]):
			continue
		var size := data.pieces[entry["piece_id"]].footprint(entry.get("rotated", false))
		for y: int in size.y:
			for x: int in size.x:
				var cell: Vector2i = entry["cell"] + Vector2i(x, y)
				if cell.x < width and cell.y < rows:
					field.obstacles[cell] = true
		field.pieces.append(entry)
	return field


## A café's furniture from its id: [{"piece_id", "cell", "rotated"}].
static func generate(rival_id: String, width: int, rows: int, flagship: bool, data: GameData) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	for attempt: int in 20:
		rng.seed = hash(rival_id) + attempt
		var pieces: Array[Dictionary] = []
		var taken: Dictionary[Vector2i, bool] = {}
		var put := func(piece_id: String, cell: Vector2i) -> bool:
			if cell.x < 0 or cell.x >= width or cell.y < 0 or cell.y >= rows - 1 or taken.has(cell):
				return false
			taken[cell] = true
			pieces.append({"piece_id": piece_id, "cell": cell, "rotated": false})
			return true
		# The back: a stove and a run of counters.
		var start := rng.randi_range(0, 2)
		put.call("stove", Vector2i(start, 0))
		for x: int in range(start + 1, start + 3 + (1 if flagship else 0)):
			put.call("counter", Vector2i(x, 0))
		# Tables with their seats, in the middle rows.
		for i: int in (4 if flagship else 3):
			var table := Vector2i(rng.randi_range(0, width - 2), rng.randi_range(1, maxi(rows - 3, 1)))
			if put.call("table", table):
				put.call("seat", table + Vector2i(1, 0))
		# A little décor at the sides.
		var decor: Array[String] = []
		for piece: Piece in data.pieces.values():
			if piece.kind == Piece.DECOR and piece.size == Vector2i.ONE:
				decor.append(piece.id)
		for i: int in (2 if flagship else 1):
			if not decor.is_empty():
				put.call(decor[rng.randi_range(0, decor.size() - 1)], Vector2i(0 if i % 2 == 0 else width - 1, rng.randi_range(0, rows - 2)))
		if _all_reachable(taken, width, rows):
			return pieces
	return []


## Every free tile of the café can be walked to from its front row.
static func _all_reachable(taken: Dictionary[Vector2i, bool], width: int, rows: int) -> bool:
	var seen: Dictionary[Vector2i, bool] = {}
	var queue: Array[Vector2i] = []
	for x: int in width:
		seen[Vector2i(x, rows - 1)] = true
		queue.append(Vector2i(x, rows - 1))
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		for direction: Vector2i in Battle.NEIGHBOURS:
			var next := at + direction
			if next.x >= 0 and next.y >= 0 and next.x < width and next.y < rows and not taken.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size() + taken.size() == width * rows
