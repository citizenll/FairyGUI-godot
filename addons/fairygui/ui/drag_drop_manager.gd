class_name FGUIDragDropManager
extends RefCounted

static var inst: FGUIDragDropManager

var agent: FGUILoader
var source_data: Variant
var source: FGUIObject

var drag_agent: FGUILoader:
	get:
		return agent
var dragging: bool:
	get:
		return agent != null and agent.parent != null


func _init() -> void:
	agent = FGUILoader.new()
	agent.name = "DragDropAgent"
	agent.draggable = true
	agent.touchable = false
	agent.set_size(100.0, 100.0)
	agent.set_pivot(0.5, 0.5, true)
	agent.sorting_order = 1000000
	agent.on(FGUIEvents.DRAG_END, Callable(self, "_on_drag_end"))
	inst = self


static func get_inst() -> FGUIDragDropManager:
	if inst == null:
		inst = FGUIDragDropManager.new()
	return inst


func start_drag(source: FGUIObject, icon: String, data: Variant = null, touch_point_id: int = -1) -> void:
	if dragging:
		return
	var target_root: FGUIRoot = source.root if source != null else FGUIRoot.get_inst()
	if target_root == null:
		return
	source_data = data
	self.source = source
	agent.url = icon
	target_root.add_child(agent)
	var root_position := target_root.global_to_local(FGUIObject.get_last_pointer_position())
	agent.set_xy(root_position.x, root_position.y)
	agent.start_drag(touch_point_id)


func cancel() -> void:
	if not dragging:
		return
	agent.stop_drag()
	agent.remove_from_parent()
	source_data = null
	source = null


func dispose() -> void:
	cancel()
	if agent != null:
		agent.off(FGUIEvents.DRAG_END, Callable(self, "_on_drag_end"))
		agent.dispose()
		agent = null
	source_data = null
	source = null
	if inst == self:
		inst = null


func _on_drag_end(event: Variant = null) -> void:
	if not dragging:
		return
	var target_root := agent.root
	if target_root != null:
		target_root.remove_child(agent)
	var payload := {
		"data": source_data,
		"source": source,
		"event": event,
	}
	source_data = null
	source = null
	var drop_target := _find_drop_target(target_root, FGUIObject.get_last_pointer_position())
	while drop_target != null:
		if drop_target.has_event_listener(FGUIEvents.DROP):
			if target_root != null:
				target_root.focus = drop_target
			drop_target.emit_event(FGUIEvents.DROP, payload)
			return
		drop_target = drop_target.parent


func _find_drop_target(target_root: FGUIRoot, global_position: Vector2) -> FGUIObject:
	if target_root == null:
		return null
	if target_root.node != null and target_root.node.get_viewport() != null:
		var hovered := target_root.node.get_viewport().gui_get_hovered_control()
		var hovered_object := FGUIToolSet.display_object_to_gobject(hovered)
		if hovered_object != null and hovered_object != agent:
			return hovered_object
	return _find_object_at(target_root, global_position)


func _find_object_at(component: FGUIComponent, global_position: Vector2) -> FGUIObject:
	for index in range(component.num_children - 1, -1, -1):
		var child := component.get_child_at(index)
		if child == null or child == agent or child.node == null or not child.internal_visible2:
			continue
		if child is FGUIComponent:
			var nested := _find_object_at(child as FGUIComponent, global_position)
			if nested != null:
				return nested
		if child.node.get_global_rect().has_point(global_position):
			return child
	return component if component.node != null and component.node.get_global_rect().has_point(global_position) else null
