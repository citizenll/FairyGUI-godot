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
var compatibility_color_rect: ColorRect
var color: Color:
	get:
		return fill_color
	set(value):
		if fill_color == value:
			return
		fill_color = value
		queue_redraw()


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
