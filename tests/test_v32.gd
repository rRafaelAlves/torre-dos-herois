extends SceneTree

const AudioSettings = preload("res://systems/audio_manager.gd")
const ActionVisuals = preload("res://data/combat_action_visuals.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CombatSprites = preload("res://data/combat_sprites.gd")
const Game = preload("res://scripts/main_v8.gd")
const SETTINGS_TEST_PATH := "user://torre_v32_audio_test.cfg"
const RUN_TEST_PATH := "user://torre_v32_run_test.json"
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
	await test_assets_and_mixer()
	await test_preferences()
	await test_combat_cues()
	await test_game_controls()
	for path in [SETTINGS_TEST_PATH, RUN_TEST_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("V32: %d verificações de áudio passaram." % checks_run)
		quit(0)
	else:
		print("V32: %d falhas em %d verificações: %s" % [failures.size(), checks_run, "; ".join(failures)])
		quit(1)


func test_assets_and_mixer() -> void:
	var audio: Node = root.get_node("AudioManager")
	for bus_name in ["Master", "Music", "SFX", "Ambience"]:
		check(AudioServer.get_bus_index(bus_name) >= 0, "Barramento %s existe" % bus_name)
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")) == "Master", "SFX envia ao Master")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Ambience")) == "Master", "Ambiente envia ao Master")
	check(audio.get_child_count() == 9, "Pool usa oito vozes e um player ambiental")
	for name in audio.SOUND_NAMES:
		var stream := load("res://assets/audio/sfx/%s.wav" % name) as AudioStreamWAV
		check(stream != null and stream.get_length() > 0.05, "WAV %s carrega" % name)
	audio.start_wind()
	check(audio.wind_playing(), "Vento começa uma vez")
	var wind_player: AudioStreamPlayer = audio.get_node("WindPlayer")
	check(wind_player.stream != null and (wind_player.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "Vento reproduz com loop")
	audio.start_wind()
	check(wind_player == audio.get_node("WindPlayer") and audio.get_child_count() == 9, "Vento não duplica player")
	audio.stop_wind()
	await create_timer(0.4).timeout
	check(not audio.wind_playing(), "Vento para fora da arena")
	audio.play("physical_hit")
	check(int(audio.played_count.get("physical_hit", 0)) >= 1, "SFX reproduz pelo pool")
	check(audio.get_child_count() == 9, "Reproduzir efeitos não cria nós extras")


func test_preferences() -> void:
	if FileAccess.file_exists(SETTINGS_TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TEST_PATH))
	var audio: Node = root.get_node("AudioManager")
	var probe: Node = AudioSettings.new()
	probe.settings_path = SETTINGS_TEST_PATH
	root.add_child(probe)
	check(probe.volume_percent("Music") == 50.0 and probe.volume_percent("SFX") == 75.0 and probe.volume_percent("Ambience") == 30.0, "Volumes novos usam os padrões")
	probe.set_volume_percent("Music", 37.0)
	probe.set_volume_percent("SFX", 64.0)
	probe.toggle_mute("Music")
	check(probe.volume_percent("Music") == 0.0 and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Mute produz silêncio real")
	probe.toggle_mute("Music")
	check(probe.volume_percent("Music") == 37.0, "Mute restaura último volume")
	probe.set_volume_percent("Music", 0.0)
	probe.queue_free()
	await process_frame
	var reopened: Node = AudioSettings.new()
	reopened.settings_path = SETTINGS_TEST_PATH
	root.add_child(reopened)
	check(reopened.volume_percent("Music") == 0.0 and reopened.volume_percent("SFX") == 64.0, "Preferências persistem após reinício")
	reopened.toggle_mute("Music")
	check(reopened.volume_percent("Music") == 37.0, "Volume anterior também persiste")
	reopened.queue_free()
	await process_frame
	for bus_name in ["Music", "SFX", "Ambience"]:
		audio._apply_bus(bus_name)


func make_feedback(ids: Array[String]) -> Control:
	var feedback: Control = CombatFeedback.new()
	root.add_child(feedback)
	feedback.size = Vector2(720, 320)
	var cards: Dictionary = {}
	var all_ids: Array[String] = ids.duplicate()
	all_ids.append_array(["goblin", "esqueleto"])
	for index in all_ids.size():
		var id: String = all_ids[index]
		var sprite := TextureRect.new()
		sprite.texture = CombatSprites.side_texture_for(id) if id in ids else CombatSprites.texture_for(id)
		sprite.position = Vector2(20, 30 + index * 50) if id in ids else Vector2(560, 30 + (index - ids.size()) * 50)
		sprite.size = Vector2(48, 48)
		feedback.add_child(sprite)
		cards[id] = {"sprite": sprite}
	feedback.bind_arena(cards, ids)
	for id in all_ids:
		feedback.living[id] = true
	return feedback


func test_combat_cues() -> void:
	var feedback: Control = make_feedback(["guerreiro", "patrulheiro", "sacerdotisa", "feiticeiro"])
	var cues: Array[String] = []
	feedback.sfx_cue.connect(func(name: String, _volume: float) -> void: cues.append(name))
	await process_frame
	await feedback.play_action(ActionVisuals.hero_action("guerreiro", "attack", "goblin", ["goblin"]), [{"kind": "damage", "target_id": "goblin", "amount": 10, "visual_type": "physical"}])
	check(cues.has("sword") and cues.count("physical_hit") == 1, "Espada e impacto físico acompanham ataque")
	cues.clear()
	await feedback.play_action(ActionVisuals.hero_action("patrulheiro", "attack", "goblin", ["goblin"]), [{"kind": "damage", "target_id": "goblin", "amount": 10, "visual_type": "physical", "critical": true}])
	check(cues.has("bow") and cues.has("arrow") and cues.has("critical_hit") and not cues.has("physical_hit"), "Arco e crítico têm sons próprios")
	cues.clear()
	await feedback.play_action(ActionVisuals.hero_action("feiticeiro", "skill:bola_de_fogo", "goblin", ["goblin"]), [{"kind": "damage", "target_id": "goblin", "amount": 15, "visual_type": "fire"}])
	check(cues.has("fire_cast") and cues.has("fire_burst"), "Bola de Fogo usa conjuração e explosão")
	cues.clear()
	await feedback.play_action(ActionVisuals.hero_action("feiticeiro", "skill:onda_arcana", "", ["goblin", "esqueleto"]), [{"kind": "damage", "target_id": "goblin", "amount": 12, "visual_type": "magical"}, {"kind": "damage", "target_id": "esqueleto", "amount": 12, "visual_type": "magical"}])
	check(cues.count("magic_hit") == 1, "Ataque em área agrupa impacto sonoro")
	cues.clear()
	await feedback.play_action(ActionVisuals.hero_action("sacerdotisa", "skill:cura", "guerreiro", ["guerreiro"]), [{"kind": "heal", "target_id": "guerreiro", "amount": 10}])
	check(cues.has("holy") and cues.count("heal") == 1, "Cura efetiva recebe som")
	cues.clear()
	await feedback.play_action(ActionVisuals.hero_action("sacerdotisa", "skill:cura", "guerreiro", ["guerreiro"]), [])
	check(not cues.has("heal"), "Cura sem PV restaurado não produz som de cura")
	cues.clear()
	await feedback.play_action(ActionVisuals.hero_action("sacerdotisa", "rescue", "guerreiro", ["guerreiro"]), [{"kind": "heal", "target_id": "guerreiro", "amount": 10}])
	check(cues.has("revive"), "Reanimação tem som próprio")
	cues.clear()
	await feedback.play_action(ActionVisuals.enemy_action("goblin", {"id": "attack", "target_id": "guerreiro"}, ["guerreiro"]), [{"kind": "damage", "target_id": "guerreiro", "amount": 10, "visual_type": "physical"}])
	check(cues.has("sword") and cues.count("physical_hit") == 1, "Ataque inimigo usa os mesmos marcos visuais de som")
	feedback.queue_free()
	await process_frame


func test_game_controls() -> void:
	var game: Control = Game.new()
	game.size = Vector2(1100, 760)
	game.run.save_path = RUN_TEST_PATH
	root.add_child(game)
	await process_frame
	check(game.audio_button != null and game.audio_panel != null and game.audio_button.visible, "Botão de áudio aparece no menu")
	check(game.audio_button.get_global_rect().end.x <= 1100.0 and game.audio_button.get_global_rect().position.x > 900.0, "Botão fica no topo direito")
	game.audio_button.pressed.emit()
	check(game.audio_panel.visible, "Botão abre painel")
	check(game.audio_controls["SFX"]["amount"].text == "%d%%" % int(root.get_node("AudioManager").volume_percent("SFX")), "Painel atualiza valor visível")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	check(not game.audio_panel.visible, "Esc fecha o painel")
	game.audio_button.pressed.emit()
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.position = Vector2(4, 4)
	game._input(outside)
	check(not game.audio_panel.visible, "Clique fora fecha o painel")
	game.show_selection()
	await process_frame
	check(game.audio_button.visible and game.audio_panel.get_parent() == game.audio_overlay, "Controle persiste ao trocar de tela")
	game.size = Vector2(800, 600)
	await process_frame
	check(game.audio_button.get_global_rect().end.x <= 800.0 and game.audio_panel.get_global_rect().position.x >= 0.0, "Painel cabe em resolução menor")
	var party: Array[String] = ["guerreiro", "patrulheiro", "bruxa"]
	check(game.run.new_attempt(party) and game.run.begin_floor(), "Tentativa de teste começa")
	game.open_combat()
	await process_frame
	check(root.get_node("AudioManager").wind_playing(), "Combate liga o vento")
	game.menu()
	await create_timer(0.4).timeout
	check(not root.get_node("AudioManager").wind_playing(), "Menu desliga o vento")
	game.queue_free()
	await process_frame
