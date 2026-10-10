extends RefCounted

const Heroes = preload("res://data/heroes.gd")
const Cards = preload("res://data/cards.gd")
const Relics = preload("res://data/relics.gd")
const Tower = preload("res://data/tower.gd")
const Rules = preload("res://systems/combat_rules.gd")
const SaveStore = preload("res://systems/save_store.gd")
const Progression = preload("res://systems/permanent_progression.gd")
const StoryFlow = preload("res://systems/story_flow.gd")
const ResurrectionFlow = preload("res://systems/resurrection_flow.gd")
const DevGuard = preload("res://systems/dev_guard.gd")
const Skills = preload("res://data/skills.gd")

const REST_HEAL_AMOUNT := 35
const MEDITATION_MANA_AMOUNT := 15

var permanent: Dictionary = {}
var attempt: Dictionary = {}
var save_path: String = SaveStore.DEFAULT_PATH


func initialize(path: String = SaveStore.DEFAULT_PATH) -> void:
	save_path = path
	var data: Dictionary = SaveStore.load_data(path)
	var source_version: int = int(data.get("version", SaveStore.VERSION))
	permanent = _default_permanent()
	var historical_best_floor: int = 0
	if typeof(data.get("permanent")) == TYPE_DICTIONARY:
		var loaded: Dictionary = data["permanent"]
		permanent["coins"] = maxi(0, _safe_int(loaded.get("coins", 0)))
		if typeof(loaded.get("narrative")) == TYPE_DICTIONARY:
			var saved_narrative: Dictionary = loaded["narrative"]
			var narrative_state: Dictionary = permanent["narrative"]
			narrative_state["resurrection_seen"] = bool(saved_narrative.get("resurrection_seen", false))
			narrative_state["resurrection_count"] = maxi(0, _safe_int(saved_narrative.get("resurrection_count", 0)))
			var last_message := str(saved_narrative.get("last_message", ""))
			narrative_state["last_message"] = last_message if ResurrectionFlow.MESSAGES.has(last_message) else ""
			var pending_message := str(saved_narrative.get("pending_message", ""))
			var valid_message: bool = pending_message == ResurrectionFlow.FIRST or ResurrectionFlow.MESSAGES.has(pending_message)
			narrative_state["pending_message"] = pending_message if valid_message else ""
			narrative_state["pending"] = bool(saved_narrative.get("pending", false)) and valid_message
			narrative_state["cursor"] = str(saved_narrative.get("cursor", "")) if narrative_state["pending"] else ""
			permanent["narrative"] = narrative_state
		if typeof(loaded.get("stats")) == TYPE_DICTIONARY:
			for key in permanent["stats"]:
				permanent["stats"][key] = maxi(0, _safe_int(loaded["stats"].get(key, 0)))
		if typeof(loaded.get("classes")) == TYPE_DICTIONARY:
			for hero_id in Heroes.ORDER:
				var entry: Variant = loaded["classes"].get(hero_id, {})
				if typeof(entry) == TYPE_DICTIONARY:
					var history: Array = []
					if typeof(entry.get("history")) == TYPE_ARRAY:
						for record in entry["history"]:
							if typeof(record) == TYPE_DICTIONARY:
								var completed_floors: int = maxi(0, _safe_int(record.get("floors", 0)))
								var reached_floor: int = clampi(maxi(completed_floors, _safe_int(record.get("floor_reached", completed_floors))), 0, Tower.MAX_FLOOR)
								history.append({"attempt": str(record.get("attempt", "")), "floors": completed_floors, "floor_reached": reached_floor, "xp": maxi(0, _safe_int(record.get("xp", 0))), "result": str(record.get("result", ""))})
								historical_best_floor = maxi(historical_best_floor, reached_floor)
							if history.size() >= 20:
								break
					var progression_entry: Dictionary = Progression.from_save(entry, hero_id, source_version)
					progression_entry["history"] = history
					permanent["classes"][hero_id] = progression_entry
		permanent["stats"]["best_floor_reached"] = clampi(maxi(int(permanent["stats"].get("best_floor_reached", 0)), historical_best_floor), 0, Tower.MAX_FLOOR)
		if DevGuard.is_dev_path(save_path) and typeof(loaded.get("dev_forced_specials")) == TYPE_DICTIONARY:
			var safe_forced: Dictionary = {}
			for hero_id in Heroes.ORDER:
				var chosen: Array[String] = []
				var raw: Variant = loaded["dev_forced_specials"].get(hero_id, [])
				if typeof(raw) == TYPE_ARRAY:
					for skill_id in Skills.SPECIALS.get(hero_id, []):
						if skill_id in raw:
							chosen.append(skill_id)
				safe_forced[hero_id] = chosen
			permanent["dev_forced_specials"] = safe_forced
	attempt = {}
	var loaded_attempt: Variant = data.get("attempt", {})
	if typeof(loaded_attempt) == TYPE_DICTIONARY and _valid_attempt(loaded_attempt):
		attempt = loaded_attempt.duplicate(true)
		if typeof(attempt.get("narrative_seen")) != TYPE_DICTIONARY:
			# Tentativas anteriores à narrativa seguem do ponto salvo, sem cenas retroativas.
			attempt["narrative_seen"] = StoryFlow.LEGACY_SEEN.duplicate()
		if not bool(attempt.get("story_v33_enabled", false)):
			# A saved V32 battle already at the gate remains in progress.
			if int(attempt.get("floor", 0)) == 10 and str(attempt.get("phase", "")) == "combat":
				attempt["narrative_seen"]["entrada_torre"] = true
			if str(attempt.get("phase", "")) == "won":
				attempt["narrative_seen"]["epilogo_gueist"] = true
			attempt["story_v33_enabled"] = true
		if typeof(attempt.get("narrative_event_steps")) != TYPE_DICTIONARY:
			attempt["narrative_event_steps"] = {}
		if typeof(attempt.get("narrative_cursor")) != TYPE_DICTIONARY:
			attempt["narrative_cursor"] = {}
		if typeof(attempt.get("route_history")) != TYPE_DICTIONARY:
			attempt["route_history"] = {}
		if typeof(attempt.get("rewarded_enemies")) != TYPE_DICTIONARY:
			attempt["rewarded_enemies"] = {}
		if not _is_whole_number(attempt.get("coins_earned", 0)) or int(attempt.get("coins_earned", 0)) < 0:
			attempt["coins_earned"] = 0
		for route_field in ["current_route", "pending_route"]:
			var route_id: String = attempt.get(route_field, "")
			if route_id != "":
				for branch_floor in Tower.ROUTES:
					for route in Tower.ROUTES[branch_floor]:
						if route["id"] == route_id:
							attempt["route_history"][str(int(branch_floor) + 1)] = route_id
		for hero in attempt["heroes"]:
			var saved_attributes: Dictionary = hero.get("permanent_attributes", {}) if typeof(hero.get("permanent_attributes")) == TYPE_DICTIONARY else {}
			hero["permanent_attributes"] = Progression.sanitized_attributes(saved_attributes, hero["id"])
			hero["unlocked_specials"] = _effective_specials(hero["id"], hero.get("unlocked_specials", []))
			for key in Heroes.DEFINITIONS[hero["id"]]:
				hero[key] = Heroes.DEFINITIONS[hero["id"]][key]
			hero["team"] = "hero"
			Rules.recalculate(hero, int(attempt["level"]), attempt.get("relics", []))
	if source_version < SaveStore.VERSION and typeof(data.get("permanent")) == TYPE_DICTIONARY:
		save()


