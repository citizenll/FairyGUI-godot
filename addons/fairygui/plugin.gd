@tool
extends EditorPlugin

const FUIImportPlugin := preload("res://addons/fairygui/editor/fui_import_plugin.gd")
const BindingCodeGenerator := preload("res://addons/fairygui/editor/binding_codegen.gd")
const BindingInspectorPlugin := preload("res://addons/fairygui/editor/binding_inspector_plugin.gd")
const BindingExportPlugin := preload("res://addons/fairygui/editor/binding_export_plugin.gd")

const SETTING_AUTO_GENERATE := "fairygui/codegen/auto_generate"
const SETTING_OUTPUT_DIR := "fairygui/codegen/output_dir"
const SETTING_REGISTRY_PATH := "fairygui/codegen/registry_path"
const SETTING_CLASS_PREFIX := "fairygui/codegen/class_prefix"
const SETTING_INCLUDE_DEFAULT_NAMES := "fairygui/codegen/include_default_names"
const TOOL_MENU_NAME := "Generate FairyGUI Bindings"

var _fui_importer: EditorImportPlugin
var _binding_inspector: EditorInspectorPlugin
var _binding_exporter: EditorExportPlugin
var _generation_queued: bool = false
var _generation_running: bool = false
var _generation_requested_while_running: bool = false


func _enter_tree() -> void:
	_register_project_settings()
	_fui_importer = FUIImportPlugin.new()
	add_import_plugin(_fui_importer, true)

	_binding_inspector = BindingInspectorPlugin.new()
	_binding_inspector.generate_callback = Callable(self, "_on_inspector_generate")
	_binding_inspector.open_callback = Callable(self, "_on_inspector_open")
	add_inspector_plugin(_binding_inspector)
	_binding_exporter = BindingExportPlugin.new()
	_binding_exporter.generate_callback = Callable(self, "generate_all_bindings")
	add_export_plugin(_binding_exporter)
	add_tool_menu_item(TOOL_MENU_NAME, Callable(self, "generate_all_bindings"))

	var filesystem := get_editor_interface().get_resource_filesystem()
	if not filesystem.resources_reimported.is_connected(_on_resources_reimported):
		filesystem.resources_reimported.connect(_on_resources_reimported)
	if bool(ProjectSettings.get_setting(SETTING_AUTO_GENERATE, true)):
		_queue_generation()


func _exit_tree() -> void:
	_generation_queued = false
	_generation_requested_while_running = false
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.resources_reimported.is_connected(_on_resources_reimported):
		filesystem.resources_reimported.disconnect(_on_resources_reimported)
	remove_tool_menu_item(TOOL_MENU_NAME)
	if _binding_exporter != null:
		remove_export_plugin(_binding_exporter)
		_binding_exporter = null
	if _binding_inspector != null:
		remove_inspector_plugin(_binding_inspector)
		_binding_inspector = null
	if _fui_importer != null:
		remove_import_plugin(_fui_importer)
		_fui_importer = null


func generate_all_bindings() -> Dictionary:
	if _generation_running:
		_generation_requested_while_running = true
		return {"ok": false, "busy": true}
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.is_scanning() or filesystem.get_filesystem() == null:
		_queue_generation()
		return {"ok": false, "busy": true, "reason": "filesystem_not_ready"}
	_generation_queued = false
	_generation_running = true

	var resource_paths := _collect_codegen_resources()
	var generator := BindingCodeGenerator.new()
	var output_dir := str(ProjectSettings.get_setting(SETTING_OUTPUT_DIR, BindingCodeGenerator.DEFAULT_OUTPUT_DIR))
	var registry_path := str(ProjectSettings.get_setting(
		SETTING_REGISTRY_PATH,
		"%s/%s" % [output_dir.trim_suffix("/"), BindingCodeGenerator.REGISTRY_FILE]
	))
	var result: Dictionary = generator.generate(
		resource_paths,
		output_dir,
		str(ProjectSettings.get_setting(SETTING_CLASS_PREFIX, "UI_")),
		bool(ProjectSettings.get_setting(SETTING_INCLUDE_DEFAULT_NAMES, false)),
		registry_path
	)
	_report_generation(result, resource_paths.size())
	_generation_running = false

	if bool(result.get("ok", false)):
		filesystem.scan_sources()
		call_deferred("_reload_generated_bindings")

	if _generation_requested_while_running:
		_generation_requested_while_running = false
		_queue_generation()
	return result


func _queue_generation() -> void:
	if _generation_running:
		_generation_requested_while_running = true
		return
	if _generation_queued:
		return
	_generation_queued = true
	call_deferred("_run_queued_generation")


func _run_queued_generation() -> void:
	if not is_inside_tree() or not _generation_queued:
		return
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.is_scanning() or filesystem.get_filesystem() == null:
		call_deferred("_run_queued_generation")
		return
	generate_all_bindings()


func _on_resources_reimported(paths: PackedStringArray) -> void:
	if not bool(ProjectSettings.get_setting(SETTING_AUTO_GENERATE, true)):
		return
	for path: String in paths:
		if path.get_extension().to_lower() == "fui":
			_queue_generation()
			return


