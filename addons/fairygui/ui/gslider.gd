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
		if _grip_object != null:
			_grip_object.draggable = value
			if not value and _grip_object.dragging:
				_grip_object.stop_drag()
		if not value:
			_dragging_grip = false
var _grip_object: FGUIObject
var _dragging_grip: bool = false
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
		_grip_object.draggable = can_drag
		_grip_object.on(FGUIEvents.DRAG_START, _on_grip_drag_start)
		_grip_object.on(FGUIEvents.DRAG_MOVE, _on_grip_drag_move)
		_grip_object.on(FGUIEvents.DRAG_END, _on_grip_drag_end)
	update(_value)


func _on_grip_drag_start(event: Variant = null) -> void:
	if not can_drag:
		return
	_dragging_grip = true
	_grip_drag_start_position = _global_to_node_local(FGUIToolSet.get_pointer_position(event)) if event is InputEvent else Vector2.ZERO
	_drag_start_percent = FGUIToolSet.clamp01((_value - min) / (max - min)) if not is_zero_approx(max - min) else 0.0


func _on_grip_drag_move(event: Variant = null) -> void:
	if not can_drag or not _dragging_grip:
		return
	var local := _global_to_node_local(FGUIToolSet.get_pointer_position(event)) if event is InputEvent else Vector2.ZERO
	var delta := local.x - _grip_drag_start_position.x if _bar_object_h != null else local.y - _grip_drag_start_position.y
	if reverse:
		delta = -delta
	var percent := _drag_start_percent + delta / _get_bar_length()
	_set_value_by_percent(percent, event)


func _on_grip_drag_end(_event: Variant = null) -> void:
	_dragging_grip = false


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
		update(_value)
		emit_event(FGUIEvents.STATE_CHANGED, event)


func _get_bar_length() -> float:
	return maxf(1.0, width - _bar_max_width_delta) if _bar_object_h != null else maxf(1.0, height - _bar_max_height_delta)
