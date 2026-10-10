extends RefCounted

const Guard = preload("res://systems/dev_guard.gd")
const SaveStore = preload("res://systems/save_store.gd")
const Heroes = preload("res://data/heroes.gd")
const Skills = preload("res://data/skills.gd")
const Cards = preload("res://data/cards.gd")
const Relics = preload("res://data/relics.gd")
const Tower = preload("res://data/tower.gd")
const Progression = preload("res://systems/permanent_progression.gd")
const Rules = preload("res://systems/combat_rules.gd")
const StateEffects = preload("res://systems/state_effects.gd")


static func allowed(run: RefCounted) -> bool:
	return Guard.is_dev_path(str(run.save_path))


static func total_xp_for(level: int) -> int:
	var total := 0
	for current in range(1, clampi(level, 1, Progression.MAX_LEVEL)):
		total += Progression.xp_required(current)
	return total


static func level_needs_reset(run: RefCounted, hero_id: String, level: int) -> bool:
	if not allowed(run) or not Heroes.DEFINITIONS.has(hero_id):
		return false
	var entry: Dictionary = run.permanent["classes"][hero_id]
	if Progression.invested_points(entry["attributes"]) + Progression.special_cost(entry["unlocked_specials"]) > level - 1:
		return true
	for skill_id in entry["unlocked_specials"]:
		if int(Skills.DEFINITIONS[skill_id]["level"]) > level:
			return true
	return false


static func set_level(run: RefCounted, hero_id: String, level: int, level_xp: int = 0) -> bool:
	if not allowed(run) or not Heroes.DEFINITIONS.has(hero_id) or level < 1 or level > Progression.MAX_LEVEL:
		return false
	var entry: Dictionary = run.permanent["classes"][hero_id].duplicate(true)
	var reset := level_needs_reset(run, hero_id, level)
	if reset:
		entry["attributes"] = Progression.empty_attributes()
		entry["unlocked_specials"] = []
	var limit := Progression.xp_required(level)
	var progress := clampi(level_xp, 0, maxi(0, limit - 1)) if level < Progression.MAX_LEVEL else 0
	entry["level"] = level
	entry["level_xp"] = progress
	entry["xp"] = total_xp_for(level) + progress
	entry["available_points"] = maxi(0, level - 1 - Progression.invested_points(entry["attributes"]) - Progression.special_cost(entry["unlocked_specials"]))
	run.permanent["classes"][hero_id] = entry
	_sync_hero_progression(run, hero_id)
	return run.save()


static func level_for_total_xp(amount: int) -> int:
	var remaining := clampi(amount, 0, total_xp_for(Progression.MAX_LEVEL))
	var level := 1
	while level < Progression.MAX_LEVEL and remaining >= Progression.xp_required(level):
		remaining -= Progression.xp_required(level)
		level += 1
	return level


static func set_total_xp(run: RefCounted, hero_id: String, amount: int) -> bool:
	if not allowed(run) or not Heroes.DEFINITIONS.has(hero_id):
		return false
	var level := level_for_total_xp(amount)
	var progress := clampi(amount, 0, total_xp_for(Progression.MAX_LEVEL)) - total_xp_for(level)
	return set_level(run, hero_id, level, progress)


static func reset_attributes(run: RefCounted, hero_id: String) -> bool:
	if not allowed(run) or not Heroes.DEFINITIONS.has(hero_id):
		return false
	var entry: Dictionary = run.permanent["classes"][hero_id]
	entry["attributes"] = Progression.empty_attributes()
	entry["available_points"] = maxi(0, int(entry["level"]) - 1 - Progression.special_cost(entry["unlocked_specials"]))
	run.permanent["classes"][hero_id] = entry
	_sync_hero_progression(run, hero_id)
	return run.save()


static func spend_attribute(run: RefCounted, hero_id: String, attribute_id: String) -> bool:
	if not allowed(run):
		return false
	if not run.spend_attribute(hero_id, attribute_id):
		return false
	_sync_hero_progression(run, hero_id)
	return run.save()


