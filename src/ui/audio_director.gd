extends Node
## Autoload "AudioDirector": every sound in the game goes through here by event
## name. A real file at res://audio/sfx/<event>.ogg (or .wav) is used when it
## exists, else a placeholder tone from ToneSynth; music the same way from
## res://audio/music/<track>.ogg. Buses: Master > Music, SFX, UI, with the
## volumes from Settings. Game events are heard by listening to the Session.
## Style target (docs/ui-plan.md): lo-fi synthwave.

const SFX_DIR: String = "res://audio/sfx"
const MUSIC_DIR: String = "res://audio/music"
const POOL_SIZE: int = 10
## The same event is not replayed faster than this (seconds), so 4x speed
## does not machine-gun coin sounds.
const MIN_GAP: float = 0.06
const MUSIC_FADE: float = 1.2

## Placeholder sounds: event -> ToneSynth segments (and the bus they play on).
const SOUNDS: Dictionary[String, Array] = {
	"ui_click": [{"f": 1300.0, "d": 0.035, "w": "sine", "v": 0.25}],
	"cook": [{"f": 900.0, "to": 300.0, "d": 0.3, "w": "noise", "v": 0.18}],
	"dish_ready": [{"f": 988.0, "d": 0.08, "v": 0.3}, {"f": 1319.0, "d": 0.14, "v": 0.3}],
	"star": [{"f": 1568.0, "d": 0.07, "w": "tri", "v": 0.25}, {"f": 2093.0, "d": 0.12, "w": "tri", "v": 0.22}],
	"tip": [{"f": 2093.0, "d": 0.05, "w": "square", "v": 0.12}, {"f": 2637.0, "d": 0.12, "w": "square", "v": 0.1}],
	"convert": [{"f": 220.0, "to": 1760.0, "d": 0.45, "w": "square", "v": 0.18},
		{"f": 1760.0, "to": 1500.0, "d": 0.05, "w": "noise", "v": 0.15}, {"f": 1760.0, "d": 0.25, "w": "tri", "v": 0.25}],
	"level_up": [{"f": 523.0, "d": 0.07, "w": "tri"}, {"f": 659.0, "d": 0.07, "w": "tri"},
		{"f": 784.0, "d": 0.07, "w": "tri"}, {"f": 1047.0, "d": 0.2, "w": "tri"}],
	"angry": [{"f": 180.0, "to": 140.0, "d": 0.28, "w": "square", "v": 0.15}],
	"broken": [{"f": 3000.0, "to": 800.0, "d": 0.22, "w": "noise", "v": 0.3}],
	"shift_end": [{"f": 784.0, "d": 0.15, "w": "tri"}, {"f": 659.0, "d": 0.15, "w": "tri"}, {"f": 523.0, "d": 0.35, "w": "tri"}],
	"hit": [{"f": 400.0, "to": 90.0, "d": 0.1, "w": "noise", "v": 0.35}],
	"ko": [{"f": 700.0, "to": 120.0, "d": 0.35, "w": "square", "v": 0.18}],
	"victory": [{"f": 523.0, "d": 0.1, "w": "square", "v": 0.16}, {"f": 659.0, "d": 0.1, "w": "square", "v": 0.16},
		{"f": 784.0, "d": 0.1, "w": "square", "v": 0.16}, {"f": 1047.0, "d": 0.4, "w": "square", "v": 0.16}],
	"defeat": [{"f": 392.0, "d": 0.2, "w": "tri"}, {"f": 330.0, "d": 0.2, "w": "tri"}, {"f": 262.0, "d": 0.5, "w": "tri"}],
	"alarm": [{"f": 880.0, "d": 0.18, "w": "square", "v": 0.14}, {"f": 660.0, "d": 0.18, "w": "square", "v": 0.14},
		{"f": 880.0, "d": 0.18, "w": "square", "v": 0.14}, {"f": 660.0, "d": 0.18, "w": "square", "v": 0.14}],
}
const UI_EVENTS: Array[String] = ["ui_click"]
## Placeholder music: lo-fi chord loops (Hz), seconds per chord, volume, wave, pulse.
const TRACKS: Dictionary[String, Array] = {
	# Cmaj7 - Am7 - Fmaj7 - G6, slow and soft.
	"shift": [[[261.6, 329.6, 392.0, 493.9], [220.0, 261.6, 329.6, 392.0], [174.6, 220.0, 261.6, 329.6],
		[196.0, 246.9, 293.7, 329.6]], 2.4, 0.22, "sine", 0.0],
	# Am - F - C - Em, darker, neon pulse.
	"night": [[[110.0, 220.0, 261.6, 329.6], [87.3, 174.6, 220.0, 261.6], [130.8, 196.0, 261.6, 329.6],
		[82.4, 164.8, 196.0, 246.9]], 3.0, 0.2, "tri", 0.5],
	# Driving minor arpeggio for fights.
	"battle": [[[110.0, 164.8, 220.0], [98.0, 146.8, 196.0], [87.3, 130.8, 174.6], [98.0, 146.8, 196.0]], 1.0, 0.16, "square", 4.0],
}

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cache: Dictionary[String, AudioStream] = {}
var _last_played: Dictionary[String, float] = {}
var _music_a := AudioStreamPlayer.new()
var _music_b := AudioStreamPlayer.new()
var _track: String = ""


