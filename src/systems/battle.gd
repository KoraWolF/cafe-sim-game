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
## A raid is fought inside the rival café, a MegaBean raid inside the player's
## (see Field and RaidField): its furniture blocks walking and gives cover from
## ranged attacks. Such a café has a front wall with one door: the defenders
## wait inside (tanks nearest the door, then fighters, fragile, ranged), the
## attackers start on the street and walk in through the door, and nobody
## fights until the first attacker is in the doorway. An attacker still outside
## keeps walking in (it fights back only at a defender who came out to it).
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


## Where a battle is fought: the board, the first attackers' row (defenders
## hold the rows above it) and the furniture standing on it (it blocks walking;
## a unit next to it takes less from ranged attacks). A café (see RaidField) also
## has a front wall in the last defenders' row with one door in it; other
## battles are fought on a bare board.
class Field:
	extends RefCounted
	var board: Vector2i = Vector2i(8, 6)
	var split: int = 3
	var obstacles: Dictionary[Vector2i, bool] = {}
	## For drawing: {"piece_id", "cell": Vector2i, "rotated": bool}.
	var pieces: Array[Dictionary] = []
	## The front wall's cells (they block walking but give no cover) and its door;
	## (-1, -1) = no wall.
	var walls: Dictionary[Vector2i, bool] = {}
	var door: Vector2i = Vector2i(-1, -1)

	## A front wall across the row just before the attackers', with the door in door_column.
	func wall_off(door_column: int) -> void:
		door = Vector2i(door_column, split - 1)
		for x: int in board.x:
			if x != door_column:
				walls[Vector2i(x, split - 1)] = true

	## Whether a cell is out on the street, beyond the door.
	func outside(cell: Vector2i) -> bool:
		return door.x >= 0 and cell.y > door.y

	static func bare(combat: CombatConfig) -> Field:
		var field := Field.new()
		field.board = combat.board
		field.split = combat.half()
		return field

	## Rows a side holds.
	func rows(attackers: bool) -> int:
		return board.y - split if attackers else split

	func open(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.y >= 0 and cell.x < board.x and cell.y < board.y and not obstacles.has(cell) \
			and not walls.has(cell)


class Report:
	extends RefCounted
	var attackers: Array[Fighter] = []
	var defenders: Array[Fighter] = []
	var events: Array[Event] = []
	## Seconds the battle lasted.
	var duration: float = 0.0
	var board: Vector2i = Vector2i(8, 6)
	var field: Field = null
	var attackers_won: bool = false
	## When the fight began: 0, or when the first attacker reached the door.
	var engaged_at: float = 0.0

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


static func run(attackers: Array[Fighter], defenders: Array[Fighter], rng: RandomNumberGenerator,
		data: GameData, field: Field = null) -> Report:
	var combat := data.combat
	var report := setup(attackers, defenders, data, field)
	var units: Array[Unit] = []
	for side: bool in [true, false]:
		var fighters := attackers if side else defenders
		for i: int in fighters.size():
			var unit := Unit.new()
			unit.fighter = fighters[i]
			unit.side = side
			unit.index = i
			unit.cell = fighters[i].cell
			fighters[i].max_mana = float(combat.skills.get(fighters[i].skill_id, {}).get("mana", 0.0)) 				if fighters[i].skill_id != "" else 0.0
			units.append(unit)
	var time := 0.0
	var engaged := report.field.door.x < 0
	# The clock runs from the first step through the door (from the start if nobody gets in).
	while time - report.engaged_at < combat.max_seconds and _standing(units, true) and _standing(units, false):
		if not engaged and units.any(func(unit: Unit) -> bool: return unit.side and not report.field.outside(unit.cell)):
			engaged = true
			report.engaged_at = time
		for unit: Unit in units:
			if unit.alive() and (engaged or unit.side):
				_act(unit, units, time, report, rng, data)
		time += combat.tick_seconds
	report.duration = minf(time, report.engaged_at + combat.max_seconds)
	report.attackers_won = _standing(units, true) and not _standing(units, false)
	return report


## Everyone on their starting cell, no fight yet (for the formation screen).
static func setup(attackers: Array[Fighter], defenders: Array[Fighter], data: GameData, field: Field = null) -> Report:
	var report := Report.new()
	report.attackers = attackers
	report.defenders = defenders
	report.field = field if field != null else Field.bare(data.combat)
	report.board = report.field.board
	_place(attackers, true, report.field)
	_place(defenders, false, report.field)
	return report


## Board cells for one side: each fighter's formation spot (column, row from
## the front), or by class where it has none or the spot is taken: tanks and
## fighters in front, fragile behind them, ranged at the back; never on furniture.
static func _place(fighters: Array[Fighter], attackers: bool, field: Field) -> void:
	if not attackers and field.door.x >= 0:
		_place_inside(fighters, field)
		return
	var taken: Dictionary[Vector2i, bool] = {}
	var waiting: Array[Fighter] = []
	var rows := field.rows(attackers)
	for fighter: Fighter in fighters:
		var spot := fighter.cell
		var cell := _board_cell(spot, attackers, field)
		if spot.x >= 0 and spot.y >= 0 and spot.y < rows and field.open(cell) and not taken.has(cell):
			taken[cell] = true
			fighter.cell = cell
		else:
			waiting.append(fighter)
	var columns: Array[int] = []
	for offset: int in field.board.x:
		var column := (field.board.x - 1) / 2 + (offset + 1) / 2 * (1 if offset % 2 == 1 else -1)
		if column >= 0 and column < field.board.x:
			columns.append(column)
	for fighter: Fighter in waiting:
		var row := mini({CombatConfig.TANK: 0, CombatConfig.FIGHTER: 0, CombatConfig.FRAGILE: 1, CombatConfig.RANGED: 2} \
			.get(fighter.class_id, 0) as int, rows - 1)
		fighter.cell = Vector2i(-1, -1)
		for offset: int in rows:
			var try_row := clampi(row + offset if row + offset < rows else row - offset, 0, rows - 1)
			for column: int in columns:
				var cell := _board_cell(Vector2i(column, try_row), attackers, field)
				if field.open(cell) and not taken.has(cell):
					fighter.cell = cell
					break
			if fighter.cell.x >= 0:
				break
		if fighter.cell.x >= 0:
			taken[fighter.cell] = true


## Defenders of a café with a door: by class (tanks, fighters, fragile, ranged),
## each on the free tile nearest the door (walking), never in the doorway.
static func _place_inside(fighters: Array[Fighter], field: Field) -> void:
	var tiles: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {field.door: true}
	var queue: Array[Vector2i] = [field.door]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		for direction: Vector2i in NEIGHBOURS:
			var next := at + direction
			if next.y < field.door.y and field.open(next) and not seen.has(next):
				seen[next] = true
				tiles.append(next)
				queue.append(next)
	# Tiles the door doesn't reach come last.
	for y: int in field.door.y:
		for x: int in field.board.x:
			if field.open(Vector2i(x, y)) and not seen.has(Vector2i(x, y)):
				tiles.append(Vector2i(x, y))
	var rank := {CombatConfig.TANK: 0, CombatConfig.FIGHTER: 1, CombatConfig.FRAGILE: 2, CombatConfig.RANGED: 3}
	var order: Array[Fighter] = fighters.duplicate()
	order.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		var ra: int = rank.get(a.class_id, 1)
		var rb: int = rank.get(b.class_id, 1)
		return ra < rb or (ra == rb and fighters.find(a) < fighters.find(b)))
	for i: int in order.size():
		order[i].cell = tiles[i] if i < tiles.size() else Vector2i(-1, -1)


