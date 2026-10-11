extends SceneTree

const Game = preload("res://scripts/main_v8.gd")
const RunState = preload("res://systems/run_state.gd")
const StoryFlow = preload("res://systems/story_flow.gd")
const Rules = preload("res://systems/combat_rules.gd")
const SAVE := "user://torre_camp_v37_test.json"
const SEEN := "user://torre_camp_v37_seen.cfg"

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


func _prepare_floor_five(game: Control) -> Dictionary:
	var team: Array[String] = ["guerreiro", "bruxa"]
	check(game.run.new_attempt(team), "Tentativa criada")
	var relic_uid: String = game.run.grant_relic("pedra_arcana", "temporary")
	check(game.run.equip_relic(relic_uid, "bruxa"), "Relíquia temporária equipada antes do andar 5")
	game.run.attempt["floor"] = 5
	game.run.attempt["completed"] = 4
	game.run.attempt["phase"] = "combat"
	game.run.attempt["heroes"][0]["hp"] = 67
	game.run.attempt["heroes"][1]["mana"] = 12
	for hero in game.run.attempt["heroes"]:
		Rules.recalculate(hero, int(game.run.attempt["level"]), game.run.attempt["relics"])
	check(game.run.save(), "Estado do andar 5 salvo")
	return {"heroes": game.run.attempt["heroes"].duplicate(true), "relics": game.run.attempt["relics"].duplicate(true), "hero_ids": game.run.attempt["hero_ids"].duplicate(true)}


func _advance_to_invitation(game: Control) -> void:
	var limit := 0
	while game.narrative.active and str(game.narrative._current.get("id", "")) != "convite_acampamento" and limit < 20:
		game.narrative.overlay.complete_text()
		game.narrative.advance()
		await process_frame
		limit += 1
	check(limit < 20 and game.narrative.active, "Convite alcançado")
	check(game.narrative.overlay._body.text == "Tenho algumas mercadorias interessantes no meu acampamento, não muito longe daqui. Gostariam de dar uma olhada?", "Convite exibido")
	game.narrative.overlay.complete_text()
	check(game.narrative.overlay._choices.visible and game.narrative.overlay._choices.get_child_count() == 3, "Três respostas disponíveis")


func _choose(game: Control, index: int) -> void:
	(game.narrative.overlay._choices.get_child(index) as Button).pressed.emit()
	await process_frame
	await process_frame


func _assert_preserved(game: Control, snapshot: Dictionary) -> void:
	var heroes_preserved: bool = game.run.attempt["heroes"].size() == snapshot["heroes"].size()
	if heroes_preserved:
		for index in game.run.attempt["heroes"].size():
			var actual: Dictionary = game.run.attempt["heroes"][index]
			var original: Dictionary = snapshot["heroes"][index]
			for field in ["id", "hp", "mana", "cards", "state"]:
				if actual.get(field) != original.get(field):
					heroes_preserved = false
	check(heroes_preserved, "PV, mana e cartas preservados")
	check(game.run.attempt["relics"] == snapshot["relics"], "Relíquias preservadas")
	check(game.run.attempt["hero_ids"] == snapshot["hero_ids"], "Equipe preservada")
	check(int(game.run.attempt["floor"]) == 5 and int(game.run.attempt["completed"]) == 4 and game.run.attempt["phase"] == "combat", "Andar e progresso preservados")


