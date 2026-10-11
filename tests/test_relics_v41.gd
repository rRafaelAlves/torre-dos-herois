extends SceneTree

const Relics = preload("res://data/relics.gd")
const Equipment = preload("res://systems/relic_equipment.gd")
const Rules = preload("res://systems/combat_rules.gd")
const RunState = preload("res://systems/run_state.gd")
const CombatEngine = preload("res://systems/combat_engine.gd")
const SaveStore = preload("res://systems/save_store.gd")
const StateEffects = preload("res://systems/state_effects.gd")
const Skills = preload("res://data/skills.gd")
const Game = preload("res://scripts/main_v8.gd")
const DevOps = preload("res://systems/dev_operations.gd")

const PATH_A := "user://v41_relic_a.json"
const PATH_B := "user://v41_relic_b.json"
const PATH_OLD := "user://v41_relic_legacy.json"
const PATH_DEV := "user://v41_relic_a.json.dev"
const PATH_SETUP := "user://v41_relic_setup.json"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run_all")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func clean(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func equipped(relic_id: String, bearer: String = "", mode: String = "temporary") -> Dictionary:
	return {"uid": "%s-%s-%s" % [relic_id, bearer, mode], "id": relic_id, "bearer": bearer, "mode": mode}


func enemy(enemy_id: String, hp: int = 500, damage: int = 20) -> Dictionary:
	return {"id": enemy_id, "name": enemy_id, "team": "enemy", "state": "alive", "hp": hp, "max_hp": hp, "damage": damage, "initiative": 1, "attack_type": "physical", "physical_resist": 0.0, "magical_resist": 0.0, "special": ""}


func hero(hero_id: String = "guerreiro", relics: Array = []) -> Dictionary:
	var value: Dictionary = Rules.create_hero(hero_id, 1, relics)
	value["crit_chance"] = 0.0
	value["initiative"] = 99
	return value


func battle(relics: Array, heroes: Array = [], enemies: Array = []) -> RefCounted:
	var engine := CombatEngine.new()
	engine.start(heroes if not heroes.is_empty() else [hero("guerreiro", relics)], enemies if not enemies.is_empty() else [enemy("dummy")], relics)
	return engine


func run_all() -> void:
	for path in [PATH_A, PATH_B, PATH_OLD, PATH_DEV, PATH_SETUP]:
		clean(path)
	test_catalog_and_stats()
	test_inventory_and_saves()
	test_next_attempt_loadout()
	test_combat_effects()
	test_remaining_effects()
	test_legacy_migration()
	test_dev_isolation()
	await test_ui()
	for path in [PATH_A, PATH_B, PATH_OLD, PATH_DEV, PATH_SETUP]:
		clean(path)
	if failures.is_empty():
		print("Relíquias V41: %d verificações passaram." % checks)
		quit(0)
	else:
		print("Relíquias V41: %d falhas em %d verificações: %s" % [failures.size(), checks, "; ".join(failures)])
		quit(1)


