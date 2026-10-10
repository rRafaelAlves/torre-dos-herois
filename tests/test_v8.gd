extends SceneTree

const Heroes = preload("res://data/heroes.gd")
const Enemies = preload("res://data/enemies.gd")
const CombatSprites = preload("res://data/combat_sprites.gd")
const CombatIcons = preload("res://data/combat_icons.gd")
const Tower = preload("res://data/tower.gd")
const Cards = preload("res://data/cards.gd")
const Relics = preload("res://data/relics.gd")
const StateEffects = preload("res://systems/state_effects.gd")
const Rules = preload("res://systems/combat_rules.gd")
const RunState = preload("res://systems/run_state.gd")
const CombatEngine = preload("res://systems/combat_engine.gd")
const Game = preload("res://scripts/main_v8.gd")
const Progression = preload("res://systems/permanent_progression.gd")
const SaveStore = preload("res://systems/save_store.gd")

var failures: Array[String] = []
var checks_run: int = 0
const TEST_PATH := "user://torre_v8_test_state.json"


func _initialize() -> void:
	call_deferred("run_tests")


func check(condition: bool, message: String) -> void:
	checks_run += 1
	if not condition:
		failures.append(message)
		push_error(message)


func reset_test_file() -> void:
	var absolute: String = ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(absolute)
	if FileAccess.file_exists(TEST_PATH + ".tmp"):
		DirAccess.remove_absolute(absolute + ".tmp")


func finish_story_for_legacy_test(game: Control) -> void:
	for _index in 3:
		if not game.narrative.active:
			break
		game.narrative.finish()
		await process_frame
		await process_frame


func run_tests() -> void:
	reset_test_file()
	test_team_sizes_and_resume()
	test_damage_cards_relics_and_downed()
	test_routes_boss_and_card_effects()
	test_invalid_save()
	test_full_tower_and_permanent()
	test_highest_floor_record()
	await test_ui_enemy_first()
	await test_v14_combat_layout()
	await test_v17_battlefield_and_sprite_visuals()
	await test_v18_combat_controls()
	await test_v19_main_menu()
	await test_v20_hero_selection()
	await test_active_bonus_panel()
	test_bonus_activation_log()
	test_state_effect_store_and_weakness()
	test_poison_turns_and_defeat()
	test_skeleton_weakened_strike()
	test_enemy_intentions_and_boss_impact()
	test_v13_expanded_skills()
	test_permanent_curve_and_limits()
	test_permanent_integration_and_migration()
	await test_permanent_progression_ui()
	await test_stage_screens()
	reset_test_file()
	for child in root.get_children():
		child.free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("V26: %d verificações de regressão e recordes de andar passaram." % checks_run)
		quit(0)
	else:
		print("V26: %d falhas em %d verificações: %s" % [failures.size(), checks_run, "; ".join(failures)])
		quit(1)


func test_team_sizes_and_resume() -> void:
	for party_size in [1, 2, 3]:
		reset_test_file()
		var state = RunState.new()
		state.initialize(TEST_PATH)
		var ids: Array[String] = []
		for index in range(party_size):
			ids.append(Heroes.ORDER[index])
		check(state.new_attempt(ids), "Nova tentativa com %d heróis" % party_size)
		check(state.begin_floor(), "Iniciar andar com %d heróis" % party_size)
		var enemies: Array[Dictionary] = Tower.enemies_for(1, "", party_size)
		check(enemies.size() == party_size if party_size <= 2 else enemies.size() == 2, "Ajuste de inimigos para %d heróis" % party_size)
		var before_hp: int = int(state.attempt["heroes"][0]["hp"])
		var fight = CombatEngine.new()
		fight.start(state.attempt["heroes"], enemies)
		fight.fighters[ids[0]]["hp"] = 1
		var restored = RunState.new()
		restored.initialize(TEST_PATH)
		check(restored.has_attempt() and restored.attempt["phase"] == "combat", "Retomar combate salvo")
		check(int(restored.attempt["heroes"][0]["hp"]) == before_hp, "Retomar no início do andar")


func test_damage_cards_relics_and_downed() -> void:
	var witch: Dictionary = Rules.create_hero("bruxa", 1, [])
	var target: Dictionary = Tower.enemies_for(1, "", 3)[0]
	target["magical_resist"] = 0.5
	var normal: Dictionary = Rules.damage_packet(witch, target, 25, "magical", false, true, 1.0)
	witch["cards"]["bruxaria_luminosa"] = 1
	Rules.recalculate(witch, 1, [])
	var radiant: Dictionary = Rules.damage_packet(witch, target, 25, "magical", false, true, 1.0)
	check(int(radiant["radiant"]) > 0 and int(radiant["amount"]) > int(normal["amount"]), "Radiante ignora resistência mágica")
	var plain_crit: Dictionary = Rules.damage_packet(Rules.create_hero("guerreiro", 1, []), target, 20, "physical", true, false, 0.08)
	var warrior: Dictionary = Rules.create_hero("guerreiro", 1, [])
	warrior["cards"]["precisao"] = 1
	Rules.recalculate(warrior, 1, [])
	var boosted_crit: Dictionary = Rules.damage_packet(warrior, target, 20, "physical", true, false, 0.08)
	check(not plain_crit["critical"] and boosted_crit["critical"], "Precisão altera chance crítica")
	var basic_before: int = int(Rules.damage_packet(warrior, target, 20, "physical", true, false, 1.0)["amount"])
	Rules.recalculate(warrior, 1, [{"id": "insignia_guerreiro", "bearer": "guerreiro"}])
	var basic_after: int = int(Rules.damage_packet(warrior, target, 20, "physical", true, false, 1.0)["amount"])
	check(basic_after > basic_before, "Insígnia aumenta ataque básico")
	var medallion_hero: Dictionary = Rules.create_hero("guerreiro", 1, [{"id": "medalhao_vital", "bearer": ""}])
	check(int(medallion_hero["max_hp"]) == 110, "Medalhão aumenta PV máximos")
	var stone_witch: Dictionary = Rules.create_hero("bruxa", 1, [{"id": "pedra_arcana", "bearer": "bruxa"}])
	var stone_enemy: Dictionary = Tower.enemies_for(1, "", 3)[0]
	stone_enemy["hp"] = 100
	stone_enemy["max_hp"] = 100
	stone_enemy["initiative"] = 1
	var stone_fight = CombatEngine.new()
	stone_fight.start([stone_witch], [stone_enemy])
	check(stone_fight.act("skill", "goblin"), "Magia com Pedra Arcana")
	check(int(stone_fight.fighters["bruxa"]["mana"]) == 22, "Pedra Arcana devolve 2 mana")
	var hero_a: Dictionary = Rules.create_hero("bruxa", 1, [])
	var hero_b: Dictionary = Rules.create_hero("guerreiro", 1, [])
	var enemy: Dictionary = Tower.enemies_for(1, "", 3)[0]
	enemy["initiative"] = 1
	var fight = CombatEngine.new()
	fight.start([hero_a, hero_b], [enemy])
	fight._deal_damage("goblin", "guerreiro", 1000, "physical", false, false)
	check(fight.fighters["guerreiro"]["state"] == "downed" and int(fight.fighters["guerreiro"]["down_rounds"]) == 3, "Queda inicia prazo de três rodadas")
	check(fight.act("rescue", "guerreiro"), "Aliado socorre caído")
	check(int(fight.fighters["guerreiro"]["hp"]) == 25 and fight.rescue_used, "Socorro restaura 25% e limita uso")
	fight._deal_damage("goblin", "guerreiro", 1000, "physical", false, false)
	fight.round_number = 2
	fight._tick_downed()
	check(int(fight.fighters["guerreiro"]["down_rounds"]) == 3, "Rodada parcial não consome prazo")
	for round_value in [3, 4, 5]:
		fight.round_number = round_value
		fight._tick_downed()
	check(fight.fighters["guerreiro"]["state"] == "dead", "Caído morre após três rodadas completas")
	var priest: Dictionary = Rules.create_hero("sacerdotisa", 1, [])
	var heal_fight = CombatEngine.new()
	heal_fight.start([priest, Rules.create_hero("guerreiro", 1, [])], [enemy])
	heal_fight._deal_damage("goblin", "guerreiro", 1000, "physical", false, false)
	heal_fight.index = heal_fight.order.find("sacerdotisa")
	check(heal_fight.act("skill", "guerreiro"), "Cura reanima caído")
	check(heal_fight.fighters["guerreiro"]["state"] == "alive" and int(heal_fight.fighters["guerreiro"]["hp"]) == 25, "Cura reanima com 25% PV")
	warrior = Rules.create_hero("guerreiro", 1, [])
	warrior["cards"]["retaliacao"] = 1
	Rules.recalculate(warrior, 1, [])
	var retaliate = CombatEngine.new()
	retaliate.start([warrior, hero_a], [enemy])
	retaliate.fighters["guerreiro"]["defending"] = true
	var enemy_hp: int = int(retaliate.fighters["goblin"]["hp"])
	retaliate._deal_damage("goblin", "guerreiro", 10, "physical", false, false)
	check(int(retaliate.fighters["guerreiro"]["hp"]) == 95 and int(retaliate.fighters["goblin"]["hp"]) < enemy_hp, "Defesa e Retaliação")


