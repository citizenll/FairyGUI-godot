class_name FGUIBitmapFont
extends RefCounted

var tint: bool = false
var auto_scale_size: bool = false
var font_size: int = 1
var line_height: int = 1
var glyphs: Dictionary = {}


func get_glyph(code: int) -> Dictionary:
	return glyphs.get(code, {})
