@tool
class_name FGUIEventBinding
extends Resource

var _enabled: bool = true
var _target_path := PackedStringArray()
var _event_name: String = FGUIEvents.CLICK
var _handler: StringName
var _capture: bool = false

@export var enabled: bool:
	get:
		return _enabled
	set(value):
		if _enabled == value:
			return
		_enabled = value
		emit_changed()

@export var target_path: PackedStringArray:
	get:
		return _target_path
	set(value):
		if _target_path == value:
			return
		_target_path = value.duplicate()
		emit_changed()

@export var event_name: String:
	get:
		return _event_name
	set(value):
		if _event_name == value:
			return
		_event_name = value
		emit_changed()

@export var handler: StringName:
	get:
		return _handler
	set(value):
		if _handler == value:
			return
		_handler = value
		emit_changed()

@export var capture: bool:
	get:
		return _capture
	set(value):
		if _capture == value:
			return
		_capture = value
		emit_changed()


func _init() -> void:
	resource_local_to_scene = true


func resolve_target(root: FGUIObject) -> FGUIEventDispatcher:
	var current: FGUIObject = root
	for segment: String in _target_path:
		if not current is FGUIComponent:
			return null
		current = (current as FGUIComponent).get_child(segment)
		if current == null:
			return null
	return current as FGUIEventDispatcher


func get_target_label() -> String:
	return "ui" if _target_path.is_empty() else "/".join(_target_path)


func get_key() -> String:
	return "%s\n%s\n%s\n%s" % [
		JSON.stringify(Array(_target_path)),
		_event_name,
		_handler,
		_capture,
	]
