extends Control

var skill_id := ""
var phase := "impact"
var duration := 0.66
var progress := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(120, 120)
	set_process(true)


func _process(delta: float) -> void:
	progress = minf(1.0, progress + delta / duration)
	queue_redraw()
	if progress >= 1.0:
		queue_free()


func _draw() -> void:
	var c := Vector2(60, 60)
	var life := 1.0 - progress
	var spread := 12.0 + progress * 34.0
	var pulse := sin(progress * PI)
	if phase == "cast":
		_draw_cast(c, spread * 0.62, life)
		return
	match skill_id:
		"golpe_poderoso":
			_stroke(c + Vector2(-34, 24), c + Vector2(27, -25), Color("fff0b5"), 7.0, life)
			_stroke(c + Vector2(-23, 29), c + Vector2(37, -19), Color("d88452"), 3.0, life)
			_sparks(c, spread, Color("ffd16d"), 6, life)
		"guarda_protetora":
			_shield(c, 20.0 + spread * 0.48, Color("8de4f0"), life)
			_ring(c, spread * 0.8, Color("bbfaff"), life)
		"disparo_duplo":
			for side in [-1.0, 1.0]:
				var y: float = float(side) * (8.0 + progress * 7.0)
				_stroke(c + Vector2(-37, y + 8), c + Vector2(37, y - 8), Color("f7dc91"), 3.0, life)
				_stroke(c + Vector2(25, y - 14), c + Vector2(37, y - 8), Color.WHITE, 2.0, life)
		"flecha_debilitante":
			_stroke(c + Vector2(-39, 13), c + Vector2(35, -12), Color("a2db83"), 4.0, life)
			_sparks(c, spread * 0.72, Color("8c5bb5"), 8, life)
		"raio_arcano":
			var points := [c + Vector2(-37, -13), c + Vector2(-17, -24), c + Vector2(-9, 5), c + Vector2(12, -8), c + Vector2(19, 19), c + Vector2(37, 8)]
			for index in range(points.size() - 1):
				_stroke(points[index], points[index + 1], Color("caa4ff"), 5.0, life)
			_sparks(c, spread, Color("f1d5ff"), 5, life)
		"maldicao_venenosa":
			_ring(c, spread * 0.85, Color("78ce6e"), life)
			for index in 7:
				var angle := TAU * float(index) / 7.0 + progress
				_dot(c + Vector2(cos(angle), sin(angle)) * spread, 3.0 + pulse * 2.0, Color("8ae363"), life)
		"cura":
			_cross(c, 13.0 + spread * 0.28, Color("bafaaa"), life)
			_sparks(c, spread, Color("f7edaa"), 8, life)
		"purificacao":
			_ring(c, spread, Color("c1efff"), life)
			_ring(c, spread * 0.66, Color("fff7cd"), life)
			_cross(c, 10.0, Color.WHITE, life)
		"bola_de_fogo":
			_ring(c, spread * 0.8, Color("ff8a42"), life)
			_dot(c, 12.0 + 11.0 * pulse, Color("ffcf66"), life)
			_sparks(c, spread, Color("ff5d38"), 10, life)
		"onda_arcana":
			for index in 3:
				_ring(c, spread * (0.55 + float(index) * 0.32), Color("ae8cff"), life * (1.0 - float(index) * 0.18))
		"golpe_carrasco":
			_stroke(c + Vector2(-31, -32), c + Vector2(29, 30), Color("ff7772"), 6.0, life)
			_stroke(c + Vector2(31, -34), c + Vector2(-27, 29), Color("f5cf97"), 4.0, life)
			_sparks(c, spread, Color("ff9c70"), 5, life)
		"fortaleza_inabalavel":
			_shield(c, 22.0 + spread * 0.38, Color("d9bf83"), life)
			for x in [-26.0, -13.0, 0.0, 13.0, 26.0]:
				_stroke(c + Vector2(x, 20), c + Vector2(x, 2), Color("f5d99c"), 4.0, life)
		"instinto_predador":
			_ring(c, spread * 0.68, Color("8dda6b"), life)
			_dot(c, 8.0 + pulse * 4.0, Color("f5d964"), life)
			for x in [-15.0, 0.0, 15.0]:
				_stroke(c + Vector2(x - 8, -29), c + Vector2(x + 8, 25), Color("b6eb80"), 2.0, life)
		"chuva_flechas":
			for index in 7:
				var x := -35.0 + float(index) * 11.5
				var y := -31.0 + fmod(float(index * 13) + progress * 48.0, 62.0)
				_stroke(c + Vector2(x - 4, y - 12), c + Vector2(x + 4, y + 12), Color("e6d7a5"), 2.0, life)
		"maldicao_coletiva":
			_ring(c, spread * 0.9, Color("b885e6"), life)
			for index in 6:
				var angle := TAU * float(index) / 6.0
				var start := c + Vector2(cos(angle), sin(angle)) * spread * 0.55
				_stroke(start, c + Vector2(cos(angle), sin(angle)) * spread, Color("d6a3ef"), 3.0, life)
		"vampirismo_arcano":
			for index in 3:
				var angle := progress * TAU * 1.5 + TAU * float(index) / 3.0
				var point := c + Vector2(cos(angle), sin(angle)) * spread
				_stroke(point, c, Color("df6c91"), 3.0, life)
				_dot(point, 5.0, Color("ffb1c9"), life)
		"prece_restauradora":
			_sparks(c, spread, Color("fff0bb"), 12, life)
			_cross(c, 12.0 + pulse * 5.0, Color("fff7d9"), life)
		"milagre_divino":
			for side in [-1.0, 1.0]:
				for index in 4:
					var wing := c + Vector2(side * (14.0 + float(index) * 10.0), -16.0 + float(index) * 8.0)
					_stroke(c + Vector2(side * 10.0, 10.0), wing, Color("fff6d9"), 3.0, life)
			_cross(c, 11.0, Color.WHITE, life)
		"ruptura_arcana":
			var rift := [c + Vector2(-7, -38), c + Vector2(9, -19), c + Vector2(-5, -5), c + Vector2(14, 11), c + Vector2(-2, 35)]
			for index in range(rift.size() - 1):
				_stroke(rift[index], rift[index + 1], Color("bca4ff"), 5.0, life)
			_ring(c, spread * 0.57, Color("e4d2ff"), life)
		"tempestade_arcana":
			for index in 8:
				var angle := progress * TAU * 1.8 + TAU * float(index) / 8.0
				var point := c + Vector2(cos(angle), sin(angle)) * spread
				_dot(point, 3.0 + pulse * 2.0, Color("c0a2ff"), life)
			_ring(c, spread * 0.66, Color("e9d8ff"), life)


