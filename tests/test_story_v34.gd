extends SceneTree

const Game = preload("res://scripts/main_v8.gd")
const RunState = preload("res://systems/run_state.gd")
const ResurrectionFlow = preload("res://systems/resurrection_flow.gd")
const SAVE := "user://torre_story_v34_test.json"
const SEEN := "user://torre_story_v34_seen.cfg"
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
	for path in [SAVE, SEEN]:
		for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			var target: String = path + suffix
			if FileAccess.file_exists(target):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(target))


func _game() -> Control:
	var game: Control = Game.new()
	game.size = Vector2(1100, 760)
	game.run.save_path = SAVE
	root.add_child(game)
	game.narrative.seen_path = SEEN
	return game


func _finish_dialogue(game: Control) -> void:
	var original: String = game.narrative.scene_id
	var count := 0
	while game.narrative.active and game.narrative.scene_id == original and count < 20:
		var waits := 0
		while (game.narrative._waiting_pause or game.narrative.interaction_locked) and waits < 180:
			await process_frame
			waits += 1
		check(waits < 180, "Pausa da voz conclui")
		if not game.narrative.active:
			break
		game.narrative.overlay.complete_text()
		game.narrative.advance()
		await process_frame
		count += 1
	check(count < 20, "Diálogo da voz encerra")
	await create_timer(0.55).timeout


func _defeat(game: Control, team: Array[String], completed: int = 2) -> void:
	check(game.run.new_attempt(team), "Tentativa criada")
	game.run.attempt["floor"] = completed + 1
	game.run.attempt["completed"] = completed
	game.run.attempt["phase"] = "combat"
	game.run.save()
	var summary: Dictionary = game._finish_attempt("defeat")
	game.show_summary(summary)
	check(not game.run.has_attempt() and game.screen.find_child("OutcomeNewAttempt", true, false) != null, "Resultado preservado antes do retorno")


