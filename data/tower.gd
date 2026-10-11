extends RefCounted

const Enemies = preload("res://data/enemies.gd")

const MAX_FLOOR := 10
const REGULAR_ENEMY_HP_MULTIPLIER := 1.08
const REGULAR_ENEMY_DAMAGE_MULTIPLIER := 0.9
const GUEIST_HP_BONUS := 250
const GUEIST_DAMAGE_MULTIPLIER := 1.3
const ENEMY_FLOOR_BONUSES := {
	3: {"hp": 20, "damage": 4},
	4: {"hp": 27, "damage": 5},
	5: {"hp": 34, "damage": 6},
	6: {"hp": 41, "damage": 7},
	7: {"hp": 48, "damage": 8},
	8: {"hp": 55, "damage": 9},
	9: {"hp": 62, "damage": 10},
	10: {"hp": 80, "damage": 6},
}
const ENCOUNTERS := {
	1: ["goblin", "goblin"],
	2: ["goblin", "esqueleto"],
	3: ["goblin", "goblin", "esqueleto"],
	4: ["orc", "goblin", "esqueleto"],
	5: ["orc", "esqueleto", "cultista"],
	6: ["orc", "orc", "goblin"],
	7: ["cultista", "cultista", "esqueleto"],
	8: ["orc", "cultista", "cultista"],
	9: ["orc", "orc", "cultista"],
	10: ["guardiao"],
}
const ROUTES := {
	1: [
		{"id": "fortaleza", "name": "Fortaleza", "description": "Goblin e Esqueleto: +25 PV máximos, dano original.", "hp": 25},
		{"id": "arena_sangrenta", "name": "Arena Sangrenta", "description": "Goblin e Esqueleto: PV originais, +6 dano.", "damage": 6},
	],
	4: [
		{"id": "muralha", "name": "Muralha de Ferro", "description": "+15 p.p. resistência física, -2 dano.", "physical_resist": 0.15, "damage": -2},
		{"id": "emboscada", "name": "Emboscada", "description": "+4 iniciativa, -10 PV máximos.", "initiative": 4, "hp": -10},
	],
	7: [
		{"id": "escudo_arcano", "name": "Escudo Arcano", "description": "+15 p.p. resistência mágica, -2 dano.", "magical_resist": 0.15, "damage": -2},
		{"id": "furia", "name": "Fúria", "description": "+7 dano, -15 PV máximos.", "damage": 7, "hp": -15},
	],
}


static func route_after(floor_number: int) -> Array:
	return ROUTES.get(floor_number, []).duplicate(true)


static func route_by_id(route_id: String) -> Dictionary:
	for floor_number in ROUTES:
		for route in ROUTES[floor_number]:
			if route["id"] == route_id:
				return route.duplicate(true)
	return {}


static func enemies_for(floor_number: int, route_id: String, _party_size: int) -> Array[Dictionary]:
	var enemy_types: Array = ENCOUNTERS.get(floor_number, [])
	var type_totals: Dictionary = {}
	for enemy_type in enemy_types:
		type_totals[enemy_type] = int(type_totals.get(enemy_type, 0)) + 1
	var type_instances: Dictionary = {}
	var result: Array[Dictionary] = []
	var route: Dictionary = route_by_id(route_id)
	for enemy_type in enemy_types:
		var type_id: String = str(enemy_type)
		var instance_number: int = int(type_instances.get(type_id, 0)) + 1
		type_instances[type_id] = instance_number
		var enemy: Dictionary = Enemies.get_definition(type_id)
		enemy["id"] = "%s_%d" % [type_id, instance_number] if int(type_totals[type_id]) > 1 else type_id
		enemy["enemy_type"] = type_id
		enemy["team"] = "enemy"
		var floor_bonus: Dictionary = ENEMY_FLOOR_BONUSES.get(floor_number, {})
		enemy["max_hp"] += int(floor_bonus.get("hp", 0)) + int(route.get("hp", 0))
		enemy["damage"] += int(floor_bonus.get("damage", 0)) + int(route.get("damage", 0))
		if type_id == "guardiao":
			enemy["max_hp"] += GUEIST_HP_BONUS
			enemy["damage"] = maxi(1, roundi(float(enemy["damage"]) * GUEIST_DAMAGE_MULTIPLIER))
			if enemy.has("special_damage"):
				enemy["special_damage"] = maxi(1, roundi(float(enemy["special_damage"]) * GUEIST_DAMAGE_MULTIPLIER))
		else:
			enemy["max_hp"] = maxi(1, roundi(float(enemy["max_hp"]) * REGULAR_ENEMY_HP_MULTIPLIER))
			enemy["damage"] = maxi(1, roundi(float(enemy["damage"]) * REGULAR_ENEMY_DAMAGE_MULTIPLIER))
		enemy["initiative"] += int(route.get("initiative", 0))
		enemy["physical_resist"] = clampf(float(enemy.get("physical_resist", 0.0)) + float(route.get("physical_resist", 0.0)), 0.0, 0.75)
		enemy["magical_resist"] = clampf(float(enemy.get("magical_resist", 0.0)) + float(route.get("magical_resist", 0.0)), 0.0, 0.75)
		enemy["hp"] = enemy["max_hp"]
		enemy["state"] = "alive"
		result.append(enemy)
	if not result.is_empty():
		var xp_per_enemy: int = floori(100.0 / float(result.size()))
		var xp_remainder: int = 100 - xp_per_enemy * result.size()
		var coins_per_enemy: int = floori(10.0 / float(result.size()))
		var coins_remainder: int = 10 - coins_per_enemy * result.size()
		for enemy_index in result.size():
			result[enemy_index]["xp_reward"] = xp_per_enemy + (1 if enemy_index < xp_remainder else 0)
			result[enemy_index]["coin_reward"] = coins_per_enemy + (1 if enemy_index < coins_remainder else 0)
	return result
