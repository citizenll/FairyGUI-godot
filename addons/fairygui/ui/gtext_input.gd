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


func _create_display_object() -> void:
	line_edit = LineEdit.new()
	line_edit.mouse_filter = Control.MOUSE_FILTER_PASS
	label = line_edit
	node = line_edit


func _get_text() -> String:
	return line_edit.text


func _set_text(value: String) -> void:
	line_edit.text = value


func _ensure_label_settings() -> void:
	pass


func _apply_align() -> void:
	match align:
		FGUIEnums.ALIGN_CENTER:
			line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		FGUIEnums.ALIGN_RIGHT:
			line_edit.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_:
			line_edit.alignment = HORIZONTAL_ALIGNMENT_LEFT


func _apply_valign() -> void:
	pass
