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

O sistema registra cenas vistas em `user://narrative_seen.cfg`, separado do salvamento da campanha. Uma cena com `skippable_when_seen: true` pode ser pulada depois de vista. `characters_per_second` em `NarrativeController` configura a velocidade do texto. Música continua tocando, com redução temporária de 5 dB durante o diálogo.

## Encontros da campanha

`systems/story_flow.gd` escolhe a próxima cena antes do combate: `intro_reino` e `encontro_pai` antes do andar 1; `encontro_comerciante` antes do combate do andar 5; `entrada_torre` antes do combate do andar 10. `epilogo_gueist` aparece após vencer o chefe e antes da tela final. A fala `conselho_comerciante` está disponível como cena opcional para uma interação futura; ela não altera o encontro obrigatório. Todos os cinco heróis aparecem na história, mesmo quando só um a três estão na equipe de combate.

Cada tentativa salva suas cenas concluídas em `attempt.narrative_seen`. Isso impede repetições ao voltar ao menu ou usar “Continuar” e mantém cenas incompletas disponíveis após recarregar. Tentativas antigas já em combate no andar 10 continuam nessa batalha; as que chegam depois ao andar 10 veem a nova cena. Tentativas novas retomam a fala atual após recarregar. `attempt.narrative_cursor` guarda a fala e `attempt.narrative_event_steps` guarda os beats visuais concluídos para reconstruir a composição sem repetir ações. As recompensas só são aplicadas pelo fluxo de vitória existente. O menu tem **Rever introdução**, sem alterar o progresso da tentativa. Ao reiniciar, o prólogo pode ser pulado se já foi visto.

## V34 — voz após a derrota

A derrota continua encerrando a tentativa e concedendo apenas as recompensas normais. O botão **Nova tentativa** da tela de resultados inicia `ressurreicao_primeira` ou uma fala curta selecionada em `systems/resurrection_flow.gd`. O sistema de diálogo V31 permanece responsável pelo texto progressivo, pelas pausas e pelos inputs. A apresentação `resurrection` de `DialogueOverlay` oculta retrato e silhueta, usa um painel escuro e permite sair ao menu sem apagar a cena pendente.

`permanent.narrative` guarda a primeira cena vista, o contador narrativo, a última mensagem, a mensagem pendente e a fala atual. O registro é independente da tentativa e não modifica XP, moedas ou atributos. Uma cena interrompida é retomada pelo botão **Continuar** no menu. A mensagem rara só pode ser selecionada a partir da quarta derrota e nenhuma alternativa é repetida imediatamente. O efeito `revive` é reproduzido em volume baixo; a música é temporariamente atenuada sem alterar a preferência do jogador.
