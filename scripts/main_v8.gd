extends Control

const Heroes = preload("res://data/heroes.gd")
const CombatSprites = preload("res://data/combat_sprites.gd")
const CombatIcons = preload("res://data/combat_icons.gd")
const BATTLEFIELD = preload("res://assets/backgrounds/campo_aberto.png")
const TOWER_GATE = preload("res://assets/backgrounds/entrada_torre.png")
const TOWER_GATE_OPEN = preload("res://assets/backgrounds/entrada_torre_aberta.png")
const TowerCutsceneDirector = preload("res://scripts/tower_cutscene_director.gd")
const MENU_COVER = preload("res://assets/menu/torre_capa_v19.png")
const MENU_TITLE_FONT = preload("res://assets/fonts/cinzel_title.res")
const Skills = preload("res://data/skills.gd")
const Cards = preload("res://data/cards.gd")
const Relics = preload("res://data/relics.gd")
const RewardVisuals = preload("res://data/reward_visuals.gd")
const StateEffects = preload("res://systems/state_effects.gd")
const Tower = preload("res://data/tower.gd")
const RunState = preload("res://systems/run_state.gd")
const CombatEngine = preload("res://systems/combat_engine.gd")
const CombatFeedback = preload("res://scripts/combat_feedback.gd")
const CombatActionVisuals = preload("res://data/combat_action_visuals.gd")
const CombatAmbience = preload("res://scripts/combat_ambience.gd")
const MenuTransitionFront = preload("res://scripts/menu_transition_front.gd")
const MenuEdgeWipeShader = preload("res://assets/shaders/menu_edge_wipe.gdshader")
const MenuEdgeBlurShader = preload("res://assets/shaders/menu_edge_blur.gdshader")
const Progression = preload("res://systems/permanent_progression.gd")
const CombatRules = preload("res://systems/combat_rules.gd")
const TowerRouteMap = preload("res://scripts/tower_route_map.gd")
const AudioToggle = preload("res://scripts/audio_toggle.gd")
const NarrativeController = preload("res://systems/narrative_controller.gd")
const StoryFlow = preload("res://systems/story_flow.gd")
const ResurrectionFlow = preload("res://systems/resurrection_flow.gd")
const ResurrectionBackdrop = preload("res://scripts/resurrection_backdrop.gd")
const DevGuard = preload("res://systems/dev_guard.gd")
const DevController = preload("res://scripts/dev_controller.gd")
const DevPanel = preload("res://scripts/dev_panel.gd")
const DevOps = preload("res://systems/dev_operations.gd")

const BG := Color("101820")
const PANEL := Color("1b2a34")
const LIGHT := Color("223641")
const GOLD := Color("f2c66d")
const WHITE := Color("f3f0e8")
const MUTED := Color("a9b7bd")
const GREEN := Color("70c58b")
const RED := Color("e47772")

var run = RunState.new()
var combat = CombatEngine.new()
var music_manager: Node
var audio_manager: Node
var audio_overlay: Control
var audio_panel: PanelContainer
var audio_button: Button
var audio_controls: Dictionary = {}
var narrative: Node
var resurrection_background: ColorRect
var resurrection_transitioning := false
var outcome_destination_after_resurrection := ""
var dev_controller: Node
var dev_panel: Control
var dev_badge: Label
var dev_previous_pause := false
var dev_preview_scene := false
var dev_preview_was_combat := false
var tower_director: Control
var combat_resolution_handled := false
var combat_action_panel: Control
var narrative_log_was_visible := false
var replaying_intro := false
var last_page_built_ms: int = 0
var host: Control
var screen: Control
var selected: Array[String] = []
var selection_buttons: Dictionary = {}
var selection_label: Label
var selection_team_row: HBoxContainer
var selection_presentations: Dictionary = {}
var start_button: Button
var progression_scroll: ScrollContainer
var progression_hero_id: String = "guerreiro"
var progression_detail: VBoxContainer
var progression_class_buttons: Dictionary = {}
var generation: int = 0
var enemy_running: bool = false
var resolving_visual_action: bool = false
var visual_actor_id: String = ""
var pending_action: String = ""
var combat_cards: Dictionary = {}
var arena_cards: Dictionary = {}
var chips: Dictionary = {}
var initiative_row: HBoxContainer
var arena_stage: Control
var combat_feedback: Control
var arena_background: TextureRect
var menu_background: TextureRect
var menu_buttons: Dictionary = {}
var menu_transitioning: bool = false
var enemy_hover_panel: PanelContainer
var enemy_hover_sprite: TextureRect
var enemy_hover_name: Label
var enemy_hover_hp: Label
var enemy_hover_resistances: Label
var enemy_hover_intention: Label
var enemy_hover_target: Label
var enemy_hover_states: Label
var inspected_fighter_id: String = ""
var hovered_target_id: String = ""
var turn_label: Label
var combat_progress_text: Label
var combat_xp_bar: ProgressBar
var hint_label: Label
var buttons: Dictionary = {}
var skill_button_ids: Dictionary = {}
var skill_button_owners: Dictionary = {}
var target_row: HFlowContainer
var log_box: RichTextLabel
var log_panel: PanelContainer
var log_toggle: Button
var skills_panel: PanelContainer
var skills_open: bool = false
var bonus_overlay: Control
var bonus_details: VBoxContainer
var bonus_hero_buttons: Dictionary = {}
var bonus_panel_open: bool = false
var route_map: Control
var route_info_content: VBoxContainer
var route_pinned_id: String = ""
var route_hover_id: String = ""


func _ready() -> void:
	music_manager = get_node("/root/MusicManager")
	audio_manager = get_node("/root/AudioManager")
	get_tree().node_added.connect(_wire_button_audio)
	var background := ColorRect.new()
	background.color = BG
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	for key in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % key, 28)
	for key in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % key, 20)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host = Control.new()
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(host)
	_build_audio_controls()
	narrative = NarrativeController.new()
	narrative.name = "NarrativeController"
	add_child(narrative)
	narrative.started.connect(_on_narrative_started)
	narrative.ended.connect(_on_narrative_ended)
	narrative.event_requested.connect(_on_narrative_event)
	narrative.line_shown.connect(_on_narrative_line_shown)
	narrative.exit_requested.connect(menu)
	run.initialize(run.save_path)
	if DevGuard.authorized():
		dev_controller = DevController.new()
		dev_controller.name = "DeveloperController"
		add_child(dev_controller)
		dev_controller.setup(self, run.save_path)
		dev_controller.close_requested.connect(close_dev_panel)
		dev_badge = Label.new()
		dev_badge.text = "PERFIL DEV · TESTES ISOLADOS"
		dev_badge.add_theme_font_size_override("font_size", 13)
		dev_badge.add_theme_color_override("font_color", GOLD)
		dev_badge.position = Vector2(30, 2)
		dev_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dev_badge)
		_refresh_dev_badge()
	menu()


func _refresh_dev_badge() -> void:
	if dev_badge != null and is_instance_valid(dev_badge):
		dev_badge.visible = dev_controller != null and dev_controller.active()


func open_dev_panel() -> void:
	if not DevGuard.authorized() or dev_controller == null or (dev_panel != null and is_instance_valid(dev_panel)):
		return
	dev_previous_pause = get_tree().paused
	dev_panel = DevPanel.new()
	dev_panel.name = "DeveloperPanel"
	dev_panel.controller = dev_controller
	dev_panel.close_requested.connect(close_dev_panel)
	add_child(dev_panel)
	move_child(dev_panel, get_child_count() - 1)
	get_tree().paused = true


func close_dev_panel() -> void:
	if dev_panel == null or not is_instance_valid(dev_panel):
		return
	get_tree().paused = dev_previous_pause
	dev_panel.queue_free()
	dev_panel = null


func _show_dev_resurrection_stage() -> void:
	music_manager.play_default()
	var root := page()
	resurrection_background = ColorRect.new()
	resurrection_background.color = Color("05060d")
	resurrection_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(resurrection_background)
	resurrection_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(resurrection_background, 1)
	resurrection_background.add_child(ResurrectionBackdrop.new())
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(stage)


func _restore_dev_preview(expected_generation: int) -> void:
	if generation != expected_generation or not DevGuard.authorized() or dev_controller == null or not dev_controller.active():
		return
	if dev_preview_was_combat and run.has_attempt() and run.attempt.get("phase", "") == "combat":
		music_manager.play_for_combat(run.attempt)
		build_combat_screen()
		audio_manager.start_wind()
		refresh_combat()
		if not combat.finished and not combat.is_hero_turn():
			enemy_loop()
	else:
		show_phase() if run.has_attempt() else menu()
	open_dev_panel()


func page() -> VBoxContainer:
	if narrative != null and narrative.active:
		narrative.finish(false)
	generation += 1
	last_page_built_ms = Time.get_ticks_msec()
	audio_manager.stop_wind()
	combat_cards.clear()
	arena_cards.clear()
	combat_feedback = null
	if resurrection_background != null and is_instance_valid(resurrection_background):
		resurrection_background.queue_free()
		remove_child(resurrection_background)
	resurrection_background = null
	if menu_background != null and is_instance_valid(menu_background):
		menu_background.queue_free()
		remove_child(menu_background)
	menu_background = null
	if arena_background != null and is_instance_valid(arena_background):
		arena_background.queue_free()
		host.remove_child(arena_background)
	arena_background = null
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
		host.remove_child(screen)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 9)
	host.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen = root
	return root


func _build_audio_controls() -> void:
	audio_overlay = Control.new()
	audio_overlay.name = "AudioOverlay"
	audio_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(audio_overlay)
	audio_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	audio_button = AudioToggle.new()
	audio_button.name = "AudioToggle"
	audio_button.tooltip_text = "Volumes de áudio"
	audio_button.focus_mode = Control.FOCUS_NONE
	audio_button.anchor_left = 1.0
	audio_button.anchor_right = 1.0
	audio_button.offset_left = -56.0
	audio_button.offset_right = -12.0
	audio_button.offset_top = 8.0
	audio_button.offset_bottom = 46.0
	audio_button.add_theme_stylebox_override("normal", menu_panel_style(0.94))
	audio_button.add_theme_stylebox_override("hover", menu_panel_style(1.0))
	audio_overlay.add_child(audio_button)
	audio_button.pressed.connect(func() -> void:
		audio_panel.visible = not audio_panel.visible
		if audio_panel.visible:
			_refresh_audio_controls()
	)
	audio_panel = PanelContainer.new()
	audio_panel.name = "AudioPanel"
	audio_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	audio_panel.anchor_left = 1.0
	audio_panel.anchor_right = 1.0
	audio_panel.offset_left = -354.0
	audio_panel.offset_right = -12.0
	audio_panel.offset_top = 52.0
	audio_panel.offset_bottom = 260.0
	audio_panel.add_theme_stylebox_override("panel", menu_panel_style(0.97))
	audio_overlay.add_child(audio_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	audio_panel.add_child(column)
	column.add_child(label("ÁUDIO", 13, GOLD))
	for entry in [{"bus": "Music", "title": "Música"}, {"bus": "SFX", "title": "Efeitos"}, {"bus": "Ambience", "title": "Ambiente"}]:
		var bus_name: String = entry["bus"]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		column.add_child(row)
		var heading_row := HBoxContainer.new()
		row.add_child(heading_row)
		var caption := label(entry["title"], 12, WHITE)
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.custom_minimum_size.x = 110.0
		heading_row.add_child(caption)
		var stretch := Control.new()
		stretch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading_row.add_child(stretch)
		var amount := label("", 11, MUTED)
		amount.autowrap_mode = TextServer.AUTOWRAP_OFF
		amount.custom_minimum_size.x = 45.0
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		heading_row.add_child(amount)
		var control_row := HBoxContainer.new()
		row.add_child(control_row)
		var slider := HSlider.new()
		slider.name = "%sVolume" % bus_name
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value = audio_manager.volume_percent(bus_name)
		control_row.add_child(slider)
		var mute := Button.new()
		mute.name = "%sMute" % bus_name
		mute.custom_minimum_size.x = 70
		mute.add_theme_font_size_override("font_size", 11)
		control_row.add_child(mute)
		audio_controls[bus_name] = {"slider": slider, "amount": amount, "mute": mute}
		slider.value_changed.connect(_on_audio_slider.bind(bus_name))
		mute.pressed.connect(_on_audio_mute.bind(bus_name))
	audio_panel.visible = false
	_refresh_audio_controls()


func _refresh_audio_controls() -> void:
	for bus_name in audio_controls:
		var controls: Dictionary = audio_controls[bus_name]
		var percent: float = audio_manager.volume_percent(bus_name)
		(controls["slider"] as HSlider).set_value_no_signal(percent)
		(controls["amount"] as Label).text = "%d%%" % int(percent)
		(controls["mute"] as Button).text = "Ouvir" if percent == 0.0 else "Silenciar"
	(audio_button as AudioToggle).muted = audio_manager.all_muted()


func _on_audio_slider(value: float, bus_name: String) -> void:
	audio_manager.set_volume_percent(bus_name, value)
	_refresh_audio_controls()


func _on_audio_mute(bus_name: String) -> void:
	audio_manager.toggle_mute(bus_name)
	_refresh_audio_controls()


func _wire_button_audio(node: Node) -> void:
	var candidate := node as BaseButton
	if candidate == null or not is_ancestor_of(candidate):
		return
	candidate.set_meta("audio_ready_ms", Time.get_ticks_msec() + 180)
	candidate.mouse_entered.connect(_on_button_hover.bind(candidate))
	candidate.pressed.connect(_on_button_pressed)


func _on_button_hover(candidate: BaseButton) -> void:
	if candidate.disabled or not candidate.is_visible_in_tree() or Time.get_ticks_msec() < int(candidate.get_meta("audio_ready_ms", 0)) or Time.get_ticks_msec() - last_page_built_ms < 180:
		return
	audio_manager.play("hover", -12.0)


func _on_button_pressed() -> void:
	audio_manager.play("click", -7.0)


func _input(event: InputEvent) -> void:
	if DevGuard.authorized() and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		if dev_panel == null or not is_instance_valid(dev_panel):
			open_dev_panel()
		else:
			close_dev_panel()
		get_viewport().set_input_as_handled()
		return
	if audio_panel == null or not audio_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		audio_panel.visible = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not audio_panel.get_global_rect().has_point(event.position) and not audio_button.get_global_rect().has_point(event.position):
			audio_panel.visible = false
			get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_wire_button_audio):
		get_tree().node_added.disconnect(_wire_button_audio)


func _on_narrative_started(scene_id: String) -> void:
	if combat_action_panel != null and is_instance_valid(combat_action_panel):
		combat_action_panel.visible = false
	if target_row != null and is_instance_valid(target_row):
		target_row.visible = false
	if skills_panel != null and is_instance_valid(skills_panel):
		skills_panel.visible = false
	if bonus_overlay != null and is_instance_valid(bonus_overlay):
		close_bonus_panel()
	narrative_log_was_visible = log_panel != null and is_instance_valid(log_panel) and log_panel.visible
	if log_panel != null and is_instance_valid(log_panel):
		log_panel.visible = false
	if log_toggle != null and is_instance_valid(log_toggle):
		log_toggle.visible = false
	audio_panel.visible = false
	audio_manager.set_music_ducked(true, 24.0 if scene_id.begins_with("ressurreicao_") else 5.0)


func _on_narrative_ended(scene_id: String, completed: bool) -> void:
	if combat_action_panel != null and is_instance_valid(combat_action_panel):
		combat_action_panel.visible = true
	if target_row != null and is_instance_valid(target_row):
		target_row.visible = not pending_action.is_empty()
	if skills_panel != null and is_instance_valid(skills_panel):
		skills_panel.visible = skills_open
	if log_panel != null and is_instance_valid(log_panel):
		log_panel.visible = narrative_log_was_visible
	if log_toggle != null and is_instance_valid(log_toggle):
		log_toggle.visible = true
	audio_manager.set_music_ducked(false)
	if dev_preview_scene:
		dev_preview_scene = false
		call_deferred("_restore_dev_preview", generation)
		return
	if scene_id.begins_with("ressurreicao_"):
		if completed:
			if run.complete_resurrection():
				call_deferred("_continue_after_resurrection", generation)
			else:
				push_error("Não foi possível salvar a conclusão do diálogo de retorno.")
		return
	if replaying_intro:
		replaying_intro = false
		if completed:
			call_deferred("menu")
		return
	if completed and StoryFlow.is_main_scene(scene_id) and run.has_attempt():
		var cursors: Dictionary = run.attempt.get("narrative_cursor", {})
		cursors.erase(scene_id)
		run.attempt["narrative_cursor"] = cursors
		run.mark_narrative_scene(scene_id)
		call_deferred("_continue_story_after_scene", generation)


func _on_narrative_line_shown(scene_id: String, line_id: String) -> void:
	if dev_preview_scene:
		return
	if scene_id.begins_with("ressurreicao_"):
		run.set_resurrection_cursor(line_id)
		return
	if not run.has_attempt() or not scene_id in ["entrada_torre", "epilogo_gueist"]:
		return
	var cursors: Dictionary = run.attempt.get("narrative_cursor", {})
	cursors[scene_id] = line_id
	run.attempt["narrative_cursor"] = cursors
	run.save()


func _on_narrative_event(event_id: String, _entry: Dictionary) -> void:
	if event_id == "resurrection:whisper":
		audio_manager.play("revive", -15.0)
	elif event_id.begins_with("sfx:"):
		audio_manager.play(event_id.trim_prefix("sfx:"))
	elif event_id.begins_with("tower:") and tower_director != null and is_instance_valid(tower_director):
		var steps: Dictionary = run.attempt.get("narrative_event_steps", {})
		if not dev_preview_scene and bool(steps.get("%s:%s" % [narrative.scene_id, event_id.trim_prefix("tower:")], false)):
			return
		if event_id == "tower:boss_reveal":
			music_manager.request_track("A")
			audio_manager.set_music_ducked(false)
		narrative.set_interaction_locked(true)
		tower_director.play_beat(event_id.trim_prefix("tower:"))


func _on_tower_beat_finished(beat_id: String) -> void:
	if dev_preview_scene:
		narrative.set_interaction_locked(false)
		return
	if not narrative.active or not run.has_attempt():
		return
	var steps: Dictionary = run.attempt.get("narrative_event_steps", {})
	steps["%s:%s" % [narrative.scene_id, beat_id]] = true
	run.attempt["narrative_event_steps"] = steps
	run.save()
	narrative.set_interaction_locked(false)


func label(value: String, size: int = 14, color: Color = WHITE) -> Label:
	var node := Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


func style(color: Color = PANEL) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(9)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


func combat_panel_style(alpha: float = 0.83) -> StyleBoxFlat:
	var color := PANEL
	color.a = alpha
	var box := style(color)
	box.border_color = Color(0.65, 0.78, 0.77, 0.34)
	box.set_border_width_all(1)
	return box


func combat_button_style(node: Button, accent: Color = GOLD) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var fill := Color(0.11, 0.18, 0.22, 0.94)
		if state == "hover" or state == "pressed":
			fill = Color(0.18, 0.29, 0.33, 0.98)
		elif state == "disabled":
			fill = Color(0.08, 0.13, 0.16, 0.78)
		var box := style(fill)
		box.border_color = accent if state != "disabled" else Color(0.28, 0.34, 0.36, 0.8)
		box.border_color.a = 0.9 if state == "hover" or state == "pressed" else 0.58
		box.border_width_bottom = 2
		box.border_width_left = 1
		box.border_width_right = 1
		box.border_width_top = 1
		node.add_theme_stylebox_override(state, box)
	node.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_color_override("icon_normal_color", Color.WHITE)
	node.add_theme_color_override("icon_disabled_color", Color(0.54, 0.58, 0.6))


func menu_panel_style(alpha: float) -> StyleBoxFlat:
	var box := style(Color(0.035, 0.048, 0.09, alpha))
	box.set_corner_radius_all(3)
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 15
	box.content_margin_bottom = 15
	box.border_color = Color(0.72, 0.545, 0.325, 0.8)
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 1
	box.border_width_bottom = 2
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	box.shadow_size = 9
	box.shadow_offset = Vector2(0, 5)
	return box


