extends RefCounted

const DEFINITIONS := {
	"guerreiro": {"name": "Guerreiro", "max_hp": 130, "damage": 20, "initiative": 12, "emblem": "W", "attack_type": "physical", "skill": "golpe_poderoso", "alternate_skills": ["guarda_protetora"]},
	"patrulheiro": {"name": "Patrulheiro", "max_hp": 110, "damage": 17, "initiative": 16, "emblem": "P", "attack_type": "physical", "skill": "disparo_duplo", "alternate_skills": ["flecha_debilitante"]},
	"bruxa": {"name": "Bruxa", "max_hp": 90, "damage": 15, "initiative": 18, "mana_max": 30, "emblem": "B", "attack_type": "magical", "skill": "raio_arcano", "alternate_skills": ["maldicao_venenosa"]},
	"sacerdotisa": {"name": "Sacerdotisa", "max_hp": 115, "damage": 12, "initiative": 10, "mana_max": 30, "emblem": "S", "attack_type": "physical", "skill": "cura", "alternate_skills": ["purificacao"]},
	"feiticeiro": {"name": "Feiticeiro", "max_hp": 85, "damage": 14, "initiative": 14, "mana_max": 30, "emblem": "F", "attack_type": "magical", "skill": "bola_de_fogo", "alternate_skills": ["onda_arcana"]},
}
const ORDER := ["guerreiro", "patrulheiro", "bruxa", "sacerdotisa", "feiticeiro"]


static func get_definition(hero_id: String) -> Dictionary:
	return DEFINITIONS.get(hero_id, {}).duplicate(true)
