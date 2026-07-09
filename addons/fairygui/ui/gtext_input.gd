class_name FGUITextInput
extends FGUITextField

var line_edit: LineEdit
var editable: bool:
	get:
		return line_edit.editable if line_edit != null else true
	set(value):
		if line_edit != null:
			line_edit.editable = value
var prompt_text: String:
	get:
		return line_edit.placeholder_text if line_edit != null else ""
	set(value):
		if line_edit != null:
			line_edit.placeholder_text = value
var max_length: int:
	get:
		return line_edit.max_length if line_edit != null else 0
	set(value):
		if line_edit != null:
			line_edit.max_length = value
var password: bool:
	get:
		return line_edit.secret if line_edit != null else false
	set(value):
		if line_edit != null:
			line_edit.secret = value
var restrict: String = ""
var keyboard_type: int = 0:
	set(value):
		keyboard_type = value
		if line_edit == null:
			return
		match value:
			4:
				line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
			3:
				line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
			_:
				line_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT


func _create_display_object() -> void:
	line_edit = LineEdit.new()
	line_edit.mouse_filter = Control.MOUSE_FILTER_PASS
	line_edit.text_changed.connect(_on_text_changed)
	label = line_edit
	node = line_edit


func _get_text() -> String:
	return line_edit.text


func _set_text(value: String) -> void:
	_text = value
	line_edit.text = value


func _ensure_label_settings() -> void:
	return


func _apply_align() -> void:
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
	if line_edit != null:
		line_edit.grab_focus()


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_before_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 4):
		return
	var value = buffer.read_s()
	if value != null:
		prompt_text = FGUIUBBParser.default_parser.parse(str(value), true)
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
	if restrict == "":
		_text = new_text
		return
	var filtered := ""
	for i in new_text.length():
		var ch := new_text.substr(i, 1)
		if restrict.find(ch) != -1:
			filtered += ch
	if filtered != new_text:
		var caret := line_edit.caret_column
		line_edit.text = filtered
		line_edit.caret_column = mini(caret, filtered.length())
	_text = filtered
