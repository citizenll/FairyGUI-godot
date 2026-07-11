class_name FGUICustomEase
extends RefCounted

var _points: PackedVector2Array = PackedVector2Array()
var _point_density: int = 200


func _init(point_density: int = 200) -> void:
	_point_density = maxi(2, point_density)


func create(path_points: Array) -> void:
	var path := FGUIGPath.new()
	path.create(path_points)
	create_from_path(path)


func create_from_path(path: FGUIGPath) -> void:
	var sampled: Array[Vector2] = []
	if path != null:
		for index in range(_point_density + 1):
			sampled.append(path.get_point_at(float(index) / float(_point_density)))
	if sampled.is_empty():
		sampled = [Vector2.ZERO, Vector2.ONE]
	sampled[0] = Vector2.ZERO
	sampled[sampled.size() - 1] = Vector2.ONE
	sampled.sort_custom(func(left: Vector2, right: Vector2) -> bool: return left.x < right.x)
	_points = PackedVector2Array(sampled)


func evaluate(time: float) -> float:
	if time <= 0.0:
		return 0.0
	if time >= 1.0:
		return 1.0
	if _points.size() < 2:
		return time
	var low := 0
	var high := _points.size() - 1
	while low + 1 < high:
		var middle := (low + high) / 2
		if _points[middle].x <= time:
			low = middle
		else:
			high = middle
	var start := _points[low]
	var end := _points[high]
	var width := end.x - start.x
	if is_zero_approx(width):
		return start.y
	return start.y + (time - start.x) * (end.y - start.y) / width
