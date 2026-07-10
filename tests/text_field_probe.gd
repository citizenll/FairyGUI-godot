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
	field.set_size(48.0, 16.0)
	field.font_size = 20
	field.single_line = true
	field.auto_size = FGUIEnums.AUTOSIZE_SHRINK
	field.text = "Shrink this text"
	await process_frame
	if field.label.label_settings.font_size >= 20 or field.label.get_minimum_size().x > field.width + 0.5:
		_fail("Shrink auto-size did not reduce the effective font size to fit fixed bounds.")
		return
	field.auto_size = FGUIEnums.AUTOSIZE_BOTH
	if field.label.label_settings.font_size != 20:
		_fail("Leaving Shrink auto-size did not restore the requested font size.")
		return
	var bitmap_field := FGUITextField.new()
	host.add_child(bitmap_field.node)
	bitmap_field._bitmap_font = _make_bitmap_font()
	bitmap_field.font_size = 10
	bitmap_field.leading = 2
	bitmap_field.letter_spacing = 1
	bitmap_field.auto_size = FGUIEnums.AUTOSIZE_HEIGHT
	bitmap_field.set_size(20.0, 1.0)
	bitmap_field.single_line = false
	bitmap_field.text = "AAA"
	if bitmap_field._bitmap_nodes.size() != 3 or bitmap_field.height < 21.0 or bitmap_field._bitmap_nodes[2].position.y < 11.0:
		_fail("Bitmap text did not wrap into lines and auto-size its height.")
		return
	bitmap_field.auto_size = FGUIEnums.AUTOSIZE_NONE
	bitmap_field.single_line = true
	bitmap_field.letter_spacing = 0
	bitmap_field.set_size(30.0, 30.0)
	bitmap_field.align = FGUIEnums.ALIGN_RIGHT
	bitmap_field.valign = FGUIEnums.VERT_ALIGN_BOTTOM
	bitmap_field.text = "A"
	if not bitmap_field._bitmap_nodes[0].position.is_equal_approx(Vector2(22.0, 20.0)):
		_fail("Bitmap text did not honor horizontal and vertical alignment.")
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
	bitmap_field.dispose()
	field.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _make_bitmap_font() -> FGUIBitmapFont:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var font := FGUIBitmapFont.new()
	font.tint = true
	font.font_size = 10
	font.line_height = 10
	font.glyphs[65] = {"x": 0, "y": 0, "width": 8, "height": 8, "advance": 8, "texture": texture}
	return font
