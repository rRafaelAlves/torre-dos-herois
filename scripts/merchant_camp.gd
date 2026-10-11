extends Control

signal leave_requested
signal equipment_requested
signal shop_requested

const TITLE_FONT = preload("res://assets/fonts/cinzel_title.res")
const FireAnimation = preload("res://scripts/merchant_camp_fire.gd")
const MerchantDialogues = preload("res://data/merchant_dialogues.gd")
const GOLD := Color("e8c57e")
const PAPER := Color("f3f0e8")

var _menu: PanelContainer
var _notice: PanelContainer
var _notice_text: Label
var _new_dialogue_marker: Control
var _notice_tween: Tween
var _seen_dialogues: Dictionary = {}
var _unlocked_topics: Dictionary = {}
var _losses: int = 0

signal dialogue_seen_requested(dialogue_id: String)


func configure(seen_dialogues: Dictionary, losses: int, unlocked_topics: Dictionary = {}) -> void:
	_seen_dialogues = seen_dialogues.duplicate(true)
	_losses = maxi(0, losses)
	_unlocked_topics = unlocked_topics.duplicate(true)
	if _unlocked_topics.is_empty():
		_unlocked_topics = MerchantDialogues.unlocked_camp_topics(_losses)
	_refresh_new_dialogue_marker()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _panel_style() -> StyleBoxFlat:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.055, 0.085, 0.12, 0.92)
	frame.border_color = Color("b79659", 0.86)
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(5)
	frame.content_margin_left = 18
	frame.content_margin_right = 18
	frame.content_margin_top = 13
	frame.content_margin_bottom = 13
	return frame


func _build() -> void:
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", _panel_style())
	header.anchor_left = 0.035
	header.anchor_right = 0.50
	header.anchor_top = 0.04
	header.anchor_bottom = 0.14
	add_child(header)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", 4)
	header.add_child(heading)
	var title := Label.new()
	LocaleManager.set_text(title, "ACAMPAMENTO DO COMERCIANTE")
	title.add_theme_font_override("font", TITLE_FONT)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", GOLD)
	heading.add_child(title)
	var hint := Label.new()
	LocaleManager.set_text(hint, "Clique na barraca ou no comerciante para interagir.")
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", PAPER)
	heading.add_child(hint)

	var fire: Control = FireAnimation.new()
	fire.name = "CampfireAnimation"
	fire.anchor_left = 0.53
	fire.anchor_right = 0.53
	fire.anchor_top = 0.74
	fire.anchor_bottom = 0.74
	fire.offset_left = -44
	fire.offset_right = 44
	fire.offset_top = -56
	fire.offset_bottom = 38
	fire.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fire)

	_add_hotspot("TentHotspot", 0.68, 0.98, 0.38, 0.83)
	_add_hotspot("MerchantHotspot", 0.68, 0.78, 0.56, 0.82)
	_build_new_dialogue_marker()

	_menu = PanelContainer.new()
	_menu.name = "MerchantInteractionMenu"
	_menu.add_theme_stylebox_override("panel", _panel_style())
	_menu.anchor_left = 0.56
	_menu.anchor_right = 0.91
	_menu.anchor_top = 0.22
	_menu.anchor_bottom = 0.54
	_menu.visible = false
	add_child(_menu)
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 7)
	_menu.add_child(options)
	_populate_main_menu(options)

	_notice = PanelContainer.new()
	_notice.name = "MerchantCampNotice"
	_notice.add_theme_stylebox_override("panel", _panel_style())
	_notice.anchor_left = 0.20
	_notice.anchor_right = 0.80
	_notice.anchor_top = 0.87
	_notice.anchor_bottom = 0.96
	_notice.visible = false
	add_child(_notice)
	_notice_text = Label.new()
	_notice_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_notice_text.add_theme_font_size_override("font_size", 13)
	_notice_text.add_theme_color_override("font_color", PAPER)
	_notice.add_child(_notice_text)


func _add_hotspot(id: String, left: float, right: float, top: float, bottom: float) -> void:
	var hotspot := Button.new()
	hotspot.name = id
	hotspot.anchor_left = left
	hotspot.anchor_right = right
	hotspot.anchor_top = top
	hotspot.anchor_bottom = bottom
	LocaleManager.set_tooltip(hotspot, "Interagir com o comerciante")
	hotspot.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxEmpty.new()
	hotspot.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.9, 0.69, 0.36, 0.055)
	hover.border_color = Color(0.88, 0.71, 0.43, 0.30)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(5)
	hotspot.add_theme_stylebox_override("hover", hover)
	hotspot.add_theme_stylebox_override("pressed", hover)
	hotspot.pressed.connect(_open_menu)
	add_child(hotspot)


