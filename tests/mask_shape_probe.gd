extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var component := FGUIComponent.new()
	component.set_size(100.0, 80.0)
	host.add_child(component.node)
	var mask := FGUIGraph.new()
	mask.set_xy(10.0, 10.0)
	mask.set_size(60.0, 40.0)
	mask.draw_ellipse(0.0, Color.TRANSPARENT, Color.WHITE)
	component.add_child(mask)
	component.set_mask(mask)
	await process_frame

	if not component._contains_mask(Vector2(40.0, 30.0)) or component._contains_mask(Vector2(11.0, 11.0)):
		_fail(component, "Ellipse masks did not use graph geometry for hit testing.")
		return

	component.set_mask(mask, true)
	var material := component.node.material as ShaderMaterial
	var mask_texture := material.get_shader_parameter("mask_texture") as Texture2D if material != null else null
	if mask_texture == null:
		_fail(component, "Reversed graph masks did not generate an alpha texture.")
		return
	var image := mask_texture.get_image()
	if image == null or image.get_pixel(30, 20).a < 0.9 or image.get_pixel(0, 0).a > 0.1:
		_fail(component, "Reversed ellipse mask texture did not preserve shape alpha.")
		return
	mask.fill_color = Color(1.0, 1.0, 1.0, 0.5)
	material = component.node.material as ShaderMaterial
	mask_texture = material.get_shader_parameter("mask_texture") as Texture2D if material != null else null
	image = mask_texture.get_image() if mask_texture != null else null
	var mask_alpha := float(material.get_shader_parameter("mask_alpha")) if material != null else 0.0
	if image == null or absf(image.get_pixel(30, 20).a - 0.5) > 0.05 or absf(mask_alpha - 1.0) > 0.01:
		_fail(component, "Reversed graph masks applied shape alpha more than once.")
		return

	mask.draw_rect(0.0, Color.TRANSPARENT, Color.WHITE, [12.0, 12.0, 12.0, 12.0])
	if mask.graph_node.get_mask_alpha_at(Vector2(1.0, 1.0)) > 0.1 or mask.graph_node.get_mask_alpha_at(Vector2(30.0, 20.0)) < 0.9:
		_fail(component, "Rounded rectangle mask geometry did not preserve corner radii.")
		return

	var texture_mask := FGUIImage.new()
	texture_mask.set_size(32.0, 32.0)
	texture_mask._set_texture(_make_nine_patch_mask_texture())
	texture_mask.image_node.patch_margin_left = 1
	texture_mask.image_node.patch_margin_top = 1
	texture_mask.image_node.patch_margin_right = 1
	texture_mask.image_node.patch_margin_bottom = 1
	component.add_child(texture_mask)
	component.set_mask(texture_mask, true)
	material = component.node.material as ShaderMaterial
	mask_texture = material.get_shader_parameter("mask_texture") as Texture2D if material != null else null
	image = mask_texture.get_image() if mask_texture != null else null
	if image == null or image.get_pixel(0, 0).a < 0.9 or image.get_pixel(16, 16).a > 0.1:
		_fail(component, "Reversed nine-patch masks did not preserve stretched alpha regions.")
		return

	component.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(component: FGUIComponent, message: String) -> void:
	push_error(message)
	if component != null and not component.is_disposed:
		component.dispose()
	quit(1)


func _make_nine_patch_mask_texture() -> ImageTexture:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for index in 4:
		image.set_pixel(index, 0, Color.WHITE)
		image.set_pixel(index, 3, Color.WHITE)
		image.set_pixel(0, index, Color.WHITE)
		image.set_pixel(3, index, Color.WHITE)
	return ImageTexture.create_from_image(image)
