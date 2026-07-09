class_name FGUIMargin
extends RefCounted

var left: int = 0
var right: int = 0
var top: int = 0
var bottom: int = 0


func copy(source: FGUIMargin) -> void:
	top = source.top
	bottom = source.bottom
	left = source.left
	right = source.right


func to_rect2i() -> Rect2i:
	return Rect2i(left, top, right, bottom)

