extends RefCounted

const Heroes = preload("res://data/heroes.gd")
const Cards = preload("res://data/cards.gd")
const Relics = preload("res://data/relics.gd")
const RelicEquipment = preload("res://systems/relic_equipment.gd")
const Tower = preload("res://data/tower.gd")
const Rules = preload("res://systems/combat_rules.gd")
const SaveStore = preload("res://systems/save_store.gd")
const Progression = preload("res://systems/permanent_progression.gd")
const StoryFlow = preload("res://systems/story_flow.gd")
const ResurrectionFlow = preload("res://systems/resurrection_flow.gd")
const MerchantDialogues = preload("res://data/merchant_dialogues.gd")
const DevGuard = preload("res://systems/dev_guard.gd")
const Skills = preload("res://data/skills.gd")

const REST_HEAL_AMOUNT := 35
const MEDITATION_MANA_AMOUNT := 15

var permanent: Dictionary = {}
var attempt: Dictionary = {}
var save_path: String = SaveStore.DEFAULT_PATH
var _playtime_tick_ms: int = Time.get_ticks_msec()


func initialize(path: String = SaveStore.DEFAULT_PATH) -> void:
	save_path = path
	_playtime_tick_ms = Time.get_ticks_msec()
	var data: Dictionary = SaveStore.load_data(path)
	var source_version: int = int(data.get("version", SaveStore.VERSION))
	permanent = _default_permanent()
	var historical_best_floor: int = 0
	if typeof(data.get("permanent")) == TYPE_DICTIONARY:
		var loaded: Dictionary = data["permanent"]
		permanent["relic_inventory"] = RelicEquipment.sanitize_inventory(loaded.get("relic_inventory", []), "permanent")
		permanent["relic_equipped"] = RelicEquipment.sanitize_equipped(loaded.get("relic_equipped", []), permanent["relic_inventory"], "permanent")
		permanent["last_relic_loadout"] = RelicEquipment.sanitize_equipped(loaded.get("last_relic_loadout", []), permanent["relic_inventory"], "permanent")
		permanent["coins"] = maxi(0, _safe_int(loaded.get("coins", 0)))
		if typeof(loaded.get("profile")) == TYPE_DICTIONARY:
			var saved_profile: Dictionary = loaded["profile"]
			var played: Variant = saved_profile.get("playtime_seconds", 0.0)
			permanent["profile"] = {
				"created_at": maxi(0, _safe_int(saved_profile.get("created_at", 0))),
				"last_saved_at": maxi(0, _safe_int(saved_profile.get("last_saved_at", 0))),
				"playtime_seconds": maxf(0.0, float(played)) if typeof(played) in [TYPE_INT, TYPE_FLOAT] else 0.0
			}
		if typeof(loaded.get("narrative")) == TYPE_DICTIONARY:
			var saved_narrative: Dictionary = loaded["narrative"]
			var narrative_state: Dictionary = permanent["narrative"]
			narrative_state["resurrection_seen"] = bool(saved_narrative.get("resurrection_seen", false))
			narrative_state["resurrection_count"] = maxi(0, _safe_int(saved_narrative.get("resurrection_count", 0)))
			var last_message := str(saved_narrative.get("last_message", ""))
			narrative_state["last_message"] = last_message if ResurrectionFlow.MESSAGES.has(last_message) else ""
			var pending_message := str(saved_narrative.get("pending_message", ""))
			var valid_message: bool = pending_message in [ResurrectionFlow.FIRST, ResurrectionFlow.SILENT] or ResurrectionFlow.MESSAGES.has(pending_message)
			narrative_state["pending_message"] = pending_message if valid_message else ""
			narrative_state["pending"] = bool(saved_narrative.get("pending", false)) and valid_message
			narrative_state["cursor"] = str(saved_narrative.get("cursor", "")) if narrative_state["pending"] else ""
			for field in ["completed_scenes", "scenes_seen", "fragments_found", "dialogues_seen", "merchant_topics_unlocked"]:
				var raw_flags: Variant = saved_narrative.get(field, {})
				if typeof(raw_flags) == TYPE_DICTIONARY:
					narrative_state[field] = _safe_true_flags(raw_flags)
			var valid_topics: Dictionary = {}
			for topic_id in MerchantDialogues.CAMP_TOPICS:
				if bool(narrative_state["merchant_topics_unlocked"].get(topic_id, false)):
					valid_topics[topic_id] = true
			narrative_state["merchant_topics_unlocked"] = valid_topics
			var seen_messages: Array = []
			if typeof(saved_narrative.get("seen_resurrection_messages")) == TYPE_ARRAY:
				for message_id in saved_narrative["seen_resurrection_messages"]:
					if message_id in ResurrectionFlow.MESSAGE_ORDER and not message_id in seen_messages:
						seen_messages.append(message_id)
			if bool(narrative_state["resurrection_seen"]) and not ResurrectionFlow.FIRST in seen_messages:
				seen_messages.append(ResurrectionFlow.FIRST)
			if str(narrative_state["last_message"]) in ResurrectionFlow.MESSAGE_ORDER and not str(narrative_state["last_message"]) in seen_messages:
				seen_messages.append(str(narrative_state["last_message"]))
			narrative_state["seen_resurrection_messages"] = seen_messages
			narrative_state["merchant_encounters"] = clampi(_safe_int(saved_narrative.get("merchant_encounters", 0)), 0, 9999)
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
		_migrate_attempt_relics()
		var old_seen: Variant = loaded_attempt.get("narrative_seen", {})
		if typeof(old_seen) == TYPE_DICTIONARY:
			var permanent_scenes: Dictionary = permanent["narrative"]["completed_scenes"]
			for scene_id in StoryFlow.PERMANENT_SCENES:
				if bool(old_seen.get(scene_id, false)):
					permanent_scenes[scene_id] = true
			permanent["narrative"]["completed_scenes"] = permanent_scenes
			if bool(old_seen.get("encontro_comerciante", false)):
				permanent["narrative"]["merchant_encounters"] = maxi(1, int(permanent["narrative"].get("merchant_encounters", 0)))
				permanent["narrative"]["completed_scenes"]["encontro_comerciante_primeiro"] = true
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
		if not str(attempt.get("merchant_camp_status", "")) in ["", "visiting", "declined", "done"]:
			attempt["merchant_camp_status"] = ""
		if typeof(attempt.get("route_history")) != TYPE_DICTIONARY:
			attempt["route_history"] = {}
		if typeof(attempt.get("rewarded_enemies")) != TYPE_DICTIONARY:
			attempt["rewarded_enemies"] = {}
		if typeof(attempt.get("merchant_shop")) != TYPE_DICTIONARY:
			attempt["merchant_shop"] = {}
		else:
			var shop_state: Dictionary = attempt["merchant_shop"]
			if typeof(shop_state.get("offers")) != TYPE_ARRAY:
				attempt["merchant_shop"] = {}
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
	var starting_relics: Array = _active_permanent_relics(hero_ids)
	for hero_id in hero_ids:
		heroes.append(Rules.create_hero(hero_id, 1, starting_relics, permanent["classes"][hero_id]["attributes"], _effective_specials(hero_id, permanent["classes"][hero_id].get("unlocked_specials", []))))
	attempt = {
		"id": "%d-%d" % [int(Time.get_unix_time_from_system()), randi()],
		"hero_ids": hero_ids.duplicate(), "heroes": heroes,
		"floor": 1, "completed": 0, "level": 1, "xp": 0,
		"coins_earned": 0, "rewarded_enemies": {},
		"relics": starting_relics, "relic_inventory": [], "phase": "between", "current_route": "", "pending_route": "", "route_history": {},
		"card_queue": [], "card_offers": {}, "relic_options": [],
		"narrative_seen": {}, "narrative_event_steps": {}, "narrative_cursor": {}, "story_v33_enabled": true,
		"merchant_camp_status": "",
		"merchant_shop": {},
	}
	return save()


