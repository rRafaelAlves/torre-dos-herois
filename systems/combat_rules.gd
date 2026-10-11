extends RefCounted

const Heroes = preload("res://data/heroes.gd")
const StateEffects = preload("res://systems/state_effects.gd")
const Progression = preload("res://systems/permanent_progression.gd")
const Relics = preload("res://data/relics.gd")

const ROBUST_HP := [0.0, 0.15, 0.25, 0.35]
const ROBUST_RES := [0.0, 0.04, 0.06, 0.08]
const SPEED := [0.0, 0.15, 0.25, 0.35]
const POWER := [0.0, 0.10, 0.20, 0.30]
const PRECISION := [0.0, 0.05, 0.10, 0.15]
const RADIANT := [0.0, 0.15, 0.25, 0.35]
const HEAL := [0.0, 0.15, 0.25, 0.35]
const SPELL := [0.0, 0.10, 0.20, 0.30]
const PREDATOR := [0, 3, 5, 7]
const RETALIATION := [0, 4, 7, 10]


static func create_hero(hero_id: String, group_level: int, relics: Array, permanent_attributes: Dictionary = {}, unlocked_specials: Array = []) -> Dictionary:
	var definition: Dictionary = Heroes.get_definition(hero_id)
	var hero: Dictionary = definition.duplicate(true)
	hero["id"] = hero_id
	hero["team"] = "hero"
	hero["cards"] = {}
	hero["permanent_attributes"] = Progression.sanitized_attributes(permanent_attributes, hero_id)
	hero["unlocked_specials"] = Progression.sanitized_specials(unlocked_specials, hero_id)
	hero["hp"] = 0
	hero["mana"] = 0
	hero["state"] = "alive"
	hero["down_rounds"] = 0
	hero["down_start_round"] = 0
	hero["defending"] = false
	hero["cooldown_remaining"] = 0
	hero["cooldown_just_started"] = false
	recalculate(hero, group_level, relics)
	hero["hp"] = hero["max_hp"]
	hero["mana"] = hero["mana_max"]
	return hero


static func recalculate(hero: Dictionary, group_level: int, relics: Array) -> void:
	var definition: Dictionary = Heroes.get_definition(hero["id"])
	var cards: Dictionary = hero.get("cards", {})
	var raw_attributes: Dictionary = hero.get("permanent_attributes", {}) if typeof(hero.get("permanent_attributes")) == TYPE_DICTIONARY else {}
	var attributes: Dictionary = Progression.sanitized_attributes(raw_attributes, hero["id"])
	hero["permanent_attributes"] = attributes
	var robust: int = clampi(int(cards.get("robusto", 0)), 0, 3)
	var speedy: int = clampi(int(cards.get("veloz", 0)), 0, 3)
	var power: int = clampi(int(cards.get("poder", 0)), 0, 3)
	var precision: int = clampi(int(cards.get("precisao", 0)), 0, 3)
	var hp_bonus := 0.0
	var mana_bonus := 0
	var initiative_bonus := 0
	var physical_bonus := 0.0
	var magical_bonus := 0.0
	var physical_reduction := 0.0
	var magical_reduction := 0.0
	var heal_bonus := 0.0
	var crit_bonus := 0.0
	var poison_bonus := 0
	var basic_bonus := 0.0
	var has_stone := false
	for relic in relics:
		var relic_id: String = str(relic.get("id", ""))
		var relic_definition: Dictionary = Relics.DEFINITIONS.get(relic_id, {})
		if relic_definition.is_empty() or (relic_definition.get("scope", "hero") == "hero" and relic.get("bearer", "") != hero["id"]):
			continue
		match relic_id:
			"medalhao_vital": hp_bonus += 0.10
			"amuleto_carvalho": hp_bonus += 0.08
			"estandarte_vale": hp_bonus += 0.04
			"reserva_arcana": mana_bonus += 8
			"botas_vento", "relogio_vento": initiative_bonus += 1
			"punho_aco": physical_bonus += 0.06
			"cristal_prismatico": magical_bonus += 0.06
			"pedra_bastiao": physical_reduction += 0.06
			"egide_nevoa": magical_reduction += 0.06
			"simbolo_graca": heal_bonus += 0.10
			"olho_cacador": crit_bonus += 0.04
			"ferrao_esmeralda": poison_bonus += 1
			"insignia_guerreiro": basic_bonus += 0.10
			"pedra_arcana": has_stone = true
	var old_max_hp: int = int(hero.get("max_hp", 0))
	var old_max_mana: int = int(hero.get("mana_max", 0))
	var hp_base: int = int(definition["max_hp"]) + 5 * (group_level - 1) + 7 * int(attributes["vitalidade"])
	hero["max_hp"] = maxi(1, roundi(hp_base * (1.0 + ROBUST_HP[robust] + hp_bonus)))
	var mana_base: int = int(definition.get("mana_max", 0)) + 3 * int(attributes["mana"])
	hero["mana_max"] = (mana_base + 2 * (group_level - 1) if mana_base > 0 else 0) + mana_bonus
	hero["damage"] = int(definition["damage"]) + group_level - 1 + 3 * int(attributes["poder"])
	hero["initiative"] = maxi(1, roundi(float(int(definition["initiative"]) + int(attributes["agilidade"])) * (1.0 + SPEED[speedy])) + initiative_bonus)
	hero["physical_resist"] = ROBUST_RES[robust] + 0.02 * int(attributes["resistencia"])
	hero["magical_resist"] = ROBUST_RES[robust] + 0.02 * int(attributes["resistencia"])
	hero["basic_multiplier"] = 1.0 + POWER[power] + basic_bonus
	hero["physical_relic_multiplier"] = 1.0 + physical_bonus
	hero["magical_relic_multiplier"] = 1.0 + magical_bonus
	hero["physical_relic_reduction"] = clampf(physical_reduction, 0.0, 0.75)
	hero["magical_relic_reduction"] = clampf(magical_reduction, 0.0, 0.75)
	hero["poison_relic_bonus"] = poison_bonus
	hero["crit_chance"] = 0.05 + PRECISION[precision] + crit_bonus
	hero["radiant_fraction"] = RADIANT[clampi(int(cards.get("bruxaria_luminosa", 0)), 0, 3)]
	hero["heal_multiplier"] = 1.0 + HEAL[clampi(int(cards.get("graca_divina", 0)), 0, 3)] + heal_bonus
	hero["spell_multiplier"] = 1.0 + SPELL[clampi(int(cards.get("poder_elemental", 0)), 0, 3)]
	hero["predator_bonus"] = PREDATOR[clampi(int(cards.get("predador", 0)), 0, 3)]
	hero["retaliation_damage"] = RETALIATION[clampi(int(cards.get("retaliacao", 0)), 0, 3)]
	hero["arcane_stone"] = has_stone
	if old_max_hp > 0:
		hero["hp"] = clampi(int(hero.get("hp", 0)), 0, hero["max_hp"])
	if old_max_mana > 0:
		hero["mana"] = clampi(int(hero.get("mana", 0)), 0, hero["mana_max"])


