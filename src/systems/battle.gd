class_name Battle
extends RefCounted
## Auto-battle on a grid for Night Ops, auto-chess style. Attackers start on
## the bottom half of the board, defenders on the top half (each in its formation
## spot, or placed by class: tanks and fighters in front, fragile units behind
## them, ranged at the back). Then, every tick, each standing unit:
##   - picks a target: the nearest enemy (a fragile unit: the weakest) and keeps
##     it until it falls;
##   - casts its skill when its mana is full (mana comes from attacking and
##     being hit; see CombatConfig);
##   - attacks when the target is in range and its attack is ready, or walks
##     one tile toward it (round other units).
## Damage is power x a random factor, less the target's armor; a shield takes it
## first. The fight ends when a side is down, or after max_seconds (defenders win).
##
## The report keeps every event with its time, so the view can play the fight
## back (and, later, drive models and animations: see BattlePlayback).


class Fighter:
	extends RefCounted
	## Synth id for the player's side; "" for MegaBean fighters.
	var synth_id: String = ""
	var class_id: String = CombatConfig.FIGHTER
	## "" = no skill.
	var skill_id: String = ""
	var power: float = 0.0
	## HP at the end of the battle (max_hp at the start).
	var hp: float = 1.0
	var max_hp: float = 1.0
	## Before the battle: the formation spot (column, row from the front), or
	## (-1, -1) to be placed by class. After: the board cell it started on.
	var cell: Vector2i = Vector2i(-1, -1)
	## Mana its skill needs (0 = no skill); set by Battle.run.
	var max_mana: float = 0.0

	static func make(synth_id: String, power: float, hp: float, class_id := CombatConfig.FIGHTER,
			skill_id := "") -> Fighter:
		var fighter := Fighter.new()
		fighter.synth_id = synth_id
		fighter.power = power
		fighter.hp = maxf(hp, 1.0)
		fighter.max_hp = fighter.hp
		fighter.class_id = class_id
		fighter.skill_id = skill_id
		return fighter


## Something that happened at a moment of the battle.
class Event:
	extends RefCounted
	const MOVE: String = "move"
	const ATTACK: String = "attack"
	const HIT: String = "hit"
	const CAST: String = "cast"
	const HEAL: String = "heal"
	const SHIELD: String = "shield"
	const STUN: String = "stun"
	const DOWN: String = "down"

	var time: float = 0.0
	var kind: String = ""
	## The unit it happened to (true = attackers' side) and its index in the report.
	var side: bool = true
	var index: int = 0
	## The other unit involved (an attack's target; a hit's attacker), -1 = none.
	var other_side: bool = true
	var other_index: int = -1
	## A move: from and to (board cells).
	var from: Vector2i = Vector2i.ZERO
	var to: Vector2i = Vector2i.ZERO
	## Damage, healing or shield; for a move or stun, its length in seconds.
	var amount: float = 0.0
	## A hit: damage the shield took instead.
	var absorbed: float = 0.0
	## The unit's mana right after (attacks, casts, hits).
	var mana: float = 0.0
	## The skill cast (CAST).
	var skill: String = ""


class Report:
	extends RefCounted
	var attackers: Array[Fighter] = []
	var defenders: Array[Fighter] = []
	var events: Array[Event] = []
	## Seconds the battle lasted.
	var duration: float = 0.0
	var board: Vector2i = Vector2i(8, 6)
	var attackers_won: bool = false

	## The fighter on a side at an index.
	func fighter(side: bool, index: int) -> Fighter:
		return attackers[index] if side else defenders[index]


## A fighter while the battle runs.
class Unit:
	extends RefCounted
	var fighter: Fighter
	var side: bool = true
	var index: int = 0
	var cell: Vector2i = Vector2i.ZERO
	var mana: float = 0.0
	var target: Unit = null
	var ready_at: float = 0.0
	var busy_until: float = 0.0
	var stunned_until: float = 0.0
	var shield: float = 0.0
	var haste: float = 1.0
	var haste_until: float = 0.0

	func alive() -> bool:
		return fighter.hp > 0.0


const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
## Columns filled first when placing by class: from the middle out.
const COLUMN_ORDER: Array[int] = [3, 4, 2, 5, 1, 6, 0, 7]


static func run(attackers: Array[Fighter], defenders: Array[Fighter], rng: RandomNumberGenerator,
		data: GameData) -> Report:
	var combat := data.combat
	var report := Report.new()
	report.attackers = attackers
	report.defenders = defenders
	report.board = combat.board
	var units: Array[Unit] = []
	for side: bool in [true, false]:
		var fighters := attackers if side else defenders
		_place(fighters, side, combat)
		for i: int in fighters.size():
			var unit := Unit.new()
			unit.fighter = fighters[i]
			unit.side = side
			unit.index = i
			unit.cell = fighters[i].cell
			fighters[i].max_mana = float(combat.skills.get(fighters[i].skill_id, {}).get("mana", 0.0)) 				if fighters[i].skill_id != "" else 0.0
			units.append(unit)
	var time := 0.0
	while time < combat.max_seconds and _standing(units, true) and _standing(units, false):
		for unit: Unit in units:
			if unit.alive():
				_act(unit, units, time, report, rng, data)
		time += combat.tick_seconds
	report.duration = minf(time, combat.max_seconds)
	report.attackers_won = _standing(units, true) and not _standing(units, false)
	return report