func ensure_merchant_shop_stock() -> Array:
	if not has_attempt() or str(attempt.get("merchant_camp_status", "")) != "visiting":
		return []
	var shop_state: Dictionary = attempt.get("merchant_shop", {})
	var offers: Array = shop_state.get("offers", [])
	if offers.size() == 6:
		return offers.duplicate(true)
	var generated := _generate_merchant_shop_offers()
	if generated.size() != 6:
		return []
	var previous: Dictionary = attempt.duplicate(true)
	attempt["merchant_shop"] = {"offers": generated}
	if save():
		return generated.duplicate(true)
	attempt = previous
	return []


func _generate_merchant_shop_offers(previous_offers: Array = []) -> Array:
	var pools := {"simple": [], "rare": [], "epic": []}
	for relic_id in Relics.DEFINITIONS:
		var rarity := str(Relics.DEFINITIONS[relic_id].get("rarity", "simple"))
		if pools.has(rarity):
			pools[rarity].append(str(relic_id))
	var previous_ids: Dictionary = {}
	for offer in previous_offers:
		if typeof(offer) == TYPE_DICTIONARY:
			previous_ids[str(offer.get("id", ""))] = true
	var generated: Array = []
	for rarity in ["simple", "rare", "epic"]:
		var needed := 3 if rarity == "simple" else (2 if rarity == "rare" else 1)
		var pool: Array = pools[rarity].duplicate()
		for relic_id in previous_ids:
			if relic_id in pool:
				pool.erase(relic_id)
		pool.shuffle()
		for index in range(mini(needed, pool.size())):
			generated.append({"id": pool[index], "rarity": rarity, "sold": false, "mode": "", "uid": ""})
	generated.shuffle()
	return generated