func menu_button_style(node: Button, prominent: bool) -> void:
	var accent: Color = Color("e5b96a") if prominent else Color("839aaa")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill := Color(0.067, 0.098, 0.169, 0.96)
		if state == "hover" or state == "focus":
			fill = Color(0.188, 0.157, 0.227, 0.98)
		elif state == "pressed":
			fill = Color(0.267, 0.188, 0.263, 0.99)
		elif state == "disabled":
			fill = Color(0.063, 0.086, 0.141, 0.82)
		var box := style(fill)
		box.set_corner_radius_all(2)
		box.content_margin_left = 18
		box.border_color = accent if state != "disabled" else Color(0.302, 0.337, 0.38, 0.7)
		box.border_width_left = 3
		box.border_width_top = 1
		box.border_width_right = 1
		box.border_width_bottom = 3
		box.shadow_color = Color(0, 0, 0, 0.48)
		box.shadow_size = 4
		box.shadow_offset = Vector2(0, 3)
		node.add_theme_stylebox_override(state, box)
	node.add_theme_font_size_override("font_size", 13)
	node.add_theme_color_override("font_color", GOLD if prominent else WHITE)
	node.add_theme_color_override("font_hover_color", Color("ffe4ab"))
	node.add_theme_color_override("font_pressed_color", Color("ffe4ab"))
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT


func menu_title_label(value: String, size: int, color: Color) -> Label:
	var node := label(value, size, color)
	node.add_theme_font_override("font", MENU_TITLE_FONT)
	node.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	node.add_theme_constant_override("shadow_offset_x", 3)
	node.add_theme_constant_override("shadow_offset_y", 4)
	return node


func menu_choice_button(title: String, detail: String, prominent: bool, emblem: String) -> Button:
	var node := Button.new()
	node.text = title
	node.tooltip_text = "%s · %s" % [title, detail]
	node.custom_minimum_size = Vector2(0, 61)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_button_style(node, prominent)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		node.add_theme_color_override(state, Color.TRANSPARENT)
	var inset := MarginContainer.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_theme_constant_override("margin_left", 16)
	inset.add_theme_constant_override("margin_right", 14)
	inset.add_theme_constant_override("margin_top", 6)
	inset.add_theme_constant_override("margin_bottom", 6)
	node.add_child(inset)
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 11)
	inset.add_child(row)
	var sigil := label(emblem, 20, GOLD if prominent else Color("a9bfca"))
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sigil.custom_minimum_size.x = 25
	row.add_child(sigil)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	var heading_text := menu_title_label(title.to_upper(), 15, Color("f8d88f") if prominent else WHITE)
	heading_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(heading_text)
	var detail_text := label(detail, 11, Color("c4c7cb") if not prominent else Color("e6d6b6"))
	detail_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(detail_text)
	var arrow := label("›", 24, Color("d6a85c") if prominent else Color("849aab"))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(arrow)
	return node


func panel() -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", style())
	return node


func bar_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(4)
	return box


func button(title: String, detail: String = "", color: Color = GOLD) -> Button:
	var node := Button.new()
	node.text = title if detail.is_empty() else "%s\n%s" % [title, detail]
	node.custom_minimum_size = Vector2(170, 46)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size", 12)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_disabled_color", MUTED)
	node.add_theme_stylebox_override("normal", style(LIGHT))
	node.add_theme_stylebox_override("hover", style(Color("304854")))
	node.add_theme_stylebox_override("disabled", style(Color("18262e")))
	return node


func heading(root: VBoxContainer, title: String, subtitle: String = "") -> void:
	root.add_child(label("TORRE DOS HERÓIS", 11, GOLD))
	root.add_child(label(title, 27))
	if not subtitle.is_empty():
		root.add_child(label(subtitle, 13, MUTED))


func footer(root: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	root.add_child(row)
	var restart := button("Reiniciar tentativa", "Mesmo grupo")
	restart.pressed.connect(restart_attempt)
	row.add_child(restart)
	var back := button("Menu", "Tentativa salva", WHITE)
	back.pressed.connect(menu)
	row.add_child(back)


func menu() -> void:
	music_manager.play_default()
	selected.clear()
	selection_buttons.clear()
	selection_presentations.clear()
	selection_team_row = null
	var root := page()
	menu_buttons.clear()
	menu_background = TextureRect.new()
	menu_background.texture = MENU_COVER
	menu_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_background)
	menu_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(menu_background, 1)
	var menu_leaf_layer: Control = CombatAmbience.new()
	menu_leaf_layer.name = "MenuLeaves"
	menu_leaf_layer.menu_leaves = true
	menu_background.add_child(menu_leaf_layer)
	menu_leaf_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(stage)
	var brand := panel()
	brand.name = "MenuTitlePanel"
	brand.add_theme_stylebox_override("panel", menu_panel_style(0.83))
	brand.anchor_left = 0.03
	brand.anchor_right = 0.465
	brand.anchor_top = 0.06
	brand.anchor_bottom = 0.425
	stage.add_child(brand)
	var brand_content := VBoxContainer.new()
	brand_content.add_theme_constant_override("separation", 2)
	brand.add_child(brand_content)
	brand_content.add_child(label("✦  UMA JORNADA ATÉ O TOPO  ✦", 11, Color("e6bd72")))
	var title_top := menu_title_label("TORRE DOS", 37, Color("f7eee0"))
	title_top.name = "MenuGameTitleTop"
	brand_content.add_child(title_top)
	var title_bottom := menu_title_label("HERÓIS", 54, Color("f3d38a"))
	title_bottom.name = "MenuGameTitleBottom"
	brand_content.add_child(title_bottom)
	var divider := HBoxContainer.new()
	divider.add_theme_constant_override("separation", 8)
	brand_content.add_child(divider)
	var left_rule := HSeparator.new()
	left_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.add_child(left_rule)
	divider.add_child(label("◆", 10, GOLD))
	var right_rule := HSeparator.new()
	right_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.add_child(right_rule)
	brand_content.add_child(label("DEZ ANDARES  ·  UMA TENTATIVA POR VEZ", 11, Color("d9d5ce")))
	var menu_panel := panel()
	menu_panel.name = "MenuActionsPanel"
	menu_panel.add_theme_stylebox_override("panel", menu_panel_style(0.9))
	menu_panel.anchor_left = 0.03
	menu_panel.anchor_right = 0.44
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_bottom = 0.975
	stage.add_child(menu_panel)
	var action_scroll := ScrollContainer.new()
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_panel.add_child(action_scroll)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 7)
	action_scroll.add_child(actions)
	actions.add_child(label("✦   ESCOLHA SEU DESTINO", 11, GOLD))
	var new_game_detail: String = "Nova tentativa; substitui a salva" if run.has_attempt() else "Escolher 1 a 3 heróis"
	for entry in [{"name": "Jogar", "detail": new_game_detail, "method": show_selection, "emblem": "✦"}, {"name": "Continuar", "detail": "Retomar tentativa salva", "method": show_phase, "emblem": "◇"}, {"name": "Progressão", "detail": "Níveis permanentes e moedas", "method": show_progression, "emblem": "◆"}]:
		var choice := menu_choice_button(entry["name"], entry["detail"], entry["name"] == "Jogar", entry["emblem"])
		choice.name = "Menu%s" % entry["name"]
		choice.pressed.connect(_transition_from_menu.bind(str(entry["name"]), entry["method"]))
		if entry["name"] == "Continuar":
			choice.disabled = not run.has_attempt() and not run.has_pending_resurrection()
		actions.add_child(choice)
		menu_buttons[entry["name"]] = choice
	if DevGuard.authorized():
		var dev_button := button("◆  FERRAMENTAS DEV", "", GOLD)
		dev_button.name = "MenuDeveloper"
		dev_button.tooltip_text = "Abrir painel de ferramentas de teste"
		dev_button.custom_minimum_size.y = 31
		menu_button_style(dev_button, false)
		dev_button.add_theme_font_size_override("font_size", 11)
		dev_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		dev_button.pressed.connect(open_dev_panel)
		actions.add_child(dev_button)
	var revisit := button("↺  REVER INTRODUÇÃO", "", MUTED)
	revisit.name = "MenuRevisitIntro"
	revisit.tooltip_text = "Rever a história da torre"
	revisit.custom_minimum_size.y = 31
	menu_button_style(revisit, false)
	revisit.add_theme_font_size_override("font_size", 11)
	revisit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	revisit.pressed.connect(replay_intro)
	actions.add_child(revisit)


func _transition_from_menu(choice_name: String, destination: Callable) -> void:
	if menu_transitioning or not destination.is_valid():
		return
	var transition_style: String = "leaves_right" if choice_name == "Jogar" else ("circle" if choice_name == "Continuar" else "slide_left")
	menu_transitioning = true
	var screenshot := get_viewport().get_texture().get_image()
	if screenshot == null or screenshot.is_empty():
		menu_transitioning = false
		destination.call()
		return
	var overlay := Control.new()
	overlay.name = "MenuTransition"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	move_child(overlay, get_child_count() - 1)
	var snapshot := TextureRect.new()
	snapshot.name = "OldScreenSnapshot"
	snapshot.texture = ImageTexture.create_from_image(screenshot)
	snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	snapshot.stretch_mode = TextureRect.STRETCH_SCALE
	snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snapshot.position = Vector2.ZERO
	snapshot.size = size
	overlay.add_child(snapshot)
	destination.call()
	if transition_style == "circle":
		_play_circle_menu_transition(overlay, snapshot)
	else:
		_play_edge_menu_transition(overlay, snapshot, 1.0 if transition_style == "leaves_right" else -1.0)


func _play_edge_menu_transition(overlay: Control, snapshot: TextureRect, direction: float) -> void:
	var viewport_size: Vector2 = size
	var wipe_material := ShaderMaterial.new()
	wipe_material.shader = MenuEdgeWipeShader
	wipe_material.set_shader_parameter("direction", direction)
	wipe_material.set_shader_parameter("pixel_size", Vector2(1.0 / maxf(1.0, viewport_size.x), 1.0 / maxf(1.0, viewport_size.y)))
	snapshot.material = wipe_material
	var blur_band := ColorRect.new()
	blur_band.name = "SoftBlurAtPageEdge"
	blur_band.color = Color.WHITE
	blur_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur_band.size = viewport_size
	var blur_material := ShaderMaterial.new()
	blur_material.shader = MenuEdgeBlurShader
	blur_material.set_shader_parameter("direction", direction)
	blur_material.set_shader_parameter("glow_color", Color("e6bd72") if direction > 0.0 else Color("b5b2d7"))
	blur_band.material = blur_material
	overlay.add_child(blur_band)
	var leaves: Control = MenuTransitionFront.new()
	leaves.name = "LeavesAtPageEdge"
	leaves.size = viewport_size
	overlay.add_child(leaves)
	leaves.configure(direction)
	var travel := create_tween()
	var update_transition := func(value: float) -> void:
		wipe_material.set_shader_parameter("progress", value)
		blur_material.set_shader_parameter("progress", value)
		leaves.set_progress(value)
	travel.tween_method(update_transition, 0.0, 1.0, 1.02).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	travel.tween_callback(func() -> void:
		overlay.queue_free()
		menu_transitioning = false
	)


func _play_circle_menu_transition(overlay: Control, snapshot: TextureRect) -> void:
	var circle_shader := Shader.new()
	circle_shader.code = """
	shader_type canvas_item;
	uniform float reveal_radius = 0.0;
	uniform float aspect_ratio = 1.0;

	void fragment() {
		vec2 offset = UV - vec2(0.5, 0.5);
		offset.x *= aspect_ratio;
		if (length(offset) < reveal_radius) {
			discard;
		}
		COLOR = texture(TEXTURE, UV);
	}
	"""
	var material := ShaderMaterial.new()
	material.shader = circle_shader
	material.set_shader_parameter("reveal_radius", 0.0)
	material.set_shader_parameter("aspect_ratio", size.x / maxf(1.0, size.y))
	snapshot.material = material
	var max_radius: float = sqrt(pow(size.x / maxf(1.0, size.y) * 0.5, 2.0) + 0.25) + 0.04
	var reveal := create_tween()
	reveal.tween_method(func(radius: float) -> void: material.set_shader_parameter("reveal_radius", radius), 0.0, max_radius, 0.76).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	reveal.tween_callback(func() -> void:
		overlay.queue_free()
		menu_transitioning = false
	)


func replay_intro() -> void:
	if narrative.active:
		return
	replaying_intro = true
	_show_story_stage("intro_reino")
	if not narrative.start("intro_reino", self):
		replaying_intro = false
		menu()


func show_progression(scroll_position: int = 0) -> void:
	music_manager.play_default()
	var root := page()
	root.add_theme_constant_override("separation", 8)
	progression_class_buttons.clear()
	var stats: Dictionary = run.permanent["stats"]
	var header_panel := panel()
	header_panel.add_theme_stylebox_override("panel", combat_panel_style(0.93))
	root.add_child(header_panel)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	header_panel.add_child(header)
	var title_block := VBoxContainer.new()
	title_block.add_theme_constant_override("separation", 2)
	title_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_block)
	title_block.add_child(label("Progressão Permanente", 23, GOLD))
	title_block.add_child(label("Evolua suas classes entre as tentativas.", 11, MUTED))
	var summary := HBoxContainer.new()
	summary.add_theme_constant_override("separation", 5)
	header.add_child(summary)
	for item in [
		{"name": "MOEDAS", "value": str(run.permanent["coins"]), "color": GOLD},
		{"name": "TENTATIVAS", "value": str(stats.get("attempts", 0)), "color": WHITE},
		{"name": "VITÓRIAS", "value": str(stats.get("wins", 0)), "color": GREEN},
		{"name": "DERROTAS", "value": str(stats.get("losses", 0)), "color": RED},
		{"name": "ANDARES", "value": str(stats.get("floors_completed", 0)), "color": Color("86cde0")},
	]:
		var pill := panel()
		pill.add_theme_stylebox_override("panel", style(Color(0.08, 0.13, 0.16, 0.92)))
		pill.custom_minimum_size = Vector2(110 if item["name"] == "MOEDAS" else 78, 43)
		summary.add_child(pill)
		var values := VBoxContainer.new()
		values.add_theme_constant_override("separation", 0)
		pill.add_child(values)
		values.add_child(label(item["name"], 8, MUTED))
		values.add_child(label(item["value"], 14, item["color"]))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	root.add_child(body)
	var selector_panel := panel()
	selector_panel.custom_minimum_size.x = 236
	selector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selector_panel.add_theme_stylebox_override("panel", combat_panel_style(0.91))
	body.add_child(selector_panel)
	var selector_content := VBoxContainer.new()
	selector_content.add_theme_constant_override("separation", 5)
	selector_panel.add_child(selector_content)
	selector_content.add_child(label("CLASSES", 10, MUTED))
	for hero_id in Heroes.ORDER:
		var hero_entry: Dictionary = run.permanent["classes"][hero_id]
		var hero_button := Button.new()
		hero_button.name = "ProgressionClass_%s" % hero_id
		hero_button.custom_minimum_size = Vector2(0, 60)
		hero_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero_button.focus_mode = Control.FOCUS_ALL
		hero_button.pressed.connect(select_progression_class.bind(hero_id))
		selector_content.add_child(hero_button)
		var hero_row := HBoxContainer.new()
		hero_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hero_row.add_theme_constant_override("separation", 6)
		hero_button.add_child(hero_row)
		var portrait := TextureRect.new()
		portrait.texture = CombatSprites.texture_for(hero_id)
		portrait.custom_minimum_size = Vector2(38, 38)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hero_row.add_child(portrait)
		var hero_info := VBoxContainer.new()
		hero_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero_info.add_theme_constant_override("separation", 0)
		hero_row.add_child(hero_info)
		var name_label := label(Heroes.DEFINITIONS[hero_id]["name"], 12, WHITE)
		hero_info.add_child(name_label)
		var level_label := label("", 9, MUTED)
		hero_info.add_child(level_label)
		var points_label := label("", 9, GREEN)
		hero_info.add_child(points_label)
		_set_mouse_pass_recursive(hero_row)
		progression_class_buttons[hero_id] = {"button": hero_button, "level": level_label, "points": points_label}
	var main_panel := panel()
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_panel.add_theme_stylebox_override("panel", combat_panel_style(0.91))
	body.add_child(main_panel)
	progression_scroll = ScrollContainer.new()
	progression_scroll.name = "ProgressionDetailScroll"
	progression_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progression_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	progression_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_panel.add_child(progression_scroll)
	progression_detail = VBoxContainer.new()
	progression_detail.name = "ProgressionDetails"
	progression_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progression_detail.add_theme_constant_override("separation", 7)
	progression_scroll.add_child(progression_detail)
	var back := button("Voltar ao menu", "", WHITE)
	back.custom_minimum_size = Vector2(0, 43)
	back.pressed.connect(menu)
	root.add_child(back)
	refresh_progression()
	progression_scroll.set_deferred("scroll_vertical", scroll_position)


func select_progression_class(hero_id: String) -> void:
	if not run.permanent.get("classes", {}).has(hero_id):
		return
	progression_hero_id = hero_id
	refresh_progression()
	progression_scroll.scroll_vertical = 0


