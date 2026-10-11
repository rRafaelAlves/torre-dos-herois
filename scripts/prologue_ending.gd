extends Control

signal menu_requested
signal quit_requested

const TOWER_GATE_OPEN = preload("res://assets/backgrounds/entrada_torre_aberta.png")
const TITLE_FONT = preload("res://assets/fonts/cinzel_title.res")
const Stars = preload("res://scripts/prologue_stars.gd")
const GOLD := Color("d9b36b")
const PALE := Color("eee8dc")
const MUTED := Color("a8b3c4")
const PANEL_COLOR := Color("d90a101b")

var _phase := "intro"
var _dialogue_index := 0
var _background: TextureRect
var _darken: ColorRect
var _stars: Control
var _dialogue_panel: PanelContainer
var _dialogue_label: Label
var _credits_clip: Control
var _credits_content: VBoxContainer
var _end_card: VBoxContainer
var _credits_tween: Tween
var _credit_speed := 1.0
var _final_actions: HBoxContainer
var _skip_button: Button
var _speed_button: Button

const DIALOGUE := [
	"Você está chegando tão perto...",
	"Agradeço por sua coragem, herói."
]
const CREDIT_BLOCKS := [
	["TORRE DOS HERÓIS", "Prólogo"],
	["Idealização e Desenvolvimento", "Alguém aí"],
	["Programação auxiliar", "Codex"],
	["Arte visual", "ChatGPT"],
	["Direção criativa", "Muita teimosia e café"],
	["Trilha sonora", "ChatGPT"],
	["Vocal experimental", "Mimosa Dark"],
	["Dubladores", "Carinha que mora logo ali"],
	["Testes de dificuldade", "Amigos que sofreram no andar 3"],
	["Balanceamento duvidoso", "O destino"],
	["Agradecimento especial", "A você, por jogar"],
	["Fim do Prólogo", ""]
]
const THANKS := "Obrigado por jogar o prólogo de Torre dos Heróis.\n\nEsta é apenas a primeira etapa da jornada.\nAinda há muitos mistérios a serem revelados, inimigos a enfrentar e verdades escondidas no topo da torre.\n\nSeu feedback e apoio são muito importantes para o futuro do projeto.\n\nNos vemos na próxima expedição."


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_scene()
	_play_intro()


func _build_scene() -> void:
	_background = TextureRect.new()
	_background.texture = TOWER_GATE_OPEN
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.pivot_offset = get_viewport_rect().size * 0.5

	_stars = Stars.new()
	_stars.name = "HopeStars"
	_stars.modulate.a = 0.0
	add_child(_stars)
	_stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_darken = ColorRect.new()
	_darken.color = Color(0.015, 0.02, 0.045, 0.0)
	_darken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_darken)
	_darken.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(_stars, get_child_count() - 1)

	_build_dialogue()
	_build_credits()
	_build_thanks_panel()
	_build_controls()


func _build_dialogue() -> void:
	_dialogue_panel = PanelContainer.new()
	_dialogue_panel.name = "UnknownGirlDialogue"
	_dialogue_panel.anchor_left = 0.16
	_dialogue_panel.anchor_right = 0.84
	_dialogue_panel.anchor_top = 0.37
	_dialogue_panel.anchor_bottom = 0.63
	_dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color("0c1423db"), Color("6c82b2"), 1, 10))
	_dialogue_panel.modulate.a = 0.0
	add_child(_dialogue_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 30)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	_dialogue_panel.add_child(margin)
	_dialogue_label = Label.new()
	_dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dialogue_label.add_theme_font_override("font", TITLE_FONT)
	_dialogue_label.add_theme_font_size_override("font_size", 30)
	_dialogue_label.add_theme_color_override("font_color", PALE)
	margin.add_child(_dialogue_label)


