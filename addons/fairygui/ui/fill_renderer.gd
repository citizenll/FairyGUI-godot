class_name FGUIFillRenderer
extends Control

const FILL_NONE := 0
const FILL_HORIZONTAL := 1
const FILL_VERTICAL := 2
const FILL_RADIAL_90 := 3
const FILL_RADIAL_180 := 4
const FILL_RADIAL_360 := 5

var texture: Texture2D
var fill_method: int = FILL_NONE
var fill_origin: int = 0
var fill_clockwise: bool = true
var fill_amount: float = 1.0


func configure(next_texture: Texture2D, next_method: int, next_origin: int, next_clockwise: bool, next_amount: float) -> void:
	texture = next_texture
	fill_method = next_method
	fill_origin = next_origin
	fill_clockwise = next_clockwise
	fill_amount = clampf(next_amount, 0.0, 1.0)
	queue_redraw()


func get_fill_polygon() -> PackedVector2Array:
	return _fill_image(size.x, size.y, fill_method, fill_origin, fill_clockwise, fill_amount)


func get_texture_mapping() -> Dictionary:
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.atlas != null:
			var atlas_size := atlas_texture.atlas.get_size()
			if atlas_size.x > 0.0 and atlas_size.y > 0.0:
				var region := atlas_texture.region
				return {
					"texture": atlas_texture.atlas,
					"uv_rect": Rect2(region.position / atlas_size, region.size / atlas_size),
				}
	return {"texture": texture, "uv_rect": Rect2(0.0, 0.0, 1.0, 1.0)}


func _draw() -> void:
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var points := get_fill_polygon()
	if points.size() < 3:
		return
	var mapping := get_texture_mapping()
	var source_texture = mapping.get("texture") as Texture2D
	if source_texture == null:
		return
	var uv_rect: Rect2 = mapping.get("uv_rect", Rect2(0.0, 0.0, 1.0, 1.0))
	var uvs := PackedVector2Array()
	for point in points:
		var normalized := Vector2(point.x / size.x, point.y / size.y)
		uvs.append(uv_rect.position + normalized * uv_rect.size)
	draw_colored_polygon(points, Color.WHITE, uvs, source_texture)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _fill_image(width: float, height: float, method: int, origin: int, clockwise: bool, amount: float) -> PackedVector2Array:
	if width <= 0.0 or height <= 0.0 or amount <= 0.0:
		return PackedVector2Array()
	if method == FILL_NONE or amount >= 0.9999:
		return _points([Vector2.ZERO, Vector2(width, 0.0), Vector2(width, height), Vector2(0.0, height)])
	match method:
		FILL_HORIZONTAL:
			return _fill_horizontal(width, height, origin, amount)
		FILL_VERTICAL:
			return _fill_vertical(width, height, origin, amount)
		FILL_RADIAL_90:
			return _fill_radial_90(width, height, origin, clockwise, amount)
		FILL_RADIAL_180:
			return _fill_radial_180(width, height, origin, clockwise, amount)
		FILL_RADIAL_360:
			return _fill_radial_360(width, height, origin, clockwise, amount)
		_:
			return PackedVector2Array()


func _fill_horizontal(width: float, height: float, origin: int, amount: float) -> PackedVector2Array:
	var fill_width := width * amount
	if origin == 0 or origin == 2:
		return _points([Vector2.ZERO, Vector2(fill_width, 0.0), Vector2(fill_width, height), Vector2(0.0, height)])
	return _points([Vector2(width, 0.0), Vector2(width, height), Vector2(width - fill_width, height), Vector2(width - fill_width, 0.0)])


func _fill_vertical(width: float, height: float, origin: int, amount: float) -> PackedVector2Array:
	var fill_height := height * amount
	if origin == 0 or origin == 2:
		return _points([Vector2.ZERO, Vector2(0.0, fill_height), Vector2(width, fill_height), Vector2(width, 0.0)])
	return _points([Vector2(0.0, height), Vector2(width, height), Vector2(width, height - fill_height), Vector2(0.0, height - fill_height)])


