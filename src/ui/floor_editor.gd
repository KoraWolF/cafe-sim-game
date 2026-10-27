class_name FloorEditor
extends RefCounted
## Arranging the café floor at night. The player holds one piece at a time:
## one from storage, or a placed piece picked up to be moved. Every change goes
## through GameLoop, so the floor rules (bounds, overlap, busy stoves, needed
## Pods, night only) are the game's own. No drawing here: CafeView shows the
## preview and the edit panel shows the buttons.

## Piece id being held ("" = nothing).
var held_piece: String = ""
## The placed piece being moved ("" = a piece from storage).
var held_uid: String = ""
var rotated: bool = false


func is_holding() -> bool:
	return held_piece != ""


## Takes a stored piece in hand to place it.
func hold_stored(state: GameState, piece_id: String) -> String:
	if state.storage.get(piece_id, 0) <= 0:
		return GameLoop.NONE_STORED
	held_piece = piece_id
	held_uid = ""
	rotated = false
	return GameLoop.OK


## Takes a placed piece in hand to move it (it stays put until dropped).
func hold_placed(state: GameState, uid: String) -> String:
	var placed := Layout.placed_by_uid(state, uid)
	if placed == null:
		return GameLoop.UNKNOWN_PLACED
	held_piece = placed.piece_id
	held_uid = uid
	rotated = placed.rotated
	return GameLoop.OK


func rotate() -> void:
	rotated = not rotated


func cancel() -> void:
	held_piece = ""
	held_uid = ""
	rotated = false


## What dropping the held piece at cell would do:
## {"error": code or OK, "vibe": total seat Vibe after, "delta": change, "matches": uids it would
## combine with, "seats": seat uids within its range}.
func preview(state: GameState, cell: Vector2i, data: GameData) -> Dictionary:
	var error := Layout.check_spot(state, held_piece, cell, rotated, data, held_uid)
	if error != GameLoop.OK:
		return {"error": error, "vibe": state.vibe, "delta": 0.0, "matches": [] as Array[String], "seats": [] as Array[String]}
	var after := Layout.vibe_if(state, held_piece, cell, rotated, data, held_uid)
	return {"error": GameLoop.OK, "vibe": after, "delta": after - state.vibe,
		"matches": Layout.matching_neighbours(state, held_piece, cell, rotated, data, held_uid),
		"seats": Layout.seats_in_range(state, held_piece, cell, rotated, data, held_uid)}


## Drops the held piece at cell. A stored piece stays in hand while more of it
## are stored (to lay out several seats quickly).
func drop(state: GameState, cell: Vector2i, data: GameData) -> String:
	if not is_holding():
		return GameLoop.OK
	var code: String
	if held_uid != "":
		code = GameLoop.move_piece(state, held_uid, cell, rotated, data)
	else:
		code = GameLoop.place_piece(state, held_piece, cell, rotated, data)
	if code == GameLoop.OK and (held_uid != "" or state.storage.get(held_piece, 0) <= 0):
		cancel()
	return code


## Puts the held placed piece back in storage.
func store(state: GameState, data: GameData) -> String:
	if held_uid == "":
		cancel()
		return GameLoop.OK
	var code := GameLoop.pick_up_piece(state, held_uid, data)
	if code == GameLoop.OK:
		cancel()
	return code


## Sells the held piece (placed or one from storage). Décor only.
func sell(state: GameState, data: GameData) -> String:
	if not is_holding():
		return GameLoop.OK
	var code := GameLoop.sell_piece(state, held_uid, data) if held_uid != "" \
		else GameLoop.sell_stored_piece(state, held_piece, data)
	if code == GameLoop.OK and (held_uid != "" or state.storage.get(held_piece, 0) <= 0):
		cancel()
	return code
