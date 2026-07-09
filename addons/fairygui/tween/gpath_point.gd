class_name FGUIGPathPoint
extends RefCounted

var pos: Vector2 = Vector2.ZERO
var control1: Vector2 = Vector2.ZERO
var control2: Vector2 = Vector2.ZERO
var curve_type: int = 0


static func new_point(x: float, y: float, p_curve_type: int = 0) -> FGUIGPathPoint:
	var point := FGUIGPathPoint.new()
	point.pos = Vector2(x, y)
	point.curve_type = p_curve_type
	return point


static func new_bezier_point(x: float, y: float, control1_x: float, control1_y: float) -> FGUIGPathPoint:
	var point := new_point(x, y, 1)
	point.control1 = Vector2(control1_x, control1_y)
	return point


static func new_cubic_bezier_point(x: float, y: float, control1_x: float, control1_y: float, control2_x: float, control2_y: float) -> FGUIGPathPoint:
	var point := new_point(x, y, 2)
	point.control1 = Vector2(control1_x, control1_y)
	point.control2 = Vector2(control2_x, control2_y)
	return point
