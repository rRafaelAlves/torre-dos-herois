extends RefCounted

const DEFINITIONS := {
	"goblin": {"name": "Goblin", "max_hp": 60, "damage": 10, "initiative": 15, "emblem": "G", "physical_resist": 0.0, "magical_resist": 0.0},
	"esqueleto": {"name": "Esqueleto", "max_hp": 50, "damage": 12, "initiative": 8, "emblem": "E", "physical_resist": 0.05, "magical_resist": 0.10, "special": "golpe_enfraquecedor"},
	"orc": {"name": "Orc", "max_hp": 82, "damage": 14, "initiative": 10, "emblem": "O", "physical_resist": 0.12, "magical_resist": 0.0},
	"cultista": {"name": "Cultista", "max_hp": 56, "damage": 11, "initiative": 17, "emblem": "C", "physical_resist": 0.0, "magical_resist": 0.15},
	"guardiao": {"name": "General Gueist", "max_hp": 220, "damage": 20, "initiative": 13, "emblem": "G", "physical_resist": 0.15, "magical_resist": 0.15, "special": "onda_sombria"},
}


static func get_definition(enemy_id: String) -> Dictionary:
	return DEFINITIONS.get(enemy_id, {}).duplicate(true)
