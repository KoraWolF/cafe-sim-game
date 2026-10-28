extends TestCase
## Dishes are unlocked one by one: a new game has its start dishes, quest
## rewards add more, and won raids and held defenses may drop one.


func test_real_start_is_coffee_and_the_story_brings_toast_and_ramen() -> void:
	var data := GameData.load_default()
	var state := GameState.new_game(1, data)
	assert_eq(state.dishes, ["coffee"] as Array[String], "coffee only")
	assert_eq(GameLoop.start_cooking(state, 0, "toast", data), GameLoop.RECIPE_LOCKED, "toast is locked")
	state.stats["conversions"] = 1
	assert_eq(GameLoop.claim_quest(state, Quests.STORY, "", data), GameLoop.OK, "first story step")
	assert_true(state.dishes.has("toast"), "it gives Toast")
	var sources := {}
	for recipe: Recipe in data.recipes.values():
		sources[recipe.source] = sources.get(recipe.source, 0) + 1
	assert_true(sources.get("raid", 0) >= 2 and sources.get("defense", 0) >= 2 and sources.get("achievement", 0) >= 2,
		"dishes to find from raids, defending and achievements: %s" % sources)


func test_a_won_raid_can_drop_a_dish() -> void:
	var content := TestFixtures.content({"dish_drop_chance": 1.0})
	content["recipes"].append({"id": "loot_soup", "cook_seconds": 10, "servings": 2, "cost": 5, "price": 9, "source": "raid"})
	var data := GameData.from_content(content)
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	state.add_synth("worker", "", data)
	GameLoop.plan_raid(state, "weak", [state.synths[-1].id] as Array[String], data)
	var report := GameLoop.end_night(state, data)
	assert_true(report.raid.attackers_won, "setup: raid won")
	assert_eq(report.new_dish, "loot_soup", "the raid dish dropped")
	assert_true(state.dishes.has("loot_soup"), "and can be cooked")
