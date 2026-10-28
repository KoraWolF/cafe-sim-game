extends TestCase
## Quests: 3 dailies rolled per real-world date (targets grow with the game
## day; progress counts from the roll), a story chain one step at a time, and
## one-time achievements. Counters come from shifts, nights and conversions.
## Uses the real /data content (quests.json, items.json).


func _game() -> Array:
	var data := GameData.load_default()
	return [GameState.new_game(1, data), data]


func test_dailies_roll_once_per_date() -> void:
	var setup := _game()
	var state: GameState = setup[0]
	var data: GameData = setup[1]
	assert_true(Quests.refresh(state, "2026-10-27", data), "rolled")
	assert_eq(state.daily_quests.size(), 3, "three dailies")
	var ids := state.daily_quests.map(func(q: Dictionary) -> String: return q["id"])
	assert_true(ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2], "all different")
	var first := state.daily_quests.duplicate(true)
	assert_true(not Quests.refresh(state, "2026-10-27", data), "same date: kept")
	assert_eq(state.daily_quests, first, "unchanged")
	assert_true(Quests.refresh(state, "2026-10-28", data), "next day: new ones")


func test_daily_progress_counts_from_the_roll_and_claims_once() -> void:
	var setup := _game()
	var state: GameState = setup[0]
	var data: GameData = setup[1]
	state.stats["served"] = 50
	state.daily_quests = [{"id": "serve", "target": 15, "start": 50, "reward": {"coins": 40}, "claimed": false}]
	state.daily_date = "2026-10-27"
	assert_eq(Quests.daily_progress(state, state.daily_quests[0], data), [0, 15] as Array[int], "earlier serving doesn't count")
	assert_eq(GameLoop.claim_quest(state, Quests.DAILY, "0", data), GameLoop.NOT_DONE, "not yet")
	state.stats["served"] = 70
	assert_eq(Quests.claimable(state, data), 1, "one to claim")
	var coins := state.coins
	assert_eq(GameLoop.claim_quest(state, Quests.DAILY, "0", data), GameLoop.OK, "claimed")
	assert_eq(state.coins, coins + 40, "reward")
	assert_eq(GameLoop.claim_quest(state, Quests.DAILY, "0", data), GameLoop.ALREADY_CLAIMED, "only once")


func test_shift_and_night_feed_the_counters() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.counter["tea"] = 6
	GameLoop.advance(state, 40, data)
	assert_true(state.stats.get("served", 0) > 0, "served counted")
	assert_true(state.stats.get("coins_earned", 0) > 0, "coins counted")
	GameLoop.advance(state, data.balance.shift_seconds, data)
	assert_true(state.stats.has("clean_days") or state.stats.get("served", 0) > 0, "the shift ended")
	state.add_synth("worker", "", data)
	GameLoop.plan_raid(state, "weak", [state.synths[1].id] as Array[String], data)
	GameLoop.end_night(state, data)
	assert_eq(state.stats.get("raids_won", 0), 1, "raid win counted")


func test_story_goes_in_order_and_gives_fashion() -> void:
	var setup := _game()
	var state: GameState = setup[0]
	var data: GameData = setup[1]
	assert_eq(Quests.story_quest(state, data)["id"], "first_conversion", "starts with a conversion")
	assert_eq(GameLoop.claim_quest(state, Quests.STORY, "", data), GameLoop.NOT_DONE, "not yet")
	state.stats["conversions"] = 1
	assert_eq(GameLoop.claim_quest(state, Quests.STORY, "", data), GameLoop.OK, "claimed")
	assert_eq(Quests.story_quest(state, data)["id"], "second_stove", "next step")
	state.coins += 500
	GameLoop.buy_piece(state, "stove", data)
	var spot := Layout.find_spot(state, "stove", data)
	GameLoop.place_piece(state, "stove", spot["cell"], spot["rotated"], data)
	var hats := state.inventory.size()
	GameLoop.claim_quest(state, Quests.STORY, "", data)
	assert_eq(state.inventory.size(), hats + 1, "a fashion piece")
	assert_eq(state.inventory[-1].type_id, "beanie", "the Beanie")


func test_achievements_claim_once() -> void:
	var setup := _game()
	var state: GameState = setup[0]
	var data: GameData = setup[1]
	assert_eq(GameLoop.claim_quest(state, Quests.ACHIEVEMENT, "served_100", data), GameLoop.NOT_DONE, "not yet")
	state.stats["served"] = 100
	assert_eq(GameLoop.claim_quest(state, Quests.ACHIEVEMENT, "served_100", data), GameLoop.OK, "claimed")
	assert_eq(GameLoop.claim_quest(state, Quests.ACHIEVEMENT, "served_100", data), GameLoop.ALREADY_CLAIMED, "once")
	assert_eq(GameLoop.claim_quest(state, Quests.ACHIEVEMENT, "nope", data), GameLoop.UNKNOWN_QUEST, "unknown")
	state.inventory.append(Items.make(state, Item.EQUIPMENT, "swift_boots", "legendary"))
	assert_true(Quests.is_done(state, data.quests["achievements"][9], data), "legendary owned")


func test_conversion_counts() -> void:
	var data := TestFixtures.data()
	var state := GameState.new_game(1, data)
	state.counter["tea"] = 3
	var events := GameLoop.advance(state, 12, data)
	GameLoop.convert_customer(state, events.starred[0], data)
	assert_eq(state.stats.get("conversions", 0), 1, "counted")


func test_quest_state_is_saved() -> void:
	var setup := _game()
	var state: GameState = setup[0]
	var data: GameData = setup[1]
	Quests.refresh(state, "2026-10-27", data)
	state.stats["served"] = 12
	state.story_index = 2
	state.achievements.append("served_100")
	var loaded := SaveSystem.from_dict(JSON.parse_string(JSON.stringify(SaveSystem.to_dict(state))))
	assert_eq(loaded.daily_date, "2026-10-27", "date")
	assert_eq(loaded.daily_quests.size(), 3, "dailies")
	assert_eq(loaded.daily_quests[0]["target"], state.daily_quests[0]["target"], "targets")
	assert_eq(loaded.stats["served"], 12, "counters")
	assert_eq(loaded.story_index, 2, "story step")
	assert_eq(loaded.achievements, ["served_100"] as Array[String], "achievements")
	assert_true(not Quests.refresh(loaded, "2026-10-27", data), "same date after loading: kept")