func test_routes_boss_and_card_effects() -> void:
	var fort: Array[Dictionary] = Tower.enemies_for(2, "fortaleza", 3)
	var arena: Array[Dictionary] = Tower.enemies_for(2, "arena_sangrenta", 3)
	check(int(fort[0]["max_hp"]) == 85 and int(fort[0]["damage"]) == 10 and int(fort[1]["max_hp"]) == 75, "Rota Fortaleza mantém V6")
	check(int(arena[0]["max_hp"]) == 60 and int(arena[0]["damage"]) == 16 and int(arena[1]["damage"]) == 18, "Rota Arena mantém V6")
	check(int(Tower.enemies_for(3, "", 3)[0]["max_hp"]) == 80, "Caminhos se reencontram no andar 3")
	var normal_floor5: Array[Dictionary] = Tower.enemies_for(5, "", 3)
	var wall_floor5: Array[Dictionary] = Tower.enemies_for(5, "muralha", 3)
	check(float(wall_floor5[0]["physical_resist"]) > float(normal_floor5[0]["physical_resist"]) and int(wall_floor5[0]["damage"]) < int(normal_floor5[0]["damage"]), "Rota do andar 4 muda resistência e dano")
	var fury_floor8: Array[Dictionary] = Tower.enemies_for(8, "furia", 3)
	check(int(fury_floor8[0]["damage"]) > int(Tower.enemies_for(8, "", 3)[0]["damage"]), "Rota do andar 7 muda dano")
	var robust: Dictionary = Rules.create_hero("guerreiro", 1, [])
	robust["cards"]["robusto"] = 3
	Rules.recalculate(robust, 1, [])
	check(int(robust["max_hp"]) == 135 and is_equal_approx(float(robust["physical_resist"]), 0.08), "Robusto III substitui efeitos anteriores")
	var speedy: Dictionary = Rules.create_hero("bruxa", 1, [])
	speedy["cards"]["veloz"] = 1
	Rules.recalculate(speedy, 1, [])
	check(int(speedy["initiative"]) == 21, "Veloz aumenta iniciativa")
	var priest: Dictionary = Rules.create_hero("sacerdotisa", 1, [])
	priest["cards"]["graca_divina"] = 1
	Rules.recalculate(priest, 1, [])
	check(Rules.heal_amount(priest, 25) == 29, "Graça Divina aumenta cura")
	var mage: Dictionary = Rules.create_hero("feiticeiro", 1, [])
	mage["cards"]["poder_elemental"] = 1
	Rules.recalculate(mage, 1, [])
	var enemy: Dictionary = Tower.enemies_for(1, "", 3)[0]
	check(int(Rules.damage_packet(mage, enemy, 30, "magical", false, true, 1.0)["amount"]) == 33, "Poder Elemental aumenta magia")
	var ranger: Dictionary = Rules.create_hero("patrulheiro", 1, [])
	ranger["cards"]["predador"] = 1
	Rules.recalculate(ranger, 1, [])
	var full_hit: int = int(Rules.damage_packet(ranger, enemy, 12, "physical", false, true, 1.0)["amount"])
	enemy["hp"] = int(enemy["hp"]) - 1
	var wounded_hit: int = int(Rules.damage_packet(ranger, enemy, 12, "physical", false, true, 1.0)["amount"])
	check(wounded_hit > full_hit, "Predador acerta mais forte inimigo ferido")
	var boss: Dictionary = Tower.enemies_for(10, "", 3)[0]
	boss["initiative"] = 1
	var boss_fight = CombatEngine.new()
	boss_fight.start([Rules.create_hero("guerreiro", 1, []), Rules.create_hero("bruxa", 1, [])], [boss])
	boss_fight.index = boss_fight.order.find("guardiao")
	boss_fight.enemy_action_counts["guardiao"] = 2
	var boss_state: Dictionary = boss_fight.fighters["guardiao"]
	boss_state["boss_next_special"] = "onda"
	boss_fight.fighters["guardiao"] = boss_state
	boss_fight._plan_enemy_intention("guardiao")
	check(boss_fight.intention_for("guardiao").get("id", "") == "shadow_wave", "Chefe revela Onda Sombria antes de executá-la")
	check(boss_fight.act_enemy(), "Chefe executa turno")
	check(int(boss_fight.fighters["guerreiro"]["hp"]) < 100 and int(boss_fight.fighters["bruxa"]["hp"]) < 70, "Onda Sombria atinge grupo")
	var rescue_fight = CombatEngine.new()
	var last_enemy: Dictionary = Tower.enemies_for(1, "", 3)[0]
	last_enemy["hp"] = 1
	last_enemy["initiative"] = 1
	rescue_fight.start([Rules.create_hero("bruxa", 1, []), Rules.create_hero("guerreiro", 1, [])], [last_enemy])
	rescue_fight._deal_damage("goblin", "guerreiro", 1000, "physical", false, false)
	check(rescue_fight.act("attack", "goblin") and rescue_fight.outcome == "victory", "Vitória com aliado caído")
	check(rescue_fight.fighters["guerreiro"]["state"] == "alive" and int(rescue_fight.fighters["guerreiro"]["hp"]) == 1, "Caído sobrevive à vitória com 1 PV")


func test_invalid_save() -> void:
	reset_test_file()
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("arquivo inválido")
	file.close()
	var loaded = RunState.new()
	loaded.initialize(TEST_PATH)
	check(not loaded.has_attempt() and int(loaded.permanent["coins"]) == 0, "JSON inválido não trava o jogo")
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "permanent": {"coins": [], "stats": {"attempts": "erro"}}, "attempt": {"phase": "combat", "hero_ids": ["guerreiro"], "heroes": []}}))
	file.close()
	loaded.initialize(TEST_PATH)
	check(not loaded.has_attempt() and int(loaded.permanent["coins"]) == 0, "Dados estruturados inválidos são ignorados")


func test_full_tower_and_permanent() -> void:
	reset_test_file()
	var state = RunState.new()
	state.initialize(TEST_PATH)
	var ids: Array[String] = ["guerreiro", "bruxa", "sacerdotisa"]
	check(state.new_attempt(ids), "Criar tentativa completa")
	var card_rounds: int = 0
	var evolved: bool = false
	var relics_taken: int = 0
	for floor_number in range(1, 11):
		check(state.begin_floor(), "Iniciar andar %d" % floor_number)
		check(int(state.attempt["floor"]) == floor_number, "Ordem de andares")
		var heroes: Array[Dictionary] = []
		for hero in state.attempt["heroes"]:
			heroes.append(hero.duplicate(true))
		state.victory(heroes)
		if floor_number == 4:
			var saved_cards = RunState.new()
			saved_cards.initialize(TEST_PATH)
			check(saved_cards.has_attempt() and saved_cards.attempt["phase"] == "cards" and saved_cards.attempt["card_offers"] == state.attempt["card_offers"], "Retomar escolha de cartas sem novo sorteio")
		while state.attempt["phase"] == "cards":
			var hero_id: String = state.current_card_hero()
			var offers: Array = state.attempt["card_offers"][hero_id]
			check(offers.size() == 3, "Três cartas para %s" % hero_id)
			var chosen: String = offers[0]
			for hero in state.attempt["heroes"]:
				if hero["id"] == hero_id and int(hero["cards"].get(chosen, 0)) > 0:
					evolved = true
			check(state.choose_card(chosen), "Escolher carta para %s" % hero_id)
			card_rounds += 1
		if state.attempt["phase"] == "reward":
			var reward_target: String = state.attempt["hero_ids"][0]
			check(not state.choose_reward("rest", reward_target).is_empty(), "Recompensa após andar %d" % floor_number)
		if state.attempt["phase"] == "relic":
			if floor_number == 3:
				var saved_relic = RunState.new()
				saved_relic.initialize(TEST_PATH)
				check(saved_relic.has_attempt() and saved_relic.attempt["phase"] == "relic" and saved_relic.attempt["relic_options"] == state.attempt["relic_options"], "Retomar oferta de relíquia")
			var relic_id: String = state.attempt["relic_options"][0]
			var bearer: String = ""
			if Relics.DEFINITIONS[relic_id].get("bearer", false):
				for hero in state.attempt["heroes"]:
					if hero["state"] == "alive" and (not Relics.DEFINITIONS[relic_id].get("requires_mana", false) or int(hero["mana_max"]) > 0):
						bearer = hero["id"]
						break
			check(state.choose_relic(relic_id, bearer), "Escolher relíquia")
			relics_taken += 1
		if state.attempt["phase"] == "route":
			check(state.choose_route(Tower.route_after(floor_number)[0]["id"]), "Escolher rota após %d" % floor_number)
	check(card_rounds == 6 and evolved, "Cartas nos níveis 5 e 10 e evolução")
	check(relics_taken == 2, "Relíquias nos andares 3 e 6")
	check(state.attempt["phase"] == "won" and int(state.attempt["level"]) == 11, "Concluir andar 10")
	var summary: Dictionary = state.end_attempt("victory")
	check(summary["coins"] == 150 and summary["xp_per_class"] == 200, "Recompensas permanentes da vitória")
	check(state.end_attempt("victory").is_empty(), "Recompensa permanente somente uma vez")
	var reloaded = RunState.new()
	reloaded.initialize(TEST_PATH)
	check(not reloaded.has_attempt() and int(reloaded.permanent["coins"]) == 150, "Persistência permanente após reinício")
	check(int(reloaded.permanent["classes"]["guerreiro"]["level"]) == 2 and int(reloaded.permanent["classes"]["guerreiro"]["level_xp"]) == 100, "Nível permanente usa a nova curva sem perder XP excedente")
	var solo: Array[String] = ["guerreiro"]
	check(reloaded.new_attempt(solo) and int(reloaded.attempt["level"]) == 1, "Nova tentativa começa no nível 1")
	check(reloaded.begin_floor(), "Iniciar tentativa após vitória")
	var loser = CombatEngine.new()
	var defeated_hero: Dictionary = reloaded.attempt["heroes"][0].duplicate(true)
	defeated_hero["hp"] = 1
	loser.start([defeated_hero], Tower.enemies_for(1, "", 1))
	check(loser.act_enemy() and loser.outcome == "defeat", "Derrota com todos caídos")
	var defeat_summary: Dictionary = reloaded.end_attempt("defeat")
	check(defeat_summary["coins"] == 0 and int(reloaded.permanent["stats"]["attempts"]) == 2, "Encerrar derrota sem duplicar progresso")


func test_ui_enemy_first() -> void:
	reset_test_file()
	var ui_state = RunState.new()
	ui_state.initialize(TEST_PATH)
	var game = Game.new()
	game.run.save_path = TEST_PATH
	root.add_child(game)
	await process_frame
	game.run = ui_state
	game.show_selection()
	game.toggle_hero("guerreiro")
	game.new_attempt()
	await finish_story_for_legacy_test(game)
	check(game.combat.current_id() == "goblin", "Goblin começa com iniciativa maior")
	check(game.combat_cards["goblin"]["intention"].visible and game.combat_cards["goblin"]["intention"].text.contains("Ataque básico"), "Cartão do inimigo mostra sua intenção")
	await create_timer(0.5).timeout
	check(int(game.combat.fighters["guerreiro"]["hp"]) < int(game.combat.fighters["guerreiro"]["max_hp"]), "Inimigo inicial ataca automaticamente na interface")
	game.queue_free()