func _effective_specials(hero_id: String, regular: Variant) -> Array[String]:
	var result: Array[String] = Progression.sanitized_specials(regular, hero_id, 19, Progression.MAX_LEVEL)
	if DevGuard.is_dev_path(save_path):
		for skill_id in permanent.get("dev_forced_specials", {}).get(hero_id, []):
			if skill_id in Skills.SPECIALS.get(hero_id, []) and not skill_id in result:
				result.append(skill_id)
	return result


func has_attempt() -> bool:
	return not attempt.is_empty()


func new_attempt(hero_ids: Array[String]) -> bool:
	if hero_ids.is_empty() or hero_ids.size() > 3:
		return false
	var unique: Dictionary = {}
	for hero_id in hero_ids:
		if not Heroes.DEFINITIONS.has(hero_id) or unique.has(hero_id):
			return false
		unique[hero_id] = true
	var heroes: Array[Dictionary] = []
	for hero_id in hero_ids:
		heroes.append(Rules.create_hero(hero_id, 1, [], permanent["classes"][hero_id]["attributes"], _effective_specials(hero_id, permanent["classes"][hero_id].get("unlocked_specials", []))))
	attempt = {
		"id": "%d-%d" % [int(Time.get_unix_time_from_system()), randi()],
		"hero_ids": hero_ids.duplicate(), "heroes": heroes,
		"floor": 1, "completed": 0, "level": 1, "xp": 0,
		"coins_earned": 0, "rewarded_enemies": {},
		"relics": [], "phase": "between", "current_route": "", "pending_route": "", "route_history": {},
		"card_queue": [], "card_offers": {}, "relic_options": [],
		"narrative_seen": {}, "narrative_event_steps": {}, "narrative_cursor": {}, "story_v33_enabled": true,
	}
	return save()


