extends Control

signal close_requested

const Guard = preload("res://systems/dev_guard.gd")
const Ops = preload("res://systems/dev_operations.gd")
const Heroes = preload("res://data/heroes.gd")
const Skills = preload("res://data/skills.gd")
const Cards = preload("res://data/cards.gd")
const Relics = preload("res://data/relics.gd")
const Progression = preload("res://systems/permanent_progression.gd")

const TABS := ["Perfil", "Progressão", "Torre", "Equipe", "Combate", "Recursos", "Narrativa", "Áudio", "Predefinições"]
const INK := Color("111923")
const GOLD := Color("e9c477")
const LIGHT := Color("eef0ed")
const MUTED := Color("a6b7c6")

var controller: Node
var current_tab := "Perfil"
var selected_hero := "guerreiro"
var selected_fighter := ""
var selected_card := "robusto"
var selected_relic := "medalhao_vital"
var team_selection: Array[String] = ["guerreiro", "bruxa", "sacerdotisa"]
var _body: VBoxContainer
var _status: Label
var _feedback: Label
var _window: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_shell()
	if controller != null:
		controller.changed.connect(_refresh)
	_refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F9, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		close_requested.emit()


func _frame(color: Color, border: Color = GOLD) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 13
	box.content_margin_bottom = 13
	return box


func _build_shell() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window = PanelContainer.new()
	_window.name = "DeveloperWindow"
	_window.anchor_left = 0.06
	_window.anchor_right = 0.94
	_window.anchor_top = 0.04
	_window.anchor_bottom = 0.96
	_window.add_theme_stylebox_override("panel", _frame(Color("172431")))
	add_child(_window)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	_window.add_child(layout)
	var title_row := HBoxContainer.new()
	layout.add_child(title_row)
	var title := _label("PAINEL DO DESENVOLVEDOR", 23, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close := _button("FECHAR  F9")
	close.pressed.connect(func() -> void: close_requested.emit())
	title_row.add_child(close)
	_status = _label("", 12, MUTED)
	layout.add_child(_status)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 5)
	tabs.add_theme_constant_override("v_separation", 4)
	layout.add_child(tabs)
	for tab_name in TABS:
		var tab := _button(tab_name)
		tab.custom_minimum_size = Vector2(85, 32)
		tab.pressed.connect(_select_tab.bind(tab_name))
		tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 9)
	scroll.add_child(_body)
	_feedback = _label("F9 ou Esc fecha o painel.", 12, GOLD)
	layout.add_child(_feedback)


func _label(value: String, size: int = 13, color: Color = LIGHT) -> Label:
	var node := Label.new()
	LocaleManager.set_text(node, value)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


func _button(value: String) -> Button:
	var node := Button.new()
	LocaleManager.set_text(node, value)
	node.custom_minimum_size = Vector2(112, 34)
	node.add_theme_font_size_override("font_size", 12)
	node.add_theme_color_override("font_color", LIGHT)
	node.add_theme_stylebox_override("normal", _frame(Color("283b4a"), Color("536f79")))
	node.add_theme_stylebox_override("hover", _frame(Color("3c5361"), GOLD))
	return node


func _header(value: String, detail: String = "") -> void:
	_body.add_child(_label(value.to_upper(), 18, GOLD))
	if not detail.is_empty():
		_body.add_child(_label(detail, 12, MUTED))


func _row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 7)
	row.add_theme_constant_override("v_separation", 5)
	_body.add_child(row)
	return row


func _add_button(row: Control, title: String, action: Callable, needs_dev: bool = true) -> Button:
	var node := _button(title)
	node.disabled = needs_dev and not controller.active()
	node.pressed.connect(func() -> void:
		var result: Variant = action.call()
		LocaleManager.set_text(_feedback, "%s: %s" % [title, "feito" if result == true else "não aplicado"])
		_refresh()
	)
	row.add_child(node)
	return node