func refresh_progression() -> void:
	if progression_detail == null or not is_instance_valid(progression_detail):
		return
	refresh_progression_class_list()
	for child in progression_detail.get_children():
		progression_detail.remove_child(child)
		child.queue_free()
	var hero_id: String = progression_hero_id
	var entry: Dictionary = run.permanent["classes"][hero_id]
	var definition: Dictionary = Heroes.get_definition(hero_id)
	var attributes: Dictionary = entry.get("attributes", Progression.empty_attributes())
	var final_hero: Dictionary = CombatRules.create_hero(hero_id, 1, [], attributes)
	var identity_panel := panel()
	identity_panel.add_theme_stylebox_override("panel", style(Color(0.075, 0.12, 0.15, 0.96)))
	progression_detail.add_child(identity_panel)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 10)
	identity_panel.add_child(identity)
	var portrait := TextureRect.new()
	portrait.texture = CombatSprites.texture_for(hero_id)
	portrait.custom_minimum_size = Vector2(66, 66)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	identity.add_child(portrait)
	var hero_info := VBoxContainer.new()
	hero_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_info.add_theme_constant_override("separation", 2)
	identity.add_child(hero_info)
	hero_info.add_child(label(definition["name"], 21, GOLD))
	hero_info.add_child(label(selection_role(hero_id), 11, MUTED))
	var level_text: String = "NÍVEL MÁXIMO" if int(entry["level"]) >= Progression.MAX_LEVEL else "Nível %d / %d" % [entry["level"], Progression.MAX_LEVEL]
	hero_info.add_child(label(level_text, 13, GOLD))
	hero_info.add_child(label("Pontos disponíveis: %d" % entry["available_points"], 12, GREEN))
	var experience_panel := panel()
	experience_panel.add_theme_stylebox_override("panel", style(Color(0.075, 0.12, 0.15, 0.96)))
	progression_detail.add_child(experience_panel)
	var experience_content := VBoxContainer.new()
	experience_content.add_theme_constant_override("separation", 4)
	experience_panel.add_child(experience_content)
	var required: int = Progression.xp_required(int(entry["level"]))
	var xp_text: String = "NÍVEL MÁXIMO · XP total %d" % int(entry["xp"]) if required == 0 else "XP no nível: %d / %d · faltam %d XP" % [int(entry["level_xp"]), required, maxi(0, required - int(entry["level_xp"]))]
	experience_content.add_child(label("EXPERIÊNCIA", 9, MUTED))
	experience_content.add_child(label(xp_text, 12, GOLD if required == 0 else WHITE))
	var xp_bar := ProgressBar.new()
	xp_bar.min_value = 0
	xp_bar.max_value = required if required > 0 else 1
	xp_bar.value = int(entry["level_xp"]) if required > 0 else 1
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size.y = 11
	xp_bar.add_theme_stylebox_override("background", bar_style(LIGHT))
	xp_bar.add_theme_stylebox_override("fill", bar_style(GOLD))
	experience_content.add_child(xp_bar)
	var preview_panel := panel()
	preview_panel.add_theme_stylebox_override("panel", style(Color(0.075, 0.12, 0.15, 0.96)))
	progression_detail.add_child(preview_panel)
	var preview_content := VBoxContainer.new()
	preview_content.add_theme_constant_override("separation", 3)
	preview_panel.add_child(preview_content)
	preview_content.add_child(label("PRÉVIA · PRÓXIMA TENTATIVA", 9, MUTED))
	var preview_grid := GridContainer.new()
	preview_grid.columns = 6
	preview_grid.add_theme_constant_override("h_separation", 5)
	preview_grid.add_theme_constant_override("v_separation", 4)
	preview_content.add_child(preview_grid)
	var preview_values: Array[Dictionary] = [
		{"name": "PV máximos", "value": "%d" % final_hero["max_hp"], "color": GREEN},
		{"name": "Mana máxima", "value": "%d" % final_hero["mana_max"] if int(final_hero["mana_max"]) > 0 else "—", "color": Color("73c9eb")},
		{"name": "Ataque básico", "value": "%d" % final_hero["damage"], "color": WHITE},
		{"name": "Iniciativa", "value": "%d" % final_hero["initiative"], "color": GOLD},
		{"name": "Resist. física", "value": "%d%%" % roundi(float(final_hero["physical_resist"]) * 100.0), "color": Color("a5c8dd")},
		{"name": "Resist. mágica", "value": "%d%%" % roundi(float(final_hero["magical_resist"]) * 100.0), "color": Color("bc83d9")},
	]
	for value in preview_values:
		var stat := panel()
		stat.add_theme_stylebox_override("panel", style(Color(0.045, 0.08, 0.1, 0.88)))
		stat.custom_minimum_size = Vector2(102, 40)
		preview_grid.add_child(stat)
		var stat_content := VBoxContainer.new()
		stat_content.add_theme_constant_override("separation", 0)
		stat.add_child(stat_content)
		stat_content.add_child(label(value["name"], 8, MUTED))
		stat_content.add_child(label(value["value"], 13, value["color"]))
	progression_detail.add_child(label("ATRIBUTOS PERMANENTES", 10, MUTED))
	var icon_ids := {"vitalidade": "rescue", "poder": "attack", "agilidade": "flecha_debilitante", "resistencia": "defend", "mana": "raio_arcano"}
	for attribute_id in Progression.ORDER:
		var attribute: Dictionary = Progression.DEFINITIONS[attribute_id]
		var points: int = int(attributes.get(attribute_id, 0))
		var usable: bool = attribute_id != "mana" or Progression.uses_mana(hero_id)
		var at_limit: bool = points >= Progression.ATTRIBUTE_LIMIT
		var row_panel := panel()
		var row_style := style(Color(0.075, 0.12, 0.15, 0.96))
		if at_limit:
			row_style.border_color = GOLD
			row_style.set_border_width_all(1)
		row_panel.add_theme_stylebox_override("panel", row_style)
		row_panel.custom_minimum_size.y = 50
		progression_detail.add_child(row_panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row_panel.add_child(row)
		var icon := TextureRect.new()
		icon.texture = CombatIcons.texture_for(icon_ids[attribute_id])
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate = MUTED if not usable else WHITE
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		row.add_child(info)
		var invested_text: String = "%s  ·  %d / %d%s" % [attribute["name"], points, Progression.ATTRIBUTE_LIMIT, "  ·  MÁXIMO" if at_limit else ""]
		info.add_child(label(invested_text, 11, GOLD if at_limit else (WHITE if usable else MUTED)))
		var effect_text: String = "%s por ponto  ·  atual: %s" % [attribute["per_point"], Progression.total_effect(attribute_id, points)] if usable else "Indisponível para esta classe (sem mana)"
		info.add_child(label(effect_text, 9, MUTED))
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 2)
		info.add_child(pips)
		for pip_index in Progression.ATTRIBUTE_LIMIT:
			var pip := ColorRect.new()
			pip.color = GOLD if usable and pip_index < points else Color("35464d")
			pip.custom_minimum_size = Vector2(17, 3)
			pips.add_child(pip)
		var invest := button("+", "", GOLD)
		invest.name = "Invest_%s" % attribute_id
		invest.custom_minimum_size = Vector2(39, 36)
		invest.size_flags_horizontal = Control.SIZE_SHRINK_END
		invest.disabled = not Progression.can_invest(entry, hero_id, attribute_id)
		invest.tooltip_text = "Investir 1 ponto em %s" % attribute["name"]
		invest.pressed.connect(invest_attribute.bind(hero_id, attribute_id))
		row.add_child(invest)
	progression_detail.add_child(label("HABILIDADES ESPECIAIS", 10, MUTED))
	for special_id in Skills.SPECIALS.get(hero_id, []):
		var special: Dictionary = Skills.get_definition(special_id)
		var acquired: bool = special_id in entry.get("unlocked_specials", [])
		var can_buy: bool = Progression.can_unlock(entry, hero_id, special_id)
		var special_panel := panel()
		special_panel.add_theme_stylebox_override("panel", style(Color(0.075, 0.12, 0.15, 0.96)))
		progression_detail.add_child(special_panel)
		var special_row := HBoxContainer.new()
		special_row.add_theme_constant_override("separation", 9)
		special_panel.add_child(special_row)
		var special_icon := TextureRect.new()
		special_icon.texture = CombatIcons.texture_for(special_id)
		special_icon.custom_minimum_size = Vector2(36, 36)
		special_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		special_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		special_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		special_row.add_child(special_icon)
		var special_info := VBoxContainer.new()
		special_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		special_row.add_child(special_info)
		var tier_text: String = "I" if int(special["tier"]) == 1 else "II"
		var status: String = "ADQUIRIDA" if acquired else ("DISPONÍVEL" if can_buy else "BLOQUEADA")
		special_info.add_child(label("ESPECIAL %s · %s · %s" % [tier_text, special["name"], status], 11, GOLD if acquired else (GREEN if can_buy else MUTED)))
		special_info.add_child(label(skill_description(special), 9, WHITE))
		var requirement: String = "Nível %d · %d pontos" % [special["level"], special["point_cost"]]
		if not acquired and not can_buy:
			requirement += " · %s" % ("nível insuficiente" if int(entry["level"]) < int(special["level"]) else "pontos insuficientes")
		special_info.add_child(label(requirement, 9, MUTED))
		var unlock_button := button("Desbloquear", "", GOLD)
		unlock_button.name = "Unlock_%s" % special_id
		unlock_button.custom_minimum_size = Vector2(96, 36)
		unlock_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		unlock_button.add_theme_font_size_override("font_size", 10)
		unlock_button.disabled = not can_buy
		unlock_button.pressed.connect(confirm_special_unlock.bind(hero_id, special_id))
		special_row.add_child(unlock_button)
	if not entry["history"].is_empty():
		var last: Dictionary = entry["history"].back()
		progression_detail.add_child(label("Última tentativa · %d andares · +%d XP" % [last.get("floors", 0), last.get("xp", 0)], 9, MUTED))


func refresh_progression_class_list() -> void:
	for hero_id in progression_class_buttons:
		var entry: Dictionary = run.permanent["classes"][hero_id]
		var controls: Dictionary = progression_class_buttons[hero_id]
		controls["level"].text = "Nível %d / %d" % [entry["level"], Progression.MAX_LEVEL]
		controls["points"].text = "%d ponto(s)" % int(entry["available_points"]) if int(entry["available_points"]) > 0 else "Sem pontos disponíveis"
		var selected_class: bool = hero_id == progression_hero_id
		var normal := style(Color(0.14, 0.13, 0.095, 0.96) if selected_class else Color(0.075, 0.12, 0.15, 0.96))
		normal.set_corner_radius_all(7)
		normal.border_color = GOLD if selected_class else Color(0.52, 0.67, 0.68, 0.45)
		normal.set_border_width_all(2 if selected_class else 1)
		controls["button"].add_theme_stylebox_override("normal", normal)
		controls["button"].add_theme_stylebox_override("hover", normal)
		controls["button"].add_theme_stylebox_override("pressed", normal)


func invest_attribute(hero_id: String, attribute_id: String) -> void:
	if run.spend_attribute(hero_id, attribute_id):
		audio_manager.play("attribute")
		progression_hero_id = hero_id
		refresh_progression()


func confirm_special_unlock(hero_id: String, skill_id: String) -> void:
	var entry: Dictionary = run.permanent["classes"][hero_id]
	if not Progression.can_unlock(entry, hero_id, skill_id):
		return
	var skill: Dictionary = Skills.get_definition(skill_id)
	var dialog := ConfirmationDialog.new()
	dialog.title = "Compra permanente"
	dialog.dialog_text = "Desbloquear %s por %d pontos de %s?\nEsta compra é permanente e não pode ser desfeita." % [skill["name"], skill["point_cost"], Heroes.DEFINITIONS[hero_id]["name"]]
	host.add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		if run.spend_special_skill(hero_id, skill_id):
			audio_manager.play("unlock")
			progression_hero_id = hero_id
			refresh_progression()
	)
	dialog.popup_centered()
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free()
	)


func show_selection() -> void:
	if run.has_pending_resurrection():
		_show_resurrection_scene()
		return
	music_manager.play_default()
	selected.clear()
	selection_buttons.clear()
	selection_presentations.clear()
	var root := page()
	root.add_theme_constant_override("separation", 8)
	heading(root, "Monte sua equipe", "Escolha de 1 a 3 heróis para iniciar a jornada pela torre.")
	var team_panel := panel()
	team_panel.add_theme_stylebox_override("panel", combat_panel_style(0.94))
	team_panel.custom_minimum_size.y = 58
	root.add_child(team_panel)
	var team_content := HBoxContainer.new()
	team_content.add_theme_constant_override("separation", 12)
	team_panel.add_child(team_content)
	selection_label = label("", 14, GOLD)
	selection_label.custom_minimum_size.x = 145
	selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	team_content.add_child(selection_label)
	var team_divider := VSeparator.new()
	team_content.add_child(team_divider)
	selection_team_row = HBoxContainer.new()
	selection_team_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_team_row.custom_minimum_size.y = 42
	selection_team_row.add_theme_constant_override("separation", 6)
	team_content.add_child(selection_team_row)
	var scroll := ScrollContainer.new()
	scroll.name = "HeroSelectionScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var grid := HFlowContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for hero_id in Heroes.ORDER:
		var hero: Dictionary = Heroes.get_definition(hero_id)
		var permanent: Dictionary = run.permanent.get("classes", {}).get(hero_id, {})
		var permanent_attributes: Dictionary = permanent.get("attributes", Progression.empty_attributes())
		var stats: Dictionary = CombatRules.create_hero(hero_id, 1, [], permanent_attributes)
		var skill_ids: Array[String] = [str(hero["skill"])]
		var skill_widgets: Array[Dictionary] = []
		for alternate in hero.get("alternate_skills", []):
			skill_ids.append(str(alternate))
		for special_id in Skills.SPECIALS.get(hero_id, []):
			skill_ids.append(str(special_id))
		var choice := Button.new()
		choice.name = "HeroCard_%s" % hero_id
		choice.custom_minimum_size = Vector2(310, 242)
		choice.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		choice.clip_contents = true
		choice.focus_mode = Control.FOCUS_ALL
		choice.add_theme_color_override("font_color", WHITE)
		var card_margin := MarginContainer.new()
		card_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for margin_side in ["left", "right"]:
			card_margin.add_theme_constant_override("margin_%s" % margin_side, 8)
		for margin_side in ["top", "bottom"]:
			card_margin.add_theme_constant_override("margin_%s" % margin_side, 6)
		choice.add_child(card_margin)
		var card_content := VBoxContainer.new()
		card_content.add_theme_constant_override("separation", 3)
		card_margin.add_child(card_content)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 7)
		card_content.add_child(top)
		var portrait := TextureRect.new()
		portrait.texture = CombatSprites.texture_for(hero_id)
		portrait.custom_minimum_size = Vector2(72, 72)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		top.add_child(portrait)
		var identity := VBoxContainer.new()
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.add_theme_constant_override("separation", 2)
		top.add_child(identity)
		var hero_title: Label = label(hero["name"], 17, GOLD)
		identity.add_child(hero_title)
		var level: int = int(permanent.get("level", 1))
		identity.add_child(label("Nível permanente %d / %d" % [level, Progression.MAX_LEVEL], 10, MUTED))
		var role_text: String = selection_role(hero_id)
		identity.add_child(label(role_text, 11, WHITE))
		var selected_status := label("SELECIONADO", 10, GOLD)
		selected_status.visible = false
		identity.add_child(selected_status)
		card_content.add_child(HSeparator.new())
		var stat_grid := GridContainer.new()
		stat_grid.columns = 3
		stat_grid.add_theme_constant_override("h_separation", 6)
		stat_grid.add_theme_constant_override("v_separation", 1)
		card_content.add_child(stat_grid)
		var mana_text: String = "Mana %d" % stats["mana_max"] if int(stats["mana_max"]) > 0 else "Mana —"
		for stat_text in ["PV %d" % stats["max_hp"], "Ataque %d" % stats["damage"], "Inic. %d" % stats["initiative"], mana_text, "Res. F %d%%" % roundi(float(stats["physical_resist"]) * 100.0), "Res. M %d%%" % roundi(float(stats["magical_resist"]) * 100.0)]:
			var stat_label := label(stat_text, 10, GREEN if stat_text.begins_with("PV") else WHITE)
			stat_label.clip_text = true
			stat_label.custom_minimum_size.y = 15
			stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			stat_grid.add_child(stat_label)
		card_content.add_child(HSeparator.new())
		for skill_id in skill_ids:
			var skill: Dictionary = Skills.get_definition(skill_id)
			var skill_row := HBoxContainer.new()
			skill_row.add_theme_constant_override("separation", 6)
			card_content.add_child(skill_row)
			var skill_icon := TextureRect.new()
			skill_icon.texture = CombatIcons.texture_for(skill_id)
			skill_icon.custom_minimum_size = Vector2(20, 20)
			skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			skill_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			skill_row.add_child(skill_icon)
			var special_status: String = ""
			if skill.has("tier"):
				var tier: String = "I" if int(skill["tier"]) == 1 else "II"
				special_status = "ESP %s OK · " % tier if skill_id in permanent.get("unlocked_specials", []) else "ESP %s N%d · " % [tier, skill["level"]]
			var skill_label := label("%s%s · %s" % [special_status, skill["name"], skill_description(skill)], 9, GOLD if skill_id in permanent.get("unlocked_specials", []) else MUTED)
			skill_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			skill_label.clip_text = true
			skill_label.custom_minimum_size.y = 18
			skill_label.tooltip_text = "%s\n%s" % [skill_label.text.split(" · ")[0], skill_description(skill)]
			skill_row.add_child(skill_label)
			skill_widgets.append({"id": skill_id, "icon": skill_icon, "label": skill_label})
		_set_mouse_pass_recursive(card_content)
		choice.pressed.connect(toggle_hero.bind(hero_id))
		grid.add_child(choice)
		selection_buttons[hero_id] = choice
		selection_presentations[hero_id] = {"status": selected_status, "stats": stats, "level": level, "portrait": portrait, "skills": skill_widgets}
	var row := HBoxContainer.new()
	root.add_child(row)
	var back := button("Voltar", "Menu", WHITE)
	back.name = "SelectionBack"
	back.custom_minimum_size = Vector2(220, 48)
	back.pressed.connect(menu)
	row.add_child(back)
	start_button = button("Iniciar Tentativa", "Andar 1 · escolha de 1 a 3 heróis")
	start_button.name = "SelectionStart"
	start_button.custom_minimum_size = Vector2(0, 48)
	start_button.pressed.connect(new_attempt)
	row.add_child(start_button)
	refresh_selection()


func selection_role(hero_id: String) -> String:
	var roles := {
		"guerreiro": "Vanguarda · ataque e proteção",
		"patrulheiro": "Precisão · pressão física",
		"bruxa": "Arcano · dano e controle",
		"sacerdotisa": "Suporte · cura e purificação",
		"feiticeiro": "Conjurador · magia em área",
	}
	return roles.get(hero_id, "Aventureiro")