func test_catalog_and_stats() -> void:
	var rarities := {"simple": 0, "rare": 0, "epic": 0}
	for relic_id in Relics.DEFINITIONS:
		var definition: Dictionary = Relics.definition(relic_id)
		check(not str(definition.get("name", "")).is_empty() and not str(definition.get("description", "")).is_empty() and definition.has("rarity") and definition.has("scope"), "Metadados completos de %s" % relic_id)
		if not bool(definition.get("legacy", false)):
			rarities[definition["rarity"]] += 1
	check(rarities == {"simple": 15, "rare": 10, "epic": 5}, "Catálogo tem 15 Simples, 10 Raras e 5 Épicas novas")
	for relic_id in Relics.available([], ["guerreiro"]):
		check(Relics.DEFINITIONS[relic_id]["rarity"] == "simple", "Recompensa da torre só oferece Simples")
	var baseline := hero()
	var oak := hero("guerreiro", [equipped("amuleto_carvalho", "guerreiro"), equipped("estandarte_vale")])
	check(int(oak["max_hp"]) == roundi(float(baseline["max_hp"]) * 1.12), "Bônus individuais e coletivos de PV usam base real")
	var active := Rules.create_hero("bruxa", 1, [equipped("reserva_arcana", "bruxa"), equipped("botas_vento", "bruxa"), equipped("relogio_vento"), equipped("simbolo_graca", "bruxa"), equipped("olho_cacador", "bruxa"), equipped("ferrao_esmeralda", "bruxa")])
	var plain := Rules.create_hero("bruxa", 1, [])
	check(int(active["mana_max"]) == int(plain["mana_max"]) + 8, "Reserva Arcana aumenta mana máxima")
	check(int(active["initiative"]) == int(plain["initiative"]) + 2, "Iniciativa individual e coletiva soma corretamente")
	check(is_equal_approx(float(active["heal_multiplier"]), float(plain["heal_multiplier"]) + 0.10), "Símbolo da Graça modifica cura")
	check(int(active["poison_relic_bonus"]) == 1 and is_equal_approx(float(active["crit_chance"]), float(plain["crit_chance"]) + 0.04), "Veneno e crítico recebem os bônus corretos")
	var guarded := hero("guerreiro", [equipped("pedra_bastiao", "guerreiro"), equipped("egide_nevoa", "guerreiro")])
	check(Rules.damage_packet(enemy("a"), guarded, 100, "physical", false, false, 1.0)["amount"] == 94, "Bastião reduz 6% do dano físico")
	check(Rules.damage_packet(enemy("a"), guarded, 100, "magical", false, false, 1.0)["amount"] == 94, "Égide reduz 6% do dano mágico")
	var warrior := hero("guerreiro", [equipped("punho_aco", "guerreiro"), equipped("insignia_guerreiro", "guerreiro")])
	var target := enemy("a")
	check(int(Rules.damage_packet(warrior, target, 100, "physical", true, false, 1.0)["amount"]) == 117, "Dano físico e ataque básico usam multiplicadores reais")
	var witch := hero("bruxa", [equipped("cristal_prismatico", "bruxa")])
	check(int(Rules.damage_packet(witch, target, 100, "magical", false, true, 1.0)["amount"]) == 106, "Cristal aumenta o dano mágico")


func test_inventory_and_saves() -> void:
	var run := RunState.new()
	run.initialize(PATH_A)
	var copies: Array[String] = []
	for index in 4:
		copies.append(run.grant_relic("amuleto_carvalho", "permanent"))
	check(copies.size() == 4 and not copies.has(""), "Inventário aceita mais cópias do que espaços")
	for index in 3:
		check(run.equip_relic(copies[index], "guerreiro"), "Três espaços permanentes individuais equipam")
	check(not run.equip_relic(copies[3], "guerreiro"), "Quarto espaço permanente individual é bloqueado")
	check(run.equip_relic(copies[3], "guerreiro", "", copies[0]), "Troca substitui uma cópia equipada")
	check(run.equip_relic(copies[3], "bruxa") and run.permanent["relic_equipped"].filter(func(entry: Dictionary) -> bool: return entry.get("uid", "") == copies[3]).size() == 1, "Transferência move a cópia sem duplicá-la")
	var group_ids: Array[String] = []
	for index in 3:
		group_ids.append(run.grant_relic("estandarte_vale", "permanent"))
	check(run.equip_relic(group_ids[0], "") and run.equip_relic(group_ids[1], ""), "Dois espaços permanentes coletivos equipam")
	check(not run.equip_relic(group_ids[2], ""), "Terceiro espaço permanente coletivo é bloqueado")
	var epic_one := run.grant_relic("chama_retornados", "permanent")
	var epic_two := run.grant_relic("chama_retornados", "permanent")
	check(not run.equip_relic(epic_one, ""), "Épica respeita lotação coletiva")
	check(run.unequip_relic(group_ids[0]) and run.equip_relic(epic_one, ""), "Épica equipa após liberar espaço")
	check(not run.equip_relic(epic_two, "", "", group_ids[1]), "Mesma épica não acumula na equipe")
	check(run.equip_relic(epic_two, "", "", epic_one), "Troca de uma cópia épica por outra mantém apenas um efeito")
	check(run.new_attempt(["guerreiro", "bruxa"]), "Expedição inicia com equipamento permanente")
	var temp_epic := run.grant_relic("chama_retornados", "temporary")
	check(not run.equip_relic(temp_epic, ""), "Mesma épica não combina entre modalidades")
	check(run.attempt["relics"].size() == 5, "Expedição recebe somente cópias permanentes equipadas")
	var temporary := run.grant_relic("frasco_regeneracao", "temporary")
	check(not temporary.is_empty() and run.equip_relic(temporary, "bruxa"), "Relíquia temporária equipa em espaço separado")
	var loaded := RunState.new()
	loaded.initialize(PATH_A)
	check(loaded.permanent["relic_inventory"].size() == 9 and loaded.attempt["relic_inventory"].size() == 2, "Inventários persistem após recarregar")
	check(loaded.attempt["relics"].size() == 6, "Portadores e modalidades persistem")
	var another := RunState.new()
	another.initialize(PATH_B)
	check(another.permanent["relic_inventory"].is_empty(), "Outro salvamento não herda relíquias")
	check(another.new_attempt(["guerreiro"]), "Outra expedição inicia independente")
	var temp_hero: Array[String] = []
	for index in 4:
		temp_hero.append(another.grant_relic("pedra_bastiao", "temporary"))
	for index in 3:
		check(another.equip_relic(temp_hero[index], "guerreiro"), "Três espaços temporários individuais equipam")
	check(not another.equip_relic(temp_hero[3], "guerreiro"), "Quarto espaço temporário individual é bloqueado")
	var temp_group: Array[String] = []
	for index in 3:
		temp_group.append(another.grant_relic("relogio_vento", "temporary"))
	check(another.equip_relic(temp_group[0], "") and another.equip_relic(temp_group[1], ""), "Dois espaços temporários coletivos equipam")
	check(not another.equip_relic(temp_group[2], ""), "Terceiro espaço temporário coletivo é bloqueado")
	another.end_attempt("defeat")
	check(another.permanent["relic_inventory"].is_empty() and another.attempt.is_empty(), "Relíquias temporárias são descartadas sem contaminar outro save")
	loaded.end_attempt("defeat")
	check(loaded.attempt.is_empty() and loaded.permanent["relic_inventory"].size() == 9, "Derrota descarta temporárias e preserva inventário permanente")
	check(loaded.permanent["relic_equipped"].is_empty() and loaded.permanent["last_relic_loadout"].size() == 5, "Permanentes retornam ao inventário e configuração fica salva")
	check(loaded.reequip_last_relics() and loaded.permanent["relic_equipped"].size() == 5, "Reequipamento rápido restaura configuração")


