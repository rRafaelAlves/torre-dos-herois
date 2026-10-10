# Torre dos Heróis

Jogo de fantasia com combates por turnos, dez andares, escolhas de rota, progressão permanente e cenas narrativas, desenvolvido em Godot.

## Abrir e jogar

1. Abra `project.godot` no Godot 4.7 ou mais recente.
2. Pressione **F5** para iniciar.

O progresso é salvo pelo Godot em `user://torre_v8_state.json`.

## Estrutura

- `data/`: heróis, inimigos, habilidades, encontros, cartas e narrativa.
- `systems/`: regras de combate, estado da tentativa, progressão, áudio e salvamento.
- `scripts/`: interface e apresentação do jogo.
- `assets/`: imagens, fontes, áudio e shaders usados pelo projeto.
- `tests/`: scripts de validação do projeto.

O projeto inclui um preset para exportação Windows em `export_presets.cfg`. Os arquivos de exportação gerados não fazem parte do repositório.
