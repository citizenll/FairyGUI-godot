class_name FGUIGraphNode
extends Control

const TYPE_EMPTY := 0
const TYPE_RECT := 1
const TYPE_ELLIPSE := 2
const TYPE_POLYGON := 3
const TYPE_REGULAR_POLYGON := 4

var graph_type: int = TYPE_EMPTY
var line_size: float = 1.0
var line_color: Color = Color.BLACK
var fill_color: Color = Color.WHITE
var corner_radii: Array[float] = []
var polygon_points: PackedVector2Array = PackedVector2Array()
var sides: int = 0
var start_angle: float = 0.0
var distances: Array[float] = []
var mask_revision: int = 0
var compatibility_color_rect: ColorRect
var color: Color:
	get:
		return fill_color
	set(value):
		if fill_color == value:
			return
		fill_color = value
		queue_redraw()


func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	if not has_meta("fgui_owner"):
		return true
	var owner := get_meta("fgui_owner")
	if owner != null and owner.has_method("_accepts_native_input_at"):
		return bool(owner.call("_accepts_native_input_at", point))
	return true


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	match graph_type:
		TYPE_RECT:
			_draw_rect_shape()
		TYPE_ELLIPSE, TYPE_POLYGON, TYPE_REGULAR_POLYGON:
			_draw_polygon_shape(get_draw_points())


func get_draw_points() -> PackedVector2Array:
	match graph_type:
		TYPE_ELLIPSE:
			return _build_ellipse_points()
		TYPE_POLYGON:
			return polygon_points.duplicate()
		TYPE_REGULAR_POLYGON:
			return _build_regular_polygon_points()
		_:
			return PackedVector2Array()


func get_mask_alpha() -> float:
	if graph_type == TYPE_EMPTY and compatibility_color_rect != null:
		return compatibility_color_rect.color.a
	return fill_color.a


func get_mask_alpha_at(point: Vector2) -> float:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return 0.0
	if graph_type == TYPE_EMPTY:
		return compatibility_color_rect.color.a if compatibility_color_rect != null else 0.0
	var inside := _contains_shape_point(point)
	var alpha := fill_color.a if inside else 0.0
	if line_size > 0.0 and line_color.a > 0.0 and _is_on_shape_outline(point):
		alpha = maxf(alpha, line_color.a)
	return alpha


func _contains_shape_point(point: Vector2) -> bool:
	match graph_type:
		TYPE_RECT:
			return _contains_rounded_rect(point, 0.0)
		TYPE_ELLIPSE:
			var radius := size * 0.5
			if radius.x <= 0.0 or radius.y <= 0.0:
				return false
			var normalized := (point - radius) / radius
			return normalized.length_squared() <= 1.0
		TYPE_POLYGON, TYPE_REGULAR_POLYGON:
			var points := get_draw_points()
			return points.size() >= 3 and Geometry2D.is_point_in_polygon(point, points)
	return false


func _is_on_shape_outline(point: Vector2) -> bool:
	var half_line := line_size * 0.5
	match graph_type:
		TYPE_RECT:
			return _contains_rounded_rect(point, -half_line) and not _contains_rounded_rect(point, half_line)
		TYPE_ELLIPSE:
			var radius := size * 0.5
			if radius.x <= 0.0 or radius.y <= 0.0:
				return false
			var center := radius
			var outer_radius := radius + Vector2(half_line, half_line)
			var inner_radius := Vector2(maxf(0.001, radius.x - half_line), maxf(0.001, radius.y - half_line))
			var outer := ((point - center) / outer_radius).length_squared() <= 1.0
			var inner := ((point - center) / inner_radius).length_squared() <= 1.0
			return outer and not inner
		TYPE_POLYGON, TYPE_REGULAR_POLYGON:
			var points := get_draw_points()
			if points.size() < 2:
				return false
			for index in points.size():
				var closest := Geometry2D.get_closest_point_to_segment(point, points[index], points[(index + 1) % points.size()])
				if point.distance_to(closest) <= half_line:
					return true
	return false


