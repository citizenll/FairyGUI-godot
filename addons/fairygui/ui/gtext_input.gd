class_name FGUITextInput
extends FGUITextField

var line_edit: LineEdit
var text_edit: TextEdit
var _input_control: Control
var _editable: bool = true
var _prompt_text: String = ""
var _prompt_color := Color.WHITE
var _has_prompt_color: bool = false
var _max_length: int = 0
var _password: bool = false
var _keyboard_type: int = 0
var _setting_input_text: bool = false

var native_input: Control:
	get:
		return _input_control
var editable: bool:
	get:
		return _editable
	set(value):
		_editable = value
		_apply_editable()
var prompt_text: String:
	get:
		return _prompt_text
	set(value):
		var parser := FGUIUBBParser.default_parser
		_prompt_text = parser.parse(value, true) if parser != null else value
		_has_prompt_color = parser != null and parser.last_color != ""
		if _has_prompt_color:
			_prompt_color = FGUIToolSet.color_from_html(parser.last_color)
		_apply_prompt_text()
var max_length: int:
	get:
		return _max_length
	set(value):
		_max_length = maxi(0, value)
		_apply_max_length()
var password: bool:
	get:
		return _password
	set(value):
		if _password == value:
			return
		_password = value
		_ensure_input_control()
var _restrict: String = ""
var restrict: String:
	get:
		return _restrict
	set(value):
		_restrict = value

var keyboard_type: int:
	get:
		return _keyboard_type
	set(value):
		_keyboard_type = value
		_apply_keyboard_type()


func _create_display_object() -> void:
	node = Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	node.focus_mode = Control.FOCUS_ALL
	node.focus_entered.connect(_on_container_focus_entered)
	_ensure_input_control()


func _get_text() -> String:
	if line_edit != null:
		return line_edit.text
	if text_edit != null:
		return text_edit.text
	return _text


func _set_text(value: String) -> void:
	_text = value
	_set_native_text(value)


func _ensure_label_settings() -> void:
	return


func _apply_align() -> void:
	if line_edit == null:
		return
	match align:
		FGUIEnums.ALIGN_CENTER:
			line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		FGUIEnums.ALIGN_RIGHT:
			line_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_:
			line_edit.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _apply_valign() -> void:
	return


func request_focus() -> void:
	super.request_focus()
	if _input_control != null:
		if _input_control.is_inside_tree():
			_input_control.grab_focus()
		else:
			_input_control.call_deferred("grab_focus")


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_before_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 4):
		return
	var value = buffer.read_s()
	if value != null:
		prompt_text = str(value)
	value = buffer.read_s()
	if value != null:
		restrict = str(value)
	var length := buffer.read_i32()
	if length != 0:
		max_length = length
	var type_value := buffer.read_i32()
	if type_value != 0:
		keyboard_type = type_value
	if buffer.read_bool():
		password = true


func _on_text_changed(new_text: String) -> void:
	if _setting_input_text:
		return
	var filtered := _apply_input_limits(new_text)
	if filtered != new_text:
		var line_caret := line_edit.caret_column if line_edit != null else 0
		var text_caret_line := text_edit.get_caret_line() if text_edit != null else 0
		var text_caret_column := text_edit.get_caret_column() if text_edit != null else 0
		_set_native_text(filtered)
		if line_edit != null:
			line_edit.caret_column = mini(line_caret, filtered.length())
		elif text_edit != null:
			_restore_text_edit_caret(text_caret_line, text_caret_column)
	_text = filtered


func _on_text_edit_changed(source: TextEdit) -> void:
	if source == text_edit:
		_on_text_changed(source.text)


func _apply_input_limits(value: String) -> String:
	var result := value
	if _max_length > 0 and result.length() > _max_length:
		result = result.substr(0, _max_length)
	if _restrict == "":
		return result
	var filtered := ""
	for i in result.length():
		var ch := result.substr(i, 1)
		if _is_restricted_character_allowed(result.unicode_at(i)):
			filtered += ch
	return filtered


func _on_single_line_changed() -> void:
	_ensure_input_control()


func _handle_touchable_changed() -> void:
	super._handle_touchable_changed()
	if _input_control != null:
		_input_control.mouse_filter = Control.MOUSE_FILTER_STOP if touchable else Control.MOUSE_FILTER_IGNORE