func _spin(value: int, minimum: int, maximum: int, width: float = 105.0) -> SpinBox:
	var field := SpinBox.new()
	field.min_value = minimum
	field.max_value = maximum
	field.step = 1
	field.value = clampi(value, minimum, maximum)
	field.custom_minimum_size.x = width
	field.add_theme_font_size_override("font_size", 13)
	return field


func _option(items: Array, current: String) -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(195, 35)
	for index in items.size():
		picker.add_item(LocaleManager.localize(str(items[index])), index)
		picker.set_item_metadata(index, items[index])
	var position := items.find(current)
	picker.select(maxi(0, position))
	return picker


func _confirm(title: String, message: String, action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.title = LocaleManager.localize(title)
	dialog.dialog_text = LocaleManager.localize(message)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		var ok: Variant = action.call()
		LocaleManager.set_text(_feedback, "%s: %s" % [title, "feito" if ok == true else "não aplicado"])
		_refresh()
	)
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free()
	)
	dialog.popup_centered()


func _select_tab(tab_name: String) -> void:
	current_tab = tab_name
	_refresh()


func _refresh() -> void:
	if controller == null or _body == null:
		return
	var game: Control = controller.game
	var profile_name := "DEV ISOLADO" if controller.active() else "NORMAL · somente leitura"
	var context := "menu"
	if game.narrative.active:
		context = "diálogo"
	elif game.run.has_attempt():
		context = str(game.run.attempt.get("phase", "expedição"))
	var floor_number := str(game.run.attempt.get("floor", "—"))
	var team: String = ", ".join(game.run.attempt.get("hero_ids", [])) if game.run.has_attempt() else "sem equipe"
	LocaleManager.set_text(_status, "PERFIL: %s  |  CONTEXTO: %s  |  ANDAR: %s  |  EQUIPE: %s" % [profile_name, context, floor_number, team])
	for child in _body.get_children():
		child.queue_free()
		_body.remove_child(child)
	match current_tab:
		"Perfil": _build_profile()
		"Progressão": _build_progression()
		"Torre": _build_tower()
		"Equipe": _build_team()
		"Combate": _build_combat()
		"Recursos": _build_resources()
		"Narrativa": _build_narrative()
		"Áudio": _build_audio()
		"Predefinições": _build_presets()
	for row in _body.get_children():
		if row is HFlowContainer:
			for item in row.get_children():
				if item is Label:
					item.autowrap_mode = TextServer.AUTOWRAP_OFF


func _require_dev() -> bool:
	if controller.active():
		return true
	_body.add_child(_label("Ative ou retome um perfil DEV na aba Perfil para liberar estas ferramentas.", 14, MUTED))
	return false


func _build_profile() -> void:
	_header("Perfis isolados", "O perfil normal nunca recebe alterações realizadas no DEV.")
	_body.add_child(_label("Normal: %s" % controller.profile.normal_path, 11, MUTED))
	_body.add_child(_label("DEV: %s" % controller.profile.dev_path, 11, MUTED))
	var row := _row()
	var start := _button("Iniciar teste · copiar normal")
	start.disabled = controller.active()
	start.pressed.connect(func() -> void:
		if controller.profile.has_test_profile():
			_confirm("Substituir perfil DEV", "A cópia anterior e seu estado inicial serão substituídos pelos dados normais atuais.", controller.start_copy)
		else:
			var ok: bool = controller.start_copy()
			LocaleManager.set_text(_feedback, "Iniciar teste: %s" % ("feito" if ok else "não aplicado"))
			_refresh()
	)
	row.add_child(start)
	_add_button(row, "Retomar perfil DEV", controller.resume, false).disabled = controller.active() or not controller.profile.has_test_profile()
	if controller.active():
		var more := _row()
		var restore := _button("Restaurar estado inicial")
		restore.pressed.connect(func() -> void: _confirm("Restaurar perfil DEV", "As mudanças DEV serão substituídas pela cópia inicial deste teste.", controller.restore_initial))
		more.add_child(restore)
		var reset := _button("Reiniciar perfil DEV vazio")
		reset.pressed.connect(func() -> void: _confirm("Reiniciar perfil DEV", "Criar um perfil de testes limpo? O perfil normal permanecerá intacto.", controller.reset_blank))
		more.add_child(reset)
		_add_button(more, "Voltar ao perfil normal", controller.return_normal)


