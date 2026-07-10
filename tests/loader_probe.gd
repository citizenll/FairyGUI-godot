extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)

	var standalone_clip := _make_movie_clip()
	standalone_clip.interval = 0.1
	standalone_clip._ensure_timer()
	host.add_child(standalone_clip.node)
	await create_timer(0.13).timeout
	if standalone_clip.frame != 1:
		_fail("MovieClip did not start playback after entering the scene tree.")
		return
	standalone_clip.playing = false

	var loader := FGUILoader.new()
	loader.set_size(100.0, 50.0)
	host.add_child(loader.node)
	var loader_clip := _make_movie_clip()
	loader.node.add_child(loader_clip.node)
	loader.content_movie_clip = loader_clip
	loader.source_width = 20.0
	loader.source_height = 10.0
	loader.fill = FGUIEnums.LOADER_FILL_SCALE_FREE
	loader.update_layout()
	if not loader_clip.node.scale.is_equal_approx(Vector2(5.0, 5.0)):
		_fail("Loader did not scale movie clip content.")
		return
	loader.use_resize = true
	if not loader_clip.node.scale.is_equal_approx(Vector2.ONE) or not Vector2(loader_clip.width, loader_clip.height).is_equal_approx(Vector2(100.0, 50.0)):
		_fail("Loader did not resize movie clip content when use_resize is enabled.")
		return
	loader.playing = false
	loader.frame = 1
	loader.time_scale = 2.0
	if loader_clip.playing or loader_clip.frame != 1 or not is_equal_approx(loader_clip.time_scale, 2.0):
		_fail("Loader did not propagate movie clip playback properties.")
		return
	loader._clear_content()
	if loader.content_movie_clip != null:
		_fail("Loader did not dispose movie clip content.")
		return
	var remote_loader := FGUILoader.new()
	host.add_child(remote_loader.node)
	var remote_image := Image.create(3, 2, false, Image.FORMAT_RGBA8)
	remote_image.fill(Color(0.2, 0.6, 0.9, 1.0))
	var image_bytes := remote_image.save_png_to_buffer()
	var decoded_texture := remote_loader._decode_external_texture(image_bytes, "https://cdn.example.test/icon.png?version=1")
	if decoded_texture == null or decoded_texture.get_width() != 3 or decoded_texture.get_height() != 2:
		_fail("Loader did not decode a remote PNG response buffer.")
		return
	remote_loader._url = "https://cdn.example.test/icon.png"
	remote_loader._load_serial = 7
	remote_loader._pending_external_url = remote_loader._url
	remote_loader._active_request_serial = 7
	remote_loader._on_http_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), image_bytes)
	if remote_loader.texture_rect.texture == null or remote_loader.source_width != 3.0 or remote_loader.source_height != 2.0:
		_fail("Loader did not apply a completed remote image response.")
		return
	remote_loader._url = "https://cdn.example.test/new.png"
	remote_loader._load_serial = 8
	remote_loader._pending_external_url = "https://cdn.example.test/icon.png"
	remote_loader._active_request_serial = 7
	remote_loader._on_http_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), image_bytes)
	if remote_loader.texture_rect.texture == null or remote_loader.source_width != 3.0:
		_fail("Loader allowed a stale remote image response to replace current content.")
		return
	var error_package := FGUIPackage.add_package("res://examples/assets/ui/Basics")
	if error_package == null:
		_fail("Loader error-sign test could not load the Basics package.")
		return
	var error_item: FGUIPackageItem
	for item: FGUIPackageItem in error_package.items:
		if item.type == FGUIEnums.PACKAGE_ITEM_COMPONENT:
			error_item = item
			break
	if error_item == null:
		_fail("Loader error-sign test could not find a reusable package component.")
		return
	var previous_error_sign := FGUIConfig.loader_error_sign
	FGUIConfig.loader_error_sign = "ui://%s%s" % [error_package.id, error_item.id]
	var error_loader := FGUILoader.new()
	error_loader.set_size(120.0, 70.0)
	host.add_child(error_loader.node)
	error_loader.url = "ui://missing-package-item"
	if error_loader._error_sign == null or error_loader._error_sign.node.get_parent() != error_loader.node:
		_fail("Loader did not show the configured FairyGUI error-sign component after a load failure.")
		return
	if not Vector2(error_loader._error_sign.width, error_loader._error_sign.height).is_equal_approx(Vector2(120.0, 70.0)):
		_fail("Loader error-sign component did not match the loader bounds.")
		return
	error_loader.set_size(80.0, 45.0)
	if not Vector2(error_loader._error_sign.width, error_loader._error_sign.height).is_equal_approx(Vector2(80.0, 45.0)):
		_fail("Loader error-sign component did not react to loader resizing.")
		return
	error_loader.url = ""
	if error_loader._error_sign != null or error_loader.node.get_child_count() < 2:
		_fail("Loader did not return the error-sign component when its content was cleared.")
		return
	FGUIConfig.loader_error_sign = previous_error_sign
	FGUIPackage.remove_package(error_package.id)

	standalone_clip.dispose()
	remote_loader.dispose()
	error_loader.dispose()
	loader.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _make_movie_clip() -> FGUIMovieClip:
	var clip := FGUIMovieClip.new()
	clip.set_size(20.0, 10.0)
	clip.frames = [
		{"texture": null, "add_delay": 0},
		{"texture": null, "add_delay": 0},
	]
	clip.frame = 0
	return clip


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
