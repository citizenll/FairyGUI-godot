extends SceneTree

const PACKAGE_PATH := "res://examples/assets/ui/Basics.fui"
const OUTPUT_DIR := "res://tests/_generated_fairygui_editor"
const REGISTRY_PATH := OUTPUT_DIR + "/registry.gd"


class InvalidSyntaxGenerator extends FGUIBindingCodeGenerator:
	func _render_component(component: Dictionary) -> String:
		return super._render_component(component) + "\nfunc _invalid_generated_syntax(:\n"


func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("Binding codegen editor probe must run through the Godot editor.")
		return
	_run.call_deferred()


func _run() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	while filesystem != null and (filesystem.is_scanning() or filesystem.is_importing()):
		await process_frame
	_remove_tree(OUTPUT_DIR)
	var paths := PackedStringArray([PACKAGE_PATH])
	var generated := FGUIBindingCodeGenerator.new().generate(
		paths,
		OUTPUT_DIR,
		"EditorProbeUI_",
		false,
		REGISTRY_PATH
	)
	if not bool(generated.get("ok", false)):
		_fail("Editor-mode binding generation failed: %s" % [generated.get("errors", [])])
		return
	var generated_files: PackedStringArray = generated.get("generated_files", PackedStringArray())
	var component_path := ""
	for path: String in generated_files:
		if path.get_extension().to_lower() != "gd":
			continue
		var script := ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE) as Script
		if script == null or script.reload() != OK:
			_fail("Generated editor binding did not reload: %s" % path)
			return
		if path != REGISTRY_PATH and component_path == "":
			component_path = path
	if component_path == "":
		_fail("Editor-mode binding generation did not create a component script.")
		return
	var stable_source := FileAccess.get_file_as_string(component_path)
	var rejected := InvalidSyntaxGenerator.new().generate(
		paths,
		OUTPUT_DIR,
		"EditorProbeUI_",
		false,
		REGISTRY_PATH
	)
	if bool(rejected.get("ok", false)):
		_fail("Editor-mode validation accepted invalid generated syntax.")
		return
	if FileAccess.get_file_as_string(component_path) != stable_source:
		_fail("Invalid editor-mode generation did not restore the previous binding.")
		return
	_remove_tree(OUTPUT_DIR)
	quit(0)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		directory.remove(file_name)
	for directory_name: String in directory.get_directories():
		_remove_tree("%s/%s" % [path, directory_name])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	push_error(message)
	_remove_tree(OUTPUT_DIR)
	quit(1)