func _contains_rounded_rect(point: Vector2, inset: float) -> bool:
	var rect := Rect2(Vector2(inset, inset), size - Vector2(inset * 2.0, inset * 2.0))
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or not rect.has_point(point):
		return false
	if corner_radii.is_empty():
		return true
	var radii := [
		maxf(0.0, _corner_radius_at(0) - inset),
		maxf(0.0, _corner_radius_at(1) - inset),
		maxf(0.0, _corner_radius_at(2) - inset),
		maxf(0.0, _corner_radius_at(3) - inset),
	]
	var corners := [
		Vector2(rect.position.x + radii[0], rect.position.y + radii[0]),
		Vector2(rect.end.x - radii[1], rect.position.y + radii[1]),
		Vector2(rect.position.x + radii[2], rect.end.y - radii[2]),
		Vector2(rect.end.x - radii[3], rect.end.y - radii[3]),
	]
	if point.x < corners[0].x and point.y < corners[0].y:
		return point.distance_squared_to(corners[0]) <= radii[0] * radii[0]
	if point.x > corners[1].x and point.y < corners[1].y:
		return point.distance_squared_to(corners[1]) <= radii[1] * radii[1]
	if point.x < corners[2].x and point.y > corners[2].y:
		return point.distance_squared_to(corners[2]) <= radii[2] * radii[2]
	if point.x > corners[3].x and point.y > corners[3].y:
		return point.distance_squared_to(corners[3]) <= radii[3] * radii[3]
	return true


func _draw_rect_shape() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if corner_radii.is_empty():
		if fill_color.a > 0.0:
			draw_rect(rect, fill_color, true)
		if line_size > 0.0 and line_color.a > 0.0:
			draw_rect(rect, line_color, false, line_size, true)
		return
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = fill_color
	style_box.corner_radius_top_left = roundi(_corner_radius_at(0))
	style_box.corner_radius_top_right = roundi(_corner_radius_at(1))
	style_box.corner_radius_bottom_right = roundi(_corner_radius_at(3))
	style_box.corner_radius_bottom_left = roundi(_corner_radius_at(2))
	if line_size > 0.0 and line_color.a > 0.0:
		var border_size := maxi(1, roundi(line_size))
		style_box.border_width_left = border_size
		style_box.border_width_top = border_size
		style_box.border_width_right = border_size
		style_box.border_width_bottom = border_size
		style_box.border_color = line_color
	draw_style_box(style_box, rect)


func _draw_polygon_shape(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	if points.size() >= 3 and fill_color.a > 0.0:
		draw_colored_polygon(points, fill_color)
	if line_size > 0.0 and line_color.a > 0.0:
		var outline := points.duplicate()
		if points.size() >= 3:
			outline.append(points[0])
		draw_polyline(outline, line_color, line_size, true)


func _build_ellipse_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	var radius_x := size.x * 0.5
	var radius_y := size.y * 0.5
	if radius_x <= 0.0 or radius_y <= 0.0:
		return result
	var segment_count := clampi(ceili(maxf(size.x, size.y) * 0.5), 16, 96)
	var center := Vector2(radius_x, radius_y)
	for index in segment_count:
		var angle := TAU * float(index) / float(segment_count)
		result.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return result


func _build_regular_polygon_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	if sides < 3:
		return result
	var radius := minf(size.x, size.y) * 0.5
	if radius <= 0.0:
		return result
	var center := size * 0.5
	var delta_angle := TAU / float(sides)
	var angle := deg_to_rad(start_angle)
	for index in sides:
		var distance := _distance_at(index)
		result.append(center + Vector2(cos(angle), sin(angle)) * radius * distance)
		angle += delta_angle
	return result


func _corner_radius_at(index: int) -> float:
	if index < 0 or index >= corner_radii.size():
		return 0.0
	return clampf(corner_radii[index], 0.0, minf(size.x, size.y) * 0.5)


func _distance_at(index: int) -> float:
	if index < 0 or index >= distances.size() or is_nan(distances[index]):
		return 1.0
	return distances[index]
