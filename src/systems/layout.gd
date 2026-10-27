class_name Layout
extends RefCounted
## The café floor: a grid floor_width tiles across and state.floor_rows deep.
## Seats, stoves, counters and décor stand on it without overlapping; only
## placed pieces count (seats seat customers, stoves cook). Sync Pods are not on
## the floor: they stand in the Pod bay outside (state.pods).
## Pieces not on the floor wait in storage.
##
## Vibe works in a range: each piece's share is its own Vibe plus half of every
## adjacency bonus it is part of; a seat's Vibe is the sum of the shares of all
## pieces within decor_range tiles of it. The café's Vibe is the total over seats.
##
## Changes go through GameLoop (night only); these functions do not check the
## phase. After any change refresh() updates state.seats, state.pods and state.vibe.

const NEIGHBOURS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


static func floor_size(state: GameState, b: BalanceConfig) -> Vector2i:
	return Vector2i(b.floor_width, state.floor_rows)


static func cells(placed: PlacedPiece, data: GameData) -> Array[Vector2i]:
	var size := data.pieces[placed.piece_id].footprint(placed.rotated)
	var result: Array[Vector2i] = []
	for y: int in size.y:
		for x: int in size.x:
			result.append(placed.cell + Vector2i(x, y))
	return result


static func placed_by_uid(state: GameState, uid: String) -> PlacedPiece:
	for placed: PlacedPiece in state.placed:
		if placed.uid == uid:
			return placed
	return null


## Why this piece cannot stand here, or OK. ignore_uid: a piece being moved.
static func check_spot(state: GameState, piece_id: String, cell: Vector2i, rotated: bool, data: GameData,
		ignore_uid := "") -> String:
	var piece: Piece = data.pieces.get(piece_id)
	if piece == null:
		return GameLoop.UNKNOWN_PIECE
	var size := piece.footprint(rotated)
	var bounds := floor_size(state, data.balance)
	if cell.x < 0 or cell.y < 0 or cell.x + size.x > bounds.x or cell.y + size.y > bounds.y:
		return GameLoop.OUT_OF_BOUNDS
	var taken := _occupied(state, data, ignore_uid)
	for y: int in size.y:
		for x: int in size.x:
			if taken.has(cell + Vector2i(x, y)):
				return GameLoop.OVERLAP
	return GameLoop.OK


## The first free spot (row by row, unrotated first): {"cell", "rotated"}, or {} if full.
static func find_spot(state: GameState, piece_id: String, data: GameData) -> Dictionary:
	var bounds := floor_size(state, data.balance)
	for y: int in bounds.y:
		for x: int in bounds.x:
			for rotated: bool in [false, true]:
				if check_spot(state, piece_id, Vector2i(x, y), rotated, data) == GameLoop.OK:
					return {"cell": Vector2i(x, y), "rotated": rotated}
	return {}


## Places a stored piece.
static func place(state: GameState, piece_id: String, cell: Vector2i, rotated: bool, data: GameData) -> String:
	if not data.pieces.has(piece_id):
		return GameLoop.UNKNOWN_PIECE
	if state.storage.get(piece_id, 0) <= 0:
		return GameLoop.NONE_STORED
	var error := check_spot(state, piece_id, cell, rotated, data)
	if error != GameLoop.OK:
		return error
	_take_from_storage(state, piece_id)
	_put(state, piece_id, cell, rotated, data)
	return GameLoop.OK


## Puts a piece (not from storage) at cell; the caller has checked the spot.
static func place_new(state: GameState, piece_id: String, cell: Vector2i, rotated: bool, data: GameData) -> void:
	_put(state, piece_id, cell, rotated, data)


## Puts a piece (not from storage) on the first free spot. False if the floor is full.
static func auto_place(state: GameState, piece_id: String, data: GameData) -> bool:
	var spot := find_spot(state, piece_id, data)
	if spot.is_empty():
		return false
	_put(state, piece_id, spot["cell"], spot["rotated"], data)
	return true


