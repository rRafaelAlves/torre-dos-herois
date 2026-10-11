extends RefCounted

const Relics = preload("res://data/relics.gd")
const Heroes = preload("res://data/heroes.gd")

const HERO_SLOTS := 3
const TEAM_SLOTS := 2


static func new_copy(relic_id: String, mode: String) -> Dictionary:
	if not Relics.DEFINITIONS.has(relic_id) or not mode in ["permanent", "temporary"]:
		return {}
	return {"uid": "%d-%d" % [Time.get_ticks_usec(), randi()], "id": relic_id, "mode": mode}


static func sanitize_inventory(raw: Variant, mode: String) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	if typeof(raw) != TYPE_ARRAY:
		return result
	for item in raw:
		if typeof(item) != TYPE_DICTIONARY or not Relics.DEFINITIONS.has(str(item.get("id", ""))):
			continue
		var uid := str(item.get("uid", ""))
		if uid.is_empty() or seen.has(uid):
			continue
		seen[uid] = true
		result.append({"uid": uid, "id": str(item["id"]), "mode": mode})
	return result


static func sanitize_equipped(raw: Variant, inventory: Array, mode: String) -> Array:
	var result: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return result
	var by_uid: Dictionary = {}
	for item in inventory:
		by_uid[item["uid"]] = item
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var uid := str(entry.get("uid", ""))
		if not by_uid.has(uid):
			continue
		var bearer := str(entry.get("bearer", ""))
		if can_equip(result, by_uid[uid], bearer, mode):
			result.append({"uid": uid, "id": by_uid[uid]["id"], "bearer": bearer, "mode": mode})
	return result


static func can_equip(equipped: Array, item: Dictionary, bearer: String, mode: String) -> bool:
	var definition: Dictionary = Relics.definition(str(item.get("id", "")))
	if definition.is_empty() or str(item.get("mode", "")) != mode:
		return false
	if definition["scope"] == "hero" and not Heroes.DEFINITIONS.has(bearer):
		return false
	if definition["scope"] == "team" and not bearer.is_empty():
		return false
	var used := 0
	for entry in equipped:
		if str(entry.get("uid", "")) == str(item.get("uid", "")):
			return false
		if str(entry.get("mode", "")) == mode and str(entry.get("bearer", "")) == bearer:
			used += 1
		if definition["rarity"] == "epic" and str(entry.get("id", "")) == str(item.get("id", "")):
			return false
	return used < (TEAM_SLOTS if bearer.is_empty() else HERO_SLOTS)


static func find_item(inventory: Array, uid: String) -> Dictionary:
	for item in inventory:
		if str(item.get("uid", "")) == uid:
			return item
	return {}
