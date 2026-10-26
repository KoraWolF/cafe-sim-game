class_name Battle
extends RefCounted
## Auto-battle for Night Ops. Each round every standing fighter, attackers
## first, hits a random standing enemy for power * a random factor. The report
## keeps every hit so the UI can play the fight back. A fight still going after
## battle_max_rounds is won by the defenders.


class Fighter:
	extends RefCounted
	## Synth id for the player's side; "" for MegaBean fighters.
	var synth_id: String = ""
	var power: float = 0.0
	var hp: float = 1.0
	var max_hp: float = 1.0

	static func make(synth_id: String, power: float, hp: float) -> Fighter:
		var fighter := Fighter.new()
		fighter.synth_id = synth_id
		fighter.power = power
		fighter.hp = maxf(hp, 1.0)
		fighter.max_hp = fighter.hp
		return fighter


class Hit:
	extends RefCounted
	var round_number: int = 0
	var attacker_side: bool = true
	## Index into the report's attackers or defenders.
	var attacker_index: int = 0
	var target_index: int = 0
	var damage: float = 0.0
	var knocked_out: bool = false


class Report:
	extends RefCounted
	var attackers: Array[Fighter] = []
	var defenders: Array[Fighter] = []
	var hits: Array[Hit] = []
	var rounds: int = 0
	var attackers_won: bool = false


static func run(attackers: Array[Fighter], defenders: Array[Fighter], rng: RandomNumberGenerator,
		b: BalanceConfig) -> Report:
	var report := Report.new()
	report.attackers = attackers
	report.defenders = defenders
	while report.rounds < b.battle_max_rounds and _standing(attackers) and _standing(defenders):
		report.rounds += 1
		_side_attacks(report, true, rng, b)
		_side_attacks(report, false, rng, b)
	report.attackers_won = _standing(attackers) and not _standing(defenders)
	return report


static func _side_attacks(report: Report, attacker_side: bool, rng: RandomNumberGenerator, b: BalanceConfig) -> void:
	var own := report.attackers if attacker_side else report.defenders
	var enemies := report.defenders if attacker_side else report.attackers
	for i: int in own.size():
		if own[i].hp <= 0.0:
			continue
		var targets: Array[int] = []
		for j: int in enemies.size():
			if enemies[j].hp > 0.0:
				targets.append(j)
		if targets.is_empty():
			return
		var hit := Hit.new()
		hit.round_number = report.rounds
		hit.attacker_side = attacker_side
		hit.attacker_index = i
		hit.target_index = targets[rng.randi_range(0, targets.size() - 1)]
		hit.damage = own[i].power * rng.randf_range(1.0 - b.battle_damage_variance, 1.0 + b.battle_damage_variance)
		var target := enemies[hit.target_index]
		target.hp = maxf(target.hp - hit.damage, 0.0)
		hit.knocked_out = target.hp <= 0.0
		report.hits.append(hit)


static func _standing(fighters: Array[Fighter]) -> bool:
	return fighters.any(func(fighter: Fighter) -> bool: return fighter.hp > 0.0)
