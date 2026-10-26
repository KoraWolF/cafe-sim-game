class_name Iso
extends RefCounted
## Isometric (2:1) projection for the café floor. Cell (x, y) is a floor tile;
## world positions are in pixels, the top corner of cell (0, 0) at the origin.

const TILE := Vector2(96, 48)


## World position of a point on the floor given in cell units (fractions allowed).
static func to_world(cell: Vector2) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE.x * 0.5, (cell.x + cell.y) * TILE.y * 0.5)


## The cell-unit point under a world position.
static func to_cell(world: Vector2) -> Vector2:
	var u := world.x / (TILE.x * 0.5)
	var v := world.y / (TILE.y * 0.5)
	return Vector2((u + v) * 0.5, (v - u) * 0.5)


## The tile under a world position.
static func tile_at(world: Vector2) -> Vector2i:
	var cell := to_cell(world)
	return Vector2i(floori(cell.x), floori(cell.y))


## World centre of a block of tiles.
static func centre(cell: Vector2i, size: Vector2i) -> Vector2:
	return to_world(Vector2(cell) + Vector2(size) * 0.5)


## Draw order: things nearer the viewer (larger x + y) are drawn later.
static func depth(cell: Vector2) -> float:
	return cell.x + cell.y
