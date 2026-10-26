class_name PlacedPiece
extends Resource
## A piece standing on the café floor. cell is its top-left tile.

@export var uid: String = ""
@export var piece_id: String = ""
@export var cell: Vector2i = Vector2i.ZERO
@export var rotated: bool = false


func to_dict() -> Dictionary:
	return {"uid": uid, "piece_id": piece_id, "cell": [cell.x, cell.y], "rotated": rotated}


static func from_dict(values: Dictionary) -> PlacedPiece:
	var placed := PlacedPiece.new()
	placed.uid = str(values.get("uid", ""))
	placed.piece_id = str(values.get("piece_id", ""))
	var cell: Variant = values.get("cell", [])
	placed.cell = Vector2i(int(cell[0]), int(cell[1])) if cell is Array and cell.size() == 2 else Vector2i(-1, -1)
	placed.rotated = bool(values.get("rotated", false))
	return placed
