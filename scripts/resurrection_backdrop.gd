extends Control

var elapsed := 0.0
const SPARKS := [
	Vector2(0.15, 0.22), Vector2(0.23, 0.67), Vector2(0.33, 0.38),
	Vector2(0.43, 0.17), Vector2(0.54, 0.73), Vector2(0.67, 0.30),
	Vector2(0.76, 0.61), Vector2(0.87, 0.24), Vector2(0.91, 0.78)
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()


func _draw() -> void:
	for index in SPARKS.size():
		var point: Vector2 = SPARKS[index]
		var pulse := 0.5 + 0.5 * sin(elapsed * (0.7 + float(index % 3) * 0.2) + float(index) * 1.8)
		var pos := Vector2(size.x * point.x, size.y * point.y + sin(elapsed + float(index)) * 5.0)
		draw_circle(pos, 2.0 + pulse, Color(0.35, 0.48, 0.75, 0.11 + 0.17 * pulse))
		draw_circle(pos, 8.0 + pulse * 5.0, Color(0.15, 0.23, 0.45, 0.015 + 0.025 * pulse))
