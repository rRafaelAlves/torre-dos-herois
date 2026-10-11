extends Control

signal sfx_cue(sound_name: String, volume_db: float)

const CombatSprites = preload("res://data/combat_sprites.gd")
const ActionGlyph = preload("res://scripts/combat_action_glyph.gd")
const HeroSkillEffect = preload("res://scripts/hero_skill_effect.gd")

const IDLE_FRAME_SECONDS := 0.29
const DAMAGE_SECONDS := 0.24
const POPUP_SECONDS := 0.62
const COLORS := {
	"physical": Color("f2f1ea"),
	"fire": Color("ff7952"),
	"magical": Color("c993ec"),
	"poison": Color("79cc76"),
	"radiant": Color("f5d874"),
	"heal": Color("9ae68f"),
}

var sprites: Dictionary = {}
var arena_panels: Dictionary = {}
var frames: Dictionary = {}
var origins: Dictionary = {}
var living: Dictionary = {}
var teams: Dictionary = {}
var reactions: Dictionary = {}
var death_started: Dictionary = {}
var idle_elapsed: float = 0.0
var idle_frame: int = 0
var active_actor: String = ""
var displayed_event_count: int = 0
var action_number_offsets: Dictionary = {}
var boss_phase_active := false
var boss_phase_elapsed := 0.0
var boss_phase_burst := 0.0


func bind_arena(arena_cards: Dictionary, hero_ids: Array[String]) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for fighter_id in arena_cards:
		var sprite: TextureRect = arena_cards[fighter_id]["sprite"]
		sprites[fighter_id] = sprite
		arena_panels[fighter_id] = arena_cards[fighter_id]["panel"]
		origins[fighter_id] = sprite.position
		teams[fighter_id] = "hero" if fighter_id in hero_ids else "enemy"
		var idle_frames: Array[Texture2D] = CombatSprites.idle_frames_for(fighter_id)
		if idle_frames.size() >= 3:
			frames[fighter_id] = idle_frames
	set_process(true)


func update_fighters(fighters: Dictionary) -> void:
	if bool(fighters.get("guardiao", {}).get("boss_phase_two", false)):
		boss_phase_active = true
	for fighter_id in sprites:
		var fighter: Dictionary = fighters.get(fighter_id, {})
		var alive: bool = fighter.get("state", "") == "alive" and int(fighter.get("hp", 0)) > 0
		living[fighter_id] = alive
		if not alive and not death_started.has(fighter_id) and frames.has(fighter_id):
			var sprite: TextureRect = sprites[fighter_id]
			if is_instance_valid(sprite):
				sprite.texture = frames[fighter_id][0]


func play_enemy_deaths(fighters: Dictionary, rewards: Dictionary = {}) -> void:
	var started_any := false
	for fighter_id in sprites:
		if teams.get(fighter_id, "") != "enemy" or death_started.has(fighter_id):
			continue
		var fighter: Dictionary = fighters.get(fighter_id, {})
		if fighter.is_empty() or (int(fighter.get("hp", 0)) > 0 and fighter.get("state", "") != "dead"):
			continue
		death_started[fighter_id] = true
		started_any = true
		_start_enemy_death(fighter_id, rewards.get(fighter_id, {}))
	if started_any:
		await get_tree().create_timer(0.84, false).timeout