func test_combat_effects() -> void:
	var mirror_relics := [equipped("espelho_batalha", "guerreiro")]
	var mirror = battle(mirror_relics)
	var before := int(mirror.fighters["guerreiro"]["hp"])
	mirror._deal_damage("dummy", "guerreiro", 20, "physical", false, false)
	check(before - int(mirror.fighters["guerreiro"]["hp"]) == 8, "Espelho reduz primeiro golpe em 60%")
	before = int(mirror.fighters["guerreiro"]["hp"])
	mirror._deal_damage("dummy", "guerreiro", 20, "physical", false, false)
	check(before - int(mirror.fighters["guerreiro"]["hp"]) == 20, "Espelho ativa só uma vez por combate")
	var rebirth = battle([equipped("relogio_renascimento", "guerreiro")])
	rebirth._deal_damage("dummy", "guerreiro", 999, "physical", false, false)
	check(rebirth.fighters["guerreiro"]["state"] == "alive" and int(rebirth.fighters["guerreiro"]["hp"]) == ceili(float(rebirth.fighters["guerreiro"]["max_hp"]) * 0.25), "Relógio impede dano fatal uma vez")
	rebirth._deal_damage("dummy", "guerreiro", 999, "physical", false, false)
	check(rebirth.fighters["guerreiro"]["state"] == "downed", "Relógio não ativa novamente no mesmo combate")
	var flame = battle([equipped("chama_retornados")])
	flame._deal_damage("dummy", "guerreiro", 999, "physical", false, false)
	check(flame.fighters["guerreiro"]["state"] == "alive" and bool(flame.relic_used.get("chama_retornados", false)), "Chama reanima antes da derrota")
	var storm_relics := [equipped("lamina_tempestade", "guerreiro")]
	var storm = battle(storm_relics, [], [enemy("first"), enemy("second")])
	for index in 3:
		storm._deal_damage("guerreiro", "first", 10, "physical", false, false)
	check(int(storm.fighters["second"]["hp"]) < 500 and int(storm.relic_counts.get("lamina_uses:guerreiro", 0)) == 1, "Lâmina descarrega no terceiro acerto")
	var echo = battle([equipped("codice_eco", "bruxa")], [hero("bruxa", [equipped("codice_eco", "bruxa")])])
	check(echo.act("skill:raio_arcano", "dummy") and bool(echo.relic_used.get("codice_eco:bruxa", false)), "Códice repete a primeira habilidade ofensiva")
	check(echo.events.any(func(message: String) -> bool: return message.contains("Códice do Eco")), "Repetição aparece nos eventos")
	var bell_relics := [equipped("sino_misericordia", "sacerdotisa")]
	var bell = battle(bell_relics, [hero("sacerdotisa", bell_relics), hero("guerreiro")])
	var wounded: Dictionary = bell.fighters["guerreiro"]
	wounded["hp"] = 20
	StateEffects.apply(wounded, "veneno")
	bell.fighters["guerreiro"] = wounded
	bell._maybe_mercy_bell("sacerdotisa", "guerreiro", 20, 12)
	check(StateEffects.get_effect(bell.fighters["guerreiro"], "veneno").is_empty(), "Sino remove Veneno após cura crítica")
	var poison_relics := [equipped("ferrao_esmeralda", "patrulheiro")]
	var poison = battle(poison_relics, [hero("patrulheiro", poison_relics)])
	StateEffects.apply(poison.fighters["dummy"], "veneno")
	poison._enhance_poison("patrulheiro", "dummy", "veneno")
	check(int(StateEffects.get_effect(poison.fighters["dummy"], "veneno")["intensity"]) == 9, "Ferrão aumenta intensidade do Veneno sem duplicar")
	var march = battle([equipped("marcha_conclave")])
	check(bool(march.fighters["guerreiro"]["relic_march_protection"]), "Marcha protege no começo do combate")
	march._deal_damage("dummy", "guerreiro", 20, "physical", false, false)
	check(int(march.fighters["guerreiro"]["hp"]) == int(march.fighters["guerreiro"]["max_hp"]) - 16, "Marcha reduz 20% do dano")
	var ashes = battle([equipped("vinculo_cinzas")], [hero("guerreiro"), hero("bruxa")])
	ashes._deal_damage("dummy", "guerreiro", 999, "physical", false, false)
	check(bool(ashes.relic_used.get("ashes_boost:bruxa", false)), "Vínculo fortalece sobrevivente ao cair aliado")
	var aurora = battle([equipped("juramento_aurora")])
	aurora._deal_damage("dummy", "guerreiro", 100, "physical", false, false)
	check(bool(aurora.relic_used.get("juramento_aurora", false)) and bool(aurora.fighters["guerreiro"]["relic_aurora_protection"]), "Juramento ativa abaixo de 40% dos PV")
	var purify = battle([equipped("circulo_purificacao")], [hero("guerreiro"), hero("bruxa")])
	StateEffects.apply(purify.fighters["guerreiro"], "veneno")
	StateEffects.apply(purify.fighters["bruxa"], "fraqueza")
	purify._check_purification()
	check(StateEffects.get_effect(purify.fighters["guerreiro"], "veneno").is_empty() and StateEffects.get_effect(purify.fighters["bruxa"], "fraqueza").is_empty(), "Círculo remove um efeito dos dois aliados")


