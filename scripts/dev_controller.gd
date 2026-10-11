extends Node

signal changed
signal close_requested

const Guard = preload("res://systems/dev_guard.gd")
const Profile = preload("res://systems/dev_profile.gd")
const Ops = preload("res://systems/dev_operations.gd")
const Heroes = preload("res://data/heroes.gd")
const Rules = preload("res://systems/combat_rules.gd")
const Music = preload("res://systems/music_manager.gd")
const Scenes = preload("res://data/narrative_scenes.gd")
const ResurrectionFlow = preload("res://systems/resurrection_flow.gd")
const MerchantDialogues = preload("res://data/merchant_dialogues.gd")

var game: Control
var profile: RefCounted = Profile.new()


func setup(target: Control, normal_path: String) -> void:
	game = target
	profile.configure(normal_path)


func authorized() -> bool:
	return Guard.authorized()


func active() -> bool:
	return authorized() and profile.active and game.run.save_path == profile.dev_path


func _before_context_change() -> void:
	game.generation += 1
	game.enemy_running = false
	game.resolving_visual_action = false
	game.combat_resolution_handled = true


func start_copy() -> bool:
	if not authorized() or profile.active:
		return false
	_before_context_change()
	if not profile.start_copy(game.run):
		return false
	game._refresh_narrative_seen()
	game.menu()
	game._refresh_dev_badge()
	changed.emit()
	return true


func resume() -> bool:
	if not authorized() or profile.active:
		return false
	_before_context_change()
	if not profile.resume(game.run):
		return false
	game._refresh_narrative_seen()
	game.menu()
	game._refresh_dev_badge()
	changed.emit()
	return true


func restore_initial() -> bool:
	if not active():
		return false
	_before_context_change()
	if not profile.restore_initial(game.run):
		return false
	game._refresh_narrative_seen()
	game.menu()
	changed.emit()
	return true


func reset_blank() -> bool:
	if not active():
		return false
	_before_context_change()
	if not profile.reset_blank(game.run):
		return false
	game._refresh_narrative_seen()
	game.menu()
	changed.emit()
	return true


func return_normal() -> bool:
	if not active():
		return false
	_before_context_change()
	if not profile.return_normal(game.run):
		return false
	game._refresh_narrative_seen()
	game.menu()
	game._refresh_dev_badge()
	changed.emit()
	return true


func set_level(hero_id: String, level: int) -> bool:
	return _mutate(Ops.set_level(game.run, hero_id, level))


func set_xp(hero_id: String, xp: int) -> bool:
	return _mutate(Ops.set_total_xp(game.run, hero_id, xp))


func reset_attributes(hero_id: String) -> bool:
	return _mutate(Ops.reset_attributes(game.run, hero_id))


func spend_attribute(hero_id: String, attribute_id: String) -> bool:
	return _mutate(Ops.spend_attribute(game.run, hero_id, attribute_id))


func set_special(hero_id: String, skill_id: String, action: String) -> bool:
	return _mutate(Ops.set_special(game.run, hero_id, skill_id, action))


func force_all_specials(hero_id: String) -> bool:
	return _mutate(Ops.force_all_specials(game.run, hero_id))


func restore_specials(hero_id: String) -> bool:
	return _mutate(Ops.restore_specials(game.run, profile.baseline_path, hero_id))


func _mutate(ok: bool) -> bool:
	if ok and active():
		for hero_id in game.combat.hero_ids:
			for hero in game.run.attempt.get("heroes", []):
				if hero["id"] == hero_id:
					game.combat.fighters[hero_id]["unlocked_specials"] = hero["unlocked_specials"].duplicate()
					game.combat.fighters[hero_id]["permanent_attributes"] = hero["permanent_attributes"].duplicate(true)
					Rules.recalculate(game.combat.fighters[hero_id], int(game.run.attempt["level"]), game.run.attempt["relics"])
					break
		if not game.combat.order.is_empty() and game.screen != null and is_instance_valid(game.screen) and not game.combat_cards.is_empty():
			game.refresh_combat()
		changed.emit()
	return ok


func set_team(ids: Array[String], preserve: bool = true) -> bool:
	if not active():
		return false
	_before_context_change()
	if not Ops.set_team(game.run, ids, preserve):
		return false
	game.open_combat()
	changed.emit()
	return true


