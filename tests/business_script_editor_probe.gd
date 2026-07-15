extends SceneTree

const SCENE_PATH := "res://examples/editor_preview/test.tscn"
const PACKAGE_PATH := "res://examples/assets/ui/VirtualList.fui"
const PluginScript := preload("res://addons/fairygui/plugin.gd")


func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("Business script probe must run through the Godot editor.")
		return
	_run.call_deferred()


func _run() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	while filesystem != null and (filesystem.is_scanning() or filesystem.is_importing()):
		await process_frame
	EditorInterface.open_scene_from_path(SCENE_PATH)
	for _frame in 20:
		await process_frame
	var scene_root := EditorInterface.get_edited_scene_root()
	var overlay := _find_node_by_name(root, "FairyGUICanvasDropOverlay")
	if scene_root == null or overlay == null:
		_fail("FairyGUI editor workflow was not available.")
		return
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(scene_root)
	overlay.emit_signal("component_dropped", PACKAGE_PATH, "Main", Vector2(80.0, 60.0))
	var selected := selection.get_selected_nodes()
	var view := selected[0] as FGUIView if selected.size() == 1 else null
	if view == null:
		_fail("Could not create the VirtualList FGUIView for business script coverage.")
		return
	view.name = "PhaseOneProbe"
	var script: Script
	for _attempt in 240:
		script = view.get_script() as Script
		if script != null and script.resource_path != "res://addons/fairygui/ui/fui_view.gd":
			break
		await create_timer(0.05).timeout
	if script == null or script.resource_path == "res://addons/fairygui/ui/fui_view.gd":
		_cleanup_scene_history(scene_root, 1)
		_fail("Canvas drop did not create and attach a business script.")
		return
	var script_path := script.resource_path
	for _frame in 4:
		await process_frame
	if view.package == null or view.package.get_source_path() != PACKAGE_PATH:
		_cleanup_scene_history(scene_root, 1)
		_remove_script(script_path)
		_fail("Attaching the business script cleared the VirtualList .fui package.")
		return
	if view.component_name != "Main" or view.fairy == null:
		_cleanup_scene_history(scene_root, 1)
		_remove_script(script_path)
		_fail("Attaching the business script did not preserve and rebuild the preview.")
		return
	var source := FileAccess.get_file_as_string(script_path)
	if source.contains("UI_BasicsMain") or not source.contains("const UI_TYPE := preload(") or not source.contains("virtual_list"):
		_cleanup_scene_history(scene_root, 1)
		_remove_script(script_path)
		_fail("Attached business script was not derived from VirtualList.fui: %s" % script_path)
		return
	_cleanup_scene_history(scene_root, 1)
	_remove_script(script_path)
	await process_frame

	var plugin := _find_node_by_script(root, PluginScript)
	var resource := ResourceLoader.load(PACKAGE_PATH) as FGUIPackageResource
	if plugin == null or resource == null:
		_fail("Could not prepare manual business script attachment coverage.")
		return
	var manual_view := FGUIView.new()
	manual_view.name = "ManualBindingProbe"
	manual_view.package = resource
	manual_view.component_name = "Main"
	manual_view.resize_to_content = false
	manual_view.match_control_size = true
	scene_root.add_child(manual_view)
	manual_view.owner = scene_root
	plugin.call("_on_inspector_business_script", manual_view)
	var manual_script: Script
	for _attempt in 240:
		manual_script = manual_view.get_script() as Script
		if manual_script != null and manual_script.resource_path != "res://addons/fairygui/ui/fui_view.gd":
			break
		await create_timer(0.05).timeout
	if manual_script == null or manual_script.resource_path == "res://addons/fairygui/ui/fui_view.gd":
		manual_view.queue_free()
		_fail("Inspector did not create and attach a business script.")
		return
	var manual_script_path := manual_script.resource_path
	for _frame in 4:
		await process_frame
	if manual_view.package == null or manual_view.package.get_source_path() != PACKAGE_PATH:
		_cleanup_scene_history(scene_root, 1)
		manual_view.queue_free()
		_remove_script(manual_script_path)
		_fail("Manual script attachment cleared the configured .fui package.")
		return
	if manual_view.resize_to_content or not manual_view.match_control_size or manual_view.fairy == null:
		_cleanup_scene_history(scene_root, 1)
		manual_view.queue_free()
		_remove_script(manual_script_path)
		_fail("Manual script attachment did not preserve all FGUIView configuration.")
		return
	_cleanup_scene_history(scene_root, 1)
	for _frame in 4:
		await process_frame
	if manual_view.get_script() == manual_script or manual_view.package == null or manual_view.fairy == null:
		manual_view.queue_free()
		_remove_script(manual_script_path)
		_fail("Undo did not restore the base FGUIView script and configuration.")
		return
	manual_view.queue_free()
	await process_frame
	_remove_script(manual_script_path)
	quit(0)


func _cleanup_scene_history(scene_root: Node, action_count: int) -> void:
	var manager := EditorInterface.get_editor_undo_redo()
	var history := manager.get_history_undo_redo(manager.get_object_history_id(scene_root))
	for _index in action_count:
		if history.has_undo():
			history.undo()


func _remove_script(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(path + ".uid"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".uid"))


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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
