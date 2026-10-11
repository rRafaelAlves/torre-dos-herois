extends Control

const Tower = preload("res://data/tower.gd")

signal hovered(node_id: String)
signal pinned(node_id: String)

const GOLD := Color("f2c66d")
const PALE_GOLD := Color("ffe3a1")
const ICE := Color("9ce7d8")
const MUTED := Color("798690")
const FOG := Color("101820")
const FONT_SMALL := 10

var completed: int = 1
var route_history: Dictionary = {}
var hovered_id: String = ""
var pinned_id: String = ""


func configure(floors_completed: int, history: Dictionary) -> void:
	completed = floors_completed
	route_history = history.duplicate()
	queue_redraw()


func set_pinned(node_id: String) -> void:
	pinned_id = node_id
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(queue_redraw)
	LocaleManager.language_changed.connect(_on_language_changed)


func _on_language_changed(_locale: String) -> void:
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_draw_atmosphere()
	_draw_mountain_silhouette()
	_draw_tower(size.x * 0.5, size.y)
	_draw_fog(size.x * 0.5, size.y)
	_draw_route_lines()
	_draw_floor_lights()
	for floor_number in range(1, Tower.MAX_FLOOR + 1):
		for node_id in _nodes_for_floor(floor_number):
			_draw_node(node_id, floor_number)
	_draw_frame_details()


func _draw_atmosphere() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("09111a"))
	var band_count: int = maxi(1, int(size.y / 5.0))
	for index in range(band_count):
		var ratio: float = float(index) / float(band_count)
		var alpha: float = lerpf(0.10, 0.0, ratio)
		draw_rect(Rect2(0, float(index) * 5.0, size.x, 5.0), Color("26394a", alpha))
	var glow_center := Vector2(size.x * 0.5, size.y * 0.48)
	for ring in range(5, 0, -1):
		var radius: float = float(ring) * minf(size.x * 0.13, size.y * 0.16)
		draw_circle(glow_center, radius, Color("27394b", 0.028))
	for index in range(46):
		var star_x: float = fposmod(float(index * 83 + 29), maxf(size.x, 1.0))
		var star_y: float = fposmod(float(index * 47 + 13), maxf(size.y * 0.98, 1.0))
		var star_color: Color = Color("d5e6ec", 0.23) if index % 4 == 0 else Color("a4b8c4", 0.13)
		var star_size: float = 2.0 if index % 7 == 0 else 1.0
		draw_rect(Rect2(Vector2(star_x, star_y), Vector2(star_size, star_size)), star_color)


func _draw_mountain_silhouette() -> void:
	var horizon: float = size.y * 0.78
	var left_range := PackedVector2Array([
		Vector2(0, horizon + 2), Vector2(0, horizon - 44), Vector2(size.x * 0.09, horizon - 87),
		Vector2(size.x * 0.17, horizon - 45), Vector2(size.x * 0.24, horizon - 100),
		Vector2(size.x * 0.34, horizon - 34), Vector2(size.x * 0.42, horizon - 63),
		Vector2(size.x * 0.48, horizon + 4)
	])
	var right_range := PackedVector2Array([
		Vector2(size.x * 0.52, horizon + 4), Vector2(size.x * 0.62, horizon - 49),
		Vector2(size.x * 0.70, horizon - 91), Vector2(size.x * 0.78, horizon - 42),
		Vector2(size.x * 0.88, horizon - 77), Vector2(size.x, horizon - 30), Vector2(size.x, horizon + 2)
	])
	draw_colored_polygon(left_range, Color("111d29"))
	draw_colored_polygon(right_range, Color("111d29"))
	draw_line(Vector2(0, horizon - 1), Vector2(size.x, horizon - 1), Color("93a8ae", 0.12), 1.0)
	for side in [-1.0, 1.0]:
		var tree_x: float = size.x * (0.07 if side < 0 else 0.93)
		var tree_y: float = size.y * 0.83
		var tree_color := Color("0c171e", 0.86)
		for index in range(3):
			var x: float = tree_x + side * float(index) * 24.0
			var h: float = 34.0 + float((index * 17) % 24)
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, tree_y - h), Vector2(x - 10, tree_y - h * 0.48), Vector2(x - 5, tree_y - h * 0.48),
				Vector2(x - 15, tree_y - h * 0.08), Vector2(x + 15, tree_y - h * 0.08),
				Vector2(x + 5, tree_y - h * 0.48), Vector2(x + 10, tree_y - h * 0.48)
			]), tree_color)
			draw_rect(Rect2(x - 2, tree_y - 8, 4, 10), tree_color)