func test_v14_combat_layout() -> void:
	root.size = Vector2i(1100, 760)
	for team_size in [1, 2, 3]:
		reset_test_file()
		var state = RunState.new()
		state.initialize(TEST_PATH)
		var heroes: Array[String] = ["bruxa", "guerreiro", "patrulheiro"]
		heroes.resize(team_size)
		state.new_attempt(heroes)
		state.begin_floor()
		var game = Game.new()
		game.run.save_path = TEST_PATH
		root.add_child(game)
		game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await process_frame
		game.run = state
		game.open_combat()
		await process_frame
		check(game.combat_cards.size() == game.combat.fighters.size() and game.arena_cards.size() == game.combat.fighters.size(), "V14 mostra todos os combatentes com %d heróis" % team_size)
		check(game.arena_cards[heroes[0]]["panel"].global_position.x < game.arena_cards[game.combat.enemy_ids[0]]["panel"].global_position.x, "V14 posiciona heróis à esquerda e inimigos à direita")
		check(game.chips[game.combat.current_id()]["panel"].get_index() == 0, "V14 inicia a faixa de iniciativa no combatente ativo")
		check(game.chips[heroes[0]]["bar"].value == game.combat.fighters[heroes[0]]["hp"], "V14 mostra os PV reais na iniciativa")
		check(game.arena_cards[heroes[0]]["sprite"].texture == CombatSprites.side_texture_for(heroes[0]), "V17 mostra o sprite lateral com %d heróis" % team_size)
		check(game.combat_cards[heroes[0]]["sprite"].texture == CombatSprites.texture_for(heroes[0]), "V17 preserva o retrato frontal no status")
		check(game.combat_cards[heroes[0]]["panel"].get_global_rect().end.y < game.buttons["attack"].global_position.y, "V14 posiciona status acima dos comandos")
		check(game.log_box.get_global_rect().end.y <= 740.0, "V14 mantém o histórico visível na janela")
		if team_size == 3:
			game.choose_action("attack")
			await process_frame
			check(game.target_row.visible and game.log_box.get_global_rect().end.y <= 740.0, "V14 mantém alvos e histórico visíveis")
			var first_enemy: String = game.combat.enemy_ids[0]
			game.hover_target(first_enemy)
			check(game.hovered_target_id == first_enemy, "V14 destaca o alvo sob o cursor")
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			game.arena_input(click, first_enemy)
			check(int(game.combat.fighters[first_enemy]["hp"]) < int(game.combat.fighters[first_enemy]["max_hp"]), "V14 mantém seleção de alvo funcional")
			game.combat.fighters[heroes[1]]["state"] = "dead"
			game.combat.fighters[heroes[1]]["hp"] = 0
			game.combat.fighters[heroes[2]]["state"] = "downed"
			game.combat.fighters[heroes[2]]["hp"] = 0
			game.refresh_combat()
			check(not game.chips[heroes[1]]["panel"].visible and game.chips[heroes[2]]["panel"].visible, "V14 omite mortos e identifica caídos na iniciativa")
			check(game.arena_cards[heroes[1]]["sprite"].modulate != Color.WHITE and game.arena_cards[heroes[2]]["sprite"].modulate != Color.WHITE, "V15 diferencia sprites mortos e caídos")
			check(game.combat_cards[heroes[1]]["sprite"].modulate != Color.WHITE and game.combat_cards[heroes[2]]["sprite"].modulate != Color.WHITE, "V17 diferencia estados nos retratos frontais")
		game.generation += 1
		game.queue_free()
		await process_frame


func test_v17_battlefield_and_sprite_visuals() -> void:
	for fighter_id in Heroes.ORDER + Enemies.DEFINITIONS.keys():
		var sprite: Texture2D = CombatSprites.texture_for(fighter_id)
		check(sprite != null and sprite.get_size() == Vector2(24, 24), "V15 possui sprite 24x24 para %s" % fighter_id)
	for hero_id in Heroes.ORDER:
		var side_sprite: Texture2D = CombatSprites.side_texture_for(hero_id)
		check(side_sprite != null and side_sprite.get_size() == Vector2(24, 24) and side_sprite != CombatSprites.texture_for(hero_id), "V17 possui sprite lateral distinto para %s" % hero_id)
	for floor_number in [5, 10]:
		reset_test_file()
		var state = RunState.new()
		state.initialize(TEST_PATH)
		state.new_attempt(["sacerdotisa", "feiticeiro", "bruxa"])
		state.begin_floor()
		state.attempt["floor"] = floor_number
		var game = Game.new()
		game.run.save_path = TEST_PATH
		root.add_child(game)
		game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await process_frame
		game.run = state
		game.open_combat()
		await process_frame
		check(game.arena_background.texture != null and game.host.is_ancestor_of(game.arena_background) and not game.arena_stage.is_ancestor_of(game.arena_background), "V17 coloca o cenário atrás de toda a interface")
		check(game.arena_background.get_global_rect().encloses(game.host.get_global_rect()), "V18 mantém o cenário atrás de toda a área útil")
		check(game.arena_background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "V16 mantém o cenário em pixel art nítido")
		for fighter_id in game.combat.fighters:
			var portrait: TextureRect = game.arena_cards[fighter_id]["sprite"]
			var expected: Texture2D = CombatSprites.side_texture_for(fighter_id) if game.combat.hero_ids.has(fighter_id) else CombatSprites.texture_for(fighter_id)
			check(portrait.texture == expected and portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "V17 mostra %s na arena sem suavização" % fighter_id)
			check(game.arena_cards[fighter_id]["panel"].get_theme_stylebox("panel").bg_color.a < 1.0, "V16 deixa o cenário aparecer sob %s" % fighter_id)
		check(not game.enemy_hover_panel.visible, "V17 oculta os detalhes do inimigo antes do hover")
		check(game.arena_cards[game.combat.hero_ids[0]]["panel"].global_position.x < game.arena_cards[game.combat.enemy_ids[0]]["panel"].global_position.x, "V16 mantém heróis à esquerda do campo")
		check(game.log_box.get_global_rect().end.y <= 740.0, "V16 mantém histórico dentro da janela no andar %d" % floor_number)
		game.choose_action("attack")
		await process_frame
		check(game.log_box.get_global_rect().end.y <= 740.0, "V15 mantém a tela visível no andar %d com alvos abertos" % floor_number)
		var enemy_id: String = game.combat.enemy_ids[0]
		var current_before: String = game.combat.current_id()
		var round_before: int = game.combat.round_number
		game.arena_cards[enemy_id]["panel"].mouse_entered.emit()
		check(game.enemy_hover_panel.visible and game.enemy_hover_name.text == game.combat.fighters[enemy_id]["name"], "V17 mostra nome e painel ao passar o mouse")
		check(game.enemy_hover_hp.text.contains("PV") and game.enemy_hover_sprite.texture == CombatSprites.texture_for(enemy_id), "V17 mostra PV e retrato frontal do inimigo")
		check(game.enemy_hover_intention.text.contains(game.combat.intention_for(enemy_id)["name"]) and game.enemy_hover_target.text.begins_with("Alvo:"), "V17 mostra a intenção real e seu alvo")
		check(game.combat.current_id() == current_before and game.combat.round_number == round_before and game.pending_action == "attack", "V17 consulta inimigo sem alterar combate ou seleção")
		var enemy_hp_before: int = int(game.combat.fighters[enemy_id]["hp"])
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		game.arena_input(click, enemy_id)
		check(int(game.combat.fighters[enemy_id]["hp"]) < enemy_hp_before and game.pending_action == "", "V17 mantém o clique de alvo durante o hover")
		if floor_number == 5:
			StateEffects.apply(game.combat.fighters[enemy_id], "veneno")
			game.refresh_combat()
			check(game.enemy_hover_states.text.contains("Veneno"), "V17 mostra efeitos ativos na inspeção")
			game.combat.fighters[enemy_id]["hp"] = 0
			game.refresh_combat()
			check(game.enemy_hover_states.text.contains("Derrotado") and game.arena_cards[enemy_id]["sprite"].modulate != Color.WHITE, "V17 diferencia inimigos derrotados")
		game.arena_cards[enemy_id]["panel"].mouse_exited.emit()
		check(not game.enemy_hover_panel.visible, "V17 fecha a inspeção ao sair com o mouse")
		game.menu()
		check(game.arena_background == null, "V17 retira o cenário ao voltar ao menu")
		game.generation += 1
		game.queue_free()
		await process_frame


func test_v18_combat_controls() -> void:
	root.size = Vector2i(1100, 760)
	for team_size in [1, 2, 3]:
		reset_test_file()
		var state = RunState.new()
		state.initialize(TEST_PATH)
		var heroes: Array[String] = ["bruxa", "guerreiro", "patrulheiro"]
		heroes.resize(team_size)
		state.new_attempt(heroes)
		state.begin_floor()
		var game = Game.new()
		game.run.save_path = TEST_PATH
		root.add_child(game)
		game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await process_frame
		game.run = state
		game.open_combat()
		await process_frame
		check(game.skills_panel != null and not game.skills_panel.visible and not game.log_panel.visible, "V18 abre habilidades e registro recolhidos com %d heróis" % team_size)
		check(game.chips[heroes[0]]["panel"].global_position.x > game.turn_label.global_position.x + 200, "V18 situa iniciativa à direita dos dados do andar")
		for action_id in ["attack", "defend", "rescue", "skills", "bonuses"]:
			check(game.buttons[action_id].icon == CombatIcons.texture_for(action_id), "V18 usa ícone correto em %s" % action_id)
		check(game.buttons["attack"].global_position.y == game.buttons["skills"].global_position.y, "V18 alinha as cinco ações principais")
		var fighter_before: String = game.combat.current_id()
		var round_before: int = game.combat.round_number
		game.toggle_skills()
		await process_frame
		check(game.skills_panel.visible and game.buttons["skill_raio_arcano"].visible and game.buttons["skill_veneno"].visible, "V18 mostra apenas as habilidades da Bruxa")
		check(game.buttons["skill_raio_arcano"].icon == CombatIcons.texture_for("raio_arcano") and game.buttons["skill_raio_arcano"].text.contains("10 mana"), "V18 mostra ícone e custo de Raio Arcano")
		game.toggle_log()
		await process_frame
		check(game.log_panel.visible and game.log_panel.get_global_rect().end.y <= 740.0 and game.skills_panel.get_global_rect().end.y < game.log_panel.global_position.y, "V18 expande registro sem cobrir habilidades")
		game.append_log("Mensagem preservada da V18")
		game.toggle_log()
		game.toggle_log()
		check(game.log_box.get_parsed_text().contains("Mensagem preservada da V18") and game.combat.current_id() == fighter_before and game.combat.round_number == round_before, "V18 consulta habilidades e registro sem mudar o turno nem apagar mensagens")
		game.choose_action("skill:raio_arcano")
		await process_frame
		check(not game.skills_panel.visible and game.pending_action == "skill:raio_arcano" and game.target_row.visible, "V18 habilidade abre a seleção de alvo e fecha submenu")
		game.cancel_targets()
		game.close_skills()
		check(game.pending_action == "" and not game.target_row.visible and not game.skills_panel.visible, "V18 cancela escolha de alvo e fecha submenu")
		game.generation += 1
		game.queue_free()
		await process_frame


