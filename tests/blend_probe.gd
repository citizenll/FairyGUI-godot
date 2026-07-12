extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var image := FGUIImage.new()
	host.add_child(image.node)
	image.blend_mode = FGUIEnums.BLEND_ADD
	var direct_material := image.node.material as CanvasItemMaterial
	if direct_material == null or direct_material.blend_mode != CanvasItemMaterial.BLEND_MODE_ADD:
		_fail("FairyGUI additive blend mode was not applied to a leaf render control.")
		return
	image.grayed = true
	var filtered_material := image.node.material as ShaderMaterial
	if filtered_material == null or filtered_material.shader == null or filtered_material.shader.code.find("render_mode blend_add;") == -1:
		_fail("Additive blend mode was not preserved when a color filter was applied.")
		return
	image.grayed = false
	direct_material = image.node.material as CanvasItemMaterial
	if direct_material == null or direct_material.blend_mode != CanvasItemMaterial.BLEND_MODE_ADD:
		_fail("Additive blend mode was not restored after removing a color filter.")
		return
	image.blend_mode = FGUIEnums.BLEND_MULTIPLY
	var multiply_material := image.node.material as ShaderMaterial
	if multiply_material == null or multiply_material.shader.code.find("render_mode blend_mul;") == -1:
		_fail("FairyGUI multiply blend mode was not mapped to Godot canvas multiplication.")
		return
	image.grayed = true
	var multiply_filter_material := image.node.material as ShaderMaterial
	if multiply_filter_material == null or multiply_filter_material.shader.code.find("render_mode blend_mul;") == -1:
		_fail("Multiply blending was not retained by color-filter shaders.")
		return
	image.grayed = false
	image.blend_mode = FGUIEnums.BLEND_SCREEN
	var screen_material := image.node.material as ShaderMaterial
	if screen_material == null or screen_material.shader.code.find("hint_screen_texture") == -1 or screen_material.shader.code.find("render_mode blend_disabled;") == -1:
		_fail("FairyGUI screen blend mode did not use destination-aware compositing.")
		return
	image.blend_mode = FGUIEnums.BLEND_OFF
	var off_material := image.node.material as ShaderMaterial
	if off_material == null or off_material.shader.code.find("render_mode blend_disabled;") == -1:
		_fail("FairyGUI off blend mode did not disable framebuffer blending.")
		return
	image.blend_mode = FGUIEnums.BLEND_ONE_ONE_MINUS_SRC_ALPHA
	var premultiplied_material := image.node.material as ShaderMaterial
	if premultiplied_material == null or premultiplied_material.shader.code.find("render_mode blend_premul_alpha;") == -1:
		_fail("FairyGUI premultiplied-alpha blend mode was not mapped.")
		return
	image._set_texture(_make_texture())
	image.fill_method = FGUIEnums.FILL_HORIZONTAL
	image.blend_mode = FGUIEnums.BLEND_SCREEN
	if not (image.fill_renderer.material is ShaderMaterial) or (image.fill_renderer.material as ShaderMaterial).shader.code.find("hint_screen_texture") == -1:
		_fail("Filled images did not propagate blend modes to their fill renderer.")
		return
	var loader := FGUILoader.new()
	host.add_child(loader.node)
	loader._set_texture(_make_texture())
	loader.fill_method = FGUIEnums.FILL_VERTICAL
	loader.blend_mode = FGUIEnums.BLEND_MULTIPLY
	if not (loader.texture_rect.material is ShaderMaterial) or not (loader.fill_renderer.material is ShaderMaterial):
		_fail("Loaders did not propagate blend modes to texture and fill renderers.")
		return
	image.blend_mode = 99
	if image.blend_mode != FGUIEnums.BLEND_NORMAL or image.node.material != null:
		_fail("Unsupported FairyGUI blend modes should fall back to normal blending.")
		return

	var field := FGUITextField.new()
	host.add_child(field.node)
	field.blend_mode = FGUIEnums.BLEND_ADD
	field.ubb_enabled = true
	if not (field.node.material is CanvasItemMaterial) or (field.node.material as CanvasItemMaterial).blend_mode != CanvasItemMaterial.BLEND_MODE_ADD:
		_fail("Text renderer changes did not preserve FairyGUI additive blend mode.")
		return
	field.grayed = true
	if not (field.node.material is ShaderMaterial) or (field.node.material as ShaderMaterial).shader.code.find("render_mode blend_add;") == -1:
		_fail("Text renderer color filters did not preserve FairyGUI additive blend mode.")
		return

	field.dispose()
	loader.dispose()
	image.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _make_texture() -> ImageTexture:
	var source := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	source.fill(Color.WHITE)
	return ImageTexture.create_from_image(source)
