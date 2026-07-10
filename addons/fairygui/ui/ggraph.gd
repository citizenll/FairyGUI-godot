class_name FGUIGraph
extends FGUIObject

const GraphRenderer := preload("res://addons/fairygui/ui/graph_node.gd")

const TYPE_EMPTY := 0
const TYPE_RECT := 1
const TYPE_ELLIPSE := 2
const TYPE_POLYGON := 3
const TYPE_REGULAR_POLYGON := 4

var graph_node
var color_rect
var _type: int = TYPE_EMPTY
var _line_size: float = 1.0
var _line_color: Color = Color.BLACK
var _fill_color: Color = Color.WHITE
var _corner_radii: Array[float] = []
var _polygon_points: PackedVector2Array = PackedVector2Array()
var _sides: int = 0
var _start_angle: float = 0.0
var _distances: Array[float] = []

var type: int:
	get:
		return _type
var polygon_points: PackedVector2Array:
	get:
		return _polygon_points.duplicate()
var fill_color: Color:
	get:
		return _fill_color
	set(value):
		if _fill_color == value:
			return
		_fill_color = value
		_update_graph()
var line_color: Color:
	get:
		return _line_color
	set(value):
		if _line_color == value:
			return
		_line_color = value
		_update_graph()
var color: Color:
	get:
		return _fill_color
	set(value):
		if _fill_color == value:
			return
		_fill_color = value
		update_gear(4)
		_update_graph()
var distances: Array:
	get:
		return _distances.duplicate()
	set(value):
		_distances = _to_float_array(value)
		if _type == TYPE_REGULAR_POLYGON:
			_update_graph()


func _create_display_object() -> void:
	graph_node = GraphRenderer.new()
	graph_node.mouse_filter = Control.MOUSE_FILTER_STOP
	color_rect = ColorRect.new()
	color_rect.color = Color.TRANSPARENT
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_node.add_child(color_rect)
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.offset_left = 0.0
	color_rect.offset_top = 0.0
	color_rect.offset_right = 0.0
	color_rect.offset_bottom = 0.0
	graph_node.compatibility_color_rect = color_rect
	node = graph_node


func draw_rect(line_size: float, next_line_color: Color, next_fill_color: Color, corner_radius: Variant = null) -> void:
	_type = TYPE_RECT
	_line_size = maxf(0.0, line_size)
	_line_color = next_line_color
	_fill_color = next_fill_color
	_corner_radii = _to_float_array(corner_radius)
	_update_graph()


func draw_ellipse(line_size: float, next_line_color: Color, next_fill_color: Color) -> void:
	_type = TYPE_ELLIPSE
	_line_size = maxf(0.0, line_size)
	_line_color = next_line_color
	_fill_color = next_fill_color
	_corner_radii.clear()
	_update_graph()


func draw_polygon(line_size: float, next_line_color: Color, next_fill_color: Color, points: Variant) -> void:
	_type = TYPE_POLYGON
	_line_size = maxf(0.0, line_size)
	_line_color = next_line_color
	_fill_color = next_fill_color
	_polygon_points = _to_packed_points(points)
	_corner_radii.clear()
	_update_graph()


func draw_regular_polygon(line_size: float, next_line_color: Color, next_fill_color: Color, next_sides: int, next_start_angle: float = 0.0, next_distances: Variant = null) -> void:
	_type = TYPE_REGULAR_POLYGON
	_line_size = maxf(0.0, line_size)
	_line_color = next_line_color
	_fill_color = next_fill_color
	_sides = maxi(0, next_sides)
	_start_angle = next_start_angle
	_distances = _to_float_array(next_distances)
	_corner_radii.clear()
	_update_graph()


func get_prop(index: int) -> Variant:
	if index == FGUIEnums.OBJECT_PROP_COLOR:
		return color
	return super.get_prop(index)


func set_prop(index: int, value: Variant) -> void:
	if index == FGUIEnums.OBJECT_PROP_COLOR and value is Color:
		color = value
	else:
		super.set_prop(index, value)


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_before_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 5):
		return
	_type = buffer.read_i8()
	if _type == TYPE_EMPTY:
		_update_graph()
		return
	_line_size = maxf(0.0, float(buffer.read_i32()))
	_line_color = buffer.read_color(true)
	_fill_color = buffer.read_color(true)
	_corner_radii.clear()
	if buffer.read_bool():
		for index in 4:
			_corner_radii.append(buffer.read_float32())
	_polygon_points = PackedVector2Array()
	_distances.clear()
	if _type == TYPE_POLYGON:
		# The package stores a count of float coordinates, not Vector2 points.
		var coordinate_count := mini(maxi(0, buffer.read_i16()), buffer.bytes_available() / 4)
		var coordinate_x := 0.0
		for index in coordinate_count:
			var coordinate := buffer.read_float32()
			if index % 2 == 0:
				coordinate_x = coordinate
			else:
				_polygon_points.append(Vector2(coordinate_x, coordinate))
	elif _type == TYPE_REGULAR_POLYGON:
		_sides = maxi(0, buffer.read_i16())
		_start_angle = buffer.read_float32()
		var distance_count := maxi(0, buffer.read_i16())
		for index in distance_count:
			_distances.append(buffer.read_float32())
	_update_graph()


func _handle_size_changed() -> void:
	super._handle_size_changed()
	if _type != TYPE_EMPTY:
		_update_graph()


func _update_graph() -> void:
	if graph_node == null:
		return
	graph_node.graph_type = _type
	graph_node.line_size = _line_size
	graph_node.line_color = _line_color
	graph_node.fill_color = _fill_color
	graph_node.corner_radii = _corner_radii.duplicate()
	graph_node.polygon_points = _polygon_points.duplicate()
	graph_node.sides = _sides
	graph_node.start_angle = _start_angle
	graph_node.distances = _distances.duplicate()
	if color_rect != null:
		color_rect.visible = _type == TYPE_EMPTY
	graph_node.queue_redraw()


func _to_float_array(value: Variant) -> Array[float]:
	var result: Array[float] = []
	if value is Array or value is PackedFloat32Array or value is PackedFloat64Array or value is PackedInt32Array:
		for entry in value:
			result.append(float(entry))
	return result


func _to_packed_points(value: Variant) -> PackedVector2Array:
	if value is PackedVector2Array:
		return value.duplicate()
	var result := PackedVector2Array()
	if not (value is Array):
		return result
	var index := 0
	while index < value.size():
		var entry = value[index]
		if entry is Vector2:
			result.append(entry)
			index += 1
		elif index + 1 < value.size():
			result.append(Vector2(float(entry), float(value[index + 1])))
			index += 2
		else:
			break
	return result