func _build_progression() -> void:
	_header("Progressão permanente", "Níveis e habilidades compradas usam a curva e os custos oficiais.")
	if not _require_dev():
		return
	var picker := _option(Heroes.ORDER, selected_hero)
	picker.item_selected.connect(func(index: int) -> void:
		selected_hero = str(picker.get_item_metadata(index))
		_refresh()
	)
	_row().add_child(picker)
	var entry: Dictionary = controller.game.run.permanent["classes"][selected_hero]
	var level := int(entry["level"])
	var spent := Progression.invested_points(entry["attributes"])
	var skills_cost := Progression.special_cost(entry["unlocked_specials"])
	_body.add_child(_label("Nível %d  |  XP total %d  |  próximo %d  |  pontos totais %d  |  livres %d  |  atributos %d  |  habilidades %d" % [level, int(entry["xp"]), Progression.xp_required(level), level - 1, int(entry["available_points"]), spent, skills_cost], 13))
	var levels := _row()
	levels.add_child(_label("Nível", 13))
	var level_field := _spin(level, 1, 20)
	levels.add_child(level_field)
	_add_button(levels, "−", func() -> bool: return _apply_level(level - 1))
	_add_button(levels, "+", func() -> bool: return _apply_level(level + 1))
	_add_button(levels, "Aplicar nível", func() -> bool: return _apply_level(int(level_field.value)))
	var xp_row := _row()
	xp_row.add_child(_label("XP total", 13))
	var xp_field := _spin(int(entry["xp"]), 0, Ops.total_xp_for(20), 140)
	xp_row.add_child(xp_field)
	_add_button(xp_row, "−100 XP", func() -> bool: return _apply_xp(int(entry["xp"]) - 100))
	_add_button(xp_row, "+100 XP", func() -> bool: return _apply_xp(int(entry["xp"]) + 100))
	_add_button(xp_row, "Aplicar XP", func() -> bool: return _apply_xp(int(xp_field.value)))
	var attr_row := _row()
	_add_button(attr_row, "Redefinir atributos", func() -> bool:
		_confirm("Redefinir atributos", "Reembolsar todos os pontos investidos em atributos desta classe no perfil DEV?", controller.reset_attributes.bind(selected_hero))
		return true
	)
	for attribute_id in Progression.ORDER:
		if attribute_id == "mana" and not Progression.uses_mana(selected_hero):
			continue
		var row := _row()
		row.add_child(_label("%s: %d / 5" % [Progression.DEFINITIONS[attribute_id]["name"], int(entry["attributes"][attribute_id])], 13))
		_add_button(row, "Investir +1", controller.spend_attribute.bind(selected_hero, attribute_id))
	_body.add_child(_label("HABILIDADES ESPECIAIS · compra normal / liberação forçada", 14, GOLD))
	var forced: Array = controller.game.run.permanent.get("dev_forced_specials", {}).get(selected_hero, [])
	for skill_id in Skills.SPECIALS[selected_hero]:
		var skill: Dictionary = Skills.DEFINITIONS[skill_id]
		var state := "COMPRADA" if skill_id in entry["unlocked_specials"] else ("FORÇADA" if skill_id in forced else "BLOQUEADA")
		_body.add_child(_label("%s · nível %d · %d pontos · %s" % [skill["name"], skill["level"], skill["point_cost"], state], 12))
		var row := _row()
		_add_button(row, "Comprar", controller.set_special.bind(selected_hero, skill_id, "buy"))
		_add_button(row, "Forçar", controller.set_special.bind(selected_hero, skill_id, "force"))
		_add_button(row, "Bloquear", controller.set_special.bind(selected_hero, skill_id, "block"))
	var specials_row := _row()
	_add_button(specials_row, "Forçar todas", controller.force_all_specials.bind(selected_hero))
	_add_button(specials_row, "Restaurar desbloqueios", controller.restore_specials.bind(selected_hero))


