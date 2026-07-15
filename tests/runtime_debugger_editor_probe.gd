extends SceneTree

const SCENE_PATH := "res://examples/editor_preview/test.tscn"
const DebuggerPanel := preload("res://addons/fairygui/editor/fairygui_debugger_panel.gd")


func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("Runtime debugger probe must run through the Godot editor.")
		return
	_run.call_deferred()


func _run() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	while filesystem != null and (filesystem.is_scanning() or filesystem.is_importing()):
		await process_frame
	EditorInterface.open_scene_from_path(SCENE_PATH)
	for _frame in 20:
		await process_frame
	EditorInterface.play_current_scene()
	var panel: Control
	for attempt in 200:
		panel = _find_node_by_script(root, DebuggerPanel) as Control
		if panel != null:
			var tree := panel.get("_tree") as Tree
			if tree != null and tree.get_root() != null and tree.get_root().get_first_child() != null:
				break
			if attempt % 10 == 0:
				panel.emit_signal("refresh_requested")
		await create_timer(0.05).timeout
	if panel == null:
		EditorInterface.stop_playing_scene()
		_fail("FairyGUI debugger did not create a debugger session tab.")
		return
	var debugger_tree := panel.get("_tree") as Tree
	if debugger_tree == null or debugger_tree.get_root() == null or debugger_tree.get_root().get_first_child() == null:
		EditorInterface.stop_playing_scene()
		_fail("FairyGUI debugger did not receive the runtime logical tree.")
		return
	var view_item := debugger_tree.get_root().get_first_child()
	var object_item := view_item.get_first_child()
	if object_item == null or int(object_item.get_metadata(0)) == 0:
		EditorInterface.stop_playing_scene()
		_fail("FairyGUI debugger tree did not expose selectable runtime objects.")
		return
	object_item.select(0)
	panel.call("_on_item_selected")
	await process_frame
	EditorInterface.stop_playing_scene()
	for _frame in 10:
		await process_frame
	quit(0)


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
