extends SceneTree

const SCENE_PATH := "res://examples/editor_preview/test.tscn"
const PACKAGE_PATH := "res://examples/assets/ui/Basics.fui"
const PluginScript := preload("res://addons/fairygui/plugin.gd")
const PreviewPanel := preload("res://addons/fairygui/editor/fui_preview_panel.gd")
const BusinessScriptGenerator := preload("res://addons/fairygui/editor/business_script_generator.gd")
const EventBindingService := preload("res://addons/fairygui/editor/event_binding_service.gd")

var _scene_root: Node
var _view: FGUIView
var _script_path: String
var _binding_action_created: bool = false


func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("Event binding editor probe must run through the Godot editor.")
		return
	_run.call_deferred()


func _run() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	while filesystem != null and (filesystem.is_scanning() or filesystem.is_importing()):
		await process_frame
	EditorInterface.open_scene_from_path(SCENE_PATH)
	for _frame in 20:
		await process_frame
	_scene_root = EditorInterface.get_edited_scene_root()
	var plugin := _find_node_by_script(root, PluginScript)
	var preview_panel := _find_node_by_script(root, PreviewPanel)
	var resource := ResourceLoader.load(PACKAGE_PATH) as FGUIPackageResource
	if _scene_root == null or plugin == null or preview_panel == null or resource == null:
		_fail("FairyGUI phase two editor services were not available.")
		return

	_view = FGUIView.new()
	_view.name = "PhaseTwoEventProbe"
	_view.package = resource
	_view.component_name = "Main"
	var service := EventBindingService.new()
	var detached_model := service.build_model(_view)
	if _find_target(detached_model.get("targets", []), PackedStringArray(["btn_Button"])).is_empty():
		_fail("Event binding targets were unavailable before the editor preview entered the scene tree.")
		return
	_scene_root.add_child(_view)
	_view.owner = _scene_root
	for _frame in 4:
		await process_frame
	var generator := BusinessScriptGenerator.new()
	var created := generator.create_for_view(_view, "res://tests/_phase_two_scene.tscn")
	if not bool(created.get("ok", false)):
		_fail("Could not create the phase two business script: %s" % created.get("error", ""))
		return
	_script_path = str(created.script_path)
	filesystem.scan_sources()
	while filesystem.is_scanning() or filesystem.is_importing():
		await process_frame
	var business_script := ResourceLoader.load(_script_path, "", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if business_script == null:
		_fail("Could not load the phase two business script.")
		return
	_view.call("_clear_preview")
	_view.set_script(business_script)
	_view.package = resource
	_view.component_name = "Main"
	_view.preview_in_editor = true
	_view.refresh_preview()
	for _frame in 4:
		await process_frame

	var model := service.build_model(_view)
	var button_target := _find_target(model.get("targets", []), PackedStringArray(["btn_Button"]))
	if button_target.is_empty():
		_fail("Real Basics.fui button target was not exposed for event binding.")
		return
	var handler := service.suggest_handler(button_target, FGUIEvents.CLICK)
	if handler != &"_on_btn_button_clicked":
		_fail("Event handler suggestion was not deterministic: %s" % handler)
		return
	plugin.call(
		"_on_event_binding_add",
		_view,
		PackedStringArray(["btn_Button"]),
		FGUIEvents.CLICK,
		handler,
		false
	)
	_binding_action_created = true
	for _frame in 8:
		await process_frame
	if _view.event_bindings.size() != 1:
		_fail("Inspector event action did not serialize the binding on FGUIView.")
		return
	if _view.package == null or _view.package.get_source_path() != PACKAGE_PATH or _view.component_name != "Main":
		_fail("Generating an event handler cleared the FGUIView package configuration.")
		return
	var source := FileAccess.get_file_as_string(_script_path)
	if source.count("func _on_btn_button_clicked(") != 1 or not _view.has_method(handler):
		_fail("Event action did not generate one valid handler function.")
		return
	model = service.build_model(_view)
	var rows: Array = model.get("bindings", [])
	if rows.size() != 1 or str((rows[0] as Dictionary).get("severity", "")) != "success":
		_fail("Valid event binding did not pass editor diagnostics: %s" % [rows])
		return

	var history := _scene_history()
	history.undo()
	await process_frame
	if not _view.event_bindings.is_empty():
		_fail("Event binding did not integrate with scene Undo.")
		return
	history.redo()
	await process_frame
	if _view.event_bindings.size() != 1:
		_fail("Event binding did not integrate with scene Redo.")
		return
	plugin.call("_on_event_binding_open", _view, 0)
	for _frame in 4:
		await process_frame
	source = FileAccess.get_file_as_string(_script_path)
	if source.count("func _on_btn_button_clicked(") != 1:
		_fail("Opening an existing event handler generated a duplicate function.")
		return
	plugin.call("_on_event_binding_toggle", _view, 0)
	await process_frame
	if _view.event_bindings[0].enabled:
		_fail("Inspector did not disable the selected event binding.")
		return
	_scene_history().undo()
	await process_frame
	if not _view.event_bindings[0].enabled:
		_fail("Event binding enable state did not integrate with Undo.")
		return

	preview_panel.call("open_package", resource, "Main", _view)
	for _frame in 8:
		await process_frame
	var preview_root := preview_panel.call("get_preview_object") as FGUIComponent
	var preview_button := preview_root.get_child("btn_Button") if preview_root != null else null
	if preview_button == null:
		_fail("GUI preview could not locate the event target.")
		return
	preview_panel.call("select_object", preview_button, true)
	await process_frame
	var bind_button := preview_panel.get("_bind_event_button") as Button
	if bind_button == null or bind_button.disabled:
		_fail("GUI preview did not enable preview-to-event binding for its FGUIView context.")
		return
	preview_panel.call("_on_bind_event_pressed")
	for _frame in 8:
		await process_frame
	var preferred: Variant = _view.get_meta(EventBindingService.META_PREFERRED_TARGET, PackedStringArray())
	if not preferred is PackedStringArray or preferred != PackedStringArray(["btn_Button"]):
		_fail("GUI preview did not transfer the selected target to the Inspector.")
		return
	var inspector := _find_node_by_name(root, "FairyGUIEventBindingInspector")
	if inspector == null:
		_fail("FGUIView Inspector did not create the phase two event binding panel.")
		return
	var target_picker := inspector.get("_target_picker") as OptionButton
	var selected_target: Variant = target_picker.get_item_metadata(target_picker.selected) if target_picker != null else null
	if not selected_target is Dictionary or str(selected_target.get("key", "")) != service.target_path_key(PackedStringArray(["btn_Button"])):
		_fail("Inspector event panel did not select the target chosen in GUI preview.")
		return

	_cleanup()
	quit(0)


func _find_target(targets: Array, path: PackedStringArray) -> Dictionary:
	var key := EventBindingService.new().target_path_key(path)
	for target: Dictionary in targets:
		if str(target.get("key", "")) == key:
			return target
	return {}


func _scene_history() -> UndoRedo:
	var manager := EditorInterface.get_editor_undo_redo()
	return manager.get_history_undo_redo(manager.get_object_history_id(_scene_root))


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _find_node_by_script(node: Node, script: Script) -> Node:
	if node.get_script() == script:
		return node
	for child: Node in node.get_children():
		var found := _find_node_by_script(child, script)
		if found != null:
			return found
	return null


func _cleanup() -> void:
	if _binding_action_created and _scene_root != null:
		var history := _scene_history()
		if history.has_undo():
			history.undo()
		_binding_action_created = false
	if _view != null:
		_view.queue_free()
		_view = null
	if _script_path != "":
		_remove_file(_script_path)
		_remove_file(_script_path + ".uid")
		_remove_file(_script_path + ".fairygui_tmp")
		_remove_file(_script_path + ".fairygui_backup")


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	push_error(message)
	_cleanup()
	quit(1)