func _on_inspector_generate(_object: Object) -> void:
	generate_all_bindings()


func _on_inspector_open(object: Object) -> void:
	if not object is FGUIView:
		return
	var path := _binding_path_for_view(object as FGUIView)
	if path == "":
		var result := generate_all_bindings()
		if not bool(result.get("ok", false)):
			return
		path = _binding_path_for_view(object as FGUIView)
	if path == "" or not ResourceLoader.exists(path):
		push_warning("[FairyGUI codegen] Binding script is not available yet. Wait for the filesystem scan and try again.")
		return
	var script := ResourceLoader.load(path) as Script
	if script != null:
		get_editor_interface().edit_script(script)


func _binding_path_for_view(view: FGUIView) -> String:
	if view == null or view.package == null:
		return ""
	var package := view.package.acquire_package()
	if package == null:
		return ""
	var component_name := view.component_name
	if component_name == "":
		var names := view.package.get_component_names()
		component_name = "Main" if names.has("Main") else (names[0] if not names.is_empty() else "")
	var item := package.get_item_by_name(component_name)
	var url := "ui://%s%s" % [package.id, item.id] if item != null else ""
	FGUIPackageResource.release_package(package)
	if url == "":
		return ""
	var output_dir := str(ProjectSettings.get_setting(SETTING_OUTPUT_DIR, BindingCodeGenerator.DEFAULT_OUTPUT_DIR)).trim_suffix("/")
	var manifest_path := "%s/%s" % [output_dir, BindingCodeGenerator.MANIFEST_FILE]
	if not FileAccess.file_exists(manifest_path):
		return ""
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary:
		return ""
	return str(manifest.get("bindings", {}).get(url, ""))


func _collect_codegen_resources() -> PackedStringArray:
	var result := PackedStringArray()
	var filesystem := get_editor_interface().get_resource_filesystem()
	var root := filesystem.get_filesystem()
	if root != null:
		_collect_codegen_resources_from_directory(root, result)
	result.sort()
	return result


func _collect_codegen_resources_from_directory(directory: EditorFileSystemDirectory, result: PackedStringArray) -> void:
	for index in directory.get_file_count():
		var path := directory.get_file_path(index)
		if path.get_extension().to_lower() != "fui":
			continue
		var resource: Resource = ResourceLoader.load(path)
		if resource is FGUIPackageResource and (resource as FGUIPackageResource).codegen_enabled:
			result.append(path)
	for index in directory.get_subdir_count():
		_collect_codegen_resources_from_directory(directory.get_subdir(index), result)


func _reload_generated_bindings() -> void:
	if not is_inside_tree():
		return
	if get_editor_interface().get_resource_filesystem().is_scanning():
		call_deferred("_reload_generated_bindings")
		return
	FGUIObjectFactory.reload_generated_extensions()
	var root := get_editor_interface().get_edited_scene_root()
	if root != null:
		_refresh_fui_views(root)


func _refresh_fui_views(node: Node) -> void:
	if node is FGUIView:
		(node as FGUIView).refresh_preview()
	for child: Node in node.get_children():
		_refresh_fui_views(child)


func _report_generation(result: Dictionary, package_count: int) -> void:
	for warning: String in result.get("warnings", PackedStringArray()):
		push_warning("[FairyGUI codegen] %s" % warning)
	for error: String in result.get("errors", PackedStringArray()):
		push_error("[FairyGUI codegen] %s" % error)
	if bool(result.get("ok", false)):
		print("[FairyGUI codegen] %d package(s), %d generated, %d unchanged, %d removed, %d warning(s)." % [
			package_count,
			result.get("generated_files", PackedStringArray()).size(),
			result.get("unchanged_files", PackedStringArray()).size(),
			result.get("removed_files", PackedStringArray()).size(),
			result.get("warnings", PackedStringArray()).size(),
		])


func _register_project_settings() -> void:
	_register_setting(SETTING_AUTO_GENERATE, true, TYPE_BOOL)
	_register_setting(SETTING_OUTPUT_DIR, BindingCodeGenerator.DEFAULT_OUTPUT_DIR, TYPE_STRING, PROPERTY_HINT_DIR)
	_register_setting(
		SETTING_REGISTRY_PATH,
		"%s/%s" % [BindingCodeGenerator.DEFAULT_OUTPUT_DIR, BindingCodeGenerator.REGISTRY_FILE],
		TYPE_STRING,
		PROPERTY_HINT_FILE,
		"*.gd"
	)
	_register_setting(SETTING_CLASS_PREFIX, "UI_", TYPE_STRING)
	_register_setting(SETTING_INCLUDE_DEFAULT_NAMES, false, TYPE_BOOL)


func _register_setting(
		name: String,
		default_value: Variant,
		type: int,
		hint: int = PROPERTY_HINT_NONE,
		hint_string: String = ""
	) -> void:
	if not ProjectSettings.has_setting(name):
		ProjectSettings.set_setting(name, default_value)
	ProjectSettings.set_initial_value(name, default_value)
	ProjectSettings.add_property_info({
		"name": name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	})