func refresh_merchant_shop_stock() -> Dictionary:
	if not has_attempt() or str(attempt.get("merchant_camp_status", "")) != "visiting":
		return {"ok": false, "reason": "A loja não está disponível."}
	var current_offers: Array = ensure_merchant_shop_stock()
	if current_offers.size() != 6:
		return {"ok": false, "reason": "Não foi possível carregar o estoque atual."}
	var refresh_cost: int = Relics.SHOP_REFRESH_COST
	if int(permanent.get("coins", 0)) < refresh_cost:
		return {"ok": false, "reason": "Moedas insuficientes."}
	var new_offers := _generate_merchant_shop_offers(current_offers)
	if new_offers.size() != 6:
		return {"ok": false, "reason": "Não foi possível gerar novas mercadorias."}
	var previous_permanent: Dictionary = permanent.duplicate(true)
	var previous_attempt: Dictionary = attempt.duplicate(true)
	permanent["coins"] = int(permanent.get("coins", 0)) - refresh_cost
	attempt["merchant_shop"] = {"offers": new_offers}
	if save():
		return {"ok": true, "cost": refresh_cost, "offers": new_offers.duplicate(true)}
	permanent = previous_permanent
	attempt = previous_attempt
	return {"ok": false, "reason": "Falha ao salvar a atualização. Nenhuma moeda foi descontada."}


func buy_merchant_relic(offer_index: int, mode: String) -> Dictionary:
	if not has_attempt() or str(attempt.get("merchant_camp_status", "")) != "visiting" or not mode in ["temporary", "permanent"]:
		return {"ok": false, "reason": "A loja não está disponível."}
	var offers: Array = ensure_merchant_shop_stock()
	if offer_index < 0 or offer_index >= offers.size():
		return {"ok": false, "reason": "Oferta inválida."}
	var offer: Dictionary = offers[offer_index]
	if bool(offer.get("sold", false)):
		return {"ok": false, "reason": "Esta mercadoria já foi vendida."}
	var relic_id := str(offer.get("id", ""))
	if not Relics.DEFINITIONS.has(relic_id):
		return {"ok": false, "reason": "Relíquia indisponível."}
	var price := Relics.shop_price(relic_id, mode)
	if price <= 0 or int(permanent.get("coins", 0)) < price:
		return {"ok": false, "reason": "Moedas insuficientes."}
	var previous_permanent: Dictionary = permanent.duplicate(true)
	var previous_attempt: Dictionary = attempt.duplicate(true)
	var item: Dictionary = RelicEquipment.new_copy(relic_id, mode)
	if item.is_empty():
		return {"ok": false, "reason": "Não foi possível preparar a relíquia."}
	if mode == "permanent":
		permanent["relic_inventory"].append(item)
	else:
		attempt["relic_inventory"].append(item)
	permanent["coins"] = int(permanent.get("coins", 0)) - price
	var updated_shop: Dictionary = attempt.get("merchant_shop", {}).duplicate(true)
	var updated_offers: Array = updated_shop.get("offers", []).duplicate(true)
	updated_offers[offer_index]["sold"] = true
	updated_offers[offer_index]["mode"] = mode
	updated_offers[offer_index]["uid"] = item["uid"]
	updated_shop["offers"] = updated_offers
	attempt["merchant_shop"] = updated_shop
	if save():
		return {"ok": true, "uid": str(item["uid"]), "price": price, "mode": mode}
	permanent = previous_permanent
	attempt = previous_attempt
	return {"ok": false, "reason": "Falha ao salvar a compra. Nenhuma moeda foi descontada."}


