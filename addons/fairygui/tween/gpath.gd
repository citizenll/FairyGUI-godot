class_name FGUIGPath
extends RefCounted

var points: Array = []


func create(p_points: Array) -> void:
	points = p_points.duplicate()


func clear() -> void:
	points.clear()


func get_point_at(t: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0].pos
	var scaled := clampf(t, 0.0, 1.0) * float(points.size() - 1)
	var index := mini(int(floorf(scaled)), points.size() - 2)
	var local_t := scaled - float(index)
	return points[index].pos.lerp(points[index + 1].pos, local_t)

