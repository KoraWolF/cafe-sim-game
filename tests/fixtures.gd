class_name TestFixtures
extends RefCounted
## Fixed test data, independent of /data so tuning the game does not break tests.
## Shift 100 s; one customer every 50 s from second 3 (only "regular" spawns;
## "tourist" has weight 0); queue holds 2, patience 20 s; no satisfaction loss for
## the first 5 s waited, then 2/s. Star at 80, window 10 s, tip 50% of price.
## Delivery 4 s at speed 1, eating 5 s. 2 seats, 2 stoves, 2 pods, 100 coins,
## 1 NanoBrew, 10 Power, 0.1 Power per battery point. Battles: no damage variance,
## 10 rounds max. MegaBean never comes (chance 0) unless a test raises it.
## Recipes: tea (10 s, 3 servings, cost 10, price 10); jelly (needs an alien Synth).
## Species: steady (starter server, speed 1, drain 1), worker (speed 2, drain 0.5,
## battery 50, power 10, hp 30), chef (cook 1), alien (recharge x3).
## Traits: owl (late slowdown -0.5, power +5), klepto (always steals, loot +50%).
## District "town" (3 Influence for the flagship, income 50): rivals "weak" (1 guard
## 1 power / 5 hp, loot 40 coins + 1 core, 1 Influence), "fort" (1 guard 100 power /
## 1000 hp) and flagship "hq" (1 guard 2 / 10, loot 100 + 2 cores). Then "city"
## (2 Influence, income 100): rival "shop", flagship "tower". Rivals do not grow.
## Corporate Audit at 90 Suspicion: 2 raiders at x2 (10 power / 40 hp), loses half
## the coins, resets Suspicion to 40.
## XP: delivery 2, batch 6 (shared), arrival 1 (shared), raid 30 / 15, defense 20;
## level n -> n + 1 costs 100 * n; max level 3; +50% of base per level.
## Upgrades: stove 50 (x2 per level, max 2), seat 20 (+2 seats, max 3),
## pod 100 (max 1), menu slot 40 (max 1), security 30 (+10 hp, max 2).
## Floor 8 x 6; the floor upgrade adds 2 rows (100 coins, max 2). Pieces: seat 1x1,
## stove 2x1, pod 1x2 (new game lays out stoves, then pods, then seats, row by
## row); décor fern 1x1 (50 coins, 10 Vibe, plant), lamp 1x1 (30, 5, light),
## tank 2x2 (200, 40, plant); light next to plant +3. Vibe: waiting loss / (1 +
## 0.01 x Vibe), +0.1 x Vibe per dish (max 10); selling returns 50%.
## Menu: 2 slots, tea on it by default (jelly needs an alien). Favourites x3,
## +10 satisfaction when served.


