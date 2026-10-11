# Torre dos Heróis

Jogo de fantasia com combates por turnos, dez andares, escolhas de rota, progressão permanente e cenas narrativas, desenvolvido em Godot.

## Abrir e jogar

1. Abra `project.godot` no Godot 4.7 ou mais recente.
2. Pressione **F5** para iniciar.

O progresso usa três espaços independentes em `user://torre_save_slot_1.json`, `user://torre_save_slot_2.json` e `user://torre_save_slot_3.json`. O salvamento antigo é migrado com backup.

## Estrutura

- `data/`: heróis, inimigos, habilidades, encontros, cartas e narrativa.
- `systems/`: regras de combate, estado da tentativa, progressão, áudio e salvamento.
- `scripts/`: interface e apresentação do jogo.
- `assets/`: imagens, fontes, áudio e shaders usados pelo projeto.
- `tests/`: scripts de validação do projeto.

O projeto inclui um preset para exportação Windows em `export_presets.cfg`. Os arquivos de exportação gerados não fazem parte do repositório.

As relíquias permanentes e da expedição são descritas em [RELICS_V41.md](RELICS_V41.md).