func jump_floor(number: int, preserve: bool = true, with_story: bool = false) -> bool:
	if not active():
		return false
	_before_context_change()
	if not Ops.jump_floor(game.run, number, preserve, with_story):
		return false
	if with_story:
		close_requested.emit()
		game._enter_story_or_combat()
	else:
		game.open_combat()
	changed.emit()
	return true


func restart_combat() -> bool:
	if not active():
		return false
	_before_context_change()
	if not Ops.restart_combat(game.run):
		return false
	game.open_combat()
	changed.emit()
	return true


func set_temporary(level: int, xp: int) -> bool:
	return _rebuild_combat(Ops.set_temporary_level(game.run, level, xp))


func set_card(hero_id: String, card_id: String, level: int) -> bool:
	return _rebuild_combat(Ops.set_card(game.run, hero_id, card_id, level))


func set_relic(relic_id: String, bearer_id: String, enabled: bool) -> bool:
	return _rebuild_combat(Ops.set_relic(game.run, relic_id, bearer_id, enabled))


func grant_relic(relic_id: String, mode: String) -> bool:
	return _rebuild_combat(Ops.grant_relic(game.run, relic_id, mode))


func remove_relic(relic_id: String, mode: String) -> bool:
	return _rebuild_combat(Ops.remove_relic(game.run, relic_id, mode))


func equip_relic(relic_id: String, bearer_id: String, mode: String) -> bool:
	return _rebuild_combat(Ops.equip_relic(game.run, relic_id, bearer_id, mode))


func clear_temporary() -> bool:
	return _rebuild_combat(Ops.clear_temporary(game.run))


func _rebuild_combat(ok: bool) -> bool:
	if ok and active():
		_before_context_change()
		game.open_combat()
		changed.emit()
	return ok


func edit_fighter(fighter_id: String, field: String, value: int) -> bool:
	return _refresh_combat(Ops.edit_fighter(game.run, game.combat, fighter_id, field, value))


func set_condition(hero_id: String, condition: String) -> bool:
	return _refresh_combat(Ops.set_hero_condition(game.run, game.combat, hero_id, condition))


func restore_resources() -> bool:
	return _refresh_combat(Ops.restore_resources(game.run, game.combat))


func clear_negative_effects() -> bool:
	return _refresh_combat(Ops.clear_negative_effects(game.run, game.combat))


func reset_cooldowns() -> bool:
	return _refresh_combat(Ops.reset_cooldowns(game.run, game.combat))


func _refresh_combat(ok: bool) -> bool:
	if ok and active():
		if not game.combat_cards.is_empty():
			game.refresh_combat()
		changed.emit()
	return ok


func force_result(result: String, full_flow: bool) -> bool:
	if not active() or not game.run.has_attempt() or game.run.attempt.get("phase", "") != "combat" or not result in ["victory", "defeat"] or game.combat.order.is_empty():
		return false
	close_requested.emit()
	_before_context_change()
	if full_flow:
		game.combat_resolution_handled = false
		game.combat.finished = true
		game.combat.outcome = result
		game.combat_end()
	else:
		var completed := int(game.run.attempt["completed"])
		var floor_number := int(game.run.attempt["floor"])
		var summary := {"result": "Vitória" if result == "victory" else "Derrota", "won": result == "victory", "dev_preview": true, "floor": floor_number, "completed": completed, "floor_reached": floor_number, "classes": game.run.attempt["hero_ids"].duplicate(), "xp_per_class": 0, "coins": 0}
		game.show_summary(summary)
	changed.emit()
	return true


