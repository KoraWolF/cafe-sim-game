class_name BattleView
extends Control
## Plays one recorded grid battle: the board in the café's 3/4 view, the
## player's half nearest the camera. Units walk, attack (melee lunge, ranged
## shot), cast their skill, flash when hit and fall when down; HP, shield and
## mana bars ride above them and damage numbers float up. A Victory/Defeat
## banner ends it. Skip jumps to the end, 2x doubles the speed.
##
## Everything a unit shows comes from BattlePlayback.unit_state() (position,
## animation and its time, facing): _draw_unit is the one place to swap the
## placeholder shapes for sprites or models.

signal finished

## Battle board tile size on screen (a 2:1 diamond, like the café floor).
const TILE: Vector2 = Vector2(136, 68)
const END_PAUSE: float = 0.8
## Seconds a ranged shot flies.
const SHOT_SECONDS: float = 0.25
const CLASS_WIDTH: Dictionary[String, float] = {"tank": 50.0, "fighter": 40.0, "ranged": 34.0, "fragile": 30.0}

var playback: BattlePlayback = null
## True when the player's fighters are the battle's attackers (a raid).
var player_attacks: bool = true
var _title := UiTheme.label("", 34, UiTheme.PANEL_BORDER)
var _clock := UiTheme.label("", 20, UiTheme.TEXT_DIM)
var _fast := UiTheme.button(tr("ui.battle_fast"), func() -> void: _speed = 2.0 if _speed == 1.0 else 1.0)
var _skip := UiTheme.button(tr("ui.battle_skip"), skip)
var _continue := UiTheme.button(tr("ui.battle_continue"), _close)
var _time: float = 0.0
var _speed: float = 1.0
var _names_attackers: Array[String] = []
var _names_defenders: Array[String] = []
var _banner_heard: bool = false


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
	top.position = Vector2(-300, 70)
	top.custom_minimum_size = Vector2(600, 0)
	for label: Label in [_title, _clock]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top.add_child(label)
	add_child(top)
	var buttons := HBoxContainer.new()
	buttons.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.position = Vector2(-200, -80)
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
	_names_attackers = attacker_names
	_names_defenders = defender_names
	_title.text = title
	_time = 0.0
	_speed = 1.0
	_fast.set_pressed_no_signal(false)
	_continue.visible = false
	_skip.visible = true
	_fast.visible = true
	_banner_heard = false
	visible = true
	Sfx.music("battle")
	if title == tr("ui.battle_audit"):
		Sfx.play("alarm")


func skip() -> void:
	_time = playback.duration() + END_PAUSE


## True when the player's side won.
func player_won() -> bool:
	return playback.report.attackers_won == player_attacks


func _process(delta: float) -> void:
	if not visible or playback == null:
		return
	var before := _time
	_time += delta * _speed
	if _time < playback.duration():
		for event: Battle.Event in playback.events_between(before, _time):
			match event.kind:
				Battle.Event.HIT:
					Sfx.play("hit")
				Battle.Event.DOWN:
					Sfx.play("ko")
				Battle.Event.CAST:
					Sfx.play("star")
	if _time >= playback.duration() and not _banner_heard:
		_banner_heard = true
		Sfx.play("victory" if player_won() else "defeat")
	_clock.text = tr("ui.battle_clock") % minf(_time, playback.duration())
	if _time >= playback.duration() + END_PAUSE and not _continue.visible:
		_continue.visible = true
		_skip.visible = false
		_fast.visible = false
		_continue.grab_focus()
	queue_redraw()


func _close() -> void:
	visible = false
	finished.emit()


## Screen point of a board position (cells; the centre of cell c is c + 0.5).
## The player's half is always the one nearest the camera.
func _screen(cell_pos: Vector2) -> Vector2:
	var board := Vector2(playback.report.board)
	var p := cell_pos + Vector2(0.5, 0.5)
	if not player_attacks:
		p = board - p  # turn the board round: the player defends from the near side
	var centre := board * 0.5
	var flat := Vector2((p.x - p.y) - (centre.x - centre.y), (p.x + p.y) - (centre.x + centre.y))
	return size * 0.5 + Vector2(0, 50) + Vector2(flat.x * TILE.x * 0.5, flat.y * TILE.y * 0.5)