static func set_special(run: RefCounted, hero_id: String, skill_id: String, action: String) -> bool:
	if not allowed(run) or not skill_id in Skills.SPECIALS.get(hero_id, []):
		return false
	if action == "buy":
		if not run.spend_special_skill(hero_id, skill_id):
			return false
	elif action == "force":
		var forced: Dictionary = run.permanent.get("dev_forced_specials", {})
		var chosen: Array = forced.get(hero_id, []).duplicate()
		if not skill_id in chosen:
			chosen.append(skill_id)
		forced[hero_id] = chosen
		run.permanent["dev_forced_specials"] = forced
	elif action == "block":
		var forced: Dictionary = run.permanent.get("dev_forced_specials", {})
		var chosen: Array = forced.get(hero_id, []).duplicate()
		chosen.erase(skill_id)
		forced[hero_id] = chosen
		run.permanent["dev_forced_specials"] = forced
		var entry: Dictionary = run.permanent["classes"][hero_id]
		var normal: Array = entry["unlocked_specials"].duplicate()
		normal.erase(skill_id)
		entry["unlocked_specials"] = normal
		entry["available_points"] = maxi(0, int(entry["level"]) - 1 - Progression.invested_points(entry["attributes"]) - Progression.special_cost(normal))
		run.permanent["classes"][hero_id] = entry
	else:
		return false
	_sync_hero_progression(run, hero_id)
	return run.save()


static func force_all_specials(run: RefCounted, hero_id: String) -> bool:
	if not allowed(run) or not Heroes.DEFINITIONS.has(hero_id):
		return false
	var forced: Dictionary = run.permanent.get("dev_forced_specials", {})
	forced[hero_id] = Skills.SPECIALS[hero_id].duplicate()
	run.permanent["dev_forced_specials"] = forced
	_sync_hero_progression(run, hero_id)
	return run.save()


static func restore_specials(run: RefCounted, baseline_path: String, hero_id: String) -> bool:
	if not allowed(run) or not Heroes.DEFINITIONS.has(hero_id):
		return false
	var source: Dictionary = SaveStore.load_data(baseline_path)
	if source.is_empty():
		return false
	var original: Dictionary = source.get("permanent", {}).get("classes", {}).get(hero_id, {})
	var entry: Dictionary = run.permanent["classes"][hero_id]
	var allowed_regular: Array[String] = Progression.sanitized_specials(original.get("unlocked_specials", []), hero_id, int(entry["level"]) - 1 - Progression.invested_points(entry["attributes"]), int(entry["level"]))
	entry["unlocked_specials"] = allowed_regular
	entry["available_points"] = maxi(0, int(entry["level"]) - 1 - Progression.invested_points(entry["attributes"]) - Progression.special_cost(allowed_regular))
	run.permanent["classes"][hero_id] = entry
	var forced: Dictionary = run.permanent.get("dev_forced_specials", {})
	forced[hero_id] = source.get("permanent", {}).get("dev_forced_specials", {}).get(hero_id, []).duplicate()
	run.permanent["dev_forced_specials"] = forced
	_sync_hero_progression(run, hero_id)
	return run.save()


static func _sync_hero_progression(run: RefCounted, hero_id: String) -> void:
	if not run.has_attempt():
		return
	for hero in run.attempt["heroes"]:
		if hero["id"] != hero_id:
			continue
		hero["permanent_attributes"] = run.permanent["classes"][hero_id]["attributes"].duplicate(true)
		hero["unlocked_specials"] = run._effective_specials(hero_id, run.permanent["classes"][hero_id]["unlocked_specials"])
		Rules.recalculate(hero, int(run.attempt["level"]), run.attempt["relics"])


