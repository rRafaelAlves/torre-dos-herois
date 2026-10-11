# Sistema narrativo

## Referência visual

A capa `assets/menu/torre_capa_v19.png` é a referência principal. Os cinco retratos neutros estão em `assets/narrative/portraits/` e não alteram os sprites pixel art de combate.

Os PNGs possuem canal alfa, mas alguns ainda trazem cor de fundo pintada junto ao personagem. `assets/narrative/portrait_feather.gdshader` suaviza as bordas na interface; uma extração manual de silhueta poderá aperfeiçoar esses arquivos depois.

| Personagem | Referência da capa |
| --- | --- |
| Guerreiro | Armadura de aço, escudo azul/dourado, espada e capa vermelha. |
| Patrulheiro | Capa verde, couro, arco e postura vigilante. |
| Bruxa | Chapéu e traje violeta, cabelo claro e cajado arcano. |
| Sacerdotisa | Roupa branca e dourada, cabelo loiro e símbolo solar. |
| Feiticeiro | Manto azul com detalhes dourados e cajado de cristal. |

O pai da garota tem roupas humildes, cabelos e barba grisalhos e aparência cansada. O comerciante usa roupas de viagem em marrom e vinho, com olhar observador e postura cordial. A garota, a figura alada e o General Gueist têm retratos neutros registrados no mesmo catálogo. Seus sprites de cena e o sprite de combate de Gueist seguem a linguagem pixel art.

## Cadastrar personagem

Adicione um ID estável em `data/narrative_characters.gd` com `name`, `portrait`, `accent`, `side` e `expressions`. Um retrato ausente usa o placeholder. Para expressões futuras, adicione um caminho em `expressions` e use `expression` na fala; `neutral` continua sendo o retrato padrão.

## Cadastrar cena

Adicione uma entrada em `data/narrative_scenes.gd` com `first` e `lines`. Cada fala precisa de `id` e `text`; `speaker`, `name`, `portrait`, `side`, `type`, `pause`, `event`, `next`, `end` e `expression` são opcionais. Os tipos aceitos são `dialogue`, `narration` e `thought`. `next` aponta ao ID da fala seguinte; `end: true` encerra a cena. `event: "sfx:nome"` toca um efeito existente, e eventos `tower:*` acionam o diretor visual da entrada da torre.

Para iniciar uma cena no jogo, use `narrative.start("id_da_cena", self)` em `scripts/main_v8.gd`. Também é possível chamar `start_definition` com dados montados em tempo de execução. A cena de demonstração `demo_narrativa` é aberta com **F9** apenas em builds de desenvolvimento; ela não faz parte da campanha.

`user://narrative_seen.cfg` guarda apenas a conveniência de pular cenas já vistas. A progressão narrativa da campanha fica no arquivo de save permanente. Uma cena com `skippable_when_seen: true` pode ser pulada depois de vista. `characters_per_second` em `NarrativeController` configura a velocidade do texto. Música continua tocando, com redução temporária de 5 dB durante o diálogo.

## Encontros da campanha

`systems/story_flow.gd` escolhe a próxima cena antes do combate: `intro_reino` e `encontro_pai` antes do andar 1; `encontro_comerciante` antes do combate do andar 5; `entrada_torre` antes do combate do andar 10. `epilogo_gueist` aparece após vencer o chefe e antes da tela final. A fala `conselho_comerciante` está disponível como cena opcional para uma interação futura; ela não altera o encontro obrigatório. Todos os cinco heróis aparecem na história, mesmo quando só um a três estão na equipe de combate.

`permanent.narrative.completed_scenes` guarda cenas únicas da campanha. Prólogo, encontro com o pai, primeira conversa com o comerciante, revelação do andar 10 e epílogo não reiniciam entre expedições. O comerciante continua aparecendo antes do andar 5, com apresentações que consideram expedições e derrotas. `fragments_found` registra os fragmentos opcionais dos andares 3 e 8; `dialogues_seen` registra falas inéditas do comerciante. Esses registros são independentes do estado temporário da tentativa. Saves antigos só migram conclusões marcadas explicitamente; um save sem essa evidência mantém os registros vazios.

`attempt.narrative_seen`, `attempt.narrative_cursor` e `attempt.narrative_event_steps` continuam guardando o andamento da tentativa atual e os beats visuais necessários para retomar cenas interrompidas. O painel DEV pode rever as cenas sem alterar o histórico narrativo permanente. As recompensas continuam no fluxo existente de vitória.

## V34 — voz após a derrota

A derrota continua encerrando a tentativa e concedendo apenas as recompensas normais. O botão **Nova tentativa** da tela de resultados inicia `ressurreicao_primeira` ou uma fala curta selecionada em `systems/resurrection_flow.gd`. O sistema de diálogo V31 permanece responsável pelo texto progressivo, pelas pausas e pelos inputs. A apresentação `resurrection` de `DialogueOverlay` oculta retrato e silhueta, usa um painel escuro e permite sair ao menu sem apagar a cena pendente.

`permanent.narrative` guarda o histórico de mensagens já vistas, a mensagem pendente e a fala atual. A primeira mensagem continua exclusiva; mensagens alternativas não se repetem enquanto houver outras inéditas. Depois delas, a garota permanece em silêncio em vez de repetir falas. O registro é independente da tentativa e não modifica XP, moedas ou atributos. Uma cena interrompida é retomada pelo botão **Continuar** no menu. O efeito `revive` é reproduzido em volume baixo; a música é temporariamente atenuada sem alterar a preferência do jogador.

## V39 — memórias entre expedições

O estado narrativo permanente também mantém conclusões de cenas, fragmentos, diálogos inéditos e a quantidade de encontros com o comerciante. Conversar no acampamento oferece cinco assuntos; cada assunto mostra suas falas inéditas uma vez e continua disponível com comentários cotidianos depois que elas acabam. Os fragmentos dourados aparecem antes dos combates dos andares 3 e 8 somente até serem encontrados. O comerciante escolhe reencontros com base no histórico permanente de tentativas e derrotas.
