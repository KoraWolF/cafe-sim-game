class_name BalanceConfig
extends RefCounted
## Tunable numbers from /data/balance.json. Times are in game seconds
## (1 game second = 1 real second at 1x speed).

## Length of one café shift.
var shift_seconds: int = 480
## The first customer arrives this long after the shift opens.
var first_arrival_seconds: int = 3
## Gap between arrivals in a café arrival_reference_size tiles square; a
## bigger café and the Cashiers' appeal shorten it (see Shift.arrival_rate).
var arrival_min_seconds: int = 10
var arrival_max_seconds: int = 18
var arrival_reference_size: float = 8.0
## No new customers in the last part of the shift.
var spawn_stop_before_end: int = 45
## Customers in a new café wait 1 + patience_bonus times as long (in line and at
## their seat); it shrinks to nothing at the top café level.
var patience_bonus: float = 0.0
## Customers waiting for a seat; more are turned away.
var max_queue: int = 6
## A queued customer leaves after this many seconds times their type's patience.
var queue_patience_seconds: int = 40
## Waiting this long costs nothing; after it, satisfaction drops each second
## by satisfaction_decay_per_second / type patience.
var wait_grace_seconds: int = 8
var satisfaction_decay_per_second: float = 1.5
## Satisfaction lost when a server drops the customer's dish.
var break_satisfaction_penalty: float = 15.0
## A customer who finishes eating at or above this (out of 100) gets a star:
## they tip, and can be converted while they pay and for star_window_seconds after.
var star_threshold: float = 80.0
var star_window_seconds: int = 20
## Seconds a speed 1.0 server spends handing a dish over (plus the walk).
var delivery_seconds: int = 6
## How fast everyone walks: trips take as long as the walk (see Shift._start_trip).
var walk_tiles_per_second: float = 1.8
## Seconds a speed 1.0 server spends picking up or putting down food (plus the walk).
var carry_seconds: int = 3
var eat_seconds: int = 15
## Tip = price * tip_rate * type tip * (1 + server tip bonus), only for starred customers.
var tip_rate: float = 0.25
## Pay = price * (min_pay_share + (1 - min_pay_share) * satisfaction / 100).
var min_pay_share: float = 0.5
## Below this share of max battery a Synth works at low_battery_factor speed;
## an empty one still works, at empty_battery_factor.
var low_battery_share: float = 0.2
var low_battery_factor: float = 0.5
var empty_battery_factor: float = 0.0
## Share of the shift after which late_shift_slowdown applies.
var late_shift_start: float = 0.7
var start_coins: int = 200
var start_nanobrew: int = 1
var start_cores: int = 0
var start_power: float = 50.0
var start_seats: int = 4
## Tables a new game starts with (each seat needs one beside it).
var start_tables: int = 0
var start_stoves: int = 2
var start_pods: int = 2
## Coins for one more Sync Pod; a café holds as many Pods as tiles along its side.
var pod_price: int = 250
## Counters a new game starts with (0 only in tests that lay out by hand).
var start_counters: int = 1
## Bins a new game starts with.
var start_bins: int = 0
## Registers a new game starts with (0 only in tests: then customers pay as
## they finish eating, with no cashier).
var start_registers: int = 0
## Seconds at a register at cashier speed 1.0: everyone, and starred customers.
var pay_seconds: float = 1.0
var star_pay_seconds: float = 2.0
## The second starting Synth, working the register ("" = none).
var starter_cashier_species: String = ""
var starter_cashier_name: String = "Tally"
## The third starting Synth, at the stove ("" = none): a stove needs its Chef.
var starter_chef_species: String = ""
var starter_chef_name: String = "Byte"
## The café floor at the start: start_floor_width tiles across, start_floor_rows
## deep (the floor upgrade makes it bigger). Seats, stoves and décor stand on it.
var start_floor_width: int = 6
var start_floor_rows: int = 6
## Where a new game's furniture stands: [{"piece": id, "cell": [x, y], "rotated": bool}].
## Empty, or a piece that does not fit there: the first free spot instead.
var start_layout: Array = []
## Décor reaches seats within this many tiles (counted like a king's move).
var decor_range: int = 2
## Vibe (décor) at a customer's seat: waiting there loses satisfaction / (1 + vibe * vibe_decay_per_point);
## every served dish adds vibe * vibe_meal_bonus satisfaction, at most vibe_meal_bonus_max.
var vibe_decay_per_point: float = 0.01
var vibe_meal_bonus: float = 0.1
var vibe_meal_bonus_max: float = 10.0
## Share of a décor piece's price returned when it is sold.
var sell_refund: float = 0.5
## Extra HP each home defender gets from security décor.
var start_security: float = 0.0
var start_district: String = "alley"
var starter_species: String = "steady_unit"
var starter_name: String = "Proto"
var brew_coin_cost: int = 30
var brew_core_cost: int = 1
## Coins per point of Power.
var power_price: int = 2
## Power per battery point recharged, times the species' recharge_multiplier.
var power_per_battery: float = 0.2
var conversion_suspicion: float = 8.0
## Day the Auto button unlocks (after two full days).
var auto_unlock_day: int = 3
## Share of max battery a new Synth loses in the Sync Pod (it starts Resting).
var conversion_battery_loss: float = 0.3
var raid_suspicion: float = 12.0
## Suspicion each district loses every night.
var suspicion_decay: float = 5.0
var raid_squad_max: int = 4
## Rival guards (not flagships) grow stronger every day the district has been open:
## power/hp * (1 + rival_growth_per_day * days since the district opened).
var rival_growth_per_day: float = 0.0
## Battery each raider spends, win or lose.
var raid_battery_cost: float = 25.0
## A raided rival can be raided again this many days later.
var raid_cooldown_days: int = 2
## A battle still going after this many rounds is won by the defenders.
var battle_max_rounds: int = 30
## Each hit deals power * a random factor in [1 - variance, 1 + variance].
var battle_damage_variance: float = 0.2
## Chance of a MegaBean raid on your café each night: base + suspicion * per, capped.
var defense_base_chance: float = 0.1
var defense_chance_per_suspicion: float = 0.006
var defense_max_chance: float = 0.8
## MegaBean squad size: 1 + one per defense_size_step suspicion, capped.
var defense_size_step: float = 30.0
var defense_max_size: int = 4
## Each MegaBean raider: power/hp = base + per_day * day.
var defense_power_base: float = 6.0
var defense_power_per_day: float = 0.5
var defense_hp_base: float = 25.0
var defense_hp_per_day: float = 2.0
## Losing a defense costs this share of coins and this many Nano Cores.
var defense_coin_loss: float = 0.25
var defense_core_loss: int = 1
## At night with Suspicion at or above this, a Corporate Audit replaces the
## random MegaBean raid: always comes, audit_size raiders, each audit_strength
## times a normal raider. Losing it costs audit_coin_loss of the coins and one
## Synth (never the last), and closes the café for the next shift. Win or
## lose, Suspicion falls to audit_reset_suspicion.
var audit_suspicion: float = 90.0
var audit_size: int = 4
var audit_strength: float = 1.5
var audit_coin_loss: float = 0.3
var audit_reset_suspicion: float = 40.0
## Coins a Synth with steal_chance pockets when the roll hits (once a night).
var steal_coins: int = 10
## Synth XP: a server per dish delivered; per batch cooked and per customer
## arriving, shared by the chefs / greeters working that second; per raid
## (won or lost) for each raider; per raid on the café for each home defender.
var xp_per_delivery: int = 2
var xp_per_batch: int = 6
var xp_per_arrival: int = 1
var xp_raid_win: int = 30
var xp_raid_loss: int = 15
var xp_defense: int = 20
## XP from level n to n + 1 = xp_per_level * n. Levels 1..max_synth_level.
var xp_per_level: int = 100
var max_synth_level: int = 10
## Each level above 1 adds this share of the species' base to LEVELED_STATS.
var stat_growth_per_level: float = 0.08


## Unknown keys are reported, missing keys keep their defaults.
static func from_dict(values: Dictionary) -> BalanceConfig:
	var config := BalanceConfig.new()
	for key: String in values:
		if key in config:
			# JSON numbers are floats; keep each field's own type.
			config.set(key, type_convert(values[key], typeof(config.get(key))))
		else:
			push_error("BalanceConfig: unknown key '%s'" % key)
	return config