static func move(state: GameState, uid: String, cell: Vector2i, rotated: bool, data: GameData) -> String:
	var placed := placed_by_uid(state, uid)
	if placed == null:
		return GameLoop.UNKNOWN_PLACED
	var error := check_spot(state, placed.piece_id, cell, rotated, data, uid)
	if error != GameLoop.OK:
		return error
	placed.cell = cell
	placed.rotated = rotated
	refresh(state, data)
	return GameLoop.OK


## Back to storage. A cooking stove or the last counter stays put.
static func pick_up(state: GameState, uid: String, data: GameData) -> String:
	var placed := placed_by_uid(state, uid)
	if placed == null:
		return GameLoop.UNKNOWN_PLACED
	var error := _can_remove(state, placed, data)
	if error != GameLoop.OK:
		return error
	_remove(state, placed, data)
	state.storage[placed.piece_id] = state.storage.get(placed.piece_id, 0) + 1
	return GameLoop.OK


## Buys a décor piece into storage.
static func buy(state: GameState, piece_id: String, data: GameData) -> String:
	var piece: Piece = data.pieces.get(piece_id)
	if piece == null:
		return GameLoop.UNKNOWN_PIECE
	if piece.kind != Piece.DECOR:
		return GameLoop.NOT_FOR_SALE
	if state.coins < piece.price:
		return GameLoop.NOT_ENOUGH_COINS
	state.coins -= piece.price
	state.storage[piece_id] = state.storage.get(piece_id, 0) + 1
	return GameLoop.OK


static func sell_placed(state: GameState, uid: String, data: GameData) -> String:
	var placed := placed_by_uid(state, uid)
	if placed == null:
		return GameLoop.UNKNOWN_PLACED
	var piece := data.pieces[placed.piece_id]
	if piece.kind != Piece.DECOR:
		return GameLoop.NOT_FOR_SALE
	_remove(state, placed, data)
	state.coins += refund(piece, data.balance)
	return GameLoop.OK


static func sell_stored(state: GameState, piece_id: String, data: GameData) -> String:
	var piece: Piece = data.pieces.get(piece_id)
	if piece == null:
		return GameLoop.UNKNOWN_PIECE
	if piece.kind != Piece.DECOR:
		return GameLoop.NOT_FOR_SALE
	if state.storage.get(piece_id, 0) <= 0:
		return GameLoop.NONE_STORED
	_take_from_storage(state, piece_id)
	state.coins += refund(piece, data.balance)
	return GameLoop.OK


static func refund(piece: Piece, b: BalanceConfig) -> int:
	return int(piece.price * b.sell_refund)


## Recomputes what the layout provides: seats and Vibe (per seat and total).
static func refresh(state: GameState, data: GameData) -> void:
	state.seats = count_placed(state, Piece.SEAT, data)
	state.seat_vibe = seat_vibes(state, data)
	state.vibe = 0.0
	for value: float in state.seat_vibe.values():
		state.vibe += value


## Seat uid -> the Vibe there: shares of every piece within decor_range tiles.
static func seat_vibes(state: GameState, data: GameData) -> Dictionary[String, float]:
	var shares := _shares(state, data)
	var result: Dictionary[String, float] = {}
	for seat: PlacedPiece in state.placed:
		if data.pieces[seat.piece_id].kind != Piece.SEAT:
			continue
		var total := 0.0
		for i: int in state.placed.size():
			if shares[i] != 0.0 and distance(state.placed[i], seat, data) <= data.balance.decor_range:
				total += shares[i]
		result[seat.uid] = total
	return result


## King's-move steps between the nearest tiles of two pieces (1 = touching, 0 = overlapping).
static func distance(a: PlacedPiece, b: PlacedPiece, data: GameData) -> int:
	var a_size := data.pieces[a.piece_id].footprint(a.rotated)
	var b_size := data.pieces[b.piece_id].footprint(b.rotated)
	var dx := maxi(0, maxi(a.cell.x - (b.cell.x + b_size.x - 1), b.cell.x - (a.cell.x + a_size.x - 1)))
	var dy := maxi(0, maxi(a.cell.y - (b.cell.y + b_size.y - 1), b.cell.y - (a.cell.y + a_size.y - 1)))
	return maxi(dx, dy)


