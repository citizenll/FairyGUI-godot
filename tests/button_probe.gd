extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var ui_root := FGUIRoot.new()
	ui_root.set_size(200.0, 100.0)
	host.add_child(ui_root.node)
	var button := FGUIButton.new()
	button.mode = FGUIEnums.BUTTON_CHECK
	button._button_controller = _make_button_controller(button)
	ui_root.add_child(button)
	button.selected = true
	if button._button_controller.selected_page != FGUIButton.DOWN:
		_fail("Selected buttons did not enter the down state.")
		return
	button._on_mouse_entered()
	if button._button_controller.selected_page != FGUIButton.SELECTED_OVER:
		_fail("Selected buttons did not enter selectedOver on pointer rollover.")
		return
	button._on_mouse_exited()
	if button._button_controller.selected_page != FGUIButton.DOWN:
		_fail("Selected buttons did not restore down state on pointer rollout.")
		return
	button.grayed = true
	if button._button_controller.selected_page != FGUIButton.SELECTED_DISABLED:
		_fail("Grayed buttons did not select the selectedDisabled page.")
		return
	button.grayed = false
	button._down_effect = 2
	button._down_effect_value = 0.5
	button.set_state(FGUIButton.DOWN)
	if not Vector2(button.scale_x, button.scale_y).is_equal_approx(Vector2(0.5, 0.5)):
		_fail("Button scale down effect was not applied once for a pressed state.")
		return
	button.set_state(FGUIButton.UP)
	if not Vector2(button.scale_x, button.scale_y).is_equal_approx(Vector2.ONE):
		_fail("Button scale down effect was not restored after release.")
		return

	var popup := FGUIComponent.new()
	popup.set_size(20.0, 10.0)
	button.linked_popup = popup
	button.mode = FGUIEnums.BUTTON_COMMON
	button._on_gui_input(_screen_touch(Vector2(5.0, 5.0), true))
	if popup.parent != ui_root:
		_fail("Linked button popups were not toggled on pointer press.")
		return
	button._on_gui_input(_screen_touch(Vector2(5.0, 5.0), false))
	button._on_gui_input(_screen_touch(Vector2(5.0, 5.0), true))
	if popup.parent != null:
		_fail("Linked button popups were not hidden on a second pointer press.")
		return

	popup.dispose()
	button.dispose()
	ui_root.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _make_button_controller(button: FGUIButton) -> FGUIController:
	var controller := FGUIController.new()
	controller.parent = button
	for state in [FGUIButton.UP, FGUIButton.DOWN, FGUIButton.OVER, FGUIButton.SELECTED_OVER, FGUIButton.DISABLED, FGUIButton.SELECTED_DISABLED]:
		controller.add_page(state)
	button.controllers.append(controller)
	return controller


func _screen_touch(position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.index = 0
	event.pressed = pressed
	return event


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
