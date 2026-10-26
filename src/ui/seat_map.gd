class_name SeatMap
extends RefCounted
## Which placed seat each seated customer sits at, for drawing. The logic only
## counts seats, so the UI keeps a stable mapping: a customer keeps their seat
## until they stand up, and newcomers take the first free seat in floor order.

## Customer id -> seat piece uid.
var seat_of: Dictionary[String, String] = {}


## Updates the mapping for the current customers and seats.
func update(state: GameState, data: GameData) -> void:
	var seat_uids: Array[String] = []
	for placed: PlacedPiece in state.placed:
		if data.pieces[placed.piece_id].kind == Piece.SEAT:
			seat_uids.append(placed.uid)
	var seated: Array[String] = []
	for customer: Customer in state.customers:
		if customer.is_seated():
			seated.append(customer.id)
	for customer_id: String in seat_of.keys():
		if not seated.has(customer_id) or not seat_uids.has(seat_of[customer_id]):
			seat_of.erase(customer_id)
	var taken: Array[String] = []
	taken.assign(seat_of.values())
	for customer_id: String in seated:
		if seat_of.has(customer_id):
			continue
		for uid: String in seat_uids:
			if not taken.has(uid):
				seat_of[customer_id] = uid
				taken.append(uid)
				break
