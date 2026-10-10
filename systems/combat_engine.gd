extends RefCounted

const Skills = preload("res://data/skills.gd")
const Heroes = preload("res://data/heroes.gd")
const Rules = preload("res://systems/combat_rules.gd")
const StateEffects = preload("res://systems/state_effects.gd")
const Progression = preload("res://systems/permanent_progression.gd")

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


func start(heroes: Array, enemies: Array) -> void:
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
		fighters[hero["id"]] = hero
		hero_ids.append(hero["id"])
		hero_turn_counts[hero["id"]] = 0
		order.append(hero["id"])
	for source in enemies:
		var enemy: Dictionary = source.duplicate(true)
		enemy["defending"] = false
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
			fighters[enemy_id] = enemy
			_plan_enemy_intention(enemy_id)
	if not _check_result():
		_begin_current_turn()


func current_id() -> String:
	return order[index] if not order.is_empty() else ""


func current() -> Dictionary:
	return fighters.get(current_id(), {})


func intention_for(enemy_id: String) -> Dictionary:
	return enemy_intentions.get(enemy_id, {}).duplicate(true)


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
	if action == "defend":
		actor["defending"] = true
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
		var cost: int = int(skill.get("mana", 0))
		actor["mana"] = int(actor.get("mana", 0)) - cost
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
				var healed: int = mini(Rules.heal_amount(actor, int(skill["amount"])), int(ally["max_hp"]) - int(ally["hp"]))
				ally["hp"] = int(ally["hp"]) + healed
				fighters[ally_id] = ally
				_record_heal(ally_id, healed)
				events.append("%s usa Prece Restauradora: %s recupera %d PV." % [actor["name"], ally["name"], healed])
		elif skill["kind"] == "miracle":
			var ally: Dictionary = fighters[target_id]
			if ally["state"] == "downed":
				_revive(target_id, 0.45)
				ally = fighters[target_id]
				events.append("%s usa Milagre Divino e reanima %s com %d PV." % [actor["name"], ally["name"], ally["hp"]])
			else:
				var healed: int = mini(Rules.heal_amount(actor, int(skill["amount"])), int(ally["max_hp"]) - int(ally["hp"]))
				ally["hp"] = int(ally["hp"]) + healed
				_record_heal(target_id, healed)
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
				var missing_hp: int = int(target["max_hp"]) - int(target["hp"])
				var amount: int = mini(Rules.heal_amount(actor, int(skill["amount"])), missing_hp)
				target["hp"] = int(target["hp"]) + amount
				fighters[target_id] = target
				_record_heal(target_id, amount)
				events.append("%s usa Cura em %s e recupera %d PV." % [actor["name"], target["name"], amount])
				var card_level: int = int(actor.get("cards", {}).get("graca_divina", 0))
				var extra_healing: int = amount - mini(int(skill["amount"]), missing_hp)
				if card_level > 0 and extra_healing > 0:
					events.append("Graça Divina %s acrescenta %d PV à cura." % [["I", "II", "III"][card_level - 1], extra_healing])
		elif skill["kind"] == "purify":
			var target: Dictionary = fighters[target_id]
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
			var effect: Dictionary = result["effect"]
			fighters[target_id] = target
			var verb: String = "renova" if result["refreshed"] else "aplica"
			events.append("%s %s %s em %s (%d turnos próprios)." % [actor["name"], verb, effect["name"], target["name"], effect["duration"]])
		elif skill["kind"] == "status_all":
			for enemy_id in enemy_ids:
				if not _is_alive(fighters[enemy_id]):
					continue
				var result: Dictionary = StateEffects.apply(fighters[enemy_id], str(skill["effect"]))
				var verb: String = "renova" if result["refreshed"] else "aplica"
				events.append("%s %s Fraqueza em %s por 2 turnos próprios." % [actor["name"], verb, fighters[enemy_id]["name"]])
		elif skill["kind"] == "damage_status":
			_deal_damage(actor_id, target_id, int(skill["amount"]), skill["damage_type"], false, false, skill["name"])
			if _is_alive(fighters[target_id]):
				var result: Dictionary = StateEffects.apply(fighters[target_id], str(skill.get("effect", "")))
				if not result.is_empty():
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
	if pending_vamp_damage > 0 and _is_alive(fighters[actor_id]):
		var vamp_actor: Dictionary = fighters[actor_id]
		var healed: int = mini(int(vamp_actor["max_hp"]) - int(vamp_actor["hp"]), roundi(float(pending_vamp_damage) * 0.30))
		if healed > 0:
			vamp_actor["hp"] = int(vamp_actor["hp"]) + healed
			fighters[actor_id] = vamp_actor
			_record_heal(actor_id, healed)
			events.append("Vampirismo Mágico recupera %d PV para %s." % [healed, vamp_actor["name"]])
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
	var target_id: String = str(intention.get("target_id", ""))
	if not target_id in living:
		target_id = living.pick_random()
		intention["target_id"] = target_id
		enemy_intentions[enemy_id] = intention
	var action_kind: String = str(intention.get("id", "attack"))
	enemy_action_counts[enemy_id] = int(enemy_action_counts.get(enemy_id, 0)) + 1
	if action_kind == "prepare_impact":
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
			_deal_damage(enemy_id, hero_id, 18, "magical", false, true, "Onda Sombria")
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
		_deal_damage(enemy_id, target_id, int(enemy["damage"]), "physical", false, false)
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
	if special == "golpe_enfraquecedor" and (int(enemy_action_counts.get(enemy_id, 0)) + 1) % 2 == 0:
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
		elif int(enemy_action_counts.get(enemy_id, 0)) == 0 or enemy.get("boss_next_special", "prepare") == "basic":
			kind = "attack"
			name = "Ataque básico"
			action_type = "Ataque"
			description = "Causará %d de dano físico a um herói." % int(enemy["damage"])
		elif enemy.get("boss_next_special", "prepare") == "onda":
			kind = "shadow_wave"
			name = "Onda Sombria"
			action_type = "Ataque em área"
			description = "Causará 18 de dano mágico a todos os heróis vivos."
		else:
			kind = "prepare_impact"
			name = "Preparar Impacto Devastador"
			action_type = "Preparação"
			description = "Não causa dano; o próximo turno executará um golpe com 50% mais dano."
	var target_id: String = living.pick_random()
	if kind == "shadow_wave":
		target_id = ""
	enemy_intentions[enemy_id] = {"id": kind, "name": name, "type": action_type, "description": description, "target_id": target_id}


