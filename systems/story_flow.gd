extends RefCounted

const MAIN_SCENES := ["intro_reino", "encontro_pai", "encontro_comerciante", "entrada_torre", "epilogo_gueist"]
const LEGACY_SEEN := {"intro_reino": true, "encontro_pai": true, "encontro_comerciante": true, "entrada_torre": true, "epilogo_gueist": true}
const PERMANENT_SCENES := ["intro_reino", "encontro_pai", "encontro_comerciante_primeiro", "entrada_torre", "epilogo_gueist"]
const FRAGMENT_SCENES := {"fragmento_luz_andar_3": 3, "fragmento_luz_andar_8": 8}
const STAGES := {
	"intro_reino": {"title": "ANTES DA TORRE", "subtitle": "A tempestade mudou o reino para sempre."},
	"encontro_pai": {"title": "UM PEDIDO DE AJUDA", "subtitle": "No caminho para a torre, alguém chama pelos aventureiros."},
	"encontro_comerciante": {"title": "UM ENCONTRO NA ESTRADA", "subtitle": "Perto do quinto andar, uma voz surge entre as ruínas."},
	"fragmento_luz_andar_3": {"title": "UMA LUZ ESQUECIDA", "subtitle": "Algo antigo parece despertar por um instante."},
	"fragmento_luz_andar_8": {"title": "ECO DOURADO", "subtitle": "Uma lembrança sem origem atravessa a torre."},
	"entrada_torre": {"title": "A ENTRADA DA TORRE", "subtitle": "O destino da garota espera além dos portões."},
	"epilogo_gueist": {"title": "O PORTÃO ESTÁ ABERTO", "subtitle": "O prólogo chega ao fim."}
}


static func next_scene(attempt: Dictionary, permanent_narrative: Dictionary = {}) -> String:
	if attempt.is_empty() or str(attempt.get("phase", "")) != "combat":
		return ""
	var flags: Dictionary = attempt.get("narrative_seen", LEGACY_SEEN)
	var floor_number := int(attempt.get("floor", 0))
	var completed := int(attempt.get("completed", 0))
	var completed_scenes: Dictionary = permanent_narrative.get("completed_scenes", {})
	var fragments_found: Dictionary = permanent_narrative.get("fragments_found", {})
	if floor_number == 1 and completed == 0:
		for id in ["intro_reino", "encontro_pai"]:
			if not bool(flags.get(id, false)) and not bool(completed_scenes.get(id, false)):
				return id
	if floor_number == 3 and completed == 2 and not bool(flags.get("fragmento_luz_andar_3", false)) and not bool(fragments_found.get("fragmento_luz_andar_3", false)):
		return "fragmento_luz_andar_3"
	if floor_number == 5 and completed == 4 and str(attempt.get("merchant_camp_status", "")) == "" and not bool(flags.get("encontro_comerciante", false)):
		return "encontro_comerciante"
	if floor_number == 8 and completed == 7 and not bool(flags.get("fragmento_luz_andar_8", false)) and not bool(fragments_found.get("fragmento_luz_andar_8", false)):
		return "fragmento_luz_andar_8"
	if floor_number == 10 and completed == 9 and not bool(flags.get("entrada_torre", false)) and not bool(completed_scenes.get("entrada_torre", false)):
		return "entrada_torre"
	return ""


static func is_main_scene(id: String) -> bool:
	return id in MAIN_SCENES
