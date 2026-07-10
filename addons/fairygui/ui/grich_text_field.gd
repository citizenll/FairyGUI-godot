class_name FGUIRichTextField
extends FGUITextField


func _create_display_object() -> void:
	label = RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.fit_content = true
	node = label


func _get_text() -> String:
	return _text


func _set_text(value: String) -> void:
	_text = value
	var resolved := _parse_template(value) if _template_vars_enabled else value
	var parsed := FGUIUBBParser.default_parser.parse(resolved) if FGUIUBBParser.default_parser != null else resolved
	if not (label is RichTextLabel):
		return
	var image_regex := RegEx.new()
	image_regex.compile("(?i)\\[img\\](ui://[^\\[]+)\\[/img\\]")
	var first_match := image_regex.search(parsed)
	if first_match == null:
		label.text = parsed
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