func _set_mouse_pass_recursive(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_set_mouse_pass_recursive(child)


func skill_description(skill: Dictionary) -> String:
	var text: String
	if skill["kind"] == "self_buff":
		text = str(StateEffects.definition(str(skill["effect"])).get("description", ""))
	elif skill["kind"] == "damage_buff":
		text = "%d dano físico; +25 p.p. crítico por 2 turnos próprios" % skill["amount"]
	elif skill["kind"] == "execute":
		text = "%d dano físico; +35%% se alvo abaixo de 35%% PV" % skill["amount"]
	elif skill["kind"] == "status_all":
		text = "aplica Fraqueza a todos os inimigos por 2 turnos"
	elif skill["kind"] == "heal_all":
		text = "cura %d PV de todos os aliados vivos" % skill["amount"]
	elif skill["kind"] == "miracle":
		text = "reanima caído com 45%% PV ou cura %d PV; remove estados" % skill["amount"]
	elif skill["kind"] == "pierce":
		text = "%d dano mágico; ignora 50%% da resistência mágica" % skill["amount"]
	elif skill["kind"] == "status":
		var effect: Dictionary = StateEffects.definition(str(skill.get("effect", "")))
		text = effect.get("name", "Efeito") + " · sem dano imediato"
	elif skill["kind"] == "guard":
		text = "reduz 40% do próximo dano de um aliado"
	elif skill["kind"] == "damage_status":
		var effect: Dictionary = StateEffects.definition(str(skill.get("effect", "")))
		text = "%d dano físico + %s por %d turnos" % [skill["amount"], effect.get("name", "efeito"), effect.get("duration", 0)]
	elif skill["kind"] == "purify":
		text = "remove Veneno e Fraqueza · recupera %d PV" % skill["amount"]
	elif skill["kind"] == "damage_all":
		text = "%d dano %s a todos os inimigos vivos" % [skill["amount"], "mágico" if skill.get("damage_type", "") == "magical" else "físico"]
	elif skill["kind"] == "heal":
		text = "cura %d PV" % skill["amount"]
	else:
		text = "%d golpes de %d" % [skill["hits"], skill["amount"]] if skill.has("hits") else "%d dano %s" % [skill["amount"], "mágico" if skill.get("damage_type", "") == "magical" else "físico"]
	if skill.has("mana"):
		text += " · %d mana" % skill["mana"]
	if skill.has("cooldown"):
		text += " · recarga %d" % skill["cooldown"]
	return text


func toggle_hero(hero_id: String) -> void:
	if hero_id in selected:
		selected.erase(hero_id)
		audio_manager.play("hero_select", -3.0)
	elif selected.size() < 3:
		selected.append(hero_id)
		audio_manager.play("hero_select")
	else:
		audio_manager.play("invalid")
	refresh_selection()


func refresh_selection() -> void:
	selection_label.text = "EQUIPE  %d / 3" % selected.size()
	start_button.disabled = selected.is_empty()
	for hero_id in Heroes.ORDER:
		var is_selected: bool = hero_id in selected
		selection_presentations[hero_id]["status"].visible = is_selected
		var button_node: Button = selection_buttons[hero_id]
		var normal := _selection_card_style(is_selected, false)
		var hover := _selection_card_style(is_selected, true)
		button_node.add_theme_stylebox_override("normal", normal)
		button_node.add_theme_stylebox_override("hover", hover)
		button_node.add_theme_stylebox_override("pressed", hover)
		button_node.add_theme_stylebox_override("focus", hover)
	for child in selection_team_row.get_children():
		selection_team_row.remove_child(child)
		child.queue_free()
	for index in range(3):
		var slot := panel()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size.y = 43
		var slot_style := style(Color(0.08, 0.12, 0.15, 0.8))
		slot_style.set_corner_radius_all(6)
		if index < selected.size():
			slot_style.border_color = GOLD
			slot_style.set_border_width_all(1)
		slot.add_theme_stylebox_override("panel", slot_style)
		selection_team_row.add_child(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		slot.add_child(row)
		if index < selected.size():
			var hero_id: String = selected[index]
			var portrait := TextureRect.new()
			portrait.texture = CombatSprites.texture_for(hero_id)
			portrait.custom_minimum_size = Vector2(30, 30)
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			row.add_child(portrait)
			var selected_name := label(Heroes.DEFINITIONS[hero_id]["name"], 11, GOLD)
			selected_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			selected_name.custom_minimum_size.y = 24
			selected_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			selected_name.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(selected_name)
		else:
			var empty_name := label("+ Espaço livre", 10, MUTED)
			empty_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty_name.custom_minimum_size.y = 15
			empty_name.clip_text = true
			row.add_child(empty_name)


func _selection_card_style(is_selected: bool, hovered: bool) -> StyleBoxFlat:
	var fill := Color(0.065, 0.09, 0.11, 0.97)
	if is_selected:
		fill = Color(0.14, 0.13, 0.095, 0.98)
	elif hovered:
		fill = Color(0.10, 0.15, 0.18, 0.98)
	var box := style(fill)
	box.set_corner_radius_all(9)
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	box.border_color = GOLD if is_selected or hovered else Color(0.52, 0.67, 0.68, 0.5)
	box.set_border_width_all(2 if is_selected else (1 if hovered else 1))
	return box


func new_attempt() -> void:
	if run.new_attempt(selected) and run.begin_floor():
		audio_manager.play("expedition_start")
		_enter_story_or_combat()


func restart_attempt() -> void:
	if not run.has_attempt():
		menu()
		return
	var ids: Array[String] = []
	for hero_id in run.attempt["hero_ids"]:
		ids.append(hero_id)
	if run.new_attempt(ids) and run.begin_floor():
		audio_manager.play("expedition_start")
		_enter_story_or_combat()


func request_outcome_destination(destination: String, dev_preview: bool = false) -> void:
	if resurrection_transitioning or narrative.active:
		return
	if dev_preview:
		_navigate_after_outcome(destination)
		return
	outcome_destination_after_resurrection = destination
	if run.queue_resurrection(true):
		_show_resurrection_scene()
	else:
		outcome_destination_after_resurrection = ""
		push_error("Não foi possível iniciar a fala da garota antes de sair do resultado.")


func _show_resurrection_scene() -> void:
	if narrative.active or not run.has_pending_resurrection():
		return
	resurrection_transitioning = true
	music_manager.play_default()
	var root := page()
	resurrection_background = ColorRect.new()
	resurrection_background.color = Color("05060d")
	resurrection_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(resurrection_background)
	resurrection_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(resurrection_background, 1)
	resurrection_background.add_child(ResurrectionBackdrop.new())
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(stage)
	var state: Dictionary = run.permanent.get("narrative", {})
	var message_id := str(state.get("pending_message", ""))
	var scene_id := "ressurreicao_primeira" if message_id == ResurrectionFlow.FIRST else "ressurreicao_alternativa"
	var definition: Dictionary = ResurrectionFlow.scene_for(message_id)
	var cursor := str(state.get("cursor", ""))
	if not cursor.is_empty():
		for line in definition.get("lines", []):
			if str(line.get("id", "")) == cursor:
				definition["first"] = cursor
				break
	if not narrative.start_definition(scene_id, definition, self):
		push_error("Não foi possível iniciar o diálogo de retorno.")
		menu()
	resurrection_transitioning = false


func _continue_after_resurrection(expected_generation: int) -> void:
	if generation != expected_generation or run.has_pending_resurrection():
		return
	resurrection_transitioning = true
	var destination: String = outcome_destination_after_resurrection
	outcome_destination_after_resurrection = ""
	_navigate_after_outcome(destination)
	var curtain := ColorRect.new()
	curtain.color = Color.BLACK
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.tween_property(curtain, "modulate:a", 0.0, 0.48)
	await tween.finished
	if is_instance_valid(curtain):
		curtain.queue_free()
	resurrection_transitioning = false


func _navigate_after_outcome(destination: String) -> void:
	match destination:
		"progression": show_progression()
		"menu": menu()
		_: show_selection()


func show_phase() -> void:
	if not run.has_attempt():
		if run.has_pending_resurrection():
			_show_resurrection_scene()
		else:
			menu()
		return
	match run.attempt["phase"]:
		"combat": _enter_story_or_combat()
		"cards": show_cards()
		"reward": show_reward()
		"relic": show_relics()
		"route": show_routes()
		"between": show_between()
		"won": _show_epilogue_or_summary()
		_: menu()


func _show_epilogue_or_summary() -> void:
	if narrative.active:
		return
	var seen: Dictionary = run.attempt.get("narrative_seen", {})
	if not bool(seen.get("epilogo_gueist", false)):
		_show_story_stage("epilogo_gueist")
		if not _start_tower_scene("epilogo_gueist"):
			push_error("Não foi possível iniciar o epílogo de Gueist.")
		return
	show_summary(_finish_attempt("victory"))


func _enter_story_or_combat() -> void:
	if not run.has_attempt() or narrative.active:
		return
	var scene_id: String = StoryFlow.next_scene(run.attempt)
	if scene_id.is_empty():
		open_combat()
		return
	_show_story_stage(scene_id)
	var started: bool = _start_tower_scene(scene_id) if scene_id == "entrada_torre" else narrative.start(scene_id, self)
	if not started:
		push_error("Não foi possível iniciar a cena narrativa %s." % scene_id)
		open_combat()


func _start_tower_scene(scene_id: String) -> bool:
	var definition: Dictionary = preload("res://data/narrative_scenes.gd").get_scene(scene_id)
	var cursors: Dictionary = run.attempt.get("narrative_cursor", {})
	var cursor := str(cursors.get(scene_id, ""))
	if not cursor.is_empty():
		for line in definition.get("lines", []):
			if str(line.get("id", "")) == cursor:
				definition["first"] = cursor
				break
	if tower_director != null and is_instance_valid(tower_director):
		tower_director.restore_state(scene_id, run.attempt.get("narrative_event_steps", {}))
	if scene_id == "entrada_torre" and bool(run.attempt.get("narrative_event_steps", {}).get("entrada_torre:boss_reveal", false)):
		music_manager.request_track("A")
	return narrative.start_definition(scene_id, definition, self)


func _continue_story_after_scene(expected_generation: int) -> void:
	if generation == expected_generation and run.has_attempt():
		show_phase()


func _show_story_stage(scene_id: String) -> void:
	if scene_id == "encontro_comerciante":
		music_manager.play_for_combat(run.attempt)
	elif scene_id == "epilogo_gueist":
		music_manager.request_track("A")
	else:
		music_manager.play_default()
	var root := page()
	menu_background = TextureRect.new()
	menu_background.texture = TOWER_GATE_OPEN if scene_id == "epilogo_gueist" else (TOWER_GATE if scene_id == "entrada_torre" else MENU_COVER)
	menu_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if scene_id in ["entrada_torre", "epilogo_gueist"] else CanvasItem.TEXTURE_FILTER_LINEAR
	menu_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_background.stretch_mode = TextureRect.STRETCH_SCALE if scene_id in ["entrada_torre", "epilogo_gueist"] else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_background)
	menu_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(menu_background, 1)
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(stage)
	if scene_id in ["entrada_torre", "epilogo_gueist"]:
		tower_director = TowerCutsceneDirector.new()
		tower_director.audio_manager = audio_manager
		stage.add_child(tower_director)
		tower_director.beat_finished.connect(_on_tower_beat_finished)
		if scene_id == "epilogo_gueist":
			tower_director.prepare_epilogue()
	else:
		tower_director = null
	var heading_panel := panel()
	heading_panel.add_theme_stylebox_override("panel", menu_panel_style(0.78))
	heading_panel.anchor_left = 0.51 if scene_id == "encontro_pai" else 0.035
	heading_panel.anchor_right = 0.965 if scene_id == "encontro_pai" else 0.49
	heading_panel.anchor_top = 0.07
	heading_panel.anchor_bottom = 0.26
	stage.add_child(heading_panel)
	var content := VBoxContainer.new()
	heading_panel.add_child(content)
	var details: Dictionary = StoryFlow.STAGES.get(scene_id, {})
	content.add_child(label(str(details.get("title", "A JORNADA")), 25, GOLD))
	content.add_child(label(str(details.get("subtitle", "")), 14, WHITE))


func open_combat() -> void:
	var attempt: Dictionary = run.attempt
	combat_resolution_handled = false
	music_manager.play_for_combat(attempt)
	combat = CombatEngine.new()
	combat.start(attempt["heroes"], Tower.enemies_for(int(attempt["floor"]), attempt.get("current_route", ""), attempt["hero_ids"].size()))
	if dev_controller != null and dev_controller.active():
		if not attempt.has("dev_floor_start_heroes"):
			attempt["dev_floor_start_heroes"] = attempt["heroes"].duplicate(true)
			run.save()
		DevOps.restore_combat_overrides(run, combat)
	pending_action = ""
	enemy_running = false
	build_combat_screen()
	audio_manager.start_wind()
	for event in combat.events:
		append_log(event)
	append_log("O combate do andar %d começou." % attempt["floor"])
	refresh_combat()
	if combat.finished:
		combat_end()
	elif not combat.is_hero_turn():
		enemy_loop()


func build_combat_screen() -> void:
	combat_action_panel = null
	close_bonus_panel()
	resolving_visual_action = false
	visual_actor_id = ""
	combat_cards.clear()
	arena_cards.clear()
	combat_feedback = null
	chips.clear()
	buttons.clear()
	skill_button_ids.clear()
	skill_button_owners.clear()
	skills_open = false
	inspected_fighter_id = ""
	var root := page()
	root.add_theme_constant_override("separation", 4)
	arena_background = TextureRect.new()
	arena_background.texture = TOWER_GATE_OPEN if int(run.attempt.get("floor", 0)) == 10 and bool(run.attempt.get("narrative_seen", {}).get("entrada_torre", false)) else (TOWER_GATE if int(run.attempt.get("floor", 0)) == 10 else BATTLEFIELD)
	arena_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Raise the landscape horizon so every participant's feet meet the grassy lane.
	arena_background.offset_top = 0 if int(run.attempt.get("floor", 0)) == 10 else -220
	arena_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena_background.stretch_mode = TextureRect.STRETCH_SCALE
	arena_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arena_background.modulate = Color(0.79, 0.85, 0.78)
	arena_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(arena_background)
	host.move_child(arena_background, 0)
	var header_panel := panel()
	header_panel.add_theme_stylebox_override("panel", combat_panel_style(0.75))
	root.add_child(header_panel)
	var header_content := HBoxContainer.new()
	header_content.add_theme_constant_override("separation", 9)
	header_panel.add_child(header_content)
	var floor_info := VBoxContainer.new()
	floor_info.custom_minimum_size.x = 300
	floor_info.add_theme_constant_override("separation", 2)
	header_content.add_child(floor_info)
	var top := HBoxContainer.new()
	floor_info.add_child(top)
	var route: Dictionary = Tower.route_by_id(run.attempt.get("current_route", ""))
	var route_name: String = " · %s" % route["name"] if not route.is_empty() else ""
	var title := label("ANDAR %d / 10%s" % [run.attempt["floor"], route_name], 20, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var back := button("Menu", "", WHITE)
	back.tooltip_text = "Voltar ao menu e recomeçar este andar"
	back.custom_minimum_size = Vector2(78, 31)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(menu)
	top.add_child(back)
	var progress := HBoxContainer.new()
	floor_info.add_child(progress)
	combat_progress_text = label("Nível %d · XP %d / 100 · %d / 10 andares" % [run.attempt["level"], run.attempt["xp"], run.attempt["completed"]], 12, MUTED)
	combat_progress_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress.add_child(combat_progress_text)
	combat_xp_bar = ProgressBar.new()
	combat_xp_bar.min_value = 0
	combat_xp_bar.max_value = 100
	combat_xp_bar.value = run.attempt["xp"]
	combat_xp_bar.show_percentage = false
	combat_xp_bar.custom_minimum_size = Vector2(62, 9)
	combat_xp_bar.add_theme_stylebox_override("background", bar_style(LIGHT))
	combat_xp_bar.add_theme_stylebox_override("fill", bar_style(GOLD))
	progress.add_child(combat_xp_bar)
	turn_label = label("", 13, GOLD)
	floor_info.add_child(turn_label)
	var initiative := panel()
	initiative.add_theme_stylebox_override("panel", combat_panel_style(0.96))
	initiative.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_content.add_child(initiative)
	var initiative_content := VBoxContainer.new()
	initiative.add_child(initiative_content)
	initiative_content.add_child(label("ORDEM DE INICIATIVA  ·  PRÓXIMOS TURNOS", 10, MUTED))
	var initiative_scroll := ScrollContainer.new()
	initiative_scroll.custom_minimum_size.y = 45
	initiative_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	initiative_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	initiative_content.add_child(initiative_scroll)
	initiative_row = HBoxContainer.new()
	initiative_row.add_theme_constant_override("separation", 4)
	initiative_scroll.add_child(initiative_row)
	for fighter_id in combat.order:
		var chip := panel()
		chip.custom_minimum_size = Vector2(103, 43)
		var chip_content := VBoxContainer.new()
		chip_content.add_theme_constant_override("separation", 2)
		chip.add_child(chip_content)
		var caption := label("", 10)
		caption.clip_text = true
		caption.custom_minimum_size = Vector2(83, 15)
		caption.tooltip_text = combat.fighters[fighter_id]["name"]
		chip_content.add_child(caption)
		var mini_bar := health_bar(combat.fighters[fighter_id]["team"] == "hero", 5)
		chip_content.add_child(mini_bar)
		initiative_row.add_child(chip)
		chips[fighter_id] = {"panel": chip, "label": caption, "bar": mini_bar}
	arena_stage = Control.new()
	arena_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# A control wrapper does not inherit the VBox/HBox minimum size, so reserve
	# enough height for three compact participant cards plus their team caption.
	arena_stage.custom_minimum_size.y = 225
	root.add_child(arena_stage)
	var teams := HBoxContainer.new()
	teams.add_theme_constant_override("separation", 18)
	teams.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	teams.offset_top = 18
	teams.offset_bottom = 18
	teams.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ambience_back: Control = CombatAmbience.new()
	ambience_back.name = "CombatAmbienceBack"
	ambience_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena_stage.add_child(ambience_back)
	arena_stage.add_child(teams)
	teams.add_child(team_column(combat.hero_ids, true))
	var versus := label("✦", 19, GOLD)
	versus.custom_minimum_size.x = 52
	versus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	teams.add_child(versus)
	teams.add_child(team_column(combat.enemy_ids, false))
	var ambience_front: Control = CombatAmbience.new()
	ambience_front.name = "CombatAmbienceFront"
	ambience_front.foreground = true
	ambience_front.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena_stage.add_child(ambience_front)
	combat_feedback = CombatFeedback.new()
	combat_feedback.name = "CombatFeedback"
	arena_stage.add_child(combat_feedback)
	combat_feedback.sfx_cue.connect(audio_manager.play)
	combat_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	combat_feedback.bind_arena(arena_cards, combat.hero_ids)
	build_enemy_hover()
	var hero_statuses := HBoxContainer.new()
	hero_statuses.add_theme_constant_override("separation", 5)
	root.add_child(hero_statuses)
	for hero_id in combat.hero_ids:
		hero_statuses.add_child(hero_status_panel(hero_id))
	for unused_slot in range(maxi(0, 3 - combat.hero_ids.size())):
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero_statuses.add_child(spacer)
	var action_panel := panel()
	combat_action_panel = action_panel
	action_panel.add_theme_stylebox_override("panel", combat_panel_style(0.88))
	root.add_child(action_panel)
	var action_content := VBoxContainer.new()
	action_panel.add_child(action_content)
	hint_label = label("", 11, MUTED)
	action_content.add_child(hint_label)
	var action_row := HFlowContainer.new()
	action_row.add_theme_constant_override("separation", 5)
	action_content.add_child(action_row)
	for item in [{"id": "attack", "title": "Atacar", "detail": "Alvo inimigo", "color": RED}, {"id": "defend", "title": "Defender", "detail": "Metade do dano", "color": Color("68aee0")}, {"id": "rescue", "title": "Socorrer", "detail": "Uma vez por combate", "color": GREEN}]:
		var action_button := button(item["title"], "", item["color"])
		combat_button_style(action_button, item["color"])
		action_button.icon = CombatIcons.texture_for(item["id"])
		action_button.tooltip_text = item["detail"]
		action_button.custom_minimum_size = Vector2(150, 39)
		action_button.pressed.connect(choose_action.bind(item["id"]))
		action_row.add_child(action_button)
		buttons[item["id"]] = action_button
	var skills_toggle := button("Habilidades", "", Color("bc83d9"))
	combat_button_style(skills_toggle, Color("bc83d9"))
	skills_toggle.icon = CombatIcons.texture_for("skills")
	skills_toggle.tooltip_text = "Abrir as habilidades do herói atual"
	skills_toggle.custom_minimum_size = Vector2(150, 39)
	skills_toggle.pressed.connect(toggle_skills)
	action_row.add_child(skills_toggle)
	buttons["skills"] = skills_toggle
	var bonuses := button("Bônus Ativos", "", GOLD)
	combat_button_style(bonuses, GOLD)
	bonuses.icon = CombatIcons.texture_for("bonuses")
	bonuses.tooltip_text = "Consultar cartas e relíquias"
	bonuses.custom_minimum_size = Vector2(150, 39)
	bonuses.pressed.connect(open_bonus_panel)
	action_row.add_child(bonuses)
	buttons["bonuses"] = bonuses
	skills_panel = panel()
	skills_panel.add_theme_stylebox_override("panel", combat_panel_style(0.96))
	skills_panel.visible = false
	action_content.add_child(skills_panel)
	var skills_content := VBoxContainer.new()
	skills_content.add_theme_constant_override("separation", 4)
	skills_panel.add_child(skills_content)
	var skills_heading := HBoxContainer.new()
	skills_content.add_child(skills_heading)
	var skills_title := label("HABILIDADES DO HERÓI ATUAL", 10, MUTED)
	skills_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_heading.add_child(skills_title)
	var close_skills_button := button("Fechar", "", MUTED)
	combat_button_style(close_skills_button)
	close_skills_button.custom_minimum_size = Vector2(85, 27)
	close_skills_button.pressed.connect(close_skills)
	skills_heading.add_child(close_skills_button)
	var skill_row := HFlowContainer.new()
	skill_row.add_theme_constant_override("separation", 5)
	skills_content.add_child(skill_row)
	for hero_id in combat.hero_ids:
		var definition: Dictionary = Heroes.get_definition(hero_id)
		var skill_ids: Array[String] = combat.skill_ids_for(combat.fighters[hero_id])
		for skill_id in skill_ids:
			var skill: Dictionary = Skills.get_definition(skill_id)
			var key: String = skill_button_key(skill_id)
			var skill_button := button(skill["name"], "", RED if skill_id == "maldicao_venenosa" else GOLD)
			combat_button_style(skill_button, RED if skill_id == "maldicao_venenosa" else GOLD)
			skill_button.icon = CombatIcons.texture_for(skill_id)
			skill_button.tooltip_text = skill_description(skill)
			skill_button.custom_minimum_size = Vector2(230, 39)
			skill_button.pressed.connect(choose_action.bind("skill:" + skill_id))
			skill_row.add_child(skill_button)
			buttons[key] = skill_button
			skill_button_ids[key] = skill_id
			skill_button_owners[key] = hero_id
			if skill_id == str(definition["skill"]) and not buttons.has("skill"):
				buttons["skill"] = skill_button
	target_row = HFlowContainer.new()
	target_row.visible = false
	action_content.add_child(target_row)
	log_toggle = button("Mostrar Registro ▴", "", MUTED)
	combat_button_style(log_toggle)
	log_toggle.custom_minimum_size = Vector2(0, 29)
	log_toggle.pressed.connect(toggle_log)
	root.add_child(log_toggle)
	log_panel = panel()
	log_panel.add_theme_stylebox_override("panel", combat_panel_style(0.87))
	log_panel.custom_minimum_size.y = 92
	log_panel.visible = false
	root.add_child(log_panel)
	var log_content := VBoxContainer.new()
	log_panel.add_child(log_content)
	log_content.add_child(label("REGISTRO DO COMBATE", 10, MUTED))
	log_box = RichTextLabel.new()
	log_box.scroll_following = true
	log_box.custom_minimum_size.y = 52
	log_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box.add_theme_color_override("default_color", WHITE)
	log_box.add_theme_font_size_override("normal_font_size", 11)
	log_content.add_child(log_box)


func health_bar(ally: bool, height: int = 7) -> ProgressBar:
	var node := ProgressBar.new()
	node.min_value = 0
	node.show_percentage = false
	node.custom_minimum_size.y = height
	node.add_theme_stylebox_override("background", bar_style(Color("102029")))
	node.add_theme_stylebox_override("fill", bar_style(GREEN if ally else RED))
	return node


func team_column(ids: Array[String], ally: bool) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	for fighter_id in ids:
		var fighter: Dictionary = combat.fighters[fighter_id]
		var slot := CenterContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(slot)
		var box := panel()
		box.add_theme_stylebox_override("panel", arena_card_style(ally, false, false, fighter["hp"] > 0))
		box.mouse_filter = Control.MOUSE_FILTER_STOP
		box.mouse_entered.connect(arena_enter.bind(fighter_id))
		box.mouse_exited.connect(arena_exit.bind(fighter_id))
		box.gui_input.connect(arena_input.bind(fighter_id))
		box.custom_minimum_size = Vector2(183, 64)
		slot.add_child(box)
		var content := HBoxContainer.new()
		box.add_child(content)
		var sprite_holder := Control.new()
		sprite_holder.custom_minimum_size = Vector2(53, 55)
		content.add_child(sprite_holder)
		var ground := Panel.new()
		var ground_style := style(Color(0.20, 0.37, 0.16, 0.48))
		ground_style.set_corner_radius_all(5)
		ground.add_theme_stylebox_override("panel", ground_style)
		ground.position = Vector2(0, 49)
		ground.size = Vector2(53, 7)
		sprite_holder.add_child(ground)
		var shadow := Panel.new()
		var shadow_style := style(Color(0.02, 0.07, 0.05, 0.62))
		shadow_style.set_corner_radius_all(8)
		shadow.add_theme_stylebox_override("panel", shadow_style)
		shadow.position = Vector2(5, 48)
		shadow.size = Vector2(43, 6)
		sprite_holder.add_child(shadow)
		var sprite := TextureRect.new()
		sprite.texture = CombatSprites.side_texture_for(fighter_id) if ally else CombatSprites.texture_for(fighter_id)
		sprite.position = Vector2(2, 2)
		sprite.size = Vector2(48, 48)
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite_holder.add_child(sprite)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_theme_constant_override("separation", 1)
		content.add_child(details)
		var name_label := label(fighter["name"], 12, GREEN if ally else RED)
		details.add_child(name_label)
		var hp := label("", 10)
		var bar := health_bar(ally)
		if not ally:
			details.add_child(bar)
		var status := label("", 9, MUTED)
		if ally:
			details.add_child(status)
		var intention := label("", 8, GOLD)
		var hidden_details := VBoxContainer.new()
		hidden_details.visible = false
		box.add_child(hidden_details)
		hidden_details.add_child(hp)
		if ally:
			hidden_details.add_child(bar)
		else:
			hidden_details.add_child(status)
		hidden_details.add_child(intention)
		var resource := label("")
		var extras := label("")
		hidden_details.add_child(resource)
		hidden_details.add_child(extras)
		var state_chips := HFlowContainer.new()
		hidden_details.add_child(state_chips)
		arena_cards[fighter_id] = {"panel": box, "sprite": sprite, "name": name_label, "hp": hp, "bar": bar, "status": status, "intention": intention if not ally else null}
		if not ally:
			combat_cards[fighter_id] = {"panel": box, "hp": hp, "bar": bar, "resource": resource, "status": status, "extras": extras, "intention": intention, "state_chips": state_chips}
		ignore_arena_mouse(box)
	return column


func ignore_arena_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ignore_arena_mouse(child)


func arena_card_style(ally: bool, active: bool, target: bool, alive: bool) -> StyleBoxFlat:
	var fill := Color(0.04, 0.08, 0.09, 0.08) if alive else Color(0.04, 0.06, 0.07, 0.27)
	if active:
		fill = Color(0.10, 0.17, 0.17, 0.38)
	elif target:
		fill = Color(0.10, 0.14, 0.16, 0.35)
	var box := style(fill)
	var accent: Color = GREEN if ally else RED
	if active:
		accent = GOLD
	elif not target:
		accent.a = 0.0
	box.border_color = accent
	box.set_border_width_all(2)
	return box


func build_enemy_hover() -> void:
	enemy_hover_panel = panel()
	enemy_hover_panel.add_theme_stylebox_override("panel", combat_panel_style(0.94))
	enemy_hover_panel.anchor_left = 0.5
	enemy_hover_panel.anchor_right = 0.5
	enemy_hover_panel.offset_left = -205
	enemy_hover_panel.offset_right = 205
	enemy_hover_panel.offset_top = 8
	enemy_hover_panel.offset_bottom = 170
	enemy_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_hover_panel.z_index = 5
	arena_stage.add_child(enemy_hover_panel)
	var row := HBoxContainer.new()
	enemy_hover_panel.add_child(row)
	enemy_hover_sprite = TextureRect.new()
	enemy_hover_sprite.custom_minimum_size = Vector2(48, 48)
	enemy_hover_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	enemy_hover_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_hover_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(enemy_hover_sprite)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 1)
	row.add_child(details)
	enemy_hover_name = label("", 14, RED)
	enemy_hover_hp = label("", 11, WHITE)
	enemy_hover_resistances = label("", 10, MUTED)
	enemy_hover_intention = label("", 10, GOLD)
	enemy_hover_target = label("", 10, WHITE)
	enemy_hover_states = label("", 10, MUTED)
	enemy_hover_intention.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_hover_states.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for part in [enemy_hover_name, enemy_hover_hp, enemy_hover_resistances, enemy_hover_intention, enemy_hover_target, enemy_hover_states]:
		details.add_child(part)
	ignore_arena_mouse(enemy_hover_panel)
	enemy_hover_panel.visible = false


func update_enemy_hover() -> void:
	if inspected_fighter_id == "" or not combat.fighters.has(inspected_fighter_id):
		enemy_hover_panel.visible = false
		return
	var fighter: Dictionary = combat.fighters[inspected_fighter_id]
	var is_enemy: bool = fighter.get("team", "enemy") == "enemy"
	enemy_hover_panel.visible = true
	enemy_hover_sprite.texture = CombatSprites.texture_for(inspected_fighter_id) if is_enemy else CombatSprites.side_texture_for(inspected_fighter_id)
	enemy_hover_name.text = fighter["name"]
	enemy_hover_name.add_theme_color_override("font_color", RED if is_enemy else GREEN)
	enemy_hover_hp.text = "%d / %d PV" % [fighter["hp"], fighter["max_hp"]]
	enemy_hover_resistances.text = "Resistências · Física %d%% · Mágica %d%%" % [roundi(float(fighter.get("physical_resist", 0.0)) * 100), roundi(float(fighter.get("magical_resist", 0.0)) * 100)]
	enemy_hover_intention.visible = is_enemy
	enemy_hover_target.visible = is_enemy
	if is_enemy:
		var intention: Dictionary = combat.intention_for(inspected_fighter_id)
		if int(fighter["hp"]) > 0 and not intention.is_empty():
			enemy_hover_intention.text = "Próxima: %s · %s\n%s" % [intention["name"], intention["type"], intention.get("description", "")]
			enemy_hover_intention.tooltip_text = intention.get("description", "")
			var target_id: String = str(intention.get("target_id", ""))
			var target: Dictionary = combat.fighters.get(target_id, {})
			enemy_hover_target.text = "Alvo: %s" % target.get("name", target_id) if target.get("state", "") == "alive" and int(target.get("hp", 0)) > 0 else "Alvo: a definir"
		else:
			enemy_hover_intention.text = "Sem próxima ação"
			enemy_hover_target.text = ""
	else:
		enemy_hover_intention.text = ""
		enemy_hover_intention.tooltip_text = ""
		enemy_hover_target.text = ""
	var states: Array[String] = []
	if int(fighter["hp"]) <= 0 or fighter.get("state", "") == "dead":
		states.append("Derrotado")
	elif fighter.get("state", "") == "downed":
		states.append("Caído")
	var descriptions: Array[String] = []
	for effect in StateEffects.get_all(fighter):
		states.append("%s %dT" % [effect["name"], effect["duration"]])
		descriptions.append("%s · %d turno(s): %s" % [effect["name"], effect["duration"], effect.get("description", "")])
	enemy_hover_states.text = "Estados: %s" % (", ".join(states) if not states.is_empty() else "nenhum")
	enemy_hover_states.tooltip_text = "\n".join(descriptions) if not descriptions.is_empty() else "Sem efeitos ativos."


func hero_status_panel(fighter_id: String) -> PanelContainer:
	var fighter: Dictionary = combat.fighters[fighter_id]
	var box := panel()
	box.add_theme_stylebox_override("panel", combat_panel_style(0.86))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size.y = 89
	var row := HBoxContainer.new()
	box.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = CombatSprites.texture_for(fighter_id)
	portrait.custom_minimum_size = Vector2(40, 40)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(portrait)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 1)
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	details.add_child(label("Classe: %s" % fighter["name"], 11, GREEN))
	var hp := label("", 10)
	details.add_child(hp)
	var bar := health_bar(true)
	details.add_child(bar)
	var resource := label("", 9, GOLD)
	details.add_child(resource)
	var status := label("", 9, MUTED)
	details.add_child(status)
	var extras := label("", 8, MUTED)
	extras.clip_text = true
	details.add_child(extras)
	var state_chips := HFlowContainer.new()
	details.add_child(state_chips)
	combat_cards[fighter_id] = {"panel": box, "sprite": portrait, "hp": hp, "bar": bar, "resource": resource, "status": status, "extras": extras, "intention": null, "state_chips": state_chips}
	return box