func _start_enemy_death(fighter_id: String, reward: Dictionary = {}) -> void:
	if not sprites.has(fighter_id) or not is_instance_valid(sprites[fighter_id]):
		return
	var sprite: TextureRect = sprites[fighter_id]
	var origin: Vector2 = origins[fighter_id]
	sprite.pivot_offset = sprite.size * 0.5
	var fall := create_tween()
	fall.tween_property(sprite, "position", origin + Vector2(0, 8), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(sprite, "rotation_degrees", 90.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(sprite, "self_modulate", Color("d5c4a5"), 0.24)
	fall.tween_interval(0.18)
	fall.tween_callback(func() -> void:
		if is_instance_valid(sprite):
			var center: Vector2 = sprite.global_position - global_position + sprite.size * 0.5
			_spawn_death_stars(center)
			if not reward.is_empty():
				_spawn_reward_popup(center, reward)
				sfx_cue.emit("xp_gain", -4.0)
	)
	fall.tween_property(sprite, "position", origin + Vector2(0, -19), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fall.parallel().tween_property(sprite, "scale", Vector2(0.62, 0.62), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(sprite, "modulate:a", 0.0, 0.42)
	fall.finished.connect(func() -> void:
		if is_instance_valid(sprite):
			sprite.visible = false
		var arena_panel: Control = arena_panels.get(fighter_id)
		if is_instance_valid(arena_panel):
			arena_panel.visible = false
	)


func _spawn_death_stars(center: Vector2) -> void:
	var offsets: Array[Vector2] = [Vector2(-11, 0), Vector2(2, -7), Vector2(12, 2), Vector2(-5, 8), Vector2(7, 10)]
	for index in offsets.size():
		var star := Label.new()
		star.text = "✦" if index % 2 == 0 else "★"
		star.position = center + offsets[index]
		star.size = Vector2(16, 16)
		star.pivot_offset = Vector2(8, 8)
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.add_theme_font_size_override("font_size", 11 if index % 2 == 0 else 9)
		star.add_theme_color_override("font_color", Color("ffe28a") if index % 2 == 0 else Color("fff4cc"))
		star.add_theme_color_override("font_outline_color", Color("6e4524"))
		star.add_theme_constant_override("outline_size", 2)
		add_child(star)
		var drift: Vector2 = Vector2(float(index - 2) * 5.0, -24.0 - float(index % 3) * 8.0)
		var sparkle := create_tween()
		sparkle.set_parallel(true)
		sparkle.tween_property(star, "position", star.position + drift, 0.48).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		sparkle.tween_property(star, "scale", Vector2(1.35, 1.35), 0.48)
		sparkle.tween_property(star, "modulate:a", 0.0, 0.48)
		sparkle.finished.connect(star.queue_free)


func _spawn_reward_popup(center: Vector2, reward: Dictionary) -> void:
	var popup := Label.new()
	popup.text = "+%d XP   +%d ◈" % [int(reward.get("xp", 0)), int(reward.get("coins", 0))]
	popup.position = center + Vector2(-66, -25)
	popup.size = Vector2(132, 24)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_theme_font_size_override("font_size", 14)
	popup.add_theme_color_override("font_color", Color("fff0a8"))
	popup.add_theme_color_override("font_outline_color", Color("382719"))
	popup.add_theme_constant_override("outline_size", 3)
	add_child(popup)
	var float_tween := create_tween()
	float_tween.set_parallel(true)
	float_tween.tween_property(popup, "position", popup.position + Vector2(0, -30), 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	float_tween.tween_property(popup, "modulate:a", 0.0, 0.72).set_delay(0.18)
	float_tween.finished.connect(popup.queue_free)


func _process(delta: float) -> void:
	if boss_phase_active and living.get("guardiao", false):
		boss_phase_elapsed += delta
		boss_phase_burst = maxf(0.0, boss_phase_burst - delta / 0.9)
		queue_redraw()
	idle_elapsed += delta
	if idle_elapsed < IDLE_FRAME_SECONDS:
		return
	idle_elapsed = fmod(idle_elapsed, IDLE_FRAME_SECONDS)
	idle_frame += 1
	for fighter_id in frames:
		if not living.get(fighter_id, false) or reactions.has(fighter_id) or fighter_id == active_actor:
			continue
		var sprite: TextureRect = sprites[fighter_id]
		if is_instance_valid(sprite):
			var actor_frames: Array = frames[fighter_id]
			sprite.texture = actor_frames[idle_frame % actor_frames.size()]


func _draw() -> void:
	if not boss_phase_active or not living.get("guardiao", false) or not sprites.has("guardiao") or not is_instance_valid(sprites["guardiao"]):
		return
	var center := _center_of("guardiao") + Vector2(0, -3)
	var pulse := 0.5 + 0.5 * sin(boss_phase_elapsed * 3.1)
	var radius := 43.0 + pulse * 4.0 + boss_phase_burst * 20.0
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.56, 0.43, 0.87, 0.19 + pulse * 0.12), 2.0, false)
	draw_arc(center, radius + 7.0, 0.0, TAU, 48, Color(0.42, 0.65, 0.96, 0.09 + boss_phase_burst * 0.38), 1.0, false)
	for index in 7:
		var angle := TAU * float(index) / 7.0 + boss_phase_elapsed * 0.42
		var point := center + Vector2(cos(angle), sin(angle)) * (radius + 4.0 + sin(boss_phase_elapsed * 2.0 + float(index)) * 4.0)
		draw_circle(point, 1.5 + boss_phase_burst * 2.0, Color(0.75, 0.79, 1.0, 0.38 + pulse * 0.22))


func play_boss_phase_transition() -> void:
	if not is_inside_tree() or not sprites.has("guardiao") or not is_instance_valid(sprites["guardiao"]):
		return
	boss_phase_active = true
	boss_phase_burst = 1.0
	var boss_sprite: TextureRect = sprites["guardiao"]
	var center := _center_of("guardiao")
	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = Color(0.04, 0.03, 0.11, 0.0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var title := Label.new()
	LocaleManager.set_text(title, "FASE II · O ECLIPSE")
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(clampf(center.x - 120.0, 0.0, maxf(0.0, size.x - 240.0)), maxf(5.0, center.y - 94.0))
	title.size = Vector2(240, 28)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("d7cbff"))
	title.add_theme_color_override("font_outline_color", Color("1b1430"))
	title.add_theme_constant_override("outline_size", 4)
	add_child(title)
	sfx_cue.emit("curse", -1.0)
	var reveal := create_tween()
	reveal.set_parallel(true)
	reveal.tween_property(veil, "color:a", 0.32, 0.28)
	reveal.tween_property(boss_sprite, "scale", Vector2(1.16, 1.16), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reveal.tween_property(title, "position:y", title.position.y - 15.0, 0.72).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal.tween_property(title, "modulate:a", 0.0, 0.72).set_delay(0.38)
	await reveal.finished
	if not is_inside_tree():
		return
	var release := create_tween()
	release.set_parallel(true)
	release.tween_property(veil, "color:a", 0.0, 0.35)
	release.tween_property(boss_sprite, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await release.finished
	veil.queue_free()
	title.queue_free()


func show_events(visual_events: Array) -> void:
	var hit_targets: Dictionary = {}
	var counts: Dictionary = {}
	for event in visual_events:
		var fighter_id: String = str(event.get("target_id", ""))
		if not sprites.has(fighter_id) or int(event.get("amount", 0)) <= 0:
			continue
		var sequence: int = int(action_number_offsets.get(fighter_id, 0)) if active_actor != "" else int(counts.get(fighter_id, 0))
		counts[fighter_id] = sequence + 1
		if active_actor != "":
			action_number_offsets[fighter_id] = sequence + 1
		_spawn_number(fighter_id, event, sequence)
		if event.get("kind", "") == "damage" and not hit_targets.has(fighter_id):
			hit_targets[fighter_id] = true
			_react(fighter_id)


func play_action(action: Dictionary, visual_events: Array) -> void:
	var actor_id: String = str(action.get("actor_id", ""))
	if not sprites.has(actor_id) or not is_instance_valid(sprites[actor_id]):
		show_events(visual_events)
		return
	var sprite: TextureRect = sprites[actor_id]
	var origin: Vector2 = origins[actor_id]
	var style: String = str(action.get("style", "melee"))
	var targets: Array = action.get("targets", [])
	var impact_targets: Array[String] = []
	for target_id in targets:
		if sprites.has(target_id) and is_instance_valid(sprites[target_id]):
			impact_targets.append(str(target_id))
	if bool(action.get("area", false)) and style != "curse":
		var actual_targets: Array[String] = []
		for event in visual_events:
			var target_id: String = str(event.get("target_id", ""))
			if target_id in impact_targets and not target_id in actual_targets:
				actual_targets.append(target_id)
		impact_targets = actual_targets
	active_actor = actor_id
	_emit_start_sound(action)
	var skill_id: String = str(action.get("action_id", "")).trim_prefix("skill:") if str(action.get("action_id", "")).begins_with("skill:") else ""
	if not skill_id.is_empty() and teams.get(actor_id, "") == "hero":
		_spawn_hero_skill_effect(skill_id, actor_id, "cast")
	action_number_offsets.clear()
	if actor_id == "guardiao" and str(action.get("action_id", "")) in ["attack", "shadow_wave", "devastating_impact", "spectral_strike"]:
		await _play_guardiao_action(action, visual_events, impact_targets, sprite, origin)
		return
	var advance: float = 10.0 if style == "melee" else 3.0
	if teams[actor_id] == "enemy":
		advance *= -1.0
	var ready: Tween = create_tween()
	ready.set_parallel(true)
	ready.tween_property(sprite, "position", origin + Vector2(advance * 0.35, -3.0), 0.11)
	ready.tween_property(sprite, "rotation_degrees", -5.0 if advance > 0 else 5.0, 0.11)
	await ready.finished
	if not is_inside_tree():
		return
	if style == "feint":
		var feint: Tween = create_tween()
		feint.tween_property(sprite, "position", origin + Vector2(12, -4), 0.10)
		feint.tween_property(sprite, "position", origin + Vector2(-10, -2), 0.10)
		await feint.finished
		await _flash_at(actor_id, "feint", Color("d5cf9d"))
	elif style == "charge":
		await _flash_at(actor_id, "slash", Color("dc825d"), true)
	elif style == "melee":
		var lunge: Tween = create_tween()
		lunge.tween_property(sprite, "position", origin + Vector2(advance, -2.0), 0.12)
		await lunge.finished
		if not is_inside_tree():
			return
		_emit_impact_sound(action, visual_events)
		for target_id in impact_targets:
			await _flash_at(target_id, "slash", Color("f6d49b"), bool(action.get("powerful", false)))
	elif style == "guard":
		for target_id in impact_targets:
			await _flash_at(target_id, "sacred", Color("83cbd5"))
	elif style == "sacred":
		await _flash_at(actor_id, "sacred", Color("f4d475"))
		_emit_impact_sound(action, visual_events)
		for target_id in impact_targets:
			await _flash_at(target_id, "sacred", Color("f4d475"))
	elif style == "curse" and bool(action.get("status", false)):
		await _flash_at(actor_id, "curse", Color("bd78db"))
		for target_id in impact_targets:
			await _flash_at(target_id, "curse", Color("bd78db"))
	elif style == "curse" and impact_targets == [actor_id]:
		await _flash_at(actor_id, "curse", Color("bd78db"))
	else:
		var projectile_style: String = "arrow" if style == "arrow" else ("fire" if style == "fire" else "arcane")
		var tint: Color = _action_color(style)
		await _flash_at(actor_id, projectile_style, tint)
		var shots: int = maxi(1, int(action.get("hits", 1)))
		if shots > 1 and impact_targets.size() == 1:
			var hit_events: Array = []
			var other_events: Array = []
			for event in visual_events:
				if event.get("kind", "") == "damage" and event.get("target_id", "") == impact_targets[0]:
					hit_events.append(event)
				else:
					other_events.append(event)
			for hit in range(mini(shots, hit_events.size())):
				_emit_projectile_sound(style)
				await _projectile(actor_id, impact_targets[0], projectile_style, tint)
				_emit_impact_sound(action, [hit_events[hit]])
				await _flash_at(impact_targets[0], "slash" if style == "arrow" else projectile_style, tint)
				show_events([hit_events[hit]])
			if hit_events.is_empty():
				_emit_projectile_sound(style)
				await _projectile(actor_id, impact_targets[0], projectile_style, tint)
				await _flash_at(impact_targets[0], projectile_style, tint)
			if not skill_id.is_empty():
				_spawn_hero_skill_effect(skill_id, impact_targets[0], "impact")
			show_events(other_events)
			await _return_actor(sprite, origin)
			return
		if not impact_targets.is_empty():
			_emit_projectile_sound(style)
			await _projectile(actor_id, impact_targets[0], projectile_style, tint)
		_emit_impact_sound(action, visual_events)
		for target_id in impact_targets:
			await _flash_at(target_id, projectile_style, tint)
	if is_inside_tree():
		if not skill_id.is_empty():
			for target_id in impact_targets:
				_spawn_hero_skill_effect(skill_id, target_id, "impact")
		show_events(visual_events)
		await _return_actor(sprite, origin)


func _spawn_hero_skill_effect(skill_id: String, fighter_id: String, phase: String) -> void:
	if not sprites.has(fighter_id) or not is_instance_valid(sprites[fighter_id]):
		return
	var effect = HeroSkillEffect.new()
	effect.skill_id = skill_id
	effect.phase = phase
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effect)
	effect.position = _center_of(fighter_id) - Vector2(60, 60)


func _play_guardiao_action(action: Dictionary, visual_events: Array, impact_targets: Array[String], sprite: TextureRect, origin: Vector2) -> void:
	var action_id: String = str(action.get("action_id", ""))
	var direction: float = -1.0 if teams.get("guardiao", "enemy") == "enemy" else 1.0
	sprite.pivot_offset = sprite.size * 0.5
	match action_id:
		"attack":
			var windup := create_tween()
			windup.set_parallel(true)
			windup.tween_property(sprite, "position", origin + Vector2(-direction * 5.0, -5.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			windup.tween_property(sprite, "rotation_degrees", 10.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			windup.tween_property(sprite, "scale", Vector2(1.08, 0.94), 0.18)
			await windup.finished
			var strike := create_tween()
			strike.set_parallel(true)
			strike.tween_property(sprite, "position", origin + Vector2(direction * 17.0, -1.0), 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			strike.tween_property(sprite, "rotation_degrees", -13.0, 0.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			strike.tween_property(sprite, "scale", Vector2(0.94, 1.06), 0.10)
			await strike.finished
			_emit_impact_sound(action, visual_events)
			for target_id in impact_targets:
				await _flash_at(target_id, "slash", Color("c9b5a2"), true)
		"shadow_wave":
			await _play_guardiao_shadow_wave(visual_events, impact_targets, sprite, origin)
		"spectral_strike":
			var windup := create_tween()
			windup.set_parallel(true)
			windup.tween_property(sprite, "position", origin + Vector2(-direction * 6.0, -9.0), 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			windup.tween_property(sprite, "rotation_degrees", 9.0, 0.24)
			windup.tween_property(sprite, "self_modulate", Color("aaa2e7"), 0.24)
			await windup.finished
			if not is_inside_tree():
				return
			var strike := create_tween()
			strike.set_parallel(true)
			strike.tween_property(sprite, "position", origin + Vector2(direction * 19.0, -3.0), 0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			strike.tween_property(sprite, "rotation_degrees", -17.0, 0.13)
			await strike.finished
			_emit_impact_sound(action, visual_events)
			for target_id in impact_targets:
				await _flash_at(target_id, "spectral_blade", Color("aebaff"), true)
		"devastating_impact":
			var charge := create_tween()
			charge.set_parallel(true)
			charge.tween_property(sprite, "position", origin + Vector2(-direction * 4.0, -9.0), 0.23).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			charge.tween_property(sprite, "rotation_degrees", 7.0, 0.23)
			charge.tween_property(sprite, "self_modulate", Color("d8a8a0"), 0.23)
			await charge.finished
			var slam := create_tween()
			slam.set_parallel(true)
			slam.tween_property(sprite, "position", origin + Vector2(direction * 20.0, 4.0), 0.11).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			slam.tween_property(sprite, "rotation_degrees", -15.0, 0.11)
			slam.tween_property(sprite, "scale", Vector2(1.12, 0.88), 0.11)
			await slam.finished
			_emit_impact_sound(action, visual_events)
			for target_id in impact_targets:
				await _flash_at(target_id, "slash", Color("f0c38a"), true)
	if is_inside_tree():
		show_events(visual_events)
		await _return_actor(sprite, origin)


func _play_guardiao_shadow_wave(visual_events: Array, impact_targets: Array[String], sprite: TextureRect, origin: Vector2) -> void:
	var charge := create_tween()
	charge.set_parallel(true)
	var direction: float = -1.0 if teams.get("guardiao", "enemy") == "enemy" else 1.0
	charge.tween_property(sprite, "position", origin + Vector2(-direction * 4.0, -7.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	charge.tween_property(sprite, "scale", Vector2(1.12, 1.12), 0.22)
	charge.tween_property(sprite, "self_modulate", Color("bb8bd4"), 0.22)
	await charge.finished
	if not is_inside_tree():
		return
	var center: Vector2 = _center_of("guardiao")
	for ring_index in 3:
		var wave: Control = ActionGlyph.new()
		wave.style = "shadow_wave"
		wave.tint = Color("b77be2") if ring_index == 0 else Color("7950ad")
		wave.size = Vector2(24, 24)
		wave.pivot_offset = wave.size * 0.5
		wave.position = center - wave.size * 0.5
		wave.scale = Vector2(0.35, 0.35)
		wave.modulate.a = 0.92
		add_child(wave)
		var expand := create_tween()
		expand.set_parallel(true)
		expand.tween_property(wave, "scale", Vector2(12.0, 12.0), 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		expand.tween_property(wave, "modulate:a", 0.0, 0.52).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		expand.finished.connect(wave.queue_free)
		if ring_index < 2:
			await get_tree().create_timer(0.09, false).timeout
	_emit_impact_sound({"action_id": "shadow_wave"}, visual_events)
	for target_id in impact_targets:
		await _flash_at(target_id, "curse", Color("b77be2"), true)


func _emit_start_sound(action: Dictionary) -> void:
	var style: String = str(action.get("style", "melee"))
	var sound_name := "sword"
	match style:
		"arrow": sound_name = "bow"
		"arcane": sound_name = "arcane_cast"
		"fire": sound_name = "fire_cast"
		"curse": sound_name = "curse"
		"sacred": sound_name = "holy"
		"guard": sound_name = "shield"
		"charge": sound_name = "shield"
		"feint": sound_name = "bow"
	sfx_cue.emit(sound_name, 1.0 if bool(action.get("powerful", false)) else -2.0)


func _emit_projectile_sound(style: String) -> void:
	sfx_cue.emit("arrow" if style == "arrow" else "magic_projectile", -3.0)


func _emit_impact_sound(action: Dictionary, events: Array) -> void:
	var damage: Dictionary = {}
	var healed: bool = false
	for event in events:
		if int(event.get("amount", 0)) <= 0:
			continue
		if event.get("kind", "") == "damage":
			if damage.is_empty() or bool(event.get("critical", false)):
				damage = event
		elif event.get("kind", "") == "heal":
			healed = true
	if not damage.is_empty():
		if bool(damage.get("critical", false)):
			sfx_cue.emit("critical_hit", -1.0)
		elif str(damage.get("visual_type", "physical")) == "fire":
			sfx_cue.emit("fire_burst", -2.0)
		elif str(damage.get("visual_type", "physical")) in ["magical", "poison", "radiant"]:
			sfx_cue.emit("magic_hit", -3.0)
		else:
			sfx_cue.emit("physical_hit", -2.0)
	elif healed:
		var action_id: String = str(action.get("action_id", ""))
		sfx_cue.emit("revive" if action_id in ["rescue", "skill:milagre_divino"] else "heal", -2.0)


func _return_actor(sprite: TextureRect, origin: Vector2) -> void:
	if not is_instance_valid(sprite):
		return
	var back: Tween = create_tween()
	back.set_parallel(true)
	back.tween_property(sprite, "position", origin, 0.16)
	back.tween_property(sprite, "rotation_degrees", 0.0, 0.16)
	back.tween_property(sprite, "scale", Vector2.ONE, 0.16)
	back.tween_property(sprite, "self_modulate", Color.WHITE, 0.16)
	await back.finished
	if is_instance_valid(sprite):
		sprite.position = origin
		sprite.rotation_degrees = 0.0
		sprite.scale = Vector2.ONE
		sprite.self_modulate = Color.WHITE
	active_actor = ""
	action_number_offsets.clear()


func _projectile(actor_id: String, target_id: String, glyph_style: String, tint: Color) -> void:
	if not sprites.has(target_id) or not is_instance_valid(sprites[target_id]):
		return
	var glyph: Control = ActionGlyph.new()
	glyph.style = glyph_style
	glyph.tint = tint
	add_child(glyph)
	glyph.position = _center_of(actor_id)
	var tween: Tween = create_tween()
	tween.tween_property(glyph, "position", _center_of(target_id), 0.19)
	await tween.finished
	if is_instance_valid(glyph):
		glyph.queue_free()


func _flash_at(fighter_id: String, glyph_style: String, tint: Color, powerful: bool = false) -> void:
	if not sprites.has(fighter_id) or not is_instance_valid(sprites[fighter_id]):
		return
	var glyph: Control = ActionGlyph.new()
	glyph.style = glyph_style
	glyph.tint = tint
	add_child(glyph)
	glyph.position = _center_of(fighter_id) + Vector2(0, -8)
	if powerful:
		glyph.scale = Vector2(1.4, 1.4)
	var tween: Tween = create_tween()
	tween.tween_property(glyph, "modulate:a", 0.0, 0.11)
	await tween.finished
	if is_instance_valid(glyph):
		glyph.queue_free()


func _center_of(fighter_id: String) -> Vector2:
	var sprite: TextureRect = sprites[fighter_id]
	return sprite.global_position - global_position + sprite.size * 0.5


func _action_color(style: String) -> Color:
	match style:
		"arrow": return Color("e5c88b")
		"fire": return Color("ff8d52")
		"curse": return Color("bd78db")
		_: return Color("79bcf4")


func _react(fighter_id: String) -> void:
	var sprite: TextureRect = sprites[fighter_id]
	if not is_instance_valid(sprite):
		return
	if reactions.has(fighter_id) and is_instance_valid(reactions[fighter_id]):
		reactions[fighter_id].kill()
	var origin: Vector2 = origins[fighter_id]
	sprite.position = origin
	sprite.self_modulate = Color.WHITE
	var direction: float = -1.0 if teams[fighter_id] == "hero" else 1.0
	var tween: Tween = create_tween()
	reactions[fighter_id] = tween
	tween.tween_property(sprite, "position", origin + Vector2(direction * 6.0, 0.0), DAMAGE_SECONDS * 0.38)
	tween.parallel().tween_property(sprite, "self_modulate", Color(1.0, 0.28, 0.28), DAMAGE_SECONDS * 0.38)
	tween.tween_property(sprite, "position", origin, DAMAGE_SECONDS * 0.62)
	tween.parallel().tween_property(sprite, "self_modulate", Color.WHITE, DAMAGE_SECONDS * 0.62)
	tween.finished.connect(func() -> void:
		if is_instance_valid(sprite):
			sprite.position = origin
			sprite.self_modulate = Color.WHITE
		if reactions.get(fighter_id) == tween:
			reactions.erase(fighter_id)
	)


func _spawn_number(fighter_id: String, event: Dictionary, sequence: int) -> void:
	var sprite: TextureRect = sprites[fighter_id]
	if not is_instance_valid(sprite):
		return
	displayed_event_count += 1
	var kind: String = str(event.get("kind", "damage"))
	var critical: bool = bool(event.get("critical", false)) and kind == "damage"
	var visual_type: String = "heal" if kind == "heal" else str(event.get("visual_type", "physical"))
	var popup := VBoxContainer.new()
	popup.name = "FloatingNumber"
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.custom_minimum_size = Vector2(86, 0)
	popup.add_theme_constant_override("separation", 0)
	add_child(popup)
	if critical:
		var header := _outlined_label("CRÍTICO!", 10, Color("f5d874"))
		popup.add_child(header)
	var amount: int = int(event["amount"])
	var value := _outlined_label("+%d" % amount if kind == "heal" else str(amount), 21 if critical else 17, COLORS.get(visual_type, COLORS["physical"]))
	popup.add_child(value)
	var sprite_position: Vector2 = sprite.global_position - global_position
	popup.position = sprite_position + Vector2(24.0 - 43.0 + float(sequence % 3) * 15.0, -16.0 - float(sequence % 3) * 7.0)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position", popup.position + Vector2(0, -16), POPUP_SECONDS)
	tween.tween_property(popup, "modulate:a", 0.0, POPUP_SECONDS)
	tween.set_parallel(false)
	tween.tween_callback(popup.queue_free)


func _outlined_label(value: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = value
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", Color("101820"))
	node.add_theme_constant_override("outline_size", 3)
	return node
