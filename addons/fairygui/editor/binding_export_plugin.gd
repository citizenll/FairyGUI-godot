@tool
extends EditorExportPlugin

const DEFAULT_OUTPUT_DIR := "res://generated/fairygui"
const MANIFEST_FILE := "manifest.json"
const DEFAULT_REGISTRY_FILE := "registry.gd"

var generate_callback: Callable


func _get_name() -> String:
	return "FairyGUIBindings"


func _export_begin(
		_features: PackedStringArray,
		_is_debug: bool,
		_path: String,
		_flags: int
	) -> void:
	if bool(ProjectSettings.get_setting("fairygui/codegen/auto_generate", true)) and generate_callback.is_valid():
		var generation_result: Variant = generate_callback.call()
		if generation_result is Dictionary and not bool(generation_result.get("ok", false)):
			push_error("[FairyGUI codegen] Could not refresh generated bindings before export: %s" % [
				generation_result.get("errors", generation_result.get("reason", "unknown error")),
			])

	var output_dir := str(ProjectSettings.get_setting("fairygui/codegen/output_dir", DEFAULT_OUTPUT_DIR)).trim_suffix("/")
	var manifest_path := "%s/%s" % [output_dir, MANIFEST_FILE]
	if not FileAccess.file_exists(manifest_path):
		return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary:
		push_error("[FairyGUI codegen] Generated binding manifest is invalid: %s" % manifest_path)
		return

	var paths := PackedStringArray()
	var registry_path := str(ProjectSettings.get_setting(
		"fairygui/codegen/registry_path",
		"%s/%s" % [output_dir, DEFAULT_REGISTRY_FILE]
	))
	if registry_path != "":
		paths.append(registry_path)
	for value: Variant in manifest.get("files", []):
		var generated_path := str(value)
		if generated_path != "" and not paths.has(generated_path):
			paths.append(generated_path)
	paths.sort()

	var standard_export_files: Dictionary = {}
	var preset := get_export_preset()
	if preset != null:
		for value: Variant in preset.get_files_to_export():
			standard_export_files[str(value)] = true
	for generated_path: String in paths:
		if not generated_path.begins_with("res://") or not FileAccess.file_exists(generated_path):
			push_error("[FairyGUI codegen] Generated binding is missing during export: %s" % generated_path)
			continue
		if standard_export_files.has(generated_path):
			continue
		add_file(generated_path, FileAccess.get_file_as_bytes(generated_path), false)
