extends SceneTree

const SCENE_PATH := "res://examples/editor_preview/test.tscn"
const PACKAGE_PATH := "res://examples/assets/ui/Basics.fui"
const PluginScript := preload("res://addons/fairygui/plugin.gd")
const TargetScript := preload("res://addons/fairygui/ui/fgui_target.gd")
const ObjectReference := preload("res://addons/fairygui/ui/object_reference.gd")

var _scene_root: Node
var _view: FGUIView
var _undo_count: int = 0


func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("FGUI target editor probe must run through the Godot editor.")
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
	var resource := ResourceLoader.load(PACKAGE_PATH) as FGUIPackageResource
	if _scene_root == null or plugin == null or resource == null:
		_fail("FairyGUI target editor services were unavailable.")
		return

	_view = FGUIView.new()
	_view.name = "TargetBridgeEditorProbe"
	_view.package = resource
	_view.component_name = "Main"
	_scene_root.add_child(_view)
	_view.owner = _scene_root
	for _frame in 8:
		await process_frame
	var component := _view.fairy as FGUIComponent
	var first_object := component.get_child("btn_Graph") if component != null else null
	var second_object := component.get_child("btn_Button") if component != null else null
	var first_reference := ObjectReference.from_object(component, first_object)
	var second_reference := ObjectReference.from_object(component, second_object)
	if first_reference == null or second_reference == null:
		_fail("Basics/Main did not provide stable target references.")
		return

	plugin.call("_on_preview_target_expose_requested", _view, first_reference, "btn_Graph")
	_undo_count += 1
	for _frame in 4:
		await process_frame
	var target := _find_direct_target(_view)
	if target == null or target.owner != _scene_root:
		_fail("Editor exposure did not create a scene-owned FGUITarget.")
		return
	if target.call("get_target_reference").call("get_key") != first_reference.call("get_key"):
		_fail("Created FGUITarget did not retain the selected FUI reference.")
		return
	for _frame in 8:
		await process_frame
	if _find_node_by_name(root, "FairyGUITargetInspector") == null:
		_fail("FGUITarget Inspector controls were not created.")
		return

	plugin.call("_on_preview_target_expose_requested", _view, first_reference, "btn_Graph")
	await process_frame
	if _count_direct_targets(_view) != 1:
		_fail("Repeated exposure created a duplicate FGUITarget.")
		return

	plugin.call("_on_target_rebind", target)
	plugin.call("_on_preview_target_expose_requested", _view, second_reference, "btn_Button")
	_undo_count += 1
	await process_frame
	if target.call("get_target_reference").call("get_key") != second_reference.call("get_key"):
		_fail("FGUITarget rebind did not use the selected preview object.")
		return

	var history := _scene_history()
	history.undo()
	_undo_count -= 1
	await process_frame
	if target.call("get_target_reference").call("get_key") != first_reference.call("get_key"):
		_fail("Undo did not restore the previous FGUI target reference.")
		return
	history.undo()
	_undo_count -= 1
	await process_frame
	if target.get_parent() != null:
		_fail("Undo did not remove the exposed FGUITarget.")
		return
	_cleanup()
	quit(0)


func _scene_history() -> UndoRedo:
	var manager := EditorInterface.get_editor_undo_redo()
	return manager.get_history_undo_redo(manager.get_object_history_id(_scene_root))


func _find_direct_target(view: FGUIView) -> Node:
	for child: Node in view.get_children():
		if child.get_script() == TargetScript:
			return child
	return null


func _count_direct_targets(view: FGUIView) -> int:
	var count := 0
	for child: Node in view.get_children():
		if child.get_script() == TargetScript:
			count += 1
	return count


func _find_node_by_script(node: Node, script: Script) -> Node:
	if node.get_script() == script:
		return node
	for child: Node in node.get_children():
		var found := _find_node_by_script(child, script)
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


func _cleanup() -> void:
	if _scene_root != null:
		var history := _scene_history()
		while _undo_count > 0 and history.has_undo():
			history.undo()
			_undo_count -= 1
	if _view != null:
		_view.queue_free()
		_view = null


func _fail(message: String) -> void:
	push_error(message)
	_cleanup()
	quit(1)
