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
var _text: String = ""
var _font_name: String = ""
var _bitmap_font: FGUIBitmapFont
var _bitmap_nodes: Array[TextureRect] = []


func _create_display_object() -> void:
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.label_settings = LabelSettings.new()
	node = label


func _get_text() -> String:
	return _text


func _set_text(value: String) -> void:
	_text = value
	if _bitmap_font != null:
		_render_bitmap_text(value)
		return
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
	_font_name = "" if font_name == null else str(font_name)
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
	if _font_name.begins_with("ui://"):
		var font_item := FGUIPackage.get_item_by_url(_font_name)
		if font_item != null:
			var font_asset := font_item.owner.get_item_asset(font_item)
			if font_asset is FGUIBitmapFont:
				_bitmap_font = font_asset
				if label != null:
					label.text = ""


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
	if _bitmap_font != null:
		_render_bitmap_text(get_text())
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
	if _bitmap_font != null:
		for node in _bitmap_nodes:
			node.modulate = _color if _bitmap_font.tint else Color.WHITE
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


func _render_bitmap_text(value: String) -> void:
	for glyph_node in _bitmap_nodes:
		if is_instance_valid(glyph_node):
			glyph_node.queue_free()
	_bitmap_nodes.clear()
	if label == null or _bitmap_font == null:
		return
	label.text = ""
	var scale := float(font_size) / float(maxi(_bitmap_font.font_size, 1))
	var cursor := Vector2.ZERO
	var max_x := 0.0
	for i in value.length():
		var code := value.unicode_at(i)
		if code == 10:
			max_x = maxf(max_x, cursor.x)
			cursor.x = 0.0
			cursor.y += _bitmap_font.line_height * scale
			continue
		var glyph := _bitmap_font.get_glyph(code)
		if glyph.is_empty():
			cursor.x += font_size * 0.5
			continue
		var texture: Texture2D = glyph.get("texture")
		if texture != null:
			var glyph_node := TextureRect.new()
			glyph_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glyph_node.texture = texture
			glyph_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			glyph_node.stretch_mode = TextureRect.STRETCH_SCALE
			glyph_node.position = Vector2(cursor.x + float(glyph.get("x", 0)) * scale, cursor.y + float(glyph.get("y", 0)) * scale)
			glyph_node.size = Vector2(float(glyph.get("width", 0)) * scale, float(glyph.get("height", 0)) * scale)
			glyph_node.modulate = color if _bitmap_font.tint else Color.WHITE
			label.add_child(glyph_node)
			_bitmap_nodes.append(glyph_node)
		cursor.x += float(glyph.get("advance", glyph.get("width", font_size))) * scale
		max_x = maxf(max_x, cursor.x)
	var total_height := cursor.y + _bitmap_font.line_height * scale
	if auto_size == FGUIEnums.AUTOSIZE_BOTH:
		set_size(max_x, total_height)
