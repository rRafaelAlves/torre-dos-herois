extends RefCounted

const Heroes = preload("res://data/heroes.gd")
const Skills = preload("res://data/skills.gd")

const MAX_LEVEL := 20
const ATTRIBUTE_LIMIT := 5
const MANA_REGEN_BASE := 2
const MANA_REGEN_POINTS_PER_STEP := 2
const ORDER := ["vitalidade", "poder", "agilidade", "resistencia", "mana"]
const DEFINITIONS := {
	"vitalidade": {"name": "Vitalidade", "per_point": "+7 PV máximos"},
	"poder": {"name": "Poder", "per_point": "+3 dano no ataque básico"},
	"agilidade": {"name": "Agilidade", "per_point": "+1 iniciativa"},
	"resistencia": {"name": "Resistência", "per_point": "+2 p.p. resistência física e mágica"},
	"mana": {"name": "Mana", "per_point": "+3 mana máxima · a cada 2 pontos, +1 mana recuperada por turno", "requires_mana": true},
}


static func xp_required(level: int) -> int:
	return 0 if level >= MAX_LEVEL else 100 + 20 * (maxi(1, level) - 1)


static func empty_attributes() -> Dictionary:
	var result: Dictionary = {}
	for attribute_id in ORDER:
		result[attribute_id] = 0
	return result


static func uses_mana(hero_id: String) -> bool:
	return int(Heroes.DEFINITIONS.get(hero_id, {}).get("mana_max", 0)) > 0


static func sanitized_attributes(raw: Dictionary, hero_id: String, point_budget: int = 19) -> Dictionary:
	var result: Dictionary = empty_attributes()
	var remaining: int = maxi(0, point_budget)
	for attribute_id in ORDER:
		if attribute_id == "mana" and not uses_mana(hero_id):
			continue
		var value: Variant = raw.get(attribute_id, 0)
		var invested: int = clampi(int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0, 0, ATTRIBUTE_LIMIT)
		result[attribute_id] = mini(invested, remaining)
		remaining -= int(result[attribute_id])
	return result


static func invested_points(attributes: Dictionary) -> int:
	var total := 0
	for attribute_id in ORDER:
		total += int(attributes.get(attribute_id, 0))
	return total


static func mana_regen_per_turn(mana_points: int) -> int:
	return MANA_REGEN_BASE + floori(float(maxi(0, mana_points)) / float(MANA_REGEN_POINTS_PER_STEP))


static func special_cost(unlocked: Array) -> int:
	var total := 0
	for skill_id in unlocked:
		total += int(Skills.DEFINITIONS.get(str(skill_id), {}).get("point_cost", 0))
	return total


static func sanitized_specials(raw: Variant, hero_id: String, budget: int = 19, level: int = 20) -> Array[String]:
	var result: Array[String] = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	var remaining := maxi(0, budget)
	for skill_id in Skills.SPECIALS.get(hero_id, []):
		var cost: int = int(Skills.DEFINITIONS[skill_id]["point_cost"])
		if skill_id in raw and cost <= remaining and level >= int(Skills.DEFINITIONS[skill_id]["level"]):
			result.append(skill_id)
			remaining -= cost
	return result


static func from_save(raw: Dictionary, hero_id: String, save_version: int) -> Dictionary:
	var total_xp: int = maxi(0, int(raw.get("xp", 0)) if typeof(raw.get("xp")) in [TYPE_INT, TYPE_FLOAT] else 0)
	var saved_level: int = maxi(1, int(raw.get("level", 1)) if typeof(raw.get("level")) in [TYPE_INT, TYPE_FLOAT] else 1)
	var level: int
	var level_xp: int
	var attributes: Dictionary
	var legacy_level: int = 0
	if save_version < 2:
		var old_level: int = maxi(saved_level, 1 + floori(float(total_xp) / 100.0))
		level = mini(MAX_LEVEL, old_level)
		if old_level > MAX_LEVEL:
			legacy_level = old_level
		level_xp = total_xp % 100
		attributes = empty_attributes()
	else:
		level = clampi(saved_level, 1, MAX_LEVEL)
		legacy_level = maxi(0, int(raw.get("legacy_level", 0)) if typeof(raw.get("legacy_level")) in [TYPE_INT, TYPE_FLOAT] else 0)
		level_xp = maxi(0, int(raw.get("level_xp", 0)) if typeof(raw.get("level_xp")) in [TYPE_INT, TYPE_FLOAT] else 0)
		var raw_attributes: Dictionary = raw.get("attributes", {}) if typeof(raw.get("attributes")) == TYPE_DICTIONARY else {}
		attributes = sanitized_attributes(raw_attributes, hero_id, level - 1)
	var unlocked: Array[String] = sanitized_specials(raw.get("unlocked_specials", []), hero_id, level - 1 - invested_points(attributes), level)
	var entry := {"xp": total_xp, "level": level, "level_xp": level_xp, "attributes": attributes, "unlocked_specials": unlocked, "available_points": maxi(0, level - 1 - invested_points(attributes) - special_cost(unlocked))}
	if legacy_level > MAX_LEVEL:
		entry["legacy_level"] = legacy_level
	_advance_levels(entry)
	return entry


