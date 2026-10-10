extends RefCounted

const DEFINITIONS := {
	"robusto": {"name": "Robusto", "class": "", "scope": "hero", "levels": ["+15% PV máx., +4% resistências", "+25% PV máx., +6% resistências", "+35% PV máx., +8% resistências"]},
	"veloz": {"name": "Veloz", "class": "", "scope": "hero", "levels": ["+15% iniciativa", "+25% iniciativa", "+35% iniciativa"]},
	"poder": {"name": "Poder", "class": "", "scope": "hero", "levels": ["+10% dano básico", "+20% dano básico", "+30% dano básico"]},
	"precisao": {"name": "Precisão", "class": "", "scope": "hero", "levels": ["+5 p.p. chance crítica", "+10 p.p. chance crítica", "+15 p.p. chance crítica"]},
	"retaliacao": {"name": "Retaliação", "class": "guerreiro", "scope": "hero", "condition": "Ativa quando o herói bloqueia um ataque inimigo.", "levels": ["4 dano ao bloquear", "7 dano ao bloquear", "10 dano ao bloquear"]},
	"predador": {"name": "Predador", "class": "patrulheiro", "scope": "hero", "condition": "Ativa ao atacar um inimigo que já perdeu PV.", "levels": ["+3 dano em inimigo ferido", "+5 dano em inimigo ferido", "+7 dano em inimigo ferido"]},
	"bruxaria_luminosa": {"name": "Bruxaria Luminosa", "class": "bruxa", "scope": "hero", "condition": "Ativa ao causar dano mágico; a parcela Radiante ignora resistência mágica.", "levels": ["15% do dano mágico é Radiante", "25% do dano mágico é Radiante", "35% do dano mágico é Radiante"]},
	"graca_divina": {"name": "Graça Divina", "class": "sacerdotisa", "scope": "hero", "condition": "Aumenta a cura de um aliado ferido, limitada aos PV que faltam.", "levels": ["+15% cura", "+25% cura", "+35% cura"]},
	"poder_elemental": {"name": "Poder Elemental", "class": "feiticeiro", "scope": "hero", "condition": "Ativa ao causar dano com uma magia.", "levels": ["+10% dano de magia", "+20% dano de magia", "+30% dano de magia"]},
}
const UNIVERSAL := ["robusto", "veloz", "poder", "precisao"]
const EXCLUSIVE := {"guerreiro": "retaliacao", "patrulheiro": "predador", "bruxa": "bruxaria_luminosa", "sacerdotisa": "graca_divina", "feiticeiro": "poder_elemental"}


static func options_for(hero_id: String, owned: Dictionary) -> Array[String]:
	var pool: Array[String] = []
	for card_id in UNIVERSAL:
		if int(owned.get(card_id, 0)) < 3:
			pool.append(card_id)
	var exclusive_id: String = EXCLUSIVE.get(hero_id, "")
	if exclusive_id != "" and int(owned.get(exclusive_id, 0)) < 3:
		pool.append(exclusive_id)
	pool.shuffle()
	var existing: Array[String] = []
	for card_id in pool:
		if int(owned.get(card_id, 0)) > 0:
			existing.append(card_id)
	if not existing.is_empty():
		pool.erase(existing[0])
		pool.push_front(existing[0])
	return pool.slice(0, mini(3, pool.size()))


static func label(card_id: String, level: int) -> String:
	var definition: Dictionary = DEFINITIONS.get(card_id, {})
	if definition.is_empty() or level < 1 or level > 3:
		return ""
	return "%s %s — %s" % [definition["name"], ["I", "II", "III"][level - 1], definition["levels"][level - 1]]