## Where each fighter would stand on its side (column, row from the front):
## its own spot, or one by its class. For showing the formation.
static func formation_spots(fighters: Array[Fighter], combat: CombatConfig) -> Array[Vector2i]:
	var field := Field.bare(combat)
	_place(fighters, true, field)
	var spots: Array[Vector2i] = []
	for fighter: Fighter in fighters:
		spots.append(Vector2i(fighter.cell.x, fighter.cell.y - field.split) if fighter.cell.x >= 0 else Vector2i(-1, -1))
	return spots


## A formation spot (row 0 = front) as a board cell: attackers below the
## split, defenders above it, both facing it.
static func _board_cell(spot: Vector2i, attackers: bool, field: Field) -> Vector2i:
	return Vector2i(spot.x, field.split + spot.y) if attackers else Vector2i(spot.x, field.split - 1 - spot.y)


static func _act(unit: Unit, units: Array[Unit], time: float, report: Report, rng: RandomNumberGenerator,
		data: GameData) -> void:
	var combat := data.combat
	if time < unit.busy_until or time < unit.stunned_until:
		return
	if unit.side and report.field.outside(unit.cell):
		# On the street: walk in, unless a defender came out to the door or beyond and is in reach.
		var near := _pick_target(unit, units)
		var reach := int(combat.value(unit.fighter.class_id, "range"))
		if near == null or near.cell.y < report.field.door.y or _distance(unit.cell, near.cell) > reach:
			unit.target = null
			_move(unit, _step_in(unit, units, report.field), time, report, combat)
			return
		unit.target = near
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
	_move(unit, _step_toward(unit, units, combat, report.field), time, report, combat)