func refresh_combat() -> void:
	if combat.order.is_empty():
		return
	if combat_cards.size() != combat.order.size() or arena_cards.size() != combat.order.size():
		return
	for fighter_id in combat.order:
		if not combat_cards.has(fighter_id) or not arena_cards.has(fighter_id):
			return
		if not is_instance_valid(combat_cards[fighter_id].get("hp")) or not is_instance_valid(arena_cards[fighter_id].get("hp")):
			return
	if combat_feedback != null and is_instance_valid(combat_feedback):
		combat_feedback.update_fighters(combat.fighters)
	if run.has_attempt():
		if is_instance_valid(combat_progress_text):
			combat_progress_text.text = "Nível %d · XP %d / 100 · %d / 10 andares" % [run.attempt["level"], run.attempt["xp"], run.attempt["completed"]]
		if is_instance_valid(combat_xp_bar):
			combat_xp_bar.value = int(run.attempt["xp"])
	for fighter_id in combat.order:
		var fighter: Dictionary = combat.fighters[fighter_id]
		var card: Dictionary = combat_cards[fighter_id]
		var arena: Dictionary = arena_cards[fighter_id]
		card["hp"].text = "%d / %d PV" % [fighter["hp"], fighter["max_hp"]]
		card["bar"].max_value = fighter["max_hp"]
		card["bar"].value = fighter["hp"]
		arena["hp"].text = "%d / %d PV" % [fighter["hp"], fighter["max_hp"]]
		arena["bar"].max_value = fighter["max_hp"]
		arena["bar"].value = fighter["hp"]
		if fighter.get("state", "") == "dead" or (fighter["team"] == "enemy" and int(fighter["hp"]) <= 0):
			arena["sprite"].modulate = Color(0.35, 0.39, 0.43, 0.6)
		elif fighter.get("state", "") == "downed":
			arena["sprite"].modulate = Color(0.65, 0.68, 0.78, 0.75)
		else:
			arena["sprite"].modulate = Color.WHITE
		if fighter["team"] == "hero":
			card["sprite"].modulate = arena["sprite"].modulate
		var shown_actor_id: String = visual_actor_id if resolving_visual_action and visual_actor_id != "" else combat.current_id()
		var current: bool = fighter_id == shown_actor_id and (resolving_visual_action or not combat.finished)
		var status: String = "Vivo"
		if fighter["team"] == "hero":
			if fighter["state"] == "downed":
				status = "Caído · %d rodadas" % fighter["down_rounds"]
			elif fighter["state"] == "dead":
				status = "Morto"
			elif current:
				status = "Vivo · agindo agora"
			elif fighter["defending"]:
				status = "Defendendo"
			card["resource"].text = "Mana: %d / %d" % [fighter["mana"], fighter["mana_max"]] if int(fighter["mana_max"]) > 0 else skill_cooldown_summary(fighter_id)
			var active_text: String = active_effects(fighter)
			if float(fighter.get("guard_reduction", 0.0)) > 0.0:
				active_text += " · Guarda Protetora (40%)"
			card["extras"].text = active_text
		else:
			status = "Derrotado" if int(fighter["hp"]) <= 0 else ("Agindo agora" if current else "Pronto")
			card["resource"].text = "Resist. física %d%% · mágica %d%%" % [roundi(float(fighter.get("physical_resist", 0.0)) * 100), roundi(float(fighter.get("magical_resist", 0.0)) * 100)]
			card["extras"].text = ""
			var intention: Dictionary = combat.intention_for(fighter_id)
			var intent_label: Label = card["intention"]
			if int(fighter["hp"]) > 0 and not intention.is_empty():
				var target_id: String = str(intention.get("target_id", ""))
				var target: Dictionary = combat.fighters.get(target_id, {})
				var target_text: String = " · alvo: %s" % target.get("name", target_id) if target.get("state", "") == "alive" and int(target.get("hp", 0)) > 0 else ""
				intent_label.text = "Próxima: %s · %s%s" % [intention["name"], intention["type"], target_text]
				intent_label.tooltip_text = "%s%s\n%s" % [intention["name"], target_text, intention["description"]]
				intent_label.visible = true
			else:
				intent_label.text = ""
				intent_label.tooltip_text = ""
				intent_label.visible = false
		card["status"].text = status
		arena["status"].text = status
		arena["status"].visible = fighter["team"] == "hero" and (current or fighter["state"] != "alive")
		if fighter["team"] == "enemy":
			arena["name"].text = fighter["name"] + (" · AGINDO" if current else (" · DERROTADO" if int(fighter["hp"]) <= 0 else ""))
		for child in card["state_chips"].get_children():
			card["state_chips"].remove_child(child)
			child.queue_free()
		for effect in StateEffects.get_all(fighter):
			var effect_chip := Button.new()
			effect_chip.text = "%s · %dT" % [effect["name"], effect["duration"]]
			effect_chip.tooltip_text = effect.get("description", "")
			effect_chip.custom_minimum_size = Vector2(0, 20)
			effect_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			effect_chip.focus_mode = Control.FOCUS_NONE
			effect_chip.add_theme_font_size_override("font_size", 9)
			effect_chip.add_theme_color_override("font_color", GOLD)
			effect_chip.add_theme_stylebox_override("normal", style(LIGHT))
			effect_chip.add_theme_stylebox_override("hover", style(Color("304854")))
			card["state_chips"].add_child(effect_chip)
		card["status"].add_theme_color_override("font_color", RED if status == "Morto" or status.begins_with("Caído") or status == "Derrotado" else (GOLD if current else MUTED))
		var card_style := combat_panel_style(0.87 if int(fighter["hp"]) > 0 else 0.91)
		if current:
			card_style.border_color = GOLD
			card_style.set_border_width_all(2)
		card["panel"].add_theme_stylebox_override("panel", card_style)
		var is_hovered: bool = hovered_target_id == fighter_id and pending_action != "" or inspected_fighter_id == fighter_id
		var arena_style := arena_card_style(fighter["team"] == "hero", current, is_hovered, int(fighter["hp"]) > 0)
		arena["panel"].add_theme_stylebox_override("panel", arena_style)
		var chip: Dictionary = chips[fighter_id]
		var dead: bool = fighter.get("state", "") == "dead" or (fighter["team"] == "enemy" and int(fighter["hp"]) <= 0)
		chip["panel"].visible = not dead
		chip["label"].text = "%s%s" % ["▶ " if current else "", fighter["name"]]
		if fighter.get("state", "") == "downed":
			chip["label"].text += " · Caído"
		chip["bar"].max_value = fighter["max_hp"]
		chip["bar"].value = fighter["hp"]
		var chip_color := GOLD if current else (Color("273238") if fighter.get("state", "") == "downed" else PANEL)
		chip_color.a = 0.88
		var chip_style := style(chip_color)
		if not current:
			chip_style.border_color = GREEN if fighter["team"] == "hero" else RED
			chip_style.set_border_width_all(1)
		chip["panel"].add_theme_stylebox_override("panel", chip_style)
		chip["label"].add_theme_color_override("font_color", BG if current else (MUTED if fighter.get("state", "") == "downed" else WHITE))
	# The first visible portrait is acting now; the rest follow the engine's order.
	if not combat.finished:
		var shown_start_id: String = visual_actor_id if resolving_visual_action and visual_actor_id != "" else combat.current_id()
		var start: int = combat.order.find(shown_start_id)
		for offset in combat.order.size():
			var ordered_id: String = combat.order[(start + offset) % combat.order.size()]
			initiative_row.move_child(chips[ordered_id]["panel"], offset)
	var shown_name: String = str(combat.fighters.get(visual_actor_id, {}).get("name", "")) if resolving_visual_action else str(combat.current().get("name", ""))
	turn_label.text = "Andar %d / 10 · Rodada %d · %s" % [run.attempt["floor"], combat.round_number, shown_name]
	var hero_turn: bool = combat.is_hero_turn()
	hint_label.text = "Escolha uma ação para %s." % combat.current().get("name", "") if hero_turn else "Turno automático do inimigo."
	if resolving_visual_action:
		hint_label.text = "Ação de %s em andamento..." % shown_name
	if pending_action != "":
		var action_name: String = "Atacar" if pending_action == "attack" else "Socorrer"
		if pending_action.begins_with("skill:"):
			action_name = Skills.get_definition(pending_action.trim_prefix("skill:"))["name"]
		hint_label.text = "Selecione um alvo para %s. Clique no personagem ou use os botões abaixo." % action_name
	buttons["attack"].disabled = resolving_visual_action or not hero_turn or pending_action != ""
	buttons["defend"].disabled = resolving_visual_action or not hero_turn or pending_action != ""
	buttons["rescue"].disabled = resolving_visual_action or not hero_turn or pending_action != "" or combat.rescue_used or combat.targets("rescue").is_empty()
	buttons["skills"].disabled = resolving_visual_action or not hero_turn or pending_action != ""
	if not hero_turn or pending_action != "":
		skills_open = false
		skills_panel.visible = false
	var active_skill_ids: Array[String] = []
	if hero_turn:
		active_skill_ids = combat.skill_ids_for(combat.current())
	for button_key in skill_button_ids:
		var skill_id: String = str(skill_button_ids[button_key])
		var owner_id: String = str(skill_button_owners[button_key])
		var skill: Dictionary = Skills.get_definition(skill_id)
		var action: String = "skill:" + skill_id
		var has_targets: bool = not combat.targets(action).is_empty()
		var available: bool = hero_turn and skill_id in active_skill_ids and combat.skill_available(skill_id) and has_targets
		buttons[button_key].visible = hero_turn and skill_id in active_skill_ids
		buttons[button_key].disabled = resolving_visual_action or not available or pending_action != ""
		var remaining: int = combat.skill_cooldown_remaining(owner_id, skill_id)
		var details: String = skill_description(skill)
		if remaining > 0:
			details += " · restante: %d turno(s)" % remaining
		var cost_text: String = "Pronta"
		if skill.has("mana"):
			cost_text = "%d mana" % skill["mana"]
			if hero_turn and skill_id in active_skill_ids and int(combat.current().get("mana", 0)) < int(skill["mana"]):
				cost_text += " · sem mana"
		elif skill.has("cooldown"):
			cost_text = "Recarga %dT" % remaining if remaining > 0 else "Pronta · recarga %dT" % skill["cooldown"]
		buttons[button_key].text = "%s  ·  %s" % [skill["name"], cost_text]
		buttons[button_key].tooltip_text = details
	update_enemy_hover()


func toggle_skills() -> void:
	if narrative.active or resolving_visual_action or not combat.is_hero_turn() or pending_action != "":
		return
	skills_open = not skills_open
	skills_panel.visible = skills_open


func close_skills() -> void:
	skills_open = false
	if skills_panel != null and is_instance_valid(skills_panel):
		skills_panel.visible = false


func toggle_log() -> void:
	if narrative.active:
		return
	log_panel.visible = not log_panel.visible
	log_toggle.text = "Ocultar Registro ▾" if log_panel.visible else "Mostrar Registro ▴"


func skill_button_key(skill_id: String) -> String:
	if skill_id == "maldicao_venenosa":
		return "skill_veneno"
	return "skill_" + skill_id


func skill_cooldown_summary(fighter_id: String) -> String:
	var parts: Array[String] = []
	var fighter: Dictionary = combat.fighters.get(fighter_id, {})
	for skill_id in combat.skill_ids_for(fighter):
		var skill: Dictionary = Skills.get_definition(skill_id)
		var remaining: int = combat.skill_cooldown_remaining(fighter_id, skill_id)
		if int(skill.get("cooldown", 0)) <= 0:
			continue
		parts.append("%s %d" % [skill["name"], remaining] if remaining > 0 else "%s pronta" % skill["name"])
	return "Recargas: %s" % " · ".join(parts) if not parts.is_empty() else "Sem recargas"


func active_effects(hero: Dictionary) -> String:
	var parts: Array[String] = []
	for card_id in hero.get("cards", {}):
		parts.append("%s %s" % [Cards.DEFINITIONS[card_id]["name"], ["I", "II", "III"][int(hero["cards"][card_id]) - 1]])
	for relic in run.attempt.get("relics", []):
		if relic.get("bearer", "") == hero["id"] or relic["id"] == "medalhao_vital":
			parts.append(Relics.DEFINITIONS[relic["id"]]["name"])
	return ", ".join(parts) if not parts.is_empty() else "Sem cartas ou relíquias"


