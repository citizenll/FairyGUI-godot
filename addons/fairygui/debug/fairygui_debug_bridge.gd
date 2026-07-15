extends Node

const RuntimeOverlay := preload("res://addons/fairygui/debug/fairygui_runtime_debug_overlay.gd")
const BRIDGE_NAME := "FairyGUIDebugBridge"
const VIEW_GROUP := "_fairygui_runtime_views"
const BRIDGE_PENDING_META := "_fairygui_debug_bridge_pending"

var _overlay: Control
var _selected_object: FGUIObject
var _capture_registered: bool = false


static func ensure_in_tree(tree: SceneTree) -> void:
	if tree == null or not EngineDebugger.is_active():
		return
	if tree.root.get_node_or_null(BRIDGE_NAME) != null or bool(tree.root.get_meta(BRIDGE_PENDING_META, false)):
		return
	tree.root.set_meta(BRIDGE_PENDING_META, true)
	var bridge_script := load("res://addons/fairygui/debug/fairygui_debug_bridge.gd") as Script
	var bridge := bridge_script.new() as Node
	bridge.name = BRIDGE_NAME
	tree.root.call_deferred("add_child", bridge)


func _ready() -> void:
	get_tree().root.remove_meta(BRIDGE_PENDING_META)
	if not EngineDebugger.is_active():
		queue_free()
		return
	if not EngineDebugger.has_capture("fairygui"):
		EngineDebugger.register_message_capture("fairygui", Callable(self, "_capture_message"))
		_capture_registered = true
	_create_overlay()
	call_deferred("send_snapshot")


func _exit_tree() -> void:
	if _capture_registered and EngineDebugger.has_capture("fairygui"):
		EngineDebugger.unregister_message_capture("fairygui")


func _capture_message(message: String, data: Array) -> bool:
	match message:
		"request_tree":
			call_deferred("send_snapshot")
			return true
		"select":
			var object_id := int(data[0]) if not data.is_empty() else 0
			select_object(object_id)
			return true
	return false


func send_snapshot() -> void:
	if not EngineDebugger.is_active() or not is_inside_tree():
		return
	var views: Array = []
	var object_count := 0
	for node: Node in get_tree().get_nodes_in_group(VIEW_GROUP):
		if not node is FGUIView:
			continue
		var view := node as FGUIView
		var fairy := view.get_fairy_object()
		if fairy == null:
			continue
		var serialized := _serialize_object(fairy)
		object_count += int(serialized.get("object_count", 0))
		views.append({
			"name": str(view.name),
			"node_path": str(view.get_path()),
			"package_path": view.package.get_source_path() if view.package != null else "",
			"component_name": view.component_name,
			"root": serialized,
		})
	EngineDebugger.send_message("fairygui:tree", [{
		"views": views,
		"view_count": views.size(),
		"object_count": object_count,
	}])


func build_snapshot() -> Dictionary:
	var views: Array = []
	var object_count := 0
	if get_tree() == null:
		return {"views": views, "view_count": 0, "object_count": 0}
	for node: Node in get_tree().get_nodes_in_group(VIEW_GROUP):
		if node is FGUIView and (node as FGUIView).get_fairy_object() != null:
			var view := node as FGUIView
			var serialized := _serialize_object(view.get_fairy_object())
			object_count += int(serialized.get("object_count", 0))
			views.append({
				"name": str(view.name),
				"node_path": str(view.get_path()),
				"package_path": view.package.get_source_path() if view.package != null else "",
				"component_name": view.component_name,
				"root": serialized,
			})
	return {"views": views, "view_count": views.size(), "object_count": object_count}


func select_object(object_id: int) -> bool:
	_selected_object = null
	if object_id != 0 and get_tree() != null:
		for node: Node in get_tree().get_nodes_in_group(VIEW_GROUP):
			if node is FGUIView:
				_selected_object = _find_object((node as FGUIView).get_fairy_object(), object_id)
				if _selected_object != null:
					break
	if _overlay != null:
		_overlay.call("set_target", _selected_object)
	return _selected_object != null


func _create_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FairyGUIDebugOverlayLayer"
	layer.layer = 4096
	add_child(layer)
	_overlay = RuntimeOverlay.new()
	_overlay.name = "Selection"
	layer.add_child(_overlay)


func _serialize_object(value: FGUIObject) -> Dictionary:
	var children: Array = []
	var object_count := 1
	if value is FGUIComponent:
		for child: FGUIObject in (value as FGUIComponent).children:
			var serialized_child := _serialize_object(child)
			object_count += int(serialized_child.get("object_count", 0))
			children.append(serialized_child)
	return {
		"object_id": value.get_instance_id(),
		"name": value.name if value.name != "" else value.id,
		"type": _object_type_name(value),
		"x": value.x,
		"y": value.y,
		"width": value.width,
		"height": value.height,
		"visible": value.visible,
		"children": children,
		"object_count": object_count,
	}


func _find_object(value: FGUIObject, object_id: int) -> FGUIObject:
	if value == null:
		return null
	if value.get_instance_id() == object_id:
		return value
	if value is FGUIComponent:
		for child: FGUIObject in (value as FGUIComponent).children:
			var found := _find_object(child, object_id)
			if found != null:
				return found
	return null


func _object_type_name(value: FGUIObject) -> String:
	var script := value.get_script() as Script
	if script != null and script.get_global_name() != "":
		return script.get_global_name()
	if value.package_item != null and value.package_item.name != "":
		return value.package_item.name
	return value.get_class()
