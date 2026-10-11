extends RefCounted

const DEFINITIONS := {
	"amuleto_carvalho": {"name": "Amuleto do Carvalho", "description": "+8% de PV máximos.", "rarity": "simple", "scope": "hero"},
	"pedra_bastiao": {"name": "Pedra do Bastião", "description": "Reduz 6% do dano físico recebido.", "rarity": "simple", "scope": "hero"},
	"egide_nevoa": {"name": "Égide da Névoa", "description": "Reduz 6% do dano mágico recebido.", "rarity": "simple", "scope": "hero"},
	"botas_vento": {"name": "Botas do Vento", "description": "+1 de iniciativa.", "rarity": "simple", "scope": "hero"},
	"punho_aco": {"name": "Punho de Aço", "description": "+6% de dano físico.", "rarity": "simple", "scope": "hero"},
	"cristal_prismatico": {"name": "Cristal Prismático", "description": "+6% de dano mágico.", "rarity": "simple", "scope": "hero"},
	"reserva_arcana": {"name": "Reserva Arcana", "description": "+8 de mana máxima.", "rarity": "simple", "scope": "hero"},
	"simbolo_graca": {"name": "Símbolo da Graça", "description": "+10% de cura realizada.", "rarity": "simple", "scope": "hero"},
	"olho_cacador": {"name": "Olho do Caçador", "description": "+4 pontos percentuais de chance crítica.", "rarity": "simple", "scope": "hero"},
	"ferrao_esmeralda": {"name": "Ferrão Esmeralda", "description": "+1 de dano periódico no Veneno aplicado.", "rarity": "simple", "scope": "hero"},
	"frasco_regeneracao": {"name": "Frasco de Regeneração", "description": "Após a vitória, recupera 5% dos PV máximos se estiver vivo.", "rarity": "simple", "scope": "hero"},
	"anel_persistencia": {"name": "Anel da Persistência", "description": "Ao Defender, recupera 2 mana uma vez por turno próprio.", "rarity": "simple", "scope": "hero"},
	"estandarte_vale": {"name": "Estandarte do Vale", "description": "Todos os heróis da equipe recebem +4% de PV máximos.", "rarity": "simple", "scope": "team"},
	"relogio_vento": {"name": "Relógio do Vento", "description": "Todos os heróis da equipe recebem +1 de iniciativa.", "rarity": "simple", "scope": "team"},
	"bolsa_ervas": {"name": "Bolsa de Ervas", "description": "Após a vitória, cada sobrevivente recupera 3 PV.", "rarity": "simple", "scope": "team"},
	"espelho_batalha": {"name": "Espelho da Batalha", "description": "O primeiro golpe recebido em cada combate causa 60% menos dano.", "rarity": "rare", "scope": "hero"},
	"pacto_cacador": {"name": "Pacto do Caçador", "description": "Duas ações ofensivas seguidas contra o mesmo inimigo: +20% no segundo ataque.", "rarity": "rare", "scope": "hero"},
	"coracao_espinhos": {"name": "Coração de Espinhos", "description": "Devolve 20% do dano físico direto recebido, uma vez por turno.", "rarity": "rare", "scope": "hero"},
	"taca_carmesim": {"name": "Taça Carmesim", "description": "Dano direto contra inimigo envenenado cura 15% do dano, até 12 PV por turno.", "rarity": "rare", "scope": "hero"},
	"ampulheta_arcana": {"name": "Ampulheta Arcana", "description": "A primeira habilidade com custo de mana por combate devolve o custo.", "rarity": "rare", "scope": "hero"},
	"sino_misericordia": {"name": "Sino da Misericórdia", "description": "A primeira cura em aliado abaixo de 35% dos PV remove Veneno ou Fraqueza.", "rarity": "rare", "scope": "hero"},
	"mascara_executor": {"name": "Máscara do Executor", "description": "Após eliminar um inimigo, o próximo ataque de alvo único causa +40%. Uma vez por combate.", "rarity": "rare", "scope": "hero"},
	"vinculo_cinzas": {"name": "Vínculo das Cinzas", "description": "Ao cair um aliado, sobreviventes recuperam 4 mana e ganham +30% no próximo ataque direto. Uma vez por combate.", "rarity": "rare", "scope": "team"},
	"marcha_conclave": {"name": "Marcha do Conclave", "description": "Cada herói recebe 20% menos dano até agir pela primeira vez.", "rarity": "rare", "scope": "team"},
	"circulo_purificacao": {"name": "Círculo da Purificação", "description": "Uma vez por combate, remove Veneno ou Fraqueza quando ao menos dois aliados forem afetados.", "rarity": "rare", "scope": "team"},
	"relogio_renascimento": {"name": "Relógio do Renascimento", "description": "Uma vez por combate, sobrevive a dano fatal com 25% dos PV máximos.", "rarity": "epic", "scope": "hero"},
	"lamina_tempestade": {"name": "Lâmina da Tempestade", "description": "A cada três acertos diretos, outro inimigo recebe 40% do último dano. Até duas vezes por combate.", "rarity": "epic", "scope": "hero"},
	"codice_eco": {"name": "Códice do Eco", "description": "A primeira habilidade ofensiva de alvo único repete 50% do dano, sem mana nem efeitos adicionais.", "rarity": "epic", "scope": "hero"},
	"chama_retornados": {"name": "Chama dos Retornados", "description": "Uma vez por combate, reanima automaticamente o primeiro herói a cair com 25% dos PV.", "rarity": "epic", "scope": "team"},
	"juramento_aurora": {"name": "Juramento da Aurora", "description": "Abaixo de 40% dos PV totais, sobreviventes recuperam 4 mana e reduzem 30% do próximo dano. Uma vez por combate.", "rarity": "epic", "scope": "team"},
	"medalhao_vital": {"name": "Medalhão Vital", "description": "+10% PV máximos para todo o grupo", "rarity": "simple", "bearer": false, "scope": "team", "legacy": true},
	"pedra_arcana": {"name": "Pedra Arcana", "description": "Portador recupera 2 mana ao usar magia com custo", "rarity": "simple", "bearer": true, "scope": "hero", "legacy": true},
	"insignia_guerreiro": {"name": "Insígnia do Guerreiro", "description": "Portador causa +10% de dano básico", "rarity": "simple", "bearer": true, "scope": "hero", "legacy": true},
}