func _build_credits() -> void:
	_credits_clip = Control.new()
	_credits_clip.name = "RollingCredits"
	_credits_clip.clip_contents = true
	_credits_clip.anchor_left = 0.055
	_credits_clip.anchor_right = 0.47
	_credits_clip.anchor_top = 0.07
	_credits_clip.anchor_bottom = 0.91
	_credits_clip.visible = false
	add_child(_credits_clip)
	_credits_content = VBoxContainer.new()
	_credits_content.name = "CreditLines"
	_credits_content.anchor_left = 0.0
	_credits_content.anchor_right = 1.0
	_credits_content.add_theme_constant_override("separation", 14)
	_credits_clip.add_child(_credits_content)
	for index in range(CREDIT_BLOCKS.size()):
		var block: Array = CREDIT_BLOCKS[index]
		var heading := Label.new()
		LocaleManager.set_text(heading, str(block[0]))
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD
		heading.add_theme_font_override("font", TITLE_FONT)
		heading.add_theme_font_size_override("font_size", 24 if index in [0, CREDIT_BLOCKS.size() - 1] else 17)
		heading.add_theme_color_override("font_color", GOLD if index in [0, CREDIT_BLOCKS.size() - 1] else PALE)
		_credits_content.add_child(heading)
		if not str(block[1]).is_empty():
			var value := Label.new()
			LocaleManager.set_text(value, str(block[1]))
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			value.add_theme_font_size_override("font_size", 17)
			value.add_theme_color_override("font_color", MUTED)
			_credits_content.add_child(value)
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 25 if index == 0 else 12
		_credits_content.add_child(spacer)
	_end_card = VBoxContainer.new()
	_end_card.anchor_left = 0.055
	_end_card.anchor_right = 0.47
	_end_card.anchor_top = 0.38
	_end_card.anchor_bottom = 0.62
	_end_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_card.add_theme_constant_override("separation", 10)
	_end_card.visible = false
	add_child(_end_card)
	var end_title := Label.new()
	LocaleManager.set_text(end_title, "TORRE DOS HERÓIS")
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_title.add_theme_font_override("font", TITLE_FONT)
	end_title.add_theme_font_size_override("font_size", 26)
	end_title.add_theme_color_override("font_color", GOLD)
	_end_card.add_child(end_title)
	var end_subtitle := Label.new()
	LocaleManager.set_text(end_subtitle, "Fim do Prólogo")
	end_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_subtitle.add_theme_font_size_override("font_size", 16)
	end_subtitle.add_theme_color_override("font_color", PALE)
	_end_card.add_child(end_subtitle)


func _build_thanks_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "PrologueThanks"
	panel.anchor_left = 0.53
	panel.anchor_right = 0.945
	panel.anchor_top = 0.12
	panel.anchor_bottom = 0.86
	panel.add_theme_stylebox_override("panel", _panel_style(Color("0b111ce8"), Color("b08a51"), 2, 12))
	panel.visible = false
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 30)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 25)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)
	var eyebrow := Label.new()
	LocaleManager.set_text(eyebrow, "UMA JORNADA APENAS COMEÇOU")
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", TITLE_FONT)
	eyebrow.add_theme_font_size_override("font_size", 14)
	eyebrow.add_theme_color_override("font_color", GOLD)
	body.add_child(eyebrow)
	var title := Label.new()
	LocaleManager.set_text(title, "Obrigado por chegar até aqui")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", PALE)
	body.add_child(title)
	var rule := ColorRect.new()
	rule.color = Color("7c684b")
	rule.custom_minimum_size.y = 1
	body.add_child(rule)
	var message := Label.new()
	LocaleManager.set_text(message, THANKS)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 16)
	message.add_theme_color_override("font_color", PALE)
	body.add_child(message)
	_final_actions = HBoxContainer.new()
	_final_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	_final_actions.add_theme_constant_override("separation", 12)
	_final_actions.visible = false
	body.add_child(_final_actions)
	var menu_button := _make_button("Voltar ao menu")
	menu_button.pressed.connect(func(): menu_requested.emit())
	_final_actions.add_child(menu_button)
	var quit_button := _make_button("Fechar jogo")
	quit_button.pressed.connect(func(): quit_requested.emit())
	_final_actions.add_child(quit_button)


func _build_controls() -> void:
	_skip_button = _make_button("PULAR PARA O FIM  ·  ESC")
	_skip_button.anchor_left = 1.0
	_skip_button.anchor_right = 1.0
	_skip_button.anchor_top = 1.0
	_skip_button.anchor_bottom = 1.0
	_skip_button.offset_left = -250
	_skip_button.offset_right = -26
	_skip_button.offset_top = -64
	_skip_button.offset_bottom = -24
	_skip_button.pressed.connect(_skip_to_final)
	add_child(_skip_button)
	_speed_button = _make_button("ACELERAR CRÉDITOS  ·  ESPAÇO")
	_speed_button.anchor_left = 0.055
	_speed_button.anchor_right = 0.055
	_speed_button.anchor_top = 1.0
	_speed_button.anchor_bottom = 1.0
	_speed_button.offset_left = 0
	_speed_button.offset_right = 260
	_speed_button.offset_top = -64
	_speed_button.offset_bottom = -24
	_speed_button.visible = false
	_speed_button.pressed.connect(_toggle_credit_speed)
	add_child(_speed_button)


