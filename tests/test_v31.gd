extends SceneTree

const RunState = preload("res://systems/run_state.gd")
const Game = preload("res://scripts/main_v8.gd")
const SAVE_PATH := "user://torre_v31_music_test.json"
var failures: Array[String] = []
var checks_run := 0


func _initialize() -> void:
	call_deferred("run_all")


func check(condition: bool, message: String) -> void:
	checks_run += 1
	if not condition:
		failures.append(message)
		push_error(message)


func run_all() -> void:
	var music: Node = root.get_node("MusicManager")
	check(AudioServer.get_bus_index("Music") >= 0, "Barramento Music existe")
	check(music.track_for_combat("combat", 1) == "C", "Combate comum usa C")
	check(music.track_for_combat("combat", 5) == "B", "Andar 5 em combate usa B")
	check(music.track_for_combat("combat", 10) == "A", "Andar 10 em combate usa A")
	check(music.track_for_combat("between", 5) == "C", "Preparação usa C mesmo no andar 5")
	check(music.track_for_combat("reward", 10) == "C", "Recompensa usa C mesmo no andar 10")
	for track in ["A", "B", "C"]:
		var stream := load(music.TRACK_PATHS[track]) as AudioStreamOggVorbis
		check(stream != null, "Faixa %s importa como OGG" % track)
		if stream != null:
			check(stream.loop, "Faixa %s ativa loop no import" % track)
			check(is_equal_approx(stream.loop_offset, music.LOOP_OFFSETS[track]), "Faixa %s mantém o offset" % track)
			check(stream.get_length() > 120.0, "Faixa %s tem mais de dois minutos" % track)
			var probe := AudioStreamPlayer.new()
			root.add_child(probe)
			probe.stream = stream
			probe.play(stream.get_length() - 0.15)
			await create_timer(0.4).timeout
			var loop_position: float = probe.get_playback_position()
			check(absf(loop_position - music.LOOP_OFFSETS[track]) < 1.0, "Faixa %s retorna à seção repetível após o fim (posição %.3f)" % [track, loop_position])
			probe.stop()
			probe.queue_free()
			await process_frame
	music.play_default()
	await create_timer(0.12).timeout
	var player: AudioStreamPlayer = music.get_node("MusicPlayer")
	check(music.current_track == "C" and player.playing, "Menu inicia C")
	var first_stream: AudioStream = player.stream
	var first_position: float = player.get_playback_position()
	music.play_default()
	await create_timer(0.12).timeout
	check(player.stream == first_stream and player.get_playback_position() >= first_position, "Requisitar C novamente não reinicia")
	check(music.get_child_count() == 1, "Existe só um reprodutor")
	music.request_track("B")
	await create_timer(1.4).timeout
	check(music.current_track == "B" and player.playing, "Transição C para B conclui")
	check(is_equal_approx(player.volume_db, 0.0), "Volume retorna ao original após transição")
	music.request_track("A")
	await create_timer(1.4).timeout
	check(music.current_track == "A" and player.playing, "Transição B para A conclui")
	music.play_default()
	await create_timer(1.4).timeout
	check(music.current_track == "C" and player.playing, "Retorno ao menu restaura C")
	await test_loaded_attempt(music, 5, "B")
	await test_loaded_attempt(music, 10, "A")
	await test_game_screens(music)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if failures.is_empty():
		print("V31: %d verificações musicais passaram." % checks_run)
		quit(0)
	else:
		print("V31: %d falhas em %d verificações: %s" % [failures.size(), checks_run, "; ".join(failures)])
		quit(1)


func test_loaded_attempt(music: Node, floor: int, expected: String) -> void:
	var initial = RunState.new()
	initial.initialize(SAVE_PATH)
	var heroes: Array[String] = ["guerreiro"]
	check(initial.new_attempt(heroes) and initial.begin_floor(), "Tentativa de teste inicia")
	initial.attempt["floor"] = floor
	initial.attempt["completed"] = floor - 1
	check(initial.save(), "Tentativa do andar %d é salva" % floor)
	var loaded = RunState.new()
	loaded.initialize(SAVE_PATH)
	check(loaded.has_attempt() and int(loaded.attempt.get("floor", 0)) == floor, "Tentativa do andar %d é carregada" % floor)
	music.play_for_combat(loaded.attempt)
	await create_timer(1.4).timeout
	check(music.current_track == expected, "Carregamento do andar %d escolhe %s" % [floor, expected])


func test_game_screens(music: Node) -> void:
	var game: Control = Game.new()
	game.run.save_path = SAVE_PATH
	root.add_child(game)
	await create_timer(1.4).timeout
	check(music.current_track == "C", "Tela principal solicita C")
	var player: AudioStreamPlayer = music.get_node("MusicPlayer")
	var previous_stream: AudioStream = player.stream
	var previous_position: float = player.get_playback_position()
	game.show_selection()
	await process_frame
	check(player.stream == previous_stream and player.get_playback_position() >= previous_position, "Seleção de heróis preserva a música")
	var heroes: Array[String] = ["guerreiro", "patrulheiro", "bruxa"]
	check(game.run.new_attempt(heroes) and game.run.begin_floor(), "Jogo prepara combate")
	game.run.attempt["floor"] = 5
	game.run.attempt["completed"] = 4
	game.open_combat()
	await create_timer(1.4).timeout
	check(music.current_track == "B", "Tela de combate do andar 5 solicita B")
	game.menu()
	await create_timer(1.4).timeout
	check(music.current_track == "C", "Voltar ao menu restaura C")
	game.queue_free()
	await process_frame
