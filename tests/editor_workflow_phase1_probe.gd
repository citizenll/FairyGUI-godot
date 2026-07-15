extends SceneTree

const PACKAGE_PATH := "res://examples/assets/ui/VirtualList.fui"
const OUTPUT_DIR := "res://tests/_generated_editor_workflow"
const REGISTRY_PATH := OUTPUT_DIR + "/registry.gd"
const BusinessScriptGenerator := preload("res://addons/fairygui/editor/business_script_generator.gd")
const PackageDiagnostics := preload("res://addons/fairygui/editor/package_diagnostics.gd")
const CanvasDropOverlay := preload("res://addons/fairygui/editor/fui_canvas_drop_overlay.gd")
const RuntimeDebugBridge := preload("res://addons/fairygui/debug/fairygui_debug_bridge.gd")

var _previous_output: Variant
var _previous_registry: Variant


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_remove_tree(OUTPUT_DIR)
	_previous_output = ProjectSettings.get_setting("fairygui/codegen/output_dir", null)
	_previous_registry = ProjectSettings.get_setting("fairygui/codegen/registry_path", null)
	ProjectSettings.set_setting("fairygui/codegen/output_dir", OUTPUT_DIR)
	ProjectSettings.set_setting("fairygui/codegen/registry_path", REGISTRY_PATH)

	var generation := FGUIBindingCodeGenerator.new().generate(
		PackedStringArray([PACKAGE_PATH]),
		OUTPUT_DIR,
		"PhaseOneUI_",
		false,
		REGISTRY_PATH
	)
	if not bool(generation.get("ok", false)):
		_fail("Dynamic binding generation failed: %s" % [generation.get("errors", [])])
		return

	var resource := ResourceLoader.load(PACKAGE_PATH) as FGUIPackageResource
	if resource == null:
		_fail("Could not load VirtualList.fui.")
		return
	var component := resource.get_component_info()
	if str(component.get("package_name", "")) != "VirtualList" or str(component.get("component_name", "")) != "Main":
		_fail("Component metadata was not parsed from VirtualList.fui: %s" % [component])
		return
	if not resource.get_component_info("does_not_exist").is_empty():
		_fail("Explicit invalid component names did not fail metadata resolution.")
		return

	var view := FGUIView.new()
	view.name = "MailPanel"
	view.package = resource
	view.component_name = str(component.component_name)
	var business_generator := BusinessScriptGenerator.new()
	var binding := business_generator.resolve_binding(resource, view.component_name)
	if not bool(binding.ok):
		_fail("Could not resolve the generated VirtualList binding: %s" % binding.error)
		return
	if str(binding.binding_class) != "PhaseOneUI_VirtualListMain":
		_fail("Business binding class was not derived from the real package: %s" % binding.binding_class)
		return
	if not bool(binding.current):
		_fail("Freshly generated binding was reported as stale.")
		return
	var source := business_generator.render_source(binding)
	if source.contains("UI_BasicsMain") or not source.contains(str(binding.binding_path)) or not source.contains("var ui: UI_TYPE"):
		_fail("Business script template used a fixed or untyped binding.")
		return
	var created := business_generator.create_for_view(view, OUTPUT_DIR + "/workflow_scene.tscn")
	if not bool(created.ok) or not FileAccess.file_exists(str(created.script_path)):
		_fail("Business script file was not created: %s" % created.get("error", ""))
		return
	if not str(created.script_path).ends_with("/mail_panel.gd"):
		_fail("Business script path was not derived from the FGUIView node name: %s" % created.script_path)
		return
	var business_script := ResourceLoader.load(str(created.script_path), "", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if business_script == null:
		_fail("Generated business script could not be loaded.")
		return
	FGUIObjectFactory.reload_generated_extensions()
	var recovered_view := FGUIView.new()
	recovered_view.set_script(business_script)
	root.add_child(recovered_view)
	for _frame in 4:
		await process_frame
	if recovered_view.package == null or recovered_view.package.get_source_path() != PACKAGE_PATH:
		_fail("Business script did not restore its generated .fui package configuration.")
		return
	if recovered_view.component_name != "Main" or recovered_view.fairy == null:
		_fail("Business script did not restore its generated component preview.")
		return
	recovered_view.queue_free()
	await process_frame

	var diagnostics := PackageDiagnostics.new().analyze(resource, view.component_name)
	if int(diagnostics.error_count) != 0 or int(diagnostics.warning_count) != 0:
		_fail("Valid generated package reported diagnostics: %s" % [diagnostics.issues])
		return
	var original_hash := resource.content_hash
	resource.content_hash = original_hash + "_stale"
	var stale_diagnostics := PackageDiagnostics.new().analyze(resource, view.component_name)
	resource.content_hash = original_hash
	if int(stale_diagnostics.warning_count) == 0:
		_fail("Stale generated bindings were not reported by package diagnostics.")
		return

	var drop_overlay := CanvasDropOverlay.new()
	var file_request := drop_overlay.extract_drop_request({
		"type": "files",
		"files": PackedStringArray([PACKAGE_PATH]),
	})
	var component_request := drop_overlay.extract_drop_request({
		"type": "fairygui_component",
		"package_path": PACKAGE_PATH,
		"component_name": "Main",
	})
	if str(file_request.get("package_path", "")) != PACKAGE_PATH or str(component_request.get("component_name", "")) != "Main":
		_fail("Canvas drop data did not preserve the real package/component metadata.")
		return
	if not drop_overlay.extract_drop_request({"type": "files", "files": PackedStringArray(["res://icon.png"])}).is_empty():
		_fail("Canvas drop overlay intercepted a non-FairyGUI resource.")
		return
	drop_overlay.free()

	root.add_child(view)
	for _frame in 4:
		await process_frame
	if view.fairy == null:
		_fail("Runtime FGUIView did not construct the dynamic VirtualList component.")
		return
	var bridge := RuntimeDebugBridge.new()
	root.add_child(bridge)
	var snapshot := bridge.build_snapshot()
	if int(snapshot.view_count) != 1 or int(snapshot.object_count) < 2:
		_fail("Runtime FairyGUI debugger did not serialize the logical tree: %s" % [snapshot])
		return
	if not bridge.select_object(view.fairy.get_instance_id()):
		_fail("Runtime FairyGUI debugger could not select a serialized object.")
		return

	view.queue_free()
	bridge.queue_free()
	await process_frame
	_cleanup()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	_cleanup()
	quit(1)


func _cleanup() -> void:
	FGUIObjectFactory.set_generated_extensions({})
	if _previous_output == null:
		ProjectSettings.clear("fairygui/codegen/output_dir")
	else:
		ProjectSettings.set_setting("fairygui/codegen/output_dir", _previous_output)
	if _previous_registry == null:
		ProjectSettings.clear("fairygui/codegen/registry_path")
	else:
		ProjectSettings.set_setting("fairygui/codegen/registry_path", _previous_registry)
	_remove_tree(OUTPUT_DIR)


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
