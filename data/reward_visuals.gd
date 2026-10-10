extends RefCounted

# Somente metadados de apresentação. Nomes, efeitos e regras vêm de Cards e Relics.
const CARD_THEMES := {
	"robusto": {"category": "DEFESA E VIDA", "color": Color("5d9ed1"), "icon": "defend"},
	"veloz": {"category": "AGILIDADE", "color": Color("69bc87"), "icon": "disparo_duplo"},
	"poder": {"category": "FORÇA FÍSICA", "color": Color("d87972"), "icon": "golpe_poderoso"},
	"precisao": {"category": "FORÇA FÍSICA", "color": Color("d87972"), "icon": "flecha_debilitante"},
	"retaliacao": {"category": "CARTA ESPECIAL", "color": Color("aeb1bf"), "icon": "guarda_protetora"},
	"predador": {"category": "FORÇA FÍSICA", "color": Color("d87972"), "icon": "flecha_debilitante"},
	"bruxaria_luminosa": {"category": "MAGIA", "color": Color("b18cdb"), "icon": "raio_arcano"},
	"graca_divina": {"category": "DEFESA E VIDA", "color": Color("5d9ed1"), "icon": "cura"},
	"poder_elemental": {"category": "MAGIA", "color": Color("b18cdb"), "icon": "bola_de_fogo"},
}

const RELIC_ICONS := {
	"medalhao_vital": preload("res://assets/rewards/medalhao_vital.svg"),
	"pedra_arcana": preload("res://assets/rewards/pedra_arcana.svg"),
	"insignia_guerreiro": preload("res://assets/rewards/insignia_guerreiro.svg"),
}


static func card_theme(card_id: String) -> Dictionary:
	return CARD_THEMES.get(card_id, {"category": "CARTA", "color": Color("aeb1bf"), "icon": "bonuses"})


static func relic_icon(relic_id: String) -> Texture2D:
	return RELIC_ICONS.get(relic_id)