func mark_narrative_scene(scene_id: String) -> bool:
	if not has_attempt() or not StoryFlow.is_main_scene(scene_id):
		return false
	var flags: Dictionary = attempt.get("narrative_seen", {})
	if bool(flags.get(scene_id, false)):
		return true
	flags[scene_id] = true
	attempt["narrative_seen"] = flags
	return save()


func mark_permanent_scene(scene_id: String) -> bool:
	if not scene_id in StoryFlow.PERMANENT_SCENES:
		return false
	var state: Dictionary = permanent["narrative"].duplicate(true)
	var completed: Dictionary = state.get("completed_scenes", {})
	if bool(completed.get(scene_id, false)):
		return true
	completed[scene_id] = true
	state["completed_scenes"] = completed
	var previous: Dictionary = permanent["narrative"]
	permanent["narrative"] = state
	if save():
		return true
	permanent["narrative"] = previous
	return false


func has_permanent_scene(scene_id: String) -> bool:
	return bool(permanent.get("narrative", {}).get("completed_scenes", {}).get(scene_id, false))


func mark_scene_seen(scene_id: String) -> bool:
	if scene_id.is_empty() or scene_id.length() > 80:
		return false
	var state: Dictionary = permanent["narrative"].duplicate(true)
	var seen: Dictionary = state.get("scenes_seen", {})
	if bool(seen.get(scene_id, false)):
		return true
	seen[scene_id] = true
	state["scenes_seen"] = seen
	var previous: Dictionary = permanent["narrative"]
	permanent["narrative"] = state
	if save():
		return true
	permanent["narrative"] = previous
	return false


func mark_narrative_fragment(scene_id: String) -> bool:
	if not StoryFlow.FRAGMENT_SCENES.has(scene_id):
		return false
	var state: Dictionary = permanent["narrative"].duplicate(true)
	var found: Dictionary = state.get("fragments_found", {})
	if bool(found.get(scene_id, false)):
		return true
	found[scene_id] = true
	state["fragments_found"] = found
	var previous: Dictionary = permanent["narrative"]
	permanent["narrative"] = state
	if save():
		return true
	permanent["narrative"] = previous
	return false


func mark_permanent_dialogue(dialogue_id: String) -> bool:
	var valid := dialogue_id.begins_with("merchant_greeting_")
	for topic in MerchantDialogues.CAMP_TOPICS.values():
		for line in topic.get("lines", []):
			if str(line.get("id", "")) == dialogue_id:
				valid = true
				break
		if valid:
			break
	if not valid:
		return false
	var state: Dictionary = permanent["narrative"].duplicate(true)
	var seen: Dictionary = state.get("dialogues_seen", {})
	if bool(seen.get(dialogue_id, false)):
		return true
	seen[dialogue_id] = true
	state["dialogues_seen"] = seen
	var previous: Dictionary = permanent["narrative"]
	permanent["narrative"] = state
	if save():
		return true
	permanent["narrative"] = previous
	return false


func sync_merchant_topic_unlocks(losses: int) -> Dictionary:
	var state: Dictionary = permanent["narrative"].duplicate(true)
	var unlocked: Dictionary = state.get("merchant_topics_unlocked", {}).duplicate(true)
	var changed := false
	for topic_id in MerchantDialogues.unlocked_camp_topics(losses):
		if not bool(unlocked.get(topic_id, false)):
			unlocked[topic_id] = true
			changed = true
	if not changed:
		return unlocked
	state["merchant_topics_unlocked"] = unlocked
	var previous: Dictionary = permanent["narrative"]
	permanent["narrative"] = state
	if save():
		return unlocked.duplicate(true)
	permanent["narrative"] = previous
	return previous.get("merchant_topics_unlocked", {}).duplicate(true)


func record_merchant_encounter() -> bool:
	var state: Dictionary = permanent["narrative"].duplicate(true)
	var encounters: int = int(state.get("merchant_encounters", 0))
	state["merchant_encounters"] = mini(9999, encounters + 1)
	if encounters == 0:
		var completed: Dictionary = state.get("completed_scenes", {})
		completed["encontro_comerciante_primeiro"] = true
		state["completed_scenes"] = completed
	var previous: Dictionary = permanent["narrative"]
	permanent["narrative"] = state
	if save():
		return true
	permanent["narrative"] = previous
	return false


