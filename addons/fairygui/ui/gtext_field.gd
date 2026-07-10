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
var _ubb_enabled: bool = false
var _updating_text_size: bool = false
var _effective_font_size: int = 14
var font_size: int:
	get:
		return _font_size
	set(value):
		_font_size = value
		_apply_font_size()
		if _text != "":
			_update_text_size()
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
		_refresh_bitmap_text()
var letter_spacing: int:
	get:
		return _letter_spacing
	set(value):
		_letter_spacing = value
		_refresh_bitmap_text()
var auto_size: int:
	get:
		return _auto_size
	set(value):
		_auto_size = value
		_configure_label_layout()
		if _bitmap_font != null:
			_refresh_bitmap_text()
		elif _text != "":
			_update_text_size()
var single_line: bool:
	get:
		return _single_line
	set(value):
		if _single_line == value:
			return
		_single_line = value
		_on_single_line_changed()
		_configure_label_layout()
		if _bitmap_font != null:
			_refresh_bitmap_text()
		elif _text != "":
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
var ubb_enabled: bool:
	get:
		return _ubb_enabled
	set(value):
		if _ubb_enabled == value:
			return
		_ubb_enabled = value
		_ensure_text_renderer()
		_apply_display_text()
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
var _align: int = FGUIEnums.ALIGN_LEFT
var align: int:
	get:
		return _align
	set(value):
		_align = value
		_apply_align()
		_refresh_bitmap_text()
var _valign: int = FGUIEnums.VERT_ALIGN_TOP
var valign: int:
	get:
		return _valign
	set(value):
		_valign = value
		_apply_valign()
		_refresh_bitmap_text()
var _text: String = ""
var _font_name: String = ""
var _bitmap_font: FGUIBitmapFont
var _bitmap_nodes: Array[TextureRect] = []
var _bitmap_text_size := Vector2.ZERO
var text_width: float:
	get:
		return _get_text_content_size().x
var text_height: float:
	get:
		return _get_text_content_size().y


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
	if label is RichTextLabel and _ubb_enabled:
		_set_rich_text_content(value)
		return
	if label != null:
		label.text = value
	_update_text_size()


func _set_rich_text_content(value: String) -> void:
	if not (label is RichTextLabel):
		return
	var parsed := FGUIUBBParser.default_parser.parse(value) if FGUIUBBParser.default_parser != null else value
	var image_regex := RegEx.new()
	image_regex.compile("(?i)\\[img\\](ui://[^\\[]+)\\[/img\\]")
	var first_match := image_regex.search(parsed)
	if first_match == null:
		label.text = parsed
		_update_text_size()
		return
	label.clear()
	var cursor := 0
	var current_match := first_match
	while current_match != null:
		var start := current_match.get_start()
		var end := current_match.get_end()
		if start > cursor:
			label.append_text(parsed.substr(cursor, start - cursor))
		_append_package_image(current_match.get_string(1))
		cursor = end
		current_match = image_regex.search(parsed, cursor)
	if cursor < parsed.length():
		label.append_text(parsed.substr(cursor))
	_update_text_size()


func _append_package_image(url: String) -> void:
	var item := FGUIPackage.get_item_by_url(url)
	if item == null:
		return
	item = item.get_branch().get_high_resolution()
	item.load()
	if item.texture == null:
		return
	label.add_image(item.texture, item.width, item.height)


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


func ensure_size_correct() -> void:
	if _bitmap_font != null:
		_refresh_bitmap_text()
	elif label is Label or label is RichTextLabel:
		_update_text_size()


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
	ubb_enabled = buffer.read_bool()
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
				_ensure_text_renderer()
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
		_set_effective_font_size(_font_size)
	elif label is RichTextLabel:
		label.add_theme_font_size_override("normal_font_size", _font_size)
	elif label is LineEdit or label is TextEdit:
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
	elif label is LineEdit or label is TextEdit:
		label.add_theme_color_override("font_color", _color)