func _ensure_input_control() -> void:
	var use_multiline := not _single_line and not _password
	if (use_multiline and text_edit != null) or (not use_multiline and line_edit != null):
		_apply_input_settings()
		return
	var current_text := _get_text()
	var restore_focus := _input_control != null and _input_control.has_focus()
	_remove_input_control()
	if use_multiline:
		text_edit = TextEdit.new()
		text_edit.text_changed.connect(_on_text_edit_changed.bind(text_edit))
		text_edit.set_line_wrapping_mode(TextEdit.LINE_WRAPPING_BOUNDARY)
		text_edit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_input_control = text_edit
	else:
		line_edit = LineEdit.new()
		line_edit.text_changed.connect(_on_text_changed)
		_input_control = line_edit
	label = _input_control
	node.add_child(_input_control)
	_input_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_control.offset_left = 0.0
	_input_control.offset_top = 0.0
	_input_control.offset_right = 0.0
	_input_control.offset_bottom = 0.0
	_input_control.gui_input.connect(_on_gui_input)
	_apply_input_settings()
	_set_native_text(current_text)
	if restore_focus:
		_input_control.call_deferred("grab_focus")


func _remove_input_control() -> void:
	if _input_control == null:
		return
	var previous := _input_control
	_input_control = null
	line_edit = null
	text_edit = null
	label = null
	if previous.get_parent() != null:
		previous.get_parent().remove_child(previous)
	if previous.is_inside_tree():
		previous.queue_free()
	else:
		previous.free()


func _apply_input_settings() -> void:
	if _input_control == null:
		return
	_apply_editable()
	_apply_prompt_text()
	_apply_max_length()
	_apply_keyboard_type()
	_apply_font_size()
	_apply_font_color()
	_apply_leading()
	_apply_stroke()
	_apply_shadow()
	if line_edit != null:
		line_edit.secret = _password
		_apply_align()
		_apply_valign()
	_handle_touchable_changed()


func _apply_editable() -> void:
	if line_edit != null:
		line_edit.editable = _editable
	elif text_edit != null:
		text_edit.editable = _editable


func _apply_prompt_text() -> void:
	if line_edit != null:
		line_edit.placeholder_text = _prompt_text
		_apply_prompt_color(line_edit)
	elif text_edit != null:
		text_edit.placeholder_text = _prompt_text
		_apply_prompt_color(text_edit)


func _apply_prompt_color(control: Control) -> void:
	if _has_prompt_color:
		control.add_theme_color_override("font_placeholder_color", _prompt_color)
	else:
		control.remove_theme_color_override("font_placeholder_color")


func _apply_max_length() -> void:
	if line_edit != null:
		line_edit.max_length = _max_length


func _apply_keyboard_type() -> void:
	if line_edit == null:
		return
	match _keyboard_type:
		4:
			line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		3:
			line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
		_:
			line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT


func _set_native_text(value: String) -> void:
	if _input_control == null:
		return
	_setting_input_text = true
	if line_edit != null:
		line_edit.text = value
	elif text_edit != null:
		text_edit.text = value
	_setting_input_text = false


func _restore_text_edit_caret(line: int, column: int) -> void:
	if text_edit == null:
		return
	var caret_line := clampi(line, 0, maxi(0, text_edit.get_line_count() - 1))
	text_edit.set_caret_line(caret_line, false)
	text_edit.set_caret_column(mini(column, text_edit.get_line(caret_line).length()), false)


func _on_container_focus_entered() -> void:
	if _input_control != null and _input_control.is_inside_tree():
		_input_control.call_deferred("grab_focus")


func _is_restricted_character_allowed(codepoint: int) -> bool:
	var inverted := _restrict.begins_with("^")
	var index := 1 if inverted else 0
	var matched := false
	while index < _restrict.length():
		var first := _restrict.unicode_at(index)
		if first == 92 and index + 1 < _restrict.length():
			index += 1
			first = _restrict.unicode_at(index)
		index += 1
		if index < _restrict.length() and _restrict.unicode_at(index) == 45:
			index += 1
			if index < _restrict.length():
				var last := _restrict.unicode_at(index)
				if last == 92 and index + 1 < _restrict.length():
					index += 1
					last = _restrict.unicode_at(index)
				index += 1
				if codepoint >= mini(first, last) and codepoint <= maxi(first, last):
					matched = true
				continue
			if codepoint == first or codepoint == 45:
				matched = true
			continue
		if codepoint == first:
			matched = true
	return not matched if inverted else matched
