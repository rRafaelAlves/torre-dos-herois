extends Button

var muted: bool = false:
	set(value):
		muted = value
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var tint := Color("a9b7bd") if muted else Color("f2c66d")
	draw_rect(Rect2(center + Vector2(-12, -4), Vector2(5, 8)), tint)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-7, -5), center + Vector2(0, -11),
		center + Vector2(0, 11), center + Vector2(-7, 5)
	]), tint)
	if muted:
		draw_line(center + Vector2(5, -7), center + Vector2(12, 7), tint, 2.0, false)
		draw_line(center + Vector2(12, -7), center + Vector2(5, 7), tint, 2.0, false)
	else:
		draw_line(center + Vector2(5, -6), center + Vector2(8, -3), tint, 2.0, false)
		draw_line(center + Vector2(8, -3), center + Vector2(8, 3), tint, 2.0, false)
		draw_line(center + Vector2(8, 3), center + Vector2(5, 6), tint, 2.0, false)
		draw_line(center + Vector2(10, -9), center + Vector2(14, -5), tint, 2.0, false)
		draw_line(center + Vector2(14, -5), center + Vector2(14, 5), tint, 2.0, false)
		draw_line(center + Vector2(14, 5), center + Vector2(10, 9), tint, 2.0, false)
