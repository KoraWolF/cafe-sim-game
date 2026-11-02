extends TestCase
## Raids from the map: each rival café has its own layout (generated from its
## id, or hand-made in data), the raid is fought inside it right away (one a
## night), furniture blocks walking and gives cover, guards have levels.
## Data from TestFixtures: district "town" with rivals "weak", "fort" and flagship "hq".


func _night(data: GameData) -> GameState:
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	return state


func test_a_generated_cafe_is_the_same_every_time_and_open_to_walk() -> void:
	var data := TestFixtures.data()
	var rival := data.districts["town"].rival_by_id("weak")
	var one := RaidField.for_rival(rival, false, data)
	var two := RaidField.for_rival(rival, false, data)
	assert_eq(one.obstacles, two.obstacles, "same layout on every visit")
	assert_true(not one.obstacles.is_empty(), "has furniture")
	assert_eq(one.split, RaidField.ROWS, "the café is 4 rows deep")
	assert_eq(one.board.y, RaidField.ROWS + data.combat.half(), "with the player's 3 rows in front")
	for x: int in one.board.x:
		assert_true(not one.obstacles.has(Vector2i(x, one.split - 1)), "the door row is clear")
	assert_true(RaidField.for_rival(data.districts["town"].flagship, true, data).split == RaidField.FLAGSHIP_ROWS,
		"a flagship is deeper")


func test_a_hand_made_layout_wins() -> void:
	var content := TestFixtures.content()
	content["districts"][0]["rivals"][0]["layout"] = {"rows": 3, "pieces": [{"piece": "seat", "cell": [2, 0]},
		{"piece": "fern", "cell": [5, 1]}]}
	var data := GameData.from_content(content)
	var field := RaidField.for_rival(data.districts["town"].rivals[0], false, data)
	assert_eq(field.split, 3, "its own depth")
	assert_eq(field.obstacles.keys().size(), 2, "only its own pieces")
	assert_true(field.obstacles.has(Vector2i(5, 1)), "where it says")


func test_a_raid_is_fought_right_away_once_a_night() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	var raider := state.add_synth("worker", "", data)
	raider.battery = 50.0
	var out: Array[NightOps.Report] = []
	assert_eq(GameLoop.raid_now(state, "weak", [raider.id] as Array[String], data, out), GameLoop.OK, "raided")
	assert_eq(out.size(), 1, "the report comes back at once")
	assert_true(out[0].raid.field.split == RaidField.ROWS, "fought inside the rival café")
	assert_eq(state.phase, GameState.Phase.NIGHT, "still night")
	assert_eq(state.raid_target, "", "nothing left planned for End Night")
	assert_eq(GameLoop.raid_now(state, "fort", [raider.id] as Array[String], data), GameLoop.RAIDED_TONIGHT, "one a night")
	var report := GameLoop.end_night(state, data)
	assert_true(report.raid == null, "End Night doesn't raid again")


func test_furniture_gives_cover_from_shots() -> void:
	var data := TestFixtures.data({"battle_damage_variance": 0.0})
	var make := func(with_cover: bool) -> float:
		var field := Battle.Field.bare(data.combat)
		if with_cover:
			field.obstacles[Vector2i(4, 2)] = true  # right beside the target's spot
		var shooter := Battle.Fighter.make("a", 10.0, 100.0, CombatConfig.RANGED)
		var dummy := Battle.Fighter.make("", 0.0, 1000.0, CombatConfig.RANGED)
		dummy.cell = Vector2i(3, 0)  # the defenders' front row, column 3
		var report := Battle.run([shooter] as Array[Battle.Fighter], [dummy] as Array[Battle.Fighter], RandomNumberGenerator.new(), data, field)
		var hit: Battle.Event = report.events.filter(func(e: Battle.Event) -> bool: return e.kind == Battle.Event.HIT and not e.side)[0]
		return hit.amount
	assert_true(is_equal_approx(make.call(true), make.call(false) * 0.75), "25% less beside furniture")


func test_guards_level_up_with_the_days() -> void:
	var data := TestFixtures.data({"rival_growth_per_day": 0.05})
	var state := GameState.new_game(1, data)
	var weak := data.districts["town"].rival_by_id("weak")
	var start := NightOps.average_level(state, weak, data)
	state.day += 6  # 30% stronger
	assert_eq(NightOps.average_level(state, weak, data), start + 2.0, "+1 level per 15%")