func _apply_leading() -> void:
	if label is Label:
		_ensure_label_settings()
		label.label_settings.line_spacing = _leading
	elif label is RichTextLabel or label is TextEdit:
		label.add_theme_constant_override("line_separation", _leading)


func _apply_stroke() -> void:
	if label is Label:
		_ensure_label_settings()
		label.label_settings.outline_size = _stroke
		label.label_settings.outline_color = _stroke_color
	elif label is RichTextLabel or label is LineEdit or label is TextEdit:
		label.add_theme_constant_override("outline_size", _stroke)
		label.add_theme_color_override("font_outline_color", _stroke_color)


func _apply_shadow() -> void:
	if label is Label:
		_ensure_label_settings()
		label.label_settings.shadow_color = _shadow_color
		label.label_settings.shadow_offset = _shadow_offset
	elif label is RichTextLabel or label is TextEdit:
		label.add_theme_color_override("font_shadow_color", _shadow_color)
		label.add_theme_constant_override("shadow_offset_x", roundi(_shadow_offset.x))
		label.add_theme_constant_override("shadow_offset_y", roundi(_shadow_offset.y))


func _configure_label_layout() -> void:
	var wrap := _auto_size != FGUIEnums.AUTOSIZE_BOTH and not _single_line
	if label is Label:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
		label.clip_text = _auto_size == FGUIEnums.AUTOSIZE_ELLIPSIS
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if _auto_size == FGUIEnums.AUTOSIZE_ELLIPSIS else TextServer.OVERRUN_NO_TRIMMING
	elif label is RichTextLabel:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
		label.fit_content = _auto_size == FGUIEnums.AUTOSIZE_BOTH or _auto_size == FGUIEnums.AUTOSIZE_HEIGHT
		label.scroll_active = false


func _on_single_line_changed() -> void:
	pass


func _update_text_size() -> void:
	if _bitmap_font != null or _updating_text_size or _text == "":
		return
	_updating_text_size = true
	_configure_label_layout()
	if label is Label and _auto_size == FGUIEnums.AUTOSIZE_SHRINK:
		_apply_shrink_to_fit()
		_updating_text_size = false
		return
	if label is Label:
		_set_effective_font_size(_font_size)
		var minimum: Vector2 = label.get_minimum_size()
		if _auto_size == FGUIEnums.AUTOSIZE_BOTH:
			set_size(minimum.x, minimum.y)
		elif _auto_size == FGUIEnums.AUTOSIZE_HEIGHT:
			set_size(width, minimum.y)
	elif label is RichTextLabel:
		var content_width := maxf(label.get_content_width(), label.get_minimum_size().x)
		var content_height := maxf(label.get_content_height(), label.get_minimum_size().y)
		if _auto_size == FGUIEnums.AUTOSIZE_BOTH and content_width > 0.0 and content_height > 0.0:
			set_size(content_width, content_height)
		elif _auto_size == FGUIEnums.AUTOSIZE_HEIGHT and content_height > 0.0:
			set_size(width, content_height)
	_updating_text_size = false


func _set_effective_font_size(value: int) -> void:
	if not (label is Label):
		return
	_ensure_label_settings()
	_effective_font_size = maxi(1, value)
	label.label_settings.font_size = _effective_font_size


func _apply_shrink_to_fit() -> void:
	if not (label is Label):
		return
	var requested_size := maxi(1, _font_size)
	var target_size := Vector2(width, height)
	if target_size.x <= 0.0 or target_size.y <= 0.0:
		_set_effective_font_size(requested_size)
		return
	var effective_size := requested_size
	while effective_size > 1:
		_set_effective_font_size(effective_size)
		var minimum: Vector2 = label.get_minimum_size()
		if minimum.x <= target_size.x + 0.5 and minimum.y <= target_size.y + 0.5:
			break
		effective_size -= 1
	_set_effective_font_size(effective_size)


func _handle_size_changed() -> void:
	super._handle_size_changed()
	if _bitmap_font != null:
		_refresh_bitmap_text()
		return
	if not _updating_text_size:
		_update_text_size()


