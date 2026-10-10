extends Control

var progress: float = 0.0
var direction: float = 1.0
var elapsed: float = 0.0
var leaves: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var palette: Array = []


func configure(travel_direction: float) -> void:
	direction = 1.0 if travel_direction >= 0.0 else -1.0
	palette = [Color("adc86b"), Color("ddbc6c"), Color("94ab61"), Color("e7d596")] if direction > 0.0 else [Color("9ebcb0"), Color("b7acd1"), Color("c4b27b"), Color("d8d4b1")]
	rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_process(true)
	_leaves_seed()


func set_progress(value: float) -> void:
	progress = clampf(value, 0.0, 1.0)
	queue_redraw()


func _process(delta: float) -> void:
	elapsed += delta
	for index in leaves.size():
		var leaf: Dictionary = leaves[index]
		leaf["offset"] = float(leaf["offset"]) + direction * float(leaf["speed"]) * delta
		leaf["y"] = float(leaf["y"]) + float(leaf["vertical_speed"]) * delta
		leaf["spin"] = float(leaf["spin"]) + float(leaf["spin_speed"]) * delta
		if absf(float(leaf["offset"])) > 185.0:
			leaf["offset"] = -direction * rng.randf_range(105.0, 165.0)
		if float(leaf["y"]) < -25.0:
			leaf["y"] = size.y + 25.0
		elif float(leaf["y"]) > size.y + 25.0:
			leaf["y"] = -25.0
		leaves[index] = leaf
	queue_redraw()


func _leaves_seed() -> void:
	leaves.clear()
	for index in range(46):
		leaves.append({
			"offset": rng.randf_range(-155.0, 155.0),
			"y": rng.randf_range(-20.0, maxf(20.0, size.y) + 20.0),
			"speed": rng.randf_range(55.0, 145.0),
			"vertical_speed": rng.randf_range(-24.0, 24.0),
			"spin": rng.randf_range(-PI, PI),
			"spin_speed": rng.randf_range(-2.4, 2.4),
			"width": rng.randf_range(9.0, 20.0),
			"height": rng.randf_range(3.0, 7.0),
			"color": palette[rng.randi_range(0, palette.size() - 1)],
			"phase": rng.randf_range(0.0, TAU),
		})


func _edge_x(y: float) -> float:
	var travel: float = -0.085 + 1.17 * progress if direction > 0.0 else 1.085 - 1.17 * progress
	var normalized_y: float = y / maxf(1.0, size.y)
	var flutter: float = sin(normalized_y * 32.0 + progress * 9.0) * 0.004 + sin(normalized_y * 71.0 - progress * 7.0) * 0.002
	return (travel + flutter) * size.x


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	for section in range(0, ceili(size.y / 22.0)):
		var y0: float = float(section) * 22.0
		var y1: float = minf(size.y, y0 + 22.0)
		var from := Vector2(_edge_x(y0), y0)
		var to := Vector2(_edge_x(y1), y1)
		draw_line(from, to, Color(0.94, 0.78, 0.48, 0.075), 15.0)
		draw_line(from, to, Color(0.96, 0.87, 0.64, 0.13), 3.0)
	for leaf in leaves:
		var y: float = float(leaf["y"])
		var offset: float = float(leaf["offset"])
		var x: float = _edge_x(y) + offset + sin(elapsed * 3.0 + float(leaf["phase"])) * 5.0
		if x < -30.0 or x > size.x + 30.0:
			continue
		var fade: float = 1.0 - smoothstep(90.0, 185.0, absf(offset))
		var color: Color = leaf["color"]
		color.a = fade * 0.82
		var width: float = float(leaf["width"])
		var height: float = float(leaf["height"])
		draw_set_transform(Vector2(x, y), float(leaf["spin"]), Vector2.ONE)
		draw_rect(Rect2(Vector2(-width * 0.5, -height * 0.5), Vector2(width, height)), color)
		draw_rect(Rect2(Vector2(0.0, -height), Vector2(1.0, height * 2.0)), Color(color.r, color.g, color.b, color.a * 0.55))
		draw_set_transform(Vector2.ZERO)
