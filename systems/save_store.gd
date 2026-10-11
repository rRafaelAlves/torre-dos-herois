extends RefCounted

const VERSION := 3
const DEFAULT_PATH := "user://torre_v8_state.json"


static func load_data(path: String = DEFAULT_PATH) -> Dictionary:
	var current := _read_payload(path)
	if not current.is_empty():
		return current
	var backup := _read_payload(path + ".bak")
	if not backup.is_empty():
		_write_bytes_atomic(FileAccess.get_file_as_bytes(path + ".bak"), path)
		return backup
	var pending := _read_payload(path + ".tmp")
	if not pending.is_empty():
		_write_bytes_atomic(FileAccess.get_file_as_bytes(path + ".tmp"), path)
		return pending
	var pending_backup := _read_payload(path + ".bak.tmp")
	if not pending_backup.is_empty():
		_write_bytes_atomic(FileAccess.get_file_as_bytes(path + ".bak.tmp"), path)
	return pending_backup


static func _read_payload(path: String) -> Dictionary:
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
	if not typeof(parsed.get("version")) in [TYPE_INT, TYPE_FLOAT] or not int(parsed["version"]) in [1, 2, VERSION] or float(parsed["version"]) != float(int(parsed["version"])):
		return {}
	if typeof(parsed.get("permanent")) != TYPE_DICTIONARY or typeof(parsed.get("attempt")) != TYPE_DICTIONARY:
		return {}
	if parsed.has("checksum"):
		var expected := str(parsed["checksum"])
		var unsigned: Dictionary = parsed.duplicate(true)
		unsigned.erase("checksum")
		if expected != JSON.stringify(unsigned, "", true).sha256_text():
			return {}
	return parsed


static func save_data(permanent: Dictionary, attempt: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var payload := {"version": VERSION, "permanent": permanent, "attempt": attempt}
	var normalized: Dictionary = JSON.parse_string(JSON.stringify(payload, "", true))
	payload["checksum"] = JSON.stringify(normalized, "", true).sha256_text()
	var serialized := JSON.stringify(payload).to_utf8_buffer()
	if FileAccess.file_exists(path) and not _read_payload(path).is_empty():
		if not _write_bytes_atomic(FileAccess.get_file_as_bytes(path), path + ".bak"):
			return false
	return _write_bytes_atomic(serialized, path)


static func write_backup_copy(source_path: String, backup_path: String) -> bool:
	if _read_payload(source_path).is_empty() or FileAccess.file_exists(backup_path):
		return false
	return _write_bytes_atomic(FileAccess.get_file_as_bytes(source_path), backup_path)


static func _write_bytes_atomic(contents: PackedByteArray, path: String) -> bool:
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(contents)
	file.flush()
	file.close()
	if FileAccess.get_file_as_bytes(temporary_path) != contents:
		return false
	var absolute_temp: String = ProjectSettings.globalize_path(temporary_path)
	var absolute_target: String = ProjectSettings.globalize_path(path)
	return DirAccess.rename_absolute(absolute_temp, absolute_target) == OK
