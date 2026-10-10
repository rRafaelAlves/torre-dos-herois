extends RefCounted

const MAIN_SCENES := ["intro_reino", "encontro_pai", "encontro_comerciante", "entrada_torre", "epilogo_gueist"]
const LEGACY_SEEN := {"intro_reino": true, "encontro_pai": true, "encontro_comerciante": true, "entrada_torre": true, "epilogo_gueist": true}
const STAGES := {
	"intro_reino": {"title": "ANTES DA TORRE", "subtitle": "A tempestade mudou o reino para sempre."},
	"encontro_pai": {"title": "UM PEDIDO DE AJUDA", "subtitle": "No caminho para a torre, alguém chama pelos aventureiros."},
	"encontro_comerciante": {"title": "UM ENCONTRO NA ESTRADA", "subtitle": "Perto do quinto andar, uma voz surge entre as ruínas."},
	"entrada_torre": {"title": "A ENTRADA DA TORRE", "subtitle": "O destino da garota espera além dos portões."},
	"epilogo_gueist": {"title": "O PORTÃO ESTÁ ABERTO", "subtitle": "O prólogo chega ao fim."}
}


static func next_scene(attempt: Dictionary) -> String:
	if attempt.is_empty() or str(attempt.get("phase", "")) != "combat":
		return ""
	var flags: Dictionary = attempt.get("narrative_seen", LEGACY_SEEN)
	var floor_number := int(attempt.get("floor", 0))
	var completed := int(attempt.get("completed", 0))
	if floor_number == 1 and completed == 0:
		for id in ["intro_reino", "encontro_pai"]:
			if not bool(flags.get(id, false)):
				return id
	elif floor_number == 5 and completed == 4 and not bool(flags.get("encontro_comerciante", false)):
		return "encontro_comerciante"
	elif floor_number == 10 and completed == 9 and not bool(flags.get("entrada_torre", false)):
		return "entrada_torre"
	return ""


static func is_main_scene(id: String) -> bool:
	return id in MAIN_SCENES