func test_v19_main_menu() -> void:
	root.size = Vector2i(1100, 760)
	reset_test_file()
	var state = RunState.new()
	state.initialize(TEST_PATH)
	var game = Game.new()
	game.run.save_path = TEST_PATH
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	game.run = state
	game.menu()
	await process_frame
	check(game.menu_background != null and game.menu_background.get_global_rect() == Rect2(Vector2.ZERO, Vector2(1100, 760)), "V19 mostra arte de capa em toda a janela")
	check(game.menu_buttons.size() == 3 and game.menu_buttons["Jogar"].get_global_rect().end.x < 550 and game.menu_buttons["Progressão"].get_global_rect().end.y < 740, "V19 mantém botões legíveis sem cobrir a torre e os heróis")
	check(game.menu_buttons["Continuar"].disabled, "V19 desabilita Continuar sem tentativa salva")
	game.menu_buttons["Jogar"].pressed.emit()
	check(game.selection_buttons.size() == 5 and game.menu_background == null, "V19 Jogar abre a seleção e remove a capa")
	game.menu()
	game.menu_buttons["Progressão"].pressed.emit()
	check(game.progression_scroll != null and game.screen.is_ancestor_of(game.progression_scroll) and game.menu_background == null, "V19 Progressão abre a tela existente sem fundo do menu")
	state.new_attempt(["bruxa"])
	state.begin_floor()
	game.menu()
	check(not game.menu_buttons["Continuar"].disabled, "V19 habilita Continuar com tentativa salva")
	game.menu_buttons["Continuar"].pressed.emit()
	await finish_story_for_legacy_test(game)
	check(game.arena_background != null and game.menu_background == null and game.run.has_attempt(), "V19 Continuar retoma o combate existente")
	game.generation += 1
	game.queue_free()
	await process_frame


func test_v20_hero_selection() -> void:
	root.size = Vector2i(1100, 760)
	reset_test_file()
	var state = RunState.new()
	state.initialize(TEST_PATH)
	var warrior_progress: Dictionary = state.permanent["classes"]["guerreiro"]
	Progression.grant_xp(warrior_progress, 520)
	for attribute_id in ["vitalidade", "poder", "agilidade", "resistencia"]:
		check(Progression.invest(warrior_progress, "guerreiro", attribute_id), "V20 investe melhoria permanente %s" % attribute_id)
	state.permanent["classes"]["guerreiro"] = warrior_progress
	var witch_progress: Dictionary = state.permanent["classes"]["bruxa"]
	Progression.grant_xp(witch_progress, 100)
	check(Progression.invest(witch_progress, "bruxa", "mana"), "V20 investe mana permanente da Bruxa")
	state.permanent["classes"]["bruxa"] = witch_progress
	var game = Game.new()
	game.run.save_path = TEST_PATH
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	game.run = state
	game.show_selection()
	await process_frame
	check(game.selection_buttons.size() == 5 and game.start_button.disabled, "V20 apresenta cinco classes e impede iniciar equipe vazia")
	check(game.menu_background == null, "V20 mantém o fundo ilustrado exclusivo do menu principal")
	var first_row_y: float = game.selection_buttons["guerreiro"].global_position.y
	var second_row_y: float = game.selection_buttons["sacerdotisa"].global_position.y
	check(game.selection_buttons["guerreiro"].global_position.x < game.selection_buttons["patrulheiro"].global_position.x and game.selection_buttons["patrulheiro"].global_position.x < game.selection_buttons["bruxa"].global_position.x and second_row_y > first_row_y, "V20 organiza três cards na primeira linha e dois na segunda")
	for hero_id in Heroes.ORDER:
		var card: Button = game.selection_buttons[hero_id]
		var portrait: TextureRect = game.selection_presentations[hero_id]["portrait"]
		check(portrait.texture == CombatSprites.texture_for(hero_id) and portrait.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "V20 usa sprite frontal nítido para %s" % hero_id)
		check(card.get_global_rect().end.y <= game.start_button.global_position.y, "V20 mantém card de %s dentro da área rolável acima dos controles" % hero_id)
		var shown_stats: Dictionary = game.selection_presentations[hero_id]["stats"]
		var expected_stats: Dictionary = Rules.create_hero(hero_id, 1, [], state.permanent["classes"][hero_id]["attributes"])
		check(shown_stats["max_hp"] == expected_stats["max_hp"] and shown_stats["damage"] == expected_stats["damage"] and shown_stats["initiative"] == expected_stats["initiative"] and shown_stats["mana_max"] == expected_stats["mana_max"] and shown_stats["physical_resist"] == expected_stats["physical_resist"] and shown_stats["magical_resist"] == expected_stats["magical_resist"], "V20 exibe valores calculados do combate para %s" % hero_id)
		for skill_widget in game.selection_presentations[hero_id]["skills"]:
			check(skill_widget["icon"].texture == CombatIcons.texture_for(skill_widget["id"]) and skill_widget["label"].tooltip_text.begins_with(skill_widget["label"].text.split(" · ")[0]), "V20 exibe ícone e descrição para habilidade de %s" % hero_id)
	var warrior: Dictionary = game.selection_presentations["guerreiro"]["stats"]
	check(game.selection_presentations["guerreiro"]["level"] == 5 and warrior["max_hp"] == 105 and warrior["damage"] == 21 and warrior["initiative"] == 13 and is_equal_approx(float(warrior["physical_resist"]), 0.01) and is_equal_approx(float(warrior["magical_resist"]), 0.01), "V20 mostra atributos permanentes finais do Guerreiro")
	var witch: Dictionary = game.selection_presentations["bruxa"]["stats"]
	check(game.selection_presentations["bruxa"]["level"] == 2 and witch["mana_max"] == 33, "V20 mostra nível e mana máxima permanente da Bruxa")
	game.selection_buttons["guerreiro"].pressed.emit()
	check(game.selected == ["guerreiro"] and not game.start_button.disabled and game.selection_presentations["guerreiro"]["status"].visible, "V20 seleciona e destaca o primeiro herói")
	game.selection_buttons["guerreiro"].pressed.emit()
	check(game.selected.is_empty() and game.start_button.disabled, "V20 permite remover seleção ao clicar novamente")
	for hero_id in ["guerreiro", "patrulheiro", "bruxa"]:
		game.selection_buttons[hero_id].pressed.emit()
	game.selection_buttons["sacerdotisa"].pressed.emit()
	check(game.selected.size() == 3 and game.selected == ["guerreiro", "patrulheiro", "bruxa"] and game.selection_team_row.get_child_count() == 3, "V20 limita equipe a três e atualiza o resumo")
	var summary_names: Array[String] = []
	for slot in game.selection_team_row.get_children():
		var summary_row: HBoxContainer = slot.get_child(0)
		for child in summary_row.get_children():
			if child is Label:
				summary_names.append(child.text)
	check(summary_names == ["Guerreiro", "Patrulheiro", "Bruxa"], "V20 resumo mostra sprites e nomes na ordem selecionada")
	game.new_attempt()
	await finish_story_for_legacy_test(game)
	check(game.run.attempt["hero_ids"] == game.selected and game.combat.hero_ids.size() == 3, "V20 inicia tentativa com a equipe escolhida")
	game.menu()
	game.show_selection()
	await process_frame
	var selection_scroll: ScrollContainer = game.screen.find_child("HeroSelectionScroll", true, false)
	check(selection_scroll != null and selection_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO and not selection_scroll.is_ancestor_of(game.start_button), "V20 usa rolagem automática e mantém ações fora da área rolável")
	for team_size in [1, 2]:
		game.menu()
		game.show_selection()
		for index in team_size:
			game.selection_buttons[Heroes.ORDER[index]].pressed.emit()
		game.new_attempt()
		await finish_story_for_legacy_test(game)
		check(game.combat.hero_ids.size() == team_size, "V20 inicia equipe com %d heróis" % team_size)
	game.menu()
	game.show_selection()
	game.screen.find_child("SelectionBack", true, false).pressed.emit()
	check(game.menu_background != null and game.selection_buttons.is_empty(), "V20 botão Voltar retorna ao menu principal")
	game.generation += 1
	game.queue_free()
	await process_frame


func test_active_bonus_panel() -> void:
	reset_test_file()
	var stage = RunState.new()
	stage.initialize(TEST_PATH)
	var ids: Array[String] = ["bruxa", "guerreiro", "patrulheiro"]
	stage.new_attempt(ids)
	stage.begin_floor()
	stage.attempt["heroes"][0]["cards"]["bruxaria_luminosa"] = 2
	stage.attempt["heroes"][2]["cards"]["predador"] = 3
	stage.attempt["heroes"][1]["cards"]["retaliacao"] = 2
	stage.attempt["relics"] = [
		{"id": "pedra_arcana", "bearer": "bruxa"},
		{"id": "insignia_guerreiro", "bearer": "guerreiro"},
		{"id": "medalhao_vital", "bearer": ""},
	]
	var game = Game.new()
	game.run.save_path = TEST_PATH
	root.add_child(game)
	await process_frame
	game.run = stage
	game.open_combat()
	check(game.buttons.has("skill_veneno") and game.buttons["skill_veneno"].text.contains("Maldição Venenosa"), "Interface mantém Raio Arcano e oferece Maldição Venenosa separadamente")
	check(game.buttons.has("skill_guarda_protetora") and game.buttons.has("skill_flecha_debilitante"), "Interface oferece alternativas do Guerreiro e Patrulheiro")
	game.combat.fighters["guerreiro"]["state"] = "dead"
	game.combat.fighters["guerreiro"]["hp"] = 0
	game.combat.fighters["patrulheiro"]["state"] = "downed"
	StateEffects.apply(game.combat.fighters["bruxa"], "veneno")
	game.refresh_combat()
	var state_chip: Button = game.combat_cards["bruxa"]["state_chips"].get_child(0)
	check(state_chip.text == "Veneno · 3T" and state_chip.tooltip_text == StateEffects.definition("veneno")["description"], "Combate exibe efeito ativo com duração e descrição consultável")
	game.choose_action("attack")
	var current_before: String = game.combat.current_id()
	var round_before: int = game.combat.round_number
	var initiative_before: int = game.combat.index
	var mana_before: int = int(game.combat.fighters["bruxa"]["mana"])
	game.open_bonus_panel()
	check(game.bonus_panel_open and game.bonus_hero_buttons.size() == 3, "Painel lista uma equipe de três, incluindo caídos e mortos")
	check(node_contains_text(game.bonus_hero_buttons["guerreiro"], "Morto") and node_contains_text(game.bonus_hero_buttons["patrulheiro"], "Caído"), "Heróis derrotados continuam consultáveis")
	game.show_bonus_hero("bruxa")
	check(node_contains_text(game.bonus_details, Cards.label("bruxaria_luminosa", 2)), "Painel apresenta carta evoluída pelo catálogo")
	check(node_contains_text(game.bonus_details, "Pedra Arcana — %s" % Relics.DEFINITIONS["pedra_arcana"]["description"]), "Painel mostra relíquia individual pelo catálogo")
	check(node_contains_text(game.bonus_details, "Medalhão Vital — %s" % Relics.DEFINITIONS["medalhao_vital"]["description"]), "Painel separa o bônus de equipe")
	check(node_contains_text(game.bonus_details, "Condição:"), "Painel explica condições de ativação")
	game.close_bonus_panel()
	for team_size in [1, 2, 3]:
		var visible_ids: Array[String] = ids.slice(0, team_size)
		game.combat.hero_ids = visible_ids
		game.open_bonus_panel()
		check(game.bonus_hero_buttons.size() == team_size, "Painel suporta equipe de %d heróis" % team_size)
		game.close_bonus_panel()
	game.combat.hero_ids = ids.duplicate()
	game.combat.fighters["bruxa"]["cards"].clear()
	stage.attempt["relics"].clear()
	game.open_bonus_panel()
	game.show_bonus_hero("bruxa")
	check(node_contains_text(game.bonus_details, "Este herói não possui cartas ou relíquias ativas."), "Painel explica quando não há bônus")
	game.close_bonus_panel()
	check(not game.bonus_panel_open and game.combat.current_id() == current_before and game.combat.round_number == round_before and game.combat.index == initiative_before and game.pending_action == "attack" and game.target_row.visible, "Fechar consulta preserva ação, seleção de alvo, rodada e iniciativa")
	check(int(game.combat.fighters["bruxa"]["mana"]) == mana_before, "Consultar bônus não altera recursos")
	game.cancel_targets()
	var enemy_id: String = "goblin" if game.combat.enemy_ids.has("goblin") else game.combat.enemy_ids[0]
	game.combat.index = game.combat.order.find(enemy_id)
	var enemy_actions_before: int = int(game.combat.enemy_action_counts.get(enemy_id, 0))
	game.open_bonus_panel()
	game.enemy_loop()
	await create_timer(0.5).timeout
	check(game.bonus_panel_open and game.combat.current_id() == enemy_id and int(game.combat.enemy_action_counts.get(enemy_id, 0)) == enemy_actions_before, "Painel pausa a IA e mantém a iniciativa consultável")
	game.close_bonus_panel()
	await create_timer(0.45).timeout
	check(int(game.combat.enemy_action_counts.get(enemy_id, 0)) > enemy_actions_before, "IA continua normalmente após fechar o painel")
	game.menu()
	game.queue_free()