func _fill_radial_90(width: float, height: float, origin: int, clockwise: bool, amount: float) -> PackedVector2Array:
	if (clockwise and (origin == 1 or origin == 2)) or (not clockwise and (origin == 0 or origin == 3)):
		amount = 1.0 - amount
	var tangent := tan(PI * 0.5 * amount)
	var fill_height := width * tangent
	var fraction := (fill_height - height) / fill_height
	match origin:
		0:
			if clockwise:
				if fill_height <= height:
					return _points([Vector2.ZERO, Vector2(width, fill_height), Vector2(width, 0.0)])
				return _points([Vector2.ZERO, Vector2(width * (1.0 - fraction), height), Vector2(width, height), Vector2(width, 0.0)])
			if fill_height <= height:
				return _points([Vector2.ZERO, Vector2(width, fill_height), Vector2(width, height), Vector2(0.0, height)])
			return _points([Vector2.ZERO, Vector2(width * (1.0 - fraction), height), Vector2(0.0, height)])
		1:
			if clockwise:
				if fill_height <= height:
					return _points([Vector2(width, 0.0), Vector2(0.0, fill_height), Vector2(0.0, height), Vector2(width, height)])
				return _points([Vector2(width, 0.0), Vector2(width * fraction, height), Vector2(width, height)])
			if fill_height <= height:
				return _points([Vector2(width, 0.0), Vector2(0.0, fill_height), Vector2.ZERO])
			return _points([Vector2(width, 0.0), Vector2(width * fraction, height), Vector2(0.0, height), Vector2.ZERO])
		2:
			if clockwise:
				if fill_height <= height:
					return _points([Vector2(0.0, height), Vector2(width, height - fill_height), Vector2(width, 0.0), Vector2.ZERO])
				return _points([Vector2(0.0, height), Vector2(width * (1.0 - fraction), 0.0), Vector2.ZERO])
			if fill_height <= height:
				return _points([Vector2(0.0, height), Vector2(width, height - fill_height), Vector2(width, height)])
			return _points([Vector2(0.0, height), Vector2(width * (1.0 - fraction), 0.0), Vector2(width, 0.0), Vector2(width, height)])
		3:
			if clockwise:
				if fill_height <= height:
					return _points([Vector2(width, height), Vector2(0.0, height - fill_height), Vector2(0.0, height)])
				return _points([Vector2(width, height), Vector2(width * fraction, 0.0), Vector2.ZERO, Vector2(0.0, height)])
			if fill_height <= height:
				return _points([Vector2(width, height), Vector2(0.0, height - fill_height), Vector2.ZERO, Vector2(width, 0.0)])
			return _points([Vector2(width, height), Vector2(width * fraction, 0.0), Vector2(width, 0.0)])
	return PackedVector2Array()