func choose_merchant_camp(visit: bool) -> bool:
	if not has_attempt() or str(attempt.get("phase", "")) != "combat" or int(attempt.get("floor", 0)) != 5 or int(attempt.get("completed", 0)) != 4:
		return false
	attempt["merchant_camp_status"] = "visiting" if visit else "declined"
	var flags: Dictionary = attempt.get("narrative_seen", {})
	flags["encontro_comerciante"] = true
	attempt["narrative_seen"] = flags
	var cursors: Dictionary = attempt.get("narrative_cursor", {})
	cursors.erase("encontro_comerciante")
	attempt["narrative_cursor"] = cursors
	return save()


func finish_merchant_camp() -> bool:
	if not has_attempt() or str(attempt.get("merchant_camp_status", "")) != "visiting":
		return false
	attempt["merchant_camp_status"] = "done"
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
	for relic in attempt["relics"]:
		var relic_id := str(relic.get("id", ""))
		if not relic_id in ["frasco_regeneracao", "bolsa_ervas"]:
			continue
		for hero in attempt["heroes"]:
			if hero.get("state", "") != "alive" or int(hero.get("hp", 0)) <= 0:
				continue
			if relic_id == "frasco_regeneracao" and str(relic.get("bearer", "")) != str(hero["id"]):
				continue
			var amount: int = maxi(1, roundi(float(hero["max_hp"]) * 0.05)) if relic_id == "frasco_regeneracao" else 3
			hero["hp"] = mini(int(hero["max_hp"]), int(hero["hp"]) + amount)
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
	var definition: Dictionary = Relics.definition(relic_id)
	if definition.is_empty() or definition.get("rarity", "") != "simple":
		return false
	if definition["scope"] == "hero":
		var valid_bearer := false
		for hero in attempt["heroes"]:
			if hero["id"] == bearer_id:
				valid_bearer = true
		if not valid_bearer:
			return false
	elif not bearer_id.is_empty():
		return false
	var item: Dictionary = RelicEquipment.new_copy(relic_id, "temporary")
	attempt["relic_inventory"].append(item)
	var active: Array = attempt["relics"]
	var equipped_now := false
	if RelicEquipment.can_equip(active, item, bearer_id, "temporary") and not _epic_equipped(relic_id):
		active.append({"uid": item["uid"], "id": relic_id, "bearer": bearer_id, "mode": "temporary"})
		_recalculate_active_relics()
		equipped_now = true
	attempt["last_reward"] = "%s equipada." % definition["name"] if equipped_now else "%s guardada no inventário da expedição; equipe-a antes do próximo combate." % definition["name"]
	_after_relic()
	return save()


func grant_relic(relic_id: String, mode: String = "permanent") -> String:
	if not Relics.DEFINITIONS.has(relic_id) or not mode in ["permanent", "temporary"] or (mode == "temporary" and not has_attempt()):
		return ""
	var item: Dictionary = RelicEquipment.new_copy(relic_id, mode)
	var inventory: Array = permanent["relic_inventory"] if mode == "permanent" else attempt["relic_inventory"]
	inventory.append(item)
	if save():
		return str(item["uid"])
	inventory.pop_back()
	return ""


func equip_relic(uid: String, bearer_id: String, context: String = "", replace_uid: String = "") -> bool:
	if not _can_manage_relics(context):
		return false
	var mode := "permanent"
	var item: Dictionary = RelicEquipment.find_item(permanent["relic_inventory"], uid)
	if item.is_empty() and has_attempt():
		item = RelicEquipment.find_item(attempt.get("relic_inventory", []), uid)
		mode = "temporary"
	if item.is_empty() or (mode == "temporary" and not has_attempt()):
		return false
	if mode == "temporary" and context == "selection":
		return false
	if has_attempt() and not bearer_id.is_empty() and not bearer_id in attempt["hero_ids"] and mode == "temporary":
		return false
	var definition: Dictionary = Relics.definition(str(item["id"]))
	var equipped: Array = permanent["relic_equipped"] if mode == "permanent" else attempt["relics"]
	var previous: Array = equipped.duplicate(true)
	var replaced_actual := ""
	for entry in equipped.duplicate():
		if str(entry.get("uid", "")) == uid:
			equipped.erase(entry)
		elif not replace_uid.is_empty() and str(entry.get("uid", "")) == replace_uid and str(entry.get("bearer", "")) == bearer_id and str(entry.get("mode", "")) == mode:
			equipped.erase(entry)
			replaced_actual = replace_uid
	if not RelicEquipment.can_equip(equipped, item, bearer_id, mode) or (definition["rarity"] == "epic" and _epic_equipped(str(item["id"]), uid, replaced_actual)):
		if mode == "permanent":
			permanent["relic_equipped"] = previous
		else:
			attempt["relics"] = previous
		return false
	equipped.append({"uid": uid, "id": item["id"], "bearer": bearer_id, "mode": mode})
	if mode == "permanent":
		permanent["relic_equipped"] = equipped
	if not (context == "selection" and has_attempt() and str(attempt.get("phase", "")) == "combat"):
		_sync_active_relics()
	if save():
		return true
	if mode == "permanent":
		permanent["relic_equipped"] = previous
	else:
		attempt["relics"] = previous
	if not (context == "selection" and has_attempt() and str(attempt.get("phase", "")) == "combat"):
		_sync_active_relics()
	return false