func _deal_damage(attacker_id: String, target_id: String, base_amount: int, damage_type: String, basic: bool, spell: bool, skill_name: String = "", raw_multiplier: float = 1.0, resistance_ignore: float = 0.0) -> void:
	var attacker: Dictionary = fighters[attacker_id]
	var target: Dictionary = fighters[target_id]
	var target_was_wounded: bool = int(target["hp"]) < int(target["max_hp"])
	var critical_roll: float = randf()
	var packet: Dictionary = Rules.damage_packet(attacker, target, base_amount, damage_type, basic, spell, critical_roll, raw_multiplier, resistance_ignore)
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
	if packet["blocked"] and target["team"] == "hero" and target["state"] == "alive" and attacker["team"] == "enemy" and int(target.get("retaliation_damage", 0)) > 0 and int(attacker["hp"]) > 0:
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
	if int(target["hp"]) == 0 and target["team"] == "enemy":
		events.append("%s foi derrotado." % target["name"])


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
	var actual_damage: int = mini(int(target["hp"]), amount)
	target["hp"] = maxi(0, int(target["hp"]) - amount)
	if int(target["hp"]) == 0:
		if target["team"] == "hero" and target["state"] == "alive":
			target["state"] = "downed"
			target["down_rounds"] = 3
			target["down_start_round"] = round_number
			events.append("%s caiu por Veneno e pode ser reanimado por três rodadas completas." % target["name"])
		elif target["team"] == "enemy":
			target["state"] = "dead"
	fighters[target_id] = target
	_record_damage(target_id, actual_damage, "poison", false)
	events.append("Veneno causa %d de dano em %s no início do turno." % [amount, target["name"]])
	if int(target["hp"]) == 0 and target["team"] == "enemy":
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
