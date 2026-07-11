extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)

	var progress := FGUIProgressBar.new()
	progress.set_size(100.0, 20.0)
	host.add_child(progress.node)
	var progress_title := FGUITextField.new()
	progress.add_child(progress_title)
	progress._title_object = progress_title
	var progress_bar := FGUIObject.new()
	progress_bar.set_xy(10.0, 0.0)
	progress_bar.set_size(80.0, 20.0)
	progress.add_child(progress_bar)
	progress._bar_object_h = progress_bar
	progress._bar_max_width_delta = 20.0
	progress._bar_start_x = 10.0
	progress.min = 20.0
	progress.max = 120.0
	progress.value = 70.0
	if absf(progress_bar.width - 40.0) > 0.1 or progress_title.text != "50%":
		_fail(progress, null, "ProgressBar did not render its configured min/max range.")
		return
	progress.min = 0.0
	if absf(progress_bar.width - 47.0) > 0.1 or progress_title.text != "58%" or not is_equal_approx(progress.value, 70.0):
		_fail(progress, null, "ProgressBar min changes rendered the bound instead of the current value.")
		return
	progress.title_type = FGUIEnums.PROGRESS_TITLE_VALUE_AND_MAX
	if progress_title.text != "70/120":
		_fail(progress, null, "ProgressBar title type did not refresh immediately.")
		return
	progress.set_size(200.0, 20.0)
	if absf(progress_bar.width - 105.0) > 0.1:
		_fail(progress, null, "ProgressBar did not recalculate its fill after resizing.")
		return

	progress.title_type = FGUIEnums.PROGRESS_TITLE_PERCENT
	progress.value = 0.0
	progress.tween_value(120.0, 0.12)
	FGUITweenManager.update(0.04)
	var width_before_retarget := progress_bar.width
	if width_before_retarget <= 0.0 or width_before_retarget >= 180.0:
		_fail(progress, null, "ProgressBar tween_value did not animate through an intermediate value: %s" % width_before_retarget)
		return
	progress.tween_value(60.0, 0.08)
	if absf(progress_bar.width - width_before_retarget) > 1.0:
		_fail(progress, null, "ProgressBar tween retarget jumped away from its current rendered value.")
		return
	FGUITweenManager.update(0.08)
	if absf(progress_bar.width - 90.0) > 1.0 or not is_equal_approx(progress.value, 60.0):
		_fail(progress, null, "ProgressBar tween retarget did not reach the requested value.")
		return
	progress.tween_value(120.0, 0.2)
	FGUITweenManager.update(0.03)
	progress.value = 30.0
	FGUITweenManager.update(0.22)
	if absf(progress_bar.width - 45.0) > 1.0 or FGUIGTween.get_tween(progress, Callable(progress, "update")) != null:
		_fail(progress, null, "Direct ProgressBar value assignment did not cancel its active tween.")
		return

	var slider := FGUISlider.new()
	slider.set_xy(0.0, 40.0)
	slider.set_size(120.0, 20.0)
	host.add_child(slider.node)
	var slider_title := FGUITextField.new()
	slider.add_child(slider_title)
	slider._title_object = slider_title
	var slider_bar := FGUIObject.new()
	slider_bar.set_xy(10.0, 0.0)
	slider_bar.set_size(100.0, 20.0)
	slider.add_child(slider_bar)
	slider._bar_object_h = slider_bar
	slider._bar_max_width_delta = 20.0
	slider._bar_start_x = 10.0
	var grip := FGUIObject.new()
	grip.set_xy(50.0, 0.0)
	grip.set_size(10.0, 20.0)
	slider.add_child(grip)
	slider._grip_object = grip
	grip.draggable = true

	var slider_changes := [0]
	slider.on(FGUIEvents.STATE_CHANGED, func(_event: Variant) -> void: slider_changes[0] += 1)
	slider.min = 0.0
	slider.max = 100.0
	slider.value = 50.0
	slider._on_gui_input(_mouse_press(Vector2(55.0, 50.0)))
	if absf(slider.value - 50.0) > 0.1:
		_fail(progress, slider, "Slider treated a grip press as a track click.")
		return
	slider._on_gui_input(_mouse_press(Vector2(75.0, 50.0)))
	if absf(slider.value - 75.0) > 0.1:
		_fail(progress, slider, "Slider track clicks were not measured relative to the grip and usable bar length: %s" % slider.value)
		return
	slider.value = 50.0
	slider.reverse = true
	slider._on_gui_input(_mouse_press(Vector2(75.0, 50.0)))
	if absf(slider.value - 25.0) > 0.1:
		_fail(progress, slider, "Reverse Slider track clicks moved in the wrong direction.")
		return

	slider.reverse = false
	slider.whole_numbers = true
	slider.max = 3.0
	slider.value = 1.0
	slider._on_gui_input(_mouse_press(Vector2(70.0, 50.0)))
	if not is_equal_approx(slider.value, 2.0):
		_fail(progress, slider, "Slider whole-number mode did not round click updates.")
		return

	slider.whole_numbers = false
	slider.max = 100.0
	slider.value = 50.0
	slider._on_grip_drag_start(_mouse_press(Vector2(60.0, 50.0)))
	slider._on_grip_drag_move(_mouse_motion(Vector2(80.0, 50.0)))
	slider._on_grip_drag_end()
	if absf(slider.value - 70.0) > 0.1:
		_fail(progress, slider, "Slider grip dragging did not preserve its initial click percentage.")
		return
	slider.value = 50.0
	slider.reverse = true
	slider._on_grip_drag_start(_mouse_press(Vector2(60.0, 50.0)))
	slider._on_grip_drag_move(_mouse_motion(Vector2(80.0, 50.0)))
	slider._on_grip_drag_end()
	if absf(slider.value - 30.0) > 0.1:
		_fail(progress, slider, "Reverse Slider grip dragging moved in the wrong direction.")
		return
	slider.can_drag = false
	if grip.draggable:
		_fail(progress, slider, "Slider can_drag did not update the grip's drag state.")
		return
	slider.reverse = false
	slider.value = 50.0
	slider.set_size(220.0, 20.0)
	if absf(slider_bar.width - 100.0) > 0.1 or slider_changes[0] < 4:
		_fail(progress, slider, "Slider resize or state-change dispatch parity failed.")
		return

	progress.dispose()
	slider.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _mouse_press(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event


func _fail(progress: FGUIProgressBar, slider: FGUISlider, message: String) -> void:
	push_error(message)
	if slider != null and not slider.is_disposed:
		slider.dispose()
	if progress != null and not progress.is_disposed:
		progress.dispose()
	quit(1)
