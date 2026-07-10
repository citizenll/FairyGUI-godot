extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var graph := FGUIGraph.new()
	host.add_child(graph.node)
	graph.set_size(100.0, 60.0)
	graph.color_rect.color = Color(0.2, 0.3, 0.4, 0.5)
	if not graph.color_rect.visible or graph.graph_node.get_mask_alpha() != 0.5:
		_fail("Legacy ColorRect graph compatibility did not preserve fill and mask alpha.")
		return
	graph.draw_rect(2.0, Color.RED, Color.BLUE, [8.0, 10.0, 12.0, 14.0])
	if graph.type != FGUIGraph.TYPE_RECT or graph.color_rect.visible or graph.graph_node.corner_radii != [8.0, 10.0, 12.0, 14.0]:
		_fail("Rounded rectangle graph state was not retained.")
		return
	graph.color = Color.GREEN
	if graph.fill_color != Color.GREEN or graph.get_prop(FGUIEnums.OBJECT_PROP_COLOR) != Color.GREEN:
		_fail("Graph color gear property did not update the fill color.")
		return
	graph.draw_ellipse(1.0, Color.BLACK, Color.WHITE)
	var ellipse_points: PackedVector2Array = graph.graph_node.get_draw_points()
	if ellipse_points.size() < 16 or not ellipse_points[0].is_equal_approx(Vector2(100.0, 30.0)):
		_fail("Ellipse graph geometry was not generated from object bounds.")
		return
	graph.draw_polygon(3.0, Color.BLACK, Color.WHITE, [0.0, 0.0, 30.0, 0.0, 15.0, 20.0])
	if graph.polygon_points.size() != 3 or graph.graph_node.get_draw_points().size() != 3:
		_fail("Polygon graph points were not converted from FairyGUI flat point data.")
		return
	var parsed_graph := FGUIGraph.new()
	host.add_child(parsed_graph.node)
	parsed_graph.setup_before_add(_polygon_setup_buffer(), 0)
	if parsed_graph.polygon_points.size() != 3:
		_fail("Graph package parsing did not treat polygon count as flat coordinate values.")
		return
	graph.draw_regular_polygon(1.0, Color.BLACK, Color.WHITE, 4, 0.0, [1.0, 0.5, 1.0, 0.5])
	var regular_points: PackedVector2Array = graph.graph_node.get_draw_points()
	if regular_points.size() != 4 or not regular_points[0].is_equal_approx(Vector2(80.0, 30.0)) or not regular_points[1].is_equal_approx(Vector2(50.0, 45.0)):
		_fail("Regular polygon graph geometry did not apply side count, angle, and distances.")
		return
	graph.set_size(40.0, 80.0)
	regular_points = graph.graph_node.get_draw_points()
	if not regular_points[0].is_equal_approx(Vector2(40.0, 40.0)):
		_fail("Regular polygon graph geometry did not refresh after resize.")
		return
	parsed_graph.dispose()
	graph.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _polygon_setup_buffer() -> FGUIByteBuffer:
	var bytes := PackedByteArray()
	bytes.resize(92)
	bytes[0] = 6
	bytes[1] = 1
	_write_u16(bytes, 2, 14)
	_write_u16(bytes, 12, 52)
	_write_u16(bytes, 49, FGUIByteBuffer.STRING_NULL)
	bytes[52] = FGUIGraph.TYPE_POLYGON
	_write_u16(bytes, 66, 6)
	var buffer := FGUIByteBuffer.new(bytes)
	buffer.string_table = ["parsed_graph"]
	return buffer


func _write_u16(bytes: PackedByteArray, offset: int, value: int) -> void:
	bytes[offset] = (value >> 8) & 0xff
	bytes[offset + 1] = value & 0xff
