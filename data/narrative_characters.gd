extends RefCounted

# A capa oficial fixa a silhueta e a paleta; os retratos neutros seguem essa referência.
# Guerreiro: aço, escudo azul/dourado e capa vermelha; patrulheiro: couro e capa verde.
# Bruxa: chapéu, traje violeta e cajado; sacerdotisa: branco, ouro e símbolo solar.
# Feiticeiro: manto azul, dourado e cajado de cristal.
const CHARACTERS := {
	"guerreiro": {"name": "Guerreiro", "portrait": "res://assets/narrative/portraits/guerreiro.png", "accent": "d98766", "side": "left", "expressions": {}},
	"patrulheiro": {"name": "Patrulheiro", "portrait": "res://assets/narrative/portraits/patrulheiro.png", "accent": "79b989", "side": "left", "expressions": {}},
	"bruxa": {"name": "Bruxa", "portrait": "res://assets/narrative/portraits/bruxa.png", "accent": "b58bd5", "side": "right", "expressions": {}},
	"sacerdotisa": {"name": "Sacerdotisa", "portrait": "res://assets/narrative/portraits/sacerdotisa.png", "accent": "e7d19a", "side": "right", "expressions": {}},
	"feiticeiro": {"name": "Feiticeiro", "portrait": "res://assets/narrative/portraits/feiticeiro.png", "accent": "80b8e8", "side": "right", "expressions": {}},
	"pai_da_garota": {"name": "Pai da garota", "portrait": "res://assets/narrative/portraits/pai_da_garota.png", "accent": "c5ad87", "side": "left", "expressions": {}},
	"comerciante": {"name": "Comerciante", "portrait": "res://assets/narrative/portraits/comerciante.png", "accent": "d5ad72", "side": "right", "expressions": {}},
	"garota_desconhecida": {"name": "Garota desconhecida", "portrait": "res://assets/narrative/portraits/garota_desconhecida.png", "accent": "c8b7dc", "side": "left", "expressions": {}},
	"figura_alada": {"name": "Figura desconhecida", "portrait": "res://assets/narrative/portraits/figura_alada.png", "accent": "c6d9e7", "side": "right", "expressions": {}},
	"general_gueist": {"name": "General Gueist", "portrait": "res://assets/narrative/portraits/general_gueist.png", "accent": "b78990", "side": "right", "expressions": {}}
}


static func get_character(id: String) -> Dictionary:
	return CHARACTERS.get(id, {})
