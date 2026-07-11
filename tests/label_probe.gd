extends SceneTree


class IconProbe extends FGUIObject:
	var current_icon: String = ""

	func get_icon() -> String:
		return current_icon

	func set_icon(value: String) -> void:
		current_icon = value


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var label := FGUILabel.new()
	host.add_child(label.node)
	var input := FGUITextInput.new()
	input.name = "title"
	label.add_child(input)
	var icon := IconProbe.new()
	icon.name = "icon"
	label.add_child(icon)
	label.construct_extension(FGUIByteBuffer.new())

	label.title = "Runtime"
	label.icon = "runtime_icon"
	label.color = Color("336699")
	label.title_font_size = 18
	label.editable = false
	label.set_prop(FGUIEnums.OBJECT_PROP_OUTLINE_COLOR, Color("aa2200"))
	if label.get_text() != "Runtime" or label.get_icon() != "runtime_icon" or label.title_color != Color("336699") or label.title_font_size != 18:
		_fail(label, "GLabel runtime title, icon, color, or font properties were not forwarded.")
		return
	if label.editable or input.editable or label.get_prop(FGUIEnums.OBJECT_PROP_OUTLINE_COLOR) != Color("aa2200"):
		_fail(label, "GLabel editable or outline properties were not forwarded to GTextInput.")
		return

	var package_item := FGUIPackageItem.new()
	package_item.object_type = FGUIEnums.OBJECT_LABEL
	label.package_item = package_item
	var buffer := FGUIByteBuffer.new(_make_setup_data())
	buffer.string_table = ["123456", "configured_icon", "[color=#44aa66]Prompt[/color]", "0-9"]
	label.setup_after_add(buffer, 0)
	if label.title != "123456" or label.icon != "configured_icon" or label.title_color != Color8(0x11, 0x22, 0x33) or label.title_font_size != 21:
		_fail(label, "GLabel package setup did not apply title styling: title=%s icon=%s color=%s size=%s" % [label.title, label.icon, label.title_color, label.title_font_size])
		return
	if input.prompt_text != "Prompt" or input.restrict != "0-9" or input.max_length != 6 or input.keyboard_type != 4 or not input.password:
		_fail(label, "GLabel package setup did not apply embedded input settings.")
		return
	if input.line_edit == null or input.line_edit.virtual_keyboard_type != LineEdit.KEYBOARD_TYPE_NUMBER or not input.line_edit.secret:
		_fail(label, "GLabel embedded input settings did not reach the native LineEdit.")
		return

	label.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _make_setup_data() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(64)
	bytes[0] = 7
	bytes[1] = 1
	_write_u16(bytes, 14, 16)
	var pos := 16
	bytes[pos] = FGUIEnums.OBJECT_LABEL
	pos += 1
	_write_u16(bytes, pos, 0)
	pos += 2
	_write_u16(bytes, pos, 1)
	pos += 2
	bytes[pos] = 1
	pos += 1
	bytes[pos] = 0x11
	bytes[pos + 1] = 0x22
	bytes[pos + 2] = 0x33
	bytes[pos + 3] = 0xff
	pos += 4
	_write_i32(bytes, pos, 21)
	pos += 4
	bytes[pos] = 1
	pos += 1
	_write_u16(bytes, pos, 2)
	pos += 2
	_write_u16(bytes, pos, 3)
	pos += 2
	_write_i32(bytes, pos, 6)
	pos += 4
	_write_i32(bytes, pos, 4)
	pos += 4
	bytes[pos] = 1
	return bytes


func _write_u16(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = (value >> 8) & 0xff
	bytes[offset + 1] = value & 0xff


func _write_i32(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = (value >> 24) & 0xff
	bytes[offset + 1] = (value >> 16) & 0xff
	bytes[offset + 2] = (value >> 8) & 0xff
	bytes[offset + 3] = value & 0xff


func _fail(label: FGUILabel, message: String) -> void:
	push_error(message)
	if label != null and not label.is_disposed:
		label.dispose()
	quit(1)
