class_name FGUIRichTextField
extends FGUITextField


func _create_display_object() -> void:
	label = RichTextLabel.new()
	# FairyGUI rich text fields are interactive, unlike ordinary text fields.
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.bbcode_enabled = true
	label.fit_content = true
	node = label


func _get_text() -> String:
	return _text


func _set_text(value: String) -> void:
	_text = value
	var resolved := _parse_template(value) if _template_vars_enabled else value
	_set_rich_text_content(resolved)


func _apply_display_text() -> void:
	_set_text(_text)


func _append_package_image(url: String) -> void:
	var item := FGUIPackage.get_item_by_url(url)
	if item == null:
		return
	item = item.get_branch().get_high_resolution()
	item.load()
	if item.texture == null:
		return
	label.add_image(item.texture, item.width, item.height)
