extends SceneTree

const RunState = preload("res://systems/run_state.gd")
const StoryFlow = preload("res://systems/story_flow.gd")
const Scenes = preload("res://data/narrative_scenes.gd")
const MerchantDialogues = preload("res://data/merchant_dialogues.gd")
const ResurrectionFlow = preload("res://systems/resurrection_flow.gd")
const DialogueOverlay = preload("res://scripts/dialogue_overlay.gd")
const SAVE_PATH := "user://torre_story_v39_test.json"

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
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var path: String = SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _attempt(floor_number: int, completed: int) -> Dictionary:
	return {"phase": "combat", "floor": floor_number, "completed": completed, "narrative_seen": {}, "merchant_camp_status": ""}


func run_all() -> void:
	_clean()
	var attempt := _attempt(1, 0)
	check(StoryFlow.next_scene(attempt) == "intro_reino", "Primeira expedição começa pelo prólogo")
	var memory := {"completed_scenes": {"intro_reino": true}}
	check(StoryFlow.next_scene(attempt, memory) == "encontro_pai", "Prólogo concluído deixa apenas o encontro com o pai")
	memory["completed_scenes"]["encontro_pai"] = true
	check(StoryFlow.next_scene(attempt, memory).is_empty(), "Expedição seguinte não repete pai nem prólogo")
	check(StoryFlow.next_scene(_attempt(3, 2), memory) == "fragmento_luz_andar_3", "Fragmento dourado surge no andar 3")
	var fragment_scene: Dictionary = Scenes.get_scene("fragmento_luz_andar_3")
	check(fragment_scene["lines"][0]["choices"].size() == 2, "Fragmento pode ser examinado ou deixado para trás")
	var fragment_ignored_attempt := _attempt(3, 2)
	fragment_ignored_attempt["narrative_seen"]["fragmento_luz_andar_3"] = true
	check(StoryFlow.next_scene(fragment_ignored_attempt, memory).is_empty(), "Ignorar fragmento não bloqueia o combate nesta expedição")
	memory["fragments_found"] = {"fragmento_luz_andar_3": true}
	check(StoryFlow.next_scene(_attempt(3, 2), memory).is_empty(), "Fragmento do andar 3 não reaparece após descoberta")
	check(StoryFlow.next_scene(_attempt(5, 4), memory) == "encontro_comerciante", "Comerciante continua aparecendo em expedições seguintes")
	check(StoryFlow.next_scene(_attempt(8, 7), memory) == "fragmento_luz_andar_8", "Segundo fragmento surge no andar 8")
	check(StoryFlow.next_scene(_attempt(10, 9), memory) == "entrada_torre", "Cutscene do andar 10 aparece antes da primeira conclusão")
	memory["completed_scenes"]["entrada_torre"] = true
	check(StoryFlow.next_scene(_attempt(10, 9), memory).is_empty(), "Cutscene do andar 10 não se repete em nova expedição")

	var first_merchant: Dictionary = MerchantDialogues.encounter_scene(0, 0, 1, {})
	check(first_merchant["lines"][0]["text"].contains("Viajantes"), "Primeiro encontro mantém a apresentação original")
	var return_merchant: Dictionary = MerchantDialogues.encounter_scene(1, 4, 2, {})
	var greeting_line: Dictionary = return_merchant["lines"][0]
	check(greeting_line["text"] == MerchantDialogues.RETURN_GREETINGS[1], "Comerciante reconhece perdas e tentativas")
	var seen_dialogues := {str(greeting_line["event"]).trim_prefix("memory:"): true}
	var next_merchant: Dictionary = MerchantDialogues.encounter_scene(2, 4, 3, seen_dialogues)
	check(next_merchant["lines"][0]["event"] != greeting_line["event"], "Reencontro usa outra apresentação inédita")
	for topic_id in MerchantDialogues.CAMP_TOPICS:
		var unique_line: Dictionary = MerchantDialogues.camp_line(str(topic_id), {}, 0)
		check(bool(unique_line["unique"]) and not str(unique_line["id"]).is_empty(), "Tópico %s possui memória inédita" % topic_id)
	var topic_memory := {"camp_origin_01": true, "camp_origin_02": true, "camp_origin_03": true}
	var repeat_line: Dictionary = MerchantDialogues.camp_line("origin", topic_memory, 0)
	check(not bool(repeat_line["unique"]) and not str(repeat_line["text"]).is_empty(), "Tópico mantém conversa funcional após esgotar lembranças")

	var all_messages: Array = []
	for losses in range(2, 8):
		var message_id: String = ResurrectionFlow.choose_unseen_message(losses, all_messages)
		check(message_id != ResurrectionFlow.SILENT and not message_id in all_messages, "Derrota %d apresenta mensagem ainda não vista" % losses)
		all_messages.append(message_id)
	check(ResurrectionFlow.choose_unseen_message(8, all_messages) == ResurrectionFlow.SILENT, "Mensagens esgotadas levam ao interlúdio silencioso")
	check(ResurrectionFlow.scene_for(ResurrectionFlow.SILENT)["presentation"] == "resurrection_silent", "Interlúdio final não repete revelações")
	var fragment_overlay = DialogueOverlay.new()
	fragment_overlay.size = Vector2(1152, 648)
	root.add_child(fragment_overlay)
	await process_frame
	fragment_overlay.set_presentation("light_fragment")
	fragment_overlay.show_line(fragment_scene["lines"][0])
	check(fragment_overlay.get_child_count() >= 16, "Fragmento usa partículas douradas discretas")
	var silent_overlay = DialogueOverlay.new()
	silent_overlay.size = Vector2(1152, 648)
	root.add_child(silent_overlay)
	await process_frame
	silent_overlay.set_presentation("resurrection_silent")
	check(not silent_overlay._panel.visible and not silent_overlay._accent_bar.visible, "Interlúdio fica sem caixa de diálogo")
	fragment_overlay.queue_free()
	silent_overlay.queue_free()
	await process_frame

	var state := RunState.new()
	state.initialize(SAVE_PATH)
	check(state.mark_permanent_scene("intro_reino"), "Conclusão permanente é salva")
	check(state.mark_permanent_scene("encontro_pai"), "Encontro do pai é salvo como concluído")
	check(state.mark_narrative_fragment("fragmento_luz_andar_3"), "Fragmento encontrado fica salvo")
	check(state.mark_permanent_dialogue("camp_origin_01"), "Conversa inédita fica salva")
	check(state.record_merchant_encounter(), "Histórico de encontro com comerciante é salvo")
	var reloaded := RunState.new()
	reloaded.initialize(SAVE_PATH)
	check(reloaded.has_permanent_scene("intro_reino") and reloaded.has_permanent_scene("encontro_pai"), "Cenas permanentes sobrevivem à recarga")
	check(bool(reloaded.permanent["narrative"]["fragments_found"].get("fragmento_luz_andar_3", false)), "Fragmento encontrado sobrevive à recarga")
	check(bool(reloaded.permanent["narrative"]["dialogues_seen"].get("camp_origin_01", false)), "Diálogo visto sobrevive à recarga")
	check(int(reloaded.permanent["narrative"]["merchant_encounters"]) == 1, "Contador do comerciante sobrevive à recarga")

	var legacy := RunState.new()
	legacy.initialize(SAVE_PATH)
	var solo: Array[String] = ["guerreiro"]
	legacy.new_attempt(solo)
	legacy.attempt["narrative_seen"]["entrada_torre"] = true
	legacy.save()
	var migrated := RunState.new()
	migrated.initialize(SAVE_PATH)
	check(migrated.has_permanent_scene("entrada_torre"), "Save antigo migra conclusão comprovada do andar 10")
	_clean()
	var no_evidence := RunState.new()
	no_evidence.initialize(SAVE_PATH)
	no_evidence.new_attempt(solo)
	no_evidence.save()
	var clean_reload := RunState.new()
	clean_reload.initialize(SAVE_PATH)
	check(not clean_reload.has_permanent_scene("entrada_torre"), "Save sem evidência não marca cena como vista")
	_clean()
	if failures.is_empty():
		print("História V39: %d verificações passaram." % checks)
		quit(0)
	else:
		print("História V39: %d falhas em %d verificações: %s" % [failures.size(), checks, "; ".join(failures)])
		quit(1)
