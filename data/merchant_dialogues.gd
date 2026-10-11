extends RefCounted

const CAMP_TOPICS := {
	"origin": {
		"label": "Como se tornou comerciante",
		"lines": [
			{"id": "camp_origin_01", "text": "Comecei trocando mapas por refeições. Depois passei a trocar refeições por mapas. A vida é feita de negociações."},
			{"id": "camp_origin_02", "text": "Uma carroça, duas rodas teimosas e um talento raro para chegar depois que o perigo passa."},
			{"id": "camp_origin_03", "text": "No começo, eu vendia coisas de que ninguém precisava. Agora vendo coisas de que todos precisam. Progresso!"}
		],
		"repeat": "Se eu contar mais, vou ter de cobrar pela história. E hoje estou fazendo uma promoção."
	},
	"region": {
		"label": "O que sabe sobre a região",
		"lines": [
			{"id": "camp_region_01", "text": "As ruínas a leste parecem seguras. O que, naturalmente, significa que não são."},
			{"id": "camp_region_02", "text": "Quando o vento muda perto da torre, os pássaros ficam quietos. Eu também, se puder."},
			{"id": "camp_region_03", "text": "Há trilhas que aparecem depois da chuva. Não pergunte para onde levam. Já perguntei."
			}
		],
		"repeat": "A região continua cheia de caminhos, pedras e coisas que preferem não ser encontradas."
	},
	"tower": {
		"label": "Os perigos da torre",
		"lines": [
			{"id": "camp_tower_01", "text": "A torre gosta de testar a pressa. E a paciência. E, pelo que ouvi, a arquitetura."},
			{"id": "camp_tower_02", "text": "Não confiem em silêncio demais. Às vezes é só um corredor esperando vocês passarem."},
			{"id": "camp_tower_03", "text": "Já vi gente entrar com mapas excelentes. Nenhum mapa sobreviveu ao primeiro andar."
			}
		],
		"repeat": "Levem poções, prestem atenção às intenções dos inimigos e tentem não discutir com as escadas."
	},
	"travels": {
		"label": "Histórias de suas viagens",
		"lines": [
			{"id": "camp_travels_01", "text": "Uma vez vendi uma bússola a um homem que jurava nunca se perder. Ele voltou para comprar outra."},
			{"id": "camp_travels_02", "text": "Já percorri tantas estradas que às vezes esqueço em qual século estou. Heh, força do hábito."},
			{"id": "camp_travels_03", "text": "Conheci alguém que acreditava poder salvar todo mundo. Uma pessoa extraordinária... e terrivelmente teimosa."}
		],
		"repeat": "Minha melhor história ainda está acontecendo. A pior envolve uma mula e três barris de geleia."
	},
	"advice": {
		"label": "Conselho para a próxima batalha",
		"lines": [
			{"id": "camp_advice_01", "text": "Guardem energia para quando ela fizer diferença. Parece óbvio. Raramente é."},
			{"id": "camp_advice_02", "text": "Um inimigo enfraquecido ainda pode acertar. Um inimigo derrotado, por outro lado, costuma ser mais cooperativo."},
			{"id": "camp_advice_03", "text": "Algumas dívidas não se pagam com ouro, aventureiro. Mas aceito ouro para as outras."
			}
		],
		"repeat": "Respirem, observem o campo e tentem sair da luta com o mesmo número de membros."
	},
	"recognition": {
		"label": "O comerciante reconhece vocês",
		"unlock_losses": 1,
		"lines": [
			{"id": "camp_recognition_01", "text": "Eu conheço esses passos. E esse jeito de olhar para a estrada como se ela já tivesse cobrado um preço."},
			{"id": "camp_recognition_02", "text": "Vocês voltaram. A maioria prefere chamar isso de coragem. Eu ainda estou decidindo o nome."},
			{"id": "camp_recognition_03", "text": "Não precisam se apresentar outra vez. Algumas pessoas deixam uma impressão difícil de esquecer."
			}
		],
		"repeat": "É bom ver rostos conhecidos por aqui. A fogueira também parece menos silenciosa."
	},
	"returning": {
		"label": "Morrer e voltar",
		"unlock_losses": 3,
		"lines": [
			{"id": "camp_returning_01", "text": "A morte deve estar ficando cansada de vocês. Ou talvez esteja apenas aprendendo a esperar."},
			{"id": "camp_returning_02", "text": "Há quem passe a vida tentando evitar o mesmo fim. Vocês parecem preferir discutir com ele."},
			{"id": "camp_returning_03", "text": "Voltar tantas vezes muda a forma de caminhar. Não deixem que mude aquilo pelo que caminham."
			}
		],
		"repeat": "Se vão insistir em voltar, ao menos descansem um pouco antes de insistir de novo."
	},
	"promises": {
		"label": "Promessas antigas",
		"unlock_losses": 5,
		"lines": [
			{"id": "camp_promises_01", "text": "Certas promessas continuam acesas mesmo quando quem as fez já não está por perto."},
			{"id": "camp_promises_02", "text": "Às vezes, uma dívida atravessa gerações. Não está no livro-caixa, claro. Esses são os piores tipos."},
			{"id": "camp_promises_03", "text": "Se encontrarem alguém esperando há muito tempo, talvez escutem antes de perguntar o motivo."
			}
		],
		"repeat": "Promessas antigas não gostam de pressa. Nem de serem esquecidas."
	},
	"cycle": {
		"label": "O peso de continuar",
		"unlock_losses": 8,
		"lines": [
			{"id": "camp_cycle_01", "text": "Há noites em que a estrada parece lembrar cada passo de quem já passou por ela."},
			{"id": "camp_cycle_02", "text": "Continuar não apaga o que aconteceu. Mas talvez dê a essas lembranças um lugar para descansar."},
			{"id": "camp_cycle_03", "text": "Eu já vi esperanças se apagarem. Algumas voltam diferentes. Ainda assim, iluminam o caminho."
			}
		],
		"repeat": "Fiquem mais um pouco junto ao fogo. Até os caminhos mais longos precisam de uma pausa."
	}
}