func _apply_level(level: int) -> bool:
	if level < 1 or level > 20:
		return false
	if Ops.level_needs_reset(controller.game.run, selected_hero, level):
		_confirm("Reduzir nível", "Os pontos investidos e habilidades normais que excedem o novo nível serão reembolsados no perfil DEV.", controller.set_level.bind(selected_hero, level))
		return true
	return controller.set_level(selected_hero, level)


func _apply_xp(amount: int) -> bool:
	var level := Ops.level_for_total_xp(amount)
	if Ops.level_needs_reset(controller.game.run, selected_hero, level):
		_confirm("Reduzir XP", "O novo nível exige reembolsar investimentos e habilidades normais no perfil DEV.", controller.set_xp.bind(selected_hero, amount))
		return true
	return controller.set_xp(selected_hero, amount)


func _build_tower() -> void:
	_header("Navegação da torre", "Os encontros e rotas vêm dos dados oficiais. Saltos não concedem recompensas.")
	if not _require_dev():
		return
	var current := int(controller.game.run.attempt.get("floor", 1))
	var row := _row()
	row.add_child(_label("Andar", 13))
	var floor_field := _spin(current, 1, 10)
	row.add_child(floor_field)
	var preserve := CheckBox.new()
	LocaleManager.set_text(preserve, "Preservar equipe e recursos")
	preserve.button_pressed = true
	row.add_child(preserve)
	var story := CheckBox.new()
	LocaleManager.set_text(story, "Exibir cena do andar")
	row.add_child(story)
	_add_button(row, "Ir", func() -> bool: return controller.jump_floor(int(floor_field.value), preserve.button_pressed, story.button_pressed))
	var moves := _row()
	_add_button(moves, "Andar anterior", controller.jump_floor.bind(maxi(1, current - 1), true, false))
	_add_button(moves, "Próximo andar", controller.jump_floor.bind(mini(10, current + 1), true, false))
	_add_button(moves, "Reiniciar andar", controller.jump_floor.bind(current, true, false))
	_add_button(moves, "Chefe final", controller.jump_floor.bind(10, true, false))
	_body.add_child(_label("Rota atual: %s  |  Histórico: %s" % [str(controller.game.run.attempt.get("current_route", "—")), str(controller.game.run.attempt.get("route_history", {}))], 11, MUTED))
	_body.add_child(_label("Ao saltar, o primeiro caminho válido de cada bifurcação alcançada é escolhido sem conceder recompensas.", 11, MUTED))


func _build_team() -> void:
	_header("Equipe de teste", "Selecione de 1 a 3 classes. Aplicar reinicia o encontro com composição válida.")
	if not _require_dev():
		return
	var options := _row()
	for hero_id in Heroes.ORDER:
		var checkbox := CheckBox.new()
		LocaleManager.set_text(checkbox, Heroes.DEFINITIONS[hero_id]["name"])
		checkbox.button_pressed = hero_id in team_selection
		checkbox.toggled.connect(func(pressed: bool) -> void:
			if pressed and not hero_id in team_selection:
				team_selection.append(hero_id)
			elif not pressed:
				team_selection.erase(hero_id)
		)
		options.add_child(checkbox)
	var row := _row()
	var preserve := CheckBox.new()
	LocaleManager.set_text(preserve, "Preservar heróis já presentes")
	preserve.button_pressed = true
	row.add_child(preserve)
	_add_button(row, "Aplicar equipe", func() -> bool: return controller.set_team(team_selection, preserve.button_pressed))
	_add_button(row, "Recuperar todos", controller.restore_resources)
	if controller.game.combat.hero_ids.is_empty():
		return
	for hero_id in controller.game.combat.hero_ids:
		var hero: Dictionary = controller.game.combat.fighters[hero_id]
		_body.add_child(_label("%s · %s · %d/%d PV · %d/%d mana" % [hero["name"], hero["state"], hero["hp"], hero["max_hp"], hero.get("mana", 0), hero.get("mana_max", 0)], 13, GOLD))
		var states := _row()
		for condition in ["healthy", "low", "downed", "veneno", "fraqueza"]:
			_add_button(states, condition, controller.set_condition.bind(hero_id, condition))