func open_bonus_panel() -> void:
	if narrative.active or bonus_panel_open or combat.fighters.is_empty():
		return
	bonus_panel_open = true
	bonus_hero_buttons.clear()
	bonus_overlay = Control.new()
	bonus_overlay.name = "ActiveBonusesOverlay"
	bonus_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	bonus_overlay.z_index = 100
	host.add_child(bonus_overlay)
	bonus_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.04, 0.06, 0.82)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	bonus_overlay.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	bonus_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var modal := panel()
	modal.custom_minimum_size = Vector2(850, 600)
	center.add_child(modal)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	modal.add_child(layout)
	var title_row := HBoxContainer.new()
	layout.add_child(title_row)
	var title := label("Bônus Ativos", 22, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close := button("Fechar", "Continuar combate", WHITE)
	close.custom_minimum_size = Vector2(150, 40)
	close.pressed.connect(close_bonus_panel)
	title_row.add_child(close)
	layout.add_child(label("Consulta gratuita: veja as cartas e relíquias atuais de qualquer herói.", 12, MUTED))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	layout.add_child(body)
	var selector_panel := panel()
	selector_panel.custom_minimum_size.x = 220
	body.add_child(selector_panel)
	var selector := VBoxContainer.new()
	selector.add_child(label("EQUIPE", 10, MUTED))
	selector_panel.add_child(selector)
	for hero_id in combat.hero_ids:
		var fighter: Dictionary = combat.fighters[hero_id]
		var state_text: String = "Vivo" if fighter["state"] == "alive" else ("Caído" if fighter["state"] == "downed" else "Morto")
		var hero_button := button(fighter["name"], "%s · %d/%d PV" % [state_text, fighter["hp"], fighter["max_hp"]], WHITE)
		hero_button.custom_minimum_size.y = 48
		hero_button.pressed.connect(show_bonus_hero.bind(hero_id))
		selector.add_child(hero_button)
		bonus_hero_buttons[hero_id] = hero_button
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	bonus_details = VBoxContainer.new()
	bonus_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus_details.add_theme_constant_override("separation", 7)
	scroll.add_child(bonus_details)
	if not combat.hero_ids.is_empty():
		show_bonus_hero(combat.hero_ids[0])


func show_bonus_hero(hero_id: String) -> void:
	if bonus_details == null or not is_instance_valid(bonus_details) or not combat.fighters.has(hero_id):
		return
	for child in bonus_details.get_children():
		bonus_details.remove_child(child)
		child.queue_free()
	for id in bonus_hero_buttons:
		var button_node: Button = bonus_hero_buttons[id]
		var box := style(GOLD.darkened(0.45) if id == hero_id else LIGHT)
		if id == hero_id:
			box.border_color = GOLD
			box.set_border_width_all(2)
		button_node.add_theme_stylebox_override("normal", box)
		button_node.add_theme_stylebox_override("hover", box)
	var fighter: Dictionary = combat.fighters[hero_id]
	var individual_count := 0
	bonus_details.add_child(label("BÔNUS INDIVIDUAIS · %s" % fighter["name"].to_upper(), 11, GOLD))
	for card_id in fighter.get("cards", {}):
		var level: int = int(fighter["cards"][card_id])
		var definition: Dictionary = Cards.DEFINITIONS.get(card_id, {})
		if definition.is_empty() or level < 1 or level > 3:
			continue
		add_bonus_entry(Cards.label(card_id, level), definition.get("condition", ""))
		individual_count += 1
	for relic in run.attempt.get("relics", []):
		var relic_id: String = relic.get("id", "")
		var definition: Dictionary = Relics.DEFINITIONS.get(relic_id, {})
		if definition.is_empty() or definition.get("scope", "hero") != "hero" or relic.get("bearer", "") != hero_id:
			continue
		add_bonus_entry("%s — %s" % [definition["name"], definition["description"]], definition.get("condition", ""))
		individual_count += 1
	var bonus_count: int = individual_count
	for effect in StateEffects.get_all(fighter):
		add_bonus_entry("%s · %d turno(s) — %s" % [effect["name"], effect["duration"], effect["description"]], "")
		individual_count += 1
	if individual_count == 0:
		bonus_details.add_child(label("Este herói não possui bônus individuais ativos.", 12, MUTED))
	bonus_details.add_child(HSeparator.new())
	bonus_details.add_child(label("BÔNUS DE EQUIPE", 11, GOLD))
	var team_count := 0
	for relic in run.attempt.get("relics", []):
		var relic_id: String = relic.get("id", "")
		var definition: Dictionary = Relics.DEFINITIONS.get(relic_id, {})
		if definition.is_empty() or definition.get("scope", "hero") != "team":
			continue
		add_bonus_entry("%s — %s" % [definition["name"], definition["description"]], definition.get("condition", ""))
		team_count += 1
	if team_count == 0:
		bonus_details.add_child(label("Nenhum bônus afeta toda a equipe.", 12, MUTED))
	if bonus_count == 0 and team_count == 0:
		bonus_details.add_child(label("Este herói não possui cartas ou relíquias ativas.", 12, MUTED))


func add_bonus_entry(description: String, condition: String) -> void:
	var box := panel()
	var content := VBoxContainer.new()
	content.add_child(label(description, 13, WHITE))
	if not condition.is_empty():
		content.add_child(label("Condição: %s" % condition, 11, MUTED))
	box.add_child(content)
	bonus_details.add_child(box)


func close_bonus_panel() -> void:
	bonus_panel_open = false
	bonus_details = null
	bonus_hero_buttons.clear()
	if bonus_overlay != null and is_instance_valid(bonus_overlay):
		bonus_overlay.queue_free()
	bonus_overlay = null


func choose_action(action: String) -> void:
	if dev_panel != null and is_instance_valid(dev_panel):
		return
	if narrative.active:
		return
	if resolving_visual_action or not combat.is_hero_turn():
		audio_manager.play("invalid", -5.0)
		return
	close_skills()
	if action == "defend":
		var visual: Dictionary = CombatActionVisuals.hero_action(combat.current_id(), action, "", [])
		if combat.act("defend"):
			after_action(visual)
		return
	if combat.is_skill_action(action):
		var skill_id: String = combat.skill_id_for(combat.current(), action)
		if not combat.skill_available(skill_id):
			audio_manager.play("invalid", -5.0)
			return
		var skill: Dictionary = Skills.get_definition(skill_id)
		if skill.get("target", "") in ["all_enemies", "all_allies", "self"]:
			var visual: Dictionary = CombatActionVisuals.hero_action(combat.current_id(), action, "", combat.targets(action))
			if combat.act(action):
				after_action(visual)
			return
	if action == "rescue" and combat.rescue_used:
		audio_manager.play("invalid", -5.0)
		return
	pending_action = action
	show_targets()
	refresh_combat()


func show_targets() -> void:
	if narrative.active:
		return
	for child in target_row.get_children():
		target_row.remove_child(child)
		child.queue_free()
	target_row.visible = true
	for target_id in combat.targets(pending_action):
		var target: Dictionary = combat.fighters[target_id]
		var choice := button("%s · %d PV" % [target["name"], target["hp"]], "Caído" if target["state"] == "downed" else "", WHITE)
		combat_button_style(choice)
		choice.custom_minimum_size = Vector2(130, 34)
		choice.mouse_entered.connect(hover_target.bind(target_id))
		choice.mouse_exited.connect(hover_target.bind(""))
		choice.pressed.connect(target_chosen.bind(target_id))
		target_row.add_child(choice)
	var cancel := button("Cancelar", "", MUTED)
	combat_button_style(cancel)
	cancel.custom_minimum_size = Vector2(130, 34)
	cancel.pressed.connect(cancel_targets)
	target_row.add_child(cancel)


func cancel_targets() -> void:
	if narrative.active:
		return
	pending_action = ""
	hovered_target_id = ""
	target_row.visible = false
	refresh_combat()


func target_chosen(target_id: String) -> void:
	if dev_panel != null and is_instance_valid(dev_panel):
		return
	if narrative.active:
		return
	if resolving_visual_action or pending_action.is_empty() or target_id not in combat.targets(pending_action):
		return
	var action: String = pending_action
	var visual: Dictionary = CombatActionVisuals.hero_action(combat.current_id(), action, target_id, combat.targets(action))
	pending_action = ""
	hovered_target_id = ""
	target_row.visible = false
	if combat.act(action, target_id):
		after_action(visual)
	else:
		refresh_combat()


func hover_target(target_id: String) -> void:
	if pending_action == "":
		return
	hovered_target_id = target_id if target_id in combat.targets(pending_action) else ""
	refresh_combat()


func arena_enter(fighter_id: String) -> void:
	inspected_fighter_id = fighter_id
	hover_target(fighter_id)
	update_enemy_hover()
	if pending_action == "":
		refresh_combat()


func arena_exit(fighter_id: String) -> void:
	if inspected_fighter_id == fighter_id:
		inspected_fighter_id = ""
	hover_target("")
	update_enemy_hover()
	if pending_action == "":
		refresh_combat()


func arena_input(event: InputEvent, fighter_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		target_chosen(fighter_id)


func after_action(visual: Dictionary) -> void:
	resolving_visual_action = true
	visual_actor_id = str(visual.get("actor_id", ""))
	var token: int = generation
	var enemy_rewards: Dictionary = _reward_defeated_enemies()
	for event in combat.events:
		append_log(event)
	refresh_combat()
	if combat_feedback != null and is_instance_valid(combat_feedback):
		await combat_feedback.play_action(visual, combat.visual_events.duplicate(true))
		await combat_feedback.play_enemy_deaths(combat.fighters, enemy_rewards)
	while is_inside_tree() and token == generation and dev_panel != null and is_instance_valid(dev_panel):
		await get_tree().process_frame
	if token != generation or not is_inside_tree():
		return
	resolving_visual_action = false
	visual_actor_id = ""
	refresh_combat()
	if combat.finished:
		finish_combat_after_feedback()
	elif not combat.is_hero_turn():
		enemy_loop()


func finish_combat_after_feedback() -> void:
	var token: int = generation
	await get_tree().create_timer(0.68, false).timeout
	while is_inside_tree() and token == generation and (narrative.active or (dev_panel != null and is_instance_valid(dev_panel))):
		await get_tree().process_frame
	if is_inside_tree() and token == generation and combat.finished:
		combat_end()


func append_log(message: String) -> void:
	if log_box != null and is_instance_valid(log_box):
		log_box.append_text("• %s\n" % message)


func enemy_loop() -> void:
	if enemy_running:
		return
	enemy_running = true
	var token: int = generation
	while token == generation and not combat.finished and not combat.is_hero_turn():
		await get_tree().create_timer(0.35, false).timeout
		while token == generation and (bonus_panel_open or narrative.active or (dev_panel != null and is_instance_valid(dev_panel))) and not combat.finished:
			await get_tree().process_frame
		if token != generation or combat.finished:
			break
		var enemy_id: String = combat.current_id()
		var living_heroes: Array[String] = []
		for hero_id in combat.hero_ids:
			if combat.fighters[hero_id].get("state", "") == "alive" and int(combat.fighters[hero_id]["hp"]) > 0:
				living_heroes.append(hero_id)
		var visual: Dictionary = CombatActionVisuals.enemy_action(enemy_id, combat.intention_for(enemy_id), living_heroes)
		resolving_visual_action = true
		visual_actor_id = enemy_id
		if not combat.act_enemy():
			resolving_visual_action = false
			visual_actor_id = ""
			break
		if not bool(visual.get("area", false)) and visual.get("style", "") != "guard":
			for effect_event in combat.visual_events:
				if effect_event.get("kind", "") == "damage" and str(effect_event.get("target_id", "")) in combat.hero_ids:
					visual["targets"] = [str(effect_event["target_id"])]
					break
		var enemy_rewards: Dictionary = _reward_defeated_enemies()
		for event in combat.events:
			append_log(event)
		refresh_combat()
		if combat_feedback != null and is_instance_valid(combat_feedback):
			await combat_feedback.play_action(visual, combat.visual_events.duplicate(true))
			await combat_feedback.play_enemy_deaths(combat.fighters, enemy_rewards)
		while is_inside_tree() and token == generation and dev_panel != null and is_instance_valid(dev_panel):
			await get_tree().process_frame
		if token != generation or not is_inside_tree():
			break
		resolving_visual_action = false
		visual_actor_id = ""
		refresh_combat()
		if combat.finished:
			finish_combat_after_feedback()
			break
	enemy_running = false


func _reward_defeated_enemies() -> Dictionary:
	var rewards: Dictionary = {}
	if not run.has_attempt():
		return rewards
	for enemy_id in combat.enemy_ids:
		var enemy: Dictionary = combat.fighters.get(enemy_id, {})
		if enemy.is_empty() or (int(enemy.get("hp", 0)) > 0 and enemy.get("state", "") != "dead"):
			continue
		var enemy_key: String = "%d:%s" % [int(run.attempt["floor"]), enemy_id]
		var reward: Dictionary = run.reward_enemy(enemy_key, int(enemy.get("xp_reward", 0)), int(enemy.get("coin_reward", 0)))
		if not reward.is_empty():
			rewards[enemy_id] = reward
	return rewards


func combat_end() -> void:
	if combat_resolution_handled or not run.has_attempt() or run.attempt.get("phase", "") != "combat":
		return
	combat_resolution_handled = true
	generation += 1
	if combat.outcome == "victory":
		if int(run.attempt.get("floor", 0)) < Tower.MAX_FLOOR:
			audio_manager.play("floor_clear")
		run.victory(combat.hero_states())
		if int(run.attempt.get("floor", 0)) < Tower.MAX_FLOOR:
			get_tree().create_timer(0.42).timeout.connect(audio_manager.play.bind("level_up"))
		show_phase()
	else:
		show_summary(_finish_attempt("defeat"))


func _finish_attempt(result: String) -> Dictionary:
	var levels_before: Dictionary = {}
	for hero_id in run.permanent["classes"]:
		levels_before[hero_id] = int(run.permanent["classes"][hero_id].get("level", 1))
	var summary: Dictionary = run.end_attempt(result)
	if summary.is_empty():
		return summary
	audio_manager.play("final_victory" if result == "victory" else "defeat")
	for hero_id in levels_before:
		if int(run.permanent["classes"][hero_id].get("level", 1)) > int(levels_before[hero_id]):
			get_tree().create_timer(0.5).timeout.connect(audio_manager.play.bind("level_up"))
			break
	return summary


func show_cards() -> void:
	music_manager.play_default()
	var hero_id: String = run.current_card_hero()
	if hero_id.is_empty():
		menu()
		return
	var root := page()
	root.add_theme_constant_override("separation", 12)
	reward_header(root, "ESCOLHA UMA CARTA", "EVOLUÇÃO DO HERÓI · NÍVEL INTERNO %d" % run.attempt["level"], "Uma carta para %s" % Heroes.DEFINITIONS[hero_id]["name"], hero_id)
	var offers := reward_scroll(root)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offers.add_child(row)
	var owned: Dictionary = {}
	for hero in run.attempt["heroes"]:
		if hero["id"] == hero_id:
			owned = hero["cards"]
			break
	for card_id in run.attempt["card_offers"].get(hero_id, []):
		var next_level: int = int(owned.get(card_id, 0)) + 1
		var choice := card_reward_choice(card_id, next_level)
		choice.pressed.connect(pick_card.bind(card_id))
		row.add_child(choice)
	root.add_child(label("CARTAS DE %s  ·  %s" % [Heroes.DEFINITIONS[hero_id]["name"].to_upper(), cards_for(hero_id)], 11, MUTED))
	footer(root)


func reward_header(root: VBoxContainer, title: String, eyebrow: String, subtitle: String, hero_id: String = "") -> void:
	var frame := panel()
	frame.name = "RewardHeader"
	frame.add_theme_stylebox_override("panel", reward_frame_style(GOLD, false, true))
	frame.custom_minimum_size.y = 94
	root.add_child(frame)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	frame.add_child(row)
	if not hero_id.is_empty():
		row.add_child(reward_icon(CombatSprites.texture_for(hero_id), 62))
	var heading_column := VBoxContainer.new()
	heading_column.add_theme_constant_override("separation", 3)
	heading_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading_column)
	heading_column.add_child(label(eyebrow, 10, GOLD))
	heading_column.add_child(label(title, 25, WHITE))
	heading_column.add_child(label(subtitle, 12, MUTED))


func reward_scroll(root: VBoxContainer) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "RewardChoicesScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	return scroll


func reward_frame_style(accent: Color, hovered: bool, neutral: bool = false) -> StyleBoxFlat:
	var fill := Color("111a24") if neutral else Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 1.0)
	if hovered:
		fill = fill.lightened(0.10)
	var box := style(fill)
	box.set_corner_radius_all(3)
	box.content_margin_left = 15
	box.content_margin_right = 15
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	box.border_color = accent if hovered else accent.darkened(0.24)
	box.border_width_top = 3
	box.border_width_bottom = 3
	box.border_width_left = 2
	box.border_width_right = 2
	return box


