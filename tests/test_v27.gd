extends SceneTree

const Skills = preload("res://data/skills.gd")
const Heroes = preload("res://data/heroes.gd")
const Enemies = preload("res://data/enemies.gd")
const Rules = preload("res://systems/combat_rules.gd")
const CombatEngine = preload("res://systems/combat_engine.gd")
const Progression = preload("res://systems/permanent_progression.gd")
const RunState = preload("res://systems/run_state.gd")
const Effects = preload("res://systems/state_effects.gd")
const Game = preload("res://scripts/main_v8.gd")

var failures: Array[String] = []
var checks_run: int = 0
const PATH := "user://torre_v27_test.json"

func _initialize() -> void:
	call_deferred("run_all")

func check(value: bool, message: String) -> void:
	checks_run += 1
	if not value:
		failures.append(message)
		push_error(message)

func enemy(id: String = "goblin") -> Dictionary:
	var value: Dictionary = Enemies.get_definition(id)
	value["id"] = id
	value["team"] = "enemy"
	value["state"] = "alive"
	value["max_hp"] = 500
	value["hp"] = 500
	value["initiative"] = 1
	return value

func hero(id: String) -> Dictionary:
	var value: Dictionary = Rules.create_hero(id, 1, [], {}, Skills.SPECIALS[id])
	value["initiative"] = 100
	value["crit_chance"] = 0.0
	return value

func battle(hero_ids: Array[String], enemies: Array[String] = ["goblin"]):
	var team: Array[Dictionary] = []
	var foes: Array[Dictionary] = []
	for id in hero_ids:
		team.append(hero(id))
	for id in enemies:
		foes.append(enemy(id))
	var combat = CombatEngine.new()
	combat.start(team, foes)
	return combat

func advance_to_hero(combat) -> void:
	var guard := 0
	while not combat.finished and not combat.is_hero_turn() and guard < 10:
		combat.act_enemy()
		guard += 1

func run_all() -> void:
	for id in Heroes.ORDER:
		var specials: Array = Skills.SPECIALS[id]
		check(specials.size() == 2, "%s possui duas especiais" % id)
		for tier in range(2):
			var skill: Dictionary = Skills.get_definition(specials[tier])
			check(int(skill["level"]) == (6 if tier == 0 else 12) and int(skill["point_cost"]) == (2 if tier == 0 else 3), "%s nível e custo corretos" % skill["name"])
		var entry: Dictionary = Progression.from_save({"level": 5, "level_xp": 0, "attributes": {}}, id, 2)
		check(not Progression.can_unlock(entry, id, specials[0]), "%s respeita nível 6" % id)
		entry["level"] = 6
		entry["available_points"] = 1
		check(not Progression.can_unlock(entry, id, specials[0]), "%s respeita custo 2" % id)
		entry["available_points"] = 5
		check(Progression.unlock(entry, id, specials[0]), "%s compra especial I" % id)
		check(not Progression.unlock(entry, id, specials[0]) and int(entry["available_points"]) == 3, "%s não duplica compra" % id)
		check(not Progression.can_unlock(entry, id, specials[1]), "%s respeita nível 12" % id)
		entry["level"] = 12
		check(Progression.unlock(entry, id, specials[1]) and int(entry["available_points"]) == 6, "%s compra especial II" % id)
		var restored: Dictionary = Progression.from_save(entry, id, 2)
		check(restored["unlocked_specials"].size() == 2 and int(restored["available_points"]) == 6, "%s persiste duas compras" % id)
	var invested: Dictionary = Progression.from_save({"level": 12, "level_xp": 0, "attributes": {"vitalidade": 5, "poder": 4}}, "guerreiro", 2)
	check(int(invested["available_points"]) == 2 and Progression.unlock(invested, "guerreiro", "golpe_carrasco"), "Especial compartilha pontos já investidos em atributos")
	check(int(invested["available_points"]) == 0 and not Progression.can_unlock(invested, "guerreiro", "fortaleza_inabalavel"), "Sem pontos para Especial II após compra")
	var sanitized: Dictionary = Progression.from_save(invested, "guerreiro", 2)
	check(int(sanitized["available_points"]) == 0 and sanitized["unlocked_specials"].size() == 1, "Recarga não duplica pontos ou compras")
	var maxed: Dictionary = Progression.from_save({"level": 20, "level_xp": 999, "attributes": {"vitalidade": 5, "poder": 5, "agilidade": 4}, "unlocked_specials": ["golpe_carrasco", "fortaleza_inabalavel"]}, "guerreiro", 2)
	check(int(maxed["level"]) == 20 and int(maxed["available_points"]) == 0 and maxed["unlocked_specials"].size() == 2, "Nível 20 respeita 19 pontos entre atributos e habilidades")
	test_save_snapshot()
	test_warrior()
	test_ranger()
	test_witch()
	test_priestess()
	test_mage()
	test_rule_interactions()
	test_all_special_contracts()
	test_vampirism_exact()
	test_legacy_save_compatibility()
	await test_ui()
	if failures.is_empty():
		print("V27.5: %d verificações de progressão, persistência e habilidades passaram." % checks_run)
		quit(0)
	else:
		print("V27.5: %d falhas em %d verificações: %s" % [failures.size(), checks_run, "; ".join(failures)])
		quit(1)