func _build_combat() -> void:
	_header("Combate e inimigos", "Alterações de PV não encerram o turno; use os botões de resultado para finalizar.")
	if not _require_dev():
		return
	var combat = controller.game.combat
	if combat.order.is_empty() or not controller.game.run.has_attempt() or controller.game.run.attempt.get("phase", "") != "combat":
		_body.add_child(_label("Abra um combate pela aba Torre ou Equipe.", 13, MUTED))
		return
	var fighter_ids: Array[String] = []
	fighter_ids.assign(combat.order)
	if selected_fighter.is_empty() or not selected_fighter in fighter_ids:
		selected_fighter = fighter_ids[0]
	var picker := _option(fighter_ids, selected_fighter)
	picker.item_selected.connect(func(index: int) -> void:
		selected_fighter = str(picker.get_item_metadata(index))
		_refresh()
	)
	_row().add_child(picker)
	var fighter: Dictionary = combat.fighters[selected_fighter]
	_body.add_child(_label("%s · %s · %d/%d PV · %d/%d mana" % [fighter["name"], fighter["state"], fighter["hp"], fighter["max_hp"], fighter.get("mana", 0), fighter.get("mana_max", 0)], 13))
	var values := _row()
	var hp_field := _spin(int(fighter["hp"]), 1 if fighter["team"] == "enemy" else 0, int(fighter["max_hp"]))
	values.add_child(_label("PV", 13))
	values.add_child(hp_field)
	_add_button(values, "Definir PV", func() -> bool: return controller.edit_fighter(selected_fighter, "hp", int(hp_field.value)))
	if fighter["team"] == "hero":
		var mana_field := _spin(int(fighter.get("mana", 0)), 0, int(fighter.get("mana_max", 0)))
		values.add_child(_label("Mana", 13))
		values.add_child(mana_field)
		_add_button(values, "Definir mana", func() -> bool: return controller.edit_fighter(selected_fighter, "mana", int(mana_field.value)))
	var damage_row := _row()
	var amount_field := _spin(10, 1, int(fighter["max_hp"]))
	damage_row.add_child(amount_field)
	_add_button(damage_row, "Dano controlado", func() -> bool: return controller.edit_fighter(selected_fighter, "hp", int(combat.fighters[selected_fighter]["hp"]) - int(amount_field.value)))
	_add_button(damage_row, "Cura controlada", func() -> bool: return controller.edit_fighter(selected_fighter, "hp", int(combat.fighters[selected_fighter]["hp"]) + int(amount_field.value)))
	var repairs := _row()
	_add_button(repairs, "Reiniciar combate", controller.restart_combat)
	_add_button(repairs, "Restaurar recursos", controller.restore_resources)
	_add_button(repairs, "Remover negativos", controller.clear_negative_effects)
	_add_button(repairs, "Zerar recargas", controller.reset_cooldowns)
	var results := _row()
	_add_button(results, "Prévia vitória", controller.force_result.bind("victory", false))
	_add_button(results, "Prévia derrota", controller.force_result.bind("defeat", false))
	_add_button(results, "Vitória completa DEV", controller.force_result.bind("victory", true))
	_add_button(results, "Derrota completa DEV", controller.force_result.bind("defeat", true))


