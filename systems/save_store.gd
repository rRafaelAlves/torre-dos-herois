extends RefCounted

const VERSION := 2
const DEFAULT_PATH := "user://torre_v8_state.json"


static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return {}
	var parsed: Variant = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if not typeof(parsed.get("version")) in [TYPE_INT, TYPE_FLOAT] or not int(parsed["version"]) in [1, VERSION] or float(parsed["version"]) != float(int(parsed["version"])):
		return {}
	return parsed


static func save_data(permanent: Dictionary, attempt: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var payload := {"version": VERSION, "permanent": permanent, "attempt": attempt}
	var temporary_path: String = path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()
	var absolute_temp: String = ProjectSettings.globalize_path(temporary_path)
	var absolute_target: String = ProjectSettings.globalize_path(path)
	return DirAccess.rename_absolute(absolute_temp, absolute_target) == OK
