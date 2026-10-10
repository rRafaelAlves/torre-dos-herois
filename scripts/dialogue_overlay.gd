extends Control

signal advance_requested
signal skip_requested
signal exit_requested

const CharacterData = preload("res://data/narrative_characters.gd")
const PORTRAIT_FEATHER = preload("res://assets/narrative/portrait_feather.gdshader")
const INK := Color("101720")
const PAPER := Color("f5f1e8")

var characters_per_second := 36.0
var input_enabled := true
var presentation := "default"
var _full_text := ""
var _elapsed := 0.0
var _typing := false
var _last_advance_ms := 0
var _current_speaker := ""
var _shade: ColorRect
var _portrait: TextureRect
var _silhouette: Label
var _panel: PanelContainer
var _name_label: Label
var _body: RichTextLabel
var _continue: Label
var _accent_bar: ColorRect
var _skip_button: Button


func _ready() -> void:
	name = "DialogueOverlay"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	set_process(false)


func _build() -> void:
	_shade = ColorRect.new()
	_shade.color = Color(0.025, 0.045, 0.085, 0.53)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_material := ShaderMaterial.new()
	portrait_material.shader = PORTRAIT_FEATHER
	_portrait.material = portrait_material
	_portrait.anchor_left = 0.01
	_portrait.anchor_right = 0.49
	_portrait.anchor_top = 0.07
	_portrait.anchor_bottom = 0.82
	add_child(_portrait)
	_silhouette = Label.new()
	_silhouette.text = "RETRATO EM PREPARAÇÃO"
	_silhouette.add_theme_font_size_override("font_size", 18)
	_silhouette.add_theme_color_override("font_color", Color("c6c0b4"))
	_silhouette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_silhouette.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_silhouette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_silhouette)
	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.anchor_left = 0.035
	_panel.anchor_right = 0.965
	_panel.anchor_top = 0.675
	_panel.anchor_bottom = 0.97
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.065, 0.105, 0.15, 0.97)
	frame.border_color = Color("d5b96d")
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(4)
	frame.content_margin_left = 26
	frame.content_margin_right = 26
	frame.content_margin_top = 20
	frame.content_margin_bottom = 15
	_panel.add_theme_stylebox_override("panel", frame)
	add_child(_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	_panel.add_child(content)
	var top := HBoxContainer.new()
	content.add_child(top)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 23)
	_name_label.add_theme_color_override("font_color", Color("e3c477"))
	top.add_child(_name_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_skip_button = Button.new()
	_skip_button.text = "PULAR CENA"
	_skip_button.flat = true
	_skip_button.add_theme_font_size_override("font_size", 12)
	_skip_button.add_theme_color_override("font_color", Color("c3cbd0"))
	_skip_button.pressed.connect(func() -> void:
		if presentation == "resurrection":
			exit_requested.emit()
		else:
			skip_requested.emit()
	)
	top.add_child(_skip_button)
	_body = RichTextLabel.new()
	_body.name = "DialogueText"
	_body.add_theme_font_size_override("normal_font_size", 21)
	_body.add_theme_color_override("default_color", PAPER)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.scroll_active = true
	_body.bbcode_enabled = false
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_body)
	_continue = Label.new()
	_continue.text = "◆  AVANÇAR"
	_continue.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_continue.add_theme_font_size_override("font_size", 12)
	_continue.add_theme_color_override("font_color", Color("e3c477"))
	content.add_child(_continue)
	_accent_bar = ColorRect.new()
	_accent_bar.color = Color("d5b96d")
	_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_accent_bar.anchor_left = 0.035
	_accent_bar.anchor_right = 0.34
	_accent_bar.anchor_top = 0.664
	_accent_bar.anchor_bottom = 0.673
	add_child(_accent_bar)
	move_child(_accent_bar, _panel.get_index())