func _draw() -> void:
	if playback == null:
		return
	var report := playback.report
	var time := minf(_time, report.duration)
	_draw_board(report)
	# Units, far to near.
	var units: Array[Array] = []
	for side: bool in [true, false]:
		var count := report.attackers.size() if side else report.defenders.size()
		for i: int in count:
			var state := playback.unit_state(side, i, time)
			units.append([side, i, state, _screen(state["pos"]).y])
	units.sort_custom(func(a: Array, b: Array) -> bool: return a[3] < b[3])
	for entry: Array in units:
		_draw_unit(entry[0], entry[1], entry[2])
	_draw_shots(time)
	_draw_numbers(time)
	if _time >= report.duration:
		var won := player_won()
		_centred_text(size * 0.5 + Vector2(0, -10), tr("ui.battle_victory") if won else tr("ui.battle_defeat"), 72,
			UiTheme.GOOD if won else UiTheme.BAD)


func _draw_board(report: Battle.Report) -> void:
	var half := report.board.y / 2
	for y: int in report.board.y:
		for x: int in report.board.x:
			var corners := PackedVector2Array()
			for corner: Vector2 in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
				corners.append(_screen(Vector2(x, y) + corner))
			var players := (y >= half) == player_attacks
			var tint := UiTheme.PANEL_BORDER if players else UiTheme.BAD
			draw_colored_polygon(corners, Color(tint, 0.10 if (x + y) % 2 == 0 else 0.16))
			corners.append(corners[0])
			draw_polyline(corners, Color(tint, 0.35), 1.5)


## One unit, from its state. Swap this for a sprite or model later: the state
## has its position, animation ("idle", "move", "attack", "cast", "hurt",
## "down") with the time into it, facing, HP, shield, mana and stun.
func _draw_unit(side: bool, index: int, state: Dictionary) -> void:
	var fighter := playback.report.fighter(side, index)
	var feet := _screen(state["pos"])
	var anim: String = state["anim"]
	var t: float = state["anim_time"]
	var mine := fighter.synth_id != ""
	var width: float = CLASS_WIDTH.get(fighter.class_id, 40.0)
	var facing := _screen(Vector2(state["pos"]) + Vector2(state["facing"])) - feet
	if anim == "attack" and fighter.class_id != CombatConfig.RANGED:
		feet += facing.normalized() * 22.0 * sin(PI * t / BattlePlayback.ANIM_SECONDS["attack"])
	elif anim == "move":
		feet.y -= absf(sin(t * 12.0)) * 4.0
	var down := anim == "down"
	var alpha := 0.35 if down else 1.0
	draw_set_transform(feet, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, width * 0.8, Color(0, 0, 0, 0.4 * alpha))
	draw_set_transform(Vector2.ZERO)
	var body := Color("9aa3b8") if mine else Color("2b2d3a")
	if down:
		draw_rect(Rect2(feet + Vector2(-width * 0.8, -14), Vector2(width * 1.2, 18)), Color(body, alpha))
		draw_circle(feet + Vector2(width * 0.6, -6), 15, Color(Color("ffd9b8"), alpha))
		_centred_text(feet + Vector2(0, 28), _name(side, index), 14, Color(UiTheme.TEXT_DIM, alpha))
		return
	if anim == "cast":
		var glow := _glow(fighter)
		draw_arc(feet + Vector2(0, -40), 30.0 + 50.0 * t, 0, TAU, 40, Color(glow, 1.0 - t / 0.6), 4.0)
	var height := 52.0 if fighter.class_id != CombatConfig.TANK else 56.0
	var torso := Rect2(feet + Vector2(-width * 0.5, -height), Vector2(width, height - 4))
	draw_rect(torso, body)
	draw_rect(torso, body.darkened(0.6), false, 3.0)
	var head := feet + Vector2(0, -height - 22)
	draw_circle(head, 22, Color("ffd9b8"))
	draw_arc(head, 22, 0, TAU, 28, Color("1a1428"), 3.0)
	if mine:
		var glow := _glow(fighter)
		draw_rect(Rect2(head + Vector2(-18, -6), Vector2(36, 11)), glow)
	else:
		draw_colored_polygon(PackedVector2Array([feet + Vector2(-5, -height + 2), feet + Vector2(5, -height + 2),
			feet + Vector2(0, -height + 26)]), UiTheme.BAD)
		draw_rect(Rect2(head + Vector2(-20, -28), Vector2(40, 10)), Color("6b4a2f"))
	# The class at a glance: a shield, a blade, a blaster, a dagger.
	var hand := feet + Vector2(width * 0.5 + 6, -height * 0.55)
	match fighter.class_id:
		CombatConfig.TANK:
			draw_rect(Rect2(feet + Vector2(-width * 0.5 - 16, -height * 0.8), Vector2(12, height * 0.6)), Color("6a7894"))
		CombatConfig.FIGHTER:
			draw_line(hand, hand + Vector2(4, -28), Color("d8dde8"), 4.0)
		CombatConfig.RANGED:
			draw_rect(Rect2(hand + Vector2(-2, -6), Vector2(18, 10)), Color("4fb3ff"))
		CombatConfig.FRAGILE:
			draw_line(hand, hand + Vector2(10, -14), Color("ff8a3d"), 3.0)
	if anim == "hurt":
		draw_rect(torso, Color(1, 1, 1, 0.55 * (1.0 - t / BattlePlayback.ANIM_SECONDS["hurt"])))
	if state["stunned"]:
		_centred_text(head + Vector2(0, -30), "✦ ✦", 16, UiTheme.WARN)
	# Bars: HP (with shield), then mana.
	var bar := Rect2(feet + Vector2(-34, -height - 64), Vector2(68, 8))
	draw_rect(bar, Color(0, 0, 0, 0.6))
	var share := clampf(float(state["hp"]) / fighter.max_hp, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)),
		UiTheme.GOOD if share > 0.5 else (UiTheme.WARN if share > 0.2 else UiTheme.BAD))
	if float(state["shield"]) > 0.0:
		var shield_share := clampf(float(state["shield"]) / fighter.max_hp, 0.0, 1.0)
		draw_rect(Rect2(bar.position + Vector2(0, -4), Vector2(bar.size.x * shield_share, 3)), Color("cfe8ff"))
	if float(state["max_mana"]) > 0.0:
		var mana := Rect2(bar.position + Vector2(0, 10), Vector2(68, 4))
		draw_rect(mana, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(mana.position, Vector2(mana.size.x * clampf(float(state["mana"]) / float(state["max_mana"]), 0.0, 1.0),
			mana.size.y)), Color("4f7bff"))
	_centred_text(feet + Vector2(0, 28), _name(side, index), 14, UiTheme.TEXT_DIM)


