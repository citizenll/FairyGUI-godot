extends SceneTree

const SAMPLE_STEP := 24

var _demo: Control
var _save_all_frames := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Demo render probe requires a graphical display driver.")
		quit(1)
		return
	_save_all_frames = OS.get_cmdline_user_args().has("--save-demo-frames")
	var packed := load("res://demo.tscn") as PackedScene
	if packed == null:
		_fail("Root demo.tscn could not be loaded for rendering.")
		return
	_demo = packed.instantiate() as Control
	root.add_child(_demo)
	await _wait_frames(6)
	if not _validate_frame("MainMenu", true):
		return
	for demo_name: String in _demo.get_demo_names():
		if not _demo.open_demo(demo_name):
			_fail("Render probe could not open %s." % demo_name)
			return
		await _wait_frames(5)
		if not _validate_frame(demo_name, false):
			return
		_demo.return_to_menu()
		await _wait_frames(3)
	_demo.queue_free()
	await _wait_frames(4)
	quit(0)


func _validate_frame(label: String, save_image: bool) -> bool:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Demo renderer returned an empty frame for %s." % label)
		return false
	var min_color := Vector3(INF, INF, INF)
	var max_color := Vector3(-INF, -INF, -INF)
	var opaque_samples := 0
	for y in range(SAMPLE_STEP / 2, image.get_height(), SAMPLE_STEP):
		for x in range(SAMPLE_STEP / 2, image.get_width(), SAMPLE_STEP):
			var color := image.get_pixel(x, y)
			if color.a > 0.1:
				opaque_samples += 1
			min_color.x = minf(min_color.x, color.r)
			min_color.y = minf(min_color.y, color.g)
			min_color.z = minf(min_color.z, color.b)
			max_color.x = maxf(max_color.x, color.r)
			max_color.y = maxf(max_color.y, color.g)
			max_color.z = maxf(max_color.z, color.b)
	if opaque_samples < 20 or (max_color - min_color).length() < 0.18:
		_fail("Demo frame was blank or visually uniform for %s." % label)
		return false
	if save_image or _save_all_frames:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.commercial-freeze"))
		var file_name := "demo-menu.png" if label == "MainMenu" else "demo-%s.png" % label.to_snake_case()
		image.save_png(ProjectSettings.globalize_path("res://.commercial-freeze/%s" % file_name))
	return true


func _wait_frames(count: int) -> void:
	for _index in count:
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	if _demo != null and is_instance_valid(_demo):
		_demo.queue_free()
	quit(1)