func test_save_snapshot() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	var state = RunState.new()
	state.initialize(PATH)
	state.permanent["classes"]["guerreiro"]["level"] = 12
	state.permanent["classes"]["guerreiro"]["available_points"] = 11
	check(state.new_attempt(["guerreiro"]), "tentativa criada")
	check(state.attempt["heroes"][0].get("unlocked_specials", []).is_empty(), "tentativa anterior sem especial")
	check(state.spend_special_skill("guerreiro", "golpe_carrasco"), "compra salva")
	check(state.attempt["heroes"][0].get("unlocked_specials", []).is_empty(), "compra não altera tentativa em andamento")
	var existing_fight = CombatEngine.new()
	existing_fight.start(state.attempt["heroes"], [enemy()])
	check(not existing_fight.skill_available("golpe_carrasco"), "Combate da tentativa em andamento não recebe habilidade comprada depois")
	var reopened = RunState.new()
	reopened.initialize(PATH)
	check("golpe_carrasco" in reopened.permanent["classes"]["guerreiro"]["unlocked_specials"], "compra persiste após reabrir")
	check(reopened.attempt["heroes"][0].get("unlocked_specials", []).is_empty(), "tentativa salva mantém snapshot")
	check(reopened.new_attempt(["guerreiro"]), "nova tentativa criada")
	check("golpe_carrasco" in reopened.attempt["heroes"][0]["unlocked_specials"], "nova tentativa recebe desbloqueio")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func test_warrior() -> void:
	var c = battle(["guerreiro"])
	c.fighters["goblin"]["hp"] = 100
	c.fighters["goblin"]["max_hp"] = 300
	check(c.act("skill:golpe_carrasco", "goblin"), "Golpe do Carrasco executa")
	check(int(c.fighters["goblin"]["hp"]) == 65, "Carrasco aumenta 26 em 35% abaixo de 35% PV")
	check(c.skill_cooldown_remaining("guerreiro", "golpe_carrasco") == 3, "Carrasco recarga 3")
	advance_to_hero(c)
	c.fighters["guerreiro"]["hp"] = 100
	check(c.act("skill:fortaleza_inabalavel"), "Fortaleza ativa sem alvo")
	check(int(Effects.get_effect(c.fighters["guerreiro"], "fortaleza")["duration"]) == 2, "Fortaleza não consome turno de ativação")
	advance_to_hero(c)
	check(c.act("defend"), "Guerreiro defende")
	check(int(Effects.get_effect(c.fighters["guerreiro"], "fortaleza")["duration"]) == 1, "Fortaleza perde um turno próprio")

