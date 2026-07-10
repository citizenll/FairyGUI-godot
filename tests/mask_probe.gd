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
	await process_frame

	var reverse_component := FGUIComponent.new()
	reverse_component.set_xy(10, 10)
	reverse_component.set_size(80, 60)
	host.add_child(reverse_component.node)
	var reverse_mask := FGUIGraph.new()
	reverse_mask.set_xy(20, 10)
	reverse_mask.set_size(30, 30)
	reverse_mask.color_rect.color = Color.WHITE
	reverse_component.add_child(reverse_mask)
	var reverse_content := FGUIGraph.new()
	reverse_content.set_size(80, 60)
	reverse_content.color_rect.color = Color.RED
	reverse_component.add_child(reverse_content)
	reverse_component.set_mask(reverse_mask, true)
	if reverse_component.node.clip_children != CanvasItem.CLIP_CHILDREN_ONLY or not (reverse_component.node.material is ShaderMaterial):
		_fail("Reversed masks did not configure a clipped shader container.")
		return

	var reverse_click_counter := {"value": 0}
	reverse_component.on("click", func(_event: Variant) -> void: reverse_click_counter["value"] += 1)
	reverse_component._on_gui_input(_mouse_release(Vector2(15, 25)))
	reverse_component._on_gui_input(_mouse_release(Vector2(35, 25)))
	if reverse_click_counter["value"] != 1:
		_fail("Reversed masks did not filter input inside the mask bounds.")
		return

	await process_frame
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	inside = image.get_pixel(35, 25)
	outside = image.get_pixel(15, 25)
	if outside.r <= inside.r + 0.3:
		_fail("Reversed alpha masking did not clip child rendering inside the mask.")
		return
	reverse_component.dispose()
	await process_frame

	var texture_component := FGUIComponent.new()
	texture_component.set_xy(110, 10)
	texture_component.set_size(80, 60)
	host.add_child(texture_component.node)
	var texture_mask := FGUIImage.new()
	texture_mask.set_xy(20, 10)
	texture_mask.set_size(30, 30)
	texture_mask.image_node.texture = _make_half_alpha_texture()
	texture_component.add_child(texture_mask)
	var texture_content := FGUIGraph.new()
	texture_content.set_size(80, 60)
	texture_content.color_rect.color = Color.RED
	texture_component.add_child(texture_content)
	texture_component.set_mask(texture_mask, true)
	await process_frame
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	var opaque_mask_pixel := image.get_pixel(135, 25)
	var transparent_mask_pixel := image.get_pixel(155, 25)
	if transparent_mask_pixel.r <= opaque_mask_pixel.r + 0.3:
		_fail("Reversed texture masks did not respect source alpha.")
		return
	texture_component.dispose()
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


func _make_half_alpha_texture() -> ImageTexture:
	var image := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.WHITE)
	image.set_pixel(1, 0, Color(1, 1, 1, 0))
	return ImageTexture.create_from_image(image)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
