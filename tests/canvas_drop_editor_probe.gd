extends SceneTree

const SCENE_PATH := "res://examples/editor_preview/test.tscn"
const PACKAGE_PATH := "res://examples/assets/ui/Basics.fui"


func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("Canvas drop probe must run through the Godot editor.")
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
	if scene_root == null:
		_fail("Could not open the editor preview scene.")
		return
	var overlay := _find_node_by_name(root, "FairyGUICanvasDropOverlay")
	if overlay == null:
		_fail("FairyGUI canvas drop overlay was not installed.")
		return
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(scene_root)
	var before_count := _count_fui_views(scene_root)
	overlay.emit_signal("component_dropped", PACKAGE_PATH, "Demo_Graph", Vector2(120.0, 80.0))
	await process_frame
	await process_frame
	var created := _find_fui_view(scene_root, "Demo_Graph")
	if created == null or created.package == null or created.package.get_source_path() != PACKAGE_PATH:
		_fail("Dropping a real .fui component did not create a configured FGUIView.")
		return
	if created.component_name != "Demo_Graph" or created.owner != scene_root:
		_fail("Created FGUIView did not preserve the real component or scene owner.")
		return
	var undo_manager := EditorInterface.get_editor_undo_redo()
	var history_id := undo_manager.get_object_history_id(scene_root)
	var history := undo_manager.get_history_undo_redo(history_id)
	history.undo()
	await process_frame
	if _count_fui_views(scene_root) != before_count:
		_fail("Canvas drop creation did not integrate with editor Undo/Redo.")
		return
	history.redo()
	for _frame in 4:
		await process_frame
	var redone := _find_fui_view(scene_root, "Demo_Graph")
	if redone == null or redone.fairy == null:
		_fail("Redo did not restore the created FGUIView preview.")
		return
	history.undo()
	await process_frame
	quit(0)


func _count_fui_views(node: Node) -> int:
	var count := 1 if node is FGUIView else 0
	for child: Node in node.get_children():
		count += _count_fui_views(child)
	return count


func _find_fui_view(node: Node, component_name: String) -> FGUIView:
	if node is FGUIView and (node as FGUIView).component_name == component_name:
		return node as FGUIView
	for child: Node in node.get_children():
		var found := _find_fui_view(child, component_name)
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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
