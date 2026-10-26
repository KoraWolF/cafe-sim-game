class_name BattleView
extends Control
## Plays one recorded battle as a short scene: the player's side on the left,
## MegaBean's on the right. Each hit is a lunge with a damage number; HP bars
## drain and knocked-out fighters fall. A Victory/Defeat banner ends it.
## Skip jumps to the end, 2x doubles the speed. Placeholder shapes, like the café.

signal finished

const SPACING: float = 140.0
## Every other fighter steps out sideways, so neighbours' labels and HP bars never overlap.
const STAGGER: float = 120.0
const SIDE_OFFSET: float = 380.0
const LUNGE: float = 0.45
const END_PAUSE: float = 0.8

var playback: BattlePlayback = null
## True when the player's fighters are the battle's attackers (a raid).
var player_attacks: bool = true
var _title := UiTheme.label("", 34, UiTheme.PANEL_BORDER)
var _round := UiTheme.label("", 20, UiTheme.TEXT_DIM)
var _fast := UiTheme.button(tr("ui.battle_fast"), func() -> void: _speed = 2.0 if _speed == 1.0 else 1.0)
var _skip := UiTheme.button(tr("ui.battle_skip"), skip)
var _continue := UiTheme.button(tr("ui.battle_continue"), _close)
var _time: float = 0.0
var _speed: float = 1.0
var _names_left: Array[String] = []
var _names_right: Array[String] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(UiTheme.BACKGROUND, 0.985)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.show_behind_parent = true
	add_child(shade)
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-300, 90)
	top.custom_minimum_size = Vector2(600, 0)
	for label: Label in [_title, _round]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top.add_child(label)
	add_child(top)
	var buttons := HBoxContainer.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.position = Vector2(-200, -110)
	buttons.custom_minimum_size = Vector2(400, 50)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_fast.toggle_mode = true
	for button: Button in [_fast, _skip, _continue]:
		button.custom_minimum_size = Vector2(120, 46)
		buttons.add_child(button)
	add_child(buttons)


## Starts a battle. Names label the fighters (same order as the report).
func play(battle: Battle.Report, title: String, attacks: bool, attacker_names: Array[String],
		defender_names: Array[String]) -> void:
	playback = BattlePlayback.new(battle)
	player_attacks = attacks
	_names_left = attacker_names if attacks else defender_names
	_names_right = defender_names if attacks else attacker_names
	_title.text = title
	_time = 0.0
	_speed = 1.0
	_fast.set_pressed_no_signal(false)
	_continue.visible = false
	_skip.visible = true
	_fast.visible = true
	visible = true


func skip() -> void:
	_time = playback.duration() + END_PAUSE
	playback.finish()


## True when the player's side won.
func player_won() -> bool:
	return playback.report.attackers_won == player_attacks


func _process(delta: float) -> void:
	if not visible or playback == null:
		return
	_time += delta * _speed
	# A hit's damage lands halfway through its lunge.
	playback.advance_time(_time + BattlePlayback.HIT_SECONDS * 0.5)
	_round.text = tr("ui.battle_round") % playback.round_at(_time) if not playback.report.hits.is_empty() else ""
	if _time >= playback.duration() + END_PAUSE and not _continue.visible:
		_continue.visible = true
		_skip.visible = false
		_fast.visible = false
		_continue.grab_focus()
	queue_redraw()


func _close() -> void:
	visible = false
	finished.emit()


func _draw() -> void:
	if playback == null:
		return
	var report := playback.report
	var left_fighters := report.attackers if player_attacks else report.defenders
	var right_fighters := report.defenders if player_attacks else report.attackers
	var left_hp := playback.attacker_hp if player_attacks else playback.defender_hp
	var right_hp := playback.defender_hp if player_attacks else playback.attacker_hp
	var lunge := _lunge()
	for i: int in left_fighters.size():
		_draw_fighter(left_fighters[i], left_hp[i], _slot(true, i, left_fighters.size()) + lunge.get(Vector2i(0, i), Vector2.ZERO),
			_names_left[i] if i < _names_left.size() else "", true)
	for i: int in right_fighters.size():
		_draw_fighter(right_fighters[i], right_hp[i], _slot(false, i, right_fighters.size()) + lunge.get(Vector2i(1, i), Vector2.ZERO),
			_names_right[i] if i < _names_right.size() else "", false)
	_draw_damage_number()
	if _time >= playback.duration():
		var won := player_won()
		var text := tr("ui.battle_victory") if won else tr("ui.battle_defeat")
		_centred_text(size * 0.5 + Vector2(0, 10), text, 72, UiTheme.GOOD if won else UiTheme.BAD)


## Feet position of fighter i of n on a side.
func _slot(left: bool, i: int, n: int) -> Vector2:
	var centre := size * 0.5 + Vector2(0, 40)
	var outward := SIDE_OFFSET + (STAGGER if i % 2 == 1 else 0.0)
	return Vector2(centre.x + (-outward if left else outward), centre.y + (i - (n - 1) * 0.5) * SPACING)


