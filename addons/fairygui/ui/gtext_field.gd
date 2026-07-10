class_name FGUITextField
extends FGUIObject

var label
var _font_size: int = 14
var _color: Color = Color.BLACK
var _leading: int = 0
var _letter_spacing: int = 0
var _auto_size: int = FGUIEnums.AUTOSIZE_BOTH
var _single_line: bool = false
var _stroke: int = 0
var _stroke_color: Color = Color.BLACK
var _shadow_color: Color = Color(0, 0, 0, 0)
var _shadow_offset: Vector2 = Vector2.ZERO
var _template_vars: Dictionary = {}
var _template_vars_enabled: bool = false
var _updating_text_size: bool = false
var font_size: int:
	get:
		return _font_size
	set(value):
		_font_size = value
		_apply_font_size()
		update_gear(9)
var color: Color:
	get:
		return _color
	set(value):
		_color = value
		_apply_font_color()
		update_gear(4)
var leading: int:
	get:
		return _leading
	set(value):
		_leading = value
		_apply_leading()
var letter_spacing: int:
	get:
		return _letter_spacing
	set(value):
		_letter_spacing = value
var auto_size: int:
	get:
		return _auto_size
	set(value):
		_auto_size = value
		_configure_label_layout()
		if _text != "":
			_update_text_size()
var single_line: bool:
	get:
		return _single_line
	set(value):
		_single_line = value
		_configure_label_layout()
		if _text != "":
			_update_text_size()
var stroke: int:
	get:
		return _stroke
	set(value):
		_stroke = maxi(0, value)
		_apply_stroke()
		update_gear(4)
var stroke_color: Color:
	get:
		return _stroke_color
	set(value):
		_stroke_color = value
		_apply_stroke()
		update_gear(4)
var shadow_color: Color:
	get:
		return _shadow_color
	set(value):
		_shadow_color = value
		_apply_shadow()
var shadow_offset: Vector2:
	get:
		return _shadow_offset
	set(value):
		_shadow_offset = value
		_apply_shadow()
var template_vars: Variant:
	get:
		return _template_vars if _template_vars_enabled else null
	set(value):
		_template_vars.clear()
		if value is Dictionary:
			_template_vars.merge(value)
			_template_vars_enabled = true
		else:
			_template_vars_enabled = bool(value)
		_apply_display_text()
var align: int = FGUIEnums.ALIGN_LEFT
var valign: int = FGUIEnums.VERT_ALIGN_TOP
var _text: String = ""
var _font_name: String = ""
var _bitmap_font: FGUIBitmapFont
var _bitmap_nodes: Array[TextureRect] = []


func _create_display_object() -> void:
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = false
	label.label_settings = LabelSettings.new()
	node = label


func _get_text() -> String:
	return _text


func _set_text(value: String) -> void:
	_text = value
	_apply_display_text()


func set_var(name: String, value: Variant) -> FGUITextField:
	_template_vars_enabled = true
	_template_vars[name] = str(value)
	return self


func flush_vars() -> void:
	_apply_display_text()


func _apply_display_text() -> void:
	var value := _parse_template(_text) if _template_vars_enabled else _text
	if _bitmap_font != null:
		_render_bitmap_text(value)
		return
	if label != null:
		label.text = value
	_update_text_size()


func _parse_template(template: String) -> String:
	var result := ""
	var start := 0
	while true:
		var open := template.find("{", start)
		if open == -1:
			break
		if open > 0 and template.substr(open - 1, 1) == "\\":
			result += template.substr(start, open - start - 1) + "{"
			start = open + 1
			continue
		result += template.substr(start, open - start)
		var close := template.find("}", open + 1)
		if close == -1:
			start = open
			break
		if close == open + 1:
			result += "{}"
			start = close + 1
			continue
		var token := template.substr(open + 1, close - open - 1)
		var separator := token.find("=")
		if separator >= 0:
			var key := token.substr(0, separator)
			var fallback := token.substr(separator + 1)
			result += str(_template_vars.get(key, fallback))
		else:
			result += str(_template_vars.get(token, ""))
		start = close + 1
	if start < template.length():
		result += template.substr(start)
	return result


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
	leading = buffer.read_i16()
	letter_spacing = buffer.read_i16()
	buffer.read_bool()
	auto_size = buffer.read_i8()
	buffer.read_bool()
	buffer.read_bool()
	buffer.read_bool()
	single_line = buffer.read_bool()
	if buffer.read_bool():
		stroke_color = buffer.read_color()
		stroke = roundi(buffer.read_float32() + 1.0)
	if buffer.read_bool():
		shadow_color = buffer.read_color()
		shadow_offset = Vector2(buffer.read_float32(), buffer.read_float32())
	if buffer.read_bool():
		template_vars = {}
	if buffer.version >= 3:
		buffer.read_bool()
		buffer.skip(12)
	if _font_name.begins_with("ui://"):
		var font_item := FGUIPackage.get_item_by_url(_font_name)
		if font_item != null:
			var font_asset: Variant = font_item.owner.get_item_asset(font_item)
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
		FGUIEnums.OBJECT_PROP_OUTLINE_COLOR:
			return stroke_color
		FGUIEnums.OBJECT_PROP_FONT_SIZE:
			return font_size
		_:
			return super.get_prop(index)


func set_prop(index: int, value: Variant) -> void:
	match index:
		FGUIEnums.OBJECT_PROP_COLOR:
			if value is Color:
				color = value
		FGUIEnums.OBJECT_PROP_OUTLINE_COLOR:
			if value is Color:
				stroke_color = value
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
		_render_bitmap_text(_parse_template(get_text()) if _template_vars_enabled else get_text())
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


func _apply_leading() -> void:
	if label is Label:
		_ensure_label_settings()
		label.label_settings.line_spacing = _leading
	elif label is RichTextLabel:
		label.add_theme_constant_override("line_separation", _leading)


func _apply_stroke() -> void:
	if label is Label:
		_ensure_label_settings()
		label.label_settings.outline_size = _stroke
		label.label_settings.outline_color = _stroke_color
	elif label is RichTextLabel or label is LineEdit:
		label.add_theme_constant_override("outline_size", _stroke)
		label.add_theme_color_override("font_outline_color", _stroke_color)


func _apply_shadow() -> void:
	if label is Label:
		_ensure_label_settings()
		label.label_settings.shadow_color = _shadow_color
		label.label_settings.shadow_offset = _shadow_offset


func _configure_label_layout() -> void:
	if not (label is Label):
		return
	var wrap := _auto_size != FGUIEnums.AUTOSIZE_BOTH and not _single_line
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.clip_text = _auto_size == FGUIEnums.AUTOSIZE_ELLIPSIS
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if _auto_size == FGUIEnums.AUTOSIZE_ELLIPSIS else TextServer.OVERRUN_NO_TRIMMING


func _update_text_size() -> void:
	if _updating_text_size or not (label is Label) or _text == "":
		return
	_updating_text_size = true
	_configure_label_layout()
	var minimum: Vector2 = label.get_minimum_size()
	if _auto_size == FGUIEnums.AUTOSIZE_BOTH:
		set_size(minimum.x, minimum.y)
	elif _auto_size == FGUIEnums.AUTOSIZE_HEIGHT:
		set_size(width, minimum.y)
	_updating_text_size = false


func _handle_size_changed() -> void:
	super._handle_size_changed()
	if not _updating_text_size:
		_update_text_size()


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
