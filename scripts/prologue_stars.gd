extends Control

var _positions: Array[Vector2] = []
var _velocities: Array[Vector2] = []
var _sizes: Array[float] = []
var _phases: Array[float] = []
var _colors: Array[Color] = []
var _elapsed := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index in range(72):
		_positions.append(Vector2(randf(), randf()))
		_velocities.append(Vector2(randf_range(-0.018, 0.018), randf_range(-0.025, -0.008)))
		_sizes.append(randf_range(1.0, 2.4))
		_phases.append(randf_range(0.0, TAU))
		_colors.append(Color("eaf5ff") if randf() > 0.42 else Color("5278d8"))


func _process(delta: float) -> void:
	_elapsed += delta
	for index in range(_positions.size()):
		_positions[index] += _velocities[index] * delta
		if _positions[index].y < -0.04:
			_positions[index].y = 1.04
			_positions[index].x = randf()
		if _positions[index].x < -0.04:
			_positions[index].x = 1.04
		elif _positions[index].x > 1.04:
			_positions[index].x = -0.04
	queue_redraw()


func _draw() -> void:
	var extent := size
	for index in range(_positions.size()):
		var point := _positions[index] * extent
		var pulse := 0.48 + 0.42 * sin(_elapsed * 1.4 + _phases[index])
		var radius := _sizes[index]
		var color := _colors[index]
		color.a = pulse
		var glow := color
		glow.a = 0.12
		draw_circle(point, radius * 2.0, glow)
		draw_line(point + Vector2(-radius, 0), point + Vector2(radius, 0), color, 1.0)
		draw_line(point + Vector2(0, -radius), point + Vector2(0, radius), color, 1.0)
		draw_circle(point, maxf(0.65, radius * 0.5), color)