func _draw_cast(center: Vector2, radius: float, opacity: float) -> void:
	var color := Color("e8c781")
	if skill_id in ["maldicao_venenosa", "maldicao_coletiva", "vampirismo_arcano"]:
		color = Color("b57bd1")
	elif skill_id in ["raio_arcano", "onda_arcana", "ruptura_arcana", "tempestade_arcana"]:
		color = Color("b9a3f8")
	elif skill_id in ["cura", "purificacao", "prece_restauradora", "milagre_divino"]:
		color = Color("e9e5ab")
	_ring(center, radius, color, opacity * 0.7)
	_sparks(center, radius, color, 5, opacity)


func _stroke(from: Vector2, to: Vector2, color: Color, width: float, opacity: float) -> void:
	color.a *= opacity
	draw_line(from, to, color, width, false)


func _dot(center: Vector2, radius: float, color: Color, opacity: float) -> void:
	color.a *= opacity
	draw_circle(center, radius, color)


func _ring(center: Vector2, radius: float, color: Color, opacity: float) -> void:
	color.a *= opacity
	draw_arc(center, radius, 0.0, TAU, 36, color, 2.5, false)


func _cross(center: Vector2, radius: float, color: Color, opacity: float) -> void:
	_stroke(center + Vector2(-radius, 0), center + Vector2(radius, 0), color, 4.0, opacity)
	_stroke(center + Vector2(0, -radius), center + Vector2(0, radius), color, 4.0, opacity)


func _shield(center: Vector2, radius: float, color: Color, opacity: float) -> void:
	var points := [center + Vector2(-radius, -radius * 0.7), center + Vector2(radius, -radius * 0.7), center + Vector2(radius * 0.75, radius * 0.5), center + Vector2(0, radius), center + Vector2(-radius * 0.75, radius * 0.5)]
	for index in points.size():
		_stroke(points[index], points[(index + 1) % points.size()], color, 3.0, opacity)


func _sparks(center: Vector2, radius: float, color: Color, count: int, opacity: float) -> void:
	for index in count:
		var angle := TAU * float(index) / float(count) + float(skill_id.length() % 5) * 0.2
		var direction := Vector2(cos(angle), sin(angle))
		_stroke(center + direction * (radius - 4.0), center + direction * (radius + 4.0), color, 2.0, opacity)
