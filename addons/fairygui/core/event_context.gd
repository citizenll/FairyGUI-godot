class_name FGUIEventContext
extends RefCounted

static var _pool: Array[FGUIEventContext] = []

var sender: Variant
var initiator: Variant
var input_event: Variant
var type: String = ""
var data: Variant
var native_event_id: int = -1
var _default_prevented: bool = false
var _stops_propagation: bool = false
var _touch_capture: bool = false

var inputEvent: Variant:
	get:
		return input_event
var is_default_prevented: bool:
	get:
		return _default_prevented
var isDefaultPrevented: bool:
	get:
		return _default_prevented


func stop_propagation() -> void:
	_stops_propagation = true


func prevent_default() -> void:
	_default_prevented = true


func capture_touch() -> void:
	_touch_capture = true


func StopPropagation() -> void:
	stop_propagation()


func PreventDefault() -> void:
	prevent_default()


func CaptureTouch() -> void:
	capture_touch()


static func obtain() -> FGUIEventContext:
	var context := _pool.pop_back() if not _pool.is_empty() else FGUIEventContext.new()
	context._default_prevented = false
	context._stops_propagation = false
	context._touch_capture = false
	return context


static func release(context: FGUIEventContext) -> void:
	if context == null:
		return
	context.sender = null
	context.initiator = null
	context.input_event = null
	context.type = ""
	context.data = null
	context.native_event_id = -1
	if _pool.size() < 64:
		_pool.append(context)
