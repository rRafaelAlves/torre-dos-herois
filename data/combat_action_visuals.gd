extends RefCounted

const Skills = preload("res://data/skills.gd")


static func hero_action(actor_id: String, action: String, target_id: String, available_targets: Array[String]) -> Dictionary:
	var result := {"actor_id": actor_id, "action_id": action, "targets": [], "style": "guard", "hits": 1, "area": false, "status": false}
	if action == "defend":
		result["targets"] = [actor_id]
		return result
	if action == "rescue":
		result["style"] = "sacred"
		result["targets"] = [target_id]
		return result
	if action == "attack":
		result["style"] = _basic_style(actor_id)
		result["targets"] = [target_id]
		return result
	var skill_id: String = action.trim_prefix("skill:")
	var skill: Dictionary = Skills.get_definition(skill_id)
	if skill.is_empty():
		return result
	var kind: String = str(skill.get("kind", ""))
	var target_type: String = str(skill.get("target", ""))
	result["targets"] = available_targets.duplicate() if target_type in ["all_enemies", "all_allies"] else ([actor_id] if target_type == "self" else [target_id])
	result["area"] = target_type in ["all_enemies", "all_allies"]
	result["hits"] = int(skill.get("hits", 1))
	result["status"] = kind in ["status", "status_all", "damage_status"]
	if kind in ["heal", "heal_all", "purify", "miracle", "guard"]:
		result["style"] = "sacred" if actor_id == "sacerdotisa" else "guard"
	elif kind == "self_buff":
		result["style"] = "curse" if actor_id == "bruxa" else "guard"
	elif kind in ["status", "status_all"]:
		result["style"] = "curse"
	elif str(skill.get("visual_type", "")) == "fire":
		result["style"] = "fire"
	else:
		result["style"] = _basic_style(actor_id)
	result["powerful"] = skill_id in ["golpe_poderoso", "golpe_carrasco"]
	return result


static func enemy_action(actor_id: String, intention: Dictionary, living_heroes: Array[String]) -> Dictionary:
	var kind: String = str(intention.get("id", "attack"))
	var result := {"actor_id": actor_id, "action_id": kind, "targets": [], "style": "melee", "hits": 1, "area": kind == "shadow_wave", "status": false, "powerful": kind == "devastating_impact"}
	if kind == "prepare_impact":
		result["style"] = "guard"
		result["targets"] = [actor_id]
	elif kind == "shadow_wave":
		result["style"] = "curse"
		result["targets"] = living_heroes.duplicate()
	else:
		result["targets"] = [str(intention.get("target_id", ""))]
	return result


static func _basic_style(actor_id: String) -> String:
	match actor_id:
		"patrulheiro": return "arrow"
		"bruxa": return "curse"
		"feiticeiro": return "arcane"
		_: return "melee"
