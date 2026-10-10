extends RefCounted

const DEFINITIONS := {
	"golpe_poderoso": {"name": "Golpe Poderoso", "kind": "damage", "amount": 30, "damage_type": "physical", "cooldown": 2, "target": "enemy"},
	"guarda_protetora": {"name": "Guarda Protetora", "kind": "guard", "reduction": 0.4, "cooldown": 3, "target": "ally_unprotected"},
	"disparo_duplo": {"name": "Disparo Duplo", "kind": "damage", "amount": 12, "hits": 2, "damage_type": "physical", "cooldown": 2, "target": "enemy"},
	"flecha_debilitante": {"name": "Flecha Debilitante", "kind": "damage_status", "amount": 12, "damage_type": "physical", "effect": "fraqueza", "cooldown": 3, "target": "enemy"},
	"raio_arcano": {"name": "Raio Arcano", "kind": "damage", "amount": 25, "damage_type": "magical", "mana": 10, "target": "enemy"},
	"maldicao_venenosa": {"name": "Maldição Venenosa", "kind": "status", "effect": "veneno", "mana": 8, "target": "enemy"},
	"cura": {"name": "Cura", "kind": "heal", "amount": 25, "mana": 10, "target": "hero"},
	"purificacao": {"name": "Purificação", "kind": "purify", "amount": 10, "mana": 10, "target": "living_ally"},
	"bola_de_fogo": {"name": "Bola de Fogo", "kind": "damage", "amount": 30, "damage_type": "magical", "visual_type": "fire", "mana": 15, "target": "enemy"},
	"onda_arcana": {"name": "Onda Arcana", "kind": "damage_all", "amount": 16, "damage_type": "magical", "mana": 15, "target": "all_enemies"},
	"golpe_carrasco": {"name": "Golpe do Carrasco", "kind": "execute", "amount": 26, "damage_type": "physical", "cooldown": 3, "target": "enemy", "class": "guerreiro", "tier": 1, "level": 6, "point_cost": 2},
	"fortaleza_inabalavel": {"name": "Fortaleza Inabalável", "kind": "self_buff", "effect": "fortaleza", "cooldown": 6, "target": "self", "class": "guerreiro", "tier": 2, "level": 12, "point_cost": 3},
	"instinto_predador": {"name": "Instinto Predador", "kind": "damage_buff", "amount": 15, "damage_type": "physical", "effect": "instinto", "cooldown": 4, "target": "enemy", "class": "patrulheiro", "tier": 1, "level": 6, "point_cost": 2},
	"chuva_flechas": {"name": "Chuva de Flechas", "kind": "damage_all", "amount": 13, "damage_type": "physical", "cooldown": 5, "target": "all_enemies", "class": "patrulheiro", "tier": 2, "level": 12, "point_cost": 3},
	"maldicao_coletiva": {"name": "Maldição Coletiva", "kind": "status_all", "effect": "fraqueza", "mana": 14, "cooldown": 4, "target": "all_enemies", "class": "bruxa", "tier": 1, "level": 6, "point_cost": 2},
	"vampirismo_arcano": {"name": "Vampirismo Arcano", "kind": "self_buff", "effect": "vampirismo", "mana": 12, "cooldown": 6, "target": "self", "class": "bruxa", "tier": 2, "level": 12, "point_cost": 3},
	"prece_restauradora": {"name": "Prece Restauradora", "kind": "heal_all", "amount": 14, "mana": 15, "cooldown": 4, "target": "all_allies", "class": "sacerdotisa", "tier": 1, "level": 6, "point_cost": 2},
	"milagre_divino": {"name": "Milagre Divino", "kind": "miracle", "amount": 30, "mana": 20, "cooldown": 6, "target": "hero", "class": "sacerdotisa", "tier": 2, "level": 12, "point_cost": 3},
	"ruptura_arcana": {"name": "Ruptura Arcana", "kind": "pierce", "amount": 26, "damage_type": "magical", "mana": 12, "cooldown": 3, "target": "enemy", "class": "feiticeiro", "tier": 1, "level": 6, "point_cost": 2},
	"tempestade_arcana": {"name": "Tempestade Arcana", "kind": "damage_all", "amount": 24, "damage_type": "magical", "mana": 24, "cooldown": 5, "target": "all_enemies", "class": "feiticeiro", "tier": 2, "level": 12, "point_cost": 3},
}

const SPECIALS := {
	"guerreiro": ["golpe_carrasco", "fortaleza_inabalavel"],
	"patrulheiro": ["instinto_predador", "chuva_flechas"],
	"bruxa": ["maldicao_coletiva", "vampirismo_arcano"],
	"sacerdotisa": ["prece_restauradora", "milagre_divino"],
	"feiticeiro": ["ruptura_arcana", "tempestade_arcana"],
}


static func get_definition(skill_id: String) -> Dictionary:
	return DEFINITIONS.get(skill_id, {}).duplicate(true)


static func visual_type_for_name(skill_name: String, fallback: String) -> String:
	for skill_id in DEFINITIONS:
		var skill: Dictionary = DEFINITIONS[skill_id]
		if skill.get("name", "") == skill_name:
			return str(skill.get("visual_type", fallback))
	return fallback
