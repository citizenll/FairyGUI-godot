extends Control

var target: FGUIObject


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_target(value: FGUIObject) -> void:
	target = value
	set_process(target != null)
	queue_redraw()


func _process(_delta: float) -> void:
	if target == null or target.is_disposed or target.node == null:
		set_target(null)
		return
	queue_redraw()


func _draw() -> void:
	if target == null or target.is_disposed or target.node == null:
		return
	var inverse := get_global_transform().affine_inverse()
	var points := PackedVector2Array([
		inverse * target.local_to_global(Vector2.ZERO),
		inverse * target.local_to_global(Vector2(target.width, 0.0)),
		inverse * target.local_to_global(Vector2(target.width, target.height)),
		inverse * target.local_to_global(Vector2(0.0, target.height)),
		inverse * target.local_to_global(Vector2.ZERO),
	])
	draw_colored_polygon(PackedVector2Array(points.slice(0, 4)), Color(0.2, 0.65, 1.0, 0.12))
	draw_polyline(points, Color(0.2, 0.72, 1.0), 2.0, true)
	for point: Vector2 in points.slice(0, 4):
		draw_circle(point, 3.0, Color.WHITE)
