class_name FGUIRichTextField
extends FGUITextField


func _create_display_object() -> void:
	label = RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.fit_content = true
	node = label


func _get_text() -> String:
	return label.text


func _set_text(value: String) -> void:
	label.text = FGUIUBBParser.default_parser.parse(value) if FGUIUBBParser.default_parser != null else value
