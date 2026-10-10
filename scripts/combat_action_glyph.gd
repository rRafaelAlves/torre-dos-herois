extends Control

var style: String = "arcane"
var tint: Color = Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(16, 16)
	size = Vector2(16, 16)
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
		_:
			draw_rect(Rect2(4, 4, 8, 8), dark)
			draw_rect(Rect2(5, 2, 6, 12), tint)
			draw_rect(Rect2(2, 5, 12, 6), tint)
			draw_rect(Rect2(6, 6, 4, 4), Color.WHITE)
