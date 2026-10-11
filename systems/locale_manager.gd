extends Node

signal language_changed(locale: String)

const SETTINGS_PATH := "user://language_preferences.cfg"
const JAPANESE_FONT: Font = preload("res://assets/fonts/NotoSansJP.ttf")
const CHINESE_FONT: Font = preload("res://assets/fonts/NotoSansSC.ttf")
const LANGUAGES := {
	"pt_BR": "Português (Brasil)",
	"en": "English",
	"fr": "Français",
	"ja": "日本語",
	"es": "Español",
	"zh_CN": "简体中文",
}
const ORDER := ["pt_BR", "en", "fr", "ja", "es", "zh_CN"]

var current_locale := "pt_BR"
var _catalogs: Dictionary = {}
var _templates: Array[Dictionary] = []
var _dynamic_cache: Dictionary = {}
func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for locale in ORDER:
		if locale == "pt_BR":
			continue
		var path := "res://locales/%s.json" % locale
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("Catálogo de idioma ausente: %s" % path)
			continue
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("Catálogo de idioma inválido: %s" % path)
			continue
		_catalogs[locale] = parsed
		var translation := Translation.new()
		translation.locale = locale
		for source in parsed:
			translation.add_message(str(source), str(parsed[source]))
		TranslationServer.add_translation(translation)
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved := str(config.get_value("language", "locale", "pt_BR"))
		if saved in ORDER:
			current_locale = saved
	TranslationServer.set_locale(current_locale)
	_build_templates()


func set_language(locale: String) -> void:
	if not locale in ORDER or current_locale == locale:
		return
	current_locale = locale
	TranslationServer.set_locale(locale)
	_build_templates()
	_dynamic_cache.clear()
	_refresh_bound(get_tree().root)
	language_changed.emit(locale)
	var config := ConfigFile.new()
	config.set_value("language", "locale", locale)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("Não foi possível salvar a preferência de idioma.")


func localize(source: String) -> String:
	if current_locale == "pt_BR" or source.is_empty():
		return source
	var catalog: Dictionary = _catalogs.get(current_locale, {})
	if catalog.has(source):
		return str(catalog[source])
	if _dynamic_cache.has(source):
		return str(_dynamic_cache[source])
	if source.contains("\n"):
		var translated_lines: Array[String] = []
		for line in source.split("\n", true):
			translated_lines.append(localize(line))
		var result := "\n".join(translated_lines)
		_dynamic_cache[source] = result
		return result
	for template in _templates:
		var regex: RegEx = template["regex"]
		var match_result := regex.search(source)
		if match_result == null:
			continue
		var values: Array = []
		for group_index in range(1, match_result.get_group_count() + 1):
			var value := match_result.get_string(group_index)
			values.append(localize(value))
		var translated: String = template["translated"]
		var cursor := 0
		for index in range(values.size()):
			var token: String = template["formats"][index]
			var start := translated.find(token, cursor)
			if start < 0:
				return source
			translated = translated.substr(0, start) + values[index] + translated.substr(start + token.length())
			cursor = start + values[index].length()
		translated = translated.replace("%%", "%")
		_dynamic_cache[source] = translated
		return translated
	if source.begins_with("▶ "):
		var selected := "▶ " + localize(source.trim_prefix("▶ "))
		_dynamic_cache[source] = selected
		return selected
	if source.contains(" · "):
		var pieces: Array[String] = []
		for piece in source.split(" · "):
			pieces.append(localize(piece))
		var joined := " · ".join(pieces)
		_dynamic_cache[source] = joined
		return joined
	if source.contains(", "):
		var pieces: Array[String] = []
		for piece in source.split(", "):
			pieces.append(localize(piece))
		var joined := ", ".join(pieces)
		_dynamic_cache[source] = joined
		return joined
	_dynamic_cache[source] = source
	return source


func set_text(control: Control, value: Variant) -> void:
	var source := str(value)
	control.set_meta("locale_source_text", source)
	control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	control.set("text", localize(source))
	_apply_font(control)


func set_tooltip(control: Control, value: Variant) -> void:
	var source := str(value)
	control.set_meta("locale_source_tooltip", source)
	control.tooltip_text = localize(source)


func _refresh_bound(node: Node) -> void:
	if node is Control and node.has_meta("locale_source_text"):
		node.set("text", localize(str(node.get_meta("locale_source_text"))))
	if node is Control and node.has_meta("locale_source_tooltip"):
		node.tooltip_text = localize(str(node.get_meta("locale_source_tooltip")))
	if node is Control:
		_apply_font(node)
	for child in node.get_children():
		_refresh_bound(child)


func _on_node_added(node: Node) -> void:
	if current_locale in ["ja", "zh_CN"] and node is Control:
		call_deferred("_apply_font", node)


func _apply_font(node: Control) -> void:
	if not is_instance_valid(node) or not (node is Label or node is BaseButton or node is RichTextLabel):
		return
	if current_locale in ["ja", "zh_CN"]:
		if not node.has_meta("locale_original_font"):
			node.set_meta("locale_original_font", node.get_theme_font("font") if node.has_theme_font_override("font") else null)
		if node is RichTextLabel and not node.has_meta("locale_original_normal_font"):
			node.set_meta("locale_original_normal_font", node.get_theme_font("normal_font") if node.has_theme_font_override("normal_font") else null)
		var cjk_font: Font = JAPANESE_FONT if current_locale == "ja" else CHINESE_FONT
		node.add_theme_font_override("font", cjk_font)
		if node is RichTextLabel:
			node.add_theme_font_override("normal_font", cjk_font)
	elif node.has_meta("locale_original_font"):
		var original: Font = node.get_meta("locale_original_font")
		if original == null:
			node.remove_theme_font_override("font")
		else:
			node.add_theme_font_override("font", original)
		node.remove_meta("locale_original_font")
		if node is RichTextLabel and node.has_meta("locale_original_normal_font"):
			var original_normal: Font = node.get_meta("locale_original_normal_font")
			if original_normal == null:
				node.remove_theme_font_override("normal_font")
			else:
				node.add_theme_font_override("normal_font", original_normal)
			node.remove_meta("locale_original_normal_font")


func _build_templates() -> void:
	_templates.clear()
	var catalog: Dictionary = _catalogs.get(current_locale, {})
	for source in catalog:
		var original := str(source)
		var token_regex := RegEx.new()
		token_regex.compile("%(?:0?[0-9]*\\.?[0-9]*[dfs])")
		var tokens := token_regex.search_all(original)
		if tokens.is_empty():
			continue
		var pattern := ""
		var formats: Array[String] = []
		var cursor := 0
		for token in tokens:
			pattern += _escape_regex(original.substr(cursor, token.get_start() - cursor).replace("%%", "%"))
			pattern += "(.+?)"
			formats.append(token.get_string())
			cursor = token.get_end()
		pattern += _escape_regex(original.substr(cursor).replace("%%", "%"))
		var compiled := RegEx.new()
		if compiled.compile("^%s$" % pattern) == OK:
			_templates.append({"source": original, "translated": str(catalog[source]), "regex": compiled, "formats": formats})
	_templates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["source"].length() > b["source"].length())


func _escape_regex(value: String) -> String:
	var escaped := value
	for char in ["\\", ".", "^", "$", "*", "+", "?", "(", ")", "[", "]", "{", "}", "|"]:
		escaped = escaped.replace(char, "\\" + char)
	return escaped
