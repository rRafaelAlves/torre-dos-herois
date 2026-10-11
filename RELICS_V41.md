# Relíquias V41

O catálogo em `data/relics.gd` contém 15 relíquias Simples, 10 Raras e 5 Épicas novas, além das três relíquias antigas. Cada definição contém nome, descrição, raridade e alcance (herói ou grupo). A modalidade pertence à cópia: o mesmo ID pode existir como permanente ou temporário.

O progresso permanente de cada espaço salvo guarda `relic_inventory`, `relic_equipped` e `last_relic_loadout`. A tentativa guarda `relic_inventory` temporário e `relics`, a lista efetivamente equipada no combate. Cada cópia tem um `uid` próprio. `systems/relic_equipment.gd` aplica os limites de 3 espaços individuais e 2 coletivos por modalidade e impede equipar a mesma cópia duas vezes.

Ao final da expedição, as cópias temporárias são descartadas. As permanentes seguem no inventário e a última configuração pode ser restaurada pela interface. Saves anteriores à V41 são carregados; as relíquias antigas de uma tentativa tornam-se cópias temporárias. A migração grava o formato V3 mantendo o arquivo anterior como `.bak`.

Para a loja da V42, `RunState.grant_relic(id, mode)` concede uma cópia e devolve seu UID; `RunState.equip_relic(uid, bearer_id, context)` a equipa. `mode` aceita `permanent` ou `temporary`. Em relíquias de grupo, `bearer_id` é vazio. Nenhum preço ou compra é tratado nessas funções.

Validação: `godot --headless --path . --script res://tests/test_relics_v41.gd`.
