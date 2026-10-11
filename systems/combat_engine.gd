extends RefCounted

const Skills = preload("res://data/skills.gd")
const Heroes = preload("res://data/heroes.gd")
const Rules = preload("res://systems/combat_rules.gd")
const StateEffects = preload("res://systems/state_effects.gd")
const Progression = preload("res://systems/permanent_progression.gd")
const Relics = preload("res://data/relics.gd")
const ORC_HEAVY_MULTIPLIER := 1.5
const GOBLIN_FEINT_MULTIPLIER := 1.25
const CULTIST_RITUAL_BONUS := 0.2

var fighters: Dictionary = {}
var order: Array[String] = []
var hero_ids: Array[String] = []
var enemy_ids: Array[String] = []
var index: int = 0
var round_number: int = 1
var rescue_used: bool = false
var finished: bool = false
var outcome: String = ""
var events: Array[String] = []
var visual_events: Array[Dictionary] = []
var enemy_action_counts: Dictionary = {}
var enemy_intentions: Dictionary = {}
var hero_turn_counts: Dictionary = {}
var pending_vamp_damage: int = 0
var relics: Array = []
var relic_used: Dictionary = {}
var relic_counts: Dictionary = {}
var offensive_history: Dictionary = {}
var action_multiplier: Dictionary = {}
var action_echo_damage: int = 0
var action_echo_target: String = ""
var action_echo_enabled: bool = false
var action_offensive_target: String = ""


func start(heroes: Array, enemies: Array, equipped_relics: Array = []) -> void:
	relics = equipped_relics.duplicate(true)
	relic_used.clear()
	relic_counts.clear()
	offensive_history.clear()
	action_multiplier.clear()
	action_echo_damage = 0
	action_echo_target = ""
	action_echo_enabled = false
	action_offensive_target = ""
	fighters.clear()
	order.clear()
	hero_ids.clear()
	enemy_ids.clear()
	enemy_action_counts.clear()
	enemy_intentions.clear()
	hero_turn_counts.clear()
	events.clear()
	visual_events.clear()
	index = 0
	round_number = 1
	rescue_used = false
	finished = false
	outcome = ""
	for source in heroes:
		var hero: Dictionary = source.duplicate(true)
		hero["defending"] = false
		StateEffects.clear(hero)
		hero["cooldown_remaining"] = 0
		hero["cooldown_just_started"] = false
		hero["skill_cooldowns"] = {}
		hero["skill_cooldowns_just_started"] = {}
		hero["guard_reduction"] = 0.0
		hero["guard_source"] = ""
		hero["guard_expires_on_source_turn"] = 0
		hero_ids.append(hero["id"])
		hero["relic_march_protection"] = _has_relic("marcha_conclave", hero["id"])
		hero["relic_aurora_protection"] = false
		fighters[hero["id"]] = hero
		hero_turn_counts[hero["id"]] = 0
		order.append(hero["id"])
	for source in enemies:
		var enemy: Dictionary = source.duplicate(true)
		enemy["defending"] = false
		enemy["ritual_bonus"] = 0.0
		enemy["orc_heavy_ready"] = false
		enemy["goblin_feint_ready"] = false
		StateEffects.clear(enemy)
		fighters[enemy["id"]] = enemy
		enemy_ids.append(enemy["id"])
		order.append(enemy["id"])
	order.sort_custom(func(a: String, b: String) -> bool: return int(fighters[a]["initiative"]) > int(fighters[b]["initiative"]))
	for position in range(order.size()):
		if _is_alive(fighters[order[position]]):
			index = position
			break
	for enemy_id in enemy_ids:
		if _is_alive(fighters[enemy_id]):
			var enemy: Dictionary = fighters[enemy_id]
			enemy["impact_ready"] = false
			enemy["boss_next_special"] = "prepare"
			enemy["boss_phase_two"] = false
			fighters[enemy_id] = enemy
			_plan_enemy_intention(enemy_id)
	if not _check_result():
		_begin_current_turn()


func current_id() -> String:
	return order[index] if not order.is_empty() else ""


func current() -> Dictionary:
	return fighters.get(current_id(), {})


func intention_for(enemy_id: String) -> Dictionary:
	var planned: Dictionary = enemy_intentions.get(enemy_id, {})
	var target_id: String = str(planned.get("target_id", ""))
	if not target_id.is_empty() and not _is_alive(fighters.get(target_id, {})):
		_plan_enemy_intention(enemy_id)
	return enemy_intentions.get(enemy_id, {}).duplicate(true)


func sync_boss_phase() -> void:
	_try_start_boss_second_phase("guardiao")


func is_hero_turn() -> bool:
	return not finished and current().get("team", "") == "hero" and _is_alive(current())


func targets(action: String) -> Array[String]:
	var result: Array[String] = []
	var skill: Dictionary = Skills.get_definition(skill_id_for(current(), action)) if is_skill_action(action) else {}
	var target_type: String = str(skill.get("target", ""))
	if action == "attack" or target_type == "enemy" or target_type == "all_enemies":
		for enemy_id in enemy_ids:
			if _is_alive(fighters[enemy_id]):
				result.append(enemy_id)
	elif action == "rescue":
		for hero_id in hero_ids:
			if fighters[hero_id]["state"] == "downed":
				result.append(hero_id)
	elif target_type == "living_ally" or target_type == "ally_unprotected":
		for hero_id in hero_ids:
			if not _is_alive(fighters[hero_id]):
				continue
			if target_type == "ally_unprotected" and float(fighters[hero_id].get("guard_reduction", 0.0)) > 0.0:
				continue
			result.append(hero_id)
	elif target_type == "hero":
		for hero_id in hero_ids:
			if fighters[hero_id]["state"] == "alive" or fighters[hero_id]["state"] == "downed":
				result.append(hero_id)
	elif target_type == "self":
		result.append(current_id())
	elif target_type == "all_allies":
		for hero_id in hero_ids:
			if _is_alive(fighters[hero_id]):
				result.append(hero_id)
	return result


func skill_available(skill_id: String = "") -> bool:
	var actor: Dictionary = current()
	if not is_hero_turn():
		return false
	if skill_id.is_empty():
		skill_id = str(actor.get("skill", ""))
	var skill: Dictionary = Skills.get_definition(skill_id)
	if skill.is_empty():
		return false
	var available_skills: Array[String] = skill_ids_for(actor)
	if not skill_id in available_skills:
		return false
	return skill_cooldown_remaining(current_id(), skill_id) == 0 and int(actor.get("mana", 0)) >= int(skill.get("mana", 0))