func _draw_tower(center_x: float, height: float) -> void:
	var bottom: float = height - 22.0
	var top: float = 22.0
	var outer := PackedVector2Array([
		Vector2(center_x - 100, top + 38), Vector2(center_x - 86, top + 5), Vector2(center_x - 52, top + 5),
		Vector2(center_x - 38, top - 9), Vector2(center_x + 38, top - 9), Vector2(center_x + 52, top + 5),
		Vector2(center_x + 86, top + 5), Vector2(center_x + 100, top + 38),
		Vector2(center_x + 154, bottom), Vector2(center_x - 154, bottom)
	])
	draw_colored_polygon(outer, Color("17232d"))
	draw_polyline(PackedVector2Array([
		Vector2(center_x - 100, top + 38), Vector2(center_x - 86, top + 5), Vector2(center_x - 52, top + 5),
		Vector2(center_x - 38, top - 9), Vector2(center_x + 38, top - 9), Vector2(center_x + 52, top + 5),
		Vector2(center_x + 86, top + 5), Vector2(center_x + 100, top + 38), Vector2(center_x + 154, bottom)
	]), Color("65717a", 0.63), 2.0, true)
	draw_line(Vector2(center_x - 154, bottom), Vector2(center_x + 154, bottom), Color("65717a", 0.63), 2.0, true)

	# Central keep and side buttresses give each floor a clear place in the ascent.
	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 91, top + 34), Vector2(center_x - 70, top + 14),
		Vector2(center_x + 70, top + 14), Vector2(center_x + 91, top + 34),
		Vector2(center_x + 119, bottom), Vector2(center_x - 119, bottom)
	]), Color("202f3b"))
	draw_rect(Rect2(center_x - 137, top + 43, 22, bottom - top - 54), Color("253541"))
	draw_rect(Rect2(center_x + 115, top + 43, 22, bottom - top - 54), Color("253541"))
	for buttress_x in [center_x - 144, center_x + 115]:
		draw_line(Vector2(buttress_x, top + 46), Vector2(buttress_x, bottom - 4), Color("82909a", 0.3), 2.0)
		draw_line(Vector2(buttress_x + 20, top + 46), Vector2(buttress_x + 20, bottom - 4), Color("080e14", 0.5), 2.0)

	# Stone courses, floor ledges and narrow lancet windows add a layered masonry texture.
	for floor_number in range(1, Tower.MAX_FLOOR + 1):
		var y: float = _floor_y(floor_number)
		var half_width: float = lerpf(145.0, 88.0, float(floor_number - 1) / float(Tower.MAX_FLOOR - 1))
		draw_line(Vector2(center_x - half_width, y + 23), Vector2(center_x + half_width, y + 23), Color("9ba6a8", 0.10), 1.0)
		draw_line(Vector2(center_x - half_width + 5, y + 26), Vector2(center_x + half_width - 5, y + 26), Color("050b11", 0.45), 1.0)
		var window_color := Color("cf9a50", 0.3)
		if floor_number <= completed:
			window_color = Color("dfb96c", 0.66)
		elif floor_number == completed + 1:
			window_color = Color("a7e0d4", 0.84)
		for side in [-1.0, 1.0]:
			var wx: float = center_x + side * (38.0 + float(floor_number - 1) * 4.0)
			draw_rect(Rect2(wx - 5, y - 13, 10, 20), Color("080e14", 0.9))
			draw_rect(Rect2(wx - 2, y - 9, 4, 12), window_color)
			if floor_number <= completed + 1:
				draw_rect(Rect2(wx - 1, y - 7, 2, 8), Color("ffe4a1", 0.37))
	for y in range(int(top + 38), int(bottom), 43):
		var row_index: int = int((float(y) - top) / 43.0)
		var offset: float = 0.0 if row_index % 2 == 0 else 24.0
		for x in range(-110, 112, 48):
			var px: float = center_x + float(x) + offset
			if absf(px - center_x) < 24.0:
				continue
			draw_line(Vector2(px, y), Vector2(px, y + 21), Color("9ba6a8", 0.075), 1.0)

	# Crowned summit and a sealed gate establish the beginning and end of the climb.
	for index in range(5):
		var crenel_x: float = center_x - 42.0 + float(index) * 21.0
		draw_rect(Rect2(crenel_x, top - 17, 13, 10), Color("33414b"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x - 24, top - 9), Vector2(center_x, top - 39),
		Vector2(center_x + 24, top - 9)
	]), Color("34434d"))
	draw_line(Vector2(center_x, top - 32), Vector2(center_x, top - 14), Color("caa45e", 0.68), 2.0)
	draw_circle(Vector2(center_x, top - 33), 3.0, PALE_GOLD)
	var gate_y: float = height - 66.0
	draw_rect(Rect2(center_x - 29, gate_y, 58, 44), Color("0a1016"))
	draw_arc(Vector2(center_x, gate_y + 5), 29.0, PI, TAU, 18, Color("9b855c", 0.72), 2.0, true)
	for gate_x in range(-20, 22, 10):
		draw_line(Vector2(center_x + float(gate_x), gate_y + 4), Vector2(center_x + float(gate_x), gate_y + 43), Color("65717a", 0.33), 1.0)
	draw_line(Vector2(center_x - 28, gate_y + 30), Vector2(center_x + 28, gate_y + 30), Color("65717a", 0.27), 1.0)
	draw_circle(Vector2(center_x, gate_y + 17), 4.0, Color("b6894b", 0.55))


