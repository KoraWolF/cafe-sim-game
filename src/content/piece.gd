class_name Piece
extends RefCounted
## Something that stands on the café floor: furniture (seat, table, stove, counter, bin),
## which comes from upgrades, or décor, which is bought for coins and adds Vibe.

## Seats only work beside a table (one seat per table; the seat faces it).
const SEAT: String = "seat"
## Where a seated customer's dish is served and eaten.
const TABLE: String = "table"
const STOVE: String = "stove"
## Where finished dishes wait for servers. A café always keeps at least one.
const COUNTER: String = "counter"
## Where servers throw away food the player no longer wants (no refund).
const BIN: String = "bin"
const DECOR: String = "decor"
const KINDS: Array[String] = [SEAT, TABLE, STOVE, COUNTER, BIN, DECOR]

var id: String = ""
var kind: String = DECOR
## Tiles wide x deep, unrotated.
var size: Vector2i = Vector2i.ONE
## Coins to buy (décor only); selling returns sell_refund of it.
var price: int = 0
var vibe: float = 0.0
## Matched by adjacency rules.
var tags: Array[String] = []


static func from_dict(values: Dictionary) -> Piece:
	var piece := Piece.new()
	piece.id = values.get("id", "")
	piece.kind = values.get("kind", DECOR)
	var size: Variant = values.get("size", [1, 1])
	if size is Array and size.size() == 2:
		piece.size = Vector2i(int(size[0]), int(size[1]))
	piece.price = int(values.get("price", 0))
	piece.vibe = float(values.get("vibe", 0.0))
	piece.tags.assign(values.get("tags", []))
	return piece


## Footprint, with width and depth swapped when rotated.
func footprint(rotated: bool) -> Vector2i:
	return Vector2i(size.y, size.x) if rotated else size