func unequip_relic(uid: String, context: String = "") -> bool:
	if not _can_manage_relics(context):
		return false
	var is_permanent := false
	for entry in permanent["relic_equipped"]:
		if str(entry.get("uid", "")) == uid:
			is_permanent = true
	if not is_permanent and context == "selection":
		return false
	var equipped: Array = permanent["relic_equipped"] if is_permanent else attempt.get("relics", [])
	var previous: Array = equipped.duplicate(true)
	var found := false
	for entry in equipped.duplicate():
		if str(entry.get("uid", "")) == uid:
			equipped.erase(entry)
			found = true
	if not found:
		return false
	if is_permanent:
		permanent["relic_equipped"] = equipped
	if not (context == "selection" and has_attempt() and str(attempt.get("phase", "")) == "combat"):
		_sync_active_relics()
	if save():
		return true
	if is_permanent:
		permanent["relic_equipped"] = previous
	else:
		attempt["relics"] = previous
	if not (context == "selection" and has_attempt() and str(attempt.get("phase", "")) == "combat"):
		_sync_active_relics()
	return false


func remove_relic(uid: String, context: String = "") -> bool:
	if not _can_manage_relics(context):
		return false
	if context == "selection" and not RelicEquipment.find_item(attempt.get("relic_inventory", []), uid).is_empty():
		return false
	unequip_relic(uid, context)
	for key in ["relic_inventory"]:
		for inventory in [permanent[key], attempt.get(key, [])]:
			for item in inventory.duplicate():
				if str(item.get("uid", "")) == uid:
					inventory.erase(item)
					return save()
	return false


func reequip_last_relics() -> bool:
	if not _can_manage_relics("selection"):
		return false
	var previous: Array = permanent["relic_equipped"].duplicate(true)
	var proposed: Array = RelicEquipment.sanitize_equipped(permanent.get("last_relic_loadout", []), permanent["relic_inventory"], "permanent")
	permanent["relic_equipped"] = proposed
	if not (has_attempt() and str(attempt.get("phase", "")) == "combat"):
		_sync_active_relics()
	if save():
		return true
	permanent["relic_equipped"] = previous
	if not (has_attempt() and str(attempt.get("phase", "")) == "combat"):
		_sync_active_relics()
	return false


func _can_manage_relics(context: String) -> bool:
	return not has_attempt() or str(attempt.get("phase", "")) != "combat" or context == "selection" or (context == "camp" and str(attempt.get("merchant_camp_status", "")) == "visiting") or DevGuard.is_dev_path(save_path)


func _epic_equipped(relic_id: String, excluding_uid: String = "", replaced_uid: String = "") -> bool:
	if Relics.DEFINITIONS[relic_id]["rarity"] != "epic":
		return false
	for entry in permanent["relic_equipped"]:
		if entry.get("id", "") == relic_id and entry.get("uid", "") != excluding_uid and entry.get("uid", "") != replaced_uid:
			return true
	for entry in attempt.get("relics", []):
		if entry.get("id", "") == relic_id and entry.get("uid", "") != excluding_uid and entry.get("uid", "") != replaced_uid:
			return true
	return false


func _active_permanent_relics(hero_ids: Array) -> Array:
	var result: Array = []
	for entry in permanent.get("relic_equipped", []):
		if str(entry.get("bearer", "")).is_empty() or str(entry.get("bearer", "")) in hero_ids:
			result.append(entry.duplicate(true))
	return result