## Placed seats a piece reaches from cell (for the range preview).
static func seats_in_range(state: GameState, piece_id: String, cell: Vector2i, rotated: bool, data: GameData,
		uid := "") -> Array[String]:
	var trial := _trial(state, piece_id, cell, rotated, uid)
	var result: Array[String] = []
	for seat: PlacedPiece in state.placed:
		if data.pieces[seat.piece_id].kind == Piece.SEAT and seat != trial["placed"] \
				and distance(trial["placed"], seat, data) <= data.balance.decor_range:
			result.append(seat.uid)
	_end_trial(state, trial)
	return result


## Each placed piece's share (same order as state.placed): own Vibe + half of its adjacency bonuses.
static func _shares(state: GameState, data: GameData) -> Array[float]:
	var shares: Array[float] = []
	var owner: Dictionary[Vector2i, int] = {}
	for i: int in state.placed.size():
		shares.append(data.pieces[state.placed[i].piece_id].vibe)
		for cell: Vector2i in cells(state.placed[i], data):
			owner[cell] = i
	for i: int in state.placed.size():
		var touching: Dictionary[int, bool] = {}
		for cell: Vector2i in cells(state.placed[i], data):
			for step: Vector2i in NEIGHBOURS:
				var j: int = owner.get(cell + step, -1)
				if j > i:
					touching[j] = true
		var a := data.pieces[state.placed[i].piece_id]
		for j: int in touching:
			var b := data.pieces[state.placed[j].piece_id]
			for rule: AdjacencyRule in data.adjacency:
				if rule.matches(a, b):
					shares[i] += rule.vibe * 0.5
					shares[j] += rule.vibe * 0.5
	return shares


static func count_placed(state: GameState, kind: String, data: GameData) -> int:
	return state.placed.filter(func(placed: PlacedPiece) -> bool:
		return data.pieces[placed.piece_id].kind == kind).size()


## Vibe ignoring range: every piece's own Vibe plus every adjacency bonus.
static func raw_vibe(state: GameState, data: GameData) -> float:
	var total := 0.0
	var owner: Dictionary[Vector2i, int] = {}
	for i: int in state.placed.size():
		total += data.pieces[state.placed[i].piece_id].vibe
		for cell: Vector2i in cells(state.placed[i], data):
			owner[cell] = i
	for i: int in state.placed.size():
		var touching: Dictionary[int, bool] = {}
		for cell: Vector2i in cells(state.placed[i], data):
			for step: Vector2i in NEIGHBOURS:
				var j: int = owner.get(cell + step, -1)
				if j > i:
					touching[j] = true
		var a := data.pieces[state.placed[i].piece_id]
		for j: int in touching:
			var b := data.pieces[state.placed[j].piece_id]
			for rule: AdjacencyRule in data.adjacency:
				if rule.matches(a, b):
					total += rule.vibe
	return total


## The placed piece covering a tile, or null.
static func piece_at(state: GameState, tile: Vector2i, data: GameData) -> PlacedPiece:
	for placed: PlacedPiece in state.placed:
		if cells(placed, data).has(tile):
			return placed
	return null


## Total seat Vibe if a piece stood here: the placed piece uid moved, or (uid "") a
## new piece_id placed. The state is left as it was.
static func vibe_if(state: GameState, piece_id: String, cell: Vector2i, rotated: bool, data: GameData, uid := "") -> float:
	var trial := _trial(state, piece_id, cell, rotated, uid)
	var total := 0.0
	for value: float in seat_vibes(state, data).values():
		total += value
	_end_trial(state, trial)
	return total