func _draw_fog(center_x: float, height: float) -> void:
	for floor_number in range(completed + 2, Tower.MAX_FLOOR + 1):
		var y: float = _floor_y(floor_number)
		var width: float = minf(size.x * 0.68, 376.0)
		draw_rect(Rect2(center_x - width * 0.5, y - 25, width, 50), Color(FOG.r, FOG.g, FOG.b, 0.65))
	for index in range(11):
		var wisp_y: float = 17.0 + float(index) * (height - 34.0) / 11.0
		if wisp_y < _floor_y(completed + 1) - 20.0:
			var phase: float = float(index % 3) * 12.0
			draw_line(Vector2(-10.0 + phase, wisp_y), Vector2(size.x * 0.47 + phase, wisp_y + 6.0), Color("c2d0d4", 0.045), 8.0)
			draw_line(Vector2(size.x * 0.58 + phase, wisp_y + 8.0), Vector2(size.x + 10.0, wisp_y), Color("c2d0d4", 0.035), 6.0)


func _draw_route_lines() -> void:
	for floor_number in range(1, Tower.MAX_FLOOR):
		for from_id in _nodes_for_floor(floor_number):
			for to_id in _nodes_for_floor(floor_number + 1):
				var past: bool = floor_number + 1 <= completed and _path_node(from_id, floor_number) and _path_node(to_id, floor_number + 1)
				var available: bool = floor_number + 1 == completed + 1 and _path_node(from_id, floor_number)
				var start: Vector2 = _node_position(from_id, floor_number)
				var finish: Vector2 = _node_position(to_id, floor_number + 1)
				if past:
					_draw_glowing_path(start, finish, GOLD, 0.75)
				elif available:
					_draw_glowing_path(start, finish, ICE, 0.83)
				else:
					draw_dashed_line(start, finish, Color("7a8c98", 0.22), 1.5, 6.0, true)


func _draw_glowing_path(start: Vector2, finish: Vector2, color: Color, strength: float) -> void:
	var selected: bool = (not pinned_id.is_empty() and _node_floor(pinned_id) == completed + 1 and finish == _node_position(pinned_id, completed + 1))
	var bright: Color = PALE_GOLD if selected else color
	draw_line(start, finish, Color(bright.r, bright.g, bright.b, 0.13 * strength), 9.0, true)
	draw_line(start, finish, Color(bright.r, bright.g, bright.b, 0.37 * strength), 4.0, true)
	draw_line(start, finish, Color(bright.r, bright.g, bright.b, 0.82 * strength), 1.5, true)


