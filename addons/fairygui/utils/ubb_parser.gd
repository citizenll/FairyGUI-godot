class_name FGUIUBBParser
extends RefCounted

## Converts FairyGUI UBB into the BBCode accepted by Godot RichTextLabel.
##
## Image tags deliberately remain [img]ui://...[/img]. FGUIRichTextField
## resolves those package URLs before forwarding the surrounding BBCode to Godot.

static var default_parser := FGUIUBBParser.new()

var default_img_width: int = 0
var default_img_height: int = 0
var last_color: String = ""
var last_size: String = ""
var link_underline: bool = false
var link_color: String = ""

var _text: String = ""
var _read_pos: int = 0
var _align_stack: Array[String] = []


func parse(text: String, remove: bool = false) -> String:
	_text = text
	_read_pos = 0
	_align_stack.clear()
	last_color = ""
	last_size = ""

	var result := ""
	var pos := 0
	while true:
		var tag_start := _text.find("[", pos)
		if tag_start == -1:
			break
		if tag_start > 0 and _text[tag_start - 1] == "\\":
			result += _text.substr(pos, tag_start - pos - 1)
			result += "["
			pos = tag_start + 1
			continue

		result += _text.substr(pos, tag_start - pos)
		var tag_end := _text.find("]", tag_start + 1)
		if tag_end == -1:
			pos = tag_start
			break

		var end := tag_start + 1 < _text.length() and _text[tag_start + 1] == "/"
		var content_start := tag_start + (2 if end else 1)
		var raw_tag := _text.substr(content_start, tag_end - content_start)
		_read_pos = tag_end + 1

		var attribute := ""
		var separator := raw_tag.find("=")
		if separator != -1:
			attribute = raw_tag.substr(separator + 1)
			raw_tag = raw_tag.substr(0, separator)
		var tag_name := raw_tag.to_lower()

		if _is_supported_tag(tag_name):
			if not remove:
				var replacement := _convert_tag(tag_name, end, attribute)
				if replacement != null:
					result += str(replacement)
		else:
			result += _text.substr(tag_start, _read_pos - tag_start)
		pos = _read_pos

	if pos < _text.length():
		result += _text.substr(pos)
	_text = ""
	return result


func _is_supported_tag(tag_name: String) -> bool:
	match tag_name:
		"url", "img", "b", "i", "u", "sup", "sub", "strike", "color", "font", "size", "align", "br":
			return true
		_:
			return false


func _convert_tag(tag_name: String, end: bool, attribute: String) -> Variant:
	match tag_name:
		"url":
			if end:
				var close := ""
				if link_color != "":
					close += "[/color]"
				if link_underline:
					close += "[/u]"
				return close + "[/url]"
			var href := attribute
			if href == "":
				var text_href := _get_tag_text()
				href = str(text_href) if text_href != null else ""
			var open := "[url=%s]" % href
			if link_underline:
				open += "[u]"
			if link_color != "":
				open += "[color=%s]" % link_color
			return open
		"img":
			if end:
				return null
			var source := attribute
			if source == "":
				var image_source := _consume_image_source()
				if image_source == null:
					return null
				source = str(image_source)
			return "[img]%s[/img]" % source if source != "" else null
		"b", "i", "u", "sup", "sub":
			return "[/%s]" % tag_name if end else "[%s]" % tag_name
		"strike":
			return "[/s]" if end else "[s]"
		"color":
			if end:
				return "[/color]"
			last_color = attribute
			return "[color=%s]" % attribute
		"size":
			if end:
				return "[/font_size]"
			last_size = attribute
			return "[font_size=%s]" % attribute
		"font":
			return "[/font]" if end else "[font=%s]" % attribute
		"align":
			if end:
				if _align_stack.is_empty():
					return null
				return "[/%s]" % _align_stack.pop_back()
			var alignment := attribute.to_lower()
			if not ["left", "center", "right", "fill"].has(alignment):
				return null
			_align_stack.append(alignment)
			return "[%s]" % alignment
		"br":
			return "" if end else "\n"
		_:
			return null


func _get_tag_text() -> Variant:
	var pos := _read_pos
	var result := ""
	while true:
		var next_tag := _text.find("[", pos)
		if next_tag == -1:
			return null
		if next_tag > 0 and _text[next_tag - 1] == "\\":
			result += _text.substr(pos, next_tag - pos - 1)
			result += "["
			pos = next_tag + 1
			continue
		result += _text.substr(pos, next_tag - pos)
		return result
	return null


func _consume_image_source() -> Variant:
	var pos := _read_pos
	var result := ""
	while true:
		var tag_start := _text.find("[", pos)
		if tag_start == -1:
			return null
		if tag_start > 0 and _text[tag_start - 1] == "\\":
			result += _text.substr(pos, tag_start - pos - 1)
			result += "["
			pos = tag_start + 1
			continue

		var tag_end := _text.find("]", tag_start + 1)
		if tag_end == -1:
			return null
		var tag_name := _text.substr(tag_start + 1, tag_end - tag_start - 1).to_lower()
		if tag_name != "/img":
			return null
		result += _text.substr(pos, tag_start - pos)
		_read_pos = tag_end + 1
		return result
	return null
