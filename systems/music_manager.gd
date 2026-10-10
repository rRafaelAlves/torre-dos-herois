extends Node

const TRACK_PATHS := {
	"C": "res://assets/audio/music/Torre_dos_Herois_C_Lendas_da_Torre_Godot_Loop_Intro_Unica.ogg",
	"B": "res://assets/audio/music/Torre_dos_Herois_B_Coracao_de_Ferro_Godot_Loop_Intro_Unica.ogg",
	"A": "res://assets/audio/music/Torre_dos_Herois_A_Sinfonia_das_Sombras_Mimosa_Dark_Godot_Loop_Intro_Unica.ogg",
}
const LOOP_OFFSETS := {"C": 9.948, "B": 9.199, "A": 10.085}
const SILENT_DB := -60.0
const FADE_OUT_SECONDS := 0.5
const FADE_IN_SECONDS := 0.8

var current_track: String = ""
var requested_track: String = ""
var _player: AudioStreamPlayer
var _fade: Tween


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = "Music"
	add_child(_player)


static func track_for_combat(phase: String, floor: int) -> String:
	if phase != "combat":
		return "C"
	if floor == 5:
		return "B"
	if floor == 10:
		return "A"
	return "C"


func play_default() -> void:
	request_track("C")


func play_for_combat(attempt: Dictionary) -> void:
	request_track(track_for_combat(str(attempt.get("phase", "")), int(attempt.get("floor", 0))))


func request_track(track: String) -> void:
	if not TRACK_PATHS.has(track):
		push_error("Faixa musical desconhecida: %s" % track)
		return
	if requested_track == track and _player.playing:
		return
	if _fade != null and _fade.is_running():
		_fade.kill()
	requested_track = track
	if current_track == track and _player.playing:
		_fade = create_tween()
		_fade.tween_property(_player, "volume_db", 0.0, FADE_IN_SECONDS)
		return
	if not _player.playing:
		_start_track(track)
		_player.volume_db = SILENT_DB
		_fade = create_tween()
		_fade.tween_property(_player, "volume_db", 0.0, FADE_IN_SECONDS)
		return
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", SILENT_DB, FADE_OUT_SECONDS)
	_fade.tween_callback(_start_track.bind(track))
	_fade.tween_property(_player, "volume_db", 0.0, FADE_IN_SECONDS)


func _start_track(track: String) -> void:
	var music_stream := load(TRACK_PATHS[track]) as AudioStreamOggVorbis
	if music_stream == null:
		push_error("Não foi possível carregar a música %s." % track)
		return
	# Mantém o loop correto mesmo se o importador refizer o recurso em outra máquina.
	music_stream.loop = true
	music_stream.loop_offset = LOOP_OFFSETS[track]
	_player.stop()
	_player.stream = music_stream
	_player.volume_db = SILENT_DB
	_player.play()
	current_track = track


func _exit_tree() -> void:
	if _fade != null and _fade.is_running():
		_fade.kill()
	if _player != null:
		_player.stop()
		_player.stream = null