const RETURN_GREETINGS := [
	"Ora, ora... Achei que não veria vocês novamente. Que surpresa agradável.",
	"Outra tentativa? Admiro sua persistência. A maioria teria desistido há muito tempo.",
	"Tenho certeza de que desta vez dará certo. Bem... estatisticamente, alguma vez precisa dar.",
	"Engraçado como algumas pessoas continuam seguindo o mesmo caminho, não importa quantas vezes ele termine mal.",
	"A morte nem sempre significa o fim de uma promessa. Enfim... alguém quer ver mercadorias?"
]


static func encounter_scene(encounters: int, losses: int, attempts: int, seen_dialogues: Dictionary) -> Dictionary:
	if encounters <= 0:
		return preload("res://data/narrative_scenes.gd").get_scene("encontro_comerciante")
	var preferred := 0
	if losses >= 4:
		preferred = 1
	elif attempts >= 4:
		preferred = 2
	var greeting_index := -1
	for offset in RETURN_GREETINGS.size():
		var candidate: int = (preferred + offset) % RETURN_GREETINGS.size()
		if not bool(seen_dialogues.get("merchant_greeting_%02d" % candidate, false)):
			greeting_index = candidate
			break
	var line: Dictionary
	if greeting_index < 0:
		line = {"id": "merchant_return_greeting_repeat", "speaker": "comerciante", "text": "Ora, vocês outra vez. A estrada anda com um senso de humor peculiar.", "next": "merchant_return_reaction"}
	else:
		var greeting_id := "merchant_greeting_%02d" % greeting_index
		line = {"id": "merchant_return_greeting", "speaker": "comerciante", "text": RETURN_GREETINGS[greeting_index], "event": "memory:%s" % greeting_id, "next": "merchant_return_reaction"}
	var reaction := {"id": "merchant_return_reaction", "speaker": "patrulheiro", "text": "Vocês se conhecem?", "next": "merchant_return_reply"}
	var reply := {"id": "merchant_return_reply", "speaker": "comerciante", "text": "Digamos que tenho boa memória para clientes interessantes.", "next": "merchant_return_invite"}
	var invite := {"id": "merchant_return_invite", "speaker": "comerciante", "text": "Tenho algumas mercadorias interessantes no meu acampamento, não muito longe daqui. Gostariam de dar uma olhada?", "choices": [
		{"text": "Claro, por que não?", "event": "camp:accept"},
		{"text": "Por que deveríamos confiar em você?", "next": "merchant_return_doubt"},
		{"text": "Agora não, obrigado.", "event": "camp:decline"}
	]}
	var doubt := {"id": "merchant_return_doubt", "speaker": "comerciante", "text": "Confiar é uma palavra muito grande. Fiquem à vontade para olhar e partir.", "choices": [
		{"text": "Claro, por que não?", "event": "camp:accept"},
		{"text": "Agora não, obrigado.", "event": "camp:decline"}
	]}
	return {"first": "merchant_return_greeting", "lines": [line, reaction, reply, invite, doubt]}


static func camp_line(topic_id: String, seen_dialogues: Dictionary, losses: int) -> Dictionary:
	var topic: Dictionary = CAMP_TOPICS.get(topic_id, {})
	if topic.is_empty():
		return {"text": "O comerciante dá de ombros. 'Uma boa conversa sempre vale a pena.'", "id": ""}
	var lines: Array = topic.get("lines", [])
	for line in lines:
		if not bool(seen_dialogues.get(str(line["id"]), false)):
			return {"id": str(line["id"]), "text": str(line["text"]), "unique": true}
	var repeat_text: String = str(topic.get("repeat", ""))
	if losses >= 5 and topic_id == "advice":
		repeat_text = "Já perderam bastante para saber que a próxima batalha merece respeito. Mas ainda há caminho."
	return {"id": "", "text": repeat_text, "unique": false}


static func camp_lines_remaining(topic_id: String, seen_dialogues: Dictionary) -> int:
	var topic: Dictionary = CAMP_TOPICS.get(topic_id, {})
	var remaining := 0
	for line in topic.get("lines", []):
		if not bool(seen_dialogues.get(str(line.get("id", "")), false)):
			remaining += 1
	return remaining


static func unlocked_camp_topics(losses: int) -> Dictionary:
	var unlocked: Dictionary = {}
	for topic_id in CAMP_TOPICS:
		var threshold := int(CAMP_TOPICS[topic_id].get("unlock_losses", 0))
		if losses >= threshold:
			unlocked[topic_id] = true
	return unlocked