func _fill_radial_180(width: float, height: float, origin: int, clockwise: bool, amount: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	match origin:
		0:
			if amount <= 0.5:
				points = _fill_radial_90(width * 0.5, height, 0 if clockwise else 1, clockwise, amount / 0.5)
				if clockwise:
					_move_points(points, width * 0.5, 0.0)
			else:
				points = _fill_radial_90(width * 0.5, height, 1 if clockwise else 0, clockwise, (amount - 0.5) / 0.5)
				if clockwise:
					points.append_array(_points([Vector2(width, height), Vector2(width, 0.0)]))
				else:
					_move_points(points, width * 0.5, 0.0)
					points.append_array(_points([Vector2(0.0, height), Vector2.ZERO]))
		1:
			if amount <= 0.5:
				points = _fill_radial_90(width * 0.5, height, 3 if clockwise else 2, clockwise, amount / 0.5)
				if not clockwise:
					_move_points(points, width * 0.5, 0.0)
			else:
				points = _fill_radial_90(width * 0.5, height, 2 if clockwise else 3, clockwise, (amount - 0.5) / 0.5)
				if clockwise:
					_move_points(points, width * 0.5, 0.0)
					points.append_array(_points([Vector2.ZERO, Vector2(0.0, height)]))
				else:
					points.append_array(_points([Vector2(width, 0.0), Vector2(width, height)]))
		2:
			if amount <= 0.5:
				points = _fill_radial_90(width, height * 0.5, 2 if clockwise else 0, clockwise, amount / 0.5)
				if not clockwise:
					_move_points(points, 0.0, height * 0.5)
			else:
				points = _fill_radial_90(width, height * 0.5, 0 if clockwise else 2, clockwise, (amount - 0.5) / 0.5)
				if clockwise:
					_move_points(points, 0.0, height * 0.5)
					points.append_array(_points([Vector2(width, 0.0), Vector2.ZERO]))
				else:
					points.append_array(_points([Vector2(width, height), Vector2(0.0, height)]))
		3:
			if amount <= 0.5:
				points = _fill_radial_90(width, height * 0.5, 1 if clockwise else 3, clockwise, amount / 0.5)
				if clockwise:
					_move_points(points, 0.0, height * 0.5)
			else:
				points = _fill_radial_90(width, height * 0.5, 3 if clockwise else 1, clockwise, (amount - 0.5) / 0.5)
				if clockwise:
					points.append_array(_points([Vector2(0.0, height), Vector2(width, height)]))
				else:
					_move_points(points, 0.0, height * 0.5)
					points.append_array(_points([Vector2.ZERO, Vector2(width, 0.0)]))
	return points


func _fill_radial_360(width: float, height: float, origin: int, clockwise: bool, amount: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	match origin:
		0:
			if amount <= 0.5:
				points = _fill_radial_180(width * 0.5, height, 2 if clockwise else 3, clockwise, amount / 0.5)
				if clockwise:
					_move_points(points, width * 0.5, 0.0)
			else:
				points = _fill_radial_180(width * 0.5, height, 3 if clockwise else 2, clockwise, (amount - 0.5) / 0.5)
				if clockwise:
					points.append_array(_points([Vector2(width, height), Vector2(width, 0.0), Vector2(width * 0.5, 0.0)]))
				else:
					_move_points(points, width * 0.5, 0.0)
					points.append_array(_points([Vector2(0.0, height), Vector2.ZERO, Vector2(width * 0.5, 0.0)]))
		1:
			if amount <= 0.5:
				points = _fill_radial_180(width * 0.5, height, 3 if clockwise else 2, clockwise, amount / 0.5)
				if not clockwise:
					_move_points(points, width * 0.5, 0.0)
			else:
				points = _fill_radial_180(width * 0.5, height, 2 if clockwise else 3, clockwise, (amount - 0.5) / 0.5)
				if clockwise:
					_move_points(points, width * 0.5, 0.0)
					points.append_array(_points([Vector2.ZERO, Vector2(0.0, height), Vector2(width * 0.5, height)]))
				else:
					points.append_array(_points([Vector2(width, 0.0), Vector2(width, height), Vector2(width * 0.5, height)]))
		2:
			if amount <= 0.5:
				points = _fill_radial_180(width, height * 0.5, 1 if clockwise else 0, clockwise, amount / 0.5)
				if not clockwise:
					_move_points(points, 0.0, height * 0.5)
			else:
				points = _fill_radial_180(width, height * 0.5, 0 if clockwise else 1, clockwise, (amount - 0.5) / 0.5)
				if clockwise:
					_move_points(points, 0.0, height * 0.5)
					points.append_array(_points([Vector2(width, 0.0), Vector2.ZERO, Vector2(0.0, height * 0.5)]))
				else:
					points.append_array(_points([Vector2(width, height), Vector2(0.0, height), Vector2(0.0, height * 0.5)]))
		3:
			if amount <= 0.5:
				points = _fill_radial_180(width, height * 0.5, 0 if clockwise else 1, clockwise, amount / 0.5)
				if clockwise:
					_move_points(points, 0.0, height * 0.5)
			else:
				points = _fill_radial_180(width, height * 0.5, 1 if clockwise else 0, clockwise, (amount - 0.5) / 0.5)
				if clockwise:
					points.append_array(_points([Vector2(0.0, height), Vector2(width, height), Vector2(width, height * 0.5)]))
				else:
					_move_points(points, 0.0, height * 0.5)
					points.append_array(_points([Vector2.ZERO, Vector2(width, 0.0), Vector2(width, height * 0.5)]))
	return points


func _move_points(points: PackedVector2Array, offset_x: float, offset_y: float) -> void:
	var offset := Vector2(offset_x, offset_y)
	for index in points.size():
		points[index] += offset


func _points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value in values:
		result.append(value as Vector2)
	return result
