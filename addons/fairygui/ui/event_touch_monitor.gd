class_name FGUIEventTouchMonitor
extends Node

const EventDispatcherClass := preload("res://addons/fairygui/core/event_dispatcher.gd")

static var _instance: Variant

var _captures: Dictionary = {}


static func capture(target: Variant, pointer_id: int) -> void:
	if target == null or target.node == null or not target.node.is_inside_tree():
		return
	var tree: SceneTree = target.node.get_tree()
	if tree == null or tree.root == null:
		return
	if _instance == null or not is_instance_valid(_instance) or _instance.is_queued_for_deletion():
		_instance = load("res://addons/fairygui/ui/event_touch_monitor.gd").new()
		tree.root.add_child(_instance)
	var targets: Array = _instance._captures.get(pointer_id, [])
	if not targets.has(target):
		targets.append(target)
	_instance._captures[pointer_id] = targets


static func release(target: Variant) -> void:
	if _instance == null or not is_instance_valid(_instance):
		return
	for pointer_id in _instance._captures.keys():
		var targets: Array = _instance._captures[pointer_id]
		targets.erase(target)
		if targets.is_empty():
			_instance._captures.erase(pointer_id)
	if _instance._captures.is_empty():
		_instance.queue_free()


func _ready() -> void:
	set_process_input(true)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _input(event: InputEvent) -> void:
	if not FGUIToolSet.is_pointer_motion(event) and not FGUIToolSet.is_primary_pointer_release(event):
		return
	var pointer_id := FGUIToolSet.get_pointer_id(event)
	if not _captures.has(pointer_id):
		return
	var targets: Array = (_captures[pointer_id] as Array).duplicate()
	var release_pointer := FGUIToolSet.is_primary_pointer_release(event)
	_dispatch_captured.call_deferred(event, pointer_id, targets, release_pointer)


func _dispatch_captured(event: InputEvent, pointer_id: int, targets: Array, release_pointer: bool) -> void:
	var event_name := FGUIEvents.TOUCH_END if release_pointer else FGUIEvents.TOUCH_MOVE
	for target in targets:
		if target == null or not is_instance_valid(target) or target.is_disposed:
			continue
		if not EventDispatcherClass.was_native_event_dispatched(event, event_name, target):
			target.dispatch_event(event_name, event, target)
	if release_pointer:
		_captures.erase(pointer_id)
	if _captures.is_empty():
		queue_free()
