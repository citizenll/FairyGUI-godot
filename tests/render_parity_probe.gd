extends SceneTree

const BACKGROUND := Color(0.2, 0.4, 0.6, 1.0)
const SOURCE := Color(0.8, 0.2, 0.1, 0.5)


func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 64)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = BACKGROUND
	viewport.add_child(background)

	var modes := [
		FGUIEnums.BLEND_NORMAL,
		FGUIEnums.BLEND_NONE,
		FGUIEnums.BLEND_ADD,
		FGUIEnums.BLEND_MULTIPLY,
		FGUIEnums.BLEND_SCREEN,
		FGUIEnums.BLEND_ERASE,
		FGUIEnums.BLEND_MASK,
		FGUIEnums.BLEND_BELOW,
		FGUIEnums.BLEND_OFF,
		FGUIEnums.BLEND_ONE_ONE_MINUS_SRC_ALPHA,
	]
	var objects: Array[FGUIGraph] = []
	for index in modes.size():
		var graph := FGUIGraph.new()
		graph.set_xy(index * 32.0, 0.0)
		graph.set_size(32.0, 32.0)
		graph.draw_rect(0.0, Color.TRANSPARENT, SOURCE)
		graph.blend_mode = modes[index]
		viewport.add_child(graph.node)
		objects.append(graph)

	var fill_image := FGUIImage.new()
	fill_image.set_xy(0.0, 32.0)
	fill_image.set_size(32.0, 32.0)
	fill_image._set_texture(_make_white_texture())
	fill_image.fill_method = FGUIEnums.FILL_RADIAL_90
	fill_image.fill_origin = 0
	fill_image.fill_clockwise = true
	fill_image.fill_amount = 0.5
	viewport.add_child(fill_image.node)

	var masked_component := _make_masked_component(false)
	masked_component.set_xy(64.0, 32.0)
	viewport.add_child(masked_component.node)
	var reversed_component := _make_masked_component(true)
	reversed_component.set_xy(96.0, 32.0)
	viewport.add_child(reversed_component.node)

	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	var expected := [
		Color(0.5, 0.3, 0.35, 1.0),
		Color(1.0, 0.6, 0.7, 1.0),
		Color(0.6, 0.5, 0.65, 1.0),
		Color(0.18, 0.24, 0.33, 1.0),
		Color(0.52, 0.46, 0.62, 1.0),
		Color(0.1, 0.2, 0.3, 0.5),
		Color(0.1, 0.2, 0.3, 0.5),
		BACKGROUND,
		Color(0.8, 0.2, 0.1, 0.5),
		Color(0.5, 0.3, 0.35, 1.0),
	]
	for index in expected.size():
		var actual := image.get_pixel(index * 32 + 16, 16)
		if not _color_near(actual, expected[index], 0.14):
			_fail(objects, viewport, "Blend mode %d rendered %s, expected %s." % [modes[index], actual, expected[index]])
			return
	var fill_inside := image.get_pixel(24, 40)
	var fill_outside := image.get_pixel(8, 56)
	if fill_inside.r < 0.85 or not _color_near(fill_outside, BACKGROUND, 0.08):
		_fail(objects, viewport, "Radial fill pixels did not match the exported wedge: %s / %s." % [fill_inside, fill_outside])
		return
	var masked_inside := image.get_pixel(80, 48)
	var masked_outside := image.get_pixel(65, 33)
	var reversed_inside := image.get_pixel(112, 48)
	var reversed_outside := image.get_pixel(97, 33)
	if masked_inside.r < 0.85 or not _color_near(masked_outside, BACKGROUND, 0.08) \
		or not _color_near(reversed_inside, BACKGROUND, 0.08) or reversed_outside.r < 0.85:
		_fail(objects, viewport, "Forward/reversed graph mask pixels were not complementary.")
		return

	fill_image.dispose()
	masked_component.dispose()
	reversed_component.dispose()
	for object in objects:
		object.dispose()
	viewport.queue_free()
	await process_frame
	quit(0)


func _color_near(actual: Color, expected: Color, tolerance: float) -> bool:
	return absf(actual.r - expected.r) <= tolerance \
		and absf(actual.g - expected.g) <= tolerance \
		and absf(actual.b - expected.b) <= tolerance \
		and absf(actual.a - expected.a) <= tolerance


func _make_white_texture() -> ImageTexture:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _make_masked_component(reversed: bool) -> FGUIComponent:
	var component := FGUIComponent.new()
	component.set_size(32.0, 32.0)
	var mask := FGUIGraph.new()
	mask.set_size(32.0, 32.0)
	mask.draw_ellipse(0.0, Color.TRANSPARENT, Color.WHITE)
	component.add_child(mask)
	var content := FGUIGraph.new()
	content.set_size(32.0, 32.0)
	content.draw_rect(0.0, Color.TRANSPARENT, Color.RED)
	component.add_child(content)
	component.set_mask(mask, reversed)
	return component


func _fail(objects: Array[FGUIGraph], viewport: SubViewport, message: String) -> void:
	push_error(message)
	for object in objects:
		if object != null and not object.is_disposed:
			object.dispose()
	if viewport != null:
		viewport.queue_free()
	quit(1)