func mark_narrative_scene(scene_id: String) -> bool:
	if not has_attempt() or not StoryFlow.is_main_scene(scene_id):
		return false
	var flags: Dictionary = attempt.get("narrative_seen", {})
	if bool(flags.get(scene_id, false)):
		return true
	flags[scene_id] = true
	attempt["narrative_seen"] = flags
	return save()


func begin_floor() -> bool:
	if not has_attempt() or attempt["phase"] != "between":
		return false
	attempt["floor"] = int(attempt["completed"]) + 1
	if int(attempt["floor"]) > Tower.MAX_FLOOR:
		return false
	attempt["current_route"] = attempt.get("pending_route", "")
	attempt["pending_route"] = ""
	attempt["phase"] = "combat"
	return save()


func victory(hero_states: Array[Dictionary]) -> void:
	if not has_attempt() or attempt["phase"] != "combat":
		return
	attempt["heroes"] = hero_states.duplicate(true)
	attempt["completed"] = int(attempt["floor"])
	for hero in attempt["heroes"]:
		Rules.recalculate(hero, int(attempt["level"]), attempt["relics"])
	if int(attempt["level"]) % 5 == 0:
		attempt["card_queue"] = attempt["hero_ids"].duplicate()
		attempt["card_offers"] = {}
		for hero in attempt["heroes"]:
			attempt["card_offers"][hero["id"]] = Cards.options_for(hero["id"], hero["cards"])
		attempt["phase"] = "cards"
	else:
		_after_cards()
	save()


func reward_enemy(enemy_key: String, xp_reward: int, coin_reward: int) -> Dictionary:
	if not has_attempt() or attempt.get("phase", "") != "combat" or enemy_key.is_empty():
		return {}
	var rewarded: Dictionary = attempt.get("rewarded_enemies", {})
	if bool(rewarded.get(enemy_key, false)):
		return {}
	var xp: int = maxi(0, xp_reward)
	var coins: int = maxi(0, coin_reward)
	rewarded[enemy_key] = true
	attempt["rewarded_enemies"] = rewarded
	if int(attempt["level"]) < 11:
		attempt["xp"] = int(attempt.get("xp", 0)) + xp
		while int(attempt["xp"]) >= 100 and int(attempt["level"]) < 11:
			attempt["xp"] = int(attempt["xp"]) - 100
			attempt["level"] = int(attempt["level"]) + 1
	attempt["coins_earned"] = int(attempt.get("coins_earned", 0)) + coins
	permanent["coins"] = int(permanent.get("coins", 0)) + coins
	save()
	return {"xp": xp, "coins": coins}


func current_card_hero() -> String:
	if not has_attempt() or attempt["phase"] != "cards" or attempt["card_queue"].is_empty():
		return ""
	return attempt["card_queue"][0]


func choose_card(card_id: String) -> bool:
	var hero_id: String = current_card_hero()
	if hero_id == "" or not card_id in attempt["card_offers"].get(hero_id, []):
		return false
	for hero in attempt["heroes"]:
		if hero["id"] == hero_id:
			var old_level: int = int(hero["cards"].get(card_id, 0))
			if old_level >= 3:
				return false
			hero["cards"][card_id] = old_level + 1
			Rules.recalculate(hero, int(attempt["level"]), attempt["relics"])
			break
	attempt["card_queue"].pop_front()
	if attempt["card_queue"].is_empty():
		_after_cards()
	return save()


