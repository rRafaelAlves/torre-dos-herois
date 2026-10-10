extends SceneTree

const Game = preload("res://scripts/main_v8.gd")
const Ambience = preload("res://scripts/combat_ambience.gd")

const PATH := "user://torre_v30_test_state.json"
var failures: Array[String] = []
var checks_run := 0


func _initialize() -> void:
	call_deferred("run_all")


func check(condition: bool, message: String) -> void:
	checks_run += 1
	if not condition:
		failures.append(message)
		push_error(message)


func run_all() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	await test_ambience()
	await test_arena_integration()
	await test_defeat_flow()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if failures.is_empty():
		print("V30: %d verificações ambientais passaram." % checks_run)
		quit(0)
	else:
		print("V30: %d falhas em %d verificações: %s" % [failures.size(), checks_run, "; ".join(failures)])
		quit(1)


func test_ambience() -> void:
	for foreground in [false, true]:
		var ambience: Control = Ambience.new()
		ambience.foreground = foreground
		root.add_child(ambience)
		ambience.size = Vector2(600, 220)
		await process_frame
		check(ambience.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Camada ambiental ignora cliques")
		var max_leaves: int = 3 if foreground else 7
		check(ambience.leaves.size() <= max_leaves, "Pool respeita máximo de folhas da camada")
		var cloud_before: float = ambience.cloud_x_at(0) if not foreground else 0.0
		var elapsed_before: float = ambience.elapsed
		await create_timer(3.2).timeout
		check(ambience.leaves.size() <= max_leaves, "Rajada não excede o limite de folhas")
		check(ambience.elapsed > elapsed_before and ambience.gust_goal_updates > 0, "Vento varia suavemente durante a cena")
		if not foreground:
			check(not is_equal_approx(ambience.cloud_x_at(0), cloud_before), "Nuvens deslocam-se lentamente")
		check(ambience.is_inside_tree(), "Ambiente permanece ativo enquanto a arena existe")
		ambience.queue_free()
		await process_frame
		check(not is_instance_valid(ambience), "Camada é removida ao encerrar a arena")


func test_arena_integration() -> void:
	var game: Control = Game.new()
	game.run.save_path = PATH
	root.add_child(game)
	await process_frame
	var party: Array[String] = ["guerreiro", "patrulheiro", "bruxa"]
	game.run.new_attempt(party)
	game.run.begin_floor()
	game.open_combat()
	await process_frame
	var back: Node = game.arena_stage.get_node("CombatAmbienceBack")
	var front: Node = game.arena_stage.get_node("CombatAmbienceFront")
	var teams: Node = game.arena_stage.get_child(game.arena_stage.get_children().find(back) + 1)
	var feedback: Node = game.arena_stage.get_node("CombatFeedback")
	check(back.get_index() < teams.get_index() and teams.get_index() < front.get_index() and front.get_index() < feedback.get_index(), "Folhas ficam em camadas atrás e à frente das unidades")
	check(back.mouse_filter == Control.MOUSE_FILTER_IGNORE and front.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Camadas não bloqueiam seleção de alvos")
	check(game.combat.is_hero_turn() or not game.combat.finished, "Arena inicia o combate sem alterar o estado")
	game.menu()
	await process_frame
	check(not is_instance_valid(back) or not back.is_inside_tree(), "Efeitos ambientais encerram ao trocar de tela")
	game.queue_free()
	await process_frame


func test_defeat_flow() -> void:
	var game: Control = Game.new()
	game.size = Vector2(520, 400)
	game.run.save_path = PATH
	root.add_child(game)
	await process_frame
	var party: Array[String] = ["guerreiro"]
	game.run.new_attempt(party)
	game.run.begin_floor()
	game.open_combat()
	game.combat.fighters["guerreiro"]["hp"] = 1
	game.combat.fighters["goblin"]["damage"] = 200
	await create_timer(2.4).timeout
	var result_panel: Node = game.screen.find_child("AttemptOutcome", true, false) if game.screen != null else null
	var summary_scroll: ScrollContainer = game.screen.find_child("OutcomeScroll", true, false) if game.screen != null else null
	var summary_actions: Control = game.screen.find_child("OutcomeActions", true, false) if game.screen != null else null
	check(game.combat.finished and game.combat.outcome == "defeat", "Golpe letal encerra o combate")
	check(result_panel != null and game.run.attempt.is_empty(), "Derrota abre o resumo e encerra a tentativa")
	check(summary_scroll != null and summary_actions != null and summary_actions.visible, "Resumo usa rolagem e mantém os botões visíveis")
	if summary_actions != null:
		check(summary_actions.position.y + summary_actions.size.y <= game.screen.size.y, "Ações do resumo cabem na janela compacta")
	game.menu()
	await process_frame
	check(game.screen != null and is_instance_valid(game.screen), "Menu continua responsivo depois da derrota")
	game.queue_free()
	await process_frame
