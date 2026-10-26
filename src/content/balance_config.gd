class_name BalanceConfig
extends RefCounted
## Tunable numbers from /data/balance.json. Times are in game seconds
## (1 game second = 1 real second at 1x speed).

## Length of one café shift.
var shift_seconds: int = 480
## The first customer arrives this long after the shift opens.
var first_arrival_seconds: int = 3
## Gap between arrivals, before greeters shorten it (gap / (1 + total appeal)).
var arrival_min_seconds: int = 10
var arrival_max_seconds: int = 18
## No new customers in the last part of the shift.
var spawn_stop_before_end: int = 45
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
## they tip, and can be converted for star_window_seconds.
var star_threshold: float = 80.0
var star_window_seconds: int = 20
## Seconds a speed 1.0 server needs to carry a dish to a table.
var delivery_seconds: int = 6
var eat_seconds: int = 15
## Tip = price * tip_rate * type tip * (1 + server tip bonus), only for starred customers.
var tip_rate: float = 0.25
## Pay = price * (min_pay_share + (1 - min_pay_share) * satisfaction / 100).
var min_pay_share: float = 0.5
## Below this share of max battery a Synth works at low_battery_factor speed.
var low_battery_share: float = 0.2
var low_battery_factor: float = 0.5
## Share of the shift after which late_shift_slowdown applies.
var late_shift_start: float = 0.7
var start_coins: int = 200
var start_nanobrew: int = 1
var start_cores: int = 0
var start_power: float = 50.0
var start_seats: int = 4
var start_stoves: int = 2
var start_pods: int = 2
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
var raid_suspicion: float = 12.0
## Suspicion each district loses every night.
var suspicion_decay: float = 5.0
var raid_squad_max: int = 4
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
## Coins a Synth with steal_chance pockets when the roll hits (once a night).
var steal_coins: int = 10


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