func test_ranger() -> void:
	var c = battle(["patrulheiro"], ["goblin", "esqueleto"])
	check(c.act("skill:instinto_predador", "goblin"), "Instinto ataca")
	check(int(c.fighters["goblin"]["hp"]) == 485 and int(Effects.get_effect(c.fighters["patrulheiro"], "instinto")["duration"]) == 2, "Instinto causa 15 e ativa crítico")
	advance_to_hero(c)
	check(c.act("skill:chuva_flechas"), "Chuva sem alvo")
	check(int(c.fighters["goblin"]["hp"]) < 485 and int(c.fighters["esqueleto"]["hp"]) < 500, "Chuva acerta cada inimigo")
	check(int(Effects.get_effect(c.fighters["patrulheiro"], "instinto")["duration"]) == 1, "Instinto dura próximo turno")

func test_witch() -> void:
	var c = battle(["bruxa"], ["goblin", "esqueleto"])
	check(c.act("skill:maldicao_coletiva"), "Maldição Coletiva ativa")
	check(int(c.fighters["bruxa"]["mana"]) == 16 and not Effects.get_effect(c.fighters["goblin"], "fraqueza").is_empty() and not Effects.get_effect(c.fighters["esqueleto"], "fraqueza").is_empty(), "Maldição consome 14 mana e afeta todos")
	advance_to_hero(c)
	c.fighters["bruxa"]["hp"] = 60
	check(c.act("skill:vampirismo_arcano"), "Vampirismo ativa")
	check(int(c.fighters["bruxa"]["mana"]) == 4 and int(Effects.get_effect(c.fighters["bruxa"], "vampirismo")["duration"]) == 2, "Vampirismo consome 12 e ignora ativação")
	advance_to_hero(c)
	c.fighters["bruxa"]["hp"] = 20
	check(c.act("skill:raio_arcano", "goblin") == false, "Vampirismo não permite magia sem mana")
	c.fighters["bruxa"]["mana"] = 30
	check(c.act("skill:raio_arcano", "goblin"), "Raio com vampirismo")
	check(int(c.fighters["bruxa"]["hp"]) > 20, "Vampirismo cura dano mágico efetivo")

func test_priestess() -> void:
	var c = battle(["sacerdotisa", "guerreiro"])
	c.fighters["sacerdotisa"]["hp"] = 60
	c.fighters["guerreiro"]["hp"] = 50
	check(c.act("skill:prece_restauradora"), "Prece restaura grupo")
	check(int(c.fighters["sacerdotisa"]["hp"]) == 74 and int(c.fighters["guerreiro"]["hp"]) == 64, "Prece cura 14 em cada vivo")
	advance_to_hero(c)
	if c.current_id() == "guerreiro":
		c.act("defend")
		advance_to_hero(c)
	c.fighters["sacerdotisa"]["mana"] = 30
	c.fighters["guerreiro"]["hp"] = 0
	c.fighters["guerreiro"]["state"] = "downed"
	Effects.apply(c.fighters["guerreiro"], "veneno")
	check(c.act("skill:milagre_divino", "guerreiro"), "Milagre reanima caído")
	check(c.fighters["guerreiro"]["state"] == "alive" and int(c.fighters["guerreiro"]["hp"]) == 45 and Effects.get_effect(c.fighters["guerreiro"], "veneno").is_empty(), "Milagre reanima 45% e remove estado")

func test_mage() -> void:
	var c = battle(["feiticeiro"], ["goblin", "esqueleto"])
	c.fighters["goblin"]["magical_resist"] = 0.5
	check(c.act("skill:ruptura_arcana", "goblin"), "Ruptura executa")
	check(int(c.fighters["goblin"]["hp"]) == 480, "Ruptura ignora metade da resistência: 26 * 0,75 = 20")
	advance_to_hero(c)
	c.fighters["feiticeiro"]["mana"] = 30
	check(c.act("skill:tempestade_arcana"), "Tempestade sem alvo")
	check(int(c.fighters["goblin"]["hp"]) < 480 and int(c.fighters["esqueleto"]["hp"]) < 500, "Tempestade acerta ambos")
	check(int(c.fighters["feiticeiro"]["mana"]) == 6, "Tempestade consome 24 mana")