func skill_ids_for(actor: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var definition: Dictionary = Heroes.get_definition(str(actor.get("id", "")))
	if definition.is_empty():
		return result
	var primary: String = str(definition.get("skill", ""))
	if not primary.is_empty():
		result.append(primary)
	for alternate in definition.get("alternate_skills", []):
		result.append(str(alternate))
	for special in actor.get("unlocked_specials", []):
		if special in Skills.SPECIALS.get(str(actor.get("id", "")), []) and not special in result:
			result.append(str(special))
	return result


func skill_cooldown_remaining(fighter_id: String, skill_id: String) -> int:
	var fighter: Dictionary = fighters.get(fighter_id, {})
	return int(fighter.get("skill_cooldowns", {}).get(skill_id, 0))


func is_skill_action(action: String) -> bool:
	return action == "skill" or action.begins_with("skill:")


func skill_id_for(actor: Dictionary, action: String) -> String:
	return action.substr(6) if action.begins_with("skill:") else str(actor.get("skill", ""))


func act(action: String, target_id: String = "") -> bool:
	if not is_hero_turn():
		return false
	events.clear()
	visual_events.clear()
	pending_vamp_damage = 0
	var actor_id: String = current_id()
	var actor: Dictionary = fighters[actor_id]
	action_echo_damage = 0
	action_echo_target = ""
	action_echo_enabled = false
	action_offensive_target = ""
	action_multiplier[actor_id] = 1.0
	if action == "defend":
		actor["defending"] = true
		if _has_relic("anel_persistencia", actor_id) and int(actor.get("mana_max", 0)) > 0:
			var recovered := mini(2, int(actor["mana_max"]) - int(actor.get("mana", 0)))
			actor["mana"] = int(actor.get("mana", 0)) + recovered
			if recovered > 0:
				events.append("Anel da Persistência recupera %d mana." % recovered)
		fighters[actor_id] = actor
		events.append("%s se defende; o próximo dano será reduzido pela metade." % actor["name"])
	elif action == "rescue":
		if rescue_used or not target_id in targets("rescue"):
			return false
		rescue_used = true
		_revive(target_id)
		events.append("%s socorre %s (1 uso neste combate)." % [actor["name"], fighters[target_id]["name"]])
	elif action == "attack":
		if not target_id in targets("attack"):
			return false
		_prepare_offensive_action(actor_id, target_id)
		_deal_damage(actor_id, target_id, int(actor["damage"]), actor["attack_type"], true, false)
	elif is_skill_action(action):
		var selected_skill_id: String = skill_id_for(actor, action)
		var skill: Dictionary = Skills.get_definition(selected_skill_id)
		if skill.is_empty() or not skill_available(selected_skill_id):
			return false
		if skill.get("target", "") in ["all_enemies", "all_allies", "self"]:
			if not target_id.is_empty() or targets(action).is_empty():
				return false
		elif not target_id in targets(action):
			return false
		if str(skill.get("target", "")) == "enemy" and str(skill.get("kind", "")) in ["damage", "damage_status", "damage_buff", "execute", "pierce"]:
			_prepare_offensive_action(actor_id, target_id)
			if _has_relic("codice_eco", actor_id) and not bool(relic_used.get("codice_eco:%s" % actor_id, false)):
				action_echo_enabled = true
				action_echo_target = target_id
				relic_used["codice_eco:%s" % actor_id] = true
		var cost: int = int(skill.get("mana", 0))
		actor["mana"] = int(actor.get("mana", 0)) - cost
		if cost > 0 and _has_relic("ampulheta_arcana", actor_id) and not bool(relic_used.get("ampulheta_arcana:%s" % actor_id, false)):
			actor["mana"] = mini(int(actor["mana_max"]), int(actor["mana"]) + cost)
			relic_used["ampulheta_arcana:%s" % actor_id] = true
			events.append("Ampulheta Arcana devolve %d mana." % cost)
		if cost > 0 and actor.get("arcane_stone", false):
			var recovered_mana: int = mini(2, int(actor["mana_max"]) - int(actor["mana"]))
			actor["mana"] = int(actor["mana"]) + recovered_mana
			if recovered_mana > 0:
				events.append("Pedra Arcana recupera %d mana para %s." % [recovered_mana, actor["name"]])
		if int(skill.get("cooldown", 0)) > 0:
			var cooldowns: Dictionary = actor.get("skill_cooldowns", {}).duplicate(true)
			cooldowns[selected_skill_id] = int(skill["cooldown"])
			actor["skill_cooldowns"] = cooldowns
			var cooldowns_started: Dictionary = actor.get("skill_cooldowns_just_started", {}).duplicate(true)
			cooldowns_started[selected_skill_id] = true
			actor["skill_cooldowns_just_started"] = cooldowns_started
			actor["cooldown_remaining"] = int(skill["cooldown"]) if selected_skill_id == str(actor.get("skill", "")) else int(actor.get("cooldown_remaining", 0))
		fighters[actor_id] = actor
		if skill["kind"] == "self_buff":
			var buff_result: Dictionary = StateEffects.apply(fighters[actor_id], str(skill["effect"]))
			var buff_actor: Dictionary = fighters[actor_id]
			var effect: Dictionary = buff_result["effect"]
			effect["skip_turn"] = true
			buff_actor["state_effects"][skill["effect"]] = effect
			fighters[actor_id] = buff_actor
			events.append("%s ativa %s por 2 próximos turnos próprios." % [actor["name"], skill["name"]])
		elif skill["kind"] == "guard":
			var target: Dictionary = fighters[target_id]
			target["guard_reduction"] = float(skill.get("reduction", 0.4))
			target["guard_source"] = actor_id
			target["guard_expires_on_source_turn"] = int(hero_turn_counts.get(actor_id, 0)) + 1
			fighters[target_id] = target
			events.append("%s usa Guarda Protetora em %s: o próximo dano será reduzido em 40%% até o próximo turno do Guerreiro." % [actor["name"], target["name"]])
		elif skill["kind"] == "heal_all":
			for ally_id in hero_ids:
				var ally: Dictionary = fighters[ally_id]
				if not _is_alive(ally):
					continue
				var before_hp: int = int(ally["hp"])
				var healed: int = mini(Rules.heal_amount(actor, int(skill["amount"])), int(ally["max_hp"]) - int(ally["hp"]))
				ally["hp"] = int(ally["hp"]) + healed
				fighters[ally_id] = ally
				_record_heal(ally_id, healed)
				_maybe_mercy_bell(actor_id, ally_id, before_hp, healed)
				events.append("%s usa Prece Restauradora: %s recupera %d PV." % [actor["name"], ally["name"], healed])
		elif skill["kind"] == "miracle":
			var ally: Dictionary = fighters[target_id]
			if ally["state"] == "downed":
				_revive(target_id, 0.45)
				ally = fighters[target_id]
				events.append("%s usa Milagre Divino e reanima %s com %d PV." % [actor["name"], ally["name"], ally["hp"]])
			else:
				var before_hp: int = int(ally["hp"])
				var healed: int = mini(Rules.heal_amount(actor, int(skill["amount"])), int(ally["max_hp"]) - int(ally["hp"]))
				ally["hp"] = int(ally["hp"]) + healed
				_record_heal(target_id, healed)
				_maybe_mercy_bell(actor_id, target_id, before_hp, healed)
				events.append("%s usa Milagre Divino: %s recupera %d PV." % [actor["name"], ally["name"], healed])
			for effect_id in ["veneno", "fraqueza"]:
				var removed: Dictionary = StateEffects.remove(ally, effect_id)
				if not removed.is_empty():
					events.append("Milagre Divino remove %s de %s." % [removed["name"], ally["name"]])
			fighters[target_id] = ally
		elif skill["kind"] == "heal":
			var target: Dictionary = fighters[target_id]
			if target["state"] == "downed":
				_revive(target_id)
				events.append("%s usa Cura e reanima %s com %d PV." % [actor["name"], target["name"], fighters[target_id]["hp"]])
			else:
				var before_hp: int = int(target["hp"])
				var missing_hp: int = int(target["max_hp"]) - int(target["hp"])
				var amount: int = mini(Rules.heal_amount(actor, int(skill["amount"])), missing_hp)
				target["hp"] = int(target["hp"]) + amount
				fighters[target_id] = target
				_record_heal(target_id, amount)
				_maybe_mercy_bell(actor_id, target_id, before_hp, amount)
				events.append("%s usa Cura em %s e recupera %d PV." % [actor["name"], target["name"], amount])
				var card_level: int = int(actor.get("cards", {}).get("graca_divina", 0))
				var extra_healing: int = amount - mini(int(skill["amount"]), missing_hp)
				if card_level > 0 and extra_healing > 0:
					events.append("Graça Divina %s acrescenta %d PV à cura." % [["I", "II", "III"][card_level - 1], extra_healing])
		elif skill["kind"] == "purify":
			var target: Dictionary = fighters[target_id]
			var before_hp: int = int(target["hp"])
			var removed_names: Array[String] = []
			for effect_id in ["veneno", "fraqueza"]:
				var removed: Dictionary = StateEffects.remove(target, effect_id)
				if not removed.is_empty():
					removed_names.append(str(removed["name"]))
					events.append("%s remove %s de %s." % [actor["name"], removed["name"], target["name"]])
			var missing_hp: int = int(target["max_hp"]) - int(target["hp"])
			var healed: int = mini(Rules.heal_amount(actor, int(skill["amount"])), missing_hp)
			target["hp"] = int(target["hp"]) + healed
			fighters[target_id] = target
			_record_heal(target_id, healed)
			_maybe_mercy_bell(actor_id, target_id, before_hp, healed)
			var removed_text: String = "Removeu %s. " % ", ".join(removed_names) if not removed_names.is_empty() else ""
			events.append("%s usa Purificação em %s. %sRecupera %d PV." % [actor["name"], target["name"], removed_text, healed])
			var grace_level: int = int(actor.get("cards", {}).get("graca_divina", 0))
			var extra_healing: int = healed - mini(int(skill["amount"]), missing_hp)
			if grace_level > 0 and extra_healing > 0:
				events.append("Graça Divina %s acrescenta %d PV à Purificação." % [["I", "II", "III"][grace_level - 1], extra_healing])
		elif skill["kind"] == "status":
			var result: Dictionary = StateEffects.apply(fighters[target_id], str(skill.get("effect", "")))
			if result.is_empty():
				return false
			var target: Dictionary = fighters[target_id]
			_enhance_poison(actor_id, target_id, str(skill.get("effect", "")))
			var effect: Dictionary = result["effect"]
			fighters[target_id] = target
			var verb: String = "renova" if result["refreshed"] else "aplica"
			events.append("%s %s %s em %s (%d turnos próprios)." % [actor["name"], verb, effect["name"], target["name"], effect["duration"]])
		elif skill["kind"] == "status_all":
			for enemy_id in enemy_ids:
				if not _is_alive(fighters[enemy_id]):
					continue
				var result: Dictionary = StateEffects.apply(fighters[enemy_id], str(skill["effect"]))
				_enhance_poison(actor_id, enemy_id, str(skill["effect"]))
				var verb: String = "renova" if result["refreshed"] else "aplica"
				events.append("%s %s Fraqueza em %s por 2 turnos próprios." % [actor["name"], verb, fighters[enemy_id]["name"]])
		elif skill["kind"] == "damage_status":
			_deal_damage(actor_id, target_id, int(skill["amount"]), skill["damage_type"], false, false, skill["name"])
			if _is_alive(fighters[target_id]):
				var result: Dictionary = StateEffects.apply(fighters[target_id], str(skill.get("effect", "")))
				if not result.is_empty():
					_enhance_poison(actor_id, target_id, str(skill.get("effect", "")))
					var effect: Dictionary = result["effect"]
					var verb: String = "renova" if result["refreshed"] else "aplica"
					events.append("%s %s %s em %s (%d turnos próprios)." % [actor["name"], verb, effect["name"], fighters[target_id]["name"], effect["duration"]])
		elif skill["kind"] == "damage_all":
			for enemy_id in enemy_ids:
				if _is_alive(fighters[enemy_id]):
					_deal_damage(actor_id, enemy_id, int(skill["amount"]), skill["damage_type"], false, skill["damage_type"] == "magical", skill["name"])
		elif skill["kind"] == "damage_buff":
			_deal_damage(actor_id, target_id, int(skill["amount"]), skill["damage_type"], false, false, skill["name"])
			var buff_result: Dictionary = StateEffects.apply(fighters[actor_id], str(skill["effect"]))
			var buff_actor: Dictionary = fighters[actor_id]
			var effect: Dictionary = buff_result["effect"]
			effect["skip_turn"] = true
			buff_actor["state_effects"][skill["effect"]] = effect
			fighters[actor_id] = buff_actor
			events.append("Instinto Predador concede +25 p.p. de crítico a %s por 2 próximos turnos próprios." % actor["name"])
		elif skill["kind"] == "execute":
			var target: Dictionary = fighters[target_id]
			var bonus: float = 1.35 if float(target["hp"]) < float(target["max_hp"]) * 0.35 else 1.0
			if bonus > 1.0:
				events.append("Golpe do Carrasco: alvo abaixo de 35%% PV, +35%% de dano da habilidade.")
			_deal_damage(actor_id, target_id, int(skill["amount"]), "physical", false, false, skill["name"], bonus)
		elif skill["kind"] == "pierce":
			_deal_damage(actor_id, target_id, int(skill["amount"]), "magical", false, true, skill["name"], 1.0, 0.5)
		else:
			var hits: int = int(skill.get("hits", 1))
			for hit in range(hits):
				if int(fighters[target_id]["hp"]) <= 0:
					break
				_deal_damage(actor_id, target_id, int(skill["amount"]), skill["damage_type"], false, skill["damage_type"] == "magical", skill["name"])
	else:
		return false
	if action_echo_enabled and action_echo_damage > 0 and _is_alive(fighters[action_echo_target]):
		_deal_fixed_damage(actor_id, action_echo_target, maxi(1, roundi(float(action_echo_damage) * 0.5)), "Códice do Eco")
	_check_purification()
	if pending_vamp_damage > 0 and _is_alive(fighters[actor_id]):
		var vamp_actor: Dictionary = fighters[actor_id]
		var healed: int = mini(int(vamp_actor["max_hp"]) - int(vamp_actor["hp"]), roundi(float(pending_vamp_damage) * 0.30))
		if healed > 0:
			vamp_actor["hp"] = int(vamp_actor["hp"]) + healed
			fighters[actor_id] = vamp_actor
			_record_heal(actor_id, healed)
			events.append("Vampirismo Mágico recupera %d PV para %s." % [healed, vamp_actor["name"]])
	if _is_alive(fighters[actor_id]):
		var acted: Dictionary = fighters[actor_id]
		acted["relic_march_protection"] = false
		fighters[actor_id] = acted
	if action_offensive_target.is_empty():
		offensive_history.erase(actor_id)
	_after_action(actor_id)
	return true


func act_enemy() -> bool:
	if finished or current().get("team", "") != "enemy" or not _is_alive(current()):
		return false
	events.clear()
	visual_events.clear()
	var enemy_id: String = current_id()
	var enemy: Dictionary = fighters[enemy_id]
	var living: Array[String] = []
	for hero_id in hero_ids:
		if _is_alive(fighters[hero_id]):
			living.append(hero_id)
	if living.is_empty():
		_check_result()
		return true
	var intention: Dictionary = intention_for(enemy_id)
	var action_kind: String = str(intention.get("id", "attack"))
	var target_id: String = str(intention.get("target_id", ""))
	if action_kind == "cultist_ritual":
		if not _is_alive(fighters.get(target_id, {})):
			target_id = _ritual_target(enemy_id)
			intention["target_id"] = target_id
			enemy_intentions[enemy_id] = intention
	elif not target_id in living:
		target_id = living.pick_random()
		intention["target_id"] = target_id
		enemy_intentions[enemy_id] = intention
	enemy_action_counts[enemy_id] = int(enemy_action_counts.get(enemy_id, 0)) + 1
	if action_kind == "orc_prepare":
		enemy["orc_heavy_ready"] = true
		enemy["orc_heavy_target"] = target_id
		fighters[enemy_id] = enemy
		events.append("%s prepara Golpe Brutal contra %s!" % [enemy["name"], fighters[target_id]["name"]])
	elif action_kind == "orc_heavy":
		enemy["orc_heavy_ready"] = false
		fighters[enemy_id] = enemy
		_deal_damage(enemy_id, target_id, int(enemy["damage"]), "physical", false, false, "Golpe Brutal", ORC_HEAVY_MULTIPLIER)
	elif action_kind == "cultist_ritual":
		var ally: Dictionary = fighters[target_id]
		ally["ritual_bonus"] = CULTIST_RITUAL_BONUS
		fighters[target_id] = ally
		events.append("%s fortalece %s: o próximo ataque causará 20%% mais dano." % [enemy["name"], ally["name"]])
		_plan_enemy_intention(target_id)
	elif action_kind == "goblin_feint":
		var choices: Array[String] = living.duplicate()
		choices.erase(str(enemy.get("goblin_last_target", "")))
		if choices.is_empty():
			choices = living.duplicate()
		enemy["goblin_feint_target"] = choices.pick_random()
		enemy["goblin_feint_ready"] = true
		fighters[enemy_id] = enemy
		if living.size() > 1 and str(enemy["goblin_feint_target"]) != str(enemy.get("goblin_last_target", "")):
			events.append("%s usa Finta e muda o alvo para %s!" % [enemy["name"], fighters[enemy["goblin_feint_target"]]["name"]])
		else:
			events.append("%s usa Finta e prepara um ataque contra %s!" % [enemy["name"], fighters[enemy["goblin_feint_target"]]["name"]])
	elif action_kind == "goblin_strike":
		enemy["goblin_feint_ready"] = false
		enemy["goblin_last_target"] = target_id
		fighters[enemy_id] = enemy
		_deal_damage(enemy_id, target_id, int(enemy["damage"]), "physical", false, false, "Ataque de Finta", GOBLIN_FEINT_MULTIPLIER)
	elif action_kind == "prepare_impact":
		enemy["impact_ready"] = true
		enemy["boss_next_special"] = "impact"
		fighters[enemy_id] = enemy
		events.append("%s prepara Impacto Devastador!" % enemy["name"])
	elif action_kind == "devastating_impact":
		var enhanced_damage: int = ceili(float(enemy["damage"]) * 1.5)
		_deal_damage(enemy_id, target_id, enhanced_damage, "physical", false, false, "Impacto Devastador")
		enemy = fighters[enemy_id]
		enemy["impact_ready"] = false
		enemy["boss_next_special"] = "onda"
		fighters[enemy_id] = enemy
	elif action_kind == "shadow_wave":
		events.append("%s usa Onda Sombria em todo o grupo!" % enemy["name"])
		enemy["boss_next_special"] = "basic"
		fighters[enemy_id] = enemy
		for hero_id in living:
			_deal_damage(enemy_id, hero_id, int(enemy.get("special_damage", 18)), "magical", false, true, "Onda Sombria")
	elif action_kind == "spectral_strike":
		_deal_damage(enemy_id, target_id, maxi(1, roundi(float(enemy["damage"]) * 0.8)), "magical", false, true, "Lâmina Espectral")
		enemy = fighters[enemy_id]
		enemy["boss_next_special"] = "prepare"
		fighters[enemy_id] = enemy
	elif action_kind == "weakened_strike":
		_deal_damage(enemy_id, target_id, int(enemy["damage"]), "physical", false, false, "Golpe Enfraquecedor")
		var effect_result: Dictionary = StateEffects.apply(fighters[target_id], "fraqueza")
		if not effect_result.is_empty():
			var target: Dictionary = fighters[target_id]
			var effect: Dictionary = effect_result["effect"]
			fighters[target_id] = target
			var verb: String = "renova" if effect_result["refreshed"] else "aplica"
			events.append("Esqueleto %s %s em %s (%d turnos próprios)." % [verb, effect["name"], target["name"], effect["duration"]])
	else:
		if str(enemy.get("special", "")) == "finta":
			enemy["goblin_last_target"] = target_id
			fighters[enemy_id] = enemy
		_deal_damage(enemy_id, target_id, int(enemy["damage"]), "physical", false, false)
	_check_purification()
	_after_action(enemy_id)
	if not finished and _is_alive(fighters[enemy_id]):
		_plan_enemy_intention(enemy_id)
	return true


func _plan_enemy_intention(enemy_id: String) -> void:
	var enemy: Dictionary = fighters.get(enemy_id, {})
	if enemy.is_empty() or not _is_alive(enemy):
		enemy_intentions.erase(enemy_id)
		return
	var living: Array[String] = []
	for hero_id in hero_ids:
		if _is_alive(fighters[hero_id]):
			living.append(hero_id)
	if living.is_empty():
		enemy_intentions.erase(enemy_id)
		return
	var kind := "attack"
	var name := "Ataque básico"
	var action_type := "Ataque"
	var description := "Causará %d de dano físico a um herói." % int(enemy["damage"])
	var special: String = str(enemy.get("special", ""))
	var target_id: String = living.pick_random()
	if special == "golpe_brutal":
		if bool(enemy.get("orc_heavy_ready", false)):
			kind = "orc_heavy"
			name = "Golpe Brutal"
			action_type = "Ataque preparado"
			description = "Causará 50% mais dano físico; Defender reduz o impacto."
			var locked_target: String = str(enemy.get("orc_heavy_target", ""))
			if locked_target in living:
				target_id = locked_target
		elif (int(enemy_action_counts.get(enemy_id, 0)) + 1) % 3 == 2:
			kind = "orc_prepare"
			name = "Preparar Golpe Brutal"
			action_type = "Preparação"
			description = "Não causa dano; o Orc atacará este alvo no próximo turno."
	elif special == "ritual" and (int(enemy_action_counts.get(enemy_id, 0)) + 1) % 3 == 1:
		var ally_id: String = _ritual_target(enemy_id)
		if ally_id != "":
			kind = "cultist_ritual"
			name = "Ritual Sombrio"
			action_type = "Fortalecimento"
			description = "Fortalece um aliado; o próximo ataque dele causará 20% mais dano."
			target_id = ally_id
	elif special == "finta":
		if bool(enemy.get("goblin_feint_ready", false)):
			kind = "goblin_strike"
			name = "Ataque de Finta"
			action_type = "Ataque preparado"
			description = "Causará 25% mais dano físico ao alvo marcado."
			var feint_target: String = str(enemy.get("goblin_feint_target", ""))
			if feint_target in living:
				target_id = feint_target
		elif (int(enemy_action_counts.get(enemy_id, 0)) + 1) % 3 == 2:
			kind = "goblin_feint"
			name = "Finta"
			action_type = "Preparação"
			description = "Não causa dano; o Goblin mudará de alvo e preparará um ataque mais forte." if living.size() > 1 else "Não causa dano; o Goblin prepara um ataque mais forte."
	elif special == "golpe_enfraquecedor" and (int(enemy_action_counts.get(enemy_id, 0)) + 1) % 2 == 0:
		kind = "weakened_strike"
		name = "Golpe Enfraquecedor"
		action_type = "Ataque e efeito"
		description = "Causará %d de dano e aplicará Fraqueza por 2 turnos." % int(enemy["damage"])
	elif special == "onda_sombria":
		if bool(enemy.get("impact_ready", false)):
			kind = "devastating_impact"
			name = "Impacto Devastador"
			action_type = "Ataque preparado"
			description = "Causará 50% mais dano físico a um herói."
		elif (int(enemy_action_counts.get(enemy_id, 0)) == 0 and enemy.get("boss_next_special", "prepare") != "onda") or enemy.get("boss_next_special", "prepare") == "basic":
			if bool(enemy.get("boss_phase_two", false)):
				kind = "spectral_strike"
				name = "Lâmina Espectral"
				action_type = "Ataque mágico"
				description = "Causará %d de dano mágico a um herói." % maxi(1, roundi(float(enemy["damage"]) * 0.8))
			else:
				kind = "attack"
				name = "Ataque básico"
				action_type = "Ataque"
				description = "Causará %d de dano físico a um herói." % int(enemy["damage"])
		elif enemy.get("boss_next_special", "prepare") == "onda":
			kind = "shadow_wave"
			name = "Onda Sombria"
			action_type = "Ataque em área"
			description = "Causará %d de dano mágico a todos os heróis vivos." % int(enemy.get("special_damage", 18))
		else:
			kind = "prepare_impact"
			name = "Preparar Impacto Devastador"
			action_type = "Preparação"
			description = "Não causa dano; o próximo turno executará um golpe com 50% mais dano."
	if kind == "shadow_wave":
		target_id = ""
	enemy_intentions[enemy_id] = {"id": kind, "name": name, "type": action_type, "description": description, "target_id": target_id}


func _ritual_target(cultist_id: String) -> String:
	for preferred_type in ["orc", "esqueleto", "goblin", "cultista"]:
		for ally_id in enemy_ids:
			if ally_id == cultist_id or not _is_alive(fighters[ally_id]):
				continue
			var ally: Dictionary = fighters[ally_id]
			if str(ally.get("enemy_type", "")) == preferred_type and float(ally.get("ritual_bonus", 0.0)) <= 0.0:
				return ally_id
	return cultist_id if _is_alive(fighters.get(cultist_id, {})) else ""


func _try_start_boss_second_phase(target_id: String) -> void:
	if target_id != "guardiao":
		return
	var boss: Dictionary = fighters.get(target_id, {})
	if boss.is_empty() or bool(boss.get("boss_phase_two", false)) or int(boss.get("hp", 0)) <= 0 or int(boss.get("hp", 0)) > 200:
		return
	boss["boss_phase_two"] = true
	if not bool(boss.get("impact_ready", false)):
		boss["boss_next_special"] = "onda"
	fighters[target_id] = boss
	events.append("O eclipse envolve Gueist. Sua lâmina passa a ferir com magia!")
	visual_events.append({"kind": "boss_phase", "target_id": target_id})
	_plan_enemy_intention(target_id)


func _deal_damage(attacker_id: String, target_id: String, base_amount: int, damage_type: String, basic: bool, spell: bool, skill_name: String = "", raw_multiplier: float = 1.0, resistance_ignore: float = 0.0) -> void:
	var attacker: Dictionary = fighters[attacker_id]
	var target: Dictionary = fighters[target_id]
	var target_was_wounded: bool = int(target["hp"]) < int(target["max_hp"])
	var critical_roll: float = randf()
	var bonus_multiplier: float = float(action_multiplier.get(attacker_id, 1.0)) if attacker.get("team", "") == "hero" and target.get("team", "") == "enemy" else 1.0
	if attacker.get("team", "") == "enemy" and float(attacker.get("ritual_bonus", 0.0)) > 0.0:
		bonus_multiplier *= 1.0 + float(attacker["ritual_bonus"])
		attacker["ritual_bonus"] = 0.0
		fighters[attacker_id] = attacker
	var packet: Dictionary = Rules.damage_packet(attacker, target, base_amount, damage_type, basic, spell, critical_roll, raw_multiplier * bonus_multiplier, resistance_ignore)
	var amount: int = int(packet["amount"])
	var effective_damage: int = mini(int(target["hp"]), amount)
	var guard_reduction: float = clampf(float(target.get("guard_reduction", 0.0)), 0.0, 1.0)
	if guard_reduction > 0.0:
		var original_amount: int = amount
		amount = maxi(1, roundi(float(amount) * (1.0 - guard_reduction)))
		target["guard_reduction"] = 0.0
		target["guard_source"] = ""
		target["guard_expires_on_source_turn"] = 0
		events.append("Guarda Protetora reduz %d de dano recebido por %s." % [original_amount - amount, target["name"]])
		effective_damage = mini(int(target["hp"]), amount)
	if target.get("team", "") == "hero":
		var reduction_factor := 1.0
		if bool(target.get("relic_march_protection", false)):
			reduction_factor *= 0.80
		if bool(target.get("relic_aurora_protection", false)):
			reduction_factor *= 0.70
			target["relic_aurora_protection"] = false
		if _has_relic("espelho_batalha", target_id) and not bool(relic_used.get("espelho_batalha:%s" % target_id, false)):
			reduction_factor *= 0.40
			relic_used["espelho_batalha:%s" % target_id] = true
		if reduction_factor < 1.0:
			amount = maxi(1, roundi(float(amount) * reduction_factor))
			effective_damage = mini(int(target["hp"]), amount)
	if spell and damage_type == "magical" and attacker.get("team", "") == "hero" and target.get("team", "") == "enemy" and not StateEffects.get_effect(attacker, "vampirismo").is_empty():
		pending_vamp_damage += effective_damage
	if attacker.get("team", "") == "hero":
		var cards: Dictionary = attacker.get("cards", {})
		var precision_level: int = int(cards.get("precisao", 0))
		if packet["critical"] and precision_level > 0 and critical_roll >= 0.05:
			events.append("Precisão %s ativa: %s consegue um acerto crítico." % [["I", "II", "III"][precision_level - 1], attacker["name"]])
		var predator_bonus: int = int(attacker.get("predator_bonus", 0))
		if attacker.get("id", "") == "patrulheiro" and target.get("team", "") == "enemy" and target_was_wounded and predator_bonus > 0:
			var predator_level: int = int(cards.get("predador", 0))
			events.append("Predador %s ativa contra o inimigo ferido (+%d dano base)." % [["I", "II", "III"][predator_level - 1], predator_bonus])
		if spell and damage_type == "magical":
			var elemental_level: int = int(cards.get("poder_elemental", 0))
			if elemental_level > 0:
				events.append("Poder Elemental %s aumenta o dano desta magia." % [["I", "II", "III"][elemental_level - 1]])
		var radiant_level: int = int(cards.get("bruxaria_luminosa", 0))
		if int(packet["radiant"]) > 0 and radiant_level > 0:
			events.append("Bruxaria Luminosa %s converte %d de dano em Radiante." % [["I", "II", "III"][radiant_level - 1], packet["radiant"]])
	target["hp"] = maxi(0, int(target["hp"]) - amount)
	if target["team"] == "hero" and int(target["hp"]) == 0 and _has_relic("relogio_renascimento", target_id) and not bool(relic_used.get("relogio_renascimento:%s" % target_id, false)):
		target["hp"] = maxi(1, ceili(float(target["max_hp"]) * 0.25))
		relic_used["relogio_renascimento:%s" % target_id] = true
		events.append("Relógio do Renascimento salva %s da queda." % target["name"])
	if packet["blocked"]:
		target["defending"] = false
	if int(target["hp"]) == 0:
		if target["team"] == "hero" and target["state"] == "alive":
			target["state"] = "downed"
			target["down_rounds"] = 3
			target["down_start_round"] = round_number
			events.append("%s caiu e pode ser reanimado por três rodadas completas." % target["name"])
		elif target["team"] == "enemy":
			target["state"] = "dead"
	fighters[target_id] = target
	if target["team"] == "hero" and target["state"] == "downed":
		_handle_hero_fall(target_id)
	if target["team"] == "hero":
		_check_aurora()
	if effective_damage > 0:
		var visual_type: String = Skills.visual_type_for_name(skill_name, damage_type)
		if int(packet["radiant"]) > 0:
			visual_type = "radiant"
		_record_damage(target_id, effective_damage, visual_type, bool(packet["critical"]))
	var action_text: String = "usa %s em" % skill_name if skill_name != "" else "ataca"
	var details: String = ""
	if packet["critical"]:
		details += " · crítico"
	if int(packet["radiant"]) > 0:
		details += " · Radiante"
	if packet["blocked"]:
		details += " · defendido"
	events.append("%s %s %s: %d dano %s%s." % [attacker["name"], action_text, target["name"], amount, damage_type, details])
	_try_start_boss_second_phase(target_id)
	if attacker.get("team", "") == "hero" and target.get("team", "") == "enemy" and effective_damage > 0:
		if action_echo_enabled and target_id == action_echo_target:
			action_echo_damage += effective_damage
		if _has_relic("taca_carmesim", attacker_id) and not StateEffects.get_effect(target, "veneno").is_empty():
			var healed_so_far: int = int(relic_counts.get("taca_carmesim:%s" % attacker_id, 0))
			var healed: int = mini(mini(12 - healed_so_far, roundi(float(effective_damage) * 0.15)), int(attacker["max_hp"]) - int(attacker["hp"]))
			if healed > 0:
				attacker["hp"] = int(attacker["hp"]) + healed
				fighters[attacker_id] = attacker
				relic_counts["taca_carmesim:%s" % attacker_id] = healed_so_far + healed
				_record_heal(attacker_id, healed)
				events.append("Taça Carmesim recupera %d PV." % healed)
		if _has_relic("lamina_tempestade", attacker_id) and int(relic_counts.get("lamina_uses:%s" % attacker_id, 0)) < 2:
			var hit_count: int = int(relic_counts.get("lamina_hits:%s" % attacker_id, 0)) + 1
			relic_counts["lamina_hits:%s" % attacker_id] = hit_count
			if hit_count % 3 == 0:
				for other_id in enemy_ids:
					if other_id != target_id and _is_alive(fighters[other_id]):
						relic_counts["lamina_uses:%s" % attacker_id] = int(relic_counts.get("lamina_uses:%s" % attacker_id, 0)) + 1
						_deal_fixed_damage(attacker_id, other_id, maxi(1, roundi(float(effective_damage) * 0.40)), "Lâmina da Tempestade")
						break
		if target["state"] == "dead" and _has_relic("mascara_executor", attacker_id) and not bool(relic_used.get("mascara_executor:%s" % attacker_id, false)):
			_arm_executor(attacker_id)
	if target.get("team", "") == "hero" and attacker.get("team", "") == "enemy" and damage_type == "physical" and effective_damage > 0 and _has_relic("coracao_espinhos", target_id) and not bool(relic_used.get("coracao_espinhos:%s" % target_id, false)):
		relic_used["coracao_espinhos:%s" % target_id] = true
		_deal_fixed_damage(target_id, attacker_id, maxi(1, roundi(float(effective_damage) * 0.20)), "Coração de Espinhos")
	if packet["blocked"] and target["team"] == "hero" and fighters[target_id]["state"] == "alive" and attacker["team"] == "enemy" and int(target.get("retaliation_damage", 0)) > 0 and int(fighters[attacker_id]["hp"]) > 0:
		attacker = fighters[attacker_id]
		var retaliation: int = int(target["retaliation_damage"])
		var counter_packet: Dictionary = Rules.damage_packet(target, attacker, retaliation, "physical", false, false, 1.0)
		var actual_counter_damage: int = mini(int(attacker["hp"]), int(counter_packet["amount"]))
		attacker["hp"] = maxi(0, int(attacker["hp"]) - int(counter_packet["amount"]))
		if int(attacker["hp"]) == 0:
			attacker["state"] = "dead"
		fighters[attacker_id] = attacker
		_record_damage(attacker_id, actual_counter_damage, "physical", bool(counter_packet["critical"]))
		var retaliation_level: int = int(target.get("cards", {}).get("retaliacao", 0))
		var retaliation_label: String = "Retaliação %s de %s" % [["I", "II", "III"][retaliation_level - 1], target["name"]] if retaliation_level > 0 else "Retaliação de %s" % target["name"]
		events.append("%s causa %d dano em %s." % [retaliation_label, counter_packet["amount"], attacker["name"]])
		_try_start_boss_second_phase(attacker_id)
	if int(target["hp"]) == 0 and target["team"] == "enemy":
		events.append("%s foi derrotado." % target["name"])


func _has_relic(relic_id: String, hero_id: String) -> bool:
	if not hero_id in hero_ids:
		return false
	for relic in relics:
		if str(relic.get("id", "")) != relic_id:
			continue
		if Relics.DEFINITIONS[relic_id].get("scope", "hero") == "team" or str(relic.get("bearer", "")) == hero_id:
			return true
	return false


func _prepare_offensive_action(actor_id: String, target_id: String) -> void:
	action_offensive_target = target_id
	var multiplier := 1.0
	var previous: Dictionary = offensive_history.get(actor_id, {})
	var streak: int = int(previous.get("count", 0)) + 1 if str(previous.get("target", "")) == target_id else 1
	if _has_relic("pacto_cacador", actor_id) and streak % 2 == 0:
		multiplier += 0.20
		events.append("Pacto do Caçador fortalece o segundo ataque.")
	if bool(relic_used.get("mascara_armed:%s" % actor_id, false)):
		multiplier += 0.40
		relic_used["mascara_armed:%s" % actor_id] = false
		events.append("Máscara do Executor fortalece este ataque.")
	if bool(relic_used.get("ashes_boost:%s" % actor_id, false)):
		multiplier += 0.30
		relic_used["ashes_boost:%s" % actor_id] = false
		events.append("Vínculo das Cinzas fortalece este ataque.")
	action_multiplier[actor_id] = multiplier
	offensive_history[actor_id] = {"target": target_id, "count": streak}


func _enhance_poison(actor_id: String, target_id: String, effect_id: String) -> void:
	if effect_id != "veneno" or not fighters.has(target_id):
		return
	var target: Dictionary = fighters[target_id]
	var effects: Dictionary = target.get("state_effects", {})
	if effects.has("veneno"):
		effects["veneno"]["intensity"] = int(StateEffects.DEFINITIONS["veneno"]["intensity"]) + int(fighters[actor_id].get("poison_relic_bonus", 0))
		effects["veneno"]["source_id"] = actor_id
		target["state_effects"] = effects
		fighters[target_id] = target


func _maybe_mercy_bell(actor_id: String, target_id: String, before_hp: int, healed: int) -> void:
	if healed <= 0 or not _has_relic("sino_misericordia", actor_id) or bool(relic_used.get("sino_misericordia:%s" % actor_id, false)):
		return
	var target: Dictionary = fighters[target_id]
	if float(before_hp) >= float(target["max_hp"]) * 0.35:
		return
	for effect_id in ["veneno", "fraqueza"]:
		var removed: Dictionary = StateEffects.remove(target, effect_id)
		if not removed.is_empty():
			fighters[target_id] = target
			relic_used["sino_misericordia:%s" % actor_id] = true
			events.append("Sino da Misericórdia remove %s de %s." % [removed["name"], target["name"]])
			return


func _deal_fixed_damage(attacker_id: String, target_id: String, amount: int, source_name: String) -> void:
	if not fighters.has(target_id) or not _is_alive(fighters[target_id]):
		return
	var target: Dictionary = fighters[target_id]
	var actual := mini(int(target["hp"]), maxi(1, amount))
	target["hp"] = int(target["hp"]) - actual
	if int(target["hp"]) == 0:
		target["state"] = "dead" if target["team"] == "enemy" else "downed"
	fighters[target_id] = target
	_record_damage(target_id, actual, "magical" if source_name == "Lâmina da Tempestade" else "physical", false)
	events.append("%s causa %d de dano em %s." % [source_name, actual, target["name"]])
	_try_start_boss_second_phase(target_id)
	if target["state"] == "downed":
		_handle_hero_fall(target_id)
	elif target["state"] == "dead" and target["team"] == "enemy":
		_arm_executor(attacker_id)


func _arm_executor(attacker_id: String) -> void:
	if not _has_relic("mascara_executor", attacker_id) or bool(relic_used.get("mascara_executor:%s" % attacker_id, false)):
		return
	relic_used["mascara_executor:%s" % attacker_id] = true
	relic_used["mascara_armed:%s" % attacker_id] = true
	events.append("Máscara do Executor prepara o próximo ataque de alvo único.")


func _handle_hero_fall(hero_id: String) -> void:
	if _has_relic("vinculo_cinzas", hero_id) and not bool(relic_used.get("vinculo_cinzas", false)):
		relic_used["vinculo_cinzas"] = true
		for ally_id in hero_ids:
			if ally_id == hero_id or not _is_alive(fighters[ally_id]):
				continue
			var ally: Dictionary = fighters[ally_id]
			ally["mana"] = mini(int(ally.get("mana_max", 0)), int(ally.get("mana", 0)) + 4)
			fighters[ally_id] = ally
			relic_used["ashes_boost:%s" % ally_id] = true
		events.append("Vínculo das Cinzas fortalece os sobreviventes.")
	if _has_relic("chama_retornados", hero_id) and not bool(relic_used.get("chama_retornados", false)):
		relic_used["chama_retornados"] = true
		_revive(hero_id, 0.25)
		events.append("Chama dos Retornados reanima %s." % fighters[hero_id]["name"])


func _check_aurora() -> void:
	if hero_ids.is_empty() or not _has_relic("juramento_aurora", hero_ids[0]) or bool(relic_used.get("juramento_aurora", false)):
		return
	var total_hp := 0
	var total_max := 0
	for hero_id in hero_ids:
		var hero: Dictionary = fighters[hero_id]
		total_hp += int(hero["hp"])
		total_max += int(hero["max_hp"])
	if total_max <= 0 or float(total_hp) >= float(total_max) * 0.40:
		return
	relic_used["juramento_aurora"] = true
	for hero_id in hero_ids:
		if not _is_alive(fighters[hero_id]):
			continue
		var hero: Dictionary = fighters[hero_id]
		hero["mana"] = mini(int(hero.get("mana_max", 0)), int(hero.get("mana", 0)) + 4)
		hero["relic_aurora_protection"] = true
		fighters[hero_id] = hero
	events.append("Juramento da Aurora protege os sobreviventes.")


func _check_purification() -> void:
	if hero_ids.is_empty() or not _has_relic("circulo_purificacao", hero_ids[0]) or bool(relic_used.get("circulo_purificacao", false)):
		return
	var affected: Array[String] = []
	for hero_id in hero_ids:
		if not _is_alive(fighters[hero_id]):
			continue
		if not StateEffects.get_effect(fighters[hero_id], "veneno").is_empty() or not StateEffects.get_effect(fighters[hero_id], "fraqueza").is_empty():
			affected.append(hero_id)
	if affected.size() < 2:
		return
	relic_used["circulo_purificacao"] = true
	for hero_id in affected:
		var hero: Dictionary = fighters[hero_id]
		if StateEffects.remove(hero, "veneno").is_empty():
			StateEffects.remove(hero, "fraqueza")
		fighters[hero_id] = hero
	events.append("Círculo da Purificação remove um efeito de cada aliado afetado.")


func _revive(hero_id: String, fraction: float = 0.25) -> void:
	var hero: Dictionary = fighters[hero_id]
	var previous_hp: int = int(hero["hp"])
	hero["state"] = "alive"
	hero["hp"] = mini(int(hero["max_hp"]), maxi(1, ceili(float(hero["max_hp"]) * fraction)))
	hero["down_rounds"] = 0
	hero["down_start_round"] = 0
	hero["defending"] = false
	fighters[hero_id] = hero
	_record_heal(hero_id, int(hero["hp"]) - previous_hp)


func _after_action(actor_id: String) -> void:
	var actor: Dictionary = fighters[actor_id]
	if actor.get("team", "") == "hero":
		var cooldowns: Dictionary = actor.get("skill_cooldowns", {}).duplicate(true)
		var cooldowns_started: Dictionary = actor.get("skill_cooldowns_just_started", {}).duplicate(true)
		for skill_id in cooldowns:
			if cooldowns_started.get(skill_id, false):
				cooldowns_started.erase(skill_id)
			elif int(cooldowns[skill_id]) > 0:
				cooldowns[skill_id] = int(cooldowns[skill_id]) - 1
		actor["skill_cooldowns"] = cooldowns
		actor["skill_cooldowns_just_started"] = cooldowns_started
		actor["cooldown_remaining"] = int(cooldowns.get(str(actor.get("skill", "")), 0))
		actor["cooldown_just_started"] = false
	fighters[actor_id] = actor
	_consume_effect_turn(actor_id)
	if _check_result():
		return
	if _advance_to_next_living():
		_begin_current_turn()


func _begin_current_turn() -> void:
	while not finished:
		var actor_id: String = current_id()
		if actor_id.is_empty():
			return
		var actor: Dictionary = fighters[actor_id]
		if not _is_alive(actor):
			if not _advance_to_next_living():
				return
			continue
		hero_turn_counts[actor_id] = int(hero_turn_counts.get(actor_id, 0)) + 1
		if actor.get("team", "") == "hero":
			relic_counts["taca_carmesim:%s" % actor_id] = 0
			relic_used["coracao_espinhos:%s" % actor_id] = false
		_expire_guard_from_source(actor_id)
		if actor.get("team", "") == "hero" and int(actor.get("mana_max", 0)) > 0:
			var mana_points: int = int(actor.get("permanent_attributes", {}).get("mana", 0))
			var mana_before: int = int(actor.get("mana", 0))
			var mana_after: int = mini(int(actor["mana_max"]), mana_before + Progression.mana_regen_per_turn(mana_points))
			var mana_recovered: int = mana_after - mana_before
			if mana_recovered > 0:
				actor["mana"] = mana_after
				fighters[actor_id] = actor
				events.append("%s recupera %d mana no início do turno." % [actor["name"], mana_recovered])
		var poison: Dictionary = StateEffects.get_effect(actor, "veneno")
		if poison.is_empty():
			return
		_apply_poison_damage(actor_id, int(poison.get("intensity", 8)))
		if not _is_alive(fighters[actor_id]):
			_consume_effect_turn(actor_id)
			if _check_result():
				return
			if not _advance_to_next_living():
				return
			continue
		return


func _expire_guard_from_source(source_id: String) -> void:
	for hero_id in hero_ids:
		var target: Dictionary = fighters[hero_id]
		if target.get("guard_source", "") != source_id:
			continue
		if int(target.get("guard_expires_on_source_turn", 0)) > int(hero_turn_counts.get(source_id, 0)):
			continue
		target["guard_reduction"] = 0.0
		target["guard_source"] = ""
		target["guard_expires_on_source_turn"] = 0
		fighters[hero_id] = target
		events.append("Guarda Protetora em %s expirou no início do turno do Guerreiro." % target["name"])


func _advance_to_next_living() -> bool:
	for _step in range(order.size()):
		index += 1
		if index >= order.size():
			index = 0
			round_number += 1
			_tick_downed()
			if _check_result():
				return false
		if _is_alive(fighters[order[index]]):
			return true
	return _check_result()


func _consume_effect_turn(fighter_id: String) -> void:
	var fighter: Dictionary = fighters[fighter_id]
	for effect in StateEffects.get_all(fighter):
		if effect.get("skip_turn", false):
			fighter["state_effects"][effect["id"]]["skip_turn"] = false
			continue
		var expired: Dictionary = StateEffects.update(fighter, str(effect["id"]))
		if not expired.is_empty():
			events.append("%s em %s expirou." % [expired["name"], fighter["name"]])
	fighters[fighter_id] = fighter


func _apply_poison_damage(target_id: String, amount: int) -> void:
	var target: Dictionary = fighters[target_id]
	var poison_source: String = str(StateEffects.get_effect(target, "veneno").get("source_id", ""))
	var actual_damage: int = mini(int(target["hp"]), amount)
	target["hp"] = maxi(0, int(target["hp"]) - amount)
	if target["team"] == "hero" and int(target["hp"]) == 0 and _has_relic("relogio_renascimento", target_id) and not bool(relic_used.get("relogio_renascimento:%s" % target_id, false)):
		target["hp"] = maxi(1, ceili(float(target["max_hp"]) * 0.25))
		relic_used["relogio_renascimento:%s" % target_id] = true
		events.append("Relógio do Renascimento salva %s do Veneno." % target["name"])
	if int(target["hp"]) == 0:
		if target["team"] == "hero" and target["state"] == "alive":
			target["state"] = "downed"
			target["down_rounds"] = 3
			target["down_start_round"] = round_number
			events.append("%s caiu por Veneno e pode ser reanimado por três rodadas completas." % target["name"])
		elif target["team"] == "enemy":
			target["state"] = "dead"
	fighters[target_id] = target
	if target["team"] == "hero" and target["state"] == "downed":
		_handle_hero_fall(target_id)
	if target["team"] == "hero":
		_check_aurora()
	_record_damage(target_id, actual_damage, "poison", false)
	events.append("Veneno causa %d de dano em %s no início do turno." % [amount, target["name"]])
	_try_start_boss_second_phase(target_id)
	if int(target["hp"]) == 0 and target["team"] == "enemy":
		if not poison_source.is_empty():
			_arm_executor(poison_source)
		events.append("%s foi derrotado por Veneno." % target["name"])


func _record_damage(target_id: String, amount: int, visual_type: String, critical: bool) -> void:
	if amount > 0:
		visual_events.append({"kind": "damage", "target_id": target_id, "amount": amount, "visual_type": visual_type, "critical": critical})


func _record_heal(target_id: String, amount: int) -> void:
	if amount > 0:
		visual_events.append({"kind": "heal", "target_id": target_id, "amount": amount})


func _tick_downed() -> void:
	for hero_id in hero_ids:
		var hero: Dictionary = fighters[hero_id]
		if hero["state"] != "downed" or round_number < int(hero["down_start_round"]) + 2:
			continue
		hero["down_rounds"] = int(hero["down_rounds"]) - 1
		if int(hero["down_rounds"]) <= 0:
			hero["state"] = "dead"
			hero["down_rounds"] = 0
			events.append("%s morreu antes de receber socorro." % hero["name"])
		fighters[hero_id] = hero


func _check_result() -> bool:
	var heroes_alive: int = 0
	var enemies_alive: int = 0
	for hero_id in hero_ids:
		if _is_alive(fighters[hero_id]):
			heroes_alive += 1
	for enemy_id in enemy_ids:
		if _is_alive(fighters[enemy_id]):
			enemies_alive += 1
	if enemies_alive == 0:
		finished = true
		outcome = "victory"
		for hero_id in hero_ids:
			var hero: Dictionary = fighters[hero_id]
			if hero["state"] == "downed":
				hero["state"] = "alive"
				hero["hp"] = 1
				hero["down_rounds"] = 0
				fighters[hero_id] = hero
				events.append("%s sobreviveu ao combate com 1 PV." % hero["name"])
		_clear_all_effects()
		return true
	if heroes_alive == 0:
		finished = true
		outcome = "defeat"
		_clear_all_effects()
		return true
	return false


func _clear_all_effects() -> void:
	for fighter_id in fighters:
		var fighter: Dictionary = fighters[fighter_id]
		StateEffects.clear(fighter)
		fighters[fighter_id] = fighter


func _is_alive(fighter: Dictionary) -> bool:
	return fighter.get("state", "alive") == "alive" and int(fighter.get("hp", 0)) > 0


func hero_states() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero_id in hero_ids:
		result.append(fighters[hero_id].duplicate(true))
	return result
