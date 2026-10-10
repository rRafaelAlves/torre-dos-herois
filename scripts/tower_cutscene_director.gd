extends Control

signal beat_finished(beat_id: String)

const GOBLIN = preload("res://assets/combat_sprites/goblin.png")
const RANGER = preload("res://assets/combat_sprites/patrulheiro_lado.png")
const GIRL = preload("res://assets/combat_sprites/garota_cena.png")
const WINGED = preload("res://assets/combat_sprites/figura_alada_cena.png")
const GUEIST = preload("res://assets/combat_sprites/guardiao.png")

var audio_manager: Node
var gate_open := 0.0
var gate_shake := 0.0
var finale := false
var winged_shadow := false
var _sprites: Dictionary = {}
var _busy := false
var _sequence := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for id in ["goblin_1", "goblin_2", "girl", "ranger", "winged", "gueist"]:
		var sprite := TextureRect.new()
		sprite.name = id
		sprite.texture = {"goblin_1": GOBLIN, "goblin_2": GOBLIN, "girl": GIRL, "ranger": RANGER, "winged": WINGED, "gueist": GUEIST}[id]
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_SCALE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.custom_minimum_size = Vector2(74, 74)
		sprite.size = Vector2(74, 74)
		sprite.visible = false
		add_child(sprite)
		_sprites[id] = sprite
	_place("goblin_1", 0.73, 0.53)
	_place("goblin_2", 0.89, 0.54)
	_place("girl", 0.81, 0.54)
	_place("ranger", 0.12, 0.58)
	_place("winged", 0.60, -0.20)
	_place("gueist", 0.48, 0.45)


func _extent() -> Vector2:
	return size if size.x > 100.0 and size.y > 100.0 else get_viewport_rect().size


func _place(id: String, x: float, y: float) -> void:
	var viewport_size := _extent()
	_sprites[id].position = Vector2(viewport_size.x * x, viewport_size.y * y)


func prepare_epilogue() -> void:
	gate_open = 1.0
	_sprites["gueist"].visible = true
	_sprites["gueist"].rotation = -0.15
	_place("gueist", 0.48, 0.55)
	queue_redraw()


func restore_state(scene_id: String, steps: Dictionary) -> void:
	if scene_id == "epilogo_gueist":
		prepare_epilogue()
		if bool(steps.get("epilogo_gueist:epilogue", false)):
			_place("gueist", 0.48, 0.62)
		if bool(steps.get("epilogo_gueist:open_path", false)):
			_sprites["gueist"].modulate.a = 0.0
		if bool(steps.get("epilogo_gueist:finale", false)):
			finale = true
		queue_redraw()
		return
	if bool(steps.get("entrada_torre:escort", false)):
		for who in ["goblin_1", "goblin_2", "girl"]:
			_sprites[who].visible = true
			_sprites[who].position.x -= 105.0
	if bool(steps.get("entrada_torre:arrows", false)):
		_sprites["ranger"].visible = true
		for who in ["goblin_1", "goblin_2"]:
			_sprites[who].rotation = 1.4
			_sprites[who].modulate.a = 0.2
	if bool(steps.get("entrada_torre:rescue", false)):
		_sprites["ranger"].position.x = _sprites["girl"].position.x - 95.0
	if bool(steps.get("entrada_torre:winged", false)):
		_sprites["winged"].visible = true
		_place("winged", 0.60, 0.38)
		winged_shadow = true
	if bool(steps.get("entrada_torre:flight", false)):
		_sprites["winged"].visible = false
		_sprites["girl"].visible = false
		winged_shadow = false
	if bool(steps.get("entrada_torre:gate_burst", false)):
		for who in ["ranger", "goblin_1", "goblin_2"]:
			_sprites[who].visible = false
		gate_open = 1.0
	if bool(steps.get("entrada_torre:boss_reveal", false)):
		_sprites["gueist"].visible = true
		_place("gueist", 0.48, 0.49)
	queue_redraw()


