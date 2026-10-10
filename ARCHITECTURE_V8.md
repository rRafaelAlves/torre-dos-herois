# Torre dos Heróis V13

## Habilidades expandidas V13

- data/heroes.gd lista a habilidade principal e as opções alternativas de cada classe; data/skills.gd mantém custos, alvo, efeito e recarga em um catálogo único.
- O motor separa recargas por habilidade e avança cada uma nos turnos próprios do herói. A interface cria botões apenas para as habilidades da equipe, mostra descrições, custos e recargas restantes e abre seleção apenas para habilidades que precisam de alvo.
- Guarda Protetora aplica 40% de redução ao próximo pacote de dano, sem acumular no mesmo alvo. Ela é consumida ao receber dano ou expira quando o Guerreiro inicia seu turno seguinte.
- Flecha Debilitante percorre o cálculo físico atual e aplica Fraqueza ao alvo sobrevivente. Purificação remove Veneno/Fraqueza de aliado vivo e cura até o máximo, sem reanimar. Onda Arcana chama o cálculo mágico existente uma vez para cada inimigo vivo e consome uma única ação.
- Essas habilidades e seus efeitos temporários vivem somente no combate; o formato e a migração dos saves não mudaram.

## Intenções e IA inimiga V12

- O motor em systems/combat_engine.gd mantém uma intenção revelada por inimigo, incluindo tipo, resumo e alvo individual quando aplicável. A ação e o alvo são planejados antes do turno; o alvo só é substituído caso deixe de estar vivo.
- A interface mostra a próxima ação em cada cartão inimigo e oculta a intenção quando o inimigo é derrotado.
- O Goblin mantém ataque básico; o Esqueleto alterna ataque básico e Golpe Enfraquecedor.
- O Guardião da Torre mantém a Onda Sombria e alterna seu ciclo com ataque básico, preparação visível e execução do Impacto Devastador no turno seguinte, com 50% a mais de dano físico.
- Intenções e preparações são estado do combate, não alteram o formato do save. Iniciar outra batalha cria planos novos e limpa preparação anterior.

## Preservado da V11

- Progressão permanente por classe, migração de save V1/V2, atributos investidos e cópia de atributos por tentativa continuam como documentado abaixo.

## Progressão permanente V11

- `systems/permanent_progression.gd` calcula a curva de XP por classe, o teto de nível 20 e os cinco atributos com limite de cinco pontos cada.
- O save usa versão 2. Ao carregar a versão 1, preserva XP total, nível conquistado, moedas, estatísticas, histórico e tentativa; a XP residual antiga passa a ser o progresso do nível migrado. Pontos disponíveis são derivados de `nível - 1 - pontos investidos`, então a migração não os concede novamente ao carregar.
- Saves legados com nível acima de 20 conservam o valor histórico em `legacy_level`; o nível utilizável respeita o teto 20.
- Cada nova tentativa grava uma cópia dos atributos permanentes em seus heróis. Recalcular atributos temporários ou distribuir pontos durante uma tentativa salva usa essa cópia até a próxima tentativa. Os PV e a mana atuais são limitados pelo novo máximo sem recuperação automática.
- O caminho do arquivo de save permanece `user://torre_v8_state.json` para que os dados existentes sejam encontrados e migrados.

## Preservado da V10

- `systems/state_effects.gd` centraliza definições, aplicação/renovação, consulta, atualização de duração, remoção e limpeza dos efeitos de estado.
- A duração avança uma vez ao fim do turno individual afetado. Veneno processa dano fixo no início do turno e Fraqueza reduz dano dentro de `combat_rules.gd`.
- Maldição Venenosa é uma segunda habilidade selecionável da Bruxa; Golpe Enfraquecedor é integrado à IA do Esqueleto; a V12 alterna essa ação com ataques básicos.
- Os efeitos são mantidos apenas no motor da batalha e removidos ao terminar; não alteram o formato dos arquivos de tentativa salvos.
- A interface mostra marcadores de efeitos junto às fichas, com a descrição no tooltip. O registro informa aplicação/renovação, ticks e expiração.

## Preservado da V9

- `data/cards.gd` e `data/relics.gd` também declaram o escopo do bônus e as condições relevantes.
- O painel **Bônus Ativos** da interface lê essas definições e os níveis/portadores atuais da tentativa; ele permite consultar heróis vivos, caídos e mortos sem consumir uma ação.
- A consulta pausa a IA inimiga até o painel ser fechado. Os registros identificam ativações condicionais que realmente ocorreram, sem registrar bônus passivos a cada ação.
- Validar regressão e V13 com o comando abaixo; a saída final esperada começa por `V13:`.

## Executar

Abra `project.godot` no Godot 4.7.2 no macOS e pressione **F5**. O jogo salva em `user://torre_v8_state.json`, no diretório de dados do usuário gerenciado pelo Godot.

Validação automatizada:

```sh
godot --headless --path . --script res://tests/test_v8.gd
```

## Organização

- `data/heroes.gd` e `data/skills.gd`: classes e habilidades.
- `data/enemies.gd` e `data/tower.gd`: inimigos, encontros dos 10 andares e rotas após os andares 1, 4 e 7.
- `data/cards.gd` e `data/relics.gd`: definições, descrições e opções válidas.
- `systems/combat_rules.gd`: cálculo central de atributos, dano, resistências, crítico e cura. Cartas e relíquias modificam os atributos neste ponto.
- `systems/combat_engine.gd` e `systems/state_effects.gd`: iniciativa, ações, IA, defesa, estados caído/efeitos, reanimação e fim de combate. Não contêm interface nem salvamento.
- `systems/permanent_progression.gd`: XP permanente, pontos por classe e limites dos atributos.
- `systems/run_state.gd`: nível e XP compartilhados, sequência de telas entre andares, cartas, relíquias, recompensas, progressão permanente e resumo.
- `systems/save_store.gd`: JSON versionado e gravação por arquivo temporário seguida de renomeação.
- `scripts/main_v8.gd`: interface com elementos nativos do Godot. `main.tscn` carrega este script.

## Ciclo da tentativa

O campo `phase` da tentativa representa `between`, `combat`, `cards`, `reward`, `relic`, `route` ou `won`. Ao entrar em um combate, o jogo salva os recursos dos heróis **antes** da batalha. Ao reabrir durante uma batalha, reconstrói o encontro desde esse ponto. Após a vitória, salva a cada escolha concluída. No fim, registra XP e moedas permanentes e remove a tentativa ativa em uma única gravação, evitando uma segunda concessão.

O nível interno começa em 1. Cada vitória concede 100 XP e um nível interno; os marcos 5 e 10 abrem uma escolha individual de carta para cada herói escolhido. Cartas usam níveis I–III e recalculam atributos a partir dos valores básicos, de modo que a evolução substitui o efeito anterior. O nível permanente de cada classe usa sua própria curva e seus pontos passam a modificar novas tentativas.

## Preservação da V7

O projeto recebido não possuía repositório Git. Os arquivos centrais da V7 foram copiados para `.v7-backup/` antes da implementação da V8.
