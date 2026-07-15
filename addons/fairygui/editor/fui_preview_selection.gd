@tool
extends Control

signal object_picked(value: FGUIObject)

const OUTLINE_COLOR := Color(0.24, 0.68, 1.0, 1.0)
const FILL_COLOR := Color(0.24, 0.68, 1.0, 0.10)
const HANDLE_SIZE := 6.0

var root_object: FGUIObject
var selected_object: FGUIObject


func _ready() -> void:
	# This overlay owns preview-canvas input and forwards navigation to its panel.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func _process(_delta: float) -> void:
	if selected_object != null:
		queue_redraw()


func set_root_object(value: FGUIObject) -> void:
	root_object = value
	if value == null:
		selected_object = null
	queue_redraw()


func set_selected_object(value: FGUIObject) -> void:
	selected_object = value
	queue_redraw()


func pick_object_at(global_position: Vector2) -> FGUIObject:
	if root_object == null or root_object.is_disposed or root_object.node == null:
		return null
	return root_object.hit_test(global_position, true)


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var global_position := get_global_transform() * mouse_event.position
	var picked := pick_object_at(global_position)
	if picked == null:
		return
	object_picked.emit(picked)
	accept_event()


func _draw() -> void:
	if selected_object == null or selected_object.is_disposed or selected_object.node == null:
		return
	if not selected_object.node.is_inside_tree():
		return
	var object_size := Vector2(selected_object.width, selected_object.height)
	if object_size.x <= 0.0 or object_size.y <= 0.0:
		return
	var to_overlay := get_global_transform().affine_inverse() * selected_object.node.get_global_transform()
	var points := PackedVector2Array([
		to_overlay * Vector2.ZERO,
		to_overlay * Vector2(object_size.x, 0.0),
		to_overlay * object_size,
		to_overlay * Vector2(0.0, object_size.y),
	])
	draw_colored_polygon(points, FILL_COLOR)
	var outline := PackedVector2Array([points[0], points[1], points[2], points[3], points[0]])
	draw_polyline(outline, OUTLINE_COLOR, 2.0, true)
	var half_handle := Vector2.ONE * HANDLE_SIZE * 0.5
	for point: Vector2 in points:
		draw_rect(Rect2(point - half_handle, Vector2.ONE * HANDLE_SIZE), OUTLINE_COLOR, true)