func _build_new_dialogue_marker() -> void:
	_new_dialogue_marker = Control.new()
	_new_dialogue_marker.name = "MerchantNewDialogueMarker"
	_new_dialogue_marker.anchor_left = 0.74
	_new_dialogue_marker.anchor_right = 0.74
	_new_dialogue_marker.anchor_top = 0.56
	_new_dialogue_marker.anchor_bottom = 0.56
	_new_dialogue_marker.offset_left = -18
	_new_dialogue_marker.offset_right = 18
	_new_dialogue_marker.offset_top = -48
	_new_dialogue_marker.offset_bottom = -6
	_new_dialogue_marker.pivot_offset = Vector2(18, 21)
	_new_dialogue_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_new_dialogue_marker.z_index = 2
	add_child(_new_dialogue_marker)
	var tail := Polygon2D.new()
	tail.position = Vector2(12, 28)
	tail.polygon = PackedVector2Array([Vector2(0, 0), Vector2(12, 0), Vector2(6, 8)])
	tail.color = Color("caa45e")
	_new_dialogue_marker.add_child(tail)
	var badge := PanelContainer.new()
	badge.name = "QuestExclamationBadge"
	badge.position = Vector2(1, 0)
	badge.size = Vector2(34, 34)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("211a13", 0.96)
	badge_style.border_color = Color("efca79")
	badge_style.set_border_width_all(2)
	badge_style.set_corner_radius_all(17)
	badge_style.shadow_color = Color("edbd62", 0.48)
	badge_style.shadow_size = 7
	badge.add_theme_stylebox_override("panel", badge_style)
	_new_dialogue_marker.add_child(badge)
	var exclamation := Label.new()
	LocaleManager.set_text(exclamation, "!")
	exclamation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exclamation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exclamation.add_theme_font_size_override("font_size", 23)
	exclamation.add_theme_color_override("font_color", Color("ffe19a"))
	exclamation.add_theme_color_override("font_outline_color", Color("120e0b"))
	exclamation.add_theme_constant_override("outline_size", 2)
	badge.add_child(exclamation)
	_refresh_new_dialogue_marker()
	if _has_unheard_dialogues():
		var float_tween := create_tween().set_loops()
		float_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		float_tween.tween_property(_new_dialogue_marker, "scale", Vector2(1.08, 1.08), 0.72)
		float_tween.tween_property(_new_dialogue_marker, "scale", Vector2.ONE, 0.72)


func _has_unheard_dialogues() -> bool:
	for topic_id in MerchantDialogues.CAMP_TOPICS:
		if not bool(_unlocked_topics.get(topic_id, false)):
			continue
		if MerchantDialogues.camp_lines_remaining(str(topic_id), _seen_dialogues) > 0:
			return true
	return false


func _refresh_new_dialogue_marker() -> void:
	if _new_dialogue_marker != null and is_instance_valid(_new_dialogue_marker):
		var interaction_menu_open := _menu != null and is_instance_valid(_menu) and _menu.visible
		_new_dialogue_marker.visible = _has_unheard_dialogues() and not interaction_menu_open


func _add_option(parent: VBoxContainer, caption: String, action: Callable, tooltip: String = "") -> void:
	var option := Button.new()
	LocaleManager.set_text(option, caption)
	LocaleManager.set_tooltip(option, tooltip)
	option.custom_minimum_size.y = 36
	option.add_theme_font_size_override("font_size", 13)
	option.add_theme_color_override("font_color", PAPER)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("182b38")
	normal.border_color = Color("71808a")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	option.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("2c4352")
	hover.border_color = GOLD
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("focus", hover)
	option.pressed.connect(action)
	parent.add_child(option)