func _ready() -> void:
	for bus: String in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	for bus: String in Settings.BUSES:
		Settings.apply_volume(bus)
	for i: int in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	for player: AudioStreamPlayer in [_music_a, _music_b]:
		player.bus = "Music"
		player.volume_db = -80.0
		add_child(player)
	var session := get_node_or_null("/root/Session")
	if session != null:
		session.shift_advanced.connect(_on_shift_advanced)
		session.phase_changed.connect(_on_phase_changed)
		session.converted.connect(func(_customer_id: String, _synth: Synth) -> void: play("convert"))


## Plays a sound effect by event name.
func play(event: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(event, -1.0) < MIN_GAP:
		return
	_last_played[event] = now
	var stream := _sound(event)
	if stream == null:
		return
	var player := _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.bus = "UI" if UI_EVENTS.has(event) else "SFX"
	player.stream = stream
	player.play()


## Crossfades to a music track ("shift", "night", "battle"; "" = silence).
func music(track: String) -> void:
	if track == _track:
		return
	_track = track
	var fading_out := _music_a if _music_a.playing and _music_a.volume_db > -40.0 else _music_b
	var fading_in := _music_b if fading_out == _music_a else _music_a
	var tween := create_tween().set_parallel()
	tween.tween_property(fading_out, "volume_db", -80.0, MUSIC_FADE)
	if track != "":
		fading_in.stream = _music(track)
		fading_in.volume_db = -40.0
		fading_in.play()
		tween.tween_property(fading_in, "volume_db", 0.0, MUSIC_FADE)


## The track for what the player is doing now.
func music_for_phase() -> void:
	var session := get_node_or_null("/root/Session")
	if session == null or not session.has_game():
		music("night")
		return
	music("shift" if session.state.phase == GameState.Phase.SHIFT else "night")


func _sound(event: String) -> AudioStream:
	if not _cache.has(event):
		var file := _file(SFX_DIR, event)
		if file != null:
			_cache[event] = file
		elif SOUNDS.has(event):
			_cache[event] = ToneSynth.render(SOUNDS[event])
		else:
			push_warning("AudioDirector: no sound for '%s'" % event)
			_cache[event] = null
	return _cache[event]


func _music(track: String) -> AudioStream:
	var key := "music:" + track
	if not _cache.has(key):
		var file := _file(MUSIC_DIR, track)
		if file != null:
			_cache[key] = file
		else:
			var spec: Array = TRACKS.get(track, TRACKS["night"])
			_cache[key] = ToneSynth.pad(spec[0], spec[1], spec[2], spec[3], spec[4])
	return _cache[key]


func _file(dir: String, name: String) -> AudioStream:
	for extension: String in ["ogg", "wav", "mp3"]:
		var path := "%s/%s.%s" % [dir, name, extension]
		if ResourceLoader.exists(path):
			return load(path)
	return null


func _on_shift_advanced(events: Shift.Events) -> void:
	if not events.dishes_ready.is_empty():
		play("dish_ready")
	if events.tips_earned > 0:
		play("tip")
	if not events.starred.is_empty():
		play("star")
	if not events.left_angry.is_empty():
		play("angry")
	if events.dishes_broken > 0:
		play("broken")
	if not events.level_ups.is_empty():
		play("level_up")
	if events.shift_ended:
		play("shift_end")


func _on_phase_changed() -> void:
	music_for_phase()