func test_rule_interactions() -> void:
	var warrior: Dictionary = hero("guerreiro")
	var foe: Dictionary = enemy()
	foe["physical_resist"] = 0.20
	var plain: int = int(Rules.damage_packet(warrior, foe, 20, "physical", false, false, 1.0)["amount"])
	Effects.apply(warrior, "fraqueza")
	var weak: int = int(Rules.damage_packet(warrior, foe, 20, "physical", false, false, 1.0)["amount"])
	check(plain == 16 and weak == 12, "Fraqueza afeta dano físico especial no cálculo central")
	Effects.apply(foe, "fortaleza")
	var protected: int = int(Rules.damage_packet(warrior, foe, 20, "physical", false, false, 1.0)["amount"])
	check(protected == 8, "Fortaleza multiplica redução depois da resistência")
	var mage: Dictionary = hero("feiticeiro")
	foe["magical_resist"] = 0.5
	var ordinary: int = int(Rules.damage_packet(mage, foe, 26, "magical", false, true, 1.0)["amount"])
	var pierced: int = int(Rules.damage_packet(mage, foe, 26, "magical", false, true, 1.0, 1.0, 0.5)["amount"])
	check(pierced > ordinary, "Ruptura reduz apenas resistência mágica positiva")
	var ranger: Dictionary = hero("patrulheiro")
	Effects.apply(ranger, "instinto")
	check(Rules.damage_packet(ranger, foe, 15, "physical", false, false, 0.20)["critical"], "Instinto adiciona 25 p.p. ao crítico")
	var c = battle(["guerreiro"])
	check(c.act("skill:fortaleza_inabalavel"), "Fortaleza ativada para teste de duração")
	for turn in range(2):
		advance_to_hero(c)
		check(not Effects.get_effect(c.fighters["guerreiro"], "fortaleza").is_empty(), "Fortaleza cobre próximo turno %d" % (turn + 1))
		c.act("defend")
	check(Effects.get_effect(c.fighters["guerreiro"], "fortaleza").is_empty(), "Fortaleza expira após dois turnos próprios")
	var priest = battle(["sacerdotisa", "guerreiro"])
	priest.fighters["guerreiro"]["state"] = "downed"
	priest.fighters["guerreiro"]["hp"] = 0
	check(priest.act("skill:prece_restauradora"), "Prece funciona com aliado caído")
	check(int(priest.fighters["guerreiro"]["hp"]) == 0, "Prece não reanima caídos")
	var miracle = battle(["sacerdotisa", "guerreiro"])
	miracle.fighters["guerreiro"]["state"] = "dead"
	miracle.fighters["guerreiro"]["hp"] = 0
	check(not "guerreiro" in miracle.targets("skill:milagre_divino") and not miracle.act("skill:milagre_divino", "guerreiro"), "Milagre não permite alvo morto")
	check(int(miracle.fighters["sacerdotisa"]["mana"]) == 30 and miracle.skill_cooldown_remaining("sacerdotisa", "milagre_divino") == 0, "Alvo morto não consome mana nem recarga")

