extends Control

## Ambiente visual da arena e folhas do menu, com o mesmo movimento procedural.
## Na arena, instancie uma camada abaixo das unidades e outra acima.

const MAX_BACK_LEAVES := 7
const MAX_FRONT_LEAVES := 3
const MAX_MENU_LEAVES := 30

@export var foreground: bool = false
@export var menu_leaves: bool = false

var rng := RandomNumberGenerator.new()
var leaves: Array[Dictionary] = []
var elapsed: float = 0.0
var gust: float = 0.0
var gust_goal: float = 0.0
var gust_change_in: float = 2.0
var spawn_in: float = 0.0
var gust_goal_updates: int = 0
var tuft_phases: Array[float] = []
var cloud_offsets: Array[float] = [0.0, 0.48, 0.79]
var seeded := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	rng.randomize()
	for index in range(7):
		tuft_phases.append(rng.randf_range(0.0, TAU))
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	if not seeded:
		_seed_leaves()
	elapsed += delta
	gust_change_in -= delta
	if gust_change_in <= 0.0:
		gust_goal = rng.randf_range(0.25, 0.9) if gust < 0.35 else 0.0
		gust_change_in = rng.randf_range(2.6, 5.4)
		gust_goal_updates += 1
	gust = move_toward(gust, gust_goal, delta * 0.18)
	spawn_in -= delta
	if spawn_in <= 0.0 and leaves.size() < _leaf_limit():
		_spawn_leaf()
		spawn_in = lerpf(0.38, 0.14, gust) if menu_leaves else (lerpf(1.35, 0.42, gust) if not foreground else lerpf(2.0, 0.72, gust))
	for index in range(leaves.size() - 1, -1, -1):
		var leaf: Dictionary = leaves[index]
		leaf["age"] = float(leaf["age"]) + delta
		var phase: float = float(leaf["phase"]) + delta * float(leaf["sway_speed"])
		leaf["phase"] = phase
		var velocity: Vector2 = leaf["velocity"]
		var position: Vector2 = leaf["position"]
		position += velocity * (1.0 + gust * 0.55) * delta
		position.y += sin(phase) * float(leaf["sway"]) * delta
		leaf["position"] = position
		leaf["rotation"] = float(leaf["rotation"]) + float(leaf["spin"]) * delta
		leaves[index] = leaf
		if float(leaf["age"]) >= float(leaf["lifetime"]) or position.x < -14.0 or position.x > size.x + 14.0 or position.y < -12.0 or position.y > size.y + 12.0:
			leaves.remove_at(index)
	queue_redraw()


func _leaf_limit() -> int:
	return MAX_MENU_LEAVES if menu_leaves else (MAX_FRONT_LEAVES if foreground else MAX_BACK_LEAVES)


func _seed_leaves() -> void:
	seeded = true
	for index in range(18 if menu_leaves else (2 if foreground else 3)):
		_spawn_leaf(rng.randf_range(0.0, size.x), rng.randf_range(size.y * 0.2, size.y * 0.86))


func cloud_x_at(index: int) -> float:
	var speeds := [2.2, 3.1, 1.6]
	return fposmod(cloud_offsets[index] * size.x + elapsed * speeds[index], size.x + 80.0) - 40.0


