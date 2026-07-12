class_name FGUISlider
extends FGUIProgressBar

var whole_numbers: bool = false:
	set(value):
		if whole_numbers == value:
			return
		whole_numbers = value
		update(_value)
var change_on_click: bool = true
var can_drag: bool = true:
	set(value):
		can_drag = value
		if not value:
			_dragging_grip = false
			if _grip_object != null:
				FGUIEventTouchMonitor.release(_grip_object)
var _grip_object: FGUIObject
var _dragging_grip: bool = false
var _grip_pointer_moved: bool = false
var _grip_drag_start_position := Vector2.ZERO
var _drag_start_percent: float = 0.0


func construct_extension(buffer: FGUIByteBuffer) -> void:
	if buffer.seek(0, 6):
		title_type = buffer.read_i8()
		reverse = buffer.read_bool()
		if buffer.version >= 2:
			whole_numbers = buffer.read_bool()
			change_on_click = buffer.read_bool()
	_title_object = get_child("title")
	_bar_object_h = get_child("bar")
	_bar_object_v = get_child("bar_v")
	_grip_object = get_child("grip")
	if _bar_object_h != null:
		_bar_max_width_delta = width - _bar_object_h.width
		_bar_start_x = _bar_object_h.x
	if _bar_object_v != null:
		_bar_max_height_delta = height - _bar_object_v.height
		_bar_start_y = _bar_object_v.y
	if _grip_object != null:
		# A slider grip reports pointer deltas, but must never use GObject's free drag.
		_grip_object.draggable = false
		_grip_object.add_event_listener(FGUIEvents.TOUCH_BEGIN, _on_grip_touch_begin)
		_grip_object.add_event_listener(FGUIEvents.TOUCH_MOVE, _on_grip_touch_move)
		_grip_object.add_event_listener(FGUIEvents.TOUCH_END, _on_grip_touch_end)
	update(_value)


func _on_grip_touch_begin(context: FGUIEventContext) -> void:
	if not can_drag or context == null or context.input_event == null:
		return
	var native_event: InputEvent = context.input_event.native_event
	if native_event is InputEventMouseButton and native_event.button_index != MOUSE_BUTTON_LEFT:
		return
	context.stop_propagation()
	context.capture_touch()
	_dragging_grip = true
	_grip_pointer_moved = false
	_grip_object._drag_click_suppressed = false
	_grip_drag_start_position = _global_to_node_local(context.input_event.position)
	_drag_start_percent = FGUIToolSet.clamp01((_value - min) / (max - min)) if not is_zero_approx(max - min) else 0.0


func _on_grip_touch_move(context: FGUIEventContext) -> void:
	if not can_drag or not _dragging_grip or context == null or context.input_event == null:
		return
	var local := _global_to_node_local(context.input_event.position)
	var delta := local.x - _grip_drag_start_position.x if _bar_object_h != null else local.y - _grip_drag_start_position.y
	if reverse:
		delta = -delta
	_grip_pointer_moved = _grip_pointer_moved or not is_zero_approx(delta)
	var percent := _drag_start_percent + delta / _get_bar_length()
	_set_value_by_percent(percent, context.data)


func _on_grip_touch_end(context: FGUIEventContext = null) -> void:
	if not _dragging_grip:
		return
	_dragging_grip = false
	if _grip_object != null:
		_grip_object._drag_testing = false
		_grip_object._drag_pointer_active = false
		_grip_object._drag_touch_index = -1
		_grip_object._drag_click_suppressed = _grip_pointer_moved
	if _grip_object is FGUIButton:
		var button := _grip_object as FGUIButton
		button._down = false
		button._button_touch_index = -2
		button._refresh_button_state()
	emit_event(FGUIEvents.GRIP_TOUCH_END, context.data if context != null else null)
	_grip_pointer_moved = false


func _on_gui_input(event: InputEvent) -> void:
	super._on_gui_input(event)
	if change_on_click and FGUIToolSet.is_primary_pointer_press(event):
		var pointer_position := FGUIToolSet.get_pointer_position(event)
		if _grip_object != null and _grip_object.node != null and _grip_object.node.get_global_rect().has_point(pointer_position):
			return
		var current_percent := FGUIToolSet.clamp01((_value - min) / (max - min)) if not is_zero_approx(max - min) else 0.0
		var percent: float
		if _grip_object != null:
			var grip_local := _grip_object._global_to_node_local(pointer_position)
			var delta := grip_local.x if _bar_object_h != null else grip_local.y
			percent = current_percent + (-delta if reverse else delta) / _get_bar_length()
		else:
			var local := _global_to_node_local(pointer_position)
			var coordinate := local.x - _bar_start_x if _bar_object_h != null else local.y - _bar_start_y
			percent = coordinate / _get_bar_length()
			if reverse:
				percent = 1.0 - percent
		_set_value_by_percent(percent, event)


func _set_value_by_percent(percent: float, event: Variant = null) -> void:
	percent = FGUIToolSet.clamp01(percent)
	var next_value := min + (max - min) * percent
	if whole_numbers:
		next_value = round(next_value)
	if not is_equal_approx(next_value, _value):
		_value = next_value
		if emit_event(FGUIEvents.STATE_CHANGED, event):
			return
		update(_value)


func _get_bar_length() -> float:
	return maxf(1.0, width - _bar_max_width_delta) if _bar_object_h != null else maxf(1.0, height - _bar_max_height_delta)


func dispose() -> void:
	if _grip_object != null:
		FGUIEventTouchMonitor.release(_grip_object)
	_grip_object = null
	_dragging_grip = false
	_grip_pointer_moved = false
	super.dispose()