func test_ui() -> void:
	var game = Game.new()
	game.run.save_path = PATH
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	game.run.permanent["classes"]["guerreiro"]["level"] = 12
	game.run.permanent["classes"]["guerreiro"]["available_points"] = 11
	game.show_progression()
	await process_frame
	var first: Button = game.progression_detail.find_child("Unlock_golpe_carrasco", true, false)
	var second: Button = game.progression_detail.find_child("Unlock_fortaleza_inabalavel", true, false)
	check(first != null and second != null, "Progressão exibe compra das duas especiais")
	if first != null and second != null:
		check(first.size.x <= 110.0 and second.size.x <= 110.0, "Botões Desbloquear são compactos")
		check(not first.disabled and not second.disabled, "Nível 12 com pontos mostra especiais disponíveis")
		game.confirm_special_unlock("guerreiro", "golpe_carrasco")
		var dialog: ConfirmationDialog = game.host.get_child(game.host.get_child_count() - 1)
		check(dialog.dialog_text.contains("permanente") and dialog.dialog_text.contains("2 pontos"), "Compra pede confirmação e informa custo permanente")
		dialog.confirmed.emit()
		check("golpe_carrasco" in game.run.permanent["classes"]["guerreiro"]["unlocked_specials"] and int(game.run.permanent["classes"]["guerreiro"]["available_points"]) == 9, "Confirmação compra uma vez e atualiza pontos")
		var acquired: Button = game.progression_detail.find_child("Unlock_golpe_carrasco", true, false)
		check(acquired != null and acquired.disabled, "Progressão mostra adquirida sem nova compra")
	game.show_selection()
	await process_frame
	check(game.selection_presentations["guerreiro"]["skills"].size() == 4, "Seleção exibe básicas e especiais")
	game.free()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func test_all_special_contracts() -> void:
	for hero_id in Heroes.ORDER:
		for skill_id in Skills.SPECIALS[hero_id]:
			var skill: Dictionary = Skills.get_definition(skill_id)
			var combat = battle([hero_id])
			check(combat.skill_available(skill_id), "%s aparece para classe desbloqueada" % skill_id)
			var before_mana: int = int(combat.fighters[hero_id]["mana"])
			var target_id: String = "goblin" if skill["target"] == "enemy" else (hero_id if skill["target"] == "hero" else "")
			check(combat.act("skill:" + skill_id, target_id), "%s consome ação válida" % skill_id)
			check(int(combat.fighters[hero_id]["mana"]) == before_mana - int(skill.get("mana", 0)), "%s custo de mana exato" % skill_id)
			check(combat.skill_cooldown_remaining(hero_id, skill_id) == int(skill["cooldown"]), "%s recarga inicial exata" % skill_id)
			check(not combat.is_hero_turn() and not combat.act("attack", "goblin"), "%s não concede segunda ação" % skill_id)
			advance_to_hero(combat)
			check(not combat.skill_available(skill_id), "%s bloqueada durante recarga" % skill_id)
			var locked = CombatEngine.new()
			locked.start([Rules.create_hero(hero_id, 1, [])], [enemy()])
			check(not skill_id in locked.skill_ids_for(locked.fighters[hero_id]) and not locked.skill_available(skill_id), "%s bloqueada não entra no combate" % skill_id)

