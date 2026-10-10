extends Control

const Tower = preload("res://data/tower.gd")

signal hovered(node_id: String)
signal pinned(node_id: String)

const GOLD := Color("f2c66d")
const MUTED := Color("798690")
const FOG := Color("101820")

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


func _draw() -> void:
	var center_x: float = size.x * 0.5
	var height: float = size.y
	_draw_tower(center_x, height)
	_draw_fog(center_x, height)
	for floor_number in range(1, Tower.MAX_FLOOR):
		for from_id in _nodes_for_floor(floor_number):
			for to_id in _nodes_for_floor(floor_number + 1):
				var past: bool = floor_number + 1 <= completed and _path_node(from_id, floor_number) and _path_node(to_id, floor_number + 1)
				var available: bool = floor_number + 1 == completed + 1 and _path_node(from_id, floor_number)
				var tint := GOLD if past else (Color("80b6c9") if available else Color("52616a", 0.33))
				draw_line(_node_position(from_id, floor_number), _node_position(to_id, floor_number + 1), tint, 3.0 if past or available else 1.5)
	for floor_number in range(1, Tower.MAX_FLOOR + 1):
		for node_id in _nodes_for_floor(floor_number):
			_draw_node(node_id, floor_number)


func _draw_tower(center_x: float, height: float) -> void:
	var stone := Color("283542", 0.72)
	var edge := Color("3a4a57", 0.56)
	draw_rect(Rect2(center_x - 160, 15, 320, height - 28), stone)
	draw_rect(Rect2(center_x - 176, 38, 16, height - 52), edge)
	draw_rect(Rect2(center_x + 160, 38, 16, height - 52), edge)
	for index in range(8):
		draw_rect(Rect2(center_x - 176 + index * 46, 4, 28, 25), stone)
	for index in range(3):
		var window_y: float = 58 + float(index) * (height - 110) / 3.0
		draw_rect(Rect2(center_x - 127, window_y, 13, 25), Color("667b83", 0.22))
		draw_rect(Rect2(center_x + 114, window_y, 13, 25), Color("667b83", 0.22))
	for y in range(48, int(height) - 24, 37):
		draw_line(Vector2(center_x - 157, y), Vector2(center_x + 157, y), Color("61717b", 0.17), 1.0)
		for x in range(-132, 148, 70):
			var offset: int = 35 if int(y / 37) % 2 == 0 else 0
			draw_line(Vector2(center_x + x + offset, y), Vector2(center_x + x + offset, y + 37), Color("61717b", 0.12), 1.0)


func _draw_fog(center_x: float, height: float) -> void:
	for floor_number in range(completed + 2, Tower.MAX_FLOOR + 1):
		var y: float = _floor_y(floor_number)
		draw_rect(Rect2(center_x - 175, y - 23, 350, 46), Color(FOG.r, FOG.g, FOG.b, 0.57))
	for index in range(8):
		var wisp_y: float = 23 + float(index) * (height - 46) / 8.0
		if wisp_y < _floor_y(completed + 1) - 20:
			draw_line(Vector2(center_x - 174, wisp_y), Vector2(center_x + 174, wisp_y + 8), Color("a4b0b5", 0.08), 9.0)


func _draw_node(node_id: String, floor_number: int) -> void:
	var point: Vector2 = _node_position(node_id, floor_number)
	var available: bool = floor_number == completed + 1
	var visited: bool = floor_number <= completed and _path_node(node_id, floor_number)
	var tint := GOLD if visited else (Color("9ce7d8") if available else MUTED)
	if available:
		draw_circle(point, 26, Color(tint.r, tint.g, tint.b, 0.13))
		draw_circle(point, 21, Color(tint.r, tint.g, tint.b, 0.19))
	elif floor_number > completed:
		tint.a = 0.34
	elif not visited:
		tint.a = 0.24
	var radius: float = 17 if available else 13
	if node_id == hovered_id or node_id == pinned_id:
		draw_circle(point, radius + 6, Color(GOLD.r, GOLD.g, GOLD.b, 0.42))
	draw_circle(point, radius, tint)
	draw_circle(point, radius - 3, Color("17222d"))
	var number_color := GOLD if visited else (Color("c5f6ec") if available else Color("8e9aa2", 0.48))
	draw_string(ThemeDB.fallback_font, point + Vector2(-9 if floor_number == 10 else -4, 5), str(floor_number), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, number_color)
	if available and not node_id.begins_with("floor:"):
		var route: Dictionary = Tower.route_by_id(node_id)
		var route_name: String = route.get("name", "")
		var sign: float = -1.0 if _route_index(node_id, floor_number) == 0 else 1.0
		var text_start: Vector2 = point + Vector2(-190 if sign < 0 else 27, 5)
		draw_string(ThemeDB.fallback_font, text_start, route_name, HORIZONTAL_ALIGNMENT_RIGHT if sign < 0 else HORIZONTAL_ALIGNMENT_LEFT, 160, 11, Color("d9e8e6"))
	if floor_number == Tower.MAX_FLOOR:
		draw_string(ThemeDB.fallback_font, point + Vector2(28, 5), "CHEFE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("bd8d75", 0.65 if not visited else 1.0))


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