func play_beat(id: String) -> void:
	if _busy:
		return
	_busy = true
	_sequence += 1
	var token := _sequence
	match id:
		"arrival":
			pass
		"escort":
			for who in ["goblin_1", "goblin_2", "girl"]:
				_sprites[who].visible = true
			var movement := create_tween().set_parallel(true)
			for who in ["goblin_1", "goblin_2", "girl"]:
				movement.tween_property(_sprites[who], "position:x", _sprites[who].position.x - 105.0, 0.8)
			await movement.finished
		"arrows":
			_sprites["ranger"].visible = true
			_sound("bow")
			await _arrow_at("goblin_1")
			_sound("bow")
			await _arrow_at("goblin_2")
		"rescue":
			var rescue := create_tween()
			rescue.tween_property(_sprites["ranger"], "position:x", _sprites["girl"].position.x - 95.0, 0.55)
			await rescue.finished
		"winged":
			winged_shadow = true
			queue_redraw()
			if audio_manager != null:
				audio_manager.start_wind()
			_sprites["winged"].visible = true
			var descent := create_tween()
			descent.tween_property(_sprites["winged"], "position:y", _extent().y * 0.38, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			await descent.finished
		"flight":
			winged_shadow = false
			queue_redraw()
			if audio_manager != null:
				audio_manager.start_wind()
			var rise := create_tween().set_parallel(true)
			for who in ["winged", "girl"]:
				rise.tween_property(_sprites[who], "position:y", -110.0, 1.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				rise.tween_property(_sprites[who], "modulate:a", 0.0, 1.15)
			await rise.finished
			_sprites["winged"].visible = false
			_sprites["girl"].visible = false
		"gate_burst":
			for who in ["ranger", "goblin_1", "goblin_2"]:
				_sprites[who].visible = false
			for hit in range(3):
				_sound("physical_hit")
				gate_shake = 3.0 if hit < 2 else 6.0
				queue_redraw()
				await get_tree().create_timer(0.3, false).timeout
			gate_shake = 0.0
			gate_open = 1.0
			queue_redraw()
		"boss_reveal":
			_sprites["gueist"].visible = true
			_place("gueist", 0.48, 0.36)
			var entry := create_tween()
			entry.tween_property(_sprites["gueist"], "position:y", _extent().y * 0.49, 0.5)
			await entry.finished
		"epilogue":
			prepare_epilogue()
			var fall := create_tween()
			fall.tween_property(_sprites["gueist"], "position:y", _extent().y * 0.62, 0.48)
			await fall.finished
		"open_path":
			var fade := create_tween()
			fade.tween_property(_sprites["gueist"], "modulate:a", 0.0, 0.6)
			await fade.finished
		"finale":
			finale = true
			queue_redraw()
	if is_inside_tree() and token == _sequence:
		_busy = false
		beat_finished.emit(id)


func _arrow_at(target_id: String) -> void:
	var arrow := ColorRect.new()
	arrow.color = Color("e4d4ad")
	arrow.size = Vector2(33, 3)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.position = _sprites["ranger"].position + Vector2(60, 24)
	add_child(arrow)
	var flight := create_tween()
	flight.tween_property(arrow, "position", _sprites[target_id].position + Vector2(22, 30), 0.28)
	await flight.finished
	arrow.queue_free()
	_sound("arrow")
	_sound("physical_hit")
	var fall := create_tween()
	fall.tween_property(_sprites[target_id], "rotation", 1.4, 0.26)
	fall.parallel().tween_property(_sprites[target_id], "modulate:a", 0.2, 0.26)
	await fall.finished


func _sound(name: String) -> void:
	if audio_manager != null:
		audio_manager.play(name)


func _draw() -> void:
	var area := _extent()
	if gate_open > 0.0:
		var gate := Rect2(area.x * 0.385, area.y * 0.33, area.x * 0.23, area.y * 0.25)
		draw_rect(gate, Color("14171e"))
		draw_line(Vector2(gate.position.x + gate.size.x * 0.5, gate.position.y), Vector2(gate.position.x + gate.size.x * 0.5, gate.end.y), Color("3b4348"), 3.0)
		for i in range(6):
			var x := gate.position.x + float(i) * gate.size.x / 5.0
			draw_rect(Rect2(x, gate.end.y + 4.0 + float(i % 2) * 8.0, 16, 5), Color("76503a"))
	elif gate_shake > 0.0:
		draw_rect(Rect2(area.x * 0.385 + gate_shake, area.y * 0.33, area.x * 0.23, area.y * 0.25), Color(0.30, 0.20, 0.14, 0.28))
	if winged_shadow:
		draw_circle(Vector2(area.x * 0.58, area.y * 0.64), 76.0, Color(0.02, 0.02, 0.07, 0.34))
		for i in range(9):
			var pos := Vector2(area.x * (0.29 + 0.075 * float(i)), area.y * (0.25 + 0.035 * float(i % 4)))
			draw_line(pos, pos + Vector2(14.0, 5.0), Color(0.05, 0.05, 0.09, 0.8), 3.0)
	if finale:
		draw_rect(Rect2(Vector2.ZERO, area), Color(0.01, 0.018, 0.03, 0.40))
