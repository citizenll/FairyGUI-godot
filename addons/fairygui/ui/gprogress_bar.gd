class_name FGUIProgressBar
extends FGUIComponent

var title_type: int = FGUIEnums.PROGRESS_TITLE_PERCENT
var reverse: bool = false
var min: float = 0.0:
	set(value):
		min = value
		update(value)
var max: float = 100.0:
	set(value):
		max = value
		update(_value)
var value: float:
	get:
		return _value
	set(next_value):
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
		_bar_object_h.width = round(full_width * percent)
		if reverse:
			_bar_object_h.x = _bar_start_x + (full_width - _bar_object_h.width)
	if _bar_object_v != null:
		_bar_object_v.height = round(full_height * percent)
		if reverse:
			_bar_object_v.y = _bar_start_y + (full_height - _bar_object_v.height)
	if _ani_object != null:
		_ani_object.set_prop(FGUIEnums.OBJECT_PROP_FRAME, int(fill_percent * 100.0))


func setup_after_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_after_add(buffer, begin_pos)
	if buffer.seek(begin_pos, 6) and buffer.read_i8() == package_item.object_type:
		_value = buffer.read_i32()
		max = buffer.read_i32()
		if buffer.version >= 2:
			min = buffer.read_i32()
	update(_value)