func _add_topic_option(parent: VBoxContainer, topic_name: String, remaining: int, action: Callable) -> void:
	var option := Button.new()
	option.custom_minimum_size.y = 42
	if remaining > 0:
		LocaleManager.set_tooltip(option, "%d fala%s inédita%s disponível%s" % [remaining, "s" if remaining != 1 else "", "s" if remaining != 1 else "", "s" if remaining != 1 else ""])
	else:
		LocaleManager.set_tooltip(option, "Todas as falas únicas deste assunto já foram ouvidas.")
	option.add_theme_color_override("font_color", PAPER)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("241f18") if remaining > 0 else Color("182b38")
	normal.border_color = Color("b79659") if remaining > 0 else Color("71808a")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 5
	normal.content_margin_bottom = 5
	option.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("342b1d") if remaining > 0 else Color("2c4352")
	hover.border_color = Color("edca7e") if remaining > 0 else GOLD
	option.add_theme_stylebox_override("hover", hover)
	option.add_theme_stylebox_override("focus", hover)
	option.add_theme_stylebox_override("pressed", hover)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.offset_top = 3
	row.offset_bottom = -3
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	option.add_child(row)
	var text_block := VBoxContainer.new()
	text_block.alignment = BoxContainer.ALIGNMENT_CENTER
	text_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_block.add_theme_constant_override("separation", 1)
	text_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_block)
	var title := Label.new()
	LocaleManager.set_text(title, topic_name)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("f3d596") if remaining > 0 else PAPER)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_block.add_child(title)
	var hint := Label.new()
	LocaleManager.set_text(hint, "Há falas inéditas neste assunto." if remaining > 0 else "Conversa cotidiana disponível")
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color("c9a76b") if remaining > 0 else Color("a2a8aa"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_block.add_child(hint)
	if remaining > 0:
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(48, 30)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color("17130f")
		badge_style.border_color = Color("cba65f")
		badge_style.set_border_width_all(1)
		badge_style.set_corner_radius_all(4)
		badge_style.content_margin_left = 5
		badge_style.content_margin_right = 5
		badge.add_theme_stylebox_override("panel", badge_style)
		row.add_child(badge)
		var badge_content := HBoxContainer.new()
		badge_content.alignment = BoxContainer.ALIGNMENT_CENTER
		badge_content.add_theme_constant_override("separation", 3)
		badge.add_child(badge_content)
		var exclamation := Label.new()
		LocaleManager.set_text(exclamation, "!")
		exclamation.add_theme_font_size_override("font_size", 13)
		exclamation.add_theme_color_override("font_color", Color("f1cd7d"))
		badge_content.add_child(exclamation)
		var count := Label.new()
		LocaleManager.set_text(count, str(remaining))
		count.add_theme_font_size_override("font_size", 11)
		count.add_theme_color_override("font_color", PAPER)
		badge_content.add_child(count)
	option.pressed.connect(action)
	parent.add_child(option)


func _open_menu() -> void:
	_menu.visible = true
	_refresh_new_dialogue_marker()
	(_menu.get_child(0).get_child(1) as Button).grab_focus()


func _show_talk_topics() -> void:
	var options := _menu.get_child(0) as VBoxContainer
	var available_topics := 0
	for topic_id in MerchantDialogues.CAMP_TOPICS:
		if bool(_unlocked_topics.get(topic_id, false)):
			available_topics += 1
	_menu.anchor_top = 0.06 if available_topics >= 8 else 0.22
	_menu.anchor_bottom = 0.96 if available_topics >= 8 else 0.84
	options.add_theme_constant_override("separation", 5)
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	var menu_title := Label.new()
	LocaleManager.set_text(menu_title, "SOBRE O QUE CONVERSAR?")
	menu_title.add_theme_font_size_override("font_size", 14)
	menu_title.add_theme_color_override("font_color", GOLD)
	options.add_child(menu_title)
	for topic_id in MerchantDialogues.CAMP_TOPICS:
		if not bool(_unlocked_topics.get(topic_id, false)):
			continue
		var topic: Dictionary = MerchantDialogues.CAMP_TOPICS[topic_id]
		var remaining := MerchantDialogues.camp_lines_remaining(str(topic_id), _seen_dialogues)
		_add_topic_option(options, str(topic["label"]), remaining, _talk.bind(str(topic_id)))
	_add_option(options, "Ver mercadorias", func() -> void: shop_requested.emit())
	_add_option(options, "Voltar ao acampamento", _show_main_menu)
	_add_option(options, "Retornar à jornada", func() -> void: leave_requested.emit())


func _show_main_menu() -> void:
	var options := _menu.get_child(0) as VBoxContainer
	_menu.anchor_top = 0.22
	_menu.anchor_bottom = 0.54
	options.add_theme_constant_override("separation", 7)
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	_populate_main_menu(options)


func _populate_main_menu(options: VBoxContainer) -> void:
	var menu_title := Label.new()
	LocaleManager.set_text(menu_title, "O QUE DESEJAM FAZER?")
	menu_title.add_theme_font_size_override("font_size", 14)
	menu_title.add_theme_color_override("font_color", GOLD)
	options.add_child(menu_title)
	_add_option(options, "Conversar", _show_talk_topics)
	_add_option(options, "Ver mercadorias", func() -> void: shop_requested.emit())
	_add_option(options, "Gerenciar relíquias", func() -> void: equipment_requested.emit())
	_add_option(options, "Retornar à jornada", func() -> void: leave_requested.emit())


func _talk(topic_id: String) -> void:
	var line: Dictionary = MerchantDialogues.camp_line(topic_id, _seen_dialogues, _losses)
	var dialogue_id: String = str(line.get("id", ""))
	if bool(line.get("unique", false)) and not dialogue_id.is_empty():
		_seen_dialogues[dialogue_id] = true
		dialogue_seen_requested.emit(dialogue_id)
		_refresh_new_dialogue_marker()
	_show_placeholder(str(line.get("text", "")))
	_show_talk_topics()


func _show_placeholder(message: String) -> void:
	LocaleManager.set_text(_notice_text, message)
	_notice.visible = true
	if _notice_tween != null and _notice_tween.is_running():
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(6.0)
	_notice_tween.tween_callback(func() -> void: _notice.visible = false)