func run_all() -> void:
	_clean()
	var game := _game()
	await process_frame
	var snapshot := _prepare_floor_five(game)
	game._enter_story_or_combat()
	check(game.narrative.active and game.narrative.scene_id == "encontro_comerciante", "Encontro do comerciante antes do andar 5")
	await _advance_to_invitation(game)
	await _choose(game, 0)
	check(not game.narrative.active and game.screen.find_child("MerchantCamp", true, false) != null, "Aceitar abre o acampamento")
	check(game.run.attempt["merchant_camp_status"] == "visiting", "Visita registrada no save")
	_assert_preserved(game, snapshot)
	var camp: Control = game.screen.find_child("MerchantCamp", true, false)
	(camp.find_child("TentHotspot", true, false) as Button).pressed.emit()
	var options: PanelContainer = camp.find_child("MerchantInteractionMenu", true, false)
	check(options.visible, "Clique na barraca abre o menu")
	(options.get_child(0).get_child(1) as Button).pressed.emit()
	(options.get_child(0).get_child(1) as Button).pressed.emit()
	check(camp.find_child("MerchantCampNotice", true, false).visible, "Conversar mostra aviso temporário")
	(camp.find_child("MerchantHotspot", true, false) as Button).pressed.emit()
	game.run.permanent["coins"] = 100000
	check(game.run.save(), "Saldo preparado para validar compra na interface")
	for option in options.get_child(0).get_children():
		if option is Button and option.text == "Ver mercadorias":
			option.pressed.emit()
			break
	check(game.screen.find_child("MerchantShopScroll", true, false) != null, "Ver mercadorias abre a loja integrada ao acampamento")
	check(game.run.attempt.get("merchant_shop", {}).get("offers", []).size() == 6, "Estoque da loja é persistido ao entrar no acampamento")
	var buy_button := game.screen.find_child("MerchantBuy_0_temporary", true, false) as Button
	check(buy_button != null and not buy_button.disabled, "Oferta possui compra temporária na interface")
	if buy_button != null:
		buy_button.pressed.emit()
	check(bool(game.run.attempt["merchant_shop"]["offers"][0]["sold"]), "Interface confirma compra e marca a oferta vendida")
	var back_button := game.screen.find_child("MerchantShopBack", true, false) as Button
	check(back_button != null, "Loja permite voltar ao acampamento")
	if back_button != null:
		back_button.pressed.emit()
	camp = game.screen.find_child("MerchantCamp", true, false)
	check(camp != null and camp.find_child("CampfireAnimation", true, false) != null, "Retorno da loja preserva o acampamento")
	game.queue_free()
	await process_frame
	game = _game()
	await process_frame
	game.show_phase()
	check(game.screen.find_child("MerchantCamp", true, false) != null and not game.narrative.active, "Recarregar retoma acampamento sem repetir convite")
	camp = game.screen.find_child("MerchantCamp", true, false)
	(camp.find_child("TentHotspot", true, false) as Button).pressed.emit()
	options = camp.find_child("MerchantInteractionMenu", true, false)
	for option in options.get_child(0).get_children():
		if option is Button and option.text == "Retornar à jornada":
			option.pressed.emit()
			break
	await process_frame
	check(game.run.attempt["merchant_camp_status"] == "done" and game.combat.order.size() > 0, "Sair inicia combate do andar 5")
	_assert_preserved(game, snapshot)
	game.queue_free()
	await process_frame

	_clean()
	game = _game()
	await process_frame
	snapshot = _prepare_floor_five(game)
	game._enter_story_or_combat()
	await _advance_to_invitation(game)
	await _choose(game, 2)
	check(game.run.attempt["merchant_camp_status"] == "declined" and game.combat.order.size() > 0, "Recusar segue direto para o combate")
	check(game.screen.find_child("MerchantCamp", true, false) == null, "Recusa não abre acampamento")
	_assert_preserved(game, snapshot)
	game.queue_free()
	await process_frame

	_clean()
	game = _game()
	await process_frame
	snapshot = _prepare_floor_five(game)
	game._enter_story_or_combat()
	await _advance_to_invitation(game)
	await _choose(game, 1)
	check(game.narrative.active and game.narrative._current.get("id", "") == "duvida_acampamento", "Desconfiança recebe resposta misteriosa")
	game.narrative.overlay.complete_text()
	check(game.narrative.overlay._choices.get_child_count() == 2, "Após desconfiança é possível aceitar ou recusar")
	await _choose(game, 0)
	check(game.screen.find_child("MerchantCamp", true, false) != null, "Aceitar após desconfiança abre acampamento")
	_assert_preserved(game, snapshot)
	game.queue_free()
	await process_frame

	_clean()
	game = _game()
	await process_frame
	snapshot = _prepare_floor_five(game)
	game._enter_story_or_combat()
	await _advance_to_invitation(game)
	game.queue_free()
	await process_frame
	game = _game()
	await process_frame
	game.show_phase()
	check(game.narrative.active and game.narrative._current.get("id", "") == "convite_acampamento", "Carregar durante o convite retoma a escolha")
	game.narrative.overlay.complete_text()
	await _choose(game, 1)
	check(game.narrative.active and game.narrative._current.get("id", "") == "duvida_acampamento", "Desconfiança permanece após carregar")
	game.narrative.overlay.complete_text()
	await _choose(game, 1)
	check(game.run.attempt["merchant_camp_status"] == "declined" and game.combat.order.size() > 0, "Recusar após desconfiança segue ao andar 5")
	_assert_preserved(game, snapshot)
	game.queue_free()
	await process_frame

	_clean()
	var legacy := RunState.new()
	legacy.initialize(SAVE)
	var team: Array[String] = ["guerreiro"]
	legacy.new_attempt(team)
	legacy.attempt["floor"] = 5
	legacy.attempt["completed"] = 4
	legacy.attempt["phase"] = "combat"
	legacy.attempt["narrative_seen"]["encontro_comerciante"] = true
	legacy.attempt.erase("merchant_camp_status")
	legacy.save()
	var loaded := RunState.new()
	loaded.initialize(SAVE)
	check(StoryFlow.next_scene(loaded.attempt) == "" and str(loaded.attempt.get("merchant_camp_status", "")) == "", "Save antigo não repete convite")
	_clean()
	if failures.is_empty():
		print("Acampamento V37: %d verificações passaram." % checks)
		quit(0)
	else:
		print("Acampamento V37: %d falhas em %d verificações: %s" % [failures.size(), checks, "; ".join(failures)])
		quit(1)