func reward_icon(texture: Texture2D, pixels: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(pixels, pixels)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func reward_choice_button(accent: Color, height: int, selected_reward: bool = false) -> Button:
	var choice := Button.new()
	choice.custom_minimum_size = Vector2(0, height)
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.focus_mode = Control.FOCUS_ALL
	choice.add_theme_stylebox_override("normal", reward_frame_style(accent, selected_reward))
	var highlighted := reward_frame_style(accent, true)
	choice.add_theme_stylebox_override("hover", highlighted)
	choice.add_theme_stylebox_override("pressed", highlighted)
	choice.add_theme_stylebox_override("focus", highlighted)
	choice.add_theme_stylebox_override("disabled", reward_frame_style(Color("667078"), false))
	return choice


func card_reward_choice(card_id: String, next_level: int) -> Button:
	var definition: Dictionary = Cards.DEFINITIONS[card_id]
	var theme: Dictionary = RewardVisuals.card_theme(card_id)
	var accent: Color = theme["color"]
	var choice := reward_choice_button(accent, 425)
	choice.name = "CardChoice_%s" % card_id
	choice.tooltip_text = Cards.label(card_id, next_level)
	if not definition.get("condition", "").is_empty():
		choice.tooltip_text += "\n%s" % definition["condition"]
	var padding := MarginContainer.new()
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		padding.add_theme_constant_override("margin_%s" % edge, 16)
	for edge in ["top", "bottom"]:
		padding.add_theme_constant_override("margin_%s" % edge, 14)
	choice.add_child(padding)
	var contents := VBoxContainer.new()
	padding.add_child(contents)
	contents.add_theme_constant_override("separation", 9)
	contents.add_child(label("✦   %s   ✦" % theme["category"], 10, accent))
	var title := label(definition["name"], 21, WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size.y = 54
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	contents.add_child(title)
	var level_text: String = ["I", "II", "III"][next_level - 1]
	var state: String = "NOVA CARTA" if next_level == 1 else "EVOLUÇÃO  %s → %s" % [["I", "II"][next_level - 2], level_text]
	var level_label := label("%s   ·   NÍVEL %s" % [state, level_text], 11, accent)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(level_label)
	contents.add_child(HSeparator.new())
	var art := CenterContainer.new()
	art.custom_minimum_size.y = 122
	contents.add_child(art)
	var medallion := panel()
	var medallion_style := style(Color(accent.r * 0.23, accent.g * 0.23, accent.b * 0.23, 1.0))
	medallion_style.set_corner_radius_all(0)
	medallion_style.border_color = accent
	medallion_style.set_border_width_all(2)
	medallion_style.content_margin_left = 14
	medallion_style.content_margin_right = 14
	medallion_style.content_margin_top = 14
	medallion_style.content_margin_bottom = 14
	medallion.add_theme_stylebox_override("panel", medallion_style)
	art.add_child(medallion)
	var symbol := reward_icon(CombatIcons.texture_for(theme["icon"]), 78)
	symbol.modulate = accent.lightened(0.2)
	medallion.add_child(symbol)
	contents.add_child(HSeparator.new())
	var effect := label(str(definition["levels"][next_level - 1]), 16, WHITE)
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.add_child(effect)
	if next_level == 3:
		var max_label := label("✦ NÍVEL MÁXIMO APÓS A ESCOLHA ✦", 10, accent)
		max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		contents.add_child(max_label)
	contents.add_child(label("◆ ━━━━━━━ ESCOLHER ━━━━━━━ ◆", 11, accent))
	_set_mouse_pass_recursive(padding)
	return choice


func cards_for(hero_id: String) -> String:
	for hero in run.attempt["heroes"]:
		if hero["id"] == hero_id:
			var names: Array[String] = []
			for card_id in hero["cards"]:
				names.append(Cards.label(card_id, int(hero["cards"][card_id])))
			return ", ".join(names) if not names.is_empty() else "nenhuma"
	return "nenhuma"


func pick_card(card_id: String) -> void:
	var old_level: int = 0
	for hero in run.attempt.get("heroes", []):
		if hero["id"] == run.current_card_hero():
			old_level = int(hero["cards"].get(card_id, 0))
			break
	if run.choose_card(card_id):
		audio_manager.play("card" if old_level == 0 else "unlock")
		show_phase()


func show_reward(reward_type: String = "", hero_id: String = "") -> void:
	music_manager.play_default()
	var root := page()
	root.add_theme_constant_override("separation", 10)
	var header := panel()
	header.name = "RewardScreenHeader"
	header.add_theme_stylebox_override("panel", reward_frame_style(GOLD, false, true))
	header.custom_minimum_size.y = 92
	root.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	header.add_child(header_row)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.add_theme_constant_override("separation", 2)
	header_row.add_child(title_column)
	title_column.add_child(label("PAUSA PARA SE RECUPERAR", 10, GOLD))
	title_column.add_child(label("Recompensa do Andar %d" % run.attempt["completed"], 24, WHITE))
	title_column.add_child(label("Escolha um benefício e um herói vivo para recebê-lo.", 11, MUTED))
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 6)
	header_row.add_child(metrics)
	metrics.add_child(between_metric("NÍVEL", str(run.attempt["level"])))
	metrics.add_child(between_metric("XP", "%d / 100" % run.attempt["xp"]))
	metrics.add_child(between_metric("AND. FEITOS", str(run.attempt["completed"])))
	var body_scroll := ScrollContainer.new()
	body_scroll.name = "RewardScreenScroll"
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(body_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if reward_type.is_empty():
		body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 8)
	body_scroll.add_child(body)
	var options_heading := label("ESCOLHA UMA RECOMPENSA", 11, GOLD)
	options_heading.custom_minimum_size.x = 300
	body.add_child(options_heading)
	var options := HBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 12)
	body.add_child(options)
	var rest_targets: Array[Dictionary] = reward_targets("rest")
	var meditation_targets: Array[Dictionary] = reward_targets("meditation")
	var rest_card := reward_option_card("rest", reward_type == "rest", not rest_targets.is_empty())
	rest_card.pressed.connect(show_reward.bind("rest", ""))
	options.add_child(rest_card)
	var meditation_card := reward_option_card("meditation", reward_type == "meditation", not meditation_targets.is_empty())
	meditation_card.pressed.connect(show_reward.bind("meditation", ""))
	options.add_child(meditation_card)
	if not reward_type.is_empty():
		var targets: Array[Dictionary] = rest_targets if reward_type == "rest" else meditation_targets
		var target_heading := label("HERÓIS ELEGÍVEIS", 11, GOLD)
		body.add_child(target_heading)
		if targets.is_empty():
			body.add_child(label("Nenhum herói vivo precisa deste recurso agora. Escolha a outra recompensa.", 12, MUTED))
		else:
			var target_row := HFlowContainer.new()
			target_row.name = "RewardEligibleHeroes"
			target_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			target_row.alignment = FlowContainer.ALIGNMENT_CENTER
			target_row.add_theme_constant_override("h_separation", 10)
			target_row.add_theme_constant_override("v_separation", 7)
			body.add_child(target_row)
			for hero in targets:
				var target_card := reward_target_card(hero, reward_type, hero["id"] == hero_id)
				target_card.pressed.connect(show_reward.bind(reward_type, hero["id"]))
				target_row.add_child(target_card)
		body.add_child(reward_effect_preview(reward_type, hero_id, targets))
	else:
		var prompt := PanelContainer.new()
		prompt.add_theme_stylebox_override("panel", style(Color("14212a")))
		body.add_child(prompt)
		prompt.add_child(label("Selecione Descanso ou Meditação para ver os heróis elegíveis e a prévia do benefício.", 12, MUTED))
	if rest_targets.is_empty() and meditation_targets.is_empty():
		var no_targets := PanelContainer.new()
		no_targets.add_theme_stylebox_override("panel", reward_frame_style(Color("829ba7"), false, true))
		body.add_child(no_targets)
		no_targets.add_child(label("✦  Todos os heróis vivos estão com PV e mana completos.", 12, MUTED))
	var confirm := button("Confirmar Recompensa", "Aplicar benefício ao herói selecionado", GOLD)
	confirm.name = "ConfirmReward"
	confirm.custom_minimum_size.y = 58
	confirm.add_theme_font_size_override("font_size", 17)
	combat_button_style(confirm, GOLD)
	var selected_is_eligible: bool = false
	for eligible_hero in reward_targets(reward_type):
		if eligible_hero["id"] == hero_id:
			selected_is_eligible = true
	confirm.disabled = not selected_is_eligible
	confirm.pressed.connect(pick_reward.bind(reward_type, hero_id))
	root.add_child(confirm)
	if rest_targets.is_empty() and meditation_targets.is_empty():
		var skip := button("Continuar sem recompensa", "Nenhum alvo elegível", WHITE)
		skip.name = "SkipReward"
		skip.custom_minimum_size.y = 42
		skip.pressed.connect(pick_reward.bind("skip", ""))
		root.add_child(skip)
	footer(root)


func reward_targets(reward_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hero in run.attempt["heroes"]:
		if hero["state"] != "alive" or int(hero["hp"]) <= 0:
			continue
		var eligible: bool = (reward_type == "rest" and int(hero["hp"]) < int(hero["max_hp"])) or (reward_type == "meditation" and int(hero.get("mana_max", 0)) > 0 and int(hero["mana"]) < int(hero["mana_max"]))
		if eligible:
			result.append(hero)
	return result


func reward_option_card(reward_type: String, selected_reward: bool, available: bool) -> Button:
	var is_rest: bool = reward_type == "rest"
	var accent: Color = GREEN if is_rest else Color("a996e2")
	var recovery_text: String
	if is_rest:
		recovery_text = "Recupera até %d PV" % RunState.REST_HEAL_AMOUNT
	else:
		recovery_text = "Recupera até %d mana" % RunState.MEDITATION_MANA_AMOUNT
	var choice := reward_choice_button(accent, 145, selected_reward)
	choice.name = "RewardOption_%s" % reward_type
	choice.disabled = not available
	choice.tooltip_text = recovery_text
	var padding := MarginContainer.new()
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		padding.add_theme_constant_override("margin_%s" % edge, 13)
	for edge in ["top", "bottom"]:
		padding.add_theme_constant_override("margin_%s" % edge, 11)
	choice.add_child(padding)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	padding.add_child(row)
	var art := CenterContainer.new()
	art.custom_minimum_size.x = 66
	row.add_child(art)
	var icon_id: String = "cura" if is_rest else "raio_arcano"
	var icon := reward_icon(CombatIcons.texture_for(icon_id), 58)
	icon.modulate = accent
	art.add_child(icon)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	row.add_child(details)
	details.add_child(label("DESCANSO" if is_rest else "MEDITAÇÃO", 16, accent))
	details.add_child(label(recovery_text, 12, WHITE))
	var count: int = reward_targets(reward_type).size()
	details.add_child(label("%d herói(s) elegível(is)" % count if available else "Sem alvos elegíveis", 10, MUTED))
	details.add_child(label("SELECIONADO" if selected_reward else "ESCOLHER", 9, GOLD if selected_reward else MUTED))
	_set_mouse_pass_recursive(padding)
	return choice


func reward_target_card(hero: Dictionary, reward_type: String, is_selected: bool) -> Button:
	var accent: Color = GREEN if reward_type == "rest" else Color("a996e2")
	var choice := reward_choice_button(accent, 112, is_selected)
	choice.name = "RewardTarget_%s" % hero["id"]
	choice.custom_minimum_size.x = 320
	choice.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var padding := MarginContainer.new()
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		padding.add_theme_constant_override("margin_%s" % edge, 9)
	for edge in ["top", "bottom"]:
		padding.add_theme_constant_override("margin_%s" % edge, 8)
	choice.add_child(padding)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	padding.add_child(row)
	row.add_child(reward_icon(CombatSprites.texture_for(hero["id"]), 58))
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	details.add_child(label(hero["name"], 12, WHITE))
	details.add_child(label("%d/%d PV" % [hero["hp"], hero["max_hp"]], 10, GREEN))
	if int(hero.get("mana_max", 0)) > 0:
		details.add_child(label("%d/%d mana" % [hero["mana"], hero["mana_max"]], 10, Color("b9a9ec")))
	details.add_child(label("SELECIONADO" if is_selected else "VIVO · ESCOLHER", 8, GOLD if is_selected else MUTED))
	_set_mouse_pass_recursive(padding)
	return choice


func reward_effect_preview(reward_type: String, hero_id: String, targets: Array[Dictionary]) -> PanelContainer:
	var accent: Color = GREEN if reward_type == "rest" else Color("a996e2")
	var preview := PanelContainer.new()
	preview.name = "RewardEffectPreview"
	preview.add_theme_stylebox_override("panel", reward_frame_style(accent, false, true))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	preview.add_child(content)
	content.add_child(label("PRÉVIA DO BENEFÍCIO", 9, accent))
	var selected_hero: Dictionary = {}
	for hero in targets:
		if hero["id"] == hero_id:
			selected_hero = hero
			break
	if selected_hero.is_empty():
		content.add_child(label("Escolha um herói acima para ver quanto ele recuperará.", 11, MUTED))
	else:
		if reward_type == "rest":
			var recovered: int = mini(RunState.REST_HEAL_AMOUNT, int(selected_hero["max_hp"]) - int(selected_hero["hp"]))
			content.add_child(label("%s: %d/%d PV  →  %d/%d PV  (+%d PV)" % [selected_hero["name"], selected_hero["hp"], selected_hero["max_hp"], int(selected_hero["hp"]) + recovered, selected_hero["max_hp"], recovered], 13, WHITE))
		else:
			var recovered: int = mini(RunState.MEDITATION_MANA_AMOUNT, int(selected_hero["mana_max"]) - int(selected_hero["mana"]))
			content.add_child(label("%s: %d/%d mana  →  %d/%d mana  (+%d mana)" % [selected_hero["name"], selected_hero["mana"], selected_hero["mana_max"], int(selected_hero["mana"]) + recovered, selected_hero["mana_max"], recovered], 13, WHITE))
	return preview


func pick_reward(reward_type: String, hero_id: String) -> void:
	if not run.choose_reward(reward_type, hero_id).is_empty():
		audio_manager.play("confirm")
		show_phase()


func show_relics(chosen_id: String = "") -> void:
	music_manager.play_default()
	var root := page()
	root.add_theme_constant_override("separation", 12)
	var choosing_bearer: bool = not chosen_id.is_empty()
	reward_header(root, "ESCOLHA O PORTADOR" if choosing_bearer else "RELÍQUIA ESPECIAL", "TESOURO DA TORRE · ANDAR %d" % run.attempt["completed"], "Quem receberá %s?" % Relics.DEFINITIONS[chosen_id]["name"] if choosing_bearer else "Escolha uma relíquia para esta tentativa.")
	if run.attempt.has("last_reward"):
		root.add_child(label(run.attempt["last_reward"], 12, GREEN))
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	if not choosing_bearer:
		var scroll := reward_scroll(root)
		scroll.add_child(content)
		content.add_child(label("◆   RELÍQUIAS ENCONTRADAS   ◆", 11, GOLD))
		var options := HBoxContainer.new()
		options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		options.add_theme_constant_override("separation", 16)
		content.add_child(options)
		for relic_id in run.attempt["relic_options"]:
			var choice := relic_reward_choice(relic_id)
			choice.pressed.connect(relic_clicked.bind(relic_id))
			options.add_child(choice)
	else:
		root.add_child(content)
		var definition: Dictionary = Relics.DEFINITIONS[chosen_id]
		var preview := panel()
		preview.add_theme_stylebox_override("panel", reward_frame_style(GOLD, false, true))
		content.add_child(preview)
		var preview_row := HBoxContainer.new()
		preview_row.add_theme_constant_override("separation", 12)
		preview.add_child(preview_row)
		preview_row.add_child(reward_icon(RewardVisuals.relic_icon(chosen_id), 66))
		var preview_details := VBoxContainer.new()
		preview_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_details.add_theme_constant_override("separation", 3)
		preview_row.add_child(preview_details)
		preview_details.add_child(label(definition["name"], 18, GOLD))
		preview_details.add_child(label(definition["description"], 13, WHITE))
		if definition.has("condition"):
			preview_details.add_child(label(definition["condition"], 11, MUTED))
		content.add_child(label("◆   HERÓIS ELEGÍVEIS   ◆", 11, GOLD))
		var bearers := HBoxContainer.new()
		bearers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bearers.add_theme_constant_override("separation", 14)
		content.add_child(bearers)
		for hero in run.attempt["heroes"]:
			if hero["state"] != "alive" or int(hero["hp"]) <= 0:
				continue
			if definition.get("requires_mana", false) and int(hero.get("mana_max", 0)) == 0:
				continue
			var choice := bearer_reward_choice(hero)
			choice.pressed.connect(pick_relic.bind(chosen_id, hero["id"]))
			bearers.add_child(choice)
		var back := button("Voltar às relíquias", "", MUTED)
		back.custom_minimum_size.y = 44
		back.pressed.connect(show_relics)
		root.add_child(back)
	footer(root)


func relic_reward_choice(relic_id: String) -> Button:
	var definition: Dictionary = Relics.DEFINITIONS[relic_id]
	var choice := reward_choice_button(GOLD, 350)
	choice.name = "RelicChoice_%s" % relic_id
	choice.tooltip_text = definition["description"]
	if definition.has("condition"):
		choice.tooltip_text += "\n%s" % definition["condition"]
	var padding := MarginContainer.new()
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		padding.add_theme_constant_override("margin_%s" % edge, 16)
	for edge in ["top", "bottom"]:
		padding.add_theme_constant_override("margin_%s" % edge, 14)
	choice.add_child(padding)
	var contents := VBoxContainer.new()
	padding.add_child(contents)
	contents.add_theme_constant_override("separation", 10)
	var scope_text: String = "BÔNUS DE GRUPO" if definition.get("scope", "hero") == "team" else "BÔNUS INDIVIDUAL"
	contents.add_child(label("✦   %s   ✦" % scope_text, 10, GOLD))
	var art := CenterContainer.new()
	art.custom_minimum_size.y = 136
	contents.add_child(art)
	var medallion := panel()
	var medallion_style := reward_frame_style(GOLD, false, true)
	medallion_style.content_margin_left = 20
	medallion_style.content_margin_right = 20
	medallion_style.content_margin_top = 14
	medallion_style.content_margin_bottom = 14
	medallion.add_theme_stylebox_override("panel", medallion_style)
	art.add_child(medallion)
	medallion.add_child(reward_icon(RewardVisuals.relic_icon(relic_id), 92))
	contents.add_child(HSeparator.new())
	var title := label(definition["name"], 20, WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(title)
	var effect := label(definition["description"], 14, WHITE)
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.add_child(effect)
	var trigger: String = "ATIVA SOB CONDIÇÃO" if definition.has("condition") else "EFEITO PASSIVO"
	contents.add_child(label("%s  ·  ESCOLHER" % trigger, 10, GOLD))
	_set_mouse_pass_recursive(padding)
	return choice


func bearer_reward_choice(hero: Dictionary) -> Button:
	var choice := reward_choice_button(GOLD, 215)
	choice.name = "RelicBearer_%s" % hero["id"]
	var padding := MarginContainer.new()
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		padding.add_theme_constant_override("margin_%s" % edge, 16)
	for edge in ["top", "bottom"]:
		padding.add_theme_constant_override("margin_%s" % edge, 14)
	choice.add_child(padding)
	var contents := VBoxContainer.new()
	padding.add_child(contents)
	contents.add_theme_constant_override("separation", 8)
	contents.add_child(label("✦  PORTADOR  ✦", 10, GOLD))
	var art := CenterContainer.new()
	art.custom_minimum_size.y = 92
	contents.add_child(art)
	art.add_child(reward_icon(CombatSprites.texture_for(hero["id"]), 82))
	var name_label := label(hero["name"], 17, WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(name_label)
	var status := label("%d/%d PV  ·  %d/%d MANA" % [hero["hp"], hero["max_hp"], hero.get("mana", 0), hero.get("mana_max", 0)], 10, MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	contents.add_child(status)
	_set_mouse_pass_recursive(padding)
	return choice


func relic_clicked(relic_id: String) -> void:
	if Relics.DEFINITIONS[relic_id].get("bearer", false):
		show_relics(relic_id)
	else:
		pick_relic(relic_id, "")


func pick_relic(relic_id: String, bearer_id: String) -> void:
	if run.choose_relic(relic_id, bearer_id):
		audio_manager.play("relic")
		show_phase()


func show_routes() -> void:
	music_manager.play_default()
	var root := page()
	root.add_theme_constant_override("separation", 12)
	var completed: int = int(run.attempt["completed"])
	reward_header(root, "MAPA DA TORRE", "ANDAR %d / %d CONCLUÍDO" % [completed, Tower.MAX_FLOOR], "Escolha o caminho para o andar %d." % (completed + 1))
	if run.attempt.has("last_reward"):
		root.add_child(label(run.attempt["last_reward"], 12, GREEN))
	var stage := HBoxContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation", 14)
	root.add_child(stage)
	var map_frame := panel()
	map_frame.name = "TowerMapFrame"
	map_frame.add_theme_stylebox_override("panel", reward_frame_style(Color("809fad"), false, true))
	map_frame.custom_minimum_size.x = 600
	map_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_frame.size_flags_stretch_ratio = 2.0
	stage.add_child(map_frame)
	route_map = TowerRouteMap.new()
	route_map.name = "TowerRouteMap"
	route_map.custom_minimum_size = Vector2(560, 470)
	route_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_frame.add_child(route_map)
	route_map.configure(completed, run.attempt.get("route_history", {}))
	route_map.hovered.connect(_route_hovered)
	route_map.pinned.connect(_route_pinned)
	var info_frame := panel()
	info_frame.name = "TowerRouteInfo"
	info_frame.add_theme_stylebox_override("panel", reward_frame_style(GOLD, false, true))
	info_frame.custom_minimum_size.x = 314
	info_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_child(info_frame)
	route_info_content = VBoxContainer.new()
	route_info_content.add_theme_constant_override("separation", 10)
	route_info_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_frame.add_child(route_info_content)
	route_pinned_id = ""
	route_hover_id = ""
	refresh_route_info()
	footer(root)


func _route_hovered(node_id: String) -> void:
	route_hover_id = node_id
	if route_pinned_id.is_empty():
		refresh_route_info()


func _route_pinned(node_id: String) -> void:
	route_pinned_id = node_id
	route_map.set_pinned(node_id)
	refresh_route_info()


func close_route_info() -> void:
	route_pinned_id = ""
	route_map.set_pinned("")
	refresh_route_info()


func refresh_route_info() -> void:
	if route_info_content == null or not is_instance_valid(route_info_content):
		return
	for child in route_info_content.get_children():
		route_info_content.remove_child(child)
		child.queue_free()
	var inspected: String = route_pinned_id if not route_pinned_id.is_empty() else route_hover_id
	var completed: int = int(run.attempt["completed"])
	if inspected.is_empty():
		route_info_content.add_child(label("PRÓXIMA SUBIDA", 11, GOLD))
		route_info_content.add_child(label("Andar %d" % (completed + 1), 25, WHITE))
		route_info_content.add_child(HSeparator.new())
		route_info_content.add_child(label("Passe o mouse sobre um nó iluminado para conhecer o caminho.", 14, WHITE))
		route_info_content.add_child(label("Clique no nó para fixar os detalhes. A viagem só começa ao selecionar.", 12, MUTED))
		for route in Tower.route_after(completed):
			route_info_content.add_child(label("◆ %s" % route["name"], 13, GOLD))
	else:
		var floor_number: int = completed + 1
		var route: Dictionary = {}
		if inspected.begins_with("floor:"):
			floor_number = int(inspected.trim_prefix("floor:"))
		else:
			route = Tower.route_by_id(inspected)
			for previous_floor in Tower.ROUTES:
				for option in Tower.ROUTES[previous_floor]:
					if option["id"] == inspected:
						floor_number = int(previous_floor) + 1
		var available: bool = floor_number == completed + 1 and not route.is_empty()
		route_info_content.add_child(label("OPÇÃO DISPONÍVEL" if available else "CAMINHO PERCORRIDO", 11, GOLD if available else GREEN))
		route_info_content.add_child(label(route.get("name", "Andar %d" % floor_number), 24, WHITE))
		route_info_content.add_child(label("ANDAR %d / %d  ·  %s" % [floor_number, Tower.MAX_FLOOR, "CHEFE" if floor_number == Tower.MAX_FLOOR else "COMBATE"], 11, MUTED))
		route_info_content.add_child(HSeparator.new())
		if not route.is_empty():
			route_info_content.add_child(label(route["description"], 14, WHITE))
		else:
			route_info_content.add_child(label("Batalha concluída neste andar.", 14, WHITE))
		if available:
			var enemies: Array[Dictionary] = Tower.enemies_for(floor_number, inspected, run.attempt["hero_ids"].size())
			route_info_content.add_child(label("ENCONTRO PREVISTO", 11, GOLD))
			for enemy in enemies:
				route_info_content.add_child(label("◆ %s  ·  %d PV  ·  %d dano" % [enemy["name"], enemy["max_hp"], enemy["damage"]], 12, WHITE))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	route_info_content.add_child(spacer)
	if not route_pinned_id.is_empty():
		var select := button("Selecionar", "Confirmar rota", GOLD)
		select.name = "RouteConfirm"
		select.custom_minimum_size.y = 56
		select.pressed.connect(pick_route.bind(route_pinned_id))
		route_info_content.add_child(select)
		var close := button("Fechar", "Continuar vendo o mapa", MUTED)
		close.name = "RouteCancel"
		close.custom_minimum_size.y = 48
		close.pressed.connect(close_route_info)
		route_info_content.add_child(close)
	else:
		route_info_content.add_child(label("● Concluído   ◉ Disponível   ○ Oculto", 11, MUTED))


func pick_route(route_id: String) -> void:
	if run.choose_route(route_id):
		audio_manager.play("route")
		show_phase()


func show_between() -> void:
	music_manager.play_default()
	var root := page()
	root.add_theme_constant_override("separation", 10)
	var next_floor: int = int(run.attempt["completed"]) + 1
	var route: Dictionary = Tower.route_by_id(run.attempt.get("pending_route", ""))
	var header := panel()
	header.name = "NextFloorHeader"
	header.add_theme_stylebox_override("panel", reward_frame_style(GOLD, false, true))
	header.custom_minimum_size.y = 94
	root.add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 14)
	header.add_child(header_row)
	var title_column := VBoxContainer.new()
	title_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_column.add_theme_constant_override("separation", 2)
	header_row.add_child(title_column)
	title_column.add_child(label("BRIEFING DA TENTATIVA", 10, GOLD))
	title_column.add_child(label("Próximo Andar: %d / %d" % [next_floor, Tower.MAX_FLOOR], 26, WHITE))
	title_column.add_child(label("Tentativa salva · PV e mana serão mantidos", 12, MUTED))
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 7)
	header_row.add_child(metrics)
	metrics.add_child(between_metric("NÍVEL", str(run.attempt["level"])))
	metrics.add_child(between_metric("XP", "%d / 100" % run.attempt["xp"]))
	metrics.add_child(between_metric("CONCLUÍDOS", "%d" % run.attempt["completed"]))
	var body_scroll := ScrollContainer.new()
	body_scroll.name = "BetweenBriefingScroll"
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(body_scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 9)
	body_scroll.add_child(body)
	if run.attempt.has("last_reward"):
		var notice := PanelContainer.new()
		notice.name = "AttemptLastBenefit"
		notice.add_theme_stylebox_override("panel", reward_frame_style(GREEN, false, true))
		body.add_child(notice)
		notice.add_child(label("✦  %s" % run.attempt["last_reward"], 12, GREEN))
	body.add_child(between_route_card(route, next_floor))
	var party_heading := HBoxContainer.new()
	party_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(party_heading)
	var party_title := label("GRUPO PARA O PRÓXIMO ANDAR", 11, GOLD)
	party_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	party_heading.add_child(party_title)
	var preserved := label("Recursos atuais preservados", 10, MUTED)
	preserved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preserved.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	party_heading.add_child(preserved)
	var party := HFlowContainer.new()
	party.name = "BriefingParty"
	party.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party.add_theme_constant_override("h_separation", 10)
	party.add_theme_constant_override("v_separation", 8)
	body.add_child(party)
	for hero in run.attempt["heroes"]:
		party.add_child(between_hero_card(hero))
	body.add_child(between_relics_panel())
	var next := button("Iniciar andar %d" % next_floor)
	next.name = "BeginNextFloor"
	next.custom_minimum_size.y = 62
	next.add_theme_font_size_override("font_size", 18)
	next.add_theme_color_override("font_color", GOLD)
	combat_button_style(next, GOLD)
	next.pressed.connect(begin_next_floor)
	root.add_child(next)
	footer(root)


func between_metric(caption: String, value: String) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(83, 58)
	box.add_theme_stylebox_override("panel", reward_frame_style(Color("829ba7"), false, true))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	box.add_child(column)
	var top := label(caption, 8, MUTED)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(top)
	var data := label(value, 14, GOLD)
	data.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(data)
	return box


func between_route_card(route: Dictionary, floor_number: int) -> PanelContainer:
	var accent: Color = Color("91adbb")
	if not route.is_empty():
		var route_id: String = route.get("id", "")
		accent = Color("d5856e") if route_id in ["arena_sangrenta", "emboscada", "furia"] else (Color("9f91d2") if route_id == "escudo_arcano" else Color("82b8d2"))
	var card := PanelContainer.new()
	card.name = "ChosenRouteCard"
	card.add_theme_stylebox_override("panel", reward_frame_style(accent, false, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var icon_label := label("◆", 28, accent)
	icon_label.custom_minimum_size.x = 38
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon_label)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 3)
	row.add_child(details)
	if route.is_empty():
		details.add_child(label("PRÓXIMO ENCONTRO", 9, accent))
		details.add_child(label("Andar %d · %s" % [floor_number, "Chefe" if floor_number == Tower.MAX_FLOOR else "Combate"], 17, WHITE))
		details.add_child(label("Encontro padrão da torre", 11, MUTED))
	else:
		details.add_child(label("ROTA ESCOLHIDA  ·  ANDAR %d" % floor_number, 9, accent))
		details.add_child(label(route["name"], 19, WHITE))
		details.add_child(label(route["description"], 11, MUTED))
	var encounter := VBoxContainer.new()
	encounter.custom_minimum_size.x = 270
	encounter.add_theme_constant_override("separation", 2)
	row.add_child(encounter)
	encounter.add_child(label("%s PREVISTO" % ("CHEFE" if floor_number == Tower.MAX_FLOOR else "INIMIGOS"), 9, accent))
	var route_id_for_floor: String = str(route.get("id", ""))
	var enemies: Array[Dictionary] = Tower.enemies_for(floor_number, route_id_for_floor, run.attempt["hero_ids"].size())
	for enemy in enemies:
		encounter.add_child(label("%s · %d PV · %d dano" % [enemy["name"], enemy["max_hp"], enemy["damage"]], 10, WHITE))
	return card


func between_hero_card(hero: Dictionary) -> PanelContainer:
	var is_alive: bool = hero.get("state", "alive") == "alive" and int(hero["hp"]) > 0
	var accent: Color = Color("77c58a") if is_alive else RED
	var card := PanelContainer.new()
	card.name = "BriefingHero_%s" % hero["id"]
	card.custom_minimum_size = Vector2(295, 222)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override("panel", reward_frame_style(accent, false, true))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 8)
	content.add_child(identity)
	identity.add_child(reward_icon(CombatSprites.texture_for(hero["id"]), 62))
	var name_column := VBoxContainer.new()
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_column.add_theme_constant_override("separation", 1)
	identity.add_child(name_column)
	name_column.add_child(label(hero["name"], 17, WHITE))
	name_column.add_child(label("PRONTO" if is_alive else ("CAÍDO" if hero.get("state", "") == "downed" else "DERROTADO"), 9, accent))
	var hp_label := label("%d / %d PV" % [hero["hp"], hero["max_hp"]], 11, WHITE)
	content.add_child(hp_label)
	var hp_bar := ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size.y = 8
	hp_bar.max_value = maxi(1, int(hero["max_hp"]))
	hp_bar.value = clampi(int(hero["hp"]), 0, int(hero["max_hp"]))
	hp_bar.add_theme_stylebox_override("background", bar_style(Color("34434b")))
	hp_bar.add_theme_stylebox_override("fill", bar_style(accent))
	content.add_child(hp_bar)
	if int(hero.get("mana_max", 0)) > 0:
		content.add_child(label("%d / %d mana" % [hero["mana"], hero["mana_max"]], 10, Color("a996e2")))
	else:
		content.add_child(label("Sem mana", 10, MUTED))
	var cards: HFlowContainer = HFlowContainer.new()
	cards.add_theme_constant_override("h_separation", 4)
	cards.add_theme_constant_override("v_separation", 3)
	content.add_child(cards)
	var owned: Dictionary = hero.get("cards", {})
	if owned.is_empty():
		var no_cards := label("Sem cartas ativas", 9, MUTED)
		no_cards.custom_minimum_size.x = 125
		no_cards.autowrap_mode = TextServer.AUTOWRAP_OFF
		cards.add_child(no_cards)
	else:
		for card_id in owned:
			var card_def: Dictionary = Cards.DEFINITIONS.get(card_id, {})
			if card_def.is_empty():
				continue
			var visual: Dictionary = RewardVisuals.card_theme(card_id)
			var chip := PanelContainer.new()
			var chip_style := style(Color(visual["color"].r * 0.16, visual["color"].g * 0.16, visual["color"].b * 0.16, 1.0))
			chip_style.set_corner_radius_all(3)
			chip_style.border_color = visual["color"].darkened(0.2)
			chip_style.set_border_width_all(1)
			chip.add_theme_stylebox_override("panel", chip_style)
			cards.add_child(chip)
			var chip_row := HBoxContainer.new()
			chip_row.add_theme_constant_override("separation", 3)
			chip.add_child(chip_row)
			var icon := reward_icon(CombatIcons.texture_for(visual["icon"]), 16)
			icon.modulate = visual["color"]
			chip_row.add_child(icon)
			var level_text: String = ["I", "II", "III"][int(owned[card_id]) - 1]
			var chip_label := label("%s %s" % [card_def["name"], level_text], 8, WHITE)
			chip_label.custom_minimum_size.x = 76
			chip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			chip_label.clip_text = true
			chip_label.tooltip_text = Cards.label(card_id, int(owned[card_id]))
			if not card_def.get("condition", "").is_empty():
				chip_label.tooltip_text += "\n%s" % card_def["condition"]
			chip_row.add_child(chip_label)
	_set_mouse_pass_recursive(content)
	return card


func between_relics_panel() -> PanelContainer:
	var box := PanelContainer.new()
	box.name = "AttemptRelics"
	box.add_theme_stylebox_override("panel", reward_frame_style(GOLD, false, true))
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	box.add_child(content)
	content.add_child(label("RELÍQUIAS DA TENTATIVA", 10, GOLD))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 5)
	content.add_child(row)
	if run.attempt["relics"].is_empty():
		var empty := PanelContainer.new()
		empty.custom_minimum_size.x = 300
		empty.add_theme_stylebox_override("panel", style(Color("14212a")))
		row.add_child(empty)
		var empty_label := label("◇  Nenhuma relíquia encontrada até agora", 11, MUTED)
		empty_label.custom_minimum_size.x = 270
		empty_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		empty.add_child(empty_label)
	else:
		for relic in run.attempt["relics"]:
			var relic_id: String = relic["id"]
			var definition: Dictionary = Relics.DEFINITIONS[relic_id]
			var chip := PanelContainer.new()
			chip.custom_minimum_size.x = 250
			chip.tooltip_text = definition["description"]
			chip.add_theme_stylebox_override("panel", style(Color("26323a")))
			row.add_child(chip)
			var relic_row := HBoxContainer.new()
			relic_row.add_theme_constant_override("separation", 6)
			chip.add_child(relic_row)
			relic_row.add_child(reward_icon(RewardVisuals.relic_icon(relic_id), 36))
			var details := VBoxContainer.new()
			details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			details.add_theme_constant_override("separation", 1)
			relic_row.add_child(details)
			details.add_child(label(definition["name"], 11, WHITE))
			var bearer_name: String = "Grupo" if definition.get("scope", "hero") == "team" else "Portador: %s" % Heroes.DEFINITIONS.get(relic.get("bearer", ""), {}).get("name", "—")
			details.add_child(label(bearer_name, 9, MUTED))
			_set_mouse_pass_recursive(relic_row)
	return box