func preview_scene(scene_key: String) -> bool:
	if not active() or game.narrative.active:
		return false
	var scene_id := scene_key
	var definition: Dictionary = {}
	if scene_key == "ressurreicao_primeira":
		definition = ResurrectionFlow.scene_for(ResurrectionFlow.FIRST)
	elif scene_key.begins_with("ressurreicao_"):
		definition = ResurrectionFlow.scene_for(scene_key.trim_prefix("ressurreicao_"))
	elif scene_key == "merchant_reunion":
		scene_id = "encontro_comerciante"
		definition = MerchantDialogues.encounter_scene(1, 0, 2, {})
		definition["skippable_when_seen"] = true
	elif scene_key in ["figura_alada", "entrada_gueist"]:
		scene_id = "entrada_torre"
		definition = Scenes.get_scene(scene_id)
		var first_index: int = 9 if scene_key == "figura_alada" else 17
		var last_index: int = 15 if scene_key == "figura_alada" else definition["lines"].size() - 1
		definition["lines"] = definition["lines"].slice(first_index, last_index + 1)
		definition["first"] = definition["lines"][0]["id"]
		var last: Dictionary = definition["lines"].back()
		last["end"] = true
		last.erase("next")
		definition["lines"][definition["lines"].size() - 1] = last
	else:
		definition = Scenes.get_scene(scene_id)
	if definition.is_empty():
		return false
	close_requested.emit()
	game.dev_preview_scene = true
	game.dev_preview_was_combat = game.run.has_attempt() and game.run.attempt.get("phase", "") == "combat" and not game.combat.order.is_empty()
	if scene_key.begins_with("ressurreicao_"):
		game._show_dev_resurrection_stage()
	else:
		game._show_story_stage(scene_id)
	if scene_key == "figura_alada" and game.tower_director != null:
		game.tower_director.restore_state("entrada_torre", {"entrada_torre:escort": true, "entrada_torre:arrows": true, "entrada_torre:rescue": true})
	if not game.narrative.start_definition(scene_id, definition, game):
		game.dev_preview_scene = false
		game.menu()
		return false
	return true


func request_track(track: String) -> bool:
	if not active() or not Music.TRACK_PATHS.has(track):
		return false
	game.music_manager.request_track(track)
	changed.emit()
	return true


func restart_track() -> bool:
	if not active():
		return false
	var track := str(game.music_manager.requested_track)
	if track.is_empty():
		return false
	game.music_manager._player.stop()
	game.music_manager.current_track = ""
	game.music_manager.requested_track = ""
	game.music_manager.request_track(track)
	return true


func stop_track() -> bool:
	if not active():
		return false
	game.music_manager._player.stop()
	game.music_manager.current_track = ""
	game.music_manager.requested_track = ""
	return true


func restore_track() -> bool:
	if not active():
		return false
	if game.run.has_attempt() and game.run.attempt.get("phase", "") == "combat":
		game.music_manager.play_for_combat(game.run.attempt)
	else:
		game.music_manager.play_default()
	return true


func play_sfx(name: String) -> bool:
	if not active() or not name in game.audio_manager.SOUND_NAMES:
		return false
	game.audio_manager.play(name)
	return true


func preset(key: String, target_floor: int = 10, target_level: int = 12) -> bool:
	if not active():
		return false
	match key:
		"witch12":
			if not Ops.set_level(game.run, "bruxa", clampi(target_level, 1, 20)) or not Ops.set_special(game.run, "bruxa", "vampirismo_arcano", "force"):
				return false
			if not Ops.set_team(game.run, ["bruxa"], false):
				return false
			return jump_floor(clampi(target_floor, 1, 10), true, false)
		"full":
			if not Ops.set_team(game.run, ["guerreiro", "bruxa", "sacerdotisa"], false):
				return false
			return jump_floor(clampi(target_floor, 1, 10), true, false)
		"boss":
			if not Ops.set_team(game.run, ["guerreiro", "bruxa", "sacerdotisa"], false):
				return false
			return jump_floor(10, true, false)
		"support":
			if not Ops.set_team(game.run, ["sacerdotisa", "guerreiro", "bruxa"], false):
				return false
			Ops.set_special(game.run, "sacerdotisa", "milagre_divino", "force")
			if not jump_floor(clampi(target_floor, 1, 10), true, false):
				return false
			Ops.set_hero_condition(game.run, game.combat, "guerreiro", "low")
			Ops.set_hero_condition(game.run, game.combat, "bruxa", "downed")
			game.refresh_combat()
			return true
		"defeat":
			if not Ops.set_team(game.run, ["guerreiro"], false):
				return false
			if not jump_floor(clampi(target_floor, 1, 10), true, false):
				return false
			Ops.set_hero_condition(game.run, game.combat, "guerreiro", "low")
			game.refresh_combat()
			return true
	return false
