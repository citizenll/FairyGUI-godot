extends SceneTree

const PACKAGE_DIR := "res://examples/assets/ui"
const OUTPUT_DIR := "res://tests/_generated_fairygui_smoke"
const REGISTRY_PATH := OUTPUT_DIR + "/registry.gd"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_remove_tree(OUTPUT_DIR)
	var package_paths := PackedStringArray()
	var directory := DirAccess.open(PACKAGE_DIR)
	if directory == null:
		_fail("Could not open the FairyGUI example package directory.")
		return
	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "fui":
			package_paths.append("%s/%s" % [PACKAGE_DIR, file_name])
	package_paths.sort()

	var previous_registry: Variant = ProjectSettings.get_setting("fairygui/codegen/registry_path", null)
	ProjectSettings.set_setting("fairygui/codegen/registry_path", REGISTRY_PATH)
	var result := FGUIBindingCodeGenerator.new().generate(package_paths, OUTPUT_DIR, "SmokeUI_", false, REGISTRY_PATH)
	if not bool(result.get("ok", false)):
		_fail("Full binding generation failed: %s" % [result.get("errors", [])])
		return
	for warning: String in result.get("warnings", PackedStringArray()):
		if warning.contains("dependency is missing") or warning.begins_with("Could not resolve child source"):
			_fail("Full binding generation reported an unresolved package reference: %s" % warning)
			return
	var generated_alias_count := 0
	var unique_binding_paths: Dictionary = {}
	for value: Variant in result.get("bindings", {}).values():
		unique_binding_paths[str(value)] = true
	for path: String in unique_binding_paths:
		generated_alias_count += FileAccess.get_file_as_string(path).count("const _TYPE_")
	if generated_alias_count == 0:
		_fail("Full binding generation did not produce any explicit custom component type preload.")
		return

	FGUIObjectFactory.reload_generated_extensions()
	if FGUIObjectFactory.generated_extensions.is_empty():
		_fail("Full generated registry did not expose any component bindings.")
		return

	var packages: Array[FGUIPackage] = []
	for path: String in package_paths:
		var package := FGUIPackage.add_package(path)
		if package == null:
			_fail("Could not load generated smoke package: %s" % path)
			return
		packages.append(package)

	var component_count := 0
	for package: FGUIPackage in packages:
		for item: FGUIPackageItem in package.items:
			if item.type != FGUIEnums.PACKAGE_ITEM_COMPONENT:
				continue
			var object := package.create_object(item.name)
			if object == null:
				_fail("Component could not be constructed during generated binding smoke coverage: %s/%s" % [package.name, item.name])
				return
			if not item.exported:
				object.dispose()
				continue
			if object.get_script() == null or not object.get_script().get_global_name().begins_with("SmokeUI_"):
				_fail("Exported component did not use a generated binding: %s/%s" % [package.name, item.name])
				return
			var url := "ui://%s%s" % [package.id, item.id]
			var script_path := str(result.get("bindings", {}).get(url, ""))
			for member_name: String in _generated_member_names(script_path):
				if object.get(member_name) == null:
					object.dispose()
					_fail("Generated member did not bind: %s/%s.%s" % [package.name, item.name, member_name])
					return
			component_count += 1
			object.dispose()
	if component_count < 10:
		_fail("Generated binding smoke test covered too few exported components: %d" % component_count)
		return

	for index in range(packages.size() - 1, -1, -1):
		FGUIPackage.remove_package_instance(packages[index])
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


func _generated_member_names(path: String) -> PackedStringArray:
	var result := PackedStringArray()
	if path == "" or not FileAccess.file_exists(path):
		return result
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.begins_with("\t") and line.contains(" = require_"):
			result.append(line.get_slice("=", 0).strip_edges())
	return result


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
