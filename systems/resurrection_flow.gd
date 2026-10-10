extends RefCounted

# These IDs carry no public clue about the speaker's place in the plot.
const FIRST := "first"
const RARE := "rare"
const COMMON := ["darkness", "strength", "bond", "path", "continue"]
const MESSAGES := {
	"darkness": "Não tenha medo da escuridão. Eu ainda consigo encontrar você nela.",
	"strength": "Você está ficando mais forte... Eu consigo sentir.",
	"bond": "Eles podem destruir seu corpo, mas não aquilo que nos mantém ligados.",
	"path": "Mesmo quando tudo parece perdido... ainda existe outro caminho.",
	"continue": "Eu sei que está cansado. Mas preciso que continue.",
	"rare": "Mais uma vez... Perdoe-me. Ainda não posso deixar você descansar."
}


static func choose_message(losses: int, last_id: String, roll: int) -> String:
	if losses >= 4 and roll % 12 == 0 and last_id != RARE:
		return RARE
	var available: Array[String] = []
	for id in COMMON:
		if id != last_id:
			available.append(id)
	return available[(roll / 12 if losses >= 4 else roll) % available.size()]


static func scene_for(message_id: String) -> Dictionary:
	if message_id == FIRST:
		return preload("res://data/narrative_scenes.gd").get_scene("ressurreicao_primeira")
	if not MESSAGES.has(message_id):
		return {}
	return {
		"presentation": "resurrection",
		"lines": [{"id": "resurrection_%s" % message_id, "speaker": "garota_desconhecida", "portrait": "", "event": "resurrection:whisper", "text": MESSAGES[message_id], "end": true}]
	}