static func set_team(run: RefCounted, ids: Array[String], preserve: bool = true) -> bool:
	if not allowed(run) or ids.is_empty() or ids.size() > 3:
		return false
	var unique: Dictionary = {}
	for hero_id in ids:
		if not Heroes.DEFINITIONS.has(hero_id) or unique.has(hero_id):
			return false
		unique[hero_id] = true
	if not run.has_attempt() or not preserve:
		var floor_number := int(run.attempt.get("floor", 1))
		if not run.new_attempt(ids):
			return false
		run.begin_floor()
		return jump_floor(run, floor_number, true, false)
	var old: Dictionary = {}
	for hero in run.attempt["heroes"]:
		old[hero["id"]] = hero
	var heroes: Array[Dictionary] = []
	for hero_id in ids:
		var hero: Dictionary = old[hero_id].duplicate(true) if old.has(hero_id) else Rules.create_hero(hero_id, int(run.attempt["level"]), run.attempt["relics"], run.permanent["classes"][hero_id]["attributes"], run._effective_specials(hero_id, run.permanent["classes"][hero_id]["unlocked_specials"]))
		hero["unlocked_specials"] = run._effective_specials(hero_id, run.permanent["classes"][hero_id]["unlocked_specials"])
		Rules.recalculate(hero, int(run.attempt["level"]), run.attempt["relics"])
		heroes.append(hero)
	run.attempt["hero_ids"] = ids.duplicate()
	run.attempt["heroes"] = heroes
	run.attempt["relics"] = run.attempt["relics"].filter(func(relic: Dictionary) -> bool: return relic.get("bearer", "") == "" or relic.get("bearer", "") in ids)
	run.attempt["phase"] = "combat"
	run.attempt["completed"] = mini(int(run.attempt["completed"]), int(run.attempt["floor"]) - 1)
	run.attempt.erase("dev_combat_overrides")
	run.attempt.erase("dev_floor_start_heroes")
	return run.save()


static func jump_floor(run: RefCounted, floor_number: int, preserve: bool = true, with_story: bool = false) -> bool:
	if not allowed(run) or floor_number < 1 or floor_number > Tower.MAX_FLOOR:
		return false
	if not run.has_attempt():
		var default_team: Array[String] = ["guerreiro"]
		if not run.new_attempt(default_team):
			return false
		run.begin_floor()
	elif not preserve:
		var ids: Array[String] = []
		ids.assign(run.attempt["hero_ids"])
		if not run.new_attempt(ids):
			return false
		run.begin_floor()
	run.attempt["floor"] = floor_number
	run.attempt["completed"] = floor_number - 1
	run.attempt["phase"] = "combat"
	run.attempt["card_queue"] = []
	run.attempt["card_offers"] = {}
	run.attempt["relic_options"] = []
	run.attempt["pending_route"] = ""
	var route_history: Dictionary = {}
	for branch_floor in [1, 4, 7]:
		if floor_number > branch_floor:
			route_history[str(branch_floor + 1)] = str(Tower.ROUTES[branch_floor][0]["id"])
	run.attempt["route_history"] = route_history
	run.attempt["current_route"] = str(route_history.get(str(floor_number), ""))
	var seen: Dictionary = run.attempt.get("narrative_seen", {})
	for scene_id in ["intro_reino", "encontro_pai", "encontro_comerciante", "entrada_torre"]:
		seen[scene_id] = true
	if with_story:
		if floor_number == 1:
			seen["intro_reino"] = false
			seen["encontro_pai"] = false
		elif floor_number == 5:
			seen["encontro_comerciante"] = false
		elif floor_number == 10:
			seen["entrada_torre"] = false
	run.attempt["narrative_seen"] = seen
	if with_story:
		run.attempt["narrative_event_steps"] = {}
		run.attempt["narrative_cursor"] = {}
	run.attempt.erase("dev_combat_overrides")
	run.attempt.erase("dev_floor_start_heroes")
	return run.save()


static func set_temporary_level(run: RefCounted, level: int, xp: int) -> bool:
	if not allowed(run) or not run.has_attempt() or run.attempt.get("phase", "") != "combat" or level < 1 or level > 11 or xp < 0 or xp >= 100:
		return false
	run.attempt["level"] = level
	run.attempt["xp"] = xp
	for hero in run.attempt["heroes"]:
		Rules.recalculate(hero, level, run.attempt["relics"])
	return run.save()