static func damage_packet(attacker: Dictionary, target: Dictionary, base_amount: int, damage_type: String, basic: bool, spell: bool, critical_roll: float, raw_multiplier: float = 1.0, resistance_ignore: float = 0.0) -> Dictionary:
	var raw: float = float(base_amount) * raw_multiplier
	if basic:
		raw *= float(attacker.get("basic_multiplier", 1.0))
	if spell:
		raw *= float(attacker.get("spell_multiplier", 1.0))
	if damage_type == "physical":
		raw *= float(attacker.get("physical_relic_multiplier", 1.0))
	elif damage_type == "magical":
		raw *= float(attacker.get("magical_relic_multiplier", 1.0))
	if attacker.get("id", "") == "patrulheiro" and int(target["hp"]) < int(target["max_hp"]):
		raw += float(attacker.get("predator_bonus", 0))
	var weakness: Dictionary = StateEffects.get_effect(attacker, "fraqueza")
	if not weakness.is_empty():
		raw *= 1.0 - clampf(float(weakness.get("intensity", 0.25)), 0.0, 1.0)
	var instinct: Dictionary = StateEffects.get_effect(attacker, "instinto")
	var critical: bool = critical_roll < float(attacker.get("crit_chance", 0.0)) + float(instinct.get("intensity", 0.0))
	if critical:
		raw *= 1.5
	var radiant: int = 0
	if damage_type == "magical":
		radiant = roundi(raw * float(attacker.get("radiant_fraction", 0.0)))
	var resist: float = clampf(float(target.get("%s_resist" % damage_type, 0.0)), 0.0, 0.75)
	resist *= 1.0 - clampf(resistance_ignore, 0.0, 1.0)
	var amount: int = maxi(1, roundi((raw - radiant) * (1.0 - resist)) + radiant)
	amount = maxi(1, roundi(float(amount) * (1.0 - clampf(float(target.get("%s_relic_reduction" % damage_type, 0.0)), 0.0, 0.75))))
	var blocked: bool = bool(target.get("defending", false))
	if blocked:
		amount = maxi(1, ceili(float(amount) / 2.0))
	var fortaleza: Dictionary = StateEffects.get_effect(target, "fortaleza")
	if not fortaleza.is_empty():
		amount = maxi(1, roundi(float(amount) * (1.0 - float(fortaleza.get("intensity", 0.35)))))
	return {"amount": amount, "critical": critical, "radiant": radiant, "blocked": blocked}


static func heal_amount(actor: Dictionary, base_amount: int) -> int:
	return maxi(1, roundi(float(base_amount) * float(actor.get("heal_multiplier", 1.0))))