func _draw_floor_lights() -> void:
	for floor_number in range(1, Tower.MAX_FLOOR + 1):
		var y: float = _floor_y(floor_number)
		var active: bool = floor_number == completed + 1
		var visited: bool = floor_number <= completed
		var color := Color("d7b66e", 0.18) if visited else Color("8a9ba3", 0.08)
		if active:
			color = Color("9ce7d8", 0.28)
		var dash_x: float = 16.0
		while dash_x < size.x - 16.0:
			if absf(dash_x - size.x * 0.5) > 170.0:
				draw_line(Vector2(dash_x, y + 23), Vector2(dash_x + 8, y + 23), color, 1.0)
			dash_x += 13.0


func _draw_node(node_id: String, floor_number: int) -> void:
	var point: Vector2 = _node_position(node_id, floor_number)
	var available: bool = floor_number == completed + 1
	var visited: bool = floor_number <= completed and _path_node(node_id, floor_number)
	var is_selected: bool = node_id == pinned_id or node_id == hovered_id
	var tint := GOLD if visited else (ICE if available else MUTED)
	var radius: float = 17.0 if available else 13.0
	if available:
		draw_circle(point, 36.0, Color(tint.r, tint.g, tint.b, 0.035))
		draw_circle(point, 27.0, Color(tint.r, tint.g, tint.b, 0.075))
		draw_circle(point, 21.0, Color(tint.r, tint.g, tint.b, 0.12))
	elif floor_number > completed:
		tint.a = 0.39
	elif not visited:
		tint.a = 0.3
	if is_selected:
		draw_circle(point, radius + 11.0, Color(PALE_GOLD.r, PALE_GOLD.g, PALE_GOLD.b, 0.12))
		draw_arc(point, radius + 7.0, 0.0, TAU, 28, PALE_GOLD, 2.0, true)
	elif available:
		draw_arc(point, radius + 5.0, 0.0, TAU, 24, Color(tint.r, tint.g, tint.b, 0.48), 1.0, true)
	_draw_diamond(point, radius + (3.0 if available else 1.0), Color(tint.r, tint.g, tint.b, 0.7 if visited or available else 0.28))
	draw_circle(point, radius, Color(tint.r, tint.g, tint.b, 0.82 if visited or available else 0.52))
	draw_circle(point, radius - 4.0, Color("111a24", 0.97))
	var font := _active_font()
	var number_color := PALE_GOLD if visited else (Color("d8fff6") if available else Color("a2adb4", 0.6))
	draw_string(font, point + Vector2(-13, 5), "%02d" % floor_number, HORIZONTAL_ALIGNMENT_CENTER, 26, 12, number_color)
	if visited and _path_node(node_id, floor_number):
		draw_circle(point + Vector2(9, -10), 3.0, GOLD)
	if available and not node_id.begins_with("floor:"):
		_draw_route_sign(node_id, floor_number, point)
	if floor_number == Tower.MAX_FLOOR:
		var boss_color := Color("e69b79", 0.54 if not visited else 1.0)
		draw_circle(point, radius + 14.0, Color("8c343c", 0.12))
		draw_string(font, point + Vector2(25, 4), LocaleManager.localize("CHEFE"), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SMALL, boss_color)
		_draw_diamond(point + Vector2(0, -34), 7.0, boss_color)


