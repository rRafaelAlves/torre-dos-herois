extends Control

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	draw_circle(center + Vector2(0, 14), 25.0 + pulse * 4.0, Color(1.0, 0.44, 0.08, 0.045 + pulse * 0.025))
	for index in 5:
		var progress := fposmod(_time * (0.42 + float(index) * 0.08) + float(index) * 0.21, 1.0)
		var sway := sin(_time * 2.1 + float(index) * 2.7) * 9.0
		var pos := center + Vector2(sway + float(index - 2) * 6.0, 11.0 - progress * 34.0)
		var spark_color := Color(1.0, 0.70 + 0.15 * pulse, 0.28, (1.0 - progress) * 0.56)
		draw_rect(Rect2(pos, Vector2(2, 2)), spark_color)
