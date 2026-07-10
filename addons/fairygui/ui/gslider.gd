class_name FGUISlider
extends FGUIProgressBar

var whole_numbers: bool = false
var change_on_click: bool = true
var can_drag: bool = true
var _grip_object: FGUIObject
var _dragging_grip: bool = false


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
		_grip_object.draggable = true
		_grip_object.on(FGUIEvents.DRAG_MOVE, _on_grip_drag_move)
	update(_value)


func _on_grip_drag_move(event: Variant = null) -> void:
	if not can_drag:
		return
	var local := _global_to_node_local(FGUIToolSet.get_pointer_position(event)) if event is InputEvent else Vector2.ZERO
	var percent := local.x / maxf(1.0, width) if _bar_object_h != null else local.y / maxf(1.0, height)
	if reverse:
		percent = 1.0 - percent
	_set_value_by_percent(percent, event)


func _on_gui_input(event: InputEvent) -> void:
	super._on_gui_input(event)
	if change_on_click and FGUIToolSet.is_primary_pointer_press(event):
		var local := _global_to_node_local(FGUIToolSet.get_pointer_position(event))
		var percent := local.x / maxf(1.0, width) if _bar_object_h != null else local.y / maxf(1.0, height)
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
