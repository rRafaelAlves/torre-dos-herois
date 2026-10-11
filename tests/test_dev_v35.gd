extends SceneTree

const Game = preload("res://scripts/main_v8.gd")
const Guard = preload("res://systems/dev_guard.gd")
const Ops = preload("res://systems/dev_operations.gd")
const RunState = preload("res://systems/run_state.gd")
const SaveStore = preload("res://systems/save_store.gd")
const Skills = preload("res://data/skills.gd")
const Progression = preload("res://systems/permanent_progression.gd")
const SAVE := "user://torre_dev_v35_test.json"
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
	for suffix in ["", ".dev", ".dev.baseline"]:
		for backup_suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
			var path: String = SAVE + suffix + backup_suffix
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _game() -> Control:
	var game: Control = Game.new()
	game.size = Vector2(1100, 760)
	game.run.save_path = SAVE
	root.add_child(game)
	return game


func _bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func _button_named(panel: Control, label_text: String) -> Button:
	for node in panel.find_children("*", "Button", true, false):
		if node.text == label_text:
			return node
	return null


func run_all() -> void:
	_clean()
	check(Guard.authorized() and not Guard.is_dev_path(SAVE) and Guard.is_dev_path(SAVE + ".dev"), "Editor libera DEV e caminho normal não é DEV")
	check(Guard.gate(true, true, false) and not Guard.gate(false, true, true) and not Guard.gate(false, true, false) and not Guard.gate(true, false, false), "Builds exportadas e sem debug não passam na validação")
	var game := _game()
	await process_frame
	check(game.menu_buttons.has("Jogar") and game.screen.find_child("MenuDeveloper", true, false) != null, "Menu possui botão DEV no editor")
	game.open_dev_panel()
	check(game.dev_panel != null and game.dev_panel.visible and paused, "Painel abre e pausa a árvore")
	check(game.dev_panel.find_child("DeveloperWindow", true, false) != null, "Janela DEV construída")
	game.close_dev_panel()
	check(not paused and game.dev_panel == null, "Fechar restaura pausa")
	var f9 := InputEventKey.new()
	f9.keycode = KEY_F9
	f9.pressed = true
	Input.parse_input_event(f9)
	await process_frame
	check(game.dev_panel != null and paused, "F9 abre o painel")
	Input.parse_input_event(f9)
	await process_frame
	check(game.dev_panel == null and not paused, "F9 fecha sem reabrir ou duplicar")
	game.run.permanent["coins"] = 137
	game.run.permanent["classes"]["guerreiro"]["xp"] = 240
	game.run.save()
	var progress_before: Dictionary = SaveStore.load_data(SAVE)
	check(game.dev_controller.start_copy(), "Cópia do perfil normal cria DEV")
	var progress_after: Dictionary = SaveStore.load_data(SAVE)
	var permanent_before: Dictionary = progress_before.get("permanent", {}).duplicate(true)
	var permanent_after: Dictionary = progress_after.get("permanent", {}).duplicate(true)
	permanent_before.erase("profile")
	permanent_after.erase("profile")
	var normal_before := _bytes(SAVE)
	check(game.dev_controller.active() and game.dev_badge.visible and game.run.save_path == SAVE + ".dev", "Perfil DEV indicado e isolado")
	game.open_dev_panel()
	for tab_name in game.dev_panel.TABS:
		game.dev_panel._select_tab(tab_name)
		await process_frame
		check(game.dev_panel._body.get_child_count() > 0, "Aba %s construída" % tab_name)
	game.close_dev_panel()
	check(progress_before.get("attempt", {}) == progress_after.get("attempt", {}) and permanent_before == permanent_after, "Cópia não modifica o progresso normal")
	check(game.dev_controller.set_level("guerreiro", 12), "Guerreiro sobe para nível 12")
	var warrior: Dictionary = game.run.permanent["classes"]["guerreiro"]
	check(warrior["level"] == 12 and warrior["xp"] == Ops.total_xp_for(12) and warrior["available_points"] == 11, "Curva XP e pontos consistentes")
	check(game.dev_controller.spend_attribute("guerreiro", "vitalidade"), "Investimento original funciona")
	check(game.dev_controller.set_level("guerreiro", 1), "Guerreiro pode reduzir para nível 1")
	warrior = game.run.permanent["classes"]["guerreiro"]
	check(warrior["available_points"] == 0 and Progression.invested_points(warrior["attributes"]) == 0, "Redução reembolsa investimentos")
	check(not game.dev_controller.set_level("guerreiro", 21), "Limite permanente 20 respeitado")
	check(game.dev_controller.set_level("bruxa", 12), "Bruxa sobe para nível 12")
	check(game.dev_controller.set_special("bruxa", "vampirismo_arcano", "force"), "Vampirismo forçado sem custo")
	check(int(game.run.permanent["classes"]["bruxa"]["available_points"]) == 11, "Forçar especial não consome pontos")
	check(game.dev_controller.set_level("bruxa", 3), "Nível pode ser reduzido")
	check("vampirismo_arcano" in game.run.permanent["dev_forced_specials"]["bruxa"], "Especial forçado persiste abaixo do requisito")
	check(game.dev_controller.set_special("bruxa", "vampirismo_arcano", "block"), "Especial forçado pode ser bloqueado")
	check(not "vampirismo_arcano" in game.run.permanent["dev_forced_specials"]["bruxa"], "Bloqueio remove liberação forçada")
	check(game.dev_controller.set_special("bruxa", "vampirismo_arcano", "force"), "Especial pode ser forçado abaixo do requisito")
	check(not game.dev_controller.set_special("bruxa", "maldicao_coletiva", "buy"), "Compra normal respeita requisito de nível")
	check(game.dev_controller.set_level("guerreiro", 6), "Classe preparada para compra normal")
	check(game.dev_controller.set_special("guerreiro", "golpe_carrasco", "buy"), "Compra normal usa sistema existente")
	check(int(game.run.permanent["classes"]["guerreiro"]["available_points"]) == 3, "Compra normal desconta dois pontos")
	check(game.dev_controller.set_special("guerreiro", "golpe_carrasco", "block") and int(game.run.permanent["classes"]["guerreiro"]["available_points"]) == 5, "Bloqueio devolve pontos comprados")
	var solo: Array[String] = ["bruxa"]
	check(game.dev_controller.set_team(solo, false), "Equipe solo montada")
	check("vampirismo_arcano" in game.combat.fighters["bruxa"]["unlocked_specials"], "Especial forçado entra no combate")
	var saved_dev := RunState.new()
	saved_dev.initialize(SAVE + ".dev")
	check("vampirismo_arcano" in saved_dev.attempt["heroes"][0]["unlocked_specials"], "Habilidade forçada persiste no perfil DEV")
	check(game.dev_controller.jump_floor(5, true, false), "Salto ao andar 5")
	check(int(game.run.attempt["floor"]) == 5 and int(game.run.attempt["completed"]) == 4 and game.combat.enemy_ids.size() > 0, "Andar 5 usa encontro real")
	check(game.dev_controller.jump_floor(10, true, false), "Salto ao chefe")
	check(game.combat.enemy_ids == ["guardiao"] and game.music_manager.requested_track == "A", "Chefe e trilha A preservados")
	check(game.dev_controller.jump_floor(1, false, false), "Retorno ao andar 1 sem bônus")
	check(game.run.attempt["relics"].is_empty() and int(game.run.attempt["level"]) == 1, "Salto limpo não concede recompensas")
	var team: Array[String] = ["guerreiro", "bruxa", "sacerdotisa"]
	check(game.dev_controller.set_team(team, false), "Equipe de três montada")
	game.open_dev_panel()
	game.dev_panel.selected_fighter = "guerreiro"
	game.dev_panel._select_tab("Combate")
	var hp_button := _button_named(game.dev_panel, "Definir PV")
	var hp_fields: Array[Node] = game.dev_panel._body.find_children("*", "SpinBox", true, false)
	check(hp_button != null and not hp_fields.is_empty(), "Controles de PV do combate disponíveis")
	if hp_button != null and not hp_fields.is_empty():
		hp_fields[0].value = 5
		hp_button.pressed.emit()
		check(int(game.combat.fighters["guerreiro"]["hp"]) == 5, "Clique em Definir PV atualiza o combate")
	game.dev_panel.selected_fighter = game.combat.enemy_ids[0]
	game.dev_panel._select_tab("Combate")
	hp_button = _button_named(game.dev_panel, "Definir PV")
	hp_fields = game.dev_panel._body.find_children("*", "SpinBox", true, false)
	if hp_button != null and not hp_fields.is_empty():
		hp_fields[0].value = 1
		hp_button.pressed.emit()
		check(int(game.combat.fighters[game.combat.enemy_ids[0]]["hp"]) == 1, "Clique em Definir PV funciona para inimigo")
	game.close_dev_panel()
	game.menu()
	check(game.combat_cards.is_empty() and game.arena_cards.is_empty(), "Sair da arena limpa referências visuais antigas")
	game.open_dev_panel()
	game.dev_panel.selected_fighter = "guerreiro"
	game.dev_panel._select_tab("Combate")
	hp_button = _button_named(game.dev_panel, "Definir PV")
	hp_fields = game.dev_panel._body.find_children("*", "SpinBox", true, false)
	if hp_button != null and not hp_fields.is_empty():
		hp_fields[0].value = 7
		hp_button.pressed.emit()
		check(int(game.combat.fighters["guerreiro"]["hp"]) == 7, "Definir PV após sair da arena não acessa interface antiga")
	game.close_dev_panel()
	game.open_combat()
	check(int(game.combat.fighters["guerreiro"]["hp"]) == 7, "PV editado fora da arena aparece ao reabrir combate")
	check(int(game.combat.fighters[game.combat.enemy_ids[0]]["hp"]) == 1, "PV editado do inimigo persiste ao reabrir combate")
	check(game.dev_controller.set_temporary(6, 35), "Nível temporário ajustado")
	check(game.dev_controller.set_card("bruxa", "robusto", 3), "Carta nível III aplicada")
	check(game.dev_controller.set_relic("medalhao_vital", "", true), "Relíquia existente adicionada")
	check(int(game.run.attempt["heroes"][1]["cards"]["robusto"]) == 3 and game.run.attempt["relics"].size() == 1, "Build temporária permanece válida")
	check(game.dev_controller.edit_fighter("guerreiro", "hp", 5), "PV de aliado editados")
	check(game.dev_controller.edit_fighter("bruxa", "mana", 0), "Mana editada")
	check(game.dev_controller.set_condition("sacerdotisa", "veneno"), "Veneno aplicado pelas regras")
	check(game.dev_controller.set_condition("sacerdotisa", "fraqueza"), "Fraqueza aplicada pelas regras")
	check(game.dev_controller.set_condition("bruxa", "downed"), "Herói caído configurado")
	check(game.dev_controller.restore_resources(), "Equipe recuperada")
	check(game.dev_controller.clear_negative_effects() and game.dev_controller.reset_cooldowns(), "Efeitos e recargas restaurados")
	check(game.dev_controller.restart_combat(), "Combate reiniciado")
	check(game.dev_controller.clear_temporary(), "Bônus temporários removidos")
	check(game.run.attempt["relics"].is_empty() and game.run.attempt["heroes"][1]["cards"].is_empty(), "Limpeza recalcula build")
	check(game.dev_controller.preview_scene("encontro_comerciante"), "Comerciante abre em prévia")
	check(game.narrative.active and game.narrative.scene_id == "encontro_comerciante", "Cena oficial exibida")
	game.narrative.finish()
	await process_frame
	await process_frame
	check(game.run.attempt["phase"] == "combat" and not game.narrative.active, "Prévia retorna sem progresso")
	game.close_dev_panel()
	var completed_before: int = int(game.run.attempt["completed"])
	check(game.dev_controller.preview_scene("entrada_torre"), "Cutscene do andar 10 abre manualmente")
	check(game.narrative.active and game.narrative.scene_id == "entrada_torre", "Roteiro V33 reaproveitado")
	game.narrative.finish(false)
	await process_frame
	await process_frame
	check(int(game.run.attempt["completed"]) == completed_before, "Prévia V33 não dá progresso")
	game.close_dev_panel()
	check(game.dev_controller.preview_scene("ressurreicao_primeira"), "Cena da garota abre em prévia")
	check(game.narrative.active and game.narrative.overlay.presentation == "resurrection", "Tema de derrota reaproveitado")
	game.narrative.finish(false)
	await process_frame
	await process_frame
	game.close_dev_panel()
	check(game.dev_controller.request_track("B") and game.music_manager.requested_track == "B", "Faixa B testável")
	check(game.dev_controller.restart_track(), "Música de teste reiniciada")
	check(game.dev_controller.stop_track() and game.music_manager.current_track == "", "Música de teste interrompida")
	check(game.dev_controller.restore_track(), "Trilha contextual restaurada")
	check(game.dev_controller.play_sfx("heal"), "SFX existente reproduzível")
	check(game.dev_controller.force_result("victory", false), "Prévia de vitória sem recompensa")
	check(game.run.has_attempt() and int(game.run.attempt["completed"]) == completed_before, "Prévia não fecha tentativa nem duplica XP")
	game.show_phase()
	check(game.dev_controller.force_result("defeat", true), "Derrota completa no perfil DEV")
	check(not game.run.has_attempt() and int(game.run.permanent["stats"]["losses"]) == 1, "Derrota DEV contabilizada só no perfil de teste")
	check(not game.dev_controller.force_result("defeat", true), "Resultado não pode ser aplicado duas vezes")
	var narrative_before_preview: Dictionary = game.run.permanent["narrative"].duplicate(true)
	check(game.dev_controller.preview_scene("ressurreicao_primeira"), "Cena da garota pode ser revista no painel DEV")
	check(game.narrative.active and game.narrative.scene_id == "ressurreicao_primeira", "Prévia da garota reutiliza a cena oficial")
	game.narrative.finish(false)
	await process_frame
	await process_frame
	check(game.run.permanent["narrative"] == narrative_before_preview, "Prévia DEV não altera histórico narrativo permanente")
	check(game.dev_controller.preset("witch12"), "Predefinição Bruxa nível 12")
	check(int(game.run.permanent["classes"]["bruxa"]["level"]) == 12 and int(game.run.attempt["floor"]) == 10, "Predefinição Bruxa prepara Gueist")
	check(game.dev_controller.preset("support"), "Predefinição suporte")
	check(game.combat.fighters["bruxa"]["state"] == "downed" and int(game.combat.fighters["guerreiro"]["hp"]) < int(game.combat.fighters["guerreiro"]["max_hp"]), "Suporte prepara cura e reanimação")
	check(game.dev_controller.preset("boss") and game.combat.enemy_ids == ["guardiao"], "Predefinição chefe final")
	check(game.dev_controller.force_result("victory", true), "Vitória completa no chefe DEV")
	check(game.narrative.active and game.narrative.scene_id == "epilogo_gueist", "Vitória DEV preserva epílogo")
	game.narrative.finish()
	await process_frame
	await process_frame
	check(int(game.run.permanent["stats"]["wins"]) == 1, "Vitória DEV computada uma vez")
	check(not game.dev_controller.force_result("victory", true), "Vitória repetida é recusada")
	check(game.dev_controller.preset("full") and game.combat.hero_ids.size() == 3, "Predefinição equipe completa")
	check(game.dev_controller.preset("defeat") and game.combat.hero_ids.size() == 1, "Predefinição derrota")
	game.open_dev_panel()
	game.dev_panel._select_tab("Predefinições")
	var preset_button := _button_named(game.dev_panel, "Equipe completa · combate comum")
	check(preset_button != null, "Botão de predefinição construído")
	if preset_button != null:
		preset_button.pressed.emit()
		check(game.combat.hero_ids.size() == 3 and int(game.run.attempt["floor"]) == 3, "Botão de predefinição usa cenário correspondente")
	game.close_dev_panel()
	check(game.dev_controller.restore_initial(), "Estado inicial DEV restaurado")
	check(int(game.run.permanent["coins"]) == 137 and not game.run.has_attempt(), "Restauração volta à cópia inicial")
	check(game.dev_controller.reset_blank(), "Perfil DEV vazio reiniciado")
	check(int(game.run.permanent["coins"]) == 0, "Reinício DEV não traz moedas reais")
	check(game.dev_controller.return_normal(), "Retorno ao perfil normal")
	check(game.run.save_path == SAVE and int(game.run.permanent["coins"]) == 137 and not game.dev_badge.visible, "Perfil normal idêntico")
	check(_bytes(SAVE) == normal_before, "Arquivo normal intacto após testes")
	game.close_dev_panel()
	paused = false
	game.queue_free()
	await process_frame
	var reopened := _game()
	await process_frame
	check(reopened.dev_controller.profile.has_test_profile() and not reopened.dev_controller.active(), "DEV persiste separado após reabrir")
	check(reopened.dev_controller.resume(), "Perfil DEV pode ser retomado")
	check(int(reopened.run.permanent["coins"]) == 0 and reopened.run.save_path == SAVE + ".dev", "Retomada usa apenas dados DEV")
	check(reopened.dev_controller.return_normal(), "Retorno após reabrir mantém perfil normal")
	var normal_team: Array[String] = ["guerreiro"]
	check(reopened.run.new_attempt(normal_team) and reopened.run.begin_floor(), "Tentativa legítima temporária preparada")
	var normal_with_attempt := _bytes(SAVE)
	check(reopened.dev_controller.start_copy() and reopened.run.has_attempt(), "Cópia DEV inclui tentativa em andamento")
	normal_with_attempt = _bytes(SAVE)
	check(reopened.dev_controller.jump_floor(5), "Tentativa copiada pode ser alterada no DEV")
	check(reopened.dev_controller.return_normal() and int(reopened.run.attempt["floor"]) == 1, "Tentativa normal recuperada no andar original")
	check(_bytes(SAVE) == normal_with_attempt, "Arquivo da tentativa normal permanece idêntico")
	reopened.close_dev_panel()
	paused = false
	reopened.queue_free()
	await process_frame
	await process_frame
	await process_frame
	_clean()
	if failures.is_empty():
		print("Modo DEV V35: %d verificações passaram." % checks)
		quit(0)
	else:
		print("Modo DEV V35: %d falhas em %d verificações: %s" % [failures.size(), checks, "; ".join(failures)])
		quit(1)