func begin_next_floor() -> void:
	if run.begin_floor():
		_enter_story_or_combat()


func show_summary(summary: Dictionary) -> void:
	music_manager.play_default()
	if summary.is_empty():
		menu()
		return
	var root := page()
	root.add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.name = "OutcomeScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 11)
	scroll.add_child(content)
	var completed: int = int(summary.get("completed", 0))
	var reached: int = clampi(int(summary.get("floor_reached", summary.get("floor", completed))), 0, Tower.MAX_FLOOR)
	var won: bool = bool(summary.get("won", summary.get("result", "") == "Vitória"))
	var new_record: bool = bool(summary.get("new_record", false))
	var dev_preview: bool = bool(summary.get("dev_preview", false))
	var accent: Color = GOLD if won or new_record else Color("83cbd1")
	var hero_panel := PanelContainer.new()
	hero_panel.name = "AttemptOutcome"
	hero_panel.custom_minimum_size.y = 160
	hero_panel.add_theme_stylebox_override("panel", reward_frame_style(accent, false, true))
	content.add_child(hero_panel)
	var outcome := VBoxContainer.new()
	outcome.alignment = BoxContainer.ALIGNMENT_CENTER
	outcome.add_theme_constant_override("separation", 5)
	hero_panel.add_child(outcome)
	var badge_text: String = "RESULTADO DE TESTE · SEM RECOMPENSAS" if dev_preview else ("JORNADA COMPLETA · NOVO RECORDE" if won and new_record else ("JORNADA COMPLETA" if won else ("NOVO RECORDE PESSOAL" if new_record else "FIM DESTA EXPEDIÇÃO")))
	var badge := label("✦   %s   ✦" % badge_text, 11, accent)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome.add_child(badge)
	var title_text: String = ("Vitória de teste" if won else "Derrota de teste") if dev_preview else ("Torre concluída!" if won else ("Novo recorde de andar!" if new_record else "Você chegou ao andar %d" % reached))
	var title := label(title_text, 31, WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome.add_child(title)
	var subtitle_text: String
	if dev_preview:
		subtitle_text = "Prévia do resultado: esta ação não altera XP, moedas ou recordes."
	elif won:
		subtitle_text = "Sua equipe venceu os dez andares da torre."
	elif new_record and int(summary.get("previous_best_floor", 0)) > 0:
		subtitle_text = "Você superou sua melhor marca anterior: andar %d." % summary["previous_best_floor"]
	elif new_record:
		subtitle_text = "Sua primeira marca ficou registrada. Cada subida conta."
	else:
		subtitle_text = "A jornada continua. O progresso conquistado segue com você."
	var subtitle := label(subtitle_text, 13, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome.add_child(subtitle)
	var progress_panel := PanelContainer.new()
	progress_panel.name = "TowerRunProgress"
	progress_panel.add_theme_stylebox_override("panel", reward_frame_style(Color("83aeba"), false, true))
	content.add_child(progress_panel)
	var progress_content := VBoxContainer.new()
	progress_content.add_theme_constant_override("separation", 5)
	progress_panel.add_child(progress_content)
	var progress_title := label("SUA SUBIDA PELA TORRE", 10, GOLD)
	progress_content.add_child(progress_title)
	var floor_bar := ProgressBar.new()
	floor_bar.name = "ReachedFloorProgress"
	floor_bar.show_percentage = false
	floor_bar.custom_minimum_size.y = 12
	floor_bar.max_value = Tower.MAX_FLOOR
	floor_bar.value = reached
	floor_bar.add_theme_stylebox_override("background", bar_style(Color("34434b")))
	floor_bar.add_theme_stylebox_override("fill", bar_style(accent))
	progress_content.add_child(floor_bar)
	var metrics := HBoxContainer.new()
	metrics.add_theme_constant_override("separation", 7)
	progress_content.add_child(metrics)
	var reached_metric := between_metric("ANDAR ALCANÇADO", "%d / %d" % [reached, Tower.MAX_FLOOR])
	reached_metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics.add_child(reached_metric)
	var completed_metric := between_metric("ANDARES CONCLUÍDOS", "%d" % completed)
	completed_metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics.add_child(completed_metric)
	var best_metric := between_metric("MELHOR MARCA", "%d / %d" % [int(run.permanent["stats"].get("best_floor_reached", reached)), Tower.MAX_FLOOR])
	best_metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics.add_child(best_metric)
	var party_title := label("EQUIPE DESTA JORNADA", 10, GOLD)
	content.add_child(party_title)
	var party := HFlowContainer.new()
	party.name = "OutcomeParty"
	party.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party.alignment = FlowContainer.ALIGNMENT_CENTER
	party.add_theme_constant_override("h_separation", 10)
	party.add_theme_constant_override("v_separation", 7)
	content.add_child(party)
	for hero_id in summary.get("classes", []):
		party.add_child(outcome_hero_card(str(hero_id)))
	var rewards := HBoxContainer.new()
	rewards.add_theme_constant_override("separation", 10)
	content.add_child(rewards)
	rewards.add_child(outcome_reward_card("XP PERMANENTE", "+%d por classe" % int(summary.get("xp_per_class", 0)), "✦", Color("9d8bd2")))
	rewards.add_child(outcome_reward_card("MOEDAS RECEBIDAS", "+%d  ·  saldo %d" % [int(summary.get("coins", 0)), int(run.permanent.get("coins", 0))], "◈", GOLD))
	var actions := HBoxContainer.new()
	actions.name = "OutcomeActions"
	actions.add_theme_constant_override("separation", 9)
	root.add_child(actions)
	var again := button("Nova tentativa", "Escolher equipe e subir novamente", GOLD)
	again.name = "OutcomeNewAttempt"
	again.custom_minimum_size.y = 58
	again.add_theme_font_size_override("font_size", 16)
	combat_button_style(again, GOLD)
	again.pressed.connect(request_outcome_destination.bind("new_attempt", dev_preview))
	actions.add_child(again)
	var progression := button("Progressão", "Ver XP e melhorias permanentes", WHITE)
	progression.name = "OutcomeProgression"
	progression.custom_minimum_size.y = 58
	progression.pressed.connect(request_outcome_destination.bind("progression", dev_preview))
	actions.add_child(progression)
	var back := button("Menu", "Voltar ao menu principal", WHITE)
	back.name = "OutcomeMenu"
	back.custom_minimum_size.y = 58
	back.pressed.connect(request_outcome_destination.bind("menu", dev_preview))
	actions.add_child(back)


func outcome_hero_card(hero_id: String) -> PanelContainer:
	var definition: Dictionary = Heroes.get_definition(hero_id)
	var progression: Dictionary = run.permanent.get("classes", {}).get(hero_id, {})
	var card := PanelContainer.new()
	card.name = "OutcomeHero_%s" % hero_id
	card.custom_minimum_size = Vector2(210, 92)
	card.add_theme_stylebox_override("panel", reward_frame_style(Color("82b8d2"), false, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	row.add_child(reward_icon(CombatSprites.texture_for(hero_id), 54))
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	details.add_child(label(definition["name"], 13, WHITE))
	details.add_child(label("Nível permanente %d" % int(progression.get("level", 1)), 9, MUTED))
	details.add_child(label("XP desta jornada +%d" % int(run.permanent.get("classes", {}).get(hero_id, {}).get("history", []).back().get("xp", 0)) if not run.permanent.get("classes", {}).get(hero_id, {}).get("history", []).is_empty() else "XP desta jornada +0", 9, GOLD))
	return card


func outcome_reward_card(caption: String, value: String, symbol: String, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 74
	card.add_theme_stylebox_override("panel", reward_frame_style(accent, false, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	var icon := label(symbol, 28, accent)
	icon.custom_minimum_size.x = 42
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(icon)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	details.add_child(label(caption, 9, accent))
	details.add_child(label(value, 14, WHITE))
	return card
