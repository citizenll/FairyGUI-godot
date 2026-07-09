class_name FGUITextField
extends FGUIObject

var label
var _font_size: int = 14
var _color: Color = Color.BLACK
var font_size: int:
	get:
		return _font_size
	set(value):
		_font_size = value
		_apply_font_size()
var color: Color:
	get:
		return _color
	set(value):
		_color = value
		_apply_font_color()
var align: int = FGUIEnums.ALIGN_LEFT
var valign: int = FGUIEnums.VERT_ALIGN_TOP
var auto_size: int = FGUIEnums.AUTOSIZE_BOTH


func _create_display_object() -> void:
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.label_settings = LabelSettings.new()
	node = label


func _get_text() -> String:
	return label.text


func _set_text(value: String) -> void:
	label.text = value
	if auto_size == FGUIEnums.AUTOSIZE_BOTH:
		var minimum: Vector2 = label.get_minimum_size()
		set_size(minimum.x, minimum.y)


var text: String:
	get:
		return _get_text()
	set(value):
		_set_text(value)


func get_text() -> String:
	return _get_text()


func set_text(value: String) -> void:
	_set_text(value)


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_before_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 5):
		return
	var font_name = buffer.read_s()
	font_size = buffer.read_i16()
	color = buffer.read_color()
	align = buffer.read_i8()
	_apply_align()
	valign = buffer.read_i8()
	_apply_valign()
	buffer.read_i16()
	buffer.read_i16()
	buffer.read_bool()
	auto_size = buffer.read_i8()
	buffer.read_bool()
	buffer.read_bool()
	buffer.read_bool()
	var single_line := buffer.read_bool()
	if label is Label:
		label.autowrap_mode = TextServer.AUTOWRAP_OFF if single_line else TextServer.AUTOWRAP_WORD_SMART
	if buffer.read_bool():
		buffer.read_color()
		buffer.read_float32()
	if buffer.read_bool():
		buffer.skip(12)
	if buffer.read_bool():
		pass
	if font_name != null and str(font_name).begins_with("ui://"):
		FGUIPackage.get_item_by_url(font_name)


func setup_after_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_after_add(buffer, begin_pos)
	if buffer.seek(begin_pos, 6):
		var value = buffer.read_s()
		if value != null:
			text = value


func get_prop(index: int) -> Variant:
	match index:
		FGUIEnums.OBJECT_PROP_COLOR:
			return color
		FGUIEnums.OBJECT_PROP_FONT_SIZE:
			return font_size
		_:
			return super.get_prop(index)


func set_prop(index: int, value: Variant) -> void:
	match index:
		FGUIEnums.OBJECT_PROP_COLOR:
			if value is Color:
				color = value
		FGUIEnums.OBJECT_PROP_FONT_SIZE:
			font_size = int(value)
		_:
			super.set_prop(index, value)


func _ensure_label_settings() -> void:
	if label is Label and label.label_settings == null:
		label.label_settings = LabelSettings.new()


func _apply_font_size() -> void:
	if label == null:
		return
	if label is Label:
		_ensure_label_settings()
		label.label_settings.font_size = _font_size
	elif label is RichTextLabel:
		label.add_theme_font_size_override("normal_font_size", _font_size)
	elif label is LineEdit:
		label.add_theme_font_size_override("font_size", _font_size)


func _apply_font_color() -> void:
	if label == null:
		return
	if label is Label:
		_ensure_label_settings()
		label.label_settings.font_color = _color
	elif label is RichTextLabel:
		label.add_theme_color_override("default_color", _color)
	elif label is LineEdit:
		label.add_theme_color_override("font_color", _color)


func _apply_align() -> void:
	if not (label is Label):
		return
	match align:
		FGUIEnums.ALIGN_CENTER:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		FGUIEnums.ALIGN_RIGHT:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _apply_valign() -> void:
	if not (label is Label):
		return
	match valign:
		FGUIEnums.VERT_ALIGN_MIDDLE:
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		FGUIEnums.VERT_ALIGN_BOTTOM:
			label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_:
			label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