## Board cells for one side: each fighter's formation spot (column, row from
## the front), or by class where it has none or the spot is taken.
static func _place(fighters: Array[Fighter], attackers: bool, combat: CombatConfig) -> void:
	var taken: Dictionary[Vector2i, bool] = {}
	var waiting: Array[Fighter] = []
	for fighter: Fighter in fighters:
		var spot := fighter.cell
		if spot.x >= 0 and spot.y >= 0 and spot.x < combat.board.x and spot.y < combat.half() \
				and not taken.has(spot):
			taken[spot] = true
			fighter.cell = _board_cell(spot, attackers, combat)
		else:
			waiting.append(fighter)
	for fighter: Fighter in waiting:
		var row := {CombatConfig.TANK: 0, CombatConfig.FIGHTER: 0, CombatConfig.FRAGILE: 1, CombatConfig.RANGED: 2} \
			.get(fighter.class_id, 0) as int
		var spot := Vector2i(-1, -1)
		for offset: int in combat.half():
			var try_row := clampi(row + offset if row + offset < combat.half() else row - offset, 0, combat.half() - 1)
			for column: int in COLUMN_ORDER:
				if column < combat.board.x and not taken.has(Vector2i(column, try_row)):
					spot = Vector2i(column, try_row)
					break
			if spot.x >= 0:
				break
		if spot.x < 0:
			continue  # no room (more fighters than half a board)
		taken[spot] = true
		fighter.cell = _board_cell(spot, attackers, combat)


## Where each fighter would stand on its side (column, row from the front):
## its own spot, or one by its class. For showing the formation.
static func formation_spots(fighters: Array[Fighter], combat: CombatConfig) -> Array[Vector2i]:
	_place(fighters, true, combat)
	var spots: Array[Vector2i] = []
	for fighter: Fighter in fighters:
		spots.append(Vector2i(fighter.cell.x, fighter.cell.y - combat.half()) if fighter.cell.x >= 0 else Vector2i(-1, -1))
	return spots


## A formation spot (row 0 = front) as a board cell: attackers on the bottom
## half, defenders on the top half, both facing the middle.
static func _board_cell(spot: Vector2i, attackers: bool, combat: CombatConfig) -> Vector2i:
	return Vector2i(spot.x, combat.half() + spot.y) if attackers else Vector2i(spot.x, combat.half() - 1 - spot.y)


static func _act(unit: Unit, units: Array[Unit], time: float, report: Report, rng: RandomNumberGenerator,
		data: GameData) -> void:
	var combat := data.combat
	if time < unit.busy_until or time < unit.stunned_until:
		return
	if unit.target == null or not unit.target.alive():
		unit.target = _pick_target(unit, units)
		if unit.target == null:
			return
	var skill: Dictionary = combat.skills.get(unit.fighter.skill_id, {})
	if not skill.is_empty() and unit.mana >= float(skill.get("mana", 100)):
		_cast(unit, skill, units, time, report, rng, data)
		unit.ready_at = time + _interval(unit, time, combat)
		return
	if _distance(unit.cell, unit.target.cell) <= int(combat.value(unit.fighter.class_id, "range")):
		if time >= unit.ready_at:
			_attack(unit, time, report, rng, data)
			unit.ready_at = time + _interval(unit, time, combat)
		return
	var step := _step_toward(unit, units, combat)
	if step == unit.cell:
		return  # boxed in: wait
	var event := _event(Event.MOVE, unit, time)
	event.from = unit.cell
	event.to = step
	event.amount = 1.0 / maxf(combat.value(unit.fighter.class_id, "move_speed"), 0.1)
	report.events.append(event)
	unit.cell = step
	unit.busy_until = time + event.amount


static func _interval(unit: Unit, time: float, combat: CombatConfig) -> float:
	var haste := unit.haste if time < unit.haste_until else 1.0
	return combat.value(unit.fighter.class_id, "attack_interval") / maxf(haste, 0.1)


## The nearest standing enemy (ties: the lowest index); a fragile unit picks the
## one with the least HP instead.
static func _pick_target(unit: Unit, units: Array[Unit]) -> Unit:
	var best: Unit = null
	for other: Unit in units:
		if other.side == unit.side or not other.alive():
			continue
		if best == null:
			best = other
		elif unit.fighter.class_id == CombatConfig.FRAGILE:
			if other.fighter.hp < best.fighter.hp:
				best = other
		elif _distance(unit.cell, other.cell) < _distance(unit.cell, best.cell):
			best = other
	return best


static func _attack(unit: Unit, time: float, report: Report, rng: RandomNumberGenerator, data: GameData) -> void:
	var combat := data.combat
	unit.mana += combat.mana_per_attack
	var event := _event(Event.ATTACK, unit, time)
	event.other_side = unit.target.side
	event.other_index = unit.target.index
	report.events.append(event)
	_damage(unit, unit.target, unit.fighter.power, time, report, rng, data)


