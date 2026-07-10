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

	standalone_clip.dispose()
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
