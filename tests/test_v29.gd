extends SceneTree

const ActionVisuals = preload("res://data/combat_action_visuals.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CombatSprites = preload("res://data/combat_sprites.gd")
const CombatEngine = preload("res://systems/combat_engine.gd")
const Rules = preload("res://systems/combat_rules.gd")
const Enemies = preload("res://data/enemies.gd")
const Game = preload("res://scripts/main_v8.gd")

const PATH := "user://torre_v29_test_state.json"
var failures: Array[String] = []
var checks_run := 0


func _initialize() -> void:
	call_deferred("run_all")


func check(condition: bool, message: String) -> void:
	checks_run += 1
	if not condition:
		failures.append(message)
		push_error(message)


func make_battle(ids: Array[String], enemy_ids: Array[String] = ["goblin", "esqueleto"]) -> CombatEngine:
	var heroes: Array[Dictionary] = []
	var enemies: Array[Dictionary] = []
	for id in ids:
		var hero: Dictionary = Rules.create_hero(id, 1, [])
		hero["initiative"] = 100
		hero["crit_chance"] = 0.0
		heroes.append(hero)
	for id in enemy_ids:
		var enemy: Dictionary = Enemies.get_definition(id)
		enemy["id"] = id
		enemy["team"] = "enemy"
		enemy["state"] = "alive"
		enemy["initiative"] = 1
		enemy["hp"] = 500
		enemy["max_hp"] = 500
		enemies.append(enemy)
	var combat := CombatEngine.new()
	combat.start(heroes, enemies)
	return combat


func make_feedback(ids: Array[String]) -> Control:
	var feedback := CombatFeedback.new()
	root.add_child(feedback)
	feedback.position = Vector2(0, 0)
	feedback.size = Vector2(720, 320)
	var cards: Dictionary = {}
	var all_ids: Array[String] = ids.duplicate()
	all_ids.append_array(["goblin", "esqueleto"])
	for i in all_ids.size():
		var id: String = all_ids[i]
		var sprite := TextureRect.new()
		sprite.texture = CombatSprites.side_texture_for(id) if id in ids else CombatSprites.texture_for(id)
		sprite.position = Vector2(32, 30 + i * 55) if id in ids else Vector2(560, 30 + (i - ids.size()) * 55)
		sprite.size = Vector2(48, 48)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		feedback.add_child(sprite)
		cards[id] = {"sprite": sprite}
	feedback.bind_arena(cards, ids)
	for id in all_ids:
		feedback.living[id] = true
	return feedback


func popup_count(feedback: Control) -> int:
	var count := 0
	for child in feedback.get_children():
		if child.name == "FloatingNumber":
			count += 1
	return count


func run_all() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	test_descriptors()
	await test_visual_sequences()
	await test_action_lock()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if failures.is_empty():
		print("V29: %d verificações de ações e animações passaram." % checks_run)
		quit(0)
	else:
		print("V29: %d falhas em %d verificações: %s" % [failures.size(), checks_run, "; ".join(failures)])
		quit(1)


func test_descriptors() -> void:
	var expectations := {"guerreiro": "melee", "patrulheiro": "arrow", "bruxa": "curse", "sacerdotisa": "melee", "feiticeiro": "arcane"}
	for id in expectations:
		var visual: Dictionary = ActionVisuals.hero_action(id, "attack", "goblin", ["goblin"])
		check(visual["style"] == expectations[id] and visual["targets"] == ["goblin"], "%s usa ataque visual correto" % id)
	var double_shot: Dictionary = ActionVisuals.hero_action("patrulheiro", "skill:disparo_duplo", "goblin", ["goblin"])
	check(double_shot["style"] == "arrow" and double_shot["hits"] == 2, "Disparo Duplo tem dois projéteis")
	var volley: Dictionary = ActionVisuals.hero_action("patrulheiro", "skill:chuva_flechas", "", ["goblin", "esqueleto"])
	check(volley["area"] and volley["targets"].size() == 2, "Habilidade física em área mantém os dois alvos")
	var fire: Dictionary = ActionVisuals.hero_action("feiticeiro", "skill:bola_de_fogo", "goblin", ["goblin"])
	check(fire["style"] == "fire", "Bola de Fogo tem visual vermelho")
	var wave: Dictionary = ActionVisuals.hero_action("feiticeiro", "skill:onda_arcana", "", ["goblin", "esqueleto"])
	check(wave["area"] and wave["style"] == "arcane", "Onda Arcana tem uma conjuração em área")
	var curse: Dictionary = ActionVisuals.hero_action("bruxa", "skill:maldicao_venenosa", "goblin", ["goblin"])
	check(curse["status"] and curse["style"] == "curse", "Maldição usa símbolo roxo")
	var vamp: Dictionary = ActionVisuals.hero_action("bruxa", "skill:vampirismo_arcano", "", ["bruxa"])
	check(vamp["targets"] == ["bruxa"] and vamp["style"] == "curse", "Vampirismo indica ativação no próprio herói")
	var cure: Dictionary = ActionVisuals.hero_action("sacerdotisa", "skill:cura", "guerreiro", ["guerreiro"])
	check(cure["style"] == "sacred" and cure["targets"] == ["guerreiro"], "Cura alcança o aliado escolhido")
	var prayer: Dictionary = ActionVisuals.hero_action("sacerdotisa", "skill:prece_restauradora", "", ["sacerdotisa", "guerreiro"])
	check(prayer["area"] and prayer["targets"].size() == 2, "Prece usa alvos do grupo")
	var revive: Dictionary = ActionVisuals.hero_action("sacerdotisa", "rescue", "guerreiro", ["guerreiro"])
	check(revive["style"] == "sacred" and revive["targets"] == ["guerreiro"], "Socorro possui brilho de reanimação")
	var enemy_melee: Dictionary = ActionVisuals.enemy_action("goblin", {"id": "attack", "target_id": "guerreiro"}, ["guerreiro"])
	check(enemy_melee["style"] == "melee", "Goblin avança para atacar")
	var enemy_magic: Dictionary = ActionVisuals.enemy_action("chefe", {"id": "shadow_wave"}, ["guerreiro", "bruxa"])
	check(enemy_magic["style"] == "curse" and enemy_magic["area"], "Onda Sombria usa magia em área")


func test_visual_sequences() -> void:
	for party in [["guerreiro"], ["patrulheiro", "bruxa"], ["guerreiro", "sacerdotisa", "feiticeiro"]]:
		var ids: Array[String] = []
		for id in party:
			ids.append(id)
		var feedback: Control = make_feedback(ids)
		await process_frame
		var actor_id: String = ids[0]
		var sprite: TextureRect = feedback.sprites[actor_id]
		var original: Vector2 = sprite.position
		var visual: Dictionary = ActionVisuals.hero_action(actor_id, "attack", "goblin", ["goblin"])
		var event := {"kind": "damage", "target_id": "goblin", "amount": 7, "visual_type": "physical", "critical": false}
		await feedback.play_action(visual, [event])
		check(sprite.position == original and sprite.rotation_degrees == 0.0 and feedback.active_actor == "", "Equipe de %d: atacante retorna ao idle" % ids.size())
		check(popup_count(feedback) == 1, "Equipe de %d: dano aparece uma única vez" % ids.size())
		feedback.queue_free()
		await process_frame
	var feedback: Control = make_feedback(["patrulheiro", "sacerdotisa", "feiticeiro"])
	await process_frame
	var double_shot: Dictionary = ActionVisuals.hero_action("patrulheiro", "skill:disparo_duplo", "goblin", ["goblin"])
	var before: int = feedback.displayed_event_count
	await feedback.play_action(double_shot, [{"kind": "damage", "target_id": "goblin", "amount": 12}, {"kind": "damage", "target_id": "goblin", "amount": 12}])
	check(feedback.displayed_event_count - before == 2, "Disparo Duplo mostra dois resultados, sem duplicar números")
	await create_timer(0.7).timeout
	var wave: Dictionary = ActionVisuals.hero_action("feiticeiro", "skill:onda_arcana", "", ["goblin", "esqueleto"])
	before = feedback.displayed_event_count
	await feedback.play_action(wave, [{"kind": "damage", "target_id": "goblin", "amount": 16}, {"kind": "damage", "target_id": "esqueleto", "amount": 16}])
	check(feedback.displayed_event_count - before == 2, "Ataque em área mostra um resultado por alvo")
	await create_timer(0.7).timeout
	var prayer: Dictionary = ActionVisuals.hero_action("sacerdotisa", "skill:prece_restauradora", "", ["patrulheiro", "sacerdotisa", "feiticeiro"])
	before = feedback.displayed_event_count
	await feedback.play_action(prayer, [{"kind": "heal", "target_id": "patrulheiro", "amount": 10}, {"kind": "heal", "target_id": "feiticeiro", "amount": 14}])
	check(feedback.displayed_event_count - before == 2, "Cura em grupo mostra somente os aliados beneficiados")
	await create_timer(0.7).timeout
	var revive: Dictionary = ActionVisuals.hero_action("sacerdotisa", "skill:milagre_divino", "patrulheiro", ["patrulheiro"])
	before = feedback.displayed_event_count
	await feedback.play_action(revive, [{"kind": "heal", "target_id": "patrulheiro", "amount": 38}])
	check(feedback.displayed_event_count - before == 1, "Reanimação mostra uma única cura no aliado")
	await feedback.play_action(ActionVisuals.enemy_action("goblin", {"id": "attack", "target_id": "patrulheiro"}, ["patrulheiro"]), [{"kind": "damage", "target_id": "patrulheiro", "amount": 10}])
	check(feedback.sprites["goblin"].position == feedback.origins["goblin"], "Inimigo retorna à posição depois do ataque")
	feedback.queue_free()
	await process_frame
	var witch_feedback: Control = make_feedback(["bruxa"])
	await process_frame
	var curse: Dictionary = ActionVisuals.hero_action("bruxa", "skill:maldicao_venenosa", "goblin", ["goblin"])
	before = witch_feedback.displayed_event_count
	await witch_feedback.play_action(curse, [])
	check(witch_feedback.displayed_event_count == before and witch_feedback.active_actor == "", "Maldição mostra símbolo e não cria número")
	witch_feedback.queue_free()
	await process_frame


func test_action_lock() -> void:
	var game: Control = Game.new()
	game.run.save_path = PATH
	root.add_child(game)
	await process_frame
	var party: Array[String] = ["bruxa"]
	game.run.new_attempt(party)
	game.run.begin_floor()
	game.open_combat()
	await process_frame
	game.choose_action("attack")
	game.target_chosen("goblin")
	var hp_after_first: int = int(game.combat.fighters["goblin"]["hp"])
	check(game.resolving_visual_action, "Ação visual bloqueia comandos repetidos")
	check(game.visual_actor_id == "bruxa" and game.turn_label.text.contains("Bruxa") and game.buttons["attack"].disabled, "Ator permanece destacado enquanto a animação resolve")
	game.choose_action("attack")
	game.target_chosen("goblin")
	check(int(game.combat.fighters["goblin"]["hp"]) == hp_after_first, "Clique repetido não reaplica dano")
	await create_timer(0.8).timeout
	check(not game.resolving_visual_action and game.visual_actor_id == "", "Controle é liberado depois da animação")
	game.menu()
	await process_frame
	check(game.combat_feedback == null or not is_instance_valid(game.combat_feedback) or not game.combat_feedback.is_inside_tree(), "Troca de tela libera a animação anterior")
	game.run.new_attempt(party)
	game.run.begin_floor()
	game.open_combat()
	await process_frame
	game.choose_action("attack")
	game.target_chosen("goblin")
	check(game.resolving_visual_action, "Animação em andamento antes da troca de tela")
	game.menu()
	await create_timer(0.8).timeout
	check(game.screen != null and is_instance_valid(game.screen), "Troca de tela durante a animação termina sem bloquear o menu")
	game.queue_free()
	await process_frame
	var enemy_first: Control = Game.new()
	enemy_first.run.save_path = PATH
	root.add_child(enemy_first)
	await process_frame
	var warrior_party: Array[String] = ["guerreiro"]
	enemy_first.run.new_attempt(warrior_party)
	enemy_first.run.begin_floor()
	enemy_first.open_combat()
	await process_frame
	check(not enemy_first.combat.is_hero_turn(), "Inimigo com maior iniciativa abre o combate")
	var hp_before: int = int(enemy_first.combat.fighters["guerreiro"]["hp"])
	await create_timer(1.1).timeout
	check(int(enemy_first.combat.fighters["guerreiro"]["hp"]) < hp_before, "Inimigo inicial executa ataque após a animação")
	enemy_first.menu()
	enemy_first.queue_free()