func test_vampirism_exact() -> void:
	var combat = battle(["bruxa"])
	combat.fighters["bruxa"]["hp"] = 20
	check(combat.act("skill:vampirismo_arcano"), "Vampirismo custa ação na ativação")
	check(int(combat.fighters["bruxa"]["hp"]) == 20 and combat.skill_cooldown_remaining("bruxa", "vampirismo_arcano") == 6, "Ativação não cura e inicia recarga 6")
	advance_to_hero(combat)
	combat.fighters["bruxa"]["hp"] = 20
	check(combat.act("skill:raio_arcano", "goblin"), "Primeiro turno com vampirismo")
	check(int(combat.fighters["bruxa"]["hp"]) == 28 and int(Effects.get_effect(combat.fighters["bruxa"], "vampirismo")["duration"]) == 1, "Vampirismo cura 30% de 25 = 8 e dura mais um turno")
	advance_to_hero(combat)
	combat.fighters["bruxa"]["hp"] = 68
	combat.fighters["bruxa"]["mana"] = 30
	check(combat.act("skill:raio_arcano", "goblin"), "Segundo turno com vampirismo")
	check(int(combat.fighters["bruxa"]["hp"]) == 70 and Effects.get_effect(combat.fighters["bruxa"], "vampirismo").is_empty(), "Vampirismo limita PV e expira após segundo turno")
	advance_to_hero(combat)
	combat.fighters["bruxa"]["hp"] = 20
	combat.fighters["bruxa"]["mana"] = 30
	combat.act("skill:raio_arcano", "goblin")
	check(int(combat.fighters["bruxa"]["hp"]) == 20, "Magia após expiração não cura")
	var radiant = battle(["bruxa"])
	radiant.fighters["bruxa"]["hp"] = 20
	radiant.fighters["bruxa"]["radiant_fraction"] = 0.35
	radiant.fighters["goblin"]["magical_resist"] = 0.5
	Effects.apply(radiant.fighters["bruxa"], "vampirismo")
	radiant.act("skill:raio_arcano", "goblin")
	check(int(radiant.fighters["goblin"]["hp"]) == 483 and int(radiant.fighters["bruxa"]["hp"]) == 25, "Vampirismo inclui Radiante e usa dano efetivo após resistência")
	var area = battle(["feiticeiro"], ["goblin", "esqueleto"])
	area.fighters["feiticeiro"]["hp"] = 20
	Effects.apply(area.fighters["feiticeiro"], "vampirismo")
	area.act("skill:tempestade_arcana")
	var vamp_events := 0
	for event in area.events:
		if event.begins_with("Vampirismo Mágico recupera"):
			vamp_events += 1
	check(int(area.fighters["feiticeiro"]["hp"]) == 34 and vamp_events == 1, "Dano mágico em área soma cura e registra uma vez")
	var periodic = battle(["bruxa"])
	periodic.fighters["bruxa"]["hp"] = 20
	Effects.apply(periodic.fighters["bruxa"], "vampirismo")
	periodic._apply_poison_damage("goblin", 8)
	check(int(periodic.fighters["bruxa"]["hp"]) == 20 and periodic.pending_vamp_damage == 0, "Veneno não alimenta vampirismo")
	periodic.act("attack", "goblin")
	check(int(periodic.fighters["bruxa"]["hp"]) == 20, "Ataque básico mágico não alimenta vampirismo")
	var physical = battle(["bruxa"])
	physical.fighters["bruxa"]["hp"] = 20
	Effects.apply(physical.fighters["bruxa"], "vampirismo")
	physical._deal_damage("bruxa", "goblin", 15, "physical", false, false, "Teste físico")
	check(int(physical.fighters["bruxa"]["hp"]) == 20 and physical.pending_vamp_damage == 0, "Dano físico direto não alimenta vampirismo")
	var defeated_target = battle(["patrulheiro"], ["goblin", "esqueleto"])
	defeated_target.fighters["goblin"]["hp"] = 0
	defeated_target.fighters["goblin"]["state"] = "dead"
	check(not "goblin" in defeated_target.targets("skill:instinto_predador") and not defeated_target.act("skill:instinto_predador", "goblin"), "Especial individual não seleciona inimigo morto")
	check(defeated_target.act("skill:chuva_flechas") and int(defeated_target.fighters["goblin"]["hp"]) == 0 and int(defeated_target.fighters["esqueleto"]["hp"]) < 500, "Especial em área ignora morto e atinge vivo")

func test_legacy_save_compatibility() -> void:
	var legacy_path := "user://torre_v27_legacy_test.json"
	if FileAccess.file_exists(legacy_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
	var legacy = RunState.new()
	legacy.initialize(legacy_path)
	legacy.permanent["coins"] = 321
	legacy.permanent["classes"]["bruxa"]["level"] = 12
	legacy.permanent["classes"]["bruxa"]["level_xp"] = 37
	legacy.permanent["classes"]["bruxa"]["xp"] = 777
	legacy.permanent["classes"]["bruxa"]["attributes"]["mana"] = 3
	legacy.permanent["classes"]["bruxa"].erase("unlocked_specials")
	legacy.save()
	var restored = RunState.new()
	restored.initialize(legacy_path)
	var witch: Dictionary = restored.permanent["classes"]["bruxa"]
	check(int(restored.permanent["coins"]) == 321 and int(witch["level"]) == 12 and int(witch["level_xp"]) == 37 and int(witch["xp"]) == 777 and int(witch["attributes"]["mana"]) == 3, "Save anterior preserva moedas, nível, XP e atributos")
	check(witch["unlocked_specials"].is_empty() and int(witch["available_points"]) == 8, "Save anterior sem especiais preserva saldo calculado")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(legacy_path))
