extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var scale_factor: float = minf(size.x / 96.0, size.y / 148.0)
	var offset: Vector2 = (size - Vector2(96, 148) * scale_factor) * 0.5
	draw_set_transform(offset, 0.0, Vector2.ONE * scale_factor)
	draw_rect(Rect2(4, 132, 88, 5), Color("27313a", 0.65))
	draw_colored_polygon(PackedVector2Array([
		Vector2(27, 58), Vector2(69, 58), Vector2(81, 72), Vector2(90, 133),
		Vector2(6, 133), Vector2(15, 72),
	]), Color("090d14"))
	draw_rect(Rect2(19, 71, 58, 48), Color("0d121a"))
	draw_rect(Rect2(27, 31, 42, 42), Color("080c12"))
	draw_rect(Rect2(22, 24, 52, 21), Color("111720"))
	draw_rect(Rect2(28, 17, 40, 12), Color("111720"))
	draw_rect(Rect2(34, 11, 28, 8), Color("111720"))
	draw_rect(Rect2(33, 45, 30, 18), Color("04070c"))
	draw_rect(Rect2(14, 81, 13, 36), Color("0a0f16"))
	draw_rect(Rect2(69, 81, 13, 36), Color("0a0f16"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
