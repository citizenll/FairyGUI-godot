class_name FGUIEventDispatcher
extends RefCounted

const EventContextClass := preload("res://addons/fairygui/core/event_context.gd")
const InputEventClass := preload("res://addons/fairygui/core/input_event.gd")
const NATIVE_RECIPIENTS_META := &"_fgui_event_recipients"
const EVENT_ALIASES := {
	"click": "onClick",
	"fui_state_changed": "onChanged",
	"fui_xy_changed": "onPositionChanged",
	"fui_size_changed": "onSizeChanged",
	"fui_click_item": "onClickItem",
	"fui_scroll": "onScroll",
	"fui_scroll_end": "onScrollEnd",
	"fui_drop": "onDrop",
	"fui_drag_start": "onDragStart",
	"fui_drag_move": "onDragMove",
	"fui_drag_end": "onDragEnd",
	"fui_pull_down_release": "onPullDownRelease",
	"fui_pull_up_release": "onPullUpRelease",
	"fui_gear_stop": "onGearStop",
}

var _event_bridges: Dictionary = {}


func on(event_name: String, callable: Callable) -> void:
	_add_event_callback(_normalize_event_name(event_name), callable, true)


func off(event_name: String, callable: Callable) -> void:
	_remove_event_callback(_normalize_event_name(event_name), callable, true)


func add_event_listener(event_name: String, callable: Callable) -> void:
	_add_event_callback(_normalize_event_name(event_name), callable, false)


func remove_event_listener(event_name: String, callable: Callable) -> void:
	_remove_event_callback(_normalize_event_name(event_name), callable, false)


func add_capture(event_name: String, callable: Callable) -> void:
	event_name = _normalize_event_name(event_name)
	if event_name == "" or not callable.is_valid():
		return
	var bridge := _get_event_bridge(event_name)
	var captures: Array = bridge["captures"]
	captures.erase(callable)
	captures.append(callable)


func remove_capture(event_name: String, callable: Callable) -> void:
	event_name = _normalize_event_name(event_name)
	var bridge := _try_get_event_bridge(event_name)
	if bridge.is_empty():
		return
	(bridge["captures"] as Array).erase(callable)


func remove_event_listeners(event_name: String = "") -> void:
	if event_name != "":
		event_name = _normalize_event_name(event_name)
		var bridge := _try_get_event_bridge(event_name)
		if not bridge.is_empty():
			(bridge["listeners"] as Array).clear()
			(bridge["captures"] as Array).clear()
		return
	for bridge: Dictionary in _event_bridges.values():
		(bridge["listeners"] as Array).clear()
		(bridge["captures"] as Array).clear()


func has_event_listener(event_name: String) -> bool:
	event_name = _normalize_event_name(event_name)
	var bridge := _try_get_event_bridge(event_name)
	return not bridge.is_empty() and (not (bridge["listeners"] as Array).is_empty() or not (bridge["captures"] as Array).is_empty())


func has_event_listeners(event_name: String) -> bool:
	return has_event_listener(event_name)


func is_dispatching(event_name: String) -> bool:
	event_name = _normalize_event_name(event_name)
	var bridge := _try_get_event_bridge(event_name)
	return not bridge.is_empty() and bool(bridge["dispatching"])


func emit_event(event_name: String, data: Variant = null) -> bool:
	return dispatch_event(event_name, data)


func dispatch_event(event_name: String, data: Variant = null, initiator: Variant = null) -> bool:
	event_name = _normalize_event_name(event_name)
	var context := _new_event_context(event_name, data, initiator)
	_dispatch_to_self(context, true)
	var prevented: bool = context.is_default_prevented
	EventContextClass.release(context)
	return prevented


func dispatch_event_context(context: Variant) -> bool:
	if context == null:
		return false
	context.type = _normalize_event_name(context.type)
	var saved_sender: Variant = context.sender
	_dispatch_to_self(context, true)
	context.sender = saved_sender
	return context.is_default_prevented


func bubble_event(event_name: String, data: Variant = null) -> bool:
	event_name = _normalize_event_name(event_name)
	var context := _new_event_context(event_name, data, self)
	var chain: Array = []
	var current: Variant = self
	while current != null:
		if current.has_event_listener(event_name):
			chain.append(current)
		current = current._get_event_parent()
	for index in range(chain.size() - 1, -1, -1):
		chain[index]._dispatch_capture(context)
		chain[index]._consume_touch_capture(context)
	if not context._stops_propagation:
		for dispatcher in chain:
			dispatcher._dispatch_listeners(context)
			dispatcher._consume_touch_capture(context)
			if context._stops_propagation:
				break
	var prevented: bool = context.is_default_prevented
	EventContextClass.release(context)
	return prevented


func broadcast_event(event_name: String, data: Variant = null) -> bool:
	event_name = _normalize_event_name(event_name)
	var context := _new_event_context(event_name, data, self)
	var targets: Array = []
	_collect_event_descendants(event_name, targets)
	for dispatcher in targets:
		dispatcher._dispatch_listeners(context)
	var prevented: bool = context.is_default_prevented
	EventContextClass.release(context)
	return prevented


