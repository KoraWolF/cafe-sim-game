extends TestCase
## Playtest 10: worker HP carries over between fights and recovers with rest;
## at 0 HP a worker is knocked out on a timer; ticked defenders can't raid.


func _night(data: GameData) -> GameState:
	var state := GameState.new_game(1, data)
	GameLoop.advance(state, data.balance.shift_seconds, data)
	return state


func test_a_ticked_defender_cant_raid() -> void:
	var data := TestFixtures.data()
	var state := _night(data)
	var raider := state.add_synth("worker", "", data)
	GameLoop.set_defender(state, raider.id, true)
	assert_eq(GameLoop.plan_raid(state, "weak", [raider.id] as Array[String], data), GameLoop.IS_DEFENDER, "ticked")
	GameLoop.set_defender(state, raider.id, false)
	assert_eq(GameLoop.plan_raid(state, "weak", [raider.id] as Array[String], data), GameLoop.OK, "unticked")


func test_hurt_stays_after_a_fight_and_a_night_heals_part_of_it() -> void:
	var data := TestFixtures.data({"night_heal_share": 0.25})
	var state := _night(data)
	var raider := state.add_synth("worker", "", data)
	var top := SynthStats.stat(raider, "hp", data)
	assert_eq(SynthStats.hp_now(raider, data), top, "new: full")
	raider.hp = top * 0.5
	GameLoop.end_night(state, data)
	assert_true(is_equal_approx(raider.hp, top * 0.75), "half + a quarter from the night")
	var fighter := NightOps.synth_fighter(raider, 0.0, data)
	assert_true(is_equal_approx(fighter.hp, top * 0.75) and fighter.max_hp == top, "fights with what it has")


func test_resting_in_a_pod_heals_by_day() -> void:
	var data := TestFixtures.data({"pod_heal_share": 0.01})
	var state := GameState.new_game(1, data)
	var hurt := state.add_synth("worker", "", data)
	hurt.role = Synth.REST
	var top := SynthStats.stat(hurt, "hp", data)
	hurt.hp = top * 0.5
	GameLoop.advance(state, 10, data)
	assert_true(is_equal_approx(hurt.hp, top * 0.6), "1% a second")


func test_a_knocked_out_worker_rests_on_a_timer_then_returns_at_half() -> void:
	var data := TestFixtures.data({"knockout_seconds": 20, "knockout_seconds_per_level": 5, "knockout_return_share": 0.5})
	var state := GameState.new_game(1, data)
	var fallen := state.add_synth("worker", "", data)
	fallen.level = 3
	NightOps.knock_out(fallen, data)
	assert_eq(fallen.ko_left, 30, "20 + 5 per level above 1")
	assert_eq(fallen.role, Synth.REST, "forced into its Pod")
	assert_eq(fallen.battery, 0.0, "drained")
	assert_true(not SynthStats.can_fight(fallen, data), "can't fight")
	assert_eq(GameLoop.assign_role(state, fallen.id, Synth.SERVER, data), GameLoop.KNOCKED_OUT, "can't work")
	GameLoop.advance(state, 29, data)
	assert_eq(fallen.battery, 0.0, "nothing recovers before the timer ends")
	GameLoop.advance(state, 1, data)
	assert_eq(fallen.ko_left, 0, "up")
	assert_true(is_equal_approx(fallen.hp, SynthStats.stat(fallen, "hp", data) * 0.5), "half HP")
	assert_true(is_equal_approx(fallen.battery, SynthStats.stat(fallen, "battery_max", data) * 0.5), "half battery")


func test_wall_decor_hangs_on_the_grid_and_adds_vibe_near_seats() -> void:
	var content := TestFixtures.content({"decor_range": 2})
	content["pieces"].append({"id": "poster", "kind": "wall_decor", "price": 10, "vibe": 5})
	content["pieces"].append({"id": "window", "kind": "wall_decor", "height": 2, "price": 10, "vibe": 1})
	var data := GameData.from_content(content)
	var state := _night(data)
	state.coins = 100
	GameLoop.buy_piece(state, "poster", data)
	GameLoop.buy_piece(state, "window", data)
	var vibe := state.vibe
	assert_eq(GameLoop.place_on_wall(state, "poster", "R7", 1, data), GameLoop.OK, "above seat (7, 0)")
	assert_true(state.vibe > vibe, "adds Vibe near the seats")
	assert_eq(GameLoop.place_on_wall(state, "window", "R7", 0, data), GameLoop.OVERLAP, "2 cells tall: the poster is in the way")
	assert_eq(GameLoop.place_on_wall(state, "window", "R7", 2, data), GameLoop.OUT_OF_BOUNDS, "doesn't fit at the top")
	assert_eq(Walls.take(state, "R7", 1, data), "poster", "comes down")
	assert_eq(state.storage.get("poster", 0), 1, "back in storage")
	assert_eq(state.vibe, vibe, "its Vibe with it")


