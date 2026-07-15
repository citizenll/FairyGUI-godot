extends SceneTree

const PACKAGE_PATH := "res://examples/assets/ui/VirtualList.fui"
const OUTPUT_DIR := "res://tests/_generated_fairygui_bindings"
const REGISTRY_PATH := OUTPUT_DIR + "/registry.gd"


class RejectingGenerator extends FGUIBindingCodeGenerator:
	func _render_component(component: Dictionary) -> String:
		return super._render_component(component) + "# rejected test output\n"

	func _validate_generated_scripts(_paths: PackedStringArray) -> PackedStringArray:
		return PackedStringArray(["Intentional validation rejection."])


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_remove_tree(OUTPUT_DIR)
	var previous_registry: Variant = ProjectSettings.get_setting("fairygui/codegen/registry_path", null)
	ProjectSettings.set_setting("fairygui/codegen/registry_path", REGISTRY_PATH)

	var generator := FGUIBindingCodeGenerator.new()
	var paths := PackedStringArray([PACKAGE_PATH])
	var first := generator.generate(paths, OUTPUT_DIR, "ProbeUI_", false, REGISTRY_PATH)
	if not bool(first.get("ok", false)):
		_fail("Initial binding generation failed: %s" % [first.get("errors", [])])
		return
	if not FileAccess.file_exists(REGISTRY_PATH) or not FileAccess.file_exists(OUTPUT_DIR + "/manifest.json"):
		_fail("Binding generation did not create the registry and manifest.")
		return
	var registry_source := FileAccess.get_file_as_string(REGISTRY_PATH)
	if registry_source.contains("preload("):
		_fail("Generated registry eagerly preloaded component scripts.")
		return

	var package_resource := ResourceLoader.load(PACKAGE_PATH) as FGUIPackageResource
	var package := package_resource.acquire_package() if package_resource != null else null
	if package == null:
		_fail("Could not load the generated binding package.")
		return
	var main_item := package.get_item_by_name("Main")
	var main_url := "ui://%s%s" % [package.id, main_item.id] if main_item != null else ""
	FGUIPackageResource.release_package(package)

	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT_DIR + "/manifest.json"))
	var main_script_path := str(manifest.get("bindings", {}).get(main_url, "")) if manifest is Dictionary else ""
	if main_script_path == "" or not FileAccess.file_exists(main_script_path):
		_fail("The generated manifest did not contain the Main component binding.")
		return
	var source := FileAccess.get_file_as_string(main_script_path)
	if not source.contains("var mail_list: FGUIList"):
		_fail("The generated binding did not expose the semantic mailList member.")
		return
	if source.contains("var n6:"):
		_fail("The generated binding included a default n<number> child name.")
		return
	var stale_generated_path := ""
	for value: Variant in manifest.get("bindings", {}).values():
		var candidate := str(value)
		if candidate != main_script_path:
			stale_generated_path = candidate
			break

	var first_modified := FileAccess.get_modified_time(main_script_path)
	OS.delay_msec(1100)
	var second := generator.generate(paths, OUTPUT_DIR, "ProbeUI_", false, REGISTRY_PATH)
	if not bool(second.get("ok", false)):
		_fail("Repeated binding generation failed: %s" % [second.get("errors", [])])
		return
	if FileAccess.get_modified_time(main_script_path) != first_modified:
		_fail("Unchanged generated binding was rewritten.")
		return
	var stable_source := FileAccess.get_file_as_string(main_script_path)
	var rejected := RejectingGenerator.new().generate(paths, OUTPUT_DIR, "ProbeUI_", false, REGISTRY_PATH)
	if bool(rejected.get("ok", false)) or FileAccess.get_file_as_string(main_script_path) != stable_source:
		_fail("Rejected generated output was not rolled back transactionally.")
		return

	_write_text(main_script_path + ".fairygui_backup", stable_source)
	_write_text(main_script_path, "# interrupted generated output\n")
	_write_text(main_script_path + ".fairygui_tmp", "# interrupted temporary output\n")
	var recovered := generator.generate(paths, OUTPUT_DIR, "ProbeUI_", false, REGISTRY_PATH)
	if not bool(recovered.get("ok", false)) or FileAccess.get_file_as_string(main_script_path) != stable_source:
		_fail("Interrupted generated output was not recovered.")
		return
	if FileAccess.file_exists(main_script_path + ".fairygui_backup") or FileAccess.file_exists(main_script_path + ".fairygui_tmp"):
		_fail("Interrupted generation artifacts were not removed.")
		return

	FGUIObjectFactory.reload_generated_extensions()
	var runtime_package := FGUIPackage.add_package(PACKAGE_PATH)
	var view := runtime_package.create_object("Main") as FGUIComponent if runtime_package != null else null
	if view == null or view.get_script() == null or view.get_script().get_global_name() != "ProbeUI_VirtualListMain":
		var actual_script := "<null>"
		if view != null and view.get_script() != null:
			actual_script = "%s (%s)" % [view.get_script().get_global_name(), view.get_script().resource_path]
		_fail("Generated registry did not create the strongly typed Main component. Actual: %s; bindings: %s" % [
			actual_script,
			FGUIObjectFactory.generated_extensions.keys(),
		])
		return
	if view.get("mail_list") == null or not view.get("mail_list") is FGUIList:
		_fail("Generated member binding did not resolve mail_list.")
		return

	view.dispose()
	FGUIPackage.remove_package_instance(runtime_package)
	var source_before_failure := FileAccess.get_file_as_string(main_script_path)
	var failed := generator.generate(
		PackedStringArray(["res://tests/does_not_exist.fui"]),
		OUTPUT_DIR,
		"ProbeUI_",
		false,
		REGISTRY_PATH
	)
	if bool(failed.get("ok", false)) or FileAccess.get_file_as_string(main_script_path) != source_before_failure:
		_fail("Failed generation did not preserve the previous generated binding.")
		return

	var protected_source := source_before_failure.replace(
		FGUIBindingCodeGenerator.GENERATED_MARKER,
		"# User-owned binding retained by the generator"
	)
	_write_text(main_script_path, protected_source)
	var user_file := OUTPUT_DIR + "/user_notes.gd"
	_write_text(user_file, "extends RefCounted\n")
	if stale_generated_path != "":
		_write_text(stale_generated_path + ".uid", "uid://fairyguicodegenprobe\n")
	var cleared := generator.generate(PackedStringArray(), OUTPUT_DIR, "ProbeUI_", false, REGISTRY_PATH)
	if not bool(cleared.get("ok", false)):
		_fail("Empty generation failed: %s" % [cleared.get("errors", [])])
		return
	if not FileAccess.file_exists(main_script_path) or not FileAccess.file_exists(user_file):
		_fail("Stale cleanup removed a user-owned file.")
		return
	if stale_generated_path != "" and FileAccess.file_exists(stale_generated_path):
		_fail("Stale cleanup did not remove an obsolete generated binding.")
		return
	if stale_generated_path != "" and FileAccess.file_exists(stale_generated_path + ".uid"):
		_fail("Stale cleanup did not remove an obsolete generated binding UID.")
		return

	FGUIObjectFactory.set_generated_extensions({})
	if previous_registry == null:
		ProjectSettings.clear("fairygui/codegen/registry_path")
	else:
		ProjectSettings.set_setting("fairygui/codegen/registry_path", previous_registry)
	_remove_tree(OUTPUT_DIR)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	FGUIObjectFactory.set_generated_extensions({})
	_remove_tree(OUTPUT_DIR)
	quit(1)


func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()


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
