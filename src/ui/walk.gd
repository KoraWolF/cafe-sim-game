class_name Walk
extends RefCounted
## Walking in and out of the café only through the door. The door is a short
## lane across the front-right edge (x = floor width): a walker crossing the edge
## goes to the lane's near end, through the lane, then on to where it is going.
## Positions are in cell units; inside the café means x < width.

## How far the lane reaches either side of the edge.
const LANE: float = 0.3
const EPSILON: float = 0.02


## The lane's ends: [outside end, inside end].
static func lane(width: float, rows: float) -> Array[Vector2]:
	var y := rows - 0.5
	return [Vector2(width + LANE, y), Vector2(width - LANE, y)]


## One step of `distance` from at toward target, through the door if needed.
static func step(at: Vector2, target: Vector2, width: float, rows: float, distance: float) -> Vector2:
	var ends := lane(width, rows)
	var inside := at.x < width
	if inside == (target.x < width):
		return at.move_toward(target, distance)
	var near_end := ends[1] if inside else ends[0]
	var far_end := ends[0] if inside else ends[1]
	var in_lane := absf(at.y - near_end.y) < EPSILON and absf(at.x - near_end.x) <= LANE * 2.0 + EPSILON
	return at.move_toward(far_end if in_lane else near_end, distance)