func _spawn_leaf(x_override: float = -99999.0, y_override: float = -99999.0) -> void:
	var from_left: bool = rng.randf() > 0.28
	var direction: float = 1.0 if from_left else -1.0
	var position_x: float = x_override
	if position_x < -1000.0:
		position_x = -8.0 if from_left else size.x + 8.0
	var position_y: float = y_override
	if position_y < -1000.0:
		position_y = rng.randf_range(size.y * 0.22, size.y * 0.9)
	var speed: float = rng.randf_range(30.0, 52.0) if menu_leaves else (rng.randf_range(15.0, 28.0) if not foreground else rng.randf_range(30.0, 52.0))
	var width: int = rng.randi_range(8, 12) if menu_leaves else (rng.randi_range(2, 3) if not foreground else rng.randi_range(3, 4))
	var palette: Array[Color] = [Color("88b95c"), Color("aec966"), Color("d1b765"), Color("8f774b")]
	leaves.append({
		"position": Vector2(position_x, position_y),
		"velocity": Vector2(speed * direction, rng.randf_range(-5.0, 5.0)),
		"phase": rng.randf_range(0.0, TAU),
		"sway_speed": rng.randf_range(2.0, 4.2),
		"sway": rng.randf_range(5.0, 13.0),
		"spin": rng.randf_range(-1.2, 1.2),
		"rotation": rng.randf_range(-0.35, 0.35),
		"width": width,
		"color": palette[rng.randi_range(0, palette.size() - 1)],
		"age": 0.0,
		"lifetime": rng.randf_range(7.5, 13.0),
	})


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	if not foreground and not menu_leaves:
		_draw_clouds()
		_draw_grass()
	for leaf in leaves:
		_draw_leaf(leaf)


func _draw_clouds() -> void:
	# Light pixel clouds drift at two depths without replacing the existing landscape.
	var cloud_y := [size.y * 0.035, size.y * 0.105, size.y * 0.07]
	var cloud_scale := [1.0, 0.72, 0.56]
	for index in range(cloud_offsets.size()):
		var x: float = cloud_x_at(index)
		var y: float = cloud_y[index] + sin(elapsed * 0.19 + index) * 1.5
		_draw_cloud(Vector2(x, y), cloud_scale[index])


func _draw_cloud(origin: Vector2, scale_factor: float) -> void:
	var cloud_color := Color(0.76, 0.9, 0.91, 0.28)
	var pixel := 6.0 * scale_factor
	for block in [Vector2(1, 1), Vector2(2, 0), Vector2(3, 1), Vector2(4, 1), Vector2(5, 2)]:
		draw_rect(Rect2(origin + block * pixel, Vector2(pixel * (1.2 if block.x == 2 else 1.0), pixel)), cloud_color)


func _draw_grass() -> void:
	var base_y := size.y * 0.92
	for index in range(tuft_phases.size()):
		var x := size.x * (0.08 + float(index) * 0.14)
		var y := base_y + sin(elapsed * 0.8 + tuft_phases[index]) * 1.2
		var sway := sin(elapsed * 1.1 + tuft_phases[index]) * (1.0 + gust * 1.4)
		var green := Color("527f3b", 0.7)
		draw_rect(Rect2(Vector2(x + sway, y - 6.0), Vector2(2, 6)), green)
		draw_rect(Rect2(Vector2(x + 2.0 + sway * 0.5, y - 4.0), Vector2(2, 4)), Color("88ad4d", 0.78))
		draw_rect(Rect2(Vector2(x + 4.0, y - 3.0), Vector2(2, 3)), green)


func _draw_leaf(leaf: Dictionary) -> void:
	var position: Vector2 = leaf["position"]
	var edge_fade: float = minf(minf(position.x, size.x - position.x), minf(position.y, size.y - position.y)) / 9.0
	var life_fade: float = minf(float(leaf["age"]) / 0.25, (float(leaf["lifetime"]) - float(leaf["age"])) / 0.6)
	var color: Color = leaf["color"]
	color.a *= clampf(minf(edge_fade, life_fade), 0.0, 1.0) * (0.72 if foreground or menu_leaves else 0.5)
	var width: float = float(leaf["width"])
	var height: float = 4.5 if menu_leaves else (2.0 if foreground else 1.5)
	var angle: float = float(leaf["rotation"]) + sin(float(leaf["phase"])) * 0.24
	draw_set_transform(position, angle)
	draw_rect(Rect2(Vector2(-width * 0.5, -height * 0.5), Vector2(width, height)), color)
	draw_rect(Rect2(Vector2(0.0, -height), Vector2(1.0, height * 2.0)), Color(color.r, color.g, color.b, color.a * 0.75))
	draw_set_transform(Vector2.ZERO)