func _get_event_parent() -> Variant:
	return null


func _get_event_children() -> Array:
	return []


func _consume_touch_capture(context: Variant) -> void:
	if not context._touch_capture:
		return
	context._touch_capture = false
	_handle_touch_capture(context)


func _handle_touch_capture(_context: Variant) -> void:
	pass


func _collect_event_descendants(event_name: String, result: Array) -> void:
	if has_event_listener(event_name):
		result.append(self)
	for child in _get_event_children():
		if child != null and child.has_method("_collect_event_descendants"):
			child._collect_event_descendants(event_name, result)


func _dispatch_to_self(context: Variant, include_capture: bool) -> void:
	if include_capture:
		_dispatch_capture(context)
	_dispatch_listeners(context)
	_consume_touch_capture(context)


func _dispatch_capture(context: Variant) -> void:
	var bridge := _try_get_event_bridge(context.type)
	if bridge.is_empty():
		return
	bridge["dispatching"] = true
	context.sender = self
	_mark_native_event_recipient(context)
	for callable: Callable in (bridge["captures"] as Array).duplicate():
		_call_context_callback(callable, context)
	bridge["dispatching"] = false


func _dispatch_listeners(context: Variant) -> void:
	var bridge := _try_get_event_bridge(context.type)
	if bridge.is_empty():
		return
	bridge["dispatching"] = true
	context.sender = self
	_mark_native_event_recipient(context)
	for entry: Dictionary in (bridge["listeners"] as Array).duplicate(true):
		var callable: Callable = entry["callback"]
		if not callable.is_valid():
			continue
		if bool(entry["legacy"]):
			_call_legacy_callback(callable, context.data)
		else:
			_call_context_callback(callable, context)
	bridge["dispatching"] = false


func _call_legacy_callback(callable: Callable, data: Variant) -> void:
	if callable.get_argument_count() == 0:
		callable.call()
	else:
		callable.call(data)


func _call_context_callback(callable: Callable, context: Variant) -> void:
	if not callable.is_valid():
		return
	if callable.get_argument_count() == 0:
		callable.call()
	else:
		callable.call(context)


func _add_event_callback(event_name: String, callable: Callable, legacy: bool) -> void:
	if event_name == "" or not callable.is_valid():
		return
	var bridge := _get_event_bridge(event_name)
	var listeners: Array = bridge["listeners"]
	for index in range(listeners.size() - 1, -1, -1):
		var entry: Dictionary = listeners[index]
		if entry["callback"] == callable and bool(entry["legacy"]) == legacy:
			listeners.remove_at(index)
	listeners.append({"callback": callable, "legacy": legacy})


func _remove_event_callback(event_name: String, callable: Callable, legacy: bool) -> void:
	var bridge := _try_get_event_bridge(event_name)
	if bridge.is_empty():
		return
	var listeners: Array = bridge["listeners"]
	for index in range(listeners.size() - 1, -1, -1):
		var entry: Dictionary = listeners[index]
		if entry["callback"] == callable and bool(entry["legacy"]) == legacy:
			listeners.remove_at(index)


func _get_event_bridge(event_name: String) -> Dictionary:
	if not _event_bridges.has(event_name):
		_event_bridges[event_name] = {
			"listeners": [],
			"captures": [],
			"dispatching": false,
		}
	return _event_bridges[event_name]


func _try_get_event_bridge(event_name: String) -> Dictionary:
	return _event_bridges.get(event_name, {})


func _new_event_context(event_name: String, data: Variant, initiator: Variant) -> Variant:
	if data is InputEventClass:
		InputEventClass.current = data
	elif data is InputEvent:
		InputEventClass.current = InputEventClass.new(data)
	var context := EventContextClass.obtain()
	context.type = event_name
	context.data = data
	context.initiator = initiator if initiator != null else self
	context.input_event = InputEventClass.current
	if context.input_event != null and context.input_event.native_event != null:
		context.native_event_id = context.input_event.native_event.get_instance_id()
	return context


func _normalize_event_name(event_name: String) -> String:
	return EVENT_ALIASES.get(event_name, event_name)


func _mark_native_event_recipient(context: Variant) -> void:
	if context.input_event == null or context.input_event.native_event == null:
		return
	var native_event: InputEvent = context.input_event.native_event
	var by_name: Dictionary = native_event.get_meta(NATIVE_RECIPIENTS_META, {})
	if not by_name.has(context.type):
		by_name[context.type] = {}
	var recipients: Dictionary = by_name[context.type]
	recipients[get_instance_id()] = true
	native_event.set_meta(NATIVE_RECIPIENTS_META, by_name)


static func was_native_event_dispatched(native_event: InputEvent, event_name: String, dispatcher: Variant) -> bool:
	if native_event == null or dispatcher == null:
		return false
	var by_name: Dictionary = native_event.get_meta(NATIVE_RECIPIENTS_META, {})
	var recipients: Dictionary = by_name.get(event_name, {})
	return recipients.has(dispatcher.get_instance_id())
