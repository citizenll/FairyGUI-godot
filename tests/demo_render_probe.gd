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
		if demo_name == "Basics" and not await _validate_grid_hover():
			return
		if demo_name == "Guide" and not await _validate_guide_overlay():
			return
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


func _validate_grid_hover() -> bool:
	_demo.call("_run_basic_demo", null, "Grid")
	await _wait_frames(45)
	var view: FGUIComponent = _demo.get_current_view()
	var container := view.get_child("container") as FGUIComponent
	var panel := container.get_child_at(0) as FGUIComponent
	var list := panel.get_child("list1") as FGUIList
	var row := list.get_child_at(0) as FGUIButton
	var row_rect := row.node.get_global_rect()
	root.push_input(_mouse_motion(row_rect.position + Vector2(row_rect.size.x + 20.0, row_rect.size.y * 0.5), Vector2.ZERO))
	await _wait_frames(2)
	var hover_events := {"over": 0, "out": 0}
	row.on(FGUIEvents.ROLL_OVER, func() -> void: hover_events["over"] += 1)
	row.on(FGUIEvents.ROLL_OUT, func() -> void: hover_events["out"] += 1)
	var previous_pointer := row_rect.position + Vector2(2.0, row_rect.size.y * 0.5)
	root.push_input(_mouse_motion(previous_pointer, Vector2.ZERO))
	for step in 12:
		var pointer := row_rect.position + Vector2(2.0 + (row_rect.size.x - 4.0) * float(step + 1) / 12.0, row_rect.size.y * 0.5)
		root.push_input(_mouse_motion(pointer, pointer - previous_pointer))
		previous_pointer = pointer
		await process_frame
	await _wait_frames(2)
	if hover_events["over"] != 1 or hover_events["out"] != 0 or not row._over:
		_fail("Grid item hover oscillated while crossing descendant controls: %s." % [hover_events])
		return false
	return true


func _validate_guide_overlay() -> bool:
	var view: FGUIComponent = _demo.get_current_view()
	await _native_click(view.get_child("n2"))
	await _wait_frames(40)
	var image := root.get_texture().get_image()
	var outside := image.get_pixel(20, 20)
	if outside.r > 0.85 and outside.g > 0.85 and outside.b > 0.85:
		_fail("Guide reversed mask replaced its child colors with white: %s." % outside)
		return false
	return true


func _native_click(object: FGUIObject) -> void:
	var position := object.node.get_global_rect().get_center()
	root.push_input(_mouse_motion(position, Vector2.ZERO))
	await process_frame
	root.push_input(_mouse_button(position, true))
	await process_frame
	root.push_input(_mouse_button(position, false))
	await process_frame


func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event


func _mouse_motion(position: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	return event


func _wait_frames(count: int) -> void:
	for _index in count:
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	if _demo != null and is_instance_valid(_demo):
		_demo.queue_free()
	quit(1)
