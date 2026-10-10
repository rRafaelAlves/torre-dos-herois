extends RefCounted

# Editor executable only. Export templates, including debug exports, fail this gate.
static func authorized() -> bool:
	return gate(OS.has_feature("editor"), OS.is_debug_build(), OS.has_feature("template"))


static func gate(editor: bool, debug: bool, template: bool) -> bool:
	return editor and debug and not template


static func is_dev_path(path: String) -> bool:
	return authorized() and path.ends_with(".dev")
