class_name FGUIProgressBar
extends FGUIComponent

var title_type: int = FGUIEnums.PROGRESS_TITLE_PERCENT:
	set(next_value):
		if title_type == next_value:
			return
		title_type = next_value
		update(_value)
var reverse: bool = false:
	set(next_value):
		if reverse == next_value:
			return
		reverse = next_value
		update(_value)
var min: float = 0.0:
	set(next_value):
		if is_equal_approx(min, next_value):
			return
		min = next_value
		update(_value)
var max: float = 100.0:
	set(next_value):
		if is_equal_approx(max, next_value):
			return
		max = next_value
		update(_value)
var value: float:
	get:
		return _value
	set(next_value):
		if is_equal_approx(_value, next_value):
			return
		FGUIGTween.kill(self, false, Callable(self, "update"))
		_value = next_value
		update(_value)

var _value: float = 50.0
var _title_object: FGUIObject
var _bar_object_h: FGUIObject
var _bar_object_v: FGUIObject
var _ani_object: FGUIObject
var _bar_max_width_delta: float = 0.0
var _bar_max_height_delta: float = 0.0
var _bar_start_x: float = 0.0
var _bar_start_y: float = 0.0


func construct_extension(buffer: FGUIByteBuffer) -> void:
	if buffer.seek(0, 6):
		title_type = buffer.read_i8()
		reverse = buffer.read_bool()
	_title_object = get_child("title")
	_bar_object_h = get_child("bar")
	_bar_object_v = get_child("bar_v")
	_ani_object = get_child("ani")
	if _bar_object_h != null:
		_bar_max_width_delta = width - _bar_object_h.width
		_bar_start_x = _bar_object_h.x
	if _bar_object_v != null:
		_bar_max_height_delta = height - _bar_object_v.height
		_bar_start_y = _bar_object_v.y
	update(_value)


func tween_value(next_value: float, duration: float) -> FGUIGTweener:
	var update_callback := Callable(self, "update")
	var old_value := _value
	var active_tween := FGUIGTween.get_tween(self, update_callback)
	if active_tween != null:
		old_value = active_tween.value.x
		active_tween.kill()
	_value = next_value
	return FGUIGTween.to(old_value, _value, duration).set_target(self, update_callback).set_ease(FGUIEaseType.LINEAR)


func update(new_value: float) -> void:
	var range_value := max - min
	var percent := FGUIToolSet.clamp01((new_value - min) / range_value) if not is_zero_approx(range_value) else 0.0
	if _title_object != null:
		match title_type:
			FGUIEnums.PROGRESS_TITLE_PERCENT:
				_title_object.set_text("%d%%" % int(floor(percent * 100.0)))
			FGUIEnums.PROGRESS_TITLE_VALUE_AND_MAX:
				_title_object.set_text("%d/%d" % [int(floor(new_value)), int(floor(max))])
			FGUIEnums.PROGRESS_TITLE_VALUE:
				_title_object.set_text(str(int(floor(new_value))))
			FGUIEnums.PROGRESS_TITLE_MAX:
				_title_object.set_text(str(int(floor(max))))
	var full_width := width - _bar_max_width_delta
	var full_height := height - _bar_max_height_delta
	var fill_percent := 1.0 - percent if reverse else percent
	if _bar_object_h != null:
		if not _set_fill_amount(_bar_object_h, fill_percent):
			_bar_object_h.width = round(full_width * percent)
			if reverse:
				_bar_object_h.x = _bar_start_x + (full_width - _bar_object_h.width)
	if _bar_object_v != null:
		if not _set_fill_amount(_bar_object_v, fill_percent):
			_bar_object_v.height = round(full_height * percent)
			if reverse:
				_bar_object_v.y = _bar_start_y + (full_height - _bar_object_v.height)
	if _ani_object != null:
		_ani_object.set_prop(FGUIEnums.OBJECT_PROP_FRAME, int(fill_percent * 100.0))


func _set_fill_amount(bar: FGUIObject, percent: float) -> bool:
	if bar is FGUIImage and (bar as FGUIImage).fill_method != FGUIEnums.FILL_NONE:
		(bar as FGUIImage).fill_amount = percent
		return true
	if bar is FGUILoader and (bar as FGUILoader).fill_method != FGUIEnums.FILL_NONE:
		(bar as FGUILoader).fill_amount = percent
		return true
	return false


func _handle_size_changed() -> void:
	super._handle_size_changed()
	if not _under_construct:
		update(_value)


func dispose() -> void:
	FGUIGTween.kill(self, false, Callable(self, "update"))
	_title_object = null
	_bar_object_h = null
	_bar_object_v = null
	_ani_object = null
	super.dispose()


func setup_after_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_after_add(buffer, begin_pos)
	if buffer.seek(begin_pos, 6) and buffer.read_i8() == package_item.object_type:
		_value = buffer.read_i32()
		max = buffer.read_i32()
		if buffer.version >= 2:
			min = buffer.read_i32()
		if buffer.version >= 5:
			var click_sound = buffer.read_s()
			var click_sound_volume := buffer.read_float32()
			_set_click_sound(click_sound, click_sound_volume)
	update(_value)