## Offset of the fighter lunging now: {Vector2i(side, index): offset}, side 0 = left.
func _lunge() -> Dictionary:
	var now := playback.current(_time)
	if now.is_empty():
		return {}
	var hit: Battle.Hit = now["hit"]
	var attacker_left := hit.attacker_side == player_attacks
	var report := playback.report
	var from := _slot(attacker_left, hit.attacker_index, (report.attackers if hit.attacker_side else report.defenders).size())
	var to := _slot(not attacker_left, hit.target_index, (report.defenders if hit.attacker_side else report.attackers).size())
	var offset := (to - from) * LUNGE * sin(PI * float(now["progress"]))
	return {Vector2i(0 if attacker_left else 1, hit.attacker_index): offset}


## The current hit's damage rising above its target once it has landed.
func _draw_damage_number() -> void:
	var now := playback.current(_time)
	if now.is_empty() or float(now["progress"]) < 0.5:
		return
	var hit: Battle.Hit = now["hit"]
	var target_left := hit.attacker_side != player_attacks
	var report := playback.report
	var at := _slot(target_left, hit.target_index, (report.defenders if hit.attacker_side else report.attackers).size())
	var rise := (float(now["progress"]) - 0.5) * 2.0
	_centred_text(at + Vector2(0, -170 - 40 * rise), "-%d" % roundi(hit.damage), 30, UiTheme.BAD if target_left else UiTheme.WARN)
	if hit.knocked_out:
		_centred_text(at + Vector2(0, -205 - 40 * rise), tr("ui.battle_ko"), 26, UiTheme.ACCENT)


func _draw_fighter(fighter: Battle.Fighter, hp: float, feet: Vector2, label: String, facing_right: bool) -> void:
	var down := hp <= 0.0
	var alpha := 0.35 if down else 1.0
	draw_set_transform(feet, 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 34, Color(0, 0, 0, 0.4 * alpha))
	draw_set_transform(Vector2.ZERO)
	if down:
		# Knocked out: lying on the floor.
		draw_rect(Rect2(feet + Vector2(-34, -16), Vector2(48, 20)), Color(_body_color(fighter), alpha))
		draw_circle(feet + Vector2(26, -8), 18, Color(_head_color(fighter), alpha))
	else:
		var body := _body_color(fighter)
		draw_rect(Rect2(feet + Vector2(-20, -62), Vector2(40, 58)), body)
		draw_rect(Rect2(feet + Vector2(-20, -62), Vector2(40, 58)), body.darkened(0.6), false, 3.0)
		var head := feet + Vector2(0, -88)
		draw_circle(head, 28, _head_color(fighter))
		draw_arc(head, 28, 0, TAU, 32, Color("1a1428"), 3.0)
		if fighter.synth_id != "":
			var glow := _glow(fighter)
			draw_circle(feet + Vector2(0, -40), 46, Color(glow, 0.15))
			draw_rect(Rect2(head + Vector2(-22 if facing_right else -18, -8), Vector2(40, 14)), glow)
		else:
			# MegaBean staff: a red tie and a coffee-cup cap.
			draw_colored_polygon(PackedVector2Array([feet + Vector2(-5, -60), feet + Vector2(5, -60), feet + Vector2(0, -30)]), UiTheme.BAD)
			draw_rect(Rect2(head + Vector2(-24, -34), Vector2(48, 12)), Color("6b4a2f"))
	var bar := Rect2(feet + Vector2(-50, -138), Vector2(100, 10))
	draw_rect(bar, Color(0, 0, 0, 0.6))
	var share := clampf(hp / fighter.max_hp, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), UiTheme.GOOD if share > 0.5 else (UiTheme.WARN if share > 0.2 else UiTheme.BAD))
	_centred_text(feet + Vector2(0, -146), "%d / %d" % [ceili(hp), roundi(fighter.max_hp)], 14, Color(UiTheme.TEXT, alpha))
	_centred_text(feet + Vector2(0, 26), label, 16, Color(UiTheme.TEXT_DIM, alpha))


func _glow(fighter: Battle.Fighter) -> Color:
	var synth := Session.state.synth_by_id(fighter.synth_id) if Session.has_game() else null
	return UiTheme.SPECIES_GLOW.get(synth.species_id, Color.CYAN) if synth != null else Color.CYAN


func _body_color(fighter: Battle.Fighter) -> Color:
	return Color("9aa3b8") if fighter.synth_id != "" else Color("2b2d3a")


func _head_color(fighter: Battle.Fighter) -> Color:
	return Color("ffd9b8")


func _centred_text(centre: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(font, centre - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color.BLACK)
	draw_string(font, centre - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
