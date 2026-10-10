extends Node

signal started(scene_id: String)
signal ended(scene_id: String, completed: bool)
signal event_requested(event_id: String, payload: Dictionary)
signal line_shown(scene_id: String, line_id: String)
signal exit_requested

const Scenes = preload("res://data/narrative_scenes.gd")
const Overlay = preload("res://scripts/dialogue_overlay.gd")
const SEEN_PATH := "user://narrative_seen.cfg"

var seen_path := SEEN_PATH
var active := false
var scene_id := ""
var overlay: Control
var seen: Dictionary = {}
var characters_per_second := 36.0
var _scene: Dictionary = {}
var _line_by_id: Dictionary = {}
var _current: Dictionary = {}
var _host: Control
var _pause_timer: SceneTreeTimer
var _waiting_pause := false
var interaction_locked := false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(seen_path) == OK:
		for id in config.get_section_keys("seen") if config.has_section("seen") else []:
			seen[id] = bool(config.get_value("seen", id, false))


func start(id: String, target: Control) -> bool:
	if active or target == null or not is_instance_valid(target):
		return false
	var definition: Dictionary = Scenes.get_scene(id)
	if definition.is_empty():
		push_warning("Cena narrativa desconhecida: %s" % id)
		return false
	return start_definition(id, definition, target)


func start_definition(id: String, definition: Dictionary, target: Control) -> bool:
	if active or target == null or not is_instance_valid(target):
		return false
	var lines: Array = definition.get("lines", [])
	if lines.is_empty():
		return false
	_line_by_id.clear()
	for line in lines:
		var key := str(line.get("id", ""))
		if key.is_empty() or _line_by_id.has(key):
			push_warning("ID de fala ausente ou repetido em %s" % id)
			return false
		_line_by_id[key] = line
	_scene = definition
	scene_id = id
	_host = target
	active = true
	interaction_locked = false
	overlay = Overlay.new()
	overlay.characters_per_second = characters_per_second
	target.add_child(overlay)
	overlay.set_presentation(str(definition.get("presentation", "default")))
	overlay.advance_requested.connect(advance)
	overlay.exit_requested.connect(func() -> void: exit_requested.emit())
	overlay.skip_requested.connect(skip)
	overlay.set_skip_allowed(bool(definition.get("skippable_when_seen", false)) and bool(seen.get(id, false)))
	started.emit(id)
	var first := str(definition.get("first", lines[0].get("id", "")))
	_show(first)
	return true


func _show(line_id: String) -> void:
	if not active:
		return
	if not _line_by_id.has(line_id):
		push_warning("Próxima fala ausente em %s: %s" % [scene_id, line_id])
		finish()
		return
	_current = _line_by_id[line_id]
	overlay.show_line(_current)
	line_shown.emit(scene_id, line_id)
	var event_id := str(_current.get("event", ""))
	if not event_id.is_empty():
		event_requested.emit(event_id, _current)


func advance() -> void:
	if not active or _waiting_pause or interaction_locked:
		return
	if overlay.is_typing():
		overlay.complete_text()
		return
	var delay := maxf(0.0, float(_current.get("pause", 0.0)))
	if delay > 0.0:
		var waiting_scene := scene_id
		var waiting_line := str(_current.get("id", ""))
		_waiting_pause = true
		_pause_timer = get_tree().create_timer(delay, false)
		await _pause_timer.timeout
		_waiting_pause = false
		if not active or scene_id != waiting_scene or str(_current.get("id", "")) != waiting_line:
			return
	var next_id := str(_current.get("next", ""))
	if bool(_current.get("end", false)) or next_id.is_empty():
		if str(_scene.get("presentation", "")) == "resurrection":
			set_interaction_locked(true)
			var fade := create_tween()
			fade.tween_property(overlay, "modulate:a", 0.0, 0.38)
			await fade.finished
			if active:
				finish()
		else:
			finish()
	else:
		_show(next_id)


func skip() -> void:
	if active and bool(_scene.get("skippable_when_seen", false)) and bool(seen.get(scene_id, false)):
		finish()


func finish(mark_seen: bool = true) -> void:
	if not active:
		return
	var finished_id := scene_id
	active = false
	interaction_locked = false
	_waiting_pause = false
	if mark_seen:
		seen[finished_id] = true
		var config := ConfigFile.new()
		for id in seen:
			config.set_value("seen", id, seen[id])
		config.save(seen_path)
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	_current = {}
	_line_by_id.clear()
	scene_id = ""
	ended.emit(finished_id, mark_seen)


func set_interaction_locked(value: bool) -> void:
	interaction_locked = value
	if overlay != null and is_instance_valid(overlay):
		overlay.input_enabled = not value
