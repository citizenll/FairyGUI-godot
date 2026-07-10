class_name FGUIGPath
extends RefCounted

const CURVE_SPLINE := 0
const CURVE_BEZIER := 1
const CURVE_CUBIC_BEZIER := 2
const CURVE_STRAIGHT := 3

var points: Array[FGUIGPathPoint] = []
var _segments: Array[Dictionary] = []
var _anchors: Array[Vector2] = []
var _full_length: float = 0.0

var length: float:
	get:
		return _full_length

var segment_count: int:
	get:
		return _segments.size()


func create(path_points: Array) -> void:
	clear()
	for point in path_points:
		if point is FGUIGPathPoint:
			points.append(point)
	if points.size() < 2:
		return

	var spline_points: Array[Vector2] = []
	var previous := points[0]
	if previous.curve_type == CURVE_SPLINE:
		spline_points.append(previous.pos)
	for index in range(1, points.size()):
		var current := points[index]
		if previous.curve_type != CURVE_SPLINE:
			_append_curve_segment(previous, current)
		if current.curve_type == CURVE_SPLINE:
			spline_points.append(current.pos)
		elif spline_points.size() > 0:
			spline_points.append(current.pos)
			_append_spline_segment(spline_points)
			spline_points.clear()
		previous = current
	if spline_points.size() > 1:
		_append_spline_segment(spline_points)


func clear() -> void:
	points.clear()
	_segments.clear()
	_anchors.clear()
	_full_length = 0.0


func get_point_at(t: float) -> Vector2:
	if _segments.is_empty():
		return Vector2.ZERO
	t = clampf(t, 0.0, 1.0)
	if is_equal_approx(t, 1.0) or _full_length <= 0.0:
		return _evaluate_segment(_segments.back(), 1.0)
	var remaining_length := t * _full_length
	for segment in _segments:
		var segment_length := float(segment["length"])
		if segment_length <= 0.0:
			continue
		remaining_length -= segment_length
		if remaining_length < 0.0:
			return _evaluate_segment(segment, 1.0 + remaining_length / segment_length)
	return _evaluate_segment(_segments.back(), 1.0)


func get_anchors_in_segment(segment_index: int, result: Array[Vector2] = []) -> Array[Vector2]:
	if segment_index < 0 or segment_index >= _segments.size():
		return result
	var segment := _segments[segment_index]
	var start := int(segment["start"])
	var count := int(segment["count"])
	for index in range(count):
		result.append(_anchors[start + index])
	return result


func get_points_in_segment(segment_index: int, t0: float, t1: float, result: Array[Vector2] = [], ts: Array[float] = [], point_density: float = 0.1) -> Array[Vector2]:
	if segment_index < 0 or segment_index >= _segments.size():
		return result
	t0 = clampf(t0, 0.0, 1.0)
	t1 = clampf(t1, 0.0, 1.0)
	if t1 < t0:
		var swap := t0
		t0 = t1
		t1 = swap
	var segment := _segments[segment_index]
	if not is_finite(point_density) or point_density <= 0.0:
		point_density = 0.1
	ts.append(t0)
	result.append(_evaluate_segment(segment, t0))
	if int(segment["type"]) != CURVE_STRAIGHT:
		var sample_count := clampi(int(ceilf(float(segment["length"]) * point_density)), 1, 50)
		for index in range(1, sample_count):
			var sample_t := float(index) / float(sample_count)
			if sample_t > t0 and sample_t < t1:
				result.append(_evaluate_segment(segment, sample_t))
				ts.append(sample_t)
	result.append(_evaluate_segment(segment, t1))
	ts.append(t1)
	return result


func get_all_points(result: Array[Vector2] = [], ts: Array[float] = [], point_density: float = 0.1) -> Array[Vector2]:
	for index in range(_segments.size()):
		get_points_in_segment(index, 0.0, 1.0, result, ts, point_density)
	return result


func _append_curve_segment(previous: FGUIGPathPoint, current: FGUIGPathPoint) -> void:
	var curve_type := previous.curve_type
	var segment_points: Array[Vector2] = [previous.pos, current.pos]
	match curve_type:
		CURVE_BEZIER:
			segment_points.append(previous.control1)
		CURVE_CUBIC_BEZIER:
			segment_points.append(previous.control1)
			segment_points.append(previous.control2)
		CURVE_STRAIGHT:
			pass
		_:
			curve_type = CURVE_STRAIGHT
	_append_segment(curve_type, segment_points, previous.pos.distance_to(current.pos))


func _append_spline_segment(spline_points: Array[Vector2]) -> void:
	if spline_points.size() < 2:
		return
	var segment_points: Array[Vector2] = [spline_points[0]]
	segment_points.append_array(spline_points)
	segment_points.append(spline_points.back())
	segment_points.append(spline_points.back())
	var segment_length := 0.0
	for index in range(1, segment_points.size()):
		segment_length += segment_points[index - 1].distance_to(segment_points[index])
	_append_segment(CURVE_SPLINE, segment_points, segment_length)


func _append_segment(curve_type: int, segment_points: Array[Vector2], segment_length: float) -> void:
	var start := _anchors.size()
	_anchors.append_array(segment_points)
	_segments.append({
		"type": curve_type,
		"start": start,
		"count": segment_points.size(),
		"length": segment_length,
	})
	_full_length += segment_length


func _evaluate_segment(segment: Dictionary, t: float) -> Vector2:
	t = clampf(t, 0.0, 1.0)
	var start := int(segment["start"])
	match int(segment["type"]):
		CURVE_BEZIER:
			return _evaluate_bezier(start, 3, t)
		CURVE_CUBIC_BEZIER:
			return _evaluate_bezier(start, 4, t)
		CURVE_SPLINE:
			return _evaluate_spline(start, int(segment["count"]), t)
		_:
			return _anchors[start].lerp(_anchors[start + 1], t)


func _evaluate_bezier(start: int, count: int, t: float) -> Vector2:
	var inverse_t := 1.0 - t
	var p0 := _anchors[start]
	var p1 := _anchors[start + 1]
	var control1 := _anchors[start + 2]
	if count == 4:
		var control2 := _anchors[start + 3]
		return p0 * inverse_t * inverse_t * inverse_t + control1 * 3.0 * inverse_t * inverse_t * t + control2 * 3.0 * inverse_t * t * t + p1 * t * t * t
	return p0 * inverse_t * inverse_t + control1 * 2.0 * inverse_t * t + p1 * t * t


func _evaluate_spline(start: int, count: int, t: float) -> Vector2:
	var interval_count := maxi(1, count - 4)
	var scaled_t := t * float(interval_count)
	var point_index := int(floorf(scaled_t))
	var local_t := scaled_t - float(point_index)
	if is_equal_approx(t, 1.0):
		point_index = interval_count
		local_t = 1.0
	else:
		point_index = clampi(point_index, 0, interval_count - 1)
	var p0 := _anchors[start + point_index]
	var p1 := _anchors[start + point_index + 1]
	var p2 := _anchors[start + point_index + 2]
	var p3 := _anchors[start + point_index + 3]
	var t0 := ((-local_t + 2.0) * local_t - 1.0) * local_t * 0.5
	var t1 := (((3.0 * local_t - 5.0) * local_t) * local_t + 2.0) * 0.5
	var t2 := ((-3.0 * local_t + 4.0) * local_t + 1.0) * local_t * 0.5
	var t3 := ((local_t - 1.0) * local_t * local_t) * 0.5
	return p0 * t0 + p1 * t1 + p2 * t2 + p3 * t3