func _sync_active_relics() -> void:
	if not has_attempt():
		return
	var active: Array = []
	var epic_ids: Dictionary = {}
	for entry in _active_permanent_relics(attempt["hero_ids"]):
		active.append(entry)
		if Relics.DEFINITIONS.get(entry.get("id", ""), {}).get("rarity", "") == "epic":
			epic_ids[entry["id"]] = true
	for entry in attempt.get("relics", []):
		if str(entry.get("mode", "temporary")) == "temporary":
			if Relics.DEFINITIONS.get(entry.get("id", ""), {}).get("rarity", "") == "epic":
				if epic_ids.has(entry["id"]):
					continue
				epic_ids[entry["id"]] = true
			active.append(entry.duplicate(true))
	attempt["relics"] = active
	_recalculate_active_relics()


func _recalculate_active_relics() -> void:
	if not has_attempt():
		return
	for hero in attempt["heroes"]:
		Rules.recalculate(hero, int(attempt["level"]), attempt["relics"])


func _migrate_attempt_relics() -> void:
	var inventory: Array = RelicEquipment.sanitize_inventory(attempt.get("relic_inventory", []), "temporary")
	var equipped: Array = []
	var active_permanent: Array = []
	var epic_ids: Dictionary = {}
	for old in attempt.get("relics", []):
		if typeof(old) != TYPE_DICTIONARY or not Relics.DEFINITIONS.has(str(old.get("id", ""))):
			continue
		if str(old.get("mode", "temporary")) == "permanent":
			var owned: Dictionary = RelicEquipment.find_item(permanent["relic_inventory"], str(old.get("uid", "")))
			if not owned.is_empty() and str(owned["id"]) == str(old["id"]):
				var bearer: String = str(old.get("bearer", ""))
				if (bearer.is_empty() or bearer in attempt["hero_ids"]) and RelicEquipment.can_equip(active_permanent, owned, bearer, "permanent"):
					active_permanent.append({"uid": owned["uid"], "id": owned["id"], "bearer": bearer, "mode": "permanent"})
					if Relics.DEFINITIONS[owned["id"]].get("rarity", "") == "epic":
						epic_ids[owned["id"]] = true
			continue
		var item: Dictionary = RelicEquipment.find_item(inventory, str(old.get("uid", "")))
		if item.is_empty():
			item = RelicEquipment.new_copy(str(old["id"]), "temporary")
			inventory.append(item)
		var bearer := str(old.get("bearer", ""))
		if RelicEquipment.can_equip(equipped, item, bearer, "temporary") and not (Relics.DEFINITIONS[item["id"]].get("rarity", "") == "epic" and epic_ids.has(item["id"])):
			equipped.append({"uid": item["uid"], "id": item["id"], "bearer": bearer, "mode": "temporary"})
			if Relics.DEFINITIONS[item["id"]].get("rarity", "") == "epic":
				epic_ids[item["id"]] = true
	attempt["relic_inventory"] = inventory
	attempt["relics"] = active_permanent + equipped
	var saved_shop: Variant = attempt.get("merchant_shop", {})
	var safe_shop: Dictionary = {}
	if typeof(saved_shop) == TYPE_DICTIONARY and typeof(saved_shop.get("offers")) == TYPE_ARRAY:
		var raw_offers: Array = saved_shop["offers"]
		var sanitized: Array = []
		var seen_ids: Dictionary = {}
		var counts := {"simple": 0, "rare": 0, "epic": 0}
		var valid := raw_offers.size() == 6
		for raw_offer in raw_offers:
			if typeof(raw_offer) != TYPE_DICTIONARY:
				valid = false
				break
			var relic_id := str(raw_offer.get("id", ""))
			if not Relics.DEFINITIONS.has(relic_id) or seen_ids.has(relic_id):
				valid = false
				break
			var rarity := str(Relics.DEFINITIONS[relic_id].get("rarity", "simple"))
			if not counts.has(rarity):
				valid = false
				break
			var sold := bool(raw_offer.get("sold", false))
			var mode := str(raw_offer.get("mode", ""))
			var uid := str(raw_offer.get("uid", ""))
			if sold and (not mode in ["temporary", "permanent"] or uid.is_empty() or RelicEquipment.find_item(permanent["relic_inventory"] if mode == "permanent" else inventory, uid).is_empty()):
				valid = false
				break
			seen_ids[relic_id] = true
			counts[rarity] += 1
			sanitized.append({"id": relic_id, "rarity": rarity, "sold": sold, "mode": mode if sold else "", "uid": uid if sold else ""})
		valid = valid and counts["simple"] == 3 and counts["rare"] == 2 and counts["epic"] == 1
		if valid:
			safe_shop["offers"] = sanitized
	attempt["merchant_shop"] = safe_shop
	_recalculate_active_relics()


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
	permanent["last_relic_loadout"] = permanent["relic_equipped"].duplicate(true)
	permanent["relic_equipped"] = []
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
	var previously_seen: Array = state.get("seen_resurrection_messages", [])
	var message_id: String = ResurrectionFlow.FIRST if not bool(state.get("resurrection_seen", false)) else ResurrectionFlow.choose_unseen_message(int(permanent["stats"]["losses"]), previously_seen, randi())
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
	var seen_messages: Array = state.get("seen_resurrection_messages", []).duplicate()
	if not message_id in seen_messages:
		seen_messages.append(message_id)
	state["seen_resurrection_messages"] = seen_messages
	state["pending"] = false
	state["pending_message"] = ""
	state["cursor"] = ""
	permanent["narrative"] = state
	if save():
		return true
	permanent["narrative"] = previous
	return false