func _draw_route_sign(node_id: String, floor_number: int, point: Vector2) -> void:
	var route: Dictionary = Tower.route_by_id(node_id)
	var route_name: String = LocaleManager.localize(str(route.get("name", "")))
	var sign: float = -1.0 if _route_index(node_id, floor_number) == 0 else 1.0
	var max_text_width: float = minf(136.0, size.x * 0.27)
	var sign_width: float = max_text_width + 19.0
	var sign_x: float = point.x - sign_width - 21.0 if sign < 0.0 else point.x + 21.0
	var sign_y: float = point.y - 12.0
	var active: bool = floor_number == completed + 1
	var fill := Color("111a22", 0.94 if active else 0.72)
	var outline := Color("80c4bb", 0.75) if active else Color("70808a", 0.37)
	draw_rect(Rect2(sign_x, sign_y, sign_width, 24), fill)
	draw_rect(Rect2(sign_x, sign_y, sign_width, 24), outline, false, 1.0)
	var anchor_x: float = sign_x + sign_width if sign < 0.0 else sign_x
	draw_line(Vector2(anchor_x, point.y), point + Vector2(sign * 20.0, 0.0), outline, 1.0)
	var font := _active_font()
	draw_string(font, Vector2(sign_x + 8.0, sign_y + 16.0), route_name, HORIZONTAL_ALIGNMENT_LEFT, max_text_width, FONT_SMALL, Color("d9e8e6", 1.0 if active else 0.72))


func _draw_frame_details() -> void:
	draw_rect(Rect2(5, 5, size.x - 10, size.y - 10), Color("c5a164", 0.34), false, 1.0)
	draw_rect(Rect2(9, 9, size.x - 18, size.y - 18), Color("78909a", 0.14), false, 1.0)
	for point in [Vector2(13, 13), Vector2(size.x - 13, 13), Vector2(13, size.y - 13), Vector2(size.x - 13, size.y - 13)]:
		_draw_diamond(point, 3.0, Color("d8b976", 0.75))
	var label_x: float = 18.0
	var label_y: float = 27.0
	draw_rect(Rect2(label_x, label_y - 12.0, 8.0, 8.0), Color("d5b265", 0.7))
	draw_string(_active_font(), Vector2(label_x + 14, label_y - 5), "%02d" % (completed + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("d6c28d", 0.72))


func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0)
	]), color)


func _active_font() -> Font:
	if LocaleManager.current_locale == "ja":
		return LocaleManager.JAPANESE_FONT
	if LocaleManager.current_locale == "zh_CN":
		return LocaleManager.CHINESE_FONT
	return ThemeDB.fallback_font


func _nodes_for_floor(floor_number: int) -> Array[String]:
	var branch: Array = Tower.route_after(floor_number - 1)
	if branch.is_empty():
		return ["floor:%d" % floor_number]
	var ids: Array[String] = []
	for route in branch:
		ids.append(route["id"])
	return ids


func _route_index(node_id: String, floor_number: int) -> int:
	var ids: Array[String] = _nodes_for_floor(floor_number)
	return ids.find(node_id)


func _node_position(node_id: String, floor_number: int) -> Vector2:
	var x: float = size.x * 0.5
	if not node_id.begins_with("floor:"):
		x += -92.0 if _route_index(node_id, floor_number) == 0 else 92.0
	return Vector2(x, _floor_y(floor_number))


func _floor_y(floor_number: int) -> float:
	return size.y - 39.0 - float(floor_number - 1) * (size.y - 78.0) / float(Tower.MAX_FLOOR - 1)


func _path_node(node_id: String, floor_number: int) -> bool:
	if node_id.begins_with("floor:"):
		return true
	return route_history.get(str(floor_number), "") == node_id


func _inspectable_at(point: Vector2) -> String:
	for floor_number in range(1, mini(Tower.MAX_FLOOR, completed + 1) + 1):
		for node_id in _nodes_for_floor(floor_number):
			if floor_number < completed + 1 and not _path_node(node_id, floor_number):
				continue
			if point.distance_to(_node_position(node_id, floor_number)) <= 23.0:
				return node_id
	return ""


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var next_id: String = _inspectable_at(event.position)
		if next_id != hovered_id:
			hovered_id = next_id
			hovered.emit(next_id)
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var node_id: String = _inspectable_at(event.position)
		if node_id != "" and not node_id.begins_with("floor:") and _node_floor(node_id) == completed + 1:
			pinned.emit(node_id)
			accept_event()


func _node_floor(node_id: String) -> int:
	for previous_floor in Tower.ROUTES:
		for route in Tower.ROUTES[previous_floor]:
			if route["id"] == node_id:
				return int(previous_floor) + 1
	return 0


func _on_mouse_exited() -> void:
	if hovered_id != "":
		hovered_id = ""
		hovered.emit("")
		queue_redraw()