func choose_reward(reward_type: String, hero_id: String) -> String:
	if not has_attempt() or attempt["phase"] != "reward":
		return ""
	var message: String = ""
	if reward_type == "skip":
		if has_reward_target("rest") or has_reward_target("meditation"):
			return ""
		message = "Nenhuma recompensa foi aplicada."
	else:
		for hero in attempt["heroes"]:
			if hero["id"] != hero_id or hero["state"] != "alive" or int(hero["hp"]) <= 0:
				continue
			if reward_type == "rest" and int(hero["hp"]) < int(hero["max_hp"]):
				var amount: int = mini(REST_HEAL_AMOUNT, int(hero["max_hp"]) - int(hero["hp"]))
				hero["hp"] = int(hero["hp"]) + amount
				message = "Descanso: %s recuperou %d PV." % [hero["name"], amount]
			elif reward_type == "meditation" and int(hero.get("mana_max", 0)) > 0 and int(hero["mana"]) < int(hero["mana_max"]):
				var amount: int = mini(MEDITATION_MANA_AMOUNT, int(hero["mana_max"]) - int(hero["mana"]))
				hero["mana"] = int(hero["mana"]) + amount
				message = "Meditação: %s recuperou %d mana." % [hero["name"], amount]
			break
	if message == "":
		return ""
	attempt["last_reward"] = message
	_after_reward()
	save()
	return message


func has_reward_target(reward_type: String) -> bool:
	if not has_attempt():
		return false
	for hero in attempt["heroes"]:
		if hero["state"] != "alive" or int(hero["hp"]) <= 0:
			continue
		if reward_type == "rest" and int(hero["hp"]) < int(hero["max_hp"]):
			return true
		if reward_type == "meditation" and int(hero.get("mana_max", 0)) > 0 and int(hero["mana"]) < int(hero["mana_max"]):
			return true
	return false


func choose_relic(relic_id: String, bearer_id: String = "") -> bool:
	if not has_attempt() or attempt["phase"] != "relic" or not relic_id in attempt["relic_options"]:
		return false
	var definition: Dictionary = Relics.DEFINITIONS.get(relic_id, {})
	if definition.is_empty():
		return false
	if definition.get("bearer", false):
		var valid_bearer := false
		for hero in attempt["heroes"]:
			if hero["id"] == bearer_id and hero["state"] == "alive" and int(hero["hp"]) > 0 and (not definition.get("requires_mana", false) or int(hero.get("mana_max", 0)) > 0):
				valid_bearer = true
		if not valid_bearer:
			return false
	attempt["relics"].append({"id": relic_id, "bearer": bearer_id})
	for hero in attempt["heroes"]:
		Rules.recalculate(hero, int(attempt["level"]), attempt["relics"])
	_after_relic()
	return save()


func choose_route(route_id: String) -> bool:
	if not has_attempt() or attempt["phase"] != "route":
		return false
	var valid := false
	for route in Tower.route_after(int(attempt["completed"])):
		if route["id"] == route_id:
			valid = true
	if not valid:
		return false
	attempt["pending_route"] = route_id
	attempt["route_history"][str(int(attempt["completed"]) + 1)] = route_id
	attempt["phase"] = "between"
	return save()


func end_attempt(result: String) -> Dictionary:
	if not has_attempt() or not result in ["victory", "defeat"]:
		return {}
	var completed: int = int(attempt["completed"])
	var won: bool = result == "victory" and completed == Tower.MAX_FLOOR
	var floor_reached: int = clampi(maxi(completed, int(attempt["floor"])), 1, Tower.MAX_FLOOR)
	var xp_gain: int = floor_reached * 40
	var coins_collected: int = int(attempt.get("coins_earned", 0))
	var victory_bonus: int = 50 if won else 0
	var coin_gain: int = coins_collected + victory_bonus
	var stats: Dictionary = permanent["stats"]
	var previous_best_floor: int = int(stats.get("best_floor_reached", 0))
	var new_record: bool = floor_reached > previous_best_floor
	var summary: Dictionary = {"result": "Vitória" if won else "Derrota", "won": won, "floor": int(attempt["floor"]), "completed": completed, "floor_reached": floor_reached, "previous_best_floor": previous_best_floor, "new_record": new_record, "classes": attempt["hero_ids"].duplicate(), "xp_per_class": xp_gain, "coins": coin_gain}
	permanent["coins"] = int(permanent["coins"]) + victory_bonus
	stats["attempts"] = int(stats.get("attempts", 0)) + 1
	stats["wins"] = int(stats.get("wins", 0)) + (1 if won else 0)
	stats["losses"] = int(stats.get("losses", 0)) + (0 if won else 1)
	stats["floors_completed"] = int(stats.get("floors_completed", 0)) + completed
	stats["best_floor_reached"] = maxi(previous_best_floor, floor_reached)
	permanent["stats"] = stats
	for hero_id in attempt["hero_ids"]:
		var entry: Dictionary = permanent["classes"][hero_id]
		Progression.grant_xp(entry, xp_gain)
		entry["history"].append({"attempt": attempt["id"], "floors": completed, "floor_reached": floor_reached, "xp": xp_gain, "result": result})
		while entry["history"].size() > 20:
			entry["history"].pop_front()
		permanent["classes"][hero_id] = entry
	attempt = {}
	save()
	return summary


