extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var field := FGUITextField.new()
	host.add_child(field.node)
	field.text = "Hello {name}, {role=guest}! \\{literal}"
	if field.set_var("name", "Ada") != field:
		_fail("set_var should return the text field for chaining.")
		return
	field.flush_vars()
	if field.text != "Hello {name}, {role=guest}! \\{literal}" or field.label.text != "Hello Ada, guest! {literal}":
		_fail("Text template variables were not resolved with fallback and escaped braces.")
		return

	field.font_size = 20
	field.leading = 7
	field.stroke = 2
	field.stroke_color = Color(0.25, 0.5, 0.75)
	field.shadow_color = Color(0, 0, 0, 0.6)
	field.shadow_offset = Vector2(3, 4)
	var settings: LabelSettings = field.label.label_settings
	if settings.font_size != 20 or not is_equal_approx(settings.line_spacing, 7.0):
		_fail("Text font size or line spacing was not applied to LabelSettings.")
		return
	if settings.outline_size != 2 or settings.outline_color != field.stroke_color:
		_fail("Text outline settings were not applied.")
		return
	if settings.shadow_color != field.shadow_color or settings.shadow_offset != field.shadow_offset:
		_fail("Text shadow settings were not applied.")
		return
	if field.get_prop(FGUIEnums.OBJECT_PROP_OUTLINE_COLOR) != field.stroke_color:
		_fail("Outline color property was not exposed to gears.")
		return

	field.set_size(80, 16)
	field.auto_size = FGUIEnums.AUTOSIZE_ELLIPSIS
	if not field.label.clip_text or field.label.text_overrun_behavior != TextServer.OVERRUN_TRIM_ELLIPSIS:
		_fail("Ellipsis auto-size mode was not mapped to Label trimming.")
		return
	field.auto_size = FGUIEnums.AUTOSIZE_BOTH
	field.text = "Auto-sized text"
	if field.width <= 0.0 or field.height <= 0.0:
		_fail("Both-axis auto-size did not measure text content.")
		return
	field.auto_size = FGUIEnums.AUTOSIZE_HEIGHT
	field.set_size(64, 12)
	field.single_line = false
	field.text = "Height auto-size should wrap this text across several lines."
	await process_frame
	if field.label.autowrap_mode != TextServer.AUTOWRAP_WORD_SMART or field.height < 12.0:
		_fail("Height auto-size did not preserve width and enable wrapping.")
		return

	var rich_field := FGUIRichTextField.new()
	host.add_child(rich_field.node)
	rich_field.template_vars = {}
	rich_field.text = "[b]{name}[/b]"
	rich_field.set_var("name", "Ada")
	rich_field.flush_vars()
	if rich_field.label.get_parsed_text() != "Ada":
		_fail("Rich text fields did not resolve text template variables.")
		return

	var input := FGUITextInput.new()
	host.add_child(input.node)
	input.restrict = "0-9"
	input._on_text_changed("a1b2")
	if input.text != "12":
		_fail("Text input numeric restrict ranges were not applied.")
		return
	input.restrict = "^0-9"
	input._on_text_changed("a1b2")
	if input.text != "ab":
		_fail("Text input inverse restrict ranges were not applied.")
		return
	input.restrict = "\\-"
	input._on_text_changed("a-b")
	if input.text != "-":
		_fail("Text input escaped restrict characters were not applied.")
		return

	input.dispose()
	rich_field.dispose()
	field.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