func run_all() -> void:
	_clean()
	check(ResurrectionFlow.choose_message(3, "", 0) != "rare", "Rara bloqueada nas primeiras derrotas")
	check(ResurrectionFlow.choose_message(4, "", 0) == "rare", "Rara habilitada após quatro derrotas")
	check(ResurrectionFlow.choose_message(5, "rare", 0) != "rare", "Rara não repete imediatamente")
	for id in ResurrectionFlow.COMMON:
		check(ResurrectionFlow.choose_message(5, id, 5) != id, "Mensagem %s não repete consecutivamente" % id)
	for party in [["guerreiro"], ["guerreiro", "bruxa"], ["guerreiro", "bruxa", "sacerdotisa"]]:
		_clean()
		var game := _game()
		await process_frame
		var team: Array[String] = []
		team.assign(party)
		_defeat(game, team)
		var coins := int(game.run.permanent["coins"])
		var level := int(game.run.permanent["classes"]["guerreiro"]["level"])
		var xp := int(game.run.permanent["classes"]["guerreiro"]["xp"])
		var attrs: Dictionary = game.run.permanent["classes"]["guerreiro"]["attributes"].duplicate(true)
		var skills: Array = game.run.permanent["classes"]["guerreiro"]["unlocked_specials"].duplicate(true)
		var volume: float = game.audio_manager.volume_percent("Music")
		game.screen.find_child("OutcomeNewAttempt", true, false).pressed.emit()
		check(game.narrative.active and game.narrative.scene_id == "ressurreicao_primeira", "Primeira derrota abre mensagem fixa")
		check(not game.run.has_attempt() and game.run.has_pending_resurrection(), "Nova tentativa não inicia durante o diálogo")
		check(game.narrative.overlay._name_label.text == "GAROTA DESCONHECIDA", "Nome misterioso aparece")
		check(not game.narrative.overlay._portrait.visible and not game.narrative.overlay._silhouette.visible, "Imagem da garota permanece oculta")
		check(game.narrative.overlay._body.text == "Ainda não chegou o fim para você, herói...", "Primeira fala literal")
		check(game.resurrection_background != null and game.resurrection_background.color.r < 0.03, "Fundo escuro")
		check(game.audio_manager.music_ducked and game.audio_manager.volume_percent("Music") == volume, "Música reduzida sem mudar preferência")
		if team.size() == 1:
			game.narrative.overlay.complete_text()
			game.narrative.advance()
			await create_timer(0.58).timeout
			check(game.narrative._current.get("id", "") == "ressurreicao_primeira_02", "Segunda fala após pausa")
			game.queue_free()
			await process_frame
			game = _game()
			await process_frame
			check(game.run.has_pending_resurrection() and int(game.run.permanent["stats"]["losses"]) == 1, "Derrota e cena pendente persistem")
			check(not game.menu_buttons["Continuar"].disabled, "Continuar habilitado após recarga")
			game.menu_buttons["Continuar"].pressed.emit()
			check(game.narrative.active and game.narrative._current.get("id", "") == "ressurreicao_primeira_02", "Recarga retoma a fala atual")
		if team.size() == 2:
			game.narrative.overlay._skip_button.pressed.emit()
			check(not game.narrative.active and game.run.has_pending_resurrection(), "Menu sai sem perder cena")
			game.menu_buttons["Continuar"].pressed.emit()
			check(game.narrative.active and game.narrative.scene_id == "ressurreicao_primeira", "Continuar reabre a cena")
		await _finish_dialogue(game)
		check(not game.run.has_pending_resurrection() and bool(game.run.permanent["narrative"]["resurrection_seen"]), "Primeira mensagem marcada após concluir")
		check(int(game.run.permanent["narrative"]["resurrection_count"]) == 1, "Contador narrativo atualizado uma vez")
		check(game.screen.find_child("HeroSelectionScroll", true, false) != null, "Escolha da equipe aparece após fala")
		check(int(game.run.permanent["coins"]) == coins and int(game.run.permanent["classes"]["guerreiro"]["xp"]) == xp and int(game.run.permanent["classes"]["guerreiro"]["level"]) == level, "XP e moedas preservados")
		check(game.run.permanent["classes"]["guerreiro"]["attributes"] == attrs and game.run.permanent["classes"]["guerreiro"]["unlocked_specials"] == skills, "Atributos e habilidades preservados")
		check(game.audio_manager.volume_percent("Music") == volume and not game.audio_manager.music_ducked, "Áudio restaurado")
		if team.size() == 3:
			_defeat(game, team)
			game.screen.find_child("OutcomeNewAttempt", true, false).pressed.emit()
			check(game.narrative.scene_id == "ressurreicao_alternativa", "Segunda derrota usa alternativa")
			var chosen := str(game.run.permanent["narrative"]["pending_message"])
			check(ResurrectionFlow.MESSAGES.has(chosen) and chosen != "rare", "Mensagem comum escolhida")
			await _finish_dialogue(game)
			check(int(game.run.permanent["narrative"]["resurrection_count"]) == 2 and game.run.permanent["narrative"]["last_message"] == chosen, "Última alternativa persiste")
		game.queue_free()
		await process_frame
	_clean()
	var old := RunState.new()
	old.initialize(SAVE)
	var solo: Array[String] = ["guerreiro"]
	old.new_attempt(solo)
	old.attempt["floor"] = 2
	old.attempt["completed"] = 1
	old.attempt["phase"] = "combat"
	old.end_attempt("defeat")
	old.permanent.erase("narrative")
	old.save()
	var loaded := RunState.new()
	loaded.initialize(SAVE)
	check(loaded.permanent.has("narrative") and not loaded.has_pending_resurrection(), "Save antigo recebe padrões seguros")
	check(loaded.queue_resurrection() and loaded.permanent["narrative"]["pending_message"] == "first", "Save antigo recebe primeira fala sem perder derrota")
	_clean()
	var victory_game := _game()
	await process_frame
	check(victory_game.run.new_attempt(solo), "Tentativa para vitória criada")
	victory_game.run.attempt["floor"] = 10
	victory_game.run.attempt["completed"] = 10
	victory_game.run.attempt["phase"] = "won"
	var victory_summary: Dictionary = victory_game._finish_attempt("victory")
	victory_game.show_summary(victory_summary)
	victory_game.screen.find_child("OutcomeNewAttempt", true, false).pressed.emit()
	check(victory_game.narrative.active and victory_game.run.has_pending_resurrection(), "Qualquer destino após o fim da expedição mostra a garota")
	await _finish_dialogue(victory_game)
	check(not victory_game.run.has_pending_resurrection(), "Mensagem após vitória é concluída antes da navegação")
	check(victory_game.screen.find_child("HeroSelectionScroll", true, false) != null, "Vitória continua para seleção normal")
	victory_game.queue_free()
	await process_frame
	_clean()
	if failures.is_empty():
		print("História V34: %d verificações passaram." % checks)
		quit(0)
	else:
		print("História V34: %d falhas em %d verificações: %s" % [failures.size(), checks, "; ".join(failures)])
		quit(1)