func _apply_align() -> void:
	var value := HORIZONTAL_ALIGNMENT_LEFT
	match align:
		FGUIEnums.ALIGN_CENTER:
			value = HORIZONTAL_ALIGNMENT_CENTER
		FGUIEnums.ALIGN_RIGHT:
			value = HORIZONTAL_ALIGNMENT_RIGHT
	if label is Label or label is RichTextLabel:
		label.horizontal_alignment = value


func _apply_valign() -> void:
	var value := VERTICAL_ALIGNMENT_TOP
	match valign:
		FGUIEnums.VERT_ALIGN_MIDDLE:
			value = VERTICAL_ALIGNMENT_CENTER
		FGUIEnums.VERT_ALIGN_BOTTOM:
			value = VERTICAL_ALIGNMENT_BOTTOM
	if label is Label or label is RichTextLabel:
		label.vertical_alignment = value


func _render_bitmap_text(value: String) -> void:
	for glyph_node in _bitmap_nodes:
		if is_instance_valid(glyph_node):
			glyph_node.queue_free()
	_bitmap_nodes.clear()
	if label == null or _bitmap_font == null:
		return
	label.text = ""
	var scale := float(font_size) / float(maxi(_bitmap_font.font_size, 1))
	var line_height := float(_bitmap_font.line_height) * scale
	var wrap_width := width if _auto_size != FGUIEnums.AUTOSIZE_BOTH and not _single_line and width > 0.0 else INF
	var lines: Array = []
	var line_entries: Array = []
	var line_width := 0.0
	for i in value.length():
		var code := value.unicode_at(i)
		if code == 13:
			continue
		if code == 10:
			lines.append({"entries": line_entries, "width": line_width})
			line_entries = []
			line_width = 0.0
			continue
		var glyph := _bitmap_font.get_glyph(code)
		var advance := float(glyph.get("advance", glyph.get("width", font_size * 0.5))) * scale if not glyph.is_empty() else float(font_size) * 0.5
		var spacing := float(_letter_spacing) if not line_entries.is_empty() else 0.0
		if not line_entries.is_empty() and line_width + spacing + advance > wrap_width:
			lines.append({"entries": line_entries, "width": line_width})
			line_entries = []
			line_width = 0.0
			spacing = 0.0
		var entry := {"glyph": glyph, "x": line_width + spacing}
		line_entries.append(entry)
		line_width += spacing + advance
	lines.append({"entries": line_entries, "width": line_width})
	var max_width := 0.0
	for line: Dictionary in lines:
		max_width = maxf(max_width, float(line["width"]))
	var total_height := maxf(line_height, float(lines.size()) * line_height + float(maxi(0, lines.size() - 1) * _leading))
	_bitmap_text_size = Vector2(max_width, total_height)
	_updating_text_size = true
	if _auto_size == FGUIEnums.AUTOSIZE_BOTH:
		set_size(max_width, total_height)
	elif _auto_size == FGUIEnums.AUTOSIZE_HEIGHT:
		set_size(width, total_height)
	_updating_text_size = false
	var layout_width := max_width if _auto_size == FGUIEnums.AUTOSIZE_BOTH else width
	var vertical_offset := 0.0
	if _auto_size != FGUIEnums.AUTOSIZE_BOTH and _auto_size != FGUIEnums.AUTOSIZE_HEIGHT:
		if valign == FGUIEnums.VERT_ALIGN_MIDDLE:
			vertical_offset = (height - total_height) * 0.5
		elif valign == FGUIEnums.VERT_ALIGN_BOTTOM:
			vertical_offset = height - total_height
	for line_index in lines.size():
		var line: Dictionary = lines[line_index]
		var horizontal_offset := 0.0
		if align == FGUIEnums.ALIGN_CENTER:
			horizontal_offset = (layout_width - float(line["width"])) * 0.5
		elif align == FGUIEnums.ALIGN_RIGHT:
			horizontal_offset = layout_width - float(line["width"])
		var line_y := vertical_offset + float(line_index) * (line_height + float(_leading))
		for entry: Dictionary in line["entries"]:
			var entry_glyph: Dictionary = entry["glyph"]
			var texture: Texture2D = entry_glyph.get("texture")
			if texture == null:
				continue
			var glyph_node := TextureRect.new()
			glyph_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glyph_node.texture = texture
			glyph_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			glyph_node.stretch_mode = TextureRect.STRETCH_SCALE
			glyph_node.position = Vector2(horizontal_offset + float(entry["x"]) + float(entry_glyph.get("x", 0)) * scale, line_y + float(entry_glyph.get("y", 0)) * scale)
			glyph_node.size = Vector2(float(entry_glyph.get("width", 0)) * scale, float(entry_glyph.get("height", 0)) * scale)
			glyph_node.modulate = color if _bitmap_font.tint else Color.WHITE
			label.add_child(glyph_node)
			_bitmap_nodes.append(glyph_node)


