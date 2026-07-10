extends SceneTree


func _initialize() -> void:
	var data := FGUIPixelHitTestData.new()
	data.pixel_width = 2
	data.scale = 1.0
	data.pixels = PackedByteArray([1])
	var hit_test := FGUIPixelHitTest.new(data, 0, 0)
	if not hit_test.contains(0, 0):
		push_error("Pixel hit test should accept the first bit.")
		quit(1)
		return
	if hit_test.contains(1, 0):
		push_error("Pixel hit test should reject a cleared bit.")
		quit(1)
		return

	var host := Control.new()
	root.add_child(host)
	var component := FGUIComponent.new()
	component.set_size(100, 100)
	host.add_child(component.node)
	var child := FGUIObject.new()
	child.set_xy(20, 10)
	child.set_size(2, 1)
	child.pixel_hit_test = hit_test
	component.add_child(child)
	var metadata := PackedByteArray([6, 1])
	for index in 6:
		_append_i16(metadata, 14 if index == 4 else 0)
	metadata.append_array(PackedByteArray([0, 0, 0]))
	_append_i16(metadata, -1)
	_append_i16(metadata, FGUIByteBuffer.STRING_NULL)
	_append_i32(metadata, 1)
	_append_i32(metadata, 0)
	component._setup_component_metadata(FGUIByteBuffer.new(metadata), null)
	if component.hit_test_child != child:
		push_error("Component metadata did not resolve its child hit area.")
		quit(1)
		return
	var click_counter := {"value": 0}
	component.on("click", func(_event: Variant) -> void: click_counter["value"] += 1)

	component._on_gui_input(_mouse_release(Vector2(20, 10)))
	component._on_gui_input(_mouse_release(Vector2(21, 10)))
	component._on_gui_input(_mouse_release(Vector2(10, 10)))
	if click_counter["value"] != 1:
		push_error("Child hit area did not filter component input by the child pixel hit test.")
		quit(1)
		return

	component.dispose()
	host.queue_free()
	quit(0)


func _mouse_release(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = position
	event.global_position = position
	return event


func _append_i16(bytes: PackedByteArray, value: int) -> void:
	bytes.append((value >> 8) & 0xff)
	bytes.append(value & 0xff)


func _append_i32(bytes: PackedByteArray, value: int) -> void:
	bytes.append((value >> 24) & 0xff)
	bytes.append((value >> 16) & 0xff)
	bytes.append((value >> 8) & 0xff)
	bytes.append(value & 0xff)
