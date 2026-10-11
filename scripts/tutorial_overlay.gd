extends Control
class_name TutorialOverlay

signal dismissed(tutorial_id: String)

const GOLD := Color("f2c66d")
const INK := Color("101820")
const PANEL := Color("18212b")
const TEXT := Color("f3f0e8")
const MUTED := Color("bdc3c3")

var tutorial_id := ""
var title_text := ""
var body_text := ""
var target: Control
var card: PanelContainer
var arrow_start := Vector2.ZERO
var arrow_end := Vector2.ZERO


func setup(id: String, title: String, body: String, focus: Control) -> void:
	tutorial_id = id
	title_text = title
	body_text = body
	target = focus


func _ready() -> void:
	name = "FirstVisitTutorial"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_card()
	get_viewport().size_changed.connect(_place_card)
	call_deferred("_place_card")


func _build_card() -> void:
	card = PanelContainer.new()
	card.name = "TutorialCard"
	var frame := StyleBoxFlat.new()
	frame.bg_color = PANEL
	frame.border_color = GOLD
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(2)
	frame.content_margin_left = 17
	frame.content_margin_right = 17
	frame.content_margin_top = 12
	frame.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", frame)
	card.custom_minimum_size = Vector2(380, 0)
	add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	card.add_child(column)
	var eyebrow := Label.new()
	LocaleManager.set_text(eyebrow, "GUIA DA JORNADA")
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", GOLD)
	column.add_child(eyebrow)
	var title := Label.new()
	LocaleManager.set_text(title, title_text)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", TEXT)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(title)
	var body := Label.new()
	LocaleManager.set_text(body, body_text)
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(body)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	var skip := Button.new()
	skip.name = "SkipTutorial"
	LocaleManager.set_text(skip, "Pular tutorial")
	skip.add_theme_font_size_override("font_size", 13)
	skip.add_theme_color_override("font_color", MUTED)
	skip.pressed.connect(_dismiss)
	actions.add_child(skip)
	var done := Button.new()
	done.name = "FinishTutorial"
	LocaleManager.set_text(done, "Entendi")
	done.add_theme_font_size_override("font_size", 14)
	done.add_theme_color_override("font_color", GOLD)
	done.pressed.connect(_dismiss)
	actions.add_child(done)


func _place_card() -> void:
	if not is_instance_valid(card):
		return
	var viewport_size := get_viewport_rect().size
	var target_rect := Rect2(viewport_size * 0.5 - Vector2(60, 30), Vector2(120, 60))
	if is_instance_valid(target):
		target_rect = target.get_global_rect()
	var card_size := Vector2(maxf(380.0, card.get_combined_minimum_size().x), card.get_combined_minimum_size().y)
	card_size.x = minf(card_size.x, viewport_size.x - 32.0)
	var center_x := clampf(target_rect.get_center().x, card_size.x * 0.5 + 16.0, viewport_size.x - card_size.x * 0.5 - 16.0)
	var above_y := target_rect.position.y - card_size.y - 28.0
	var below_y := target_rect.end.y + 28.0
	var place_below := above_y < 12.0 and below_y + card_size.y < viewport_size.y - 12.0
	var card_y := below_y if place_below else maxf(12.0, above_y)
	card.position = Vector2(center_x - card_size.x * 0.5, card_y)
	card.size = card_size
	arrow_start = Vector2(center_x, card_y if place_below else card_y + card_size.y)
	arrow_end = target_rect.get_center()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.022, 0.04, 0.72), true)
	if is_instance_valid(target):
		var rect := target.get_global_rect().grow(5.0)
		draw_rect(rect, Color(GOLD, 0.10), true)
		draw_rect(rect, GOLD, false, 2.0, true)
	if arrow_start.distance_to(arrow_end) > 2.0:
		draw_line(arrow_start, arrow_end, GOLD, 3.0, true)
		var direction := (arrow_end - arrow_start).normalized()
		var perpendicular := Vector2(-direction.y, direction.x)
		var head := PackedVector2Array([
			arrow_end,
			arrow_end - direction * 15.0 + perpendicular * 7.0,
			arrow_end - direction * 15.0 - perpendicular * 7.0,
		])
		draw_colored_polygon(head, GOLD)


func _dismiss() -> void:
	dismissed.emit(tutorial_id)
	queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
		_dismiss()
		get_viewport().set_input_as_handled()
