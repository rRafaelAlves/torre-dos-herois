extends Control

var style: String = "arcane"
var tint: Color = Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size == Vector2.ZERO:
		custom_minimum_size = Vector2(16, 16)
		size = Vector2(16, 16)
	else:
		custom_minimum_size = size
	queue_redraw()


func _draw() -> void:
	var dark := Color("17212b")
	match style:
		"arrow":
			draw_rect(Rect2(1, 7, 11, 2), dark)
			draw_rect(Rect2(2, 7, 10, 1), tint)
			draw_rect(Rect2(10, 5, 2, 6), tint)
			draw_rect(Rect2(12, 6, 3, 4), tint)
		"slash":
			draw_rect(Rect2(3, 10, 3, 4), tint)
			draw_rect(Rect2(6, 7, 3, 4), tint)
			draw_rect(Rect2(9, 4, 3, 4), tint)
			draw_rect(Rect2(12, 2, 2, 3), Color.WHITE)
		"feint":
			draw_line(Vector2(2, 12), Vector2(9, 5), tint, 2.0, false)
			draw_line(Vector2(9, 5), Vector2(5, 5), tint, 2.0, false)
			draw_line(Vector2(9, 5), Vector2(9, 9), tint, 2.0, false)
			draw_line(Vector2(7, 13), Vector2(14, 6), Color("fff1d0"), 2.0, false)
		"curse":
			draw_rect(Rect2(7, 1, 2, 14), tint)
			draw_rect(Rect2(1, 7, 14, 2), tint)
			draw_rect(Rect2(4, 4, 8, 8), dark)
			draw_rect(Rect2(6, 6, 4, 4), tint)
		"sacred":
			draw_rect(Rect2(7, 0, 2, 16), tint)
			draw_rect(Rect2(0, 7, 16, 2), tint)
			draw_rect(Rect2(5, 5, 6, 6), Color.WHITE)
		"fire":
			draw_rect(Rect2(4, 5, 8, 10), Color("b93638"))
			draw_rect(Rect2(6, 2, 6, 10), tint)
			draw_rect(Rect2(7, 7, 4, 5), Color("ffe39d"))
		"shadow_wave":
			draw_arc(Vector2(12, 12), 9.0, 0.0, TAU, 16, Color("241b32"), 3.0, false)
			draw_arc(Vector2(12, 12), 6.0, 0.0, TAU, 16, tint, 2.0, false)
			draw_rect(Rect2(10, 10, 4, 4), Color("e5c9f5"))
		"spectral_blade":
			draw_line(Vector2(3, 13), Vector2(13, 3), Color("252040"), 6.0, false)
			draw_line(Vector2(3, 13), Vector2(13, 3), tint, 3.0, false)
			draw_line(Vector2(2, 8), Vector2(8, 14), Color("e3daff"), 2.0, false)
			draw_circle(Vector2(13, 3), 2.0, Color("f2e9ff"))
		_:
			draw_rect(Rect2(4, 4, 8, 8), dark)
			draw_rect(Rect2(5, 2, 6, 12), tint)
			draw_rect(Rect2(2, 5, 12, 6), tint)
			draw_rect(Rect2(6, 6, 4, 4), Color.WHITE)