func _refresh_bitmap_text() -> void:
	if _bitmap_font != null and not _updating_text_size:
		_render_bitmap_text(_parse_template(get_text()) if _template_vars_enabled else get_text())


func _get_text_content_size() -> Vector2:
	if _bitmap_font != null:
		return _bitmap_text_size
	if label is RichTextLabel:
		return Vector2(label.get_content_width(), label.get_content_height())
	if label != null:
		return label.get_minimum_size()
	return Vector2.ZERO


func _ensure_text_renderer() -> void:
	if self is FGUITextInput:
		return
	var use_rich_text := _bitmap_font == null and (_ubb_enabled or self is FGUIRichTextField)
	if use_rich_text == (label is RichTextLabel):
		return
	_replace_text_renderer(use_rich_text)


func _replace_text_renderer(use_rich_text: bool) -> void:
	var previous_node := node
	var native_parent := previous_node.get_parent() if previous_node != null else null
	var sibling_index := previous_node.get_index() if previous_node != null and native_parent != null else -1
	var filter_values: Variant = previous_node.get_meta("_fgui_filter_values") if previous_node != null and previous_node.has_meta("_fgui_filter_values") else null
	var filter_grayed := bool(previous_node.get_meta("_fgui_filter_gray")) if previous_node != null and previous_node.has_meta("_fgui_filter_gray") else false
	var self_modulate := previous_node.self_modulate if previous_node != null else Color.WHITE
	var mouse_filter := previous_node.mouse_filter if previous_node != null else Control.MOUSE_FILTER_IGNORE
	if previous_node != null:
		previous_node.remove_meta("fgui_owner")
		if native_parent != null:
			native_parent.remove_child(previous_node)
		previous_node.free()
	if use_rich_text:
		label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = false
		label.label_settings = LabelSettings.new()
	node = label
	node.set_meta("fgui_owner", self)
	node.name = name if name != "" else id
	node.gui_input.connect(_on_gui_input)
	node.mouse_entered.connect(_on_mouse_entered)
	node.mouse_exited.connect(_on_mouse_exited)
	if native_parent != null:
		native_parent.add_child(node)
		if sibling_index >= 0:
			native_parent.move_child(node, sibling_index)
	node.self_modulate = self_modulate
	node.mouse_filter = mouse_filter
	node.tooltip_text = _tooltips if FGUIConfig.tooltips_win == "" else ""
	node.scale = _scale
	node.pivot_offset = Vector2(_width * _pivot.x, _height * _pivot.y)
	node.size = Vector2(_width, _height)
	_handle_xy_changed()
	_handle_alpha_changed()
	_handle_visible_changed()
	_apply_font_size()
	_apply_font_color()
	_apply_leading()
	_apply_stroke()
	_apply_shadow()
	_apply_align()
	_apply_valign()
	_configure_label_layout()
	if filter_values != null:
		FGUIToolSet.set_color_filter(node, filter_values)
	if filter_grayed or _grayed:
		FGUIToolSet.set_color_filter(node, true)