func test_a_wall_panel_paints_a_column_and_returns_the_old_one() -> void:
	var content := TestFixtures.content()
	content["pieces"].append({"id": "brick", "kind": "wall_style", "price": 10, "vibe": 0})
	content["pieces"].append({"id": "steel", "kind": "wall_style", "price": 10, "vibe": 0})
	var data := GameData.from_content(content)
	var state := _night(data)
	state.coins = 100
	assert_eq(Walls.style(state, "L2"), Walls.BARE, "cracked to start with")
	GameLoop.buy_piece(state, "brick", data)
	GameLoop.buy_piece(state, "steel", data)
	GameLoop.place_on_wall(state, "brick", "L2", 0, data)
	assert_eq(Walls.style(state, "L2"), "brick", "painted")
	assert_eq(Walls.style(state, "L3"), Walls.BARE, "only that column")
	GameLoop.place_on_wall(state, "steel", "L2", 2, data)
	assert_eq(Walls.style(state, "L2"), "steel", "repainted")
	assert_eq(state.storage.get("brick", 0), 1, "the old panel is back in storage")


func test_a_knocked_out_worker_goes_back_to_its_job_when_the_timer_ends() -> void:
	var data := GameData.from_content(TestFixtures.content({"knockout_seconds": 3, "knockout_seconds_per_level": 0}))
	var state := _night(data)
	var worker := state.synths[0]
	worker.day_role = Synth.SERVER
	NightOps.knock_out(worker, data)
	GameLoop.end_night(state, data)
	assert_eq(worker.role, Synth.REST, "still out in the morning")
	GameLoop.advance(state, 4, data)
	assert_eq(worker.ko_left, 0, "timer done")
	assert_eq(worker.role, Synth.SERVER, "back at its job")


func test_a_raider_cant_be_ticked_as_a_defender() -> void:
	var data := GameData.from_content(TestFixtures.content())
	var state := _night(data)
	var raider := state.synths[0]
	state.raid_squad.append(raider.id)
	assert_eq(GameLoop.set_defender(state, raider.id, true), GameLoop.ON_RAID, "refused")
	assert_true(not state.defenders.has(raider.id), "not ticked")


func test_a_save_with_broken_walls_or_hp_is_refused() -> void:
	var content := TestFixtures.content()
	content["pieces"].append({"id": "window", "kind": "wall_decor", "height": 2, "price": 10, "vibe": 1})
	content["pieces"].append({"id": "brick", "kind": "wall_style", "price": 10, "vibe": 0})
	var data := GameData.from_content(content)
	var state := _night(data)
	state.coins = 100
	GameLoop.buy_piece(state, "window", data)
	GameLoop.buy_piece(state, "brick", data)
	GameLoop.place_on_wall(state, "window", "L1", 0, data)
	GameLoop.place_on_wall(state, "brick", "L1", 0, data)
	assert_eq(Walls.check(state, data).size(), 0, "real walls pass")
	state.walls["L1"]["cells"] = ["window", "", ""]
	assert_eq(Walls.check(state, data).size(), 1, "a tall piece cut short")
	state.walls["L1"]["cells"] = ["nope", "", ""]
	assert_eq(Walls.check(state, data).size(), 1, "an unknown piece")
	state.walls["L1"] = {"style": "window", "cells": ["", "", ""]}
	assert_eq(Walls.check(state, data).size(), 1, "decor used as a panel")
	state.walls["L1"] = {"style": ""}
	assert_eq(Walls.check(state, data).size(), 1, "no cells")
	state.walls.clear()
	state.walls["L99"] = {"style": "", "cells": ["", "", ""]}
	assert_eq(Walls.check(state, data).size(), 1, "a column off the walls")
	state.walls.clear()
	state.synths[0].ko_left = -1
	assert_true(SaveSystem.validate(state, data).size() > 0, "a negative knockout timer")
