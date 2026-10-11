extends SceneTree

const SaveSlots = preload("res://systems/save_slots.gd")
const SaveStore = preload("res://systems/save_store.gd")
const RunState = preload("res://systems/run_state.gd")
const StoryFlow = preload("res://systems/story_flow.gd")
const Progression = preload("res://systems/permanent_progression.gd")
const Heroes = preload("res://data/heroes.gd")
const Skills = preload("res://data/skills.gd")
const DevProfile = preload("res://systems/dev_profile.gd")
const Game = preload("res://scripts/main_v8.gd")

const BASE := "user://v40_slot_validation/"
const MIGRATION := "user://v40_migration_validation/"
const MIGRATION_V1 := "user://v40_migration_v1_validation/"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run_all")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func _fixture(base: String) -> RefCounted:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base))
	var slots := SaveSlots.new()
	slots.configure_paths(base + "slot_", base + "legacy.json", base + "selected.cfg", base + "migration.flag")
	return slots


func _clean(base: String) -> void:
	for stem in ["slot_1.json", "slot_2.json", "slot_3.json", "slot_1.json.dev", "slot_2.json.dev", "slot_3.json.dev", "slot_1.json.dev.baseline", "slot_2.json.dev.baseline", "slot_3.json.dev.baseline", "legacy.json"]:
		for suffix in ["", ".tmp", ".bak", ".bak.tmp", ".legacy.bak", ".legacy.bak.tmp"]:
			var path: String = base + str(stem) + str(suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for name in ["selected.cfg", "migration.flag", "migration.flag.tmp"]:
		var path: String = base + str(name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func run_all() -> void:
	_clean(BASE)
	_clean(MIGRATION)
	_clean(MIGRATION_V1)
	var slots := _fixture(BASE)
	for slot in range(1, 4):
		check(slots.create_slot(slot), "Espaço %d criado" % slot)
		check(slots.active_slot == slot and slots.slot_exists(slot), "Espaço %d selecionado e válido" % slot)
		var run := RunState.new()
		run.initialize(slots.path_for_slot(slot))
		run.permanent["coins"] = slot * 137
		run.permanent["stats"]["attempts"] = slot * 2
		run.permanent["stats"]["losses"] = slot - 1
		run.permanent["stats"]["best_floor_reached"] = slot + 1
		check(run.mark_permanent_dialogue("camp_origin_01" if slot == 1 else "camp_region_01"), "Diálogo próprio do Espaço %d salvo" % slot)
		if slot == 1:
			for hero_id in Heroes.ORDER:
				var class_entry: Dictionary = run.permanent["classes"][hero_id]
				Progression.grant_xp(class_entry, 700)
				run.permanent["classes"][hero_id] = class_entry
				check(run.spend_attribute(hero_id, "vitalidade"), "Atributo da classe %s salvo" % hero_id)
				check(run.spend_special_skill(hero_id, str(Skills.SPECIALS[hero_id][0])), "Especial da classe %s salvo" % hero_id)
			check(run.mark_permanent_scene("encontro_pai"), "Cena do pai salva no Espaço 1")
			check(run.mark_permanent_scene("entrada_torre"), "Cena única do andar 10 salva no Espaço 1")
			check(run.mark_scene_seen("conselho_comerciante"), "Cutscene vista salva no Espaço 1")
			check(run.mark_narrative_fragment("fragmento_luz_andar_3"), "Fragmento salvo no Espaço 1")
			check(run.sync_merchant_topic_unlocks(8).has("cycle"), "Conversas liberadas no Espaço 1")
			run.permanent["narrative"]["resurrection_count"] = 2
			run.permanent["narrative"]["resurrection_seen"] = true
			run.permanent["narrative"]["seen_resurrection_messages"] = ["darkness"]
		var team: Array[String] = ["bruxa", "guerreiro"]
		check(run.new_attempt(team), "Expedição do Espaço %d criada" % slot)
		run.attempt["heroes"][0]["hp"] = 31 + slot
		run.attempt["heroes"][0]["mana"] = 7 + slot
		run.attempt["card_queue"] = ["golpe_poderoso"]
		run.attempt["relics"] = [{"id": "pedra_arcana", "bearer": "bruxa"}]
		if slot == 1:
			run._playtime_tick_ms -= 61000
		check(run.save(), "PV, mana e cartas do Espaço %d salvos" % slot)
	check(not slots.create_slot(1), "Novo jogo não sobrescreve espaço ocupado")
	var restarted_slots := _fixture(BASE)
	restarted_slots.initialize()
	check(restarted_slots.active_slot == 3, "Seleção ativa persiste após reinício")
	for slot in range(1, 4):
		check(restarted_slots.select_slot(slot), "Alternância para o Espaço %d" % slot)
		var loaded := RunState.new()
		loaded.initialize(restarted_slots.path_for_slot(slot))
		check(int(loaded.permanent["coins"]) == slot * 137, "Moedas isoladas no Espaço %d" % slot)
		check(int(loaded.attempt["heroes"][0]["hp"]) == 31 + slot and int(loaded.attempt["heroes"][0]["mana"]) == 7 + slot, "Equipe, PV e mana isolados no Espaço %d" % slot)
		check(loaded.attempt["card_queue"] == ["golpe_poderoso"], "Cartas isoladas no Espaço %d" % slot)
		check(loaded.attempt["relics"].size() == 1 and str(loaded.attempt["relics"][0]["id"]) == "pedra_arcana", "Relíquias isoladas no Espaço %d" % slot)
		check(int(loaded.permanent["stats"]["attempts"]) == slot * 2 and int(loaded.permanent["stats"]["losses"]) == slot - 1, "Expedições e derrotas isoladas no Espaço %d" % slot)
		check(loaded.has_permanent_scene("encontro_pai") == (slot == 1), "Cena do pai pertence apenas ao Espaço 1")
		check(bool(loaded.permanent["narrative"]["scenes_seen"].get("conselho_comerciante", false)) == (slot == 1), "Histórico de cutscenes isolado no Espaço %d" % slot)
		check(bool(loaded.permanent["narrative"]["fragments_found"].get("fragmento_luz_andar_3", false)) == (slot == 1), "Fragmento pertence apenas ao Espaço 1")
		check(bool(loaded.permanent["narrative"]["merchant_topics_unlocked"].get("cycle", false)) == (slot == 1), "Assuntos do comerciante isolados no Espaço %d" % slot)
		if slot == 1:
			for hero_id in Heroes.ORDER:
				var class_entry: Dictionary = loaded.permanent["classes"][hero_id]
				check(int(class_entry["level"]) == 6 and int(class_entry["attributes"]["vitalidade"]) == 1 and str(Skills.SPECIALS[hero_id][0]) in class_entry["unlocked_specials"], "XP, nível, atributo e especial da classe %s persistem" % hero_id)
			check(int(loaded.permanent["narrative"]["resurrection_count"]) == 2 and "darkness" in loaded.permanent["narrative"]["seen_resurrection_messages"], "Histórico de renascimentos persiste")
		check(int(restarted_slots.summary(slot)["best_floor"]) == slot + 1 and int(restarted_slots.summary(slot)["last_saved_at"]) > 0, "Resumo do Espaço %d completo" % slot)
		check((float(restarted_slots.summary(slot)["playtime_seconds"]) >= 60.0) == (slot == 1), "Tempo jogado permanece no Espaço %d" % slot)
		if slot == 1:
			check(loaded.new_attempt(["guerreiro"]), "Nova expedição criada no Espaço 1")
			check(loaded.has_permanent_scene("encontro_pai") and loaded.has_permanent_scene("entrada_torre"), "Nova expedição preserva cenas permanentes")
			check(StoryFlow.next_scene(loaded.attempt, loaded.permanent["narrative"]) == "", "Pai não reaparece na nova expedição")
	var dev_run := RunState.new()
	dev_run.initialize(restarted_slots.path_for_slot(1))
	var dev_profile := DevProfile.new()
	dev_profile.configure(restarted_slots.path_for_slot(1))
	check(dev_profile.start_copy(dev_run), "Perfil DEV nasce como cópia do Espaço 1")
	dev_run.permanent["coins"] = 999
	check(dev_run.save() and dev_profile.return_normal(dev_run), "Alteração DEV fica no arquivo separado")
	check(int(dev_run.permanent["coins"]) == 137, "Voltar do DEV restaura o Espaço 1")
	dev_profile.configure(restarted_slots.path_for_slot(2))
	check(not dev_profile.has_test_profile() and dev_profile.normal_path != restarted_slots.path_for_slot(1), "Espaço 2 não reutiliza perfil DEV do Espaço 1")
	var recovered_path: String = restarted_slots.path_for_slot(1)
	var source := FileAccess.open(recovered_path, FileAccess.WRITE)
	source.store_string("{interrupted")
	source.close()
	check(not SaveStore.load_data(recovered_path).is_empty(), "Backup recupera escrita interrompida")
	check(not SaveStore.load_data(recovered_path).is_empty(), "Arquivo principal restaurado a partir do backup")
	var altered: Dictionary = SaveStore.load_data(recovered_path)
	altered["permanent"]["coins"] = 999999
	var altered_file := FileAccess.open(recovered_path, FileAccess.WRITE)
	altered_file.store_string(JSON.stringify(altered))
	altered_file.close()
	check(int(SaveStore.load_data(recovered_path).get("permanent", {}).get("coins", 0)) != 999999, "Checksum detecta corrupção mesmo quando o JSON continua válido")
	check(restarted_slots.delete_slot(2), "Espaço 2 excluído")
	check(not restarted_slots.slot_occupied(2) and restarted_slots.slot_exists(1) and restarted_slots.slot_exists(3), "Exclusão preserva os outros espaços")

	var migration_slots := _fixture(MIGRATION)
	var old := RunState.new()
	old.save_path = MIGRATION + "legacy.json"
	old.permanent = old._default_permanent()
	old.permanent["coins"] = 987
	check(old.new_attempt(["sacerdotisa"]), "Salvamento antigo de teste criado")
	check(old.mark_permanent_scene("encontro_pai"), "História antiga preparada")
	migration_slots.initialize()
	check(migration_slots.active_slot == 1 and migration_slots.slot_exists(1), "Save antigo migrado para Espaço 1")
	check(FileAccess.file_exists(MIGRATION + "legacy.json.legacy.bak") and FileAccess.file_exists(MIGRATION + "legacy.json"), "Original e backup antigo preservados")
	var migrated := RunState.new()
	migrated.initialize(migration_slots.path_for_slot(1))
	check(int(migrated.permanent["coins"]) == 987 and migrated.has_permanent_scene("encontro_pai"), "Dados e narrativa mantidos na migração")
	check(migration_slots.delete_slot(1), "Espaço migrado pode ser excluído")
	var after_delete := _fixture(MIGRATION)
	after_delete.initialize()
	check(not after_delete.slot_occupied(1), "Save antigo não reaparece após excluir Espaço 1")
	var old_v1_slots := _fixture(MIGRATION_V1)
	var old_v1_path := MIGRATION_V1 + "legacy.json"
	var old_v1_file := FileAccess.open(old_v1_path, FileAccess.WRITE)
	old_v1_file.store_string(JSON.stringify({"version": 1, "permanent": {"coins": 42, "stats": {"attempts": 3, "losses": 2}, "classes": {"guerreiro": {"xp": 250, "level": 3}}}, "attempt": {}}))
	old_v1_file.close()
	var original_v1 := FileAccess.get_file_as_bytes(old_v1_path)
	old_v1_slots.initialize()
	var upgraded := RunState.new()
	upgraded.initialize(old_v1_slots.path_for_slot(1))
	check(int(upgraded.permanent["classes"]["guerreiro"]["xp"]) == 250 and int(upgraded.permanent["classes"]["guerreiro"]["available_points"]) == 2, "Formato V1 recebe migração de atributos antes de entrar no Espaço 1")
	check(FileAccess.get_file_as_bytes(old_v1_path) == original_v1 and FileAccess.get_file_as_bytes(old_v1_path + ".legacy.bak") == original_v1, "Migração V1 preserva original e backup byte a byte")

	var ui_slots := _fixture(BASE)
	var game: Control = Game.new()
	game.save_slots = ui_slots
	game.size = Vector2(1100, 760)
	root.add_child(game)
	await process_frame
	game.show_play_menu()
	check(game.screen.find_child("PlayNewGame", true, false) != null and game.screen.find_child("PlayLoadGame", true, false) != null, "Menu Jogar oferece Novo jogo e Carregar jogo")
	game.show_slot_selection("new")
	check(game.screen.find_child("SaveSlotCreate2", true, false) != null, "Novo jogo mostra espaço vazio")
	game.show_slot_selection("load")
	check(game.screen.find_child("SaveSlotLoad1", true, false) != null and game.screen.find_child("SaveSlotLoad3", true, false) != null, "Carregar lista espaços existentes")
	check(not bool(game.narrative.seen.get("encontro_pai", false)), "História do Espaço 1 não aparece no Espaço 3")
	game._load_game_from_slot(1)
	check(bool(game.narrative.seen.get("encontro_pai", false)), "História do Espaço 1 é restaurada ao carregar")
	game._load_game_from_slot(3)
	check(not bool(game.narrative.seen.get("encontro_pai", false)), "Alternância limpa as cenas vistas de outro espaço")
	game.show_delete_confirmation(3, "load")
	check(game.screen.find_child("SaveDeleteConfirm", true, false) != null and game.screen.find_child("SaveDeleteAccept", true, false) != null, "Exclusão exige confirmação")
	game._create_game_in_slot(2)
	check(game.save_slots.active_slot == 2 and not game.run.has_attempt() and not game.run.has_permanent_scene("encontro_pai"), "Novo jogo inicia história própria no espaço vazio")
	game.queue_free()
	await process_frame
	_clean(BASE)
	_clean(MIGRATION)
	_clean(MIGRATION_V1)
	if failures.is_empty():
		print("Salvamentos V40: %d verificações passaram." % checks)
		quit(0)
	else:
		print("Salvamentos V40: %d falhas em %d verificações: %s" % [failures.size(), checks, "; ".join(failures)])
		quit(1)
