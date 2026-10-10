extends RefCounted

const DEFINITIONS := {
	"veneno": {
		"id": "veneno",
		"name": "Veneno",
		"duration": 3,
		"intensity": 8,
		"description": "No início do próprio turno, causa 8 de dano fixo. Dura 3 turnos próprios.",
	},
	"fraqueza": {
		"id": "fraqueza",
		"name": "Fraqueza",
		"duration": 2,
		"intensity": 0.25,
		"description": "Reduz em 25% o dano causado. Dura 2 turnos próprios.",
	},
	"fortaleza": {"id": "fortaleza", "name": "Fortaleza Inabalável", "duration": 2, "intensity": 0.35, "description": "Reduz em 35% o dano físico e mágico recebido, multiplicativamente, até o fim dos próximos 2 turnos próprios."},
	"instinto": {"id": "instinto", "name": "Instinto Predador", "duration": 2, "intensity": 0.25, "description": "+25 pontos percentuais de chance crítica até o fim dos próximos 2 turnos próprios."},
	"vampirismo": {"id": "vampirismo", "name": "Vampirismo Mágico", "duration": 2, "intensity": 0.30, "description": "Recupera 30% do dano direto efetivo de magias contra inimigos até o fim dos próximos 2 turnos próprios."},
}


static func definition(effect_id: String) -> Dictionary:
	return DEFINITIONS.get(effect_id, {}).duplicate(true)


static func apply(fighter: Dictionary, effect_id: String) -> Dictionary:
	var template: Dictionary = definition(effect_id)
	if template.is_empty():
		return {}
	var effects: Dictionary = fighter.get("state_effects", {}).duplicate(true)
	var refreshed: bool = effects.has(effect_id)
	var intensity: Variant = template["intensity"]
	if refreshed:
		intensity = effects[effect_id].get("intensity", intensity)
	var active := {
		"id": effect_id,
		"name": template["name"],
		"duration": int(template["duration"]),
		"intensity": intensity,
		"description": template["description"],
	}
	effects[effect_id] = active
	fighter["state_effects"] = effects
	return {"effect": active.duplicate(true), "refreshed": refreshed}


static func update(fighter: Dictionary, effect_id: String, turns: int = 1) -> Dictionary:
	var effects: Dictionary = fighter.get("state_effects", {}).duplicate(true)
	if not effects.has(effect_id):
		return {}
	var active: Dictionary = effects[effect_id]
	active["duration"] = maxi(0, int(active.get("duration", 0)) - maxi(0, turns))
	if int(active["duration"]) == 0:
		effects.erase(effect_id)
		fighter["state_effects"] = effects
		return active
	effects[effect_id] = active
	fighter["state_effects"] = effects
	return {}


static func get_effect(fighter: Dictionary, effect_id: String) -> Dictionary:
	return fighter.get("state_effects", {}).get(effect_id, {}).duplicate(true)


static func get_all(fighter: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect_id in fighter.get("state_effects", {}):
		var active: Dictionary = get_effect(fighter, effect_id)
		if not active.is_empty():
			result.append(active)
	return result


static func remove(fighter: Dictionary, effect_id: String) -> Dictionary:
	var effects: Dictionary = fighter.get("state_effects", {}).duplicate(true)
	var removed: Dictionary = effects.get(effect_id, {}).duplicate(true)
	effects.erase(effect_id)
	fighter["state_effects"] = effects
	return removed


static func clear(fighter: Dictionary) -> void:
	fighter["state_effects"] = {}