func node_contains_text(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text.contains(expected):
		return true
	if node is Button and (node as Button).text.contains(expected):
		return true
	if node is RichTextLabel and (node as RichTextLabel).text.contains(expected):
		return true
	for child in node.get_children():
		if node_contains_text(child, expected):
			return true
	return false


func test_bonus_activation_log() -> void:
	var ranger: Dictionary = Rules.create_hero("patrulheiro", 1, [])
	ranger["cards"]["predador"] = 3
	Rules.recalculate(ranger, 1, [])
	var enemies: Array[Dictionary] = Tower.enemies_for(1, "", 1)
	enemies[0]["initiative"] = 1
	enemies[0]["hp"] = int(enemies[0]["max_hp"]) - 1
	var fight = CombatEngine.new()
	fight.start([ranger], enemies)
	check(fight.act("attack", enemies[0]["id"]), "Ataque para ativar Predador")
	check(_events_contain(fight.events, "Predador III ativa"), "Registro identifica ativação condicional de Predador III")
	var witch: Dictionary = Rules.create_hero("bruxa", 1, [])
	witch["cards"]["bruxaria_luminosa"] = 2
	Rules.recalculate(witch, 1, [])
	enemies = Tower.enemies_for(1, "", 1)
	enemies[0]["initiative"] = 1
	enemies[0]["hp"] = int(enemies[0]["max_hp"]) - 1
	var magic_fight = CombatEngine.new()
	magic_fight.start([witch], enemies)
	check(magic_fight.act("skill", enemies[0]["id"]), "Magia para ativar Bruxaria Luminosa")
	check(_events_contain(magic_fight.events, "Bruxaria Luminosa II converte"), "Registro identifica conversão Radiante realmente aplicada")
	var priest: Dictionary = Rules.create_hero("sacerdotisa", 1, [])
	priest["cards"]["graca_divina"] = 1
	Rules.recalculate(priest, 1, [])
	var ally: Dictionary = Rules.create_hero("guerreiro", 1, [])
	ally["hp"] = 50
	enemies = Tower.enemies_for(1, "", 2)
	for enemy in enemies:
		enemy["initiative"] = 1
	var heal_fight = CombatEngine.new()
	heal_fight.start([priest, ally], enemies)
	heal_fight.index = heal_fight.order.find("sacerdotisa")
	check(heal_fight.act("skill", "guerreiro"), "Cura para ativar Graça Divina")
	check(_events_contain(heal_fight.events, "Graça Divina I acrescenta"), "Registro identifica cura adicional efetiva")


func _events_contain(events: Array[String], expected: String) -> bool:
	for event in events:
		if event.contains(expected):
			return true
	return false


func test_state_effect_store_and_weakness() -> void:
	var fighter: Dictionary = {"state_effects": {}}
	var first: Dictionary = StateEffects.apply(fighter, "veneno")
	check(not first.is_empty() and not first["refreshed"] and int(first["effect"]["duration"]) == 3 and int(first["effect"]["intensity"]) == 8, "Aplicar Veneno usa duração e intensidade da definição")
	var renewal: Dictionary = StateEffects.apply(fighter, "veneno")
	check(renewal["refreshed"] and int(renewal["effect"]["duration"]) == 3 and int(renewal["effect"]["intensity"]) == 8, "Reaplicar Veneno renova duração sem acumular intensidade")
	StateEffects.apply(fighter, "fraqueza")
	check(StateEffects.get_all(fighter).size() == 2 and StateEffects.get_effect(fighter, "fraqueza")["description"] == StateEffects.definition("fraqueza")["description"], "Consultar mais de um efeito ativo")
	var removed: Dictionary = StateEffects.remove(fighter, "fraqueza")
	check(removed["id"] == "fraqueza" and StateEffects.get_effect(fighter, "fraqueza").is_empty(), "Remover efeito de estado")
	for _turn in range(2):
		check(StateEffects.update(fighter, "veneno").is_empty(), "Veneno permanece antes do terceiro turno próprio")
	var expired: Dictionary = StateEffects.update(fighter, "veneno")
	check(expired["id"] == "veneno" and StateEffects.get_effect(fighter, "veneno").is_empty(), "Duração expira após três turnos próprios")
	var attacker: Dictionary = Rules.create_hero("guerreiro", 1, [])
	var target: Dictionary = Tower.enemies_for(1, "", 3)[0]
	var base_hit: Dictionary = Rules.damage_packet(attacker, target, 20, "physical", true, false, 1.0)
	StateEffects.apply(attacker, "fraqueza")
	var weakened_hit: Dictionary = Rules.damage_packet(attacker, target, 20, "physical", true, false, 1.0)
	var weakened_skill: Dictionary = Rules.damage_packet(attacker, target, 25, "magical", false, true, 1.0)
	check(int(base_hit["amount"]) == 20 and int(weakened_hit["amount"]) == 15 and int(weakened_skill["amount"]) == 19, "Fraqueza reduz dano básico e mágico em 25% no cálculo central")
	StateEffects.clear(attacker)
	check(StateEffects.get_all(attacker).is_empty(), "Limpar efeitos")


func test_poison_turns_and_defeat() -> void:
	var witch: Dictionary = Rules.create_hero("bruxa", 1, [])
	var goblin: Dictionary = Tower.enemies_for(1, "", 1)[0]
	goblin["hp"] = int(goblin["max_hp"])
	goblin["initiative"] = 15
	var fight = CombatEngine.new()
	fight.start([witch], [goblin])
	var goblin_hp: int = int(goblin["hp"])
	check(fight.act("skill:maldicao_venenosa", "goblin"), "Maldição Venenosa pode ser usada")
	check(int(fight.fighters["bruxa"]["mana"]) == 22 and int(fight.fighters["goblin"]["hp"]) == goblin_hp - 8, "Maldição custa 8 mana e não causa dano imediato")
	check(int(StateEffects.get_effect(fight.fighters["goblin"], "veneno")["duration"]) == 3 and _events_contain(fight.events, "Veneno causa 8 de dano"), "Primeiro dano ocorre no início do turno envenenado")
	fight.act_enemy()
	check(int(StateEffects.get_effect(fight.fighters["goblin"], "veneno")["duration"]) == 2, "Duração avança ao fim do turno próprio, uma única vez")
	fight.act("defend")
	check(int(fight.fighters["goblin"]["hp"]) == goblin_hp - 16 and int(StateEffects.get_effect(fight.fighters["goblin"], "veneno")["duration"]) == 2, "Segundo turno próprio aplica dano")
	fight.act_enemy()
	fight.act("defend")
	check(int(fight.fighters["goblin"]["hp"]) == goblin_hp - 24 and int(StateEffects.get_effect(fight.fighters["goblin"], "veneno")["duration"]) == 1, "Terceiro turno próprio recebe dano antes de encerrar sua duração")
	fight.act_enemy()
	check(StateEffects.get_effect(fight.fighters["goblin"], "veneno").is_empty(), "Terceiro turno próprio encerra e expira Veneno")
	check(_events_contain(fight.events, "Veneno em Goblin expirou."), "Expiração aparece no registro de combate")
	var poisoned_witch: Dictionary = Rules.create_hero("bruxa", 1, [])
	poisoned_witch["hp"] = 5
	var enemy: Dictionary = Tower.enemies_for(1, "", 1)[0]
	var defeat_fight = CombatEngine.new()
	defeat_fight.start([poisoned_witch], [enemy])
	StateEffects.apply(defeat_fight.fighters["bruxa"], "veneno")
	defeat_fight.index = defeat_fight.order.find("bruxa")
	defeat_fight._begin_current_turn()
	check(defeat_fight.finished and defeat_fight.outcome == "defeat" and defeat_fight.fighters["bruxa"]["state"] == "downed", "Veneno pode derrubar o último herói e encerrar em derrota")
	check(not defeat_fight.act("defend") and int(defeat_fight.enemy_action_counts.get("goblin", 0)) == 0, "Personagem derrotado por Veneno não executa ação")
	check(StateEffects.get_all(defeat_fight.fighters["bruxa"]).is_empty(), "Fim de combate limpa efeitos de estado")
	var nearly_dead: Dictionary = Rules.create_hero("bruxa", 1, [])
	var poisoned_enemy: Dictionary = Tower.enemies_for(1, "", 1)[0]
	poisoned_enemy["hp"] = 8
	var victory_fight = CombatEngine.new()
	victory_fight.start([nearly_dead], [poisoned_enemy])
	check(victory_fight.act("skill:maldicao_venenosa", "goblin") and victory_fight.outcome == "victory", "Veneno pode derrotar um inimigo no início do turno")
	check(int(victory_fight.enemy_action_counts.get("goblin", 0)) == 0 and _events_contain(victory_fight.events, "derrotado por Veneno"), "Inimigo derrotado por Veneno não age e o histórico registra a causa")
	var next_battle = CombatEngine.new()
	var source_with_effect: Dictionary = Rules.create_hero("bruxa", 1, [])
	StateEffects.apply(source_with_effect, "veneno")
	next_battle.start([source_with_effect], [enemy])
	check(StateEffects.get_all(next_battle.fighters["bruxa"]).is_empty(), "Nova batalha não herda efeitos anteriores")


func test_skeleton_weakened_strike() -> void:
	var hero: Dictionary = Rules.create_hero("guerreiro", 1, [])
	var skeleton: Dictionary = Tower.enemies_for(1, "", 3)[1]
	skeleton["initiative"] = 1
	var fight = CombatEngine.new()
	fight.start([hero], [skeleton])
	var hero_hp: int = int(fight.fighters["guerreiro"]["hp"])
	fight.index = fight.order.find("esqueleto")
	check(fight.intention_for("esqueleto").get("id", "") == "attack", "Esqueleto revela ataque normal na primeira ação")
	check(fight.act_enemy() and StateEffects.get_effect(fight.fighters["guerreiro"], "fraqueza").is_empty(), "Primeira ação do Esqueleto é ataque normal")
	check(fight.intention_for("esqueleto").get("id", "") == "weakened_strike", "Após atacar, Esqueleto revela Golpe Enfraquecedor")
	var first_damage: int = hero_hp - int(fight.fighters["guerreiro"]["hp"])
	fight.index = fight.order.find("esqueleto")
	check(fight.act_enemy(), "Segunda ação do Esqueleto")
	var weakness: Dictionary = StateEffects.get_effect(fight.fighters["guerreiro"], "fraqueza")
	check(not weakness.is_empty() and int(weakness["duration"]) == 2 and is_equal_approx(float(weakness["intensity"]), 0.25), "Golpe Enfraquecedor aplica Fraqueza por dois turnos próprios")
	check(_events_contain(fight.events, "Golpe Enfraquecedor") and int(fight.fighters["guerreiro"]["hp"]) < hero_hp - first_damage, "Segundo golpe causa dano normal e registra a habilidade")
	check(fight.intention_for("esqueleto").get("id", "") == "attack", "Esqueleto volta a revelar ataque normal")


func test_enemy_intentions_and_boss_impact() -> void:
	var boss: Dictionary = Tower.enemies_for(10, "", 3)[0]
	boss["initiative"] = 1
	var warrior: Dictionary = Rules.create_hero("guerreiro", 1, [])
	var witch: Dictionary = Rules.create_hero("bruxa", 1, [])
	var fight = CombatEngine.new()
	fight.start([warrior, witch], [boss])
	fight.index = fight.order.find("guardiao")
	var first_intention: Dictionary = fight.intention_for("guardiao")
	check(first_intention.get("id", "") == "attack" and first_intention.get("type", "") == "Ataque", "Chefe revela sua ação inicial")
	check(fight.act_enemy() and _events_contain(fight.events, "ataca"), "Ataque planejado do chefe é executado")
	check(fight.intention_for("guardiao").get("id", "") == "prepare_impact", "Chefe revela preparação após o ataque inicial")
	fight.index = fight.order.find("guardiao")
	var hp_before_prepare: int = int(fight.fighters["guerreiro"]["hp"]) + int(fight.fighters["bruxa"]["hp"])
	check(fight.act_enemy() and _events_contain(fight.events, "prepara Impacto Devastador"), "Preparação é registrada sem dano")
	var hp_after_prepare: int = int(fight.fighters["guerreiro"]["hp"]) + int(fight.fighters["bruxa"]["hp"])
	check(hp_before_prepare == hp_after_prepare, "Preparar Impacto não causa dano")
	var impact_intention: Dictionary = fight.intention_for("guardiao")
	check(impact_intention.get("id", "") == "devastating_impact" and impact_intention.get("name", "") == "Impacto Devastador", "Impacto aparece como ação seguinte")
	var target_id: String = str(impact_intention.get("target_id", ""))
	check(not target_id.is_empty(), "Alvo do golpe preparado fica determinado junto à intenção")
	var target_hp: int = int(fight.fighters[target_id]["hp"])
	fight.index = fight.order.find("guardiao")
	check(fight.act_enemy() and _events_contain(fight.events, "Impacto Devastador"), "Chefe executa o golpe que revelou")
	var expected_damage: int = ceili(float(fight.fighters["guardiao"]["damage"]) * 1.5)
	check(target_hp - int(fight.fighters[target_id]["hp"]) == expected_damage, "Impacto causa 50% a mais de dano físico")
	check(fight.intention_for("guardiao").get("id", "") == "shadow_wave", "Após o Impacto, chefe revela Onda Sombria")
	fight.index = fight.order.find("guardiao")
	check(fight.act_enemy() and _events_contain(fight.events, "Onda Sombria"), "Chefe executa Onda Sombria revelada")
	check(fight.intention_for("guardiao").get("id", "") == "attack", "Onda Sombria é seguida por ataque básico")
	var boss_state: Dictionary = fight.fighters["guardiao"]
	boss_state["hp"] = 0
	boss_state["state"] = "dead"
	fight.fighters["guardiao"] = boss_state
	fight.index = fight.order.find("guardiao")
	check(not fight.act_enemy(), "Chefe derrotado não executa a intenção planejada")

	var target_fight = CombatEngine.new()
	var target_boss: Dictionary = Tower.enemies_for(1, "", 2)[0]
	target_fight.start([Rules.create_hero("guerreiro", 1, []), Rules.create_hero("bruxa", 1, [])], [target_boss])
	target_fight.enemy_intentions["goblin"]["target_id"] = "guerreiro"
	target_fight._deal_damage("goblin", "guerreiro", 1000, "physical", false, false)
	target_fight.index = target_fight.order.find("goblin")
	check(target_fight.act_enemy() and _events_contain(target_fight.events, "Bruxa"), "Intenção escolhe alvo vivo se o alvo previsto cair")


func test_v13_expanded_skills() -> void:
	var warrior: Dictionary = Rules.create_hero("guerreiro", 1, [])
	var ally: Dictionary = Rules.create_hero("bruxa", 1, [])
	warrior["initiative"] = 30
	var goblin: Dictionary = Tower.enemies_for(1, "", 3)[0]
	goblin["initiative"] = 1
	var guard_fight = CombatEngine.new()
	guard_fight.start([warrior, ally], [goblin])
	check(guard_fight.current_id() == "guerreiro" and guard_fight.skill_available("guarda_protetora"), "Guarda Protetora está disponível para o Guerreiro")
	check("guerreiro" in guard_fight.targets("skill:guarda_protetora") and "bruxa" in guard_fight.targets("skill:guarda_protetora"), "Guarda pode proteger a si mesmo ou um aliado vivo")
	var ally_hp: int = int(guard_fight.fighters["bruxa"]["hp"])
	check(guard_fight.act("skill:guarda_protetora", "bruxa"), "Guarda Protetora pode ser aplicada")
	check(guard_fight.skill_cooldown_remaining("guerreiro", "guarda_protetora") == 3 and float(guard_fight.fighters["bruxa"]["guard_reduction"]) == 0.4, "Guarda aplica 40% e inicia recarga individual de três turnos")
	guard_fight.index = guard_fight.order.find("guerreiro")
	check(not "bruxa" in guard_fight.targets("skill:guarda_protetora"), "Guarda não acumula no mesmo alvo")
	guard_fight.enemy_intentions["goblin"]["target_id"] = "bruxa"
	guard_fight.index = guard_fight.order.find("goblin")
	check(guard_fight.act_enemy(), "Inimigo ataca alvo protegido")
	check(ally_hp - int(guard_fight.fighters["bruxa"]["hp"]) == 6 and float(guard_fight.fighters["bruxa"]["guard_reduction"]) == 0.0, "Guarda reduz exatamente 40% e é consumida pelo próximo dano")
	check(_events_contain(guard_fight.events, "Guarda Protetora reduz"), "Consumo da Guarda fica no registro")
	for remaining in [2, 1, 0]:
		guard_fight.index = guard_fight.order.find("guerreiro")
		check(guard_fight.act("defend") and guard_fight.skill_cooldown_remaining("guerreiro", "guarda_protetora") == remaining, "Recarga da Guarda avança em turnos próprios")

	var expiring_warrior: Dictionary = Rules.create_hero("guerreiro", 1, [])
	expiring_warrior["initiative"] = 30
	var expiry_fight = CombatEngine.new()
	expiry_fight.start([expiring_warrior], [Tower.enemies_for(1, "", 1)[0]])
	check(expiry_fight.act("skill:guarda_protetora", "guerreiro"), "Guerreiro pode proteger a si mesmo")
	check(float(expiry_fight.fighters["guerreiro"]["guard_reduction"]) > 0.0, "Proteção permanece durante o turno em que foi aplicada")
	expiry_fight.index = expiry_fight.order.find("guerreiro")
	expiry_fight._begin_current_turn()
	check(float(expiry_fight.fighters["guerreiro"]["guard_reduction"]) == 0.0 and _events_contain(expiry_fight.events, "expirou"), "Guarda expira no início do próximo turno do Guerreiro")
	var guarded_snapshot: Array[Dictionary] = expiry_fight.hero_states()
	guarded_snapshot[0]["guard_reduction"] = 0.4
	guarded_snapshot[0]["skill_cooldowns"]["guarda_protetora"] = 2
	var restarted_guard_fight = CombatEngine.new()
	restarted_guard_fight.start(guarded_snapshot, [Tower.enemies_for(1, "", 1)[0]])
	check(float(restarted_guard_fight.fighters["guerreiro"]["guard_reduction"]) == 0.0 and restarted_guard_fight.skill_cooldown_remaining("guerreiro", "guarda_protetora") == 0, "Nova batalha limpa proteção temporária e recargas")

	var ranger: Dictionary = Rules.create_hero("patrulheiro", 1, [])
	ranger["initiative"] = 30
	ranger["cards"]["predador"] = 3
	Rules.recalculate(ranger, 1, [])
	ranger["crit_chance"] = 0.0
	var wounded_goblin: Dictionary = Tower.enemies_for(1, "", 1)[0]
	wounded_goblin["hp"] -= 1
	var arrow_fight = CombatEngine.new()
	arrow_fight.start([ranger], [wounded_goblin])
	var wounded_hp: int = int(arrow_fight.fighters["goblin"]["hp"])
	check(arrow_fight.act("skill:flecha_debilitante", "goblin"), "Flecha Debilitante pode ser usada")
	check(wounded_hp - int(arrow_fight.fighters["goblin"]["hp"]) == 19, "Flecha causa 12 de dano e ativa Predador III")
	check(int(StateEffects.get_effect(arrow_fight.fighters["goblin"], "fraqueza")["duration"]) == 2, "Flecha aplica Fraqueza por dois turnos")
	arrow_fight.index = arrow_fight.order.find("patrulheiro")
	check(arrow_fight.skill_cooldown_remaining("patrulheiro", "flecha_debilitante") == 3 and arrow_fight.skill_available("disparo_duplo"), "Recarga da Flecha não bloqueia a outra habilidade do Patrulheiro")
	check(_events_contain(arrow_fight.events, "Predador III") and _events_contain(arrow_fight.events, "aplica Fraqueza"), "Flecha registra carta e efeito aplicado")

	var priest: Dictionary = Rules.create_hero("sacerdotisa", 1, [])
	priest["initiative"] = 30
	var wounded_ally: Dictionary = Rules.create_hero("guerreiro", 1, [])
	wounded_ally["hp"] = 70
	var priest_fight = CombatEngine.new()
	priest_fight.start([priest, wounded_ally], [Tower.enemies_for(1, "", 1)[0]])
	priest_fight.fighters["sacerdotisa"]["mana"] = 0
	check(not priest_fight.skill_available("purificacao"), "Purificação fica bloqueada sem mana suficiente")
	priest_fight.fighters["sacerdotisa"]["mana"] = 30
	StateEffects.apply(priest_fight.fighters["guerreiro"], "veneno")
	StateEffects.apply(priest_fight.fighters["guerreiro"], "fraqueza")
	check(priest_fight.act("skill:purificacao", "guerreiro"), "Purificação pode ser usada em aliado vivo")
	check(int(priest_fight.fighters["sacerdotisa"]["mana"]) == 20 and int(priest_fight.fighters["guerreiro"]["hp"]) == 80, "Purificação custa 10 mana e cura 10 PV")
	check(StateEffects.get_all(priest_fight.fighters["guerreiro"]).is_empty() and _events_contain(priest_fight.events, "remove Veneno") and _events_contain(priest_fight.events, "remove Fraqueza"), "Purificação remove os dois efeitos e registra ambos")
	priest_fight.index = priest_fight.order.find("sacerdotisa")
	priest_fight.fighters["guerreiro"]["hp"] = 90
	check(priest_fight.act("skill:purificacao", "guerreiro") and int(priest_fight.fighters["guerreiro"]["hp"]) == 100, "Purificação também cura sem efeitos negativos")
	priest_fight.fighters["guerreiro"]["state"] = "downed"
	priest_fight.fighters["guerreiro"]["hp"] = 0
	check(not "guerreiro" in priest_fight.targets("skill:purificacao"), "Purificação não permite selecionar nem reanimar caídos")

	var arcane_relics: Array[Dictionary] = [{"id": "pedra_arcana", "bearer": "feiticeiro"}]
	var wizard: Dictionary = Rules.create_hero("feiticeiro", 1, arcane_relics)
	wizard["cards"]["poder_elemental"] = 2
	Rules.recalculate(wizard, 1, arcane_relics)
	wizard["initiative"] = 30
	wizard["crit_chance"] = 0.0
	var enemies: Array[Dictionary] = Tower.enemies_for(1, "", 3)
	var arcane_fight = CombatEngine.new()
	arcane_fight.start([wizard], enemies)
	var initial_hp: Dictionary = {}
	var expected_by_enemy: Dictionary = {}
	for enemy_id in arcane_fight.enemy_ids:
		var enemy: Dictionary = arcane_fight.fighters[enemy_id]
		initial_hp[enemy_id] = int(enemy["hp"])
		expected_by_enemy[enemy_id] = int(Rules.damage_packet(arcane_fight.fighters["feiticeiro"], enemy, 16, "magical", false, true, 1.0)["amount"])
	arcane_fight.fighters["feiticeiro"]["mana"] = 14
	check(not arcane_fight.skill_available("onda_arcana"), "Onda Arcana fica bloqueada com menos de 15 mana")
	arcane_fight.fighters["feiticeiro"]["mana"] = 30
	check(arcane_fight.act("skill:onda_arcana"), "Onda Arcana é usada sem selecionar um alvo individual")
	check(int(arcane_fight.fighters["feiticeiro"]["mana"]) == 17, "Onda custa 15 mana e Pedra Arcana recupera 2")
	for enemy_id in arcane_fight.enemy_ids:
		var actual: int = int(initial_hp[enemy_id]) - int(arcane_fight.fighters[enemy_id]["hp"])
		check(actual == int(expected_by_enemy[enemy_id]), "Onda respeita dano mágico, resistência e Poder Elemental em %s" % enemy_id)
	var arcane_hits := 0
	var elemental_logs := 0
	for event in arcane_fight.events:
		if event.contains("usa Onda Arcana"):
			arcane_hits += 1
		if event.contains("Poder Elemental II"):
			elemental_logs += 1
	check(arcane_hits == 2 and elemental_logs == 2, "Onda processa cada inimigo uma vez e ativa bônus uma vez por alvo")
	check(arcane_fight.enemy_action_counts.get("goblin", 0) == 0 and arcane_fight.enemy_action_counts.get("esqueleto", 0) == 0 and arcane_fight.round_number == 1, "Onda consome uma única ação sem executar turnos extras")


func test_permanent_curve_and_limits() -> void:
	check(Progression.xp_required(1) == 100 and Progression.xp_required(2) == 120 and Progression.xp_required(19) == 460, "Curva de XP cresce 20 por nível")
	var entry: Dictionary = Progression.from_save({}, "guerreiro", SaveStore.VERSION)
	Progression.grant_xp(entry, 250)
	check(int(entry["level"]) == 3 and int(entry["level_xp"]) == 30 and int(entry["available_points"]) == 2 and int(entry["xp"]) == 250, "XP excedente atravessa dois níveis e concede dois pontos")
	Progression.grant_xp(entry, 110)
	check(int(entry["level"]) == 4 and int(entry["level_xp"]) == 0 and int(entry["available_points"]) == 3, "XP no limite exato sobe um nível")
	var multiple: Dictionary = Progression.from_save({}, "bruxa", SaveStore.VERSION)
	Progression.grant_xp(multiple, 1000)
	check(int(multiple["level"]) == 7 and int(multiple["level_xp"]) == 100 and int(multiple["available_points"]) == 6, "Uma concessão pode subir vários níveis")
	var capped: Dictionary = Progression.from_save({}, "guerreiro", SaveStore.VERSION)
	Progression.grant_xp(capped, 6000)
	check(int(capped["level"]) == 20 and int(capped["available_points"]) == 19 and int(capped["xp"]) == 6000, "Nível máximo concede 19 pontos")
	Progression.grant_xp(capped, 200)
	check(int(capped["level"]) == 20 and int(capped["available_points"]) == 19 and int(capped["xp"]) == 6200, "XP continua registrada sem pontos extras após nível 20")
	check(not Progression.invest(capped, "guerreiro", "mana"), "Classes sem mana não investem em Mana")
	for _point in range(5):
		check(Progression.invest(capped, "guerreiro", "vitalidade"), "Investimento permitido até cinco pontos")
	check(not Progression.invest(capped, "guerreiro", "vitalidade") and int(capped["available_points"]) == 14, "Limite de atributo bloqueia sexto ponto")
	var mana_class: Dictionary = Progression.from_save({}, "bruxa", SaveStore.VERSION)
	Progression.grant_xp(mana_class, 6000)
	for _point in range(5):
		check(Progression.invest(mana_class, "bruxa", "mana"), "Classe com mana recebe atributo Mana")
	check(not Progression.invest(mana_class, "bruxa", "mana"), "Mana também respeita limite de cinco pontos")
	var legacy_over_cap: Dictionary = Progression.from_save({"xp": 6000, "level": 61}, "guerreiro", 1)
	check(int(legacy_over_cap["level"]) == 20 and int(legacy_over_cap["legacy_level"]) == 61 and int(legacy_over_cap["xp"]) == 6000, "Save antigo acima do teto preserva registro histórico do nível")


func test_permanent_integration_and_migration() -> void:
	reset_test_file()
	var state = RunState.new()
	state.initialize(TEST_PATH)
	var warrior_progress: Dictionary = state.permanent["classes"]["guerreiro"]
	Progression.grant_xp(warrior_progress, 1000)
	for attribute_id in ["vitalidade", "vitalidade", "poder", "agilidade", "resistencia", "resistencia"]:
		check(Progression.invest(warrior_progress, "guerreiro", attribute_id), "Distribuir pontos do Guerreiro")
	state.permanent["classes"]["guerreiro"] = warrior_progress
	var witch_progress: Dictionary = state.permanent["classes"]["bruxa"]
	Progression.grant_xp(witch_progress, 250)
	check(Progression.invest(witch_progress, "bruxa", "mana"), "Distribuir Mana da Bruxa")
	state.permanent["classes"]["bruxa"] = witch_progress
	var ids: Array[String] = ["guerreiro", "bruxa"]
	check(state.new_attempt(ids) and int(state.attempt["level"]) == 1, "Nova tentativa começa com nível interno 1")
	var warrior: Dictionary = state.attempt["heroes"][0]
	var witch: Dictionary = state.attempt["heroes"][1]
	check(int(warrior["max_hp"]) == 110 and int(warrior["damage"]) == 21 and int(warrior["initiative"]) == 13 and is_equal_approx(float(warrior["physical_resist"]), 0.02) and is_equal_approx(float(warrior["magical_resist"]), 0.02), "Pontos permanentes alteram PV, ataque básico, iniciativa e resistências")
	check(int(witch["mana_max"]) == 33 and int(witch["mana"]) == 33 and int(warrior["mana_max"]) == 0, "Mana aplica somente à classe com recurso")
	warrior["hp"] = 60
	warrior["cards"]["robusto"] = 3
	warrior["cards"]["veloz"] = 1
	Rules.recalculate(warrior, 2, [{"id": "medalhao_vital", "bearer": ""}])
	check(int(warrior["max_hp"]) == 167 and int(warrior["hp"]) == 60 and int(warrior["damage"]) == 22 and int(warrior["initiative"]) == 15 and is_equal_approx(float(warrior["physical_resist"]), 0.10), "Pontos combinam com nível interno, carta e relíquia sem curar PV")
	Rules.recalculate(warrior, 2, [{"id": "medalhao_vital", "bearer": ""}])
	check(int(warrior["max_hp"]) == 167 and int(warrior["hp"]) == 60, "Recálculo repetido não duplica bônus")
	witch["mana"] = 7
	Rules.recalculate(witch, 2, [{"id": "medalhao_vital", "bearer": ""}])
	check(int(witch["mana_max"]) == 35 and int(witch["mana"]) == 7, "Recálculo não recupera mana")
	state.attempt["heroes"][0]["hp"] = 60
	state.attempt["heroes"][1]["mana"] = 7
	state.save()
	var reloaded = RunState.new()
	reloaded.initialize(TEST_PATH)
	check(reloaded.has_attempt() and int(reloaded.attempt["heroes"][0]["hp"]) == 60 and int(reloaded.attempt["heroes"][1]["mana"]) == 7, "Continuar tentativa preserva PV e mana")
	check(int(reloaded.attempt["heroes"][0]["damage"]) == 21 and int(reloaded.attempt["heroes"][1]["mana_max"]) == 33, "Reabrir save aplica retrato permanente original")
	warrior_progress = reloaded.permanent["classes"]["guerreiro"]
	Progression.grant_xp(warrior_progress, 120)
	reloaded.permanent["classes"]["guerreiro"] = warrior_progress
	check(reloaded.spend_attribute("guerreiro", "poder"), "Ponto ganho depois da tentativa é salvo")
	var after_spend = RunState.new()
	after_spend.initialize(TEST_PATH)
	check(int(after_spend.permanent["classes"]["guerreiro"]["attributes"]["poder"]) == 2 and int(after_spend.attempt["heroes"][0]["damage"]) == 21, "Distribuição posterior não muda tentativa salva")
	check(after_spend.new_attempt(ids) and int(after_spend.attempt["heroes"][0]["damage"]) == 22, "Nova tentativa usa pontos permanentes atualizados")
	reset_test_file()
	var seed = RunState.new()
	seed.initialize(TEST_PATH)
	seed.new_attempt(ids)
	seed.begin_floor()
	var legacy_attempt: Dictionary = seed.attempt.duplicate(true)
	legacy_attempt["heroes"][0].erase("permanent_attributes")
	legacy_attempt["heroes"][1].erase("permanent_attributes")
	legacy_attempt["heroes"][0]["hp"] = 50
	legacy_attempt["heroes"][1]["mana"] = 4
	var legacy: Dictionary = {"version": 1, "permanent": {"coins": 42, "stats": {"attempts": 3, "wins": 1, "losses": 2, "floors_completed": 12}, "classes": {"guerreiro": {"xp": 250, "level": 3, "history": [{"attempt": "antiga", "floors": 2, "xp": 40, "result": "victory"}]}, "bruxa": {"xp": 120, "level": 2, "history": []}}}, "attempt": legacy_attempt}
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	var migrated = RunState.new()
	migrated.initialize(TEST_PATH)
	check(int(migrated.permanent["coins"]) == 42 and int(migrated.permanent["stats"]["attempts"]) == 3 and migrated.permanent["classes"]["guerreiro"]["history"].size() == 1, "Migração preserva moedas, estatísticas e histórico")
	check(int(migrated.permanent["classes"]["guerreiro"]["xp"]) == 250 and int(migrated.permanent["classes"]["guerreiro"]["level"]) == 3 and int(migrated.permanent["classes"]["guerreiro"]["level_xp"]) == 50 and int(migrated.permanent["classes"]["guerreiro"]["available_points"]) == 2, "Migração preserva nível antigo e concede pontos anteriores")
	check(migrated.has_attempt() and migrated.attempt["phase"] == "combat" and int(migrated.attempt["heroes"][0]["hp"]) == 50 and int(migrated.attempt["heroes"][1]["mana"]) == 4, "Migração preserva tentativa ativa e recursos")
	check(int(SaveStore.load_data(TEST_PATH).get("version", 0)) == 2, "Migração grava save versão 2")
	var migrated_again = RunState.new()
	migrated_again.initialize(TEST_PATH)
	check(int(migrated_again.permanent["classes"]["guerreiro"]["available_points"]) == 2 and int(migrated_again.permanent["classes"]["bruxa"]["available_points"]) == 1, "Reabrir save migrado não duplica pontos")
	check(migrated_again.spend_attribute("guerreiro", "vitalidade"), "Ponto migrado pode ser investido")
	var migrated_with_spend = RunState.new()
	migrated_with_spend.initialize(TEST_PATH)
	check(int(migrated_with_spend.permanent["classes"]["guerreiro"]["available_points"]) == 1 and int(migrated_with_spend.attempt["heroes"][0]["max_hp"]) == 100, "Investir após migração preserva atributos da tentativa antiga")
	var single: Array[String] = ["guerreiro"]
	check(migrated_with_spend.new_attempt(single) and int(migrated_with_spend.attempt["heroes"][0]["max_hp"]) == 105, "Tentativa seguinte aplica ponto migrado")


func test_permanent_progression_ui() -> void:
	reset_test_file()
	var state = RunState.new()
	state.initialize(TEST_PATH)
	var warrior: Dictionary = state.permanent["classes"]["guerreiro"]
	Progression.grant_xp(warrior, 6000)
	state.permanent["classes"]["guerreiro"] = warrior
	var witch: Dictionary = state.permanent["classes"]["bruxa"]
	Progression.grant_xp(witch, 250)
	state.permanent["classes"]["bruxa"] = witch
	state.save()
	var game = Game.new()
	game.run.save_path = TEST_PATH
	root.add_child(game)
	await process_frame
	game.run = state
	game.show_progression()
	check(game.progression_class_buttons.size() == 5 and node_contains_text(game.screen, "NÍVEL MÁXIMO") and node_contains_text(game.screen, "Pontos disponíveis: 19"), "V21 lista cinco classes e exibe classe no nível máximo")
	var before_coins: int = int(state.permanent["coins"])
	var before_attempts: int = int(state.permanent["stats"]["attempts"])
	game.progression_class_buttons["bruxa"]["button"].pressed.emit()
	check(game.progression_hero_id == "bruxa" and node_contains_text(game.screen, "faltam 110 XP") and node_contains_text(game.screen, "Pontos disponíveis: 2"), "V21 alterna classe e mostra XP exata para o próximo nível")
	game.progression_class_buttons["guerreiro"]["button"].pressed.emit()
	check(node_contains_text(game.screen, "Indisponível para esta classe (sem mana)"), "V21 diferencia atributos de mana indisponíveis")
	game.progression_class_buttons["bruxa"]["button"].pressed.emit()
	var mana_button: Button = game.progression_detail.find_child("Invest_mana", true, false)
	check(mana_button != null and not mana_button.disabled, "V21 habilita investimento de mana para Bruxa")
	mana_button.pressed.emit()
	check(int(state.permanent["classes"]["bruxa"]["attributes"]["mana"]) == 1 and node_contains_text(game.screen, "atual: +3 mana máxima") and node_contains_text(game.screen, "Mana máxima") and node_contains_text(game.screen, "33"), "V21 investe, salva e atualiza a prévia de mana imediatamente")
	var reloaded = RunState.new()
	reloaded.initialize(TEST_PATH)
	check(int(reloaded.permanent["classes"]["bruxa"]["attributes"]["mana"]) == 1 and int(reloaded.permanent["coins"]) == before_coins and int(reloaded.permanent["stats"]["attempts"]) == before_attempts, "V21 mantém investimento persistido sem alterar moedas ou estatísticas")
	game.queue_free()


func test_stage_screens() -> void:
	reset_test_file()
	var stage = RunState.new()
	stage.initialize(TEST_PATH)
	var ids: Array[String] = ["guerreiro", "bruxa"]
	stage.new_attempt(ids)
	stage.begin_floor()
	var game = Game.new()
	game.run.save_path = TEST_PATH
	root.add_child(game)
	await process_frame
	game.run = stage
	for floor_number in range(1, 5):
		if floor_number > 1:
			stage.begin_floor()
		var heroes: Array[Dictionary] = []
		for hero in stage.attempt["heroes"]:
			heroes.append(hero.duplicate(true))
		stage.victory(heroes)
		if stage.attempt["phase"] == "cards":
			game.show_phase()
			check(game.screen != null, "Tela de cartas")
			while stage.attempt["phase"] == "cards":
				var card_hero: String = stage.current_card_hero()
				stage.choose_card(stage.attempt["card_offers"][card_hero][0])
		game.show_phase()
		check(stage.attempt["phase"] == "reward" and game.screen != null, "Tela de recompensa")
		stage.choose_reward("rest", "guerreiro")
		if stage.attempt["phase"] == "relic":
			game.show_phase()
			check(game.screen != null, "Tela de relíquias")
			var relic_id: String = stage.attempt["relic_options"][0]
			var bearer: String = "bruxa" if Relics.DEFINITIONS[relic_id].get("requires_mana", false) else ("guerreiro" if Relics.DEFINITIONS[relic_id].get("bearer", false) else "")
			stage.choose_relic(relic_id, bearer)
		if stage.attempt["phase"] == "route":
			game.show_phase()
			check(game.screen != null, "Tela de rotas")
			stage.choose_route(Tower.route_after(floor_number)[0]["id"])
		game.show_phase()
		check(stage.attempt["phase"] == "between" and game.screen != null, "Tela entre andares")
	var final_summary: Dictionary = stage.end_attempt("defeat")
	game.show_summary(final_summary)
	check(game.screen != null, "Tela de encerramento")
	check(bool(final_summary.get("new_record", false)) and int(final_summary.get("floor_reached", 0)) == 4, "Recorde de andar chega à tela final")
	check(game.screen.find_child("OutcomeNewAttempt", true, false) != null and game.screen.find_child("OutcomeProgression", true, false) != null and game.screen.find_child("OutcomeMenu", true, false) != null, "Ações da tela de resultado")
	check(not _control_tree_has_text(game.screen, "Derrota") and not _control_tree_has_text(game.screen, "derrota"), "Tela de progresso não chama o fim de derrota")
	check(stage.new_attempt(ids), "Nova tentativa após o resumo")
	stage.attempt["floor"] = Tower.MAX_FLOOR
	stage.attempt["completed"] = Tower.MAX_FLOOR
	var tower_summary: Dictionary = stage.end_attempt("victory")
	game.show_summary(tower_summary)
	check(bool(tower_summary.get("won", false)) and _control_tree_has_text(game.screen, "Torre concluída!") and _control_tree_has_text(game.screen, "NOVO RECORDE"), "Resumo de vitória celebra conclusão e recorde")
	game.queue_free()


func test_highest_floor_record() -> void:
	reset_test_file()
	var state = RunState.new()
	state.initialize(TEST_PATH)
	var ids: Array[String] = ["guerreiro"]
	check(state.new_attempt(ids), "Iniciar para registrar andar alcançado")
	state.attempt["floor"] = 3
	state.attempt["completed"] = 2
	var first_result: Dictionary = state.end_attempt("defeat")
	check(bool(first_result.get("new_record", false)) and int(first_result.get("floor_reached", 0)) == 3 and int(state.permanent["stats"]["best_floor_reached"]) == 3, "Novo melhor andar é registrado mesmo sem concluir a torre")
	var loaded = RunState.new()
	loaded.initialize(TEST_PATH)
	check(int(loaded.permanent["stats"].get("best_floor_reached", 0)) == 3, "Recorde do andar persiste após carregar save")
	check(loaded.new_attempt(ids), "Nova tentativa mantém o recorde anterior")
	loaded.attempt["floor"] = 3
	loaded.attempt["completed"] = 2
	var repeat_result: Dictionary = loaded.end_attempt("defeat")
	check(not bool(repeat_result.get("new_record", true)) and int(repeat_result.get("previous_best_floor", 0)) == 3, "Repetir o mesmo andar não anuncia novo recorde")
	check(repeat_result.get("result", "") == "Derrota", "Resultado interno preserva compatibilidade com saves e estatísticas")


func _control_tree_has_text(node: Node, searched: String) -> bool:
	if node is Label and searched in node.text:
		return true
	for child in node.get_children():
		if _control_tree_has_text(child, searched):
			return true
	return false
