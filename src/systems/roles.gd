class_name Roles
extends RefCounted
## Jobs by place: the player clicks a worker, then a stove (Chef at that
## stove), a counter or table (Server), a register (Cashier at that register)
## or the Pod bay (Rest). One Chef per stove and one Cashier per register; a
## worker already there goes to Rest. A Chef or Cashier whose station is gone
## takes a free one (or waits); bind_free also covers older saves.


## Gives a worker the job of the placed piece at uid.
static func assign_to(state: GameState, synth_id: String, uid: String, data: GameData) -> String:
	var synth := state.synth_by_id(synth_id)
	if synth == null:
		return GameLoop.UNKNOWN_SYNTH
	var placed := Layout.placed_by_uid(state, uid)
	if placed == null:
		return GameLoop.UNKNOWN_PLACED
	if synth.is_busy():
		return GameLoop.SYNTH_BUSY
	match data.pieces[placed.piece_id].kind:
		Piece.STOVE:
			_take_station(state, synth, Synth.CHEF, uid)
		Piece.REGISTER:
			_take_station(state, synth, Synth.CASHIER, uid)
		Piece.COUNTER, Piece.TABLE:
			synth.role = Synth.SERVER
			synth.station_uid = ""
		_:
			return GameLoop.NO_JOB_THERE
	return GameLoop.OK


## Back to its Pod to rest.
static func rest(state: GameState, synth_id: String) -> String:
	var synth := state.synth_by_id(synth_id)
	if synth == null:
		return GameLoop.UNKNOWN_SYNTH
	if synth.is_busy():
		return GameLoop.SYNTH_BUSY
	synth.role = Synth.REST
	synth.station_uid = ""
	return GameLoop.OK


static func _take_station(state: GameState, synth: Synth, role: String, uid: String) -> void:
	for other: Synth in state.synths:
		if other != synth and other.station_uid == uid:
			other.role = Synth.REST
			other.station_uid = ""
	synth.role = role
	synth.station_uid = uid


## The Synth stationed at a placed piece, or null.
static func at_station(state: GameState, uid: String) -> Synth:
	for synth: Synth in state.synths:
		if synth.station_uid == uid and synth.station_uid != "":
			return synth
	return null


## Chefs and Cashiers without a station (or whose station is gone) take a free
## stove or register, in floor order; others drop their station.
static func bind_free(state: GameState, data: GameData) -> void:
	for synth: Synth in state.synths:
		var kind := {Synth.CHEF: Piece.STOVE, Synth.CASHIER: Piece.REGISTER}.get(synth.role, "") as String
		var placed := Layout.placed_by_uid(state, synth.station_uid)
		if kind == "":
			synth.station_uid = ""
			continue
		if placed != null and data.pieces[placed.piece_id].kind == kind:
			continue
		synth.station_uid = ""
		for piece: PlacedPiece in state.placed:
			if data.pieces[piece.piece_id].kind == kind and at_station(state, piece.uid) == null:
				synth.station_uid = piece.uid
				break
