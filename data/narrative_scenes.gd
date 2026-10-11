extends RefCounted

# Cada fala tem ID estável. Campos opcionais: name, portrait, side, pause,
# event, next, end, expression. Eventos são repassados ao jogo pela controladora.
const SCENES := {
	"intro_reino": {
		"skippable_when_seen": true,
		"lines": [
			{"speaker": "", "type": "narration", "text": "Durante séculos, a magia fez parte da vida neste reino."},
			{"speaker": "", "type": "narration", "text": "Alguns nasceram com dons extraordinários. Outros passaram a vida tentando compreendê-los."},
			{"speaker": "", "type": "narration", "text": "Então veio a tempestade."},
			{"speaker": "", "type": "narration", "text": "Por dias, os céus permaneceram escuros, e trovões ecoaram sobre todo o reino."},
			{"speaker": "", "type": "narration", "text": "Quando as nuvens se dispersaram, uma torre colossal havia surgido no coração do país."},
			{"speaker": "", "type": "narration", "text": "Ninguém sabia quem a construíra. Nem por que monstros protegiam seus arredores."},
			{"speaker": "", "type": "narration", "text": "Mas isso não impediu cinco aventureiros de procurar respostas."}
		]
	},
	"encontro_pai": {
		"skippable_when_seen": true,
		"lines": [
			{"speaker": "pai_da_garota", "text": "Por favor! Preciso de ajuda! Levaram minha filha!"},
			{"speaker": "guerreiro", "text": "Quem a levou?"},
			{"speaker": "pai_da_garota", "text": "Monstros... Criaturas vindas daquela torre!"},
			{"speaker": "patrulheiro", "text": "Isso não faz sentido. Eles atacam quem se aproxima. Por que levariam alguém vivo?"},
			{"speaker": "pai_da_garota", "text": "Eu... não sei."},
			{"speaker": "bruxa", "text": "Está escondendo alguma coisa."},
			{"speaker": "pai_da_garota", "text": "Minha filha nasceu diferente. Ela tem um dom que nunca compreendemos."},
			{"speaker": "sacerdotisa", "text": "Que tipo de dom?"},
			{"speaker": "pai_da_garota", "text": "Ela vê coisas... Acontecimentos que ainda não ocorreram."},
			{"speaker": "pai_da_garota", "text": "Antes mesmo da tempestade, dizia que uma torre surgiria."},
			{"speaker": "feiticeiro", "text": "Ela previu o aparecimento da torre?"},
			{"speaker": "pai_da_garota", "text": "Na noite em que tudo começou, acordou gritando. Disse que alguém viria buscá-la."},
			{"speaker": "pai_da_garota", "text": "E agora... agora ela desapareceu."},
			{"speaker": "guerreiro", "text": "Vamos procurá-la."},
			{"speaker": "pai_da_garota", "text": "Obrigado... Por favor, tragam minha filha de volta."}
		]
	},
	"encontro_comerciante": {
		"skippable_when_seen": true,
		"lines": [
			{"speaker": "comerciante", "text": "Ora, ora... Viajantes! Não esperava encontrar ninguém tão longe da estrada."},
			{"speaker": "patrulheiro", "text": "Estamos procurando uma menina. Foi levada por monstros."},
			{"speaker": "comerciante", "text": "Ah... a menina."},
			{"speaker": "sacerdotisa", "text": "Você a viu?"},
			{"speaker": "comerciante", "text": "Vi alguns goblins conduzindo uma garota em direção à entrada da torre."},
			{"speaker": "guerreiro", "text": "Ela estava ferida?"},
			{"speaker": "comerciante", "text": "Não. Assustada, talvez. Mas não parecia temer os goblins."},
			{"speaker": "bruxa", "text": "Então o que ela temia?"},
			{"speaker": "comerciante", "text": "Aquilo que a esperava."},
			{"speaker": "feiticeiro", "text": "Como você sabe disso?"},
			{"speaker": "comerciante", "text": "Há muitas coisas que se aprende viajando."},
			{"speaker": "comerciante", "text": "Enfim... precisam de suprimentos? A estrada adiante costuma ser cruel com os despreparados.", "next": "convite_acampamento"},
			{"id": "convite_acampamento", "speaker": "comerciante", "text": "Tenho algumas mercadorias interessantes no meu acampamento, não muito longe daqui. Gostariam de dar uma olhada?", "choices": [
				{"text": "Claro, por que não?", "event": "camp:accept"},
				{"text": "Por que deveríamos confiar em você?", "next": "duvida_acampamento"},
				{"text": "Agora não, obrigado.", "event": "camp:decline"}
			]},
			{"id": "duvida_acampamento", "speaker": "comerciante", "text": "Confiar? Não peço tanto. A fogueira está acesa; podem olhar e partir quando quiserem.", "choices": [
				{"text": "Claro, por que não?", "event": "camp:accept"},
				{"text": "Agora não, obrigado.", "event": "camp:decline"}
			]}
		]
	},
	"conselho_comerciante": {
		"lines": [{"speaker": "comerciante", "text": "Um conselho, aventureiros: algumas portas permanecem fechadas por um bom motivo."}]
	},
	"ressurreicao_primeira": {
		"presentation": "resurrection",
		"lines": [
			{"speaker": "garota_desconhecida", "portrait": "", "event": "resurrection:whisper", "text": "Ainda não chegou o fim para você, herói...", "pause": 0.48},
			{"speaker": "garota_desconhecida", "portrait": "", "text": "Enquanto minha vontade resistir, seu destino não terminará aqui.", "pause": 0.55},
			{"speaker": "garota_desconhecida", "portrait": "", "text": "Volte... por favor, não desista de mim."}
		]
	},
	"entrada_torre": {
		"lines": [
			{"speaker": "", "type": "narration", "event": "tower:arrival", "text": "A floresta se abria diante dos portões fechados da torre colossal."},
			{"speaker": "", "type": "narration", "event": "tower:escort", "text": "Dois goblins conduziam uma garota exausta pela clareira."},
			{"speaker": "patrulheiro", "event": "tower:arrows", "text": "Afastem-se dela!"},
			{"speaker": "", "type": "narration", "event": "tower:rescue", "text": "Duas flechas cortaram o ar. Os goblins caíram, e os heróis correram até a menina."},
			{"speaker": "garota_desconhecida", "text": "Vocês... vieram por mim?"},
			{"speaker": "sacerdotisa", "text": "Seu pai nos pediu ajuda. Vamos tirar você daqui."},
			{"speaker": "garota_desconhecida", "text": "Meu pai..."},
			{"speaker": "garota_desconhecida", "text": "Não... vocês não deviam ter vindo."},
			{"speaker": "guerreiro", "text": "Não temos tempo. Precisamos sair daqui."},
			{"speaker": "", "type": "narration", "event": "tower:winged", "text": "O vento se ergueu. Penas negras cruzaram a clareira, e uma sombra imensa cobriu o chão."},
			{"speaker": "guerreiro", "text": "Afaste-se dela!"},
			{"speaker": "figura_alada", "name": "Figura desconhecida", "text": "..."},
			{"speaker": "bruxa", "text": "Quem é você?"},
			{"speaker": "figura_alada", "name": "Figura desconhecida", "text": "Vocês não podem tirá-la de mim...", "pause": 0.55},
			{"speaker": "figura_alada", "name": "Figura desconhecida", "text": "Não de novo."},
			{"speaker": "garota_desconhecida", "event": "tower:flight", "text": "Esperem! Vocês não entendem..."},
			{"speaker": "", "type": "narration", "text": "Os dois desapareceram na direção do topo da torre. Por um instante, só houve silêncio."},
			{"speaker": "", "type": "narration", "event": "tower:gate_burst", "text": "Uma pancada veio de dentro. Depois outra. Na terceira, os portões explodiram para fora."},
			{"speaker": "general_gueist", "event": "tower:boss_reveal", "text": "Vocês chegaram longe demais."},
			{"speaker": "guerreiro", "text": "Saia do caminho. Vamos buscar a garota."},
			{"speaker": "general_gueist", "text": "Minha ordem é simples."},
			{"speaker": "general_gueist", "text": "Ninguém atravessa estes portões."},
			{"speaker": "general_gueist", "text": "Se desejam entrar... terão de passar por mim."}
		]
	},
	"epilogo_gueist": {
		"lines": [
			{"speaker": "", "type": "narration", "event": "tower:epilogue", "text": "Gueist caiu de joelhos diante da entrada destruída."},
			{"speaker": "general_gueist", "text": "Vocês..."},
			{"speaker": "general_gueist", "text": "Não sabem o que estão tentando libertar..."},
			{"speaker": "", "type": "narration", "event": "tower:open_path", "text": "O general tombou. Os portões permaneceram destruídos. Além deles, uma escadaria parecia não ter fim."},
			{"speaker": "", "type": "narration", "text": "A menina estava viva."},
			{"speaker": "", "type": "narration", "text": "O caminho para encontrá-la finalmente estava aberto."},
			{"speaker": "", "type": "narration", "text": "Mas a torre guardava muito mais do que os heróis poderiam imaginar."},
			{"speaker": "", "type": "narration", "event": "tower:finale", "text": "FIM DO PRÓLOGO\nTORRE DOS HERÓIS"}
		]
	},
	"fragmento_luz_andar_3": {
		"presentation": "light_fragment",
		"first": "fragmento_luz_andar_3_inicio",
		"lines": [
			{"id": "fragmento_luz_andar_3_inicio", "speaker": "", "name": "LUZ ENTRE AS PEDRAS", "type": "narration", "text": "Um brilho dourado pulsa entre as raízes. Por um instante, parece esperar por alguém.", "choices": [
				{"text": "Tocar o fragmento", "next": "fragmento_luz_andar_3_memoria"},
				{"text": "Seguir em frente", "event": "fragment:ignore:fragmento_luz_andar_3"}
			]},
			{"id": "fragmento_luz_andar_3_memoria", "speaker": "", "name": "FRAGMENTO DE LUZ", "type": "narration", "event": "fragment:found:fragmento_luz_andar_3", "text": "Alguém segurou minha mão naquele dia... Lembro-me de prometer que tudo ficaria bem.", "end": true}
		]
	},
	"fragmento_luz_andar_8": {
		"presentation": "light_fragment",
		"first": "fragmento_luz_andar_8_inicio",
		"lines": [
			{"id": "fragmento_luz_andar_8_inicio", "speaker": "", "name": "LUZ ENTRE AS PEDRAS", "type": "narration", "text": "Um fragmento dourado flutua no ar. A luz vacila, como se guardasse uma lembrança.", "choices": [
				{"text": "Tocar o fragmento", "next": "fragmento_luz_andar_8_memoria"},
				{"text": "Seguir em frente", "event": "fragment:ignore:fragmento_luz_andar_8"}
			]},
			{"id": "fragmento_luz_andar_8_memoria", "speaker": "", "name": "FRAGMENTO DE LUZ", "type": "narration", "event": "fragment:found:fragmento_luz_andar_8", "text": "Por um instante, senti uma solidão que não era minha. Era como se alguém tivesse passado a eternidade esperando por algo que nunca conheceu.", "end": true}
		]
	},
	"demo_narrativa": {
		"skippable_when_seen": true,
		"first": "guerreiro_1",
		"lines": [
			{"id": "guerreiro_1", "scene_id": "demo_narrativa", "speaker": "guerreiro", "type": "dialogue", "text": "Há algo estranho naquele lugar...", "side": "left", "next": "bruxa_1"},
			{"id": "bruxa_1", "scene_id": "demo_narrativa", "speaker": "bruxa", "type": "dialogue", "text": "Consigo sentir magia até daqui. Mas não se parece com nada que conheço.", "side": "right", "next": "narrador_1"},
			{"id": "narrador_1", "scene_id": "demo_narrativa", "speaker": "", "name": "NARRADOR", "portrait": "", "type": "narration", "text": "A torre permanecia imóvel sob as nuvens.", "end": true}
		]
	}
}


static func get_scene(id: String) -> Dictionary:
	var scene: Dictionary = SCENES.get(id, {}).duplicate(true)
	if scene.is_empty():
		return {}
	var lines: Array = scene.get("lines", [])
	for index in lines.size():
		var entry: Dictionary = lines[index]
		if not entry.has("id"):
			entry["id"] = "%s_%02d" % [id, index + 1]
		entry["scene_id"] = id
		if not entry.has("next") and not entry.has("end") and entry.get("choices", []).is_empty():
			entry["next"] = "%s_%02d" % [id, index + 2] if index + 1 < lines.size() else ""
			if index + 1 == lines.size():
				entry["end"] = true
		lines[index] = entry
	if not scene.has("first") and not lines.is_empty():
		scene["first"] = str(lines[0]["id"])
	return scene
