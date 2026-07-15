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
	var plugin := _find_node_by_script(root, PluginScript)
	if scene_root == null or overlay == null or plugin == null:
		_fail("FairyGUI editor workflow was not available.")
		return
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(scene_root)
	overlay.emit_signal("component_dropped", PACKAGE_PATH, "Main", Vector2(80.0, 60.0))
	for _frame in 4:
		await process_frame
	var view := _find_view_for_package(scene_root, PACKAGE_PATH)
	if view == null:
		_fail("Could not create the VirtualList FGUIView for business script coverage.")
		return
	view.name = "PhaseOneProbe"
	plugin.call("_on_inspector_business_script", view)
	var script: Script
	for _attempt in 240:
		script = view.get_script() as Script
		if script != null and script.resource_path != "res://addons/fairygui/ui/fui_view.gd":
			break
		await create_timer(0.05).timeout
	if script == null or script.resource_path == "res://addons/fairygui/ui/fui_view.gd":
		_cleanup_scene_history(scene_root, 1)
		_fail("Inspector did not create and attach a business script.")
		return
	var script_path := script.resource_path
	var source := FileAccess.get_file_as_string(script_path)
	if source.contains("UI_BasicsMain") or not source.contains("const UI_TYPE := preload(") or not source.contains("virtual_list"):
		_cleanup_scene_history(scene_root, 2)
		_remove_script(script_path)
		_fail("Attached business script was not derived from VirtualList.fui: %s" % script_path)
		return
	_cleanup_scene_history(scene_root, 2)
	_remove_script(script_path)
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


func _find_view_for_package(node: Node, package_path: String) -> FGUIView:
	if node is FGUIView:
		var view := node as FGUIView
		if view.package != null and view.package.get_source_path() == package_path:
			return view
	for child: Node in node.get_children():
		var found := _find_view_for_package(child, package_path)
		if found != null:
			return found
	return null


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
