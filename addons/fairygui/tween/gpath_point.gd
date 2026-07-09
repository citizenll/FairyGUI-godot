class_name FGUIGPathPoint
extends RefCounted

var pos: Vector2 = Vector2.ZERO
var control1: Vector2 = Vector2.ZERO
var control2: Vector2 = Vector2.ZERO
var curve_type: int = 0


static func new_point(x: float, y: float) -> FGUIGPathPoint:
	var point := FGUIGPathPoint.new()
	point.pos = Vector2(x, y)
	return point

