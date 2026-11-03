class_name PieceArt
extends RefCounted
## Drawn art for furniture and décor: art/furniture/<name>.svg or
## art/decor/<name>.svg (made by tools/art/furniture_svg.py, see
## docs/art-guide.md). The café and battle views draw it in place of the
## placeholder blocks when it exists; a piece without art keeps its block.
##
## Each SVG is a 4x canvas: a tile is a 384 x 192 diamond, and for a piece
## drawn with a footprint of w x d tiles the top corner of its top-left tile
## sits at (d * 192 + PAD, height - (w + d) * 96 - PAD). A rotated piece is the
## same drawing mirrored (a w x d footprint mirrored is d x w).

## The SVGs are imported at half their 4x canvas (svg/scale in their .import files).
const IMPORT_SCALE: float = 0.5
## A tile's width on the 4x canvas, and the canvas's margin.
const CANVAS_TILE: float = 384.0
const PAD: float = 16.0
const FOLDERS: Array[String] = ["res://art/furniture/", "res://art/decor/"]

static var _cache: Dictionary[String, Texture2D] = {}


## The art called name, or null if there is none.
static func texture(name: String) -> Texture2D:
	if not _cache.has(name):
		var found: Texture2D = null
		for folder: String in FOLDERS:
			if ResourceLoader.exists(folder + name + ".svg"):
				found = load(folder + name + ".svg")
				break
		_cache[name] = found
	return _cache[name]


## Draws art name, drawn for a footprint of `footprint` tiles (unrotated), with
## the top corner of its top-left tile at `top` on canvas, a tile tile_width
## px wide; mirrored for a rotated piece. False if there is no such art.
static func draw(canvas: CanvasItem, name: String, footprint: Vector2i, mirrored: bool, top: Vector2, tile_width: float,
		tint := Color.WHITE) -> bool:
	var art := texture(name)
	if art == null:
		return false
	var page := Vector2(art.get_size()) / IMPORT_SCALE  # the SVG's own canvas size
	var anchor := Vector2(footprint.y * CANVAS_TILE * 0.5 + PAD, page.y - (footprint.x + footprint.y) * CANVAS_TILE * 0.25 - PAD)
	if mirrored:
		anchor.x = page.x - anchor.x
	var to_screen := tile_width / CANVAS_TILE
	var rect := Rect2(top - anchor * to_screen, page * to_screen)
	if mirrored:
		rect = Rect2(rect.position + Vector2(rect.size.x, 0), Vector2(-rect.size.x, rect.size.y))
	canvas.draw_texture_rect(art, rect, false, tint)
	return true


## The art and mirroring for a seat facing its table (facing = table cell - seat
## cell; zero = no table): ["seat_far" | "seat_near" | "seat", mirrored].
static func seat(facing: Vector2i) -> Array:
	match facing:
		Vector2i(1, 0):
			return ["seat_far", false]
		Vector2i(0, 1):
			return ["seat_far", true]
		Vector2i(-1, 0):
			return ["seat_near", false]
		Vector2i(0, -1):
			return ["seat_near", true]
	return ["seat", false]
