extends RefCounted

const SaveStore = preload("res://systems/save_store.gd")
const RunState = preload("res://systems/run_state.gd")
const Heroes = preload("res://data/heroes.gd")
const NarrativeScenes = preload("res://data/narrative_scenes.gd")

const SLOT_COUNT := 3
const SELECTION_PATH := "user://torre_v40_slots.cfg"
const MIGRATION_MARKER := "user://torre_v40_legacy_migrated.flag"

var slot_prefix := "user://torre_save_slot_"
var legacy_path := SaveStore.DEFAULT_PATH
var selection_path := SELECTION_PATH
var migration_marker := MIGRATION_MARKER
var active_slot: int = 0
var migration_error: String = ""


func configure_paths(prefix: String, old_path: String, selected_path: String, marker_path: String) -> void:
	slot_prefix = prefix
	legacy_path = old_path
	selection_path = selected_path
	migration_marker = marker_path


func path_for_slot(slot: int) -> String:
	if slot < 1 or slot > SLOT_COUNT:
		return ""
	return "%s%d.json" % [slot_prefix, slot]


func slot_occupied(slot: int) -> bool:
	var path := path_for_slot(slot)
	return not path.is_empty() and (FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".tmp") or FileAccess.file_exists(path + ".bak.tmp"))


func slot_exists(slot: int) -> bool:
	var path := path_for_slot(slot)
	return not path.is_empty() and not SaveStore.load_data(path).is_empty()


func initialize() -> void:
	var migrated := migrate_legacy()
	var config := ConfigFile.new()
	if config.load(selection_path) == OK:
		var selected := int(config.get_value("slots", "active", 0))
		if slot_exists(selected):
			active_slot = selected
	if active_slot == 0 and migrated and slot_exists(1):
		active_slot = 1
		_save_selection()


func migrate_legacy() -> bool:
	if FileAccess.file_exists(migration_marker) or not (FileAccess.file_exists(legacy_path) or FileAccess.file_exists(legacy_path + ".bak") or FileAccess.file_exists(legacy_path + ".tmp")):
		return false
	if slot_occupied(1):
		if slot_exists(1) and FileAccess.file_exists(legacy_path + ".legacy.bak") and not SaveStore.load_data(legacy_path + ".legacy.bak").is_empty():
			_write_migration_marker()
		elif not slot_exists(1):
			migration_error = "O Espaço 1 contém dados danificados. O salvamento antigo foi preservado."
		return false
	var legacy: Dictionary = SaveStore.load_data(legacy_path)
	if legacy.is_empty():
		migration_error = "O salvamento antigo não pôde ser lido. Ele foi preservado."
		return false
	var old_backup := legacy_path + ".legacy.bak"
	if FileAccess.file_exists(old_backup) and SaveStore.load_data(old_backup).is_empty():
		migration_error = "O backup antigo está danificado. O salvamento original foi preservado."
		return false
	if not FileAccess.file_exists(old_backup) and not SaveStore.write_backup_copy(legacy_path, old_backup):
		migration_error = "Não foi possível criar o backup do salvamento antigo."
		return false
	var staging_path := path_for_slot(1) + ".migration"
	if not SaveStore._write_bytes_atomic(FileAccess.get_file_as_bytes(legacy_path), staging_path):
		migration_error = "Não foi possível preparar a migração do salvamento antigo."
		return false
	var staged := RunState.new()
	staged.initialize(staging_path)
	if legacy_path == SaveStore.DEFAULT_PATH:
		var old_seen := ConfigFile.new()
		if old_seen.load("user://narrative_seen.cfg") == OK and old_seen.has_section("seen"):
			var seen_flags: Dictionary = staged.permanent["narrative"].get("scenes_seen", {})
			for scene_id in old_seen.get_section_keys("seen"):
				if bool(old_seen.get_value("seen", scene_id, false)) and not NarrativeScenes.get_scene(scene_id).is_empty():
					seen_flags[scene_id] = true
			staged.permanent["narrative"]["scenes_seen"] = seen_flags
	if not SaveStore.save_data(staged.permanent, staged.attempt, path_for_slot(1)):
		migration_error = "Não foi possível copiar o salvamento antigo para o Espaço 1."
		return false
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var temporary: String = staging_path + str(suffix)
		if FileAccess.file_exists(temporary):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	if not _write_migration_marker():
		migration_error = "O salvamento foi copiado, mas o registro da migração falhou."
	return true


func create_slot(slot: int) -> bool:
	var path := path_for_slot(slot)
	if path.is_empty() or slot_occupied(slot):
		return false
	var fresh := RunState.new()
	fresh.permanent = fresh._default_permanent()
	fresh.attempt = {}
	fresh.save_path = path
	if not fresh.save():
		return false
	return select_slot(slot)


func select_slot(slot: int) -> bool:
	if not slot_exists(slot):
		return false
	var previous := active_slot
	active_slot = slot
	if _save_selection():
		return true
	active_slot = previous
	return false


func clear_selection() -> bool:
	var previous := active_slot
	active_slot = 0
	if _save_selection():
		return true
	active_slot = previous
	return false


func delete_slot(slot: int) -> bool:
	var path := path_for_slot(slot)
	if path.is_empty() or not slot_occupied(slot):
		return false
	if slot == 1 and FileAccess.file_exists(legacy_path) and not FileAccess.file_exists(migration_marker) and not _write_migration_marker():
		return false
	for suffix in [".bak", "", ".tmp", ".bak.tmp"]:
		var target: String = path + str(suffix)
		if FileAccess.file_exists(target) and DirAccess.remove_absolute(ProjectSettings.globalize_path(target)) != OK:
			return false
	if active_slot == slot:
		active_slot = 0
		_save_selection()
	return true


func summary(slot: int) -> Dictionary:
	var path := path_for_slot(slot)
	if path.is_empty():
		return {"status": "invalid"}
	var data: Dictionary = SaveStore.load_data(path)
	if data.is_empty():
		return {"status": "damaged" if slot_occupied(slot) else "empty"}
	var permanent: Dictionary = data.get("permanent", {})
	var classes: Dictionary = permanent.get("classes", {})
	var highest_level := 1
	for hero_id in Heroes.ORDER:
		var entry: Dictionary = classes.get(hero_id, {}) if typeof(classes.get(hero_id, {})) == TYPE_DICTIONARY else {}
		highest_level = maxi(highest_level, int(entry.get("level", 1)))
	var stats: Dictionary = permanent.get("stats", {})
	var profile: Dictionary = permanent.get("profile", {}) if typeof(permanent.get("profile", {})) == TYPE_DICTIONARY else {}
	var last_saved := int(profile.get("last_saved_at", 0))
	if last_saved <= 0:
		last_saved = int(FileAccess.get_modified_time(path))
	var played: Variant = profile.get("playtime_seconds", 0.0)
	return {
		"status": "saved", "highest_level": highest_level,
		"best_floor": int(stats.get("best_floor_reached", 0)),
		"playtime_seconds": maxf(0.0, float(played)) if typeof(played) in [TYPE_INT, TYPE_FLOAT] else 0.0,
		"last_saved_at": last_saved,
		"has_attempt": typeof(data.get("attempt")) == TYPE_DICTIONARY and not data["attempt"].is_empty()
	}


func _save_selection() -> bool:
	var config := ConfigFile.new()
	config.set_value("slots", "active", active_slot)
	return config.save(selection_path) == OK


func _write_migration_marker() -> bool:
	return SaveStore._write_bytes_atomic("legacy_migrated".to_utf8_buffer(), migration_marker)
