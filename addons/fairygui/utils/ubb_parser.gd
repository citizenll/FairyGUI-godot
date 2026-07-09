class_name FGUIUBBParser
extends RefCounted

static var default_parser := FGUIUBBParser.new()

var default_img_width: int = 0
var default_img_height: int = 0


func parse(text: String, remove: bool = false) -> String:
	if remove:
		return _strip_tags(text)
	var result := text
	result = result.replace("[size=", "[font_size=").replace("[/size]", "[/font_size]")
	return result


func _strip_tags(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[[^\\]]+\\]")
	return regex.sub(text, "", true)