static func set_card(run: RefCounted, hero_id: String, card_id: String, level: int) -> bool:
	if not allowed(run) or not run.has_attempt() or run.attempt.get("phase", "") != "combat" or not Cards.DEFINITIONS.has(card_id) or level < 0 or level > 3:
		return false
	var definition: Dictionary = Cards.DEFINITIONS[card_id]
	if definition["class"] != "" and definition["class"] != hero_id:
		return false
	for hero in run.attempt["heroes"]:
		if hero["id"] == hero_id:
			var owned: Dictionary = hero["cards"]
			if level == 0:
				owned.erase(card_id)
			else:
				owned[card_id] = level
			hero["cards"] = owned
			Rules.recalculate(hero, int(run.attempt["level"]), run.attempt["relics"])
			return run.save()
	return false


static func set_relic(run: RefCounted, relic_id: String, bearer_id: String, enabled: bool) -> bool:
	if not allowed(run) or not run.has_attempt() or run.attempt.get("phase", "") != "combat" or not Relics.DEFINITIONS.has(relic_id):
		return false
	var relics: Array = run.attempt["relics"].duplicate(true)
	for relic in relics:
		if relic["id"] == relic_id:
			relics.erase(relic)
			break
	if enabled:
		var definition: Dictionary = Relics.DEFINITIONS[relic_id]
		if bool(definition.get("bearer", false)):
			if not bearer_id in run.attempt["hero_ids"]:
				return false
			if bool(definition.get("requires_mana", false)) and not Progression.uses_mana(bearer_id):
				return false
		else:
			bearer_id = ""
		relics.append({"id": relic_id, "bearer": bearer_id})
	run.attempt["relics"] = relics
	for hero in run.attempt["heroes"]:
		Rules.recalculate(hero, int(run.attempt["level"]), relics)
	return run.save()


static func clear_temporary(run: RefCounted) -> bool:
	if not allowed(run) or not run.has_attempt() or run.attempt.get("phase", "") != "combat":
		return false
	run.attempt["relics"] = []
	run.attempt["level"] = 1
	run.attempt["xp"] = 0
	for hero in run.attempt["heroes"]:
		hero["cards"] = {}
		Rules.recalculate(hero, 1, [])
	return run.save()


static func edit_fighter(run: RefCounted, combat: RefCounted, fighter_id: String, field: String, value: int) -> bool:
	if not allowed(run) or not run.has_attempt() or not combat.fighters.has(fighter_id):
		return false
	var fighter: Dictionary = combat.fighters[fighter_id]
	if field == "hp":
		fighter["hp"] = clampi(value, 0, int(fighter["max_hp"]))
		if fighter["team"] == "enemy" and int(fighter["hp"]) == 0:
			fighter["hp"] = 1
		elif fighter["team"] == "hero":
			fighter["state"] = "alive" if int(fighter["hp"]) > 0 else "downed"
			if fighter["state"] == "downed":
				fighter["down_start_round"] = int(combat.round_number)
	elif field == "mana" and fighter["team"] == "hero":
		fighter["mana"] = clampi(value, 0, int(fighter.get("mana_max", 0)))
	else:
		return false
	combat.fighters[fighter_id] = fighter
	_snapshot_fighter(run, fighter_id, fighter)
	return run.save()


static func set_hero_condition(run: RefCounted, combat: RefCounted, hero_id: String, condition: String) -> bool:
	if not allowed(run) or not combat.hero_ids.has(hero_id):
		return false
	var hero: Dictionary = combat.fighters[hero_id]
	match condition:
		"healthy":
			hero["state"] = "alive"
			hero["hp"] = hero["max_hp"]
			StateEffects.clear(hero)
		"low":
			hero["state"] = "alive"
			hero["hp"] = maxi(1, roundi(float(hero["max_hp"]) * 0.15))
		"downed":
			hero["state"] = "downed"
			hero["hp"] = 0
			hero["down_rounds"] = 0
			hero["down_start_round"] = int(combat.round_number)
		"veneno", "fraqueza":
			if hero["state"] != "alive" or int(hero["hp"]) <= 0:
				return false
			StateEffects.apply(hero, condition)
		_:
			return false
	combat.fighters[hero_id] = hero
	_snapshot_fighter(run, hero_id, hero)
	return run.save()