## Deals power (x a random factor, less armor; a shield takes it first) to target.
static func _damage(from: Unit, target: Unit, power: float, time: float, report: Report, rng: RandomNumberGenerator,
		data: GameData) -> void:
	var variance := data.balance.battle_damage_variance
	var amount := power * rng.randf_range(1.0 - variance, 1.0 + variance) \
		* (1.0 - clampf(data.combat.value(target.fighter.class_id, "armor"), 0.0, 0.9))
	var absorbed := minf(target.shield, amount)
	target.shield -= absorbed
	amount -= absorbed
	target.fighter.hp = maxf(target.fighter.hp - amount, 0.0)
	target.mana += data.combat.mana_per_hit
	var hit := _event(Event.HIT, target, time)
	hit.other_side = from.side
	hit.other_index = from.index
	hit.amount = amount
	hit.absorbed = absorbed
	report.events.append(hit)
	if not target.alive():
		report.events.append(_event(Event.DOWN, target, time))


static func _cast(unit: Unit, skill: Dictionary, units: Array[Unit], time: float, report: Report,
		rng: RandomNumberGenerator, data: GameData) -> void:
	unit.mana = 0.0
	var cast := _event(Event.CAST, unit, time)
	cast.skill = unit.fighter.skill_id
	cast.other_side = unit.target.side
	cast.other_index = unit.target.index
	report.events.append(cast)
	var power := unit.fighter.power * float(skill.get("power", 1.0))
	match unit.fighter.skill_id:
		"slam":
			for other: Unit in units:
				if other.side != unit.side and other.alive() and _distance(unit.cell, other.cell) <= 1:
					_damage(unit, other, power, time, report, rng, data)
					if other.alive():
						other.stunned_until = time + float(skill.get("stun", 1.0))
						var stun := _event(Event.STUN, other, time)
						stun.amount = float(skill.get("stun", 1.0))
						report.events.append(stun)
		"fortify":
			unit.shield += unit.fighter.max_hp * float(skill.get("shield", 0.3))
			var shield := _event(Event.SHIELD, unit, time)
			shield.amount = unit.shield
			report.events.append(shield)
		"overtime":
			unit.haste = float(skill.get("haste", 1.5))
			unit.haste_until = time + float(skill.get("seconds", 4.0))
		"chain":
			var struck: Array[Unit] = [unit.target]
			for jump: int in int(skill.get("jumps", 2)):
				var next: Unit = null
				for other: Unit in units:
					if other.side != unit.side and other.alive() and not struck.has(other) and (next == null
							or _distance(struck[-1].cell, other.cell) < _distance(struck[-1].cell, next.cell)):
						next = other
				if next != null:
					struck.append(next)
			for other: Unit in struck:
				_damage(unit, other, power, time, report, rng, data)
		"cheer":
			var hurt: Unit = null
			for other: Unit in units:
				if other.side == unit.side and other.alive() and (hurt == null
						or other.fighter.hp / other.fighter.max_hp < hurt.fighter.hp / hurt.fighter.max_hp):
					hurt = other
			var healed := minf(hurt.fighter.max_hp * float(skill.get("heal", 0.3)), hurt.fighter.max_hp - hurt.fighter.hp)
			hurt.fighter.hp += healed
			var heal := _event(Event.HEAL, hurt, time)
			heal.other_side = unit.side
			heal.other_index = unit.index
			heal.amount = healed
			report.events.append(heal)
		"beam":
			_damage(unit, unit.target, power, time, report, rng, data)


## The next tile toward a spot in range of the target (8 directions, round
## other units); the unit's own cell if there is no way.
static func _step_toward(unit: Unit, units: Array[Unit], combat: CombatConfig) -> Vector2i:
	var blocked: Dictionary[Vector2i, bool] = {}
	for other: Unit in units:
		if other != unit and other.alive():
			blocked[other.cell] = true
	var reach := int(combat.value(unit.fighter.class_id, "range"))
	# Breadth-first from the unit; remember each tile's first step.
	var first: Dictionary[Vector2i, Vector2i] = {unit.cell: unit.cell}
	var queue: Array[Vector2i] = [unit.cell]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		if at != unit.cell and _distance(at, unit.target.cell) <= reach:
			return first[at]
		for direction: Vector2i in NEIGHBOURS:
			var next := at + direction
			if next.x < 0 or next.y < 0 or next.x >= combat.board.x or next.y >= combat.board.y:
				continue
			if first.has(next) or blocked.has(next):
				continue
			first[next] = next if at == unit.cell else first[at]
			queue.append(next)
	return unit.cell


static func _event(kind: String, unit: Unit, time: float) -> Event:
	var event := Event.new()
	event.kind = kind
	event.time = time
	event.side = unit.side
	event.index = unit.index
	event.mana = unit.mana
	return event


## Tiles between two cells, diagonals counting as one.
static func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _standing(units: Array[Unit], side: bool) -> bool:
	return units.any(func(unit: Unit) -> bool: return unit.side == side and unit.alive())
