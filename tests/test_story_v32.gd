extends SceneTree

const Game = preload("res://scripts/main_v8.gd")
const RunState = preload("res://systems/run_state.gd")
const StoryFlow = preload("res://systems/story_flow.gd")
const Scenes = preload("res://data/narrative_scenes.gd")
const Characters = preload("res://data/narrative_characters.gd")
const SAVE_PATH := "user://torre_story_v32_test.json"
const SEEN_PATH := "user://torre_story_v32_seen.cfg"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run_all")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _remove_test_files() -> void:
	for path in [SAVE_PATH, SEEN_PATH]:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			var target: String = path + suffix
			if FileAccess.file_exists(target):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(target))


func _make_game() -> Control:
	var game: Control = Game.new()
	game.size = Vector2(1100, 760)
	game.run.save_path = SAVE_PATH
	root.add_child(game)
	game.narrative.seen_path = SEEN_PATH
	return game


func _finish_scene(game: Control) -> void:
	var scene_id: String = game.narrative.scene_id
	var steps := 0
	while game.narrative.active and game.narrative.scene_id == scene_id and steps < 40:
		game.narrative.overlay.complete_text()
		var options: Array = game.narrative._current.get("choices", [])
		if options.is_empty():
			game.narrative.advance()
		else:
			game.narrative.choose(options.back())
		steps += 1
	check(steps < 40, "Diálogo %s termina pelo avanço de falas" % scene_id)
	await process_frame
	await process_frame


func run_all() -> void:
	_remove_test_files()
	for id in ["pai_da_garota", "comerciante"]:
		check(ResourceLoader.exists(str(Characters.get_character(id).get("portrait", ""))), "Retrato %s existe" % id)
	for id in ["intro_reino", "encontro_pai", "encontro_comerciante", "conselho_comerciante"]:
		var scene: Dictionary = Scenes.get_scene(id)
		check(not scene.is_empty() and not scene.get("lines", []).is_empty(), "Cena %s cadastrada" % id)
		var lines: Array = scene.get("lines", [])
		for index in lines.size():
			check(lines[index].get("scene_id", "") == id and (index + 1 == lines.size() or not lines[index].get("choices", []).is_empty() or lines[index].get("next", "") == lines[index + 1].get("id", "")), "Sequência válida em %s/%d" % [id, index])
	var father_speakers: Array = []
	for line in Scenes.get_scene("encontro_pai")["lines"]:
		father_speakers.append(line.get("speaker", ""))
	for id in ["guerreiro", "patrulheiro", "bruxa", "sacerdotisa", "feiticeiro"]:
		check(id in father_speakers, "Herói %s participa narrativamente" % id)
	for party in [["guerreiro"], ["guerreiro", "bruxa"], ["guerreiro", "bruxa", "sacerdotisa"]]:
		_remove_test_files()
		var game := _make_game()
		await process_frame
		var team: Array[String] = []
		team.assign(party)
		game.selected = team
		game.new_attempt()
		check(game.narrative.active and game.narrative.scene_id == "intro_reino", "Nova tentativa com %d herói(s) abre prólogo" % team.size())
		check(game.combat_action_panel == null or not is_instance_valid(game.combat_action_panel), "Prólogo antecede o combate")
		var initial_coins := int(game.run.permanent["coins"])
		var initial_heroes: Array = game.run.attempt["heroes"].duplicate(true)
		await _finish_scene(game)
		check(game.narrative.active and game.narrative.scene_id == "encontro_pai", "Pai sucede o prólogo")
		check(game.narrative.overlay._portrait.texture != null and game.narrative.overlay._name_label.text == "PAI DA GAROTA", "Pai tem nome e retrato corretos")
		await _finish_scene(game)
		check(not game.narrative.active and game.combat.hero_ids.size() == team.size() and int(game.run.attempt["floor"]) == 1, "Combate 1 começa com equipe original")
		check(game.run.attempt["heroes"] == initial_heroes and int(game.run.permanent["coins"]) == initial_coins and int(game.run.attempt["xp"]) == 0, "Cenas não alteram vida, mana, moedas ou XP")
		check(bool(game.run.attempt["narrative_seen"].get("intro_reino", false)) and bool(game.run.attempt["narrative_seen"].get("encontro_pai", false)), "Conclusão da tentativa atual fica registrada")
		check(game.run.has_permanent_scene("intro_reino") and game.run.has_permanent_scene("encontro_pai"), "Prólogo e pai ficam concluídos entre expedições")
		game.menu()
		game.show_phase()
		check(not game.narrative.active and int(game.run.attempt["floor"]) == 1, "Continuar não repete prólogo ou pai")
		if team.size() == 3:
			var old_attempt_id := str(game.run.attempt["id"])
			game.restart_attempt()
			check(not game.narrative.active and str(game.run.attempt["id"]) != old_attempt_id, "Reinício cria nova tentativa sem repetir cenas permanentes")
			check(game.combat.hero_ids.size() == 3, "Reinício retorna ao combate com os mesmos três heróis")
		game.queue_free()
		await process_frame
	_remove_test_files()
	var game := _make_game()
	await process_frame
	var solo: Array[String] = ["guerreiro"]
	game.selected = solo
	game.new_attempt()
	await _finish_scene(game)
	await _finish_scene(game)
	game.run.attempt["completed"] = 4
	game.run.attempt["phase"] = "between"
	game.begin_next_floor()
	check(game.narrative.active and game.narrative.scene_id == "encontro_comerciante", "Andar 5 abre comerciante antes do combate")
	check(int(game.run.attempt["floor"]) == 5 and int(game.run.attempt["completed"]) == 4, "Encontro não conta como andar")
	check(game.narrative.overlay._portrait.texture != null and game.narrative.overlay._name_label.text == "COMERCIANTE", "Comerciante tem retrato e nome")
	game.queue_free()
	await process_frame
	var resumed := _make_game()
	await process_frame
	resumed.show_phase()
	check(resumed.narrative.active and resumed.narrative.scene_id == "encontro_comerciante", "Salvar durante encontro permite retomar cena")
	await _finish_scene(resumed)
	check(not resumed.narrative.active and int(resumed.run.attempt["floor"]) == 5 and resumed.combat.enemy_ids.size() > 0, "Comerciante devolve ao combate 5")
	resumed.menu()
	resumed.show_phase()
	check(not resumed.narrative.active and bool(resumed.run.attempt["narrative_seen"].get("encontro_comerciante", false)), "Comerciante não aparece duas vezes")
	resumed.menu()
	resumed.screen.find_child("MenuRevisitIntro", true, false).pressed.emit()
	check(resumed.narrative.active and resumed.narrative.scene_id == "intro_reino", "Menu permite rever introdução")
	await _finish_scene(resumed)
	check(not resumed.narrative.active and resumed.screen != null, "Revisita retorna ao menu")
	resumed.queue_free()
	await process_frame
	var legacy := RunState.new()
	legacy.initialize(SAVE_PATH)
	legacy.attempt.erase("narrative_seen")
	check(legacy.save(), "Salvamento antigo simulado é gravado")
	var loaded := RunState.new()
	loaded.initialize(SAVE_PATH)
	check(StoryFlow.next_scene(loaded.attempt) == "" and bool(loaded.attempt["narrative_seen"].get("encontro_comerciante", false)), "Salvamento legado continua sem encontro retroativo")
	_remove_test_files()
	if failures.is_empty():
		print("História V32: %d verificações passaram." % checks)
		quit(0)
	else:
		print("História V32: %d falhas em %d verificações: %s" % [failures.size(), checks, "; ".join(failures)])
		quit(1)