static func restore_resources(run: RefCounted, combat: RefCounted) -> bool:
	if not allowed(run) or not run.has_attempt():
		return false
	for hero_id in combat.hero_ids:
		var hero: Dictionary = combat.fighters[hero_id]
		hero["state"] = "alive"
		hero["hp"] = hero["max_hp"]
		hero["mana"] = hero["mana_max"]
		hero["down_rounds"] = 0
		StateEffects.clear(hero)
		combat.fighters[hero_id] = hero
		_snapshot_fighter(run, hero_id, hero)
	return run.save()


static func clear_negative_effects(run: RefCounted, combat: RefCounted) -> bool:
	if not allowed(run):
		return false
	for fighter_id in combat.fighters:
		var fighter: Dictionary = combat.fighters[fighter_id]
		for effect_id in ["veneno", "fraqueza"]:
			StateEffects.remove(fighter, effect_id)
		combat.fighters[fighter_id] = fighter
		_snapshot_fighter(run, fighter_id, fighter)
	return run.save()


static func reset_cooldowns(run: RefCounted, combat: RefCounted) -> bool:
	if not allowed(run):
		return false
	for hero_id in combat.hero_ids:
		var hero: Dictionary = combat.fighters[hero_id]
		hero["skill_cooldowns"] = {}
		hero["skill_cooldowns_just_started"] = {}
		hero["cooldown_remaining"] = 0
		hero["cooldown_just_started"] = false
		combat.fighters[hero_id] = hero
		_snapshot_fighter(run, hero_id, hero)
	return run.save()


static func _snapshot_fighter(run: RefCounted, fighter_id: String, fighter: Dictionary) -> void:
	if not run.has_attempt():
		return
	var overrides: Dictionary = run.attempt.get("dev_combat_overrides", {})
	overrides[fighter_id] = {
		"hp": fighter.get("hp", 0), "mana": fighter.get("mana", 0), "state": fighter.get("state", "alive"),
		"down_rounds": fighter.get("down_rounds", 0), "down_start_round": fighter.get("down_start_round", 0),
		"state_effects": fighter.get("state_effects", {}).duplicate(true),
		"skill_cooldowns": fighter.get("skill_cooldowns", {}).duplicate(true)
	}
	run.attempt["dev_combat_overrides"] = overrides
	if fighter["team"] == "hero":
		for index in run.attempt["heroes"].size():
			if run.attempt["heroes"][index]["id"] == fighter_id:
				run.attempt["heroes"][index] = fighter.duplicate(true)
				break


static func restore_combat_overrides(run: RefCounted, combat: RefCounted) -> void:
	if not allowed(run) or not run.has_attempt():
		return
	for fighter_id in run.attempt.get("dev_combat_overrides", {}):
		if not combat.fighters.has(fighter_id):
			continue
		var fighter: Dictionary = combat.fighters[fighter_id]
		var override: Dictionary = run.attempt["dev_combat_overrides"][fighter_id]
		fighter["hp"] = clampi(int(override.get("hp", fighter["hp"])), 0, int(fighter["max_hp"]))
		fighter["mana"] = clampi(int(override.get("mana", fighter.get("mana", 0))), 0, int(fighter.get("mana_max", 0)))
		fighter["state"] = override.get("state", "alive")
		fighter["down_rounds"] = override.get("down_rounds", 0)
		fighter["down_start_round"] = override.get("down_start_round", 0)
		fighter["state_effects"] = override.get("state_effects", {}).duplicate(true)
		fighter["skill_cooldowns"] = override.get("skill_cooldowns", {}).duplicate(true)
		combat.fighters[fighter_id] = fighter


static func restart_combat(run: RefCounted) -> bool:
	if not allowed(run) or not run.has_attempt() or run.attempt.get("phase", "") != "combat":
		return false
	if run.attempt.has("dev_floor_start_heroes"):
		run.attempt["heroes"] = run.attempt["dev_floor_start_heroes"].duplicate(true)
	run.attempt.erase("dev_combat_overrides")
	run.attempt["phase"] = "combat"
	return run.save()
