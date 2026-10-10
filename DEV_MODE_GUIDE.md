# Painel do Desenvolvedor — V35

O painel é uma ferramenta do editor Godot. Ele só é criado quando a execução tem as características `editor` e `debug`, sem a característica `template`. Exportações públicas e exportações de depuração usam template e não passam pela validação. O botão DEV, o atalho F9 e as operações de teste usam essa mesma proteção.

## Abrir e fechar

Execute o projeto pelo editor Godot. No menu principal, clique em **DEV**. Nas demais telas, inclusive no combate, pressione **F9**. Em teclados Mac que usam as teclas de função para controles do sistema, pressione **Fn + F9**. Feche com **F9**, **Esc** ou **FECHAR F9**. A árvore do jogo fica pausada enquanto o painel está aberto; ao fechar, a pausa anterior é restaurada.

## Perfis e salvamentos

Na aba **Perfil**, escolha **Iniciar teste · copiar normal**. O estado normal é copiado integralmente para dois arquivos separados, com os sufixos `.dev` e `.dev.baseline`. O painel passa a mostrar **DEV ISOLADO** e o jogo exibe a marca **PERFIL DEV · TESTES ISOLADOS**. Salvamentos automáticos, recompensas e resultados passam a usar o arquivo `.dev`.

- **Retomar perfil DEV** carrega o último teste depois de reabrir o projeto.
- **Restaurar estado inicial** recupera a cópia feita ao iniciar o teste.
- **Reiniciar perfil DEV vazio** cria dados de teste limpos. Há confirmação antes de apagar o estado de teste.
- **Voltar ao perfil normal** salva o teste no arquivo `.dev` e recarrega o arquivo normal. O retorno também funciona se o teste começou com uma expedição normal em andamento.

O arquivo normal usa o caminho de salvamento já configurado pelo jogo. Habilidades forçadas são persistidas e lidas apenas no perfil DEV; o carregamento normal ignora esses dados. Não copie arquivos `.dev` manualmente sobre o salvamento normal.

## Testes rápidos

- **Progressão:** escolha uma classe, defina nível de 1 a 20 ou XP total, invista pontos, compre habilidades pelas regras normais ou use **Forçar** para testá-las sem custo e sem requisito de nível. Uma redução que exige reembolso mostra confirmação. **Bloquear** remove a compra ou liberação forçada no teste.
- **Torre e equipe:** escolha o andar 1–10, preserve ou reinicie os recursos e monte de um a três heróis. Saltos criam rotas válidas sem conceder as recompensas dos andares pulados. **Exibir cena do andar** usa o fluxo narrativo correspondente.
- **Combate:** edite PV e mana, aplique dano ou cura controlados, configure condições dos heróis, limpe efeitos e recargas, reinicie o encontro ou abra uma prévia de vitória/derrota. **Vitória completa DEV** e **Derrota completa DEV** executam o fluxo real de finalização e registram recompensas somente no perfil de teste.
- **Recursos:** ajuste o nível e XP temporários, cartas oficiais de nível I–III e relíquias existentes. O valor zero remove uma carta. Os atributos derivados são recalculados pelas regras do combate.
- **Narrativa:** abra os roteiros oficiais, incluindo prólogo, comerciante, entrada da torre, Gueist, epílogo e variantes da garota desconhecida. A prévia retorna ao contexto de teste e não concede recompensas.
- **Áudio:** veja volumes e trilha ativa, toque as três faixas, reinicie ou restaure a trilha contextual e reproduza efeitos existentes por categoria.
- **Predefinições:** prepare rapidamente Bruxa com Vampirismo Arcano, equipe completa, chefe final, suporte com aliado caído ou derrota narrativa. Os campos disponíveis permitem ajustar nível e andar; o cenário de chefe usa sempre o andar 10.

## Validação

Execute os testes com `Godot --headless --path . --script res://tests/test_dev_v35.gd`. As 118 verificações usam apenas `user://torre_dev_v35_test.json` e removem os arquivos temporários ao final. Elas incluem clicar em **Definir PV** para aliado e inimigo e repetir o comando após sair da arena, verificando que a interface antiga não é acessada. Também foram executadas as suítes anteriores de V8, V27–V32 e narrativa V31–V34. Foram inspecionadas capturas renderizadas pelo Godot das abas Perfil, Progressão e Combate em 1100 × 760 e da aba Progressão em 800 × 600.

A validação automatizada verifica troca e persistência dos perfis, bytes idênticos do arquivo normal após operações DEV, progresso com expedição normal em andamento, limites de nível e XP, compra e liberação forçada de habilidades, andares, equipe, recursos, estados, resultados completos e prévias, cenas narrativas, áudio e predefinições. A verificação do bloqueio de exportação usa a função de autorização com combinações de características de build. Uma exportação pública real ainda precisa ser inspecionada quando houver preset e template de exportação instalados neste ambiente.