## Placed pieces that would touch this piece here and match an adjacency rule with it.
static func matching_neighbours(state: GameState, piece_id: String, cell: Vector2i, rotated: bool, data: GameData,
		uid := "") -> Array[String]:
	var trial := _trial(state, piece_id, cell, rotated, uid)
	var mine := cells(trial["placed"], data)
	var piece := data.pieces[piece_id]
	var result: Array[String] = []
	for placed: PlacedPiece in state.placed:
		if placed == trial["placed"]:
			continue
		var other := data.pieces[placed.piece_id]
		if not data.adjacency.any(func(rule: AdjacencyRule) -> bool: return rule.matches(piece, other)):
			continue
		var touching := false
		for other_cell: Vector2i in cells(placed, data):
			for step: Vector2i in NEIGHBOURS:
				if mine.has(other_cell + step):
					touching = true
		if touching:
			result.append(placed.uid)
	_end_trial(state, trial)
	return result


## Puts the piece at cell for a moment: moves the placed uid, or adds a new one.
## Returns what _end_trial needs to undo it.
static func _trial(state: GameState, piece_id: String, cell: Vector2i, rotated: bool, uid: String) -> Dictionary:
	var placed := placed_by_uid(state, uid) if uid != "" else null
	if placed != null:
		var undo := {"placed": placed, "cell": placed.cell, "rotated": placed.rotated, "added": false}
		placed.cell = cell
		placed.rotated = rotated
		return undo
	placed = PlacedPiece.new()
	placed.uid = "trial"
	placed.piece_id = piece_id
	placed.cell = cell
	placed.rotated = rotated
	state.placed.append(placed)
	return {"placed": placed, "added": true}


static func _end_trial(state: GameState, undo: Dictionary) -> void:
	var placed: PlacedPiece = undo["placed"]
	if undo["added"]:
		state.placed.erase(placed)
	else:
		placed.cell = undo["cell"]
		placed.rotated = undo["rotated"]


static func _occupied(state: GameState, data: GameData, ignore_uid: String) -> Dictionary[Vector2i, bool]:
	var taken: Dictionary[Vector2i, bool] = {}
	for placed: PlacedPiece in state.placed:
		if placed.uid == ignore_uid:
			continue
		for cell: Vector2i in cells(placed, data):
			taken[cell] = true
	return taken


static func _put(state: GameState, piece_id: String, cell: Vector2i, rotated: bool, data: GameData) -> void:
	var placed := PlacedPiece.new()
	placed.uid = state.new_id("piece")
	placed.piece_id = piece_id
	placed.cell = cell
	placed.rotated = rotated
	state.placed.append(placed)
	if data.pieces[piece_id].kind == Piece.STOVE:
		var stove := Stove.new()
		stove.piece_uid = placed.uid
		state.stoves.append(stove)
	refresh(state, data)


static func _can_remove(state: GameState, placed: PlacedPiece, data: GameData) -> String:
	match data.pieces[placed.piece_id].kind:
		Piece.STOVE:
			var stove := stove_of(state, placed.uid)
			if stove != null and not stove.is_idle():
				return GameLoop.STOVE_BUSY
		Piece.COUNTER:
			if count_placed(state, Piece.COUNTER, data) <= 1:
				return GameLoop.COUNTER_NEEDED
			if Counters.dish_on(state, placed.uid) != "":
				return GameLoop.COUNTER_BUSY
	return GameLoop.OK


static func _remove(state: GameState, placed: PlacedPiece, data: GameData) -> void:
	state.placed.erase(placed)
	var stove := stove_of(state, placed.uid)
	if stove != null:
		state.stoves.erase(stove)
	state.counter_dish.erase(placed.uid)
	state.counter_count.erase(placed.uid)
	refresh(state, data)


static func stove_of(state: GameState, uid: String) -> Stove:
	for stove: Stove in state.stoves:
		if stove.piece_uid == uid:
			return stove
	return null


static func _take_from_storage(state: GameState, piece_id: String) -> void:
	state.storage[piece_id] -= 1
	if state.storage[piece_id] <= 0:
		state.storage.erase(piece_id)