func _play_intro() -> void:
	_background.pivot_offset = size * 0.5
	var camera_tween := create_tween()
	camera_tween.set_parallel(true)
	camera_tween.tween_property(_background, "scale", Vector2(1.13, 1.13), 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_property(_darken, "color:a", 0.94, 8.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(7.6).timeout
	if not is_inside_tree() or _phase != "intro":
		return
	_phase = "dialogue"
	_stars.modulate.a = 1.0
	_show_dialogue(0)


func _show_dialogue(index: int) -> void:
	_dialogue_index = index
	LocaleManager.set_text(_dialogue_label, DIALOGUE[index])
	_dialogue_panel.visible = true
	var tween := create_tween()
	tween.tween_property(_dialogue_panel, "modulate:a", 1.0, 1.2)
	await get_tree().create_timer(5.0).timeout
	if _phase == "dialogue" and _dialogue_index == index:
		_advance_dialogue()


func _advance_dialogue() -> void:
	if _phase != "dialogue":
		return
	if _dialogue_index + 1 < DIALOGUE.size():
		_dialogue_panel.modulate.a = 0.0
		_show_dialogue(_dialogue_index + 1)
	else:
		_show_credits()


func _show_credits() -> void:
	if _phase == "credits" or _phase == "final":
		return
	_phase = "credits"
	_dialogue_panel.visible = false
	_credits_clip.visible = true
	get_node("PrologueThanks").visible = true
	_speed_button.visible = true
	await get_tree().process_frame
	if _phase != "credits":
		return
	_credits_content.position = Vector2(0, _credits_clip.size.y)
	var target_y := -_credits_content.size.y
	_credits_tween = create_tween()
	_credits_tween.tween_property(_credits_content, "position:y", target_y, 129.0).set_trans(Tween.TRANS_LINEAR)
	_credits_tween.finished.connect(_show_final_screen)


func _show_final_screen() -> void:
	if _phase == "final":
		return
	_phase = "final"
	if _credits_tween != null and _credits_tween.is_running():
		_credits_tween.kill()
	_speed_button.visible = false
	_skip_button.visible = false
	_dialogue_panel.visible = false
	_credits_clip.visible = false
	_final_actions.visible = true
	_end_card.visible = true
	var thanks := get_node_or_null("PrologueThanks") as Control
	if thanks != null:
		thanks.visible = true
		thanks.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(thanks, "modulate:a", 1.0, 1.0)


func _skip_to_final() -> void:
	if _phase == "final":
		return
	if _credits_tween != null and _credits_tween.is_running():
		_credits_tween.kill()
	if _phase == "intro" or _phase == "dialogue":
		get_node("PrologueThanks").visible = true
	else:
		_credits_content.position.y = -_credits_content.size.y
	_show_final_screen()


func _toggle_credit_speed() -> void:
	if _phase != "credits" or _credits_tween == null:
		return
	_credit_speed = 2.5 if is_equal_approx(_credit_speed, 1.0) else 1.0
	_credits_tween.set_speed_scale(_credit_speed)
	LocaleManager.set_text(_speed_button, "VELOCIDADE NORMAL  ·  ESPAÇO" if _credit_speed > 1.0 else "ACELERAR CRÉDITOS  ·  ESPAÇO")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_skip_to_final()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _phase == "dialogue":
			_advance_dialogue()
		elif _phase == "credits":
			_toggle_credit_speed()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if _phase == "credits":
			_toggle_credit_speed()
			get_viewport().set_input_as_handled()


func _make_button(caption: String) -> Button:
	var button := Button.new()
	LocaleManager.set_text(button, caption)
	button.custom_minimum_size = Vector2(190, 42)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", PALE)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_stylebox_override("normal", _panel_style(Color("1a202ae8"), Color("927445"), 1, 5))
	button.add_theme_stylebox_override("hover", _panel_style(Color("2a3140f2"), GOLD, 1, 5))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("090d15f2"), Color("d2ab64"), 2, 5))
	return button


func _panel_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style