const SIMPLE_NEW := ["amuleto_carvalho", "pedra_bastiao", "egide_nevoa", "botas_vento", "punho_aco", "cristal_prismatico", "reserva_arcana", "simbolo_graca", "olho_cacador", "ferrao_esmeralda", "frasco_regeneracao", "anel_persistencia", "estandarte_vale", "relogio_vento", "bolsa_ervas"]
const RARITY_NAMES := {"simple": "Simples", "rare": "Rara", "epic": "Épica"}
const RARITY_COLORS := {"simple": Color("b8c3cb"), "rare": Color("6db5ef"), "epic": Color("c99bf1")}
const SHOP_PRICES := {
	"simple": {"temporary": 70, "permanent": 700},
	"rare": {"temporary": 250, "permanent": 2500},
	"epic": {"temporary": 700, "permanent": 7000},
}
const SHOP_REFRESH_COST := 10
const CLASS_RECOMMENDATIONS := {
	"guerreiro": ["amuleto_carvalho", "pedra_bastiao", "punho_aco", "espelho_batalha", "coracao_espinhos", "taca_carmesim", "relogio_renascimento", "insignia_guerreiro"],
	"patrulheiro": ["botas_vento", "olho_cacador", "ferrao_esmeralda", "pacto_cacador", "taca_carmesim", "mascara_executor", "lamina_tempestade"],
	"bruxa": ["egide_nevoa", "cristal_prismatico", "reserva_arcana", "anel_persistencia", "ampulheta_arcana", "codice_eco", "pedra_arcana"],
	"sacerdotisa": ["simbolo_graca", "frasco_regeneracao", "sino_misericordia", "circulo_purificacao"],
	"feiticeiro": ["cristal_prismatico", "reserva_arcana", "anel_persistencia", "ampulheta_arcana", "codice_eco", "pedra_arcana"],
}
const TEAM_RELICS := ["estandarte_vale", "relogio_vento", "bolsa_ervas", "vinculo_cinzas", "marcha_conclave", "juramento_aurora", "medalhao_vital", "chama_retornados"]


static func definition(relic_id: String) -> Dictionary:
	var result: Dictionary = DEFINITIONS.get(relic_id, {}).duplicate(true)
	if not result.is_empty():
		result["id"] = relic_id
		result["bearer"] = result.get("scope", "hero") == "hero"
	return result


static func shop_price(relic_id: String, mode: String) -> int:
	var rarity := str(DEFINITIONS.get(relic_id, {}).get("rarity", ""))
	return int(SHOP_PRICES.get(rarity, {}).get(mode, 0))


static func recommended_class(relic_id: String) -> String:
	if relic_id in TEAM_RELICS:
		return "Grupo"
	for hero_id in CLASS_RECOMMENDATIONS:
		if relic_id in CLASS_RECOMMENDATIONS[hero_id]:
			return {"guerreiro": "Guerreiro", "patrulheiro": "Patrulheiro", "bruxa": "Bruxa", "sacerdotisa": "Sacerdotisa", "feiticeiro": "Feiticeiro"}[hero_id]
	return "Qualquer classe"


static func available(owned: Array, hero_ids: Array) -> Array[String]:
	var result: Array[String] = []
	for relic_id in DEFINITIONS:
		if DEFINITIONS[relic_id].get("rarity", "") != "simple":
			continue
		var count := 0
		for relic in owned:
			if relic.get("id", "") == relic_id:
				count += 1
		if count >= 2:
			continue
		result.append(relic_id)
	result.shuffle()
	return result
