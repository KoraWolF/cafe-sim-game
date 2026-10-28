class_name Quests
extends RefCounted
## Quests and achievements (content in data.quests, from /data/quests.json):
## - Daily: daily_count quests rolled each real-world day (Session passes the
##   date) from the daily pool; targets grow with the game day, each with a
##   random reward. Progress counts from when the quest was rolled.
## - Story: one at a time, in order.
## - Achievements: one-time milestones.
## Lifetime counters in state.stats feed them (record_shift, record_night and
## GameLoop.convert_customer). Rewards are claimed by the player.

const DAILY: String = "daily"
const STORY: String = "story"
const ACHIEVEMENT: String = "achievement"


## Rolls new daily quests when the date changed (or there are none yet).
static func refresh(state: GameState, today: String, data: GameData) -> bool:
	if state.daily_date == today or data.quests.get("daily", []).is_empty():
		return false
	state.daily_date = today
	state.daily_quests.clear()
	var rng := state.rng()
	var pool: Array = data.quests["daily"].duplicate()
	for i: int in mini(int(data.quests.get("daily_count", 3)), pool.size()):
		var entry: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var target := int(entry.get("base", 1)) + int(entry.get("per_day", 0)) * (state.day - 1)
		var stat := str(entry.get("stat", ""))
		state.daily_quests.append({"id": entry["id"], "target": target, "start": int(state.stats.get(stat, 0)),
			"reward": _daily_reward(state, data, rng), "claimed": false})
	state.store_rng(rng)
	return true


static func _daily_reward(state: GameState, data: GameData, rng: RandomNumberGenerator) -> Dictionary:
	var options: Array = data.quests.get("daily_rewards", [])
	var total := 0.0
	for option: Dictionary in options:
		total += float(option.get("weight", 1.0))
	var roll := rng.randf() * total
	for option: Dictionary in options:
		roll -= float(option.get("weight", 1.0))
		if roll < 0.0:
			var reward: Dictionary = option["reward"].duplicate()
			if reward.has("coins"):
				reward["coins"] = int(reward["coins"]) + int(option.get("coins_per_day", 0)) * (state.day - 1)
			return reward
	return {}


## [progress, target] of a daily quest.
static func daily_progress(state: GameState, quest: Dictionary, data: GameData) -> Array[int]:
	var entry := _daily_entry(quest["id"], data)
	var target := int(quest["target"])
	if entry.get("check", "") == "vibe":
		return [mini(roundi(state.vibe), target), target]
	return [mini(int(state.stats.get(str(entry.get("stat", "")), 0)) - int(quest["start"]), target), target]


static func _daily_entry(quest_id: String, data: GameData) -> Dictionary:
	for entry: Dictionary in data.quests.get("daily", []):
		if entry["id"] == quest_id:
			return entry
	return {}


## The current story quest (empty when the story is done).
static func story_quest(state: GameState, data: GameData) -> Dictionary:
	var story: Array = data.quests.get("story", [])
	return story[state.story_index] if state.story_index < story.size() else {}


## [progress, target] of a story quest or achievement.
static func progress(state: GameState, entry: Dictionary, data: GameData) -> Array[int]:
	var target := int(entry.get("target", 1))
	var value := 0
	match str(entry.get("check", "")):
		"stat":
			value = int(state.stats.get(str(entry["stat"]), 0))
		"upgrade":
			value = int(state.upgrades.get(str(entry["upgrade"]), 0))
		"decor":
			value = Layout.count_placed(state, Piece.DECOR, data)
		"placed":
			value = Layout.count_placed(state, str(entry["kind"]), data)
		"district":
			value = 1 if state.owned_districts.has(str(entry["district"])) else 0
		"districts":
			value = state.owned_districts.size()
		"synths":
			value = state.synths.size()
		"max_level":
			for synth: Synth in state.synths:
				value = maxi(value, synth.level)
		"legendary":
			var owned: Array[Item] = state.inventory.duplicate()
			for synth: Synth in state.synths:
				owned.append_array(synth.items)
			value = owned.filter(func(item: Item) -> bool: return item.tier == "legendary").size()
		"vibe":
			value = roundi(state.vibe)
	return [mini(value, target), target]


