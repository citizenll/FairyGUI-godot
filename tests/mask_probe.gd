extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var component := FGUIComponent.new()
	component.set_xy(10, 10)
	component.set_size(80, 60)
	host.add_child(component.node)
	if not (component.node is FGUIMaskContainer):
		_fail("Components should use the mask-aware native container.")
		return

	var mask := FGUIGraph.new()
	mask.set_xy(20, 10)
	mask.set_size(30, 30)
	mask.color_rect.color = Color.WHITE
	component.add_child(mask)
	var content := FGUIGraph.new()
	content.set_size(80, 60)
	content.color_rect.color = Color.RED
	component.add_child(content)

	var metadata := PackedByteArray([6, 1])
	for index in 6:
		_append_i16(metadata, 14 if index == 4 else 0)
	metadata.append_array(PackedByteArray([0, 0, 0]))
	_append_i16(metadata, 0)
	metadata.append(0)
	_append_i16(metadata, FGUIByteBuffer.STRING_NULL)
	_append_i32(metadata, 0)
	_append_i32(metadata, -1)
	component._setup_component_metadata(FGUIByteBuffer.new(metadata), null)
	if component.mask != mask or component.node.clip_children != CanvasItem.CLIP_CHILDREN_ONLY or mask.node.visible:
		_fail("Component metadata did not configure a native alpha mask.")
		return

	var click_counter := {"value": 0}
	component.on("click", func(_event: Variant) -> void: click_counter["value"] += 1)
	component._on_gui_input(_mouse_release(Vector2(35, 25)))
	component._on_gui_input(_mouse_release(Vector2(15, 25)))
	if click_counter["value"] != 1:
		_fail("Masked components did not filter input outside the mask bounds.")
		return

	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var inside := image.get_pixel(35, 25)
	var outside := image.get_pixel(15, 25)
	if inside.r <= outside.r + 0.3:
		_fail("Native alpha masking did not clip child rendering.")
		return

	component.remove_child(mask)
	if component.mask != null or component.node.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
		_fail("Removing the mask child did not restore unclipped rendering.")
		return
	component.dispose()
	host.queue_free()
	await process_frame
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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