func show_line(entry: Dictionary) -> void:
	var speaker_id := str(entry.get("speaker", ""))
	var character: Dictionary = CharacterData.get_character(speaker_id)
	var kind := str(entry.get("type", "dialogue"))
	var display_name := str(entry.get("name", character.get("name", "NARRADOR")))
	_name_label.text = display_name.to_upper()
	var accent := Color(str(character.get("accent", "d5b96d")))
	_name_label.add_theme_color_override("font_color", accent)
	_accent_bar.color = Color("8296cf") if presentation == "resurrection" else accent
	var portrait_path := str(entry.get("portrait", character.get("portrait", "")))
	var expression := str(entry.get("expression", "neutral"))
	if expression != "neutral":
		portrait_path = str(character.get("expressions", {}).get(expression, portrait_path))
	_portrait.visible = presentation != "resurrection" and kind != "narration" and not portrait_path.is_empty() and ResourceLoader.exists(portrait_path)
	_portrait.texture = load(portrait_path) if _portrait.visible else null
	_silhouette.visible = presentation != "resurrection" and kind != "narration" and not _portrait.visible
	var side := str(entry.get("side", character.get("side", "left")))
	var left := side != "right"
	_portrait.anchor_left = 0.01 if left else 0.51
	_portrait.anchor_right = 0.49 if left else 0.99
	_silhouette.anchor_left = _portrait.anchor_left
	_silhouette.anchor_right = _portrait.anchor_right
	_silhouette.anchor_top = _portrait.anchor_top
	_silhouette.anchor_bottom = _portrait.anchor_bottom
	if speaker_id != _current_speaker and _portrait.visible:
		_portrait.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_portrait, "modulate:a", 1.0, 0.18)
	_current_speaker = speaker_id
	_full_text = str(entry.get("text", ""))
	_body.text = _full_text
	_body.add_theme_color_override("default_color", Color("cdd8e2") if kind == "thought" else PAPER)
	_body.visible_characters = 0
	_elapsed = 0.0
	_typing = true
	_continue.visible = false
	set_process(true)


func set_presentation(variant: String) -> void:
	presentation = variant
	if variant != "resurrection":
		return
	_shade.color = Color(0.005, 0.006, 0.016, 0.17)
	_panel.anchor_left = 0.13
	_panel.anchor_right = 0.87
	_panel.anchor_top = 0.59
	_panel.anchor_bottom = 0.86
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.035, 0.043, 0.075, 0.92)
	frame.border_color = Color("6879ad")
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(8)
	frame.content_margin_left = 30
	frame.content_margin_right = 30
	frame.content_margin_top = 22
	frame.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", frame)
	_accent_bar.anchor_left = 0.20
	_accent_bar.anchor_right = 0.80
	_accent_bar.anchor_top = 0.582
	_accent_bar.anchor_bottom = 0.588
	_accent_bar.color = Color("8296cf")
	_name_label.add_theme_color_override("font_color", Color("acbde7"))
	_skip_button.text = "MENU"
	_skip_button.visible = true
	_panel.modulate.a = 0.0
	_accent_bar.modulate.a = 0.0
	var fade := create_tween().set_parallel(true)
	fade.tween_property(_panel, "modulate:a", 1.0, 0.42)
	fade.tween_property(_accent_bar, "modulate:a", 1.0, 0.42)


func set_skip_allowed(allowed: bool) -> void:
	_skip_button.visible = true if presentation == "resurrection" else allowed


func _process(delta: float) -> void:
	if not _typing:
		return
	_elapsed += delta
	_body.visible_characters = mini(_body.get_total_character_count(), floori(_elapsed * characters_per_second))
	if _body.visible_characters >= _body.get_total_character_count():
		complete_text()


func complete_text() -> void:
	_typing = false
	_body.visible_characters = -1
	_continue.visible = true
	set_process(false)


func is_typing() -> bool:
	return _typing


func _input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.pressed and _skip_button.visible and _skip_button.get_global_rect().has_point(event.position):
		return
	if presentation == "resurrection" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		exit_requested.emit()
		return
	var advance := false
	if event is InputEventMouseButton:
		advance = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventKey:
		advance = event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_Z]
	elif event is InputEventJoypadButton:
		advance = event.pressed and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B]
	if not advance:
		return
	get_viewport().set_input_as_handled()
	var now := Time.get_ticks_msec()
	if now - _last_advance_ms < 100:
		return
	_last_advance_ms = now
	if _typing:
		complete_text()
	else:
		advance_requested.emit()
