extends TestCase
## Replaying a battle hit by hit ends exactly where Battle.run did.


func _battle(seed_value: int) -> Battle.Report:
	var data := TestFixtures.data({"battle_damage_variance": 0.3})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var a: Array[Battle.Fighter] = [Battle.Fighter.make("a", 6.0, 30.0), Battle.Fighter.make("b", 9.0, 20.0)]
	var d: Array[Battle.Fighter] = [Battle.Fighter.make("", 7.0, 25.0), Battle.Fighter.make("", 5.0, 40.0)]
	return Battle.run(a, d, rng, data.balance)


func test_replay_starts_full_and_ends_at_the_recorded_result() -> void:
	for seed_value: int in [1, 2, 3, 4, 5]:
		var report := _battle(seed_value)
		var playback := BattlePlayback.new(report)
		assert_eq(playback.attacker_hp, [30.0, 20.0] as Array[float], "starts at full HP")
		playback.finish()
		for i: int in report.attackers.size():
			assert_true(is_equal_approx(playback.attacker_hp[i], report.attackers[i].hp), "attacker %d ends as recorded" % i)
		for i: int in report.defenders.size():
			assert_true(is_equal_approx(playback.defender_hp[i], report.defenders[i].hp), "defender %d ends as recorded" % i)


func test_time_applies_hits_one_by_one() -> void:
	var report := _battle(1)
	var playback := BattlePlayback.new(report)
	assert_true(playback.hit_count() >= 2, "setup: at least two hits")
	playback.advance_time(BattlePlayback.HIT_SECONDS * 0.5)
	assert_eq(playback.applied, 0, "first hit still playing")
	var first := playback.current(BattlePlayback.HIT_SECONDS * 0.5)
	assert_eq(first["hit"], report.hits[0], "playing the first hit")
	assert_true(is_equal_approx(first["progress"], 0.5), "halfway through it")
	playback.advance_time(BattlePlayback.HIT_SECONDS * 1.01)
	assert_eq(playback.applied, 1, "first hit landed")
	var target := playback.defender_hp if report.hits[0].attacker_side else playback.attacker_hp
	var full := report.defenders if report.hits[0].attacker_side else report.attackers
	assert_true(is_equal_approx(target[report.hits[0].target_index],
		maxf(full[report.hits[0].target_index].max_hp - report.hits[0].damage, 0.0)), "its damage applied")
	assert_true(playback.current(playback.duration() + 1.0).is_empty(), "nothing after the end")
	assert_eq(playback.round_at(0.0), 1, "round 1 first")
