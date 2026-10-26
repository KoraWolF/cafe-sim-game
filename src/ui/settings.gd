class_name Settings
extends RefCounted
## Player settings kept between sessions in user://settings.cfg (a ConfigFile
## of plain values): bus volumes and whether the guided first day was done.

const PATH: String = "user://settings.cfg"
const BUSES: Array[String] = ["Master", "Music", "SFX", "UI"]
const DEFAULT_VOLUMES: Dictionary[String, float] = {"Master": 0.8, "Music": 0.6, "SFX": 0.8, "UI": 0.7}

static var _config: ConfigFile = null


static func _file() -> ConfigFile:
	if _config == null:
		_config = ConfigFile.new()
		_config.load(PATH)  # missing on first run: defaults apply
	return _config


## 0..1.
static func volume(bus: String) -> float:
	return clampf(float(_file().get_value("audio", bus, DEFAULT_VOLUMES.get(bus, 1.0))), 0.0, 1.0)


static func set_volume(bus: String, value: float) -> void:
	_file().set_value("audio", bus, clampf(value, 0.0, 1.0))
	apply_volume(bus)
	_file().save(PATH)


## Sets an audio bus to its saved volume (silent at 0).
static func apply_volume(bus: String) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	var value := volume(bus)
	AudioServer.set_bus_mute(index, value <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))


static func tutorial_done() -> bool:
	return bool(_file().get_value("tutorial", "done", false))


static func set_tutorial_done(done: bool) -> void:
	_file().set_value("tutorial", "done", done)
	_file().save(PATH)