func has_pending_resurrection() -> bool:
	return bool(permanent.get("narrative", {}).get("pending", false))


func queue_resurrection(force: bool = false) -> bool:
	if has_attempt() or (not force and int(permanent.get("stats", {}).get("losses", 0)) <= 0):
		return false
	if has_pending_resurrection():
		return true
	var state: Dictionary = permanent["narrative"].duplicate(true)
	var previous: Dictionary = state.duplicate(true)
	var message_id: String = ResurrectionFlow.FIRST if not bool(state.get("resurrection_seen", false)) else ResurrectionFlow.choose_message(int(permanent["stats"]["losses"]), str(state.get("last_message", "")), randi())
	state["pending"] = true
	state["pending_message"] = message_id
	state["cursor"] = ""
	permanent["narrative"] = state
	if save():
		return true
	permanent["narrative"] = previous
	return false


func set_resurrection_cursor(line_id: String) -> bool:
	if not has_pending_resurrection():
		return false
	var state: Dictionary = permanent["narrative"]
	state["cursor"] = line_id
	permanent["narrative"] = state
	return save()


func complete_resurrection() -> bool:
	if not has_pending_resurrection():
		return false
	var state: Dictionary = permanent["narrative"].duplicate(true)
	var previous: Dictionary = state.duplicate(true)
	var message_id := str(state.get("pending_message", ""))
	state["resurrection_seen"] = true
	state["resurrection_count"] = int(state.get("resurrection_count", 0)) + 1
	if message_id != ResurrectionFlow.FIRST:
		state["last_message"] = message_id
	state["pending"] = false
	state["pending_message"] = ""
	state["cursor"] = ""
	permanent["narrative"] = state
	if save():
		return true
	permanent["narrative"] = previous
	return false


func save() -> bool:
	return SaveStore.save_data(permanent, attempt, save_path)


func spend_attribute(hero_id: String, attribute_id: String) -> bool:
	if not permanent.get("classes", {}).has(hero_id):
		return false
	var entry: Dictionary = permanent["classes"][hero_id]
	var previous: Dictionary = entry.duplicate(true)
	if not Progression.invest(entry, hero_id, attribute_id):
		return false
	permanent["classes"][hero_id] = entry
	if save():
		return true
	permanent["classes"][hero_id] = previous
	return false


func spend_special_skill(hero_id: String, skill_id: String) -> bool:
	if not permanent.get("classes", {}).has(hero_id):
		return false
	var entry: Dictionary = permanent["classes"][hero_id]
	var previous: Dictionary = entry.duplicate(true)
	if not Progression.unlock(entry, hero_id, skill_id):
		return false
	permanent["classes"][hero_id] = entry
	if save():
		return true
	permanent["classes"][hero_id] = previous
	return false


func _after_cards() -> void:
	if int(attempt["completed"]) == Tower.MAX_FLOOR:
		attempt["phase"] = "won"
	else:
		attempt["phase"] = "reward"


func _after_reward() -> void:
	if int(attempt["completed"]) in [3, 6]:
		var available: Array[String] = Relics.available(attempt["relics"], attempt["hero_ids"])
		var eligible: Array[String] = []
		for relic_id in available:
			var definition: Dictionary = Relics.DEFINITIONS[relic_id]
			if not definition.get("bearer", false):
				eligible.append(relic_id)
			else:
				for hero in attempt["heroes"]:
					if hero["state"] == "alive" and int(hero["hp"]) > 0 and (not definition.get("requires_mana", false) or int(hero.get("mana_max", 0)) > 0):
						eligible.append(relic_id)
						break
		attempt["relic_options"] = eligible.slice(0, mini(2, eligible.size()))
		if not attempt["relic_options"].is_empty():
			attempt["phase"] = "relic"
			return
	_after_relic()


func _after_relic() -> void:
	attempt["phase"] = "route" if int(attempt["completed"]) in [1, 4, 7] else "between"