## One step to a neighbouring tile; none if it is the unit's own (boxed in: it waits).
static func _move(unit: Unit, step: Vector2i, time: float, report: Report, combat: CombatConfig) -> void:
	if step == unit.cell:
		return
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
	# Cover: furniture next to the target takes some of a shot from afar.
	if _distance(from.cell, target.cell) > 1 and _beside_furniture(target.cell, report.field):
		amount *= 1.0 - clampf(data.combat.cover, 0.0, 0.9)
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
static func _step_toward(unit: Unit, units: Array[Unit], combat: CombatConfig, field: Field) -> Vector2i:
	var reach := int(combat.value(unit.fighter.class_id, "range"))
	return _first_step(unit, units, field, func(at: Vector2i) -> bool: return _distance(at, unit.target.cell) <= reach)


## The next tile toward the door and through it; the unit's own cell if the way is blocked.
static func _step_in(unit: Unit, units: Array[Unit], field: Field) -> Vector2i:
	return _first_step(unit, units, field, func(at: Vector2i) -> bool: return not field.outside(at))


## The first step of the shortest walk (8 directions, round furniture, walls and
## other units) to a tile where arrived is true; the unit's own cell if there is none.
static func _first_step(unit: Unit, units: Array[Unit], field: Field, arrived: Callable) -> Vector2i:
	var blocked: Dictionary[Vector2i, bool] = field.obstacles.duplicate()
	blocked.merge(field.walls)
	for other: Unit in units:
		if other != unit and other.alive():
			blocked[other.cell] = true
	# Breadth-first from the unit; remember each tile's first step.
	var first: Dictionary[Vector2i, Vector2i] = {unit.cell: unit.cell}
	var queue: Array[Vector2i] = [unit.cell]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_front()
		if at != unit.cell and arrived.call(at):
			return first[at]
		for direction: Vector2i in NEIGHBOURS:
			var next := at + direction
			if next.x < 0 or next.y < 0 or next.x >= field.board.x or next.y >= field.board.y:
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


static func _beside_furniture(cell: Vector2i, field: Field) -> bool:
	for direction: Vector2i in NEIGHBOURS:
		if field.obstacles.has(cell + direction):
			return true
	return false


## Tiles between two cells, diagonals counting as one.
static func _distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


static func _standing(units: Array[Unit], side: bool) -> bool:
	return units.any(func(unit: Unit) -> bool: return unit.side == side and unit.alive())