## Ranged attacks fly as a bolt from shooter to target.
func _draw_shots(time: float) -> void:
	for entry: Array in playback.shots(time, SHOT_SECONDS):
		var event: Battle.Event = entry[0]
		if playback.report.fighter(event.side, event.index).class_id != CombatConfig.RANGED or event.other_index < 0:
			continue
		var from := _screen(playback.unit_position(event.side, event.index, event.time)) + Vector2(0, -40)
		var to := _screen(playback.unit_position(event.other_side, event.other_index, event.time)) + Vector2(0, -40)
		var at := from.lerp(to, float(entry[1]))
		var color := _glow(playback.report.fighter(event.side, event.index))
		draw_line(at - (to - from).normalized() * 16.0, at, Color(color, 0.6), 4.0)
		draw_circle(at, 6.0, color)


func _draw_numbers(time: float) -> void:
	for entry: Array in playback.numbers(time):
		var event: Battle.Event = entry[0]
		var age: float = entry[1]
		var at := _screen(playback.unit_position(event.side, event.index, event.time)) + Vector2(0, -130 - 40 * age)
		var heal := event.kind == Battle.Event.HEAL
		var players := event.side == player_attacks
		var color := UiTheme.GOOD if heal else (UiTheme.BAD if players else UiTheme.WARN)
		_centred_text(at, ("+%d" if heal else "-%d") % roundi(event.amount), 22, Color(color, 1.0 - age / BattlePlayback.NUMBER_SECONDS))


func _name(side: bool, index: int) -> String:
	var names := _names_attackers if side else _names_defenders
	return names[index] if index < names.size() else ""


func _glow(fighter: Battle.Fighter) -> Color:
	if fighter.synth_id == "":
		return UiTheme.BAD
	var synth := Session.state.synth_by_id(fighter.synth_id) if Session.has_game() else null
	return UiTheme.SPECIES_GLOW.get(synth.species_id, Color.CYAN) if synth != null else Color.CYAN


func _centred_text(centre: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string_outline(font, centre - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6,
		Color(0, 0, 0, color.a))
	draw_string(font, centre - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
