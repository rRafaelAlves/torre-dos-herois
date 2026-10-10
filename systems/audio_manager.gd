extends Node

const DEFAULT_SETTINGS_PATH := "user://audio_preferences_v32.cfg"
const DEFAULTS := {"Music": 50.0, "SFX": 75.0, "Ambience": 30.0}
const MAX_VOICES := 8
const SOUND_NAMES := [
	"hover", "click", "confirm", "invalid", "hero_select", "route", "attribute", "unlock",
	"sword", "bow", "arrow", "physical_hit", "critical_hit", "shield",
	"arcane_cast", "magic_projectile", "magic_hit", "fire_cast", "fire_burst",
	"curse", "heal", "holy", "revive", "level_up", "card", "relic",
	"floor_clear", "expedition_start", "defeat", "final_victory", "xp_gain"
]

var levels: Dictionary = DEFAULTS.duplicate()
var last_nonzero: Dictionary = DEFAULTS.duplicate()
var settings_path: String = DEFAULT_SETTINGS_PATH
var _voices: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}
var _last_played: Dictionary = {}
var _ambience: AudioStreamPlayer
var _wind_fade: Tween
var played_count: Dictionary = {}
var music_ducked := false
var _music_duck_tween: Tween


func _ready() -> void:
	_load_preferences()
	for bus_name in DEFAULTS:
		_apply_bus(bus_name)
	for index in MAX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "SFXVoice%d" % index
		voice.bus = "SFX"
		add_child(voice)
		_voices.append(voice)
	_ambience = AudioStreamPlayer.new()
	_ambience.name = "WindPlayer"
	_ambience.bus = "Ambience"
	add_child(_ambience)


func volume_percent(bus_name: String) -> float:
	return float(levels.get(bus_name, 0.0))


func set_volume_percent(bus_name: String, percent: float) -> void:
	if not DEFAULTS.has(bus_name):
		return
	var clamped := clampf(percent, 0.0, 100.0)
	levels[bus_name] = clamped
	if clamped > 0.0:
		last_nonzero[bus_name] = clamped
	_apply_bus(bus_name)
	_save_preferences()


func toggle_mute(bus_name: String) -> void:
	if not DEFAULTS.has(bus_name):
		return
	if volume_percent(bus_name) > 0.0:
		set_volume_percent(bus_name, 0.0)
	else:
		set_volume_percent(bus_name, maxf(1.0, float(last_nonzero.get(bus_name, DEFAULTS[bus_name]))))


func all_muted() -> bool:
	return volume_percent("Music") == 0.0 and volume_percent("SFX") == 0.0 and volume_percent("Ambience") == 0.0


func set_music_ducked(ducked: bool, reduction_db: float = 5.0) -> void:
	music_ducked = ducked
	var bus_index := AudioServer.get_bus_index("Music")
	if bus_index < 0:
		return
	if _music_duck_tween != null and _music_duck_tween.is_running():
		_music_duck_tween.kill()
	var fraction := maxf(0.0001, volume_percent("Music") / 100.0)
	var target_db := linear_to_db(fraction) - 2.0 - (reduction_db if ducked else 0.0)
	_music_duck_tween = create_tween()
	_music_duck_tween.tween_method(func(value: float) -> void: AudioServer.set_bus_volume_db(bus_index, value), AudioServer.get_bus_volume_db(bus_index), target_db, 0.2)


func play(sound_name: String, volume_db: float = 0.0) -> void:
	if not SOUND_NAMES.has(sound_name):
		return
	var now: int = Time.get_ticks_msec()
	var cooldown: int = 85 if sound_name in ["hover", "click"] else 45
	if now - int(_last_played.get(sound_name, -100000)) < cooldown:
		return
	var chosen: AudioStreamPlayer
	for voice in _voices:
		if not voice.playing:
			chosen = voice
			break
	if chosen == null:
		return
	if not _sounds.has(sound_name):
		_sounds[sound_name] = load("res://assets/audio/sfx/%s.wav" % sound_name)
	var stream: AudioStream = _sounds[sound_name]
	if stream == null:
		push_error("Efeito sonoro indisponível: %s" % sound_name)
		return
	chosen.stream = stream
	chosen.pitch_scale = randf_range(0.97, 1.03)
	chosen.volume_db = volume_db + randf_range(-0.8, 0.5)
	chosen.play()
	_last_played[sound_name] = now
	played_count[sound_name] = int(played_count.get(sound_name, 0)) + 1


func start_wind() -> void:
	if _wind_fade != null and _wind_fade.is_running():
		_wind_fade.kill()
	if _ambience.stream == null:
		var stream := load("res://assets/audio/sfx/wind.wav") as AudioStreamWAV
		if stream == null:
			return
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		_ambience.stream = stream
	if not _ambience.playing:
		_ambience.volume_db = -60.0
		_ambience.play()
	_wind_fade = create_tween()
	_wind_fade.tween_property(_ambience, "volume_db", 0.0, 0.45)


func stop_wind() -> void:
	if _ambience != null and _ambience.playing:
		if _wind_fade != null and _wind_fade.is_running():
			_wind_fade.kill()
		_wind_fade = create_tween()
		_wind_fade.tween_property(_ambience, "volume_db", -60.0, 0.35)
		_wind_fade.tween_callback(_ambience.stop)


func wind_playing() -> bool:
	return _ambience != null and _ambience.playing


func _apply_bus(bus_name: String) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_error("Barramento de áudio ausente: %s" % bus_name)
		return
	var fraction: float = volume_percent(bus_name) / 100.0
	AudioServer.set_bus_mute(index, fraction <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, fraction)) - (2.0 if bus_name == "Music" else 0.0) - (5.0 if bus_name == "Music" and music_ducked else 0.0))


func _load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	for bus_name in DEFAULTS:
		levels[bus_name] = clampf(float(config.get_value("volume", bus_name, DEFAULTS[bus_name])), 0.0, 100.0)
		last_nonzero[bus_name] = clampf(float(config.get_value("restore", bus_name, DEFAULTS[bus_name])), 1.0, 100.0)


func _save_preferences() -> void:
	var config := ConfigFile.new()
	for bus_name in DEFAULTS:
		config.set_value("volume", bus_name, levels[bus_name])
		config.set_value("restore", bus_name, last_nonzero[bus_name])
	var result: Error = config.save(settings_path)
	if result != OK:
		push_warning("Não foi possível salvar as preferências de áudio.")


func _exit_tree() -> void:
	if _wind_fade != null and _wind_fade.is_running():
		_wind_fade.kill()
	if _ambience != null:
		_ambience.stop()
	for voice in _voices:
		voice.stop()
		voice.stream = null
	if _ambience != null:
		_ambience.stream = null
