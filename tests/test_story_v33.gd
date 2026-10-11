extends SceneTree

const Game = preload("res://scripts/main_v8.gd")
const RunState = preload("res://systems/run_state.gd")
const Scenes = preload("res://data/narrative_scenes.gd")
const Characters = preload("res://data/narrative_characters.gd")
const StoryFlow = preload("res://systems/story_flow.gd")
const Enemies = preload("res://data/enemies.gd")
const MusicManager = preload("res://systems/music_manager.gd")
const SAVE_PATH := "user://torre_story_v33_test.json"
const SEEN_PATH := "user://torre_story_v33_seen.cfg"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run_all")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func _clean() -> void:
	for path in [SAVE_PATH, SEEN_PATH]:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			var target: String = path + suffix
			if FileAccess.file_exists(target):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(target))


func _game() -> Control:
	var game: Control = Game.new()
	game.size = Vector2(1100, 760)
	game.run.save_path = SAVE_PATH
	root.add_child(game)
	game.narrative.seen_path = SEEN_PATH
	return game


func _finish_scene(game: Control) -> void:
	var scene_id: String = game.narrative.scene_id
	var steps := 0
	while game.narrative.active and game.narrative.scene_id == scene_id and steps < 50:
		var waits := 0
		while (game.narrative.interaction_locked or game.narrative._waiting_pause) and waits < 240:
			await process_frame
			waits += 1
		check(waits < 240, "Beat visual %s conclui" % scene_id)
		game.narrative.overlay.complete_text()
		game.narrative.advance()
		await process_frame
		steps += 1
	check(steps < 50, "Cena %s encerra" % scene_id)
	await process_frame
	await process_frame


func run_all() -> void:
	_clean()
	for id in ["garota_desconhecida", "figura_alada", "general_gueist"]:
		check(ResourceLoader.exists(str(Characters.get_character(id).get("portrait", ""))), "Retrato de %s existe" % id)
	var entrance: Dictionary = Scenes.get_scene("entrada_torre")
	var lines: Array = entrance.get("lines", [])
	check(lines.size() >= 20 and str(lines.back().get("text", "")).contains("passar por mim"), "Entrada inclui todos os diálogos")
	check(Scenes.get_scene("epilogo_gueist").get("lines", []).size() == 8, "Epílogo cadastrado")
	check(MusicManager.track_for_combat("combat", 10) == "A", "Sinfonia das Sombras no chefe")
	var gueist: Dictionary = Enemies.DEFINITIONS["guardiao"]
	check(gueist["name"] == "General Gueist" and gueist["max_hp"] == 220 and gueist["damage"] == 20 and gueist["special"] == "onda_sombria", "Identidade nova preserva estatísticas e especial")
	for party in [["guerreiro"], ["guerreiro", "bruxa"], ["guerreiro", "bruxa", "sacerdotisa"]]:
		_clean()
		var game := _game()
		await process_frame
		var team: Array[String] = []
		team.assign(party)
		check(game.run.new_attempt(team), "Tentativa com %d herói(s) criada" % team.size())
		game.run.attempt["floor"] = 10
		game.run.attempt["completed"] = 9
		game.run.attempt["phase"] = "combat"
		game.run.save()
		check(StoryFlow.next_scene(game.run.attempt) == "entrada_torre", "Cena prevista no andar 10")
		var coins := int(game.run.permanent["coins"])
		var xp := int(game.run.attempt["xp"])
		game.show_phase()
		check(game.narrative.active and game.narrative.scene_id == "entrada_torre", "Cena abre antes do chefe")
		check(game.combat_action_panel == null or not is_instance_valid(game.combat_action_panel), "Controles de combate ausentes")
		check(game.tower_director != null and game.tower_director.gate_open == 0.0, "Portões fechados")
		await process_frame
		game.narrative.overlay.complete_text()
		game.narrative.advance()
		check(game.narrative.interaction_locked, "Escolta bloqueia avanço durante o tween")
		await create_timer(0.9).timeout
		check(game.tower_director._sprites["girl"].visible and game.tower_director._sprites["goblin_1"].visible, "Garota e goblins aparecem")
		if team.size() == 3:
			check(bool(game.run.attempt.get("narrative_event_steps", {}).get("entrada_torre:escort", false)), "Beat concluído foi salvo")
			game.queue_free()
			await process_frame
			game = _game()
			await process_frame
			game.show_phase()
			check(game.narrative.active and game.narrative.scene_id == "entrada_torre" and game.narrative._current.get("id", "") == "entrada_torre_02", "Salvamento no meio da cena retoma da fala atual")
			check(game.tower_director._sprites["girl"].visible, "Estado visual da escolta é restaurado")
		await _finish_scene(game)
		check(not game.narrative.active and int(game.run.attempt["floor"]) == 10 and game.combat.enemy_ids.size() == 1, "Mesmo chefe inicia após diálogo")
		check(game.combat.hero_ids.size() == team.size() and not "patrulheiro" in game.combat.hero_ids, "Patrulheiro narrativo não altera equipe")
		check(game.music_manager.requested_track == "A", "Faixa A permanece no combate")
		check(bool(game.run.attempt["narrative_seen"].get("entrada_torre", false)), "Cena concluída registrada")
		check(int(game.run.permanent["coins"]) == coins and int(game.run.attempt["xp"]) == xp, "Goblins cinematográficos não concedem recompensa")
		game.menu()
		game.show_phase()
		check(not game.narrative.active, "Entrada não duplica após continuar")
		if team.size() == 1:
			game.combat.outcome = "defeat"
			game.combat_end()
			check(not game.run.has_attempt(), "Derrota encerra tentativa sem epílogo")
		elif team.size() == 2:
			game.combat.outcome = "victory"
			game.combat_end()
			check(game.narrative.active and game.narrative.scene_id == "epilogo_gueist", "Vitória abre epílogo")
			check(int(game.run.attempt["completed"]) == 10 and game.run.attempt["phase"] == "won", "Vitória real persiste antes do epílogo")
			var xp_after_victory: int = int(game.run.attempt["xp"])
			game.combat_end()
			check(int(game.run.attempt["xp"]) == xp_after_victory, "Resolução repetida não duplica XP")
			await create_timer(0.55).timeout
			game.queue_free()
			await process_frame
			game = _game()
			await process_frame
			game.show_phase()
			check(game.narrative.active and game.narrative.scene_id == "epilogo_gueist", "Epílogo salvo retoma antes da tela final")
			check(game.tower_director.gate_open == 1.0, "Portões permanecem abertos ao retomar")
			await _finish_scene(game)
			check(not game.run.has_attempt(), "Epílogo retorna à finalização")
			check(game.screen != null, "Tela final preservada")
		game.queue_free()
		await process_frame
	_clean()
	var old := RunState.new()
	old.initialize(SAVE_PATH)
	var trio: Array[String] = ["guerreiro"]
	old.new_attempt(trio)
	old.attempt["floor"] = 10
	old.attempt["completed"] = 9
	old.attempt["phase"] = "combat"
	old.attempt.erase("story_v33_enabled")
	old.save()
	var resumed := RunState.new()
	resumed.initialize(SAVE_PATH)
	check(bool(resumed.attempt["narrative_seen"].get("entrada_torre", false)), "Salvamento V32 já em combate não recebe cena retroativa")
	_clean()
	if failures.is_empty():
		print("História V33: %d verificações passaram." % checks)
		quit(0)
	else:
		print("História V33: %d falhas em %d verificações: %s" % [failures.size(), checks, "; ".join(failures)])
		quit(1)