static func is_done(state: GameState, entry: Dictionary, data: GameData) -> bool:
	var done := progress(state, entry, data)
	return done[0] >= done[1]


## Rewards waiting to be claimed (for the top bar's count).
static func claimable(state: GameState, data: GameData) -> int:
	var count := 0
	for quest: Dictionary in state.daily_quests:
		var done := daily_progress(state, quest, data)
		if not quest["claimed"] and done[0] >= done[1]:
			count += 1
	var story := story_quest(state, data)
	if not story.is_empty() and is_done(state, story, data):
		count += 1
	for entry: Dictionary in data.quests.get("achievements", []):
		if not state.achievements.has(entry["id"]) and is_done(state, entry, data):
			count += 1
	return count


## Claims a finished quest: DAILY with its index, STORY, or ACHIEVEMENT with
## its id. out_reward gets what was given.
static func claim(state: GameState, kind: String, key: String, data: GameData, out_reward: Array[Dictionary] = []) -> String:
	var reward: Dictionary
	match kind:
		DAILY:
			var index := int(key)
			if index < 0 or index >= state.daily_quests.size():
				return GameLoop.UNKNOWN_QUEST
			var quest := state.daily_quests[index]
			if quest["claimed"]:
				return GameLoop.ALREADY_CLAIMED
			var done := daily_progress(state, quest, data)
			if done[0] < done[1]:
				return GameLoop.NOT_DONE
			quest["claimed"] = true
			reward = quest["reward"]
		STORY:
			var story := story_quest(state, data)
			if story.is_empty():
				return GameLoop.UNKNOWN_QUEST
			if not is_done(state, story, data):
				return GameLoop.NOT_DONE
			state.story_index += 1
			reward = story["reward"]
		ACHIEVEMENT:
			var entry: Dictionary = {}
			for one: Dictionary in data.quests.get("achievements", []):
				if one["id"] == key:
					entry = one
			if entry.is_empty():
				return GameLoop.UNKNOWN_QUEST
			if state.achievements.has(key):
				return GameLoop.ALREADY_CLAIMED
			if not is_done(state, entry, data):
				return GameLoop.NOT_DONE
			state.achievements.append(key)
			reward = entry["reward"]
		_:
			return GameLoop.UNKNOWN_QUEST
	give(state, reward)
	out_reward.append(reward)
	return GameLoop.OK


static func give(state: GameState, reward: Dictionary) -> void:
	state.coins += int(reward.get("coins", 0))
	state.scrap += int(reward.get("scrap", 0))
	state.cores += int(reward.get("cores", 0))
	state.nanobrew += int(reward.get("nanobrew", 0))
	if reward.has("bottle"):
		state.bottles[reward["bottle"]] = state.bottles.get(reward["bottle"], 0) + 1
	if reward.has("fashion"):
		state.inventory.append(Items.make(state, Item.FASHION, str(reward["fashion"])))
	if reward.has("dish") and not state.dishes.has(str(reward["dish"])):
		state.dishes.append(str(reward["dish"]))


## Shift counters: served, stars, coins earned, batches; a day with nobody
## leaving angry (and not shut) counts as a clean day.
static func record_shift(state: GameState, events: Shift.Events) -> void:
	_add(state, "served", events.served.size())
	_add(state, "stars", events.starred.size())
	_add(state, "coins_earned", events.coins_earned + events.tips_earned)
	_add(state, "batches", events.dishes_ready.size())
	_add(state, "angry_today", events.left_angry.size())
	if events.shift_ended:
		if not events.closed and state.stats.get("angry_today", 0) == 0:
			_add(state, "clean_days", 1)
		state.stats.erase("angry_today")


static func record_night(state: GameState, report: NightOps.Report) -> void:
	if report.raid != null and report.raid.attackers_won:
		_add(state, "raids_won", 1)


static func _add(state: GameState, stat: String, amount: int) -> void:
	if amount != 0:
		state.stats[stat] = state.stats.get(stat, 0) + amount
