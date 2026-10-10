extends SceneTree

const Game = preload("res://scripts/main_v8.gd")
const Characters = preload("res://data/narrative_characters.gd")
const Scenes = preload("res://data/narrative_scenes.gd")
const TEST_RUN := "user://torre_narrative_run_test.json"
const TEST_SEEN := "user://torre_narrative_seen_test.cfg"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run_all")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func run_all() -> void:
	for id in ["guerreiro", "patrulheiro", "bruxa", "sacerdotisa", "feiticeiro"]:
		var record: Dictionary = Characters.get_character(id)
		check(not record.is_empty() and ResourceLoader.exists(record.get("portrait", "")), "Retrato do %s carrega" % id)
	for id in ["pai_da_garota", "comerciante"]:
		check(ResourceLoader.exists(Characters.get_character(id).get("portrait", "")), "Retrato do %s carrega" % id)
	for id in ["garota_desconhecida", "figura_alada", "general_gueist"]:
		check(ResourceLoader.exists(Characters.get_character(id).get("portrait", "")), "Retrato do NPC %s carrega" % id)
	check(Scenes.get_scene("demo_narrativa").get("lines", []).size() == 3, "Demonstração tem três falas")
	var game: Control = Game.new()
	game.size = Vector2(1100, 760)
	game.run.save_path = TEST_RUN
	root.add_child(game)
	await process_frame
	game.narrative.seen_path = TEST_SEEN
	var music_bus := AudioServer.get_bus_index("Music")
	var original_db := AudioServer.get_bus_volume_db(music_bus)
	check(game.narrative.start("demo_narrativa", game), "Cena inicia no menu")
	check(game.narrative.active and game.narrative.overlay._name_label.text == "GUERREIRO", "Primeiro retrato e nome são do guerreiro")
	check(game.narrative.overlay._portrait.texture != null, "Guerreiro tem retrato")
	check(game.narrative.overlay._body.visible_characters == 0, "Texto começa oculto")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	game.narrative.overlay._input(key)
	game.narrative.overlay._input(key)
	check(game.narrative.overlay._body.visible_characters == -1 and game.narrative.overlay._name_label.text == "GUERREIRO", "Primeiro avanço apenas revela")
	await create_timer(0.12).timeout
	game.narrative.overlay.advance_requested.emit()
	check(game.narrative.overlay._name_label.text == "BRUXA" and game.narrative.overlay._portrait.anchor_left > 0.5, "Fala seguinte troca retrato e lado")
	game.narrative.overlay.complete_text()
	game.narrative.advance()
	check(game.narrative.overlay._name_label.text == "NARRADOR" and not game.narrative.overlay._portrait.visible, "Narração fica sem retrato")
	game.narrative.overlay.complete_text()
	game.narrative.advance()
	check(not game.narrative.active and game.narrative.seen.get("demo_narrativa", false), "Cena termina uma vez e marca vista")
	check(game.narrative.start("demo_narrativa", game) and game.narrative.overlay._skip_button.visible, "Cena vista permite pular")
	game.narrative.skip()
	check(not game.narrative.active, "Pulo termina a cena")
	await create_timer(0.25).timeout
	check(is_equal_approx(AudioServer.get_bus_volume_db(music_bus), original_db), "Volume musical retorna ao original")
	var heroes: Array[String] = ["guerreiro", "bruxa", "sacerdotisa"]
	check(game.run.new_attempt(heroes) and game.run.begin_floor(), "Combate de teste inicia")
	game.open_combat()
	await process_frame
	check(game.combat_action_panel.visible, "Caixa de ação aparece antes da cena")
	game.toggle_log()
	check(game.log_panel.visible, "Registro aberto antes da cena")
	check(game.narrative.start("demo_narrativa", game), "Cena pode abrir no combate")
	check(not game.combat_action_panel.visible, "Caixa de ação some durante a cena")
	check(not game.log_panel.visible and not game.log_toggle.visible, "Registro não disputa espaço com diálogo")
	var turn_before: int = game.combat.index
	game.choose_action("defend")
	game.target_chosen("goblin")
	game.toggle_skills()
	check(game.combat.index == turn_before and not game.skills_open, "Ações e habilidade ficam bloqueadas")
	game.narrative.finish()
	check(game.combat_action_panel.visible and game.log_panel.visible and not game.narrative.active, "Interface anterior é restaurada")
	var long_scene := {"first": "long", "lines": [{"id": "long", "speaker": "bruxa", "text": "Uma mensagem longa de teste. ".repeat(18), "end": true}]}
	check(game.narrative.start_definition("long_test", long_scene, game), "Cena de dados externos inicia")
	check(game.narrative.overlay._body.text.length() > 300, "Texto longo é aceito")
	check(game.narrative.overlay._body.scroll_active, "Texto longo possui rolagem")
	for resolution in [Vector2(1100, 760), Vector2(800, 600), Vector2(1600, 900)]:
		game.size = resolution
		await process_frame
		var dialogue_rect: Rect2 = game.narrative.overlay._panel.get_global_rect()
		check(dialogue_rect.size.x > 0 and dialogue_rect.size.y > 0 and dialogue_rect.end.y <= resolution.y + 1.0, "Painel cabe em %s" % resolution)
	game.narrative.finish()
	game.queue_free()
	await process_frame
	for path in [TEST_RUN, TEST_SEEN]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty():
		print("Narrativa: %d verificações passaram." % checks)
		quit(0)
	else:
		print("Narrativa: %d falhas em %d verificações: %s" % [failures.size(), checks, "; ".join(failures)])
		quit(1)