func _build_resources() -> void:
	_header("Recursos da expedição", "Cartas e relíquias oficiais; os bônus são recalculados pelas regras existentes.")
	if not _require_dev():
		return
	if not controller.game.run.has_attempt():
		_body.add_child(_label("Crie uma expedição de teste primeiro.", 13, MUTED))
		return
	var attempt: Dictionary = controller.game.run.attempt
	var row := _row()
	row.add_child(_label("Nível temporário", 13))
	var level_field := _spin(int(attempt["level"]), 1, 11)
	row.add_child(level_field)
	row.add_child(_label("XP", 13))
	var xp_field := _spin(int(attempt["xp"]), 0, 99)
	row.add_child(xp_field)
	_add_button(row, "Aplicar", func() -> bool: return controller.set_temporary(int(level_field.value), int(xp_field.value)))
	var team: Array[String] = []
	team.assign(attempt["hero_ids"])
	if not selected_hero in team:
		selected_hero = team[0]
	var hero_picker := _option(team, selected_hero)
	hero_picker.item_selected.connect(func(index: int) -> void:
		selected_hero = str(hero_picker.get_item_metadata(index))
		_refresh()
	)
	_row().add_child(hero_picker)
	var card_ids: Array[String] = []
	for card_id in Cards.DEFINITIONS:
		if Cards.DEFINITIONS[card_id]["class"] in ["", selected_hero]:
			card_ids.append(card_id)
	if not selected_card in card_ids:
		selected_card = card_ids[0]
	var cards_row := _row()
	var card_picker := _option(card_ids, selected_card)
	card_picker.item_selected.connect(func(index: int) -> void: selected_card = str(card_picker.get_item_metadata(index)))
	cards_row.add_child(card_picker)
	var card_level := 0
	for hero in attempt["heroes"]:
		if hero["id"] == selected_hero:
			card_level = int(hero["cards"].get(selected_card, 0))
	var card_field := _spin(card_level, 0, 3)
	cards_row.add_child(card_field)
	_add_button(cards_row, "Aplicar carta 0–III", func() -> bool: return controller.set_card(selected_hero, selected_card, int(card_field.value)))
	_body.add_child(_label("0 remove a carta. I–III definem seu nível.", 11, MUTED))
	var relic_ids: Array[String] = []
	for relic_id in Relics.DEFINITIONS:
		relic_ids.append(relic_id)
	var relic_row := _row()
	var relic_picker := _option(relic_ids, selected_relic)
	relic_picker.item_selected.connect(func(index: int) -> void: selected_relic = str(relic_picker.get_item_metadata(index)))
	relic_row.add_child(relic_picker)
	var bearer_options: Array = ["grupo"]
	bearer_options.append_array(team)
	var bearer_picker := _option(bearer_options, team[0])
	relic_row.add_child(bearer_picker)
	var mode_picker := _option(["permanent", "temporary"], "temporary")
	relic_row.add_child(mode_picker)
	_add_button(relic_row, "Conceder cópia", func() -> bool: return controller.grant_relic(selected_relic, str(mode_picker.get_item_metadata(mode_picker.selected))))
	_add_button(relic_row, "Equipar cópia", func() -> bool: return controller.equip_relic(selected_relic, "" if Relics.DEFINITIONS[selected_relic].get("scope", "hero") == "team" or str(bearer_picker.get_item_metadata(bearer_picker.selected)) == "grupo" else str(bearer_picker.get_item_metadata(bearer_picker.selected)), str(mode_picker.get_item_metadata(mode_picker.selected))))
	_add_button(relic_row, "Remover cópia", func() -> bool: return controller.remove_relic(selected_relic, str(mode_picker.get_item_metadata(mode_picker.selected))))
	var clear_row := _row()
	_add_button(clear_row, "Limpar bônus temporários", controller.clear_temporary)
	_body.add_child(_label("Equipadas: %s" % str(attempt["relics"]), 11, MUTED))
	_body.add_child(_label("Inventário permanente: %d · temporário: %d" % [controller.game.run.permanent.get("relic_inventory", []).size(), attempt.get("relic_inventory", []).size()], 11, MUTED))


