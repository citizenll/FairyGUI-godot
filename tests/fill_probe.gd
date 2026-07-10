extends SceneTree

const FillRenderer := preload("res://addons/fairygui/ui/fill_renderer.gd")

func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var renderer := FillRenderer.new()
	host.add_child(renderer)
	renderer.size = Vector2(100.0, 50.0)
	renderer.configure(null, FGUIEnums.FILL_HORIZONTAL, 2, true, 0.25)
	var points := renderer.get_fill_polygon()
	if points.size() != 4 or not points[1].is_equal_approx(Vector2(25.0, 0.0)):
		_fail("Horizontal fill geometry did not honor left origin and amount.")
		return
	renderer.configure(null, FGUIEnums.FILL_VERTICAL, 1, true, 0.5)
	points = renderer.get_fill_polygon()
	if points.size() != 4 or not points[0].is_equal_approx(Vector2(0.0, 50.0)) or not points[2].is_equal_approx(Vector2(100.0, 25.0)):
		_fail("Vertical fill geometry did not honor bottom origin.")
		return
	renderer.configure(null, FGUIEnums.FILL_RADIAL_90, 0, true, 0.5)
	points = renderer.get_fill_polygon()
	if points.size() != 4 or not points[1].is_equal_approx(Vector2(50.0, 50.0)):
		_fail("Radial90 fill geometry did not create the expected wedge.")
		return
	renderer.configure(null, FGUIEnums.FILL_RADIAL_180, 0, true, 0.75)
	if renderer.get_fill_polygon().size() < 4:
		_fail("Radial180 fill geometry was not generated.")
		return
	renderer.configure(null, FGUIEnums.FILL_RADIAL_360, 3, false, 0.75)
	if renderer.get_fill_polygon().size() < 5:
		_fail("Radial360 fill geometry was not generated.")
		return

	var texture := _make_texture()
	var image := FGUIImage.new()
	host.add_child(image.node)
	image.set_size(40.0, 20.0)
	image._set_texture(texture)
	image.fill_method = FGUIEnums.FILL_HORIZONTAL
	image.fill_origin = 2
	image.fill_amount = 0.5
	await process_frame
	if not image.fill_renderer.visible or image.image_node.self_modulate.a != 0.0 or image.fill_renderer.get_fill_polygon().size() != 4:
		_fail("GImage did not activate the reusable fill renderer.")
		return

	var loader := FGUILoader.new()
	host.add_child(loader.node)
	loader.set_size(40.0, 20.0)
	loader._set_texture(texture)
	loader.source_width = 8.0
	loader.source_height = 8.0
	loader.fill_method = FGUIEnums.FILL_VERTICAL
	loader.fill_origin = 0
	loader.fill_amount = 0.5
	loader.update_layout()
	await process_frame
	if not loader.fill_renderer.visible or loader.texture_rect.visible or not loader.fill_renderer.size.is_equal_approx(Vector2(8.0, 8.0)):
		_fail("GLoader did not route texture content through the fill renderer.")
		return

	var progress := FGUIProgressBar.new()
	var bar := FGUIImage.new()
	bar.fill_method = FGUIEnums.FILL_HORIZONTAL
	progress._bar_object_h = bar
	progress._bar_max_width_delta = 0.0
	progress.set_size(100.0, 20.0)
	progress.min = 0.0
	progress.max = 100.0
	progress.value = 25.0
	if not is_equal_approx(bar.fill_amount, 0.25) or not is_equal_approx(bar.width, 0.0):
		_fail("Progress bars did not update image fill amount instead of resizing a filled bar.")
		return
	progress.reverse = true
	progress.update(25.0)
	if not is_equal_approx(bar.fill_amount, 0.75):
		_fail("Reverse progress bars did not invert image fill amount.")
		return

	progress.dispose()
	bar.dispose()
	loader.dispose()
	image.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _make_texture() -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
