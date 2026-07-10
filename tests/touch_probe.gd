extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)

	var button := FGUIButton.new()
	button.mode = FGUIEnums.BUTTON_CHECK
	button.set_size(60.0, 30.0)
	host.add_child(button.node)
	var click_count := {"value": 0}
	button.on("click", func(_event: Variant) -> void: click_count["value"] += 1)
	button._on_gui_input(_screen_touch(Vector2(20.0, 10.0), true, 0))
	button._on_gui_input(_screen_touch(Vector2(20.0, 10.0), false, 0))
	if click_count["value"] != 1 or not button.selected:
		_fail("Buttons did not handle primary screen touches.")
		return

	var draggable := FGUIObject.new()
	draggable.set_size(20.0, 20.0)
	draggable.draggable = true
	host.add_child(draggable.node)
	var drag_counts := {"start": 0, "move": 0, "end": 0}
	draggable.on(FGUIEvents.DRAG_START, func(_event: Variant) -> void: drag_counts["start"] += 1)
	draggable.on(FGUIEvents.DRAG_MOVE, func(_event: Variant) -> void: drag_counts["move"] += 1)
	draggable.on(FGUIEvents.DRAG_END, func(_event: Variant) -> void: drag_counts["end"] += 1)
	draggable._on_gui_input(_screen_touch(Vector2(10.0, 10.0), true, 1))
	draggable._on_gui_input(_screen_drag(Vector2(35.0, 30.0), 1))
	draggable._on_gui_input(_screen_touch(Vector2(35.0, 30.0), false, 1))
	if not Vector2(draggable.x, draggable.y).is_equal_approx(Vector2(25.0, 20.0)) or drag_counts["start"] != 1 or drag_counts["move"] != 1 or drag_counts["end"] != 1:
		_fail("Draggable objects did not handle screen drag events.")
		return

	var slider := FGUISlider.new()
	slider.set_size(100.0, 20.0)
	slider.max = 100.0
	var bar := FGUIObject.new()
	bar.set_size(100.0, 20.0)
	slider.add_child(bar)
	slider._bar_object_h = bar
	host.add_child(slider.node)
	slider._on_gui_input(_screen_touch(Vector2(75.0, 10.0), true, 2))
	if absf(slider.value - 75.0) > 0.1:
		_fail("Sliders did not handle screen touches.")
		return

	var component := FGUIComponent.new()
	component.set_xy(120.0, 0.0)
	component.set_size(60.0, 40.0)
	host.add_child(component.node)
	var mask := FGUIGraph.new()
	mask.set_xy(10.0, 5.0)
	mask.set_size(20.0, 20.0)
	component.add_child(mask)
	component.set_mask(mask)
	var component_clicks := {"value": 0}
	component.on("click", func(_event: Variant) -> void: component_clicks["value"] += 1)
	component._on_gui_input(_screen_touch(Vector2(125.0, 10.0), true, 3))
	component._on_gui_input(_screen_touch(Vector2(125.0, 10.0), false, 3))
	component._on_gui_input(_screen_touch(Vector2(135.0, 10.0), true, 4))
	component._on_gui_input(_screen_touch(Vector2(135.0, 10.0), false, 4))
	if component_clicks["value"] != 1:
		_fail("Mask input filtering did not handle screen touches.")
		return

	component.dispose()
	slider.dispose()
	draggable.dispose()
	button.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _screen_touch(position: Vector2, pressed: bool, index: int) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.index = index
	event.pressed = pressed
	return event


func _screen_drag(position: Vector2, index: int) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.position = position
	event.index = index
	return event


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
