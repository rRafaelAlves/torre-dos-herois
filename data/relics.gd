extends RefCounted

const DEFINITIONS := {
	"medalhao_vital": {"name": "Medalhão Vital", "description": "+10% PV máximos para todo o grupo", "bearer": false, "scope": "team"},
	"pedra_arcana": {"name": "Pedra Arcana", "description": "Portador recupera 2 mana ao usar magia com custo", "bearer": true, "requires_mana": true, "scope": "hero", "condition": "Ativa ao usar uma magia com custo de mana; recuperação limitada ao mana que falta."},
	"insignia_guerreiro": {"name": "Insígnia do Guerreiro", "description": "Portador causa +10% de dano básico", "bearer": true, "scope": "hero"},
}


static func available(owned: Array, hero_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for relic_id in DEFINITIONS:
		var already_owned := false
		for relic in owned:
			if relic.get("id", "") == relic_id:
				already_owned = true
		if already_owned:
			continue
		if DEFINITIONS[relic_id].get("requires_mana", false):
			var has_mana := false
			for hero_id in hero_ids:
				if hero_id == "bruxa" or hero_id == "sacerdotisa" or hero_id == "feiticeiro":
					has_mana = true
			if not has_mana:
				continue
		result.append(relic_id)
	result.shuffle()
	return result
