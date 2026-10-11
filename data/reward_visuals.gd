extends RefCounted
const Relics = preload("res://data/relics.gd")

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
static var _generated_relic_icons: Dictionary = {}


static func card_theme(card_id: String) -> Dictionary:
	return CARD_THEMES.get(card_id, {"category": "CARTA", "color": Color("aeb1bf"), "icon": "bonuses"})


static func relic_icon(relic_id: String) -> Texture2D:
	if RELIC_ICONS.has(relic_id):
		return RELIC_ICONS[relic_id]
	if _generated_relic_icons.has(relic_id):
		return _generated_relic_icons[relic_id]
	var definition: Dictionary = Relics.DEFINITIONS.get(relic_id, {})
	if definition.is_empty():
		return null
	var tint: Color = Relics.RARITY_COLORS.get(str(definition.get("rarity", "simple")), Color("b8c3cb"))
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var dark := Color("19222f")
	var gleam := tint.lightened(0.25)
	for y in range(3, 29):
		for x in range(3, 29):
			var radius: int = absi(x - 16) + absi(y - 16)
			if radius <= 21:
				image.set_pixel(x, y, dark)
			if radius >= 18 and radius <= 20:
				image.set_pixel(x, y, tint.darkened(0.35))
	var motif: int = absi(relic_id.hash()) % 5
	for y in range(8, 25):
		for x in range(8, 25):
			var dx: int = absi(x - 16)
			var dy: int = absi(y - 16)
			var lit := false
			match motif:
				0: lit = dx + dy <= 7 and dx + dy >= 5
				1: lit = (dx <= 2 and y < 22) or (y in [13, 14] and dx <= 7)
				2: lit = (dy <= 2 and x < 23) or (x in [12, 13] and dy <= 7)
				3: lit = (dx <= 2 and dy <= 7) or (dy <= 2 and dx <= 7)
				4: lit = (dx + dy <= 8 and dx + dy >= 4 and (x + y) % 2 == 0)
			if lit:
				image.set_pixel(x, y, gleam if (x + y) % 3 == 0 else tint)
	var result := ImageTexture.create_from_image(image)
	_generated_relic_icons[relic_id] = result
	return result