static func content(balance_overrides := {}) -> Dictionary:
	var balance := {
		"shift_seconds": 100, "first_arrival_seconds": 3, "arrival_min_seconds": 50, "arrival_max_seconds": 50,
		"spawn_stop_before_end": 10, "max_queue": 2, "queue_patience_seconds": 20, "wait_grace_seconds": 5,
		"satisfaction_decay_per_second": 2.0, "break_satisfaction_penalty": 15.0, "star_threshold": 80.0,
		"star_window_seconds": 10, "delivery_seconds": 4, "eat_seconds": 5, "tip_rate": 0.5, "min_pay_share": 0.5,
		"low_battery_share": 0.2, "low_battery_factor": 0.5, "late_shift_start": 0.7,
		"start_coins": 100, "start_nanobrew": 1, "start_cores": 0, "start_power": 10.0, "start_seats": 2,
		"start_stoves": 2, "start_pods": 2, "start_menu_slots": 2, "favorite_weight": 3.0,
		"floor_width": 8, "start_floor_rows": 6, "vibe_decay_per_point": 0.01, "vibe_meal_bonus": 0.1,
		"vibe_meal_bonus_max": 10.0, "sell_refund": 0.5,
		"favorite_satisfaction": 10.0, "start_security": 0.0, "start_district": "town",
		"starter_species": "steady", "starter_name": "Proto", "brew_coin_cost": 30, "brew_core_cost": 1,
		"power_price": 2, "power_per_battery": 0.1, "conversion_suspicion": 10.0, "raid_suspicion": 20.0,
		"suspicion_decay": 5.0, "raid_squad_max": 2, "raid_battery_cost": 25.0, "raid_cooldown_days": 2,
		"battle_max_rounds": 10, "battle_damage_variance": 0.0, "defense_base_chance": 0.0,
		"defense_chance_per_suspicion": 0.0, "defense_max_chance": 1.0, "defense_size_step": 50.0,
		"defense_max_size": 2, "defense_power_base": 5.0, "defense_power_per_day": 0.0, "defense_hp_base": 20.0,
		"defense_hp_per_day": 0.0, "defense_coin_loss": 0.5, "defense_core_loss": 1, "steal_coins": 10,
		"audit_suspicion": 90.0, "audit_size": 2, "audit_strength": 2.0, "audit_coin_loss": 0.5,
		"audit_reset_suspicion": 40.0,
		"xp_per_delivery": 2, "xp_per_batch": 6, "xp_per_arrival": 1, "xp_raid_win": 30, "xp_raid_loss": 15,
		"xp_defense": 20, "xp_per_level": 100, "max_synth_level": 3, "stat_growth_per_level": 0.5,
	}
	balance.merge(balance_overrides, true)
	return {
		"balance": balance,
		"recipes": [
			{"id": "tea", "cook_seconds": 10, "servings": 3, "cost": 10, "price": 10},
			{"id": "jelly", "cook_seconds": 10, "servings": 1, "cost": 5, "price": 50, "unlock_species": "alien"},
		],
		"customer_types": [
			{"id": "regular", "weight": 1, "synth_species": "worker", "patience": 1.0, "tip": 1.0,
				"trait_pool": ["owl"]},
			{"id": "tourist", "weight": 0, "synth_species": "alien", "patience": 1.0, "tip": 1.0, "favorites": ["jelly"],
				"trait_pool": []},
		],
		"species": [
			{"id": "steady", "best_role": "server", "stats": {"speed": 1.0, "power": 5, "hp": 20,
				"battery_max": 100, "drain": 1.0}},
			{"id": "worker", "best_role": "server", "stats": {"speed": 2.0, "power": 10, "hp": 30,
				"battery_max": 50, "drain": 0.5}},
			{"id": "chef", "best_role": "chef", "stats": {"cook": 1.0, "power": 5, "hp": 20, "battery_max": 100}},
			{"id": "alien", "best_role": "chef", "stats": {"cook": 0.5, "power": 5, "hp": 20, "battery_max": 100,
				"recharge_multiplier": 3.0}},
		],
		"traits": [
			{"id": "owl", "modifiers": {"late_shift_slowdown": -0.5, "power": 5}},
			{"id": "klepto", "modifiers": {"steal_chance": 1.0, "raid_loot": 0.5}},
		],
		"districts": [
			{"id": "town", "influence_required": 3, "income": 50, "rivals": [
				{"id": "weak", "defenders": [{"power": 1, "hp": 5}], "loot_coins": 40, "loot_cores": 1, "influence": 1},
				{"id": "fort", "defenders": [{"power": 100, "hp": 1000}], "loot_coins": 999, "loot_cores": 9,
					"influence": 2},
			], "flagship": {"id": "hq", "defenders": [{"power": 2, "hp": 10}], "loot_coins": 100, "loot_cores": 2}},
			{"id": "city", "influence_required": 2, "income": 100, "rivals": [
				{"id": "shop", "defenders": [{"power": 1, "hp": 5}], "loot_coins": 10, "loot_cores": 0, "influence": 1},
			], "flagship": {"id": "tower", "defenders": [{"power": 2, "hp": 10}], "loot_coins": 300, "loot_cores": 3}},
		],
		"upgrades": [
			{"id": "stove", "step": 1, "base_cost": 50, "cost_growth": 2.0, "max_level": 2},
			{"id": "seat", "step": 2, "base_cost": 20, "cost_growth": 1.0, "max_level": 3},
			{"id": "pod", "step": 1, "base_cost": 100, "cost_growth": 1.0, "max_level": 1},
			{"id": "menu_slot", "step": 1, "base_cost": 40, "cost_growth": 1.0, "max_level": 1},
			{"id": "floor", "step": 2, "base_cost": 100, "cost_growth": 1.0, "max_level": 2},
			{"id": "security", "step": 10, "base_cost": 30, "cost_growth": 1.0, "max_level": 2},
		],
		"pieces": [
			{"id": "seat", "kind": "seat", "size": [1, 1], "tags": ["seat"]},
			{"id": "stove", "kind": "stove", "size": [2, 1], "tags": ["kitchen"]},
			{"id": "pod", "kind": "pod", "size": [1, 2], "tags": ["tech"]},
			{"id": "fern", "kind": "decor", "size": [1, 1], "price": 50, "vibe": 10, "tags": ["plant"]},
			{"id": "lamp", "kind": "decor", "size": [1, 1], "price": 30, "vibe": 5, "tags": ["light"]},
			{"id": "tank", "kind": "decor", "size": [2, 2], "price": 200, "vibe": 40, "tags": ["plant"]},
		],
		"adjacency": [
			{"tags": ["light", "plant"], "vibe": 3},
		],
	}


static func data(balance_overrides := {}) -> GameData:
	return GameData.from_content(content(balance_overrides))
