extends SceneTree

const Game = preload("res://scripts/main_v8.gd")
const Rules = preload("res://systems/combat_rules.gd")
const CombatEngine = preload("res://systems/combat_engine.gd")
const CombatSprites = preload("res://data/combat_sprites.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const Effects = preload("res://systems/state_effects.gd")
const Enemies = preload("res://data/enemies.gd")

const PATH := "user://torre_v28_test_state.json"
var failures: Array[String] = []
var checks_run: int = 0

func _initialize() -> void:
	call_deferred("run_all")

func check(value: bool, message: String) -> void:
	checks_run += 1
	if not value:
		failures.append(message)
		push_error(message)

func enemy(id: String = "goblin", hp: int = 500) -> Dictionary:
	var value: Dictionary = Enemies.get_definition(id)
	value["id"] = id
	value["team"] = "enemy"
	value["state"] = "alive"
	value["max_hp"] = hp
	value["hp"] = hp
	value["initiative"] = 1
	return value

func hero(id: String) -> Dictionary:
	var value: Dictionary = Rules.create_hero(id, 1, [])
	value["initiative"] = 100
	value["crit_chance"] = 0.0
	return value

func battle(heroes: Array[String], enemies: Array[String] = ["goblin"]):
	var team: Array[Dictionary] = []
	var foes: Array[Dictionary] = []
	for id in heroes:
		team.append(hero(id))
	for id in enemies:
		foes.append(enemy(id))
	var combat = CombatEngine.new()
	combat.start(team, foes)
	return combat

func run_all() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	test_idle_frames()
	test_damage_events()
	test_healing_events()
	await test_feedback_scene()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if failures.is_empty():
		print("V28: %d verificações visuais e de eventos passaram." % checks_run)
		quit(0)
	else:
		print("V28: %d falhas em %d verificações: %s" % [failures.size(), checks_run, "; ".join(failures)])
		quit(1)

func test_idle_frames() -> void:
	for id in ["guerreiro", "patrulheiro", "bruxa", "sacerdotisa", "feiticeiro"]:
		var frames: Array[Texture2D] = CombatSprites.idle_frames_for(id)
		check(frames.size() == 3 and frames[0] == CombatSprites.side_texture_for(id), "%s tem três frames, primeiro original" % id)
		var original: Image = frames[0].get_image()
		var second: Image = frames[1].get_image()
		var third: Image = frames[2].get_image()
		check(original.get_width() == second.get_width() and original.get_height() == third.get_height(), "%s mantém dimensões de 24 pixels" % id)
		var changed_two := false
		var changed_three := false
		var grounded := true
		for y in original.get_height():
			for x in original.get_width():
				if original.get_pixel(x, y) != second.get_pixel(x, y):
					changed_two = true
				if original.get_pixel(x, y) != third.get_pixel(x, y):
					changed_three = true
				if y >= 16:
					var base_pixel: Color = original.get_pixel(x, y)
					for frame_pixel in [second.get_pixel(x, y), third.get_pixel(x, y)]:
						if not is_equal_approx(base_pixel.a, frame_pixel.a) or (base_pixel.a > 0.1 and not base_pixel.is_equal_approx(frame_pixel)):
							grounded = false
		check(changed_two and changed_three, "%s possui duas variações reais" % id)
		check(grounded, "%s mantém pés e chão na mesma posição" % id)

func test_damage_events() -> void:
	var physical = battle(["guerreiro"])
	physical.fighters["goblin"]["hp"] = 3
	physical.act("attack", "goblin")
	check(physical.visual_events.size() == 1 and physical.visual_events[0]["amount"] == 3 and physical.visual_events[0]["visual_type"] == "physical", "Ataque físico mostra dano efetivo, inclusive golpe final")
	var fire = battle(["feiticeiro"])
	fire.act("skill:bola_de_fogo", "goblin")
	check(fire.visual_events.size() == 1 and fire.visual_events[0]["visual_type"] == "fire" and int(fire.fighters["goblin"]["hp"]) == 470, "Bola de Fogo tem cor de fogo e cálculo mágico intacto")
	var arcane = battle(["bruxa"])
	arcane.act("skill:raio_arcano", "goblin")
	check(arcane.visual_events[0]["visual_type"] == "magical", "Raio Arcano permanece roxo")
	var radiant = battle(["bruxa"])
	radiant.fighters["bruxa"]["radiant_fraction"] = 0.35
	radiant.act("skill:raio_arcano", "goblin")
	check(radiant.visual_events[0]["visual_type"] == "radiant", "Dano com parcela Radiante recebe destaque dourado")
	var poison = battle(["bruxa"])
	poison.fighters["goblin"]["hp"] = 2
	poison._apply_poison_damage("goblin", 8)
	check(poison.visual_events.size() == 1 and poison.visual_events[0]["amount"] == 2 and poison.visual_events[0]["visual_type"] == "poison", "Veneno mostra dano efetivo verde")
	var critical = battle(["guerreiro"])
	critical.fighters["guerreiro"]["crit_chance"] = 1.0
	critical.act("attack", "goblin")
	check(critical.visual_events[0]["critical"] and critical.visual_events[0]["amount"] == 30, "Crítico visual usa resultado real de 30 dano")
	var area = battle(["feiticeiro"], ["goblin", "esqueleto"])
	area.act("skill:onda_arcana")
	check(area.visual_events.size() == 2 and area.visual_events[0]["target_id"] != area.visual_events[1]["target_id"], "Ataque em área gera um número por inimigo vivo")
	var multi = battle(["patrulheiro"])
	multi.act("skill:disparo_duplo", "goblin")
	check(multi.visual_events.size() == 2 and multi.visual_events[0]["target_id"] == "goblin", "Golpe duplo mantém dois números separados")
	var retaliation = battle(["guerreiro"])
	retaliation.fighters["guerreiro"]["defending"] = true
	retaliation.fighters["guerreiro"]["retaliation_damage"] = 4
	retaliation.index = retaliation.order.find("goblin")
	retaliation._plan_enemy_intention("goblin")
	retaliation.act_enemy()
	check(retaliation.visual_events.size() == 2 and retaliation.visual_events[1]["target_id"] == "goblin" and retaliation.visual_events[1]["amount"] == 4, "Retaliação gera número no inimigo sem dano duplicado")

func test_healing_events() -> void:
	var cure = battle(["sacerdotisa"])
	cure.fighters["sacerdotisa"]["hp"] = 88
	cure.act("skill:cura", "sacerdotisa")
	check(cure.visual_events.size() == 1 and cure.visual_events[0]["kind"] == "heal" and cure.visual_events[0]["amount"] == 2, "Cura mostra apenas os 2 PV efetivos")
	var full = battle(["sacerdotisa"])
	full.act("skill:cura", "sacerdotisa")
	check(full.visual_events.is_empty(), "Cura em PV máximo não mostra valor fictício")
	var revived = battle(["sacerdotisa", "guerreiro"])
	revived.fighters["guerreiro"]["state"] = "downed"
	revived.fighters["guerreiro"]["hp"] = 0
	revived.act("rescue", "guerreiro")
	check(revived.visual_events.size() == 1 and revived.visual_events[0]["amount"] == 25, "Socorro mostra PV da reanimação")
	var prayer = battle(["sacerdotisa", "guerreiro"])
	prayer.fighters["sacerdotisa"]["hp"] = 80
	prayer.fighters["guerreiro"]["hp"] = 80
	prayer.fighters["sacerdotisa"]["unlocked_specials"] = ["prece_restauradora"]
	prayer.act("skill:prece_restauradora")
	check(prayer.visual_events.size() == 2 and prayer.visual_events[0]["amount"] == 10 and prayer.visual_events[1]["amount"] == 14, "Prece gera números efetivos individuais para cada aliado")

func test_feedback_scene() -> void:
	var game = Game.new()
	game.run.save_path = PATH
	root.add_child(game)
	game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	for ids in [["bruxa"], ["bruxa", "guerreiro"], ["bruxa", "guerreiro", "sacerdotisa"]]:
		var party: Array[String] = []
		for id in ids:
			party.append(id)
		game.run.new_attempt(party)
		game.run.begin_floor()
		game.open_combat()
		await process_frame
		var feedback: Control = game.combat_feedback
		check(feedback != null and feedback.sprites.size() == game.combat.order.size(), "Feedback vincula equipe de %d heróis e inimigos" % party.size())
		for id in party:
			check(feedback.frames[id].size() == 3 and game.arena_cards[id]["sprite"].texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s anima apenas sprite lateral pixel perfect" % id)
		var witch_sprite: TextureRect = game.arena_cards["bruxa"]["sprite"]
		var original: Vector2 = witch_sprite.position
		feedback.show_events([{"kind": "damage", "target_id": "bruxa", "amount": 9, "visual_type": "physical", "critical": false}, {"kind": "damage", "target_id": "bruxa", "amount": 4, "visual_type": "physical", "critical": false}, {"kind": "damage", "target_id": "goblin", "amount": 12, "visual_type": "fire", "critical": true}])
		check(feedback.get_child_count() == 3, "Golpes múltiplos mostram dois números no mesmo alvo e um no inimigo")
		check(feedback.get_child(0).position != feedback.get_child(1).position, "Golpes múltiplos não sobrepõem os números")
		var physical_number: Label = feedback.get_child(0).get_child(0)
		var critical_header: Label = feedback.get_child(2).get_child(0)
		var fire_number: Label = feedback.get_child(2).get_child(1)
		check(physical_number.get_theme_color("font_color") == CombatFeedback.COLORS["physical"], "Dano físico usa branco")
		check(critical_header.text == "CRÍTICO!" and critical_header.get_theme_color("font_color") == Color("f5d874") and fire_number.get_theme_color("font_color") == CombatFeedback.COLORS["fire"], "Crítico mantém cor de fogo e aviso dourado")
		check(witch_sprite.position == original, "Feedback começa na posição de referência")
		await create_timer(0.11).timeout
		check(witch_sprite.position.x < original.x, "Herói recua para a esquerda")
		var goblin_sprite: TextureRect = game.arena_cards["goblin"]["sprite"]
		check(goblin_sprite.position.x > feedback.origins["goblin"].x, "Inimigo recua para a direita")
		await create_timer(0.20).timeout
		check(witch_sprite.position == original and goblin_sprite.position == feedback.origins["goblin"], "Sprites retornam exatamente à posição original")
		await create_timer(0.40).timeout
		check(feedback.get_child_count() == 0, "Números flutuantes desaparecem após cerca de 0,6 s")
		for visual_type in ["magical", "poison", "radiant"]:
			feedback.show_events([{"kind": "damage", "target_id": "goblin", "amount": 8, "visual_type": visual_type, "critical": false}])
			var number: Label = feedback.get_child(feedback.get_child_count() - 1).get_child(0)
			check(number.get_theme_color("font_color") == CombatFeedback.COLORS[visual_type], "%s usa cor própria" % visual_type)
		feedback.show_events([{"kind": "heal", "target_id": "bruxa", "amount": 12}])
		var heal_number: Label = feedback.get_child(feedback.get_child_count() - 1).get_child(0)
		check(heal_number.text == "+12" and heal_number.get_theme_color("font_color") == CombatFeedback.COLORS["heal"], "Cura mostra sinal positivo e verde claro")
		var hp_before: int = int(game.combat.fighters["goblin"]["hp"])
		check(game.combat.act("skill:raio_arcano", "goblin"), "Ação real da Bruxa produz evento visual")
		var hp_after: int = int(game.combat.fighters["goblin"]["hp"])
		feedback.show_events(game.combat.visual_events)
		check(game.combat.visual_events.size() == 1 and game.combat.visual_events[0]["amount"] == hp_before - hp_after and int(game.combat.fighters["goblin"]["hp"]) == hp_after, "Exibir número real não aplica dano novamente")
		game.combat.fighters["bruxa"]["state"] = "downed"
		game.combat.fighters["bruxa"]["hp"] = 0
		game.refresh_combat()
		await create_timer(0.35).timeout
		check(witch_sprite.texture == feedback.frames["bruxa"][0], "Herói caído para no primeiro frame")
	game.free()
