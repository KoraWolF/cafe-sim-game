extends TestCase
## Walking through the door: customers reach their seat and get back out
## (playtest 2 bug: they got stuck in the doorway).

const WIDTH: float = 8.0
const ROWS: float = 6.0
const STEP: float = 3.0 / 60.0  # 3 tiles a second at 60 fps


## Walks until it arrives (or gives up); returns [position, steps taken, crossed through the door].
func _walk(from: Vector2, to: Vector2) -> Array:
	var at := from
	var through_door := false
	for i: int in 2000:
		if at.is_equal_approx(to):
			return [at, i, through_door]
		var next := Walk.step(at, to, WIDTH, ROWS, STEP)
		if (at.x < WIDTH) != (next.x < WIDTH):
			# Crossing the edge only inside the door lane.
			through_door = absf(next.y - (ROWS - 0.5)) < 0.05
		at = next
	return [at, -1, through_door]


func test_customer_walks_in_to_a_seat() -> void:
	for seat: Vector2 in [Vector2(5.5, 3.5), Vector2(3.5, 5.5), Vector2(7.5, 0.5), Vector2(0.5, 0.5)]:
		var result := _walk(Vector2(WIDTH + 5.0, ROWS - 0.5), seat)
		assert_true(result[1] > 0, "reached the seat at %s (ended at %s)" % [seat, result[0]])
		assert_true(result[2], "came in through the door")


func test_customer_walks_out_to_the_street() -> void:
	var result := _walk(Vector2(5.5, 3.5), Vector2(WIDTH + 5.0, ROWS - 0.5))
	assert_true(result[1] > 0, "reached the street (ended at %s)" % result[0])
	assert_true(result[2], "left through the door")


func test_seat_to_call_board_and_queue() -> void:
	assert_true(_walk(Vector2(3.5, 3.5), Vector2(WIDTH + 0.55, ROWS - 2.3))[1] > 0, "seat to the call board line")
	assert_true(_walk(Vector2(WIDTH + 5.0, ROWS - 0.5), Vector2(WIDTH + 0.6, ROWS - 0.5))[1] > 0, "street to the queue")
	assert_true(_walk(Vector2(WIDTH + 0.6, ROWS - 0.5), Vector2(1.5, 5.5))[1] > 0, "front of the queue to a seat")