func _valid_attempt(value: Dictionary) -> bool:
	if not value.has("hero_ids") or not value.has("heroes") or typeof(value["hero_ids"]) != TYPE_ARRAY or typeof(value["heroes"]) != TYPE_ARRAY:
		return false
	if value["hero_ids"].is_empty() or value["hero_ids"].size() > 3 or value["heroes"].size() != value["hero_ids"].size():
		return false
	if not _is_whole_number(value.get("floor")) or int(value["floor"]) < 1 or int(value["floor"]) > Tower.MAX_FLOOR:
		return false
	if not _is_whole_number(value.get("completed")) or int(value["completed"]) < 0 or int(value["completed"]) > Tower.MAX_FLOOR:
		return false
	if not _is_whole_number(value.get("level")) or int(value["level"]) < 1 or int(value["level"]) > 11:
		return false
	if not _is_whole_number(value.get("xp")) or int(value["xp"]) < 0 or int(value["xp"]) >= 100:
		return false
	if not value.get("phase", "") in ["combat", "cards", "reward", "relic", "route", "between", "won"]:
		return false
	if typeof(value.get("relics")) != TYPE_ARRAY or typeof(value.get("card_queue")) != TYPE_ARRAY or typeof(value.get("card_offers")) != TYPE_DICTIONARY or typeof(value.get("relic_options")) != TYPE_ARRAY:
		return false
	if typeof(value.get("id")) != TYPE_STRING or typeof(value.get("current_route")) != TYPE_STRING or typeof(value.get("pending_route")) != TYPE_STRING:
		return false
	if value["current_route"] != "" and Tower.route_by_id(value["current_route"]).is_empty():
		return false
	if value["pending_route"] != "" and Tower.route_by_id(value["pending_route"]).is_empty():
		return false
	var unique: Dictionary = {}
	for hero_id in value["hero_ids"]:
		if typeof(hero_id) != TYPE_STRING or not Heroes.DEFINITIONS.has(hero_id) or unique.has(hero_id):
			return false
		unique[hero_id] = true
	var seen_heroes: Dictionary = {}
	for hero in value["heroes"]:
		if typeof(hero) != TYPE_DICTIONARY or typeof(hero.get("id")) != TYPE_STRING or not unique.has(hero["id"]) or typeof(hero.get("cards")) != TYPE_DICTIONARY or not _is_whole_number(hero.get("hp")) or not _is_whole_number(hero.get("mana")) or not hero.get("state", "") in ["alive", "downed", "dead"]:
			return false
		if seen_heroes.has(hero["id"]):
			return false
		seen_heroes[hero["id"]] = true
		for card_id in hero["cards"]:
			if not Cards.DEFINITIONS.has(card_id) or not _is_whole_number(hero["cards"][card_id]) or int(hero["cards"][card_id]) < 1 or int(hero["cards"][card_id]) > 3:
				return false
			var exclusive: String = Cards.DEFINITIONS[card_id]["class"]
			if exclusive != "" and exclusive != hero["id"]:
				return false
	var seen_relics: Dictionary = {}
	for relic in value["relics"]:
		if typeof(relic) != TYPE_DICTIONARY or not Relics.DEFINITIONS.has(relic.get("id", "")) or typeof(relic.get("bearer")) != TYPE_STRING:
			return false
		if seen_relics.has(relic["id"]):
			return false
		seen_relics[relic["id"]] = true
		if relic["bearer"] != "" and not unique.has(relic["bearer"]):
			return false
	if value["phase"] == "cards":
		if value["card_queue"].is_empty():
			return false
		for hero_id in value["card_queue"]:
			if not unique.has(hero_id) or typeof(value["card_offers"].get(hero_id)) != TYPE_ARRAY:
				return false
			var offers: Array = value["card_offers"][hero_id]
			if offers.is_empty() or offers.size() > 3:
				return false
			for card_id in offers:
				if not Cards.DEFINITIONS.has(card_id):
					return false
				var exclusive: String = Cards.DEFINITIONS[card_id]["class"]
				if exclusive != "" and exclusive != hero_id:
					return false
	for relic_id in value["relic_options"]:
		if not Relics.DEFINITIONS.has(relic_id):
			return false
	return true


func _safe_int(value: Variant) -> int:
	return int(value) if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT else 0


func _is_whole_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and float(value) == float(int(value))


func _default_permanent() -> Dictionary:
	var classes: Dictionary = {}
	for hero_id in Heroes.ORDER:
		var entry: Dictionary = Progression.from_save({}, hero_id, SaveStore.VERSION)
		entry["history"] = []
		classes[hero_id] = entry
	return {"coins": 0, "classes": classes, "stats": {"attempts": 0, "wins": 0, "losses": 0, "floors_completed": 0, "best_floor_reached": 0}, "narrative": {"resurrection_seen": false, "resurrection_count": 0, "last_message": "", "pending": false, "pending_message": "", "cursor": ""}}