func save() -> bool:
	if save_path.is_empty():
		return false
	var previous_profile: Dictionary = permanent.get("profile", {}).duplicate(true)
	var profile: Dictionary = previous_profile.duplicate(true)
	var now := int(Time.get_unix_time_from_system())
	if int(profile.get("created_at", 0)) <= 0:
		profile["created_at"] = now
	profile["last_saved_at"] = now
	profile["playtime_seconds"] = maxf(0.0, float(profile.get("playtime_seconds", 0.0))) + maxf(0.0, float(Time.get_ticks_msec() - _playtime_tick_ms) / 1000.0)
	permanent["profile"] = profile
	if SaveStore.save_data(permanent, attempt, save_path):
		_playtime_tick_ms = Time.get_ticks_msec()
		return true
	permanent["profile"] = previous_profile
	return false


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


func refund_attribute(hero_id: String, attribute_id: String) -> bool:
	if not permanent.get("classes", {}).has(hero_id):
		return false
	var entry: Dictionary = permanent["classes"][hero_id]
	var previous: Dictionary = entry.duplicate(true)
	if not Progression.refund(entry, hero_id, attribute_id):
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
		var available: Array[String] = Relics.available(attempt.get("relic_inventory", []), attempt["hero_ids"])
		var eligible: Array[String] = []
		for relic_id in available:
			var definition: Dictionary = Relics.DEFINITIONS[relic_id]
			if definition.get("scope", "hero") == "team":
				eligible.append(relic_id)
			else:
				for hero in attempt["heroes"]:
					if hero["state"] == "alive" and int(hero["hp"]) > 0:
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
	for relic in value["relics"]:
		if typeof(relic) != TYPE_DICTIONARY or not Relics.DEFINITIONS.has(relic.get("id", "")) or typeof(relic.get("bearer")) != TYPE_STRING:
			return false
		if Relics.DEFINITIONS[relic["id"]].get("scope", "hero") == "team" and relic["bearer"] != "":
			return false
		if Relics.DEFINITIONS[relic["id"]].get("scope", "hero") == "hero" and relic["bearer"] == "":
			return false
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
		if not Relics.DEFINITIONS.has(relic_id) or Relics.DEFINITIONS[relic_id].get("rarity", "") != "simple":
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
	return {"coins": 0, "relic_inventory": [], "relic_equipped": [], "last_relic_loadout": [], "profile": {"created_at": 0, "last_saved_at": 0, "playtime_seconds": 0.0}, "classes": classes, "stats": {"attempts": 0, "wins": 0, "losses": 0, "floors_completed": 0, "best_floor_reached": 0}, "narrative": {"resurrection_seen": false, "resurrection_count": 0, "last_message": "", "seen_resurrection_messages": [], "pending": false, "pending_message": "", "cursor": "", "completed_scenes": {}, "scenes_seen": {}, "fragments_found": {}, "dialogues_seen": {}, "merchant_topics_unlocked": MerchantDialogues.unlocked_camp_topics(0), "merchant_encounters": 0}}


func _safe_true_flags(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in raw:
		if typeof(key) == TYPE_STRING and bool(raw[key]):
			result[key] = true
	return result