func _build_narrative() -> void:
	_header("Cenas narrativas", "Prévia usa roteiros oficiais e retorna ao contexto DEV sem conceder recompensas.")
	if not _require_dev():
		return
	var scenes := [
		["Introdução da torre", "intro_reino"], ["Pai da garota", "encontro_pai"],
		["Comerciante", "encontro_comerciante"], ["Comerciante · reencontro", "merchant_reunion"],
		["Fragmento de Luz · andar 3", "fragmento_luz_andar_3"], ["Fragmento de Luz · andar 8", "fragmento_luz_andar_8"],
		["Entrada da torre · completa", "entrada_torre"],
		["Figura alada", "figura_alada"], ["Entrada de Gueist", "entrada_gueist"],
		["Epílogo de Gueist", "epilogo_gueist"], ["Primeira derrota", "ressurreicao_primeira"],
		["Derrota · escuridão", "ressurreicao_darkness"], ["Derrota · rara", "ressurreicao_rare"]
	]
	for entry in scenes:
		_add_button(_row(), str(entry[0]), controller.preview_scene.bind(str(entry[1])))


func _build_audio() -> void:
	_header("Música e efeitos sonoros", "Preferências de volume e pontos de loop são mantidos.")
	if not _require_dev():
		return
	var game: Control = controller.game
	_body.add_child(_label("Trilha ativa: %s  |  Música %.0f%%  |  SFX %.0f%%  |  Ambiente %.0f%%" % [game.music_manager.current_track, game.audio_manager.volume_percent("Music"), game.audio_manager.volume_percent("SFX"), game.audio_manager.volume_percent("Ambience")], 13))
	var tracks := _row()
	for track in ["C", "B", "A"]:
		_add_button(tracks, "Faixa %s" % track, controller.request_track.bind(track))
	var controls := _row()
	_add_button(controls, "Reiniciar trilha", controller.restart_track)
	_add_button(controls, "Parar teste", controller.stop_track)
	_add_button(controls, "Restaurar trilha", controller.restore_track)
	_body.add_child(_label("Efeitos por categoria", 13, GOLD))
	for category in [["Interface", ["hover", "click", "confirm", "invalid", "hero_select", "route", "attribute", "unlock"]], ["Combate", ["sword", "bow", "arrow", "physical_hit", "critical_hit", "shield"]], ["Magia", ["arcane_cast", "magic_projectile", "magic_hit", "fire_cast", "fire_burst", "curse", "heal", "holy", "revive"]], ["Jornada", ["xp_gain", "level_up", "card", "relic", "floor_clear", "expedition_start", "defeat", "final_victory"]]]:
		_body.add_child(_label(str(category[0]), 12, MUTED))
		var row := _row()
		for sound_id in category[1]:
			_add_button(row, str(sound_id), controller.play_sfx.bind(str(sound_id)))


func _build_presets() -> void:
	_header("Predefinições rápidas", "Ajuste andar e nível antes de abrir cenários DEV. O chefe final usa sempre o andar 10.")
	if not _require_dev():
		return
	for entry in [["Bruxa · Vampirismo · Gueist", "witch12", 10], ["Equipe completa · combate comum", "full", 3], ["Chefe final · andar 10", "boss", 10], ["Suporte · cura e reanimação", "support", 3], ["Derrota narrativa", "defeat", 1]]:
		var row := _row()
		var floor_field: SpinBox = null
		if str(entry[1]) != "boss":
			floor_field = _spin(int(entry[2]), 1, 10)
			row.add_child(_label("Andar", 12))
			row.add_child(floor_field)
		var level_field: SpinBox = null
		if str(entry[1]) == "witch12":
			level_field = _spin(12, 1, 20)
			row.add_child(_label("Nível", 12))
			row.add_child(level_field)
		var preset_key: String = str(entry[1])
		_add_button(row, str(entry[0]), func() -> bool: return controller.preset(preset_key, int(floor_field.value) if floor_field != null else 10, int(level_field.value) if level_field != null else 12))