func test_next_attempt_loadout() -> void:
	var run := RunState.new()
	run.initialize(PATH_SETUP)
	var old_uid := run.grant_relic("amuleto_carvalho", "permanent")
	run.equip_relic(old_uid, "guerreiro")
	run.new_attempt(["guerreiro"])
	run.attempt["phase"] = "combat"
	run.save()
	var new_uid := run.grant_relic("botas_vento", "permanent")
	check(run.equip_relic(new_uid, "guerreiro", "selection"), "Seleção permite preparar equipamento da próxima expedição")
	check(not run.attempt["relics"].any(func(item: Dictionary) -> bool: return item.get("uid", "") == new_uid), "Preparação não altera relíquias do combate salvo")
	var restored := RunState.new()
	restored.initialize(PATH_SETUP)
	check(not restored.attempt["relics"].any(func(item: Dictionary) -> bool: return item.get("uid", "") == new_uid), "Recarregar preserva equipamento original do combate")
	restored.new_attempt(["guerreiro"])
	check(restored.attempt["relics"].any(func(item: Dictionary) -> bool: return item.get("uid", "") == new_uid), "Nova expedição usa equipamento preparado")


func test_remaining_effects() -> void:
	var persistence = battle([equipped("anel_persistencia", "bruxa")], [hero("bruxa", [equipped("anel_persistencia", "bruxa")])])
	persistence.fighters["bruxa"]["mana"] = 0
	check(persistence.act("defend") and int(persistence.fighters["bruxa"]["mana"]) == 2, "Anel recupera 2 mana ao Defender")
	var arcane = battle([equipped("ampulheta_arcana", "bruxa")], [hero("bruxa", [equipped("ampulheta_arcana", "bruxa")])])
	var mana_before := int(arcane.fighters["bruxa"]["mana"])
	check(arcane.act("skill:raio_arcano", "dummy") and int(arcane.fighters["bruxa"]["mana"]) == mana_before, "Ampulheta devolve custo integral da primeira habilidade")
	var pact = battle([equipped("pacto_cacador", "guerreiro")])
	pact._prepare_offensive_action("guerreiro", "dummy")
	pact._prepare_offensive_action("guerreiro", "dummy")
	check(is_equal_approx(float(pact.action_multiplier["guerreiro"]), 1.20), "Pacto aumenta segundo ataque consecutivo ao mesmo alvo")
	pact._prepare_offensive_action("guerreiro", "dummy")
	check(is_equal_approx(float(pact.action_multiplier["guerreiro"]), 1.0), "Terceiro ataque inicia novo par do Pacto")
	var thorns = battle([equipped("coracao_espinhos", "guerreiro")])
	thorns._deal_damage("dummy", "guerreiro", 20, "physical", false, false)
	check(int(thorns.fighters["dummy"]["hp"]) == 496, "Coração devolve 20% do dano físico direto")
	var chalice = battle([equipped("taca_carmesim", "guerreiro")])
	chalice.fighters["guerreiro"]["hp"] = 60
	StateEffects.apply(chalice.fighters["dummy"], "veneno")
	chalice._deal_damage("guerreiro", "dummy", 40, "physical", false, false)
	check(int(chalice.fighters["guerreiro"]["hp"]) == 66, "Taça converte 15% do dano ao inimigo envenenado em cura")
	var executor = battle([equipped("mascara_executor", "guerreiro")], [], [enemy("victim", 5), enemy("next")])
	executor._deal_damage("guerreiro", "victim", 10, "physical", false, false)
	executor._prepare_offensive_action("guerreiro", "next")
	check(bool(executor.relic_used.get("mascara_executor:guerreiro", false)) and is_equal_approx(float(executor.action_multiplier["guerreiro"]), 1.40), "Máscara fortalece próximo ataque após eliminar inimigo")
	var legacy_hp := hero("guerreiro", [equipped("medalhao_vital")])
	check(int(legacy_hp["max_hp"]) == roundi(float(hero()["max_hp"]) * 1.10), "Medalhão Vital antigo preserva efeito")
	var legacy_mana = battle([equipped("pedra_arcana", "bruxa")], [hero("bruxa", [equipped("pedra_arcana", "bruxa")])])
	var skill_cost := int(legacy_mana.fighters["bruxa"]["mana"])
	legacy_mana.act("skill:raio_arcano", "dummy")
	check(int(legacy_mana.fighters["bruxa"]["mana"]) == skill_cost - int(Skills.get_definition("raio_arcano").get("mana", 0)) + 2, "Pedra Arcana antiga ainda recupera mana")
	var triple = battle([equipped("relogio_vento")], [hero("guerreiro"), hero("bruxa"), hero("patrulheiro")])
	check(triple.hero_ids.size() == 3 and triple._has_relic("relogio_vento", "patrulheiro"), "Relíquia coletiva alcança equipe de três heróis")
	var heal_run := RunState.new()
	heal_run.initialize(PATH_B)
	heal_run.new_attempt(["guerreiro", "bruxa"])
	var bottle := heal_run.grant_relic("frasco_regeneracao", "temporary")
	var herbs := heal_run.grant_relic("bolsa_ervas", "temporary")
	heal_run.equip_relic(bottle, "guerreiro")
	heal_run.equip_relic(herbs, "")
	heal_run.attempt["phase"] = "combat"
	var states: Array[Dictionary] = heal_run.attempt["heroes"].duplicate(true)
	for member in states:
		member["hp"] = 50
	heal_run.victory(states)
	check(int(heal_run.attempt["heroes"][0]["hp"]) == 50 + roundi(float(heal_run.attempt["heroes"][0]["max_hp"]) * 0.05) + 3, "Frasco e Bolsa curam portador após vitória")
	check(int(heal_run.attempt["heroes"][1]["hp"]) == 53, "Bolsa cura todos os sobreviventes da equipe")