static func grant_xp(entry: Dictionary, amount: int) -> void:
	var gain: int = maxi(0, amount)
	entry["xp"] = int(entry.get("xp", 0)) + gain
	entry["level_xp"] = int(entry.get("level_xp", 0)) + gain
	_advance_levels(entry)


static func can_invest(entry: Dictionary, hero_id: String, attribute_id: String) -> bool:
	if not DEFINITIONS.has(attribute_id) or (attribute_id == "mana" and not uses_mana(hero_id)):
		return false
	return int(entry.get("available_points", 0)) > 0 and int(entry.get("attributes", {}).get(attribute_id, 0)) < ATTRIBUTE_LIMIT


static func invest(entry: Dictionary, hero_id: String, attribute_id: String) -> bool:
	if not can_invest(entry, hero_id, attribute_id):
		return false
	var attributes: Dictionary = entry["attributes"]
	attributes[attribute_id] = int(attributes[attribute_id]) + 1
	entry["attributes"] = attributes
	entry["available_points"] = maxi(0, int(entry["level"]) - 1 - invested_points(attributes) - special_cost(entry.get("unlocked_specials", [])))
	return true


static func can_refund(entry: Dictionary, hero_id: String, attribute_id: String) -> bool:
	if not DEFINITIONS.has(attribute_id) or (attribute_id == "mana" and not uses_mana(hero_id)):
		return false
	return int(entry.get("attributes", {}).get(attribute_id, 0)) > 0


static func refund(entry: Dictionary, hero_id: String, attribute_id: String) -> bool:
	if not can_refund(entry, hero_id, attribute_id):
		return false
	var attributes: Dictionary = entry["attributes"]
	attributes[attribute_id] = int(attributes[attribute_id]) - 1
	entry["attributes"] = attributes
	entry["available_points"] = maxi(0, int(entry["level"]) - 1 - invested_points(attributes) - special_cost(entry.get("unlocked_specials", [])))
	return true


static func can_unlock(entry: Dictionary, hero_id: String, skill_id: String) -> bool:
	if not skill_id in Skills.SPECIALS.get(hero_id, []) or skill_id in entry.get("unlocked_specials", []):
		return false
	var skill: Dictionary = Skills.DEFINITIONS[skill_id]
	return int(entry.get("level", 1)) >= int(skill["level"]) and int(entry.get("available_points", 0)) >= int(skill["point_cost"])


static func unlock(entry: Dictionary, hero_id: String, skill_id: String) -> bool:
	if not can_unlock(entry, hero_id, skill_id):
		return false
	var unlocked: Array = entry.get("unlocked_specials", []).duplicate()
	unlocked.append(skill_id)
	entry["unlocked_specials"] = unlocked
	entry["available_points"] = maxi(0, int(entry["level"]) - 1 - invested_points(entry["attributes"]) - special_cost(unlocked))
	return true


static func total_effect(attribute_id: String, points: int) -> String:
	match attribute_id:
		"vitalidade": return "+%d PV máximos" % (points * 7)
		"poder": return "+%d dano básico" % (points * 3)
		"agilidade": return "+%d iniciativa" % points
		"resistencia": return "+%d p.p. resistências" % (points * 2)
		"mana":
			var regen: int = mana_regen_per_turn(points)
			return "+%d mana máxima · %d mana por turno" % [points * 3, regen]
	return ""


static func _advance_levels(entry: Dictionary) -> void:
	var level: int = clampi(int(entry.get("level", 1)), 1, MAX_LEVEL)
	var progress: int = maxi(0, int(entry.get("level_xp", 0)))
	while level < MAX_LEVEL and progress >= xp_required(level):
		progress -= xp_required(level)
		level += 1
	entry["level"] = level
	entry["level_xp"] = progress
	entry["available_points"] = maxi(0, level - 1 - invested_points(entry.get("attributes", {})) - special_cost(entry.get("unlocked_specials", [])))