func test_legacy_migration() -> void:
	var old := RunState.new()
	old.initialize(PATH_OLD)
	old.permanent["coins"] = 77
	old.new_attempt(["bruxa"])
	old.attempt["relics"] = [{"id": "pedra_arcana", "bearer": "bruxa"}]
	var payload := {"version": 2, "permanent": old.permanent, "attempt": old.attempt}
	var normalized: Dictionary = JSON.parse_string(JSON.stringify(payload, "", true))
	payload["checksum"] = JSON.stringify(normalized, "", true).sha256_text()
	var file := FileAccess.open(PATH_OLD, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var migrated := RunState.new()
	migrated.initialize(PATH_OLD)
	check(int(migrated.permanent["coins"]) == 77 and migrated.attempt["relics"].size() == 1, "Save V2 mantém moedas e relíquia antiga")
	check(str(migrated.attempt["relics"][0].get("mode", "")) == "temporary" and migrated.attempt["relic_inventory"].size() == 1, "Relíquia antiga vira cópia temporária")
	check(FileAccess.file_exists(PATH_OLD + ".bak") and int(SaveStore.load_data(PATH_OLD).get("version", 0)) == SaveStore.VERSION, "Migração mantém backup e grava V3")


func test_dev_isolation() -> void:
	var dev := RunState.new()
	dev.initialize(PATH_DEV)
	dev.new_attempt(["guerreiro"])
	dev.attempt["phase"] = "combat"
	check(DevOps.grant_relic(dev, "espelho_batalha", "permanent"), "DEV concede relíquia permanente")
	check(DevOps.equip_relic(dev, "espelho_batalha", "guerreiro", "permanent"), "DEV equipa relíquia permanente")
	check(DevOps.grant_relic(dev, "chama_retornados", "temporary"), "DEV concede relíquia temporária")
	check(DevOps.equip_relic(dev, "chama_retornados", "", "temporary"), "DEV equipa relíquia coletiva")
	check(DevOps.remove_relic(dev, "chama_retornados", "temporary"), "DEV remove uma cópia")
	var normal := RunState.new()
	normal.initialize(PATH_A)
	check(normal.permanent["relic_inventory"].size() == 9 and not normal.attempt.get("relics", []).any(func(item: Dictionary) -> bool: return item.get("id", "") == "espelho_batalha"), "Perfil DEV não altera salvamento normal")


func test_ui() -> void:
	var game: Control = Game.new()
	game.run.save_path = PATH_B
	game.size = Vector2(1100, 760)
	root.add_child(game)
	await process_frame
	var ui_uid: String = game.run.grant_relic("amuleto_carvalho", "permanent")
	game.show_relic_inventory("progression", "guerreiro")
	check(game.screen.find_child("RelicInventoryScroll", true, false) != null and game.screen.find_child("RelicBearerSelector", true, false) != null, "Inventário abre na progressão com seleção de portador")
	var equip_button: Button = game.screen.find_child("RelicEquip_%s" % ui_uid, true, false)
	check(equip_button != null and not equip_button.disabled, "Cópia disponível mostra ação de equipar")
	if equip_button != null:
		equip_button.pressed.emit()
		check(game.run.permanent["relic_equipped"].size() == 1, "Botão da interface equipa e salva a cópia")
	var remove_button: Button = game.screen.find_child("RelicUnequip_%s" % ui_uid, true, false)
	if remove_button != null:
		remove_button.pressed.emit()
	check(game.run.permanent["relic_equipped"].is_empty(), "Botão da interface desequipa a cópia")
	game.show_selection()
	game._open_relics_from_selection()
	check(game.screen.find_child("RelicInventoryBack", true, false) != null, "Seleção de heróis abre inventário")
	game._return_from_relic_inventory("selection")
	check(game.screen.find_child("SelectionRelics", true, false) != null, "Inventário retorna à seleção")
	var camp_team: Array[String] = ["bruxa"]
	game.run.new_attempt(camp_team)
	game.run.attempt["merchant_camp_status"] = "visiting"
	game.show_merchant_camp(true)
	var camp: Control = game.screen.find_child("MerchantCamp", true, false)
	check(camp != null, "Acampamento abre com inventário disponível")
	if camp != null:
		camp.equipment_requested.emit()
		check(game.screen.find_child("RelicInventoryScroll", true, false) != null, "Comerciante abre gerenciamento de relíquias")
		game._return_from_relic_inventory("camp")
		check(game.screen.find_child("MerchantCamp", true, false) != null, "Gerenciamento retorna ao acampamento")
	game.queue_free()
	await process_frame
	await process_frame
