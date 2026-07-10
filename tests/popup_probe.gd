extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var ui_root := FGUIRoot.new()
	ui_root.set_size(200.0, 100.0)
	host.add_child(ui_root.node)
	var target := FGUIObject.new()
	target.set_xy(160.0, 80.0)
	target.set_size(20.0, 10.0)
	ui_root.add_child(target)
	var popup := FGUIComponent.new()
	popup.set_size(80.0, 30.0)
	ui_root.show_popup(popup, target)
	if popup.parent != ui_root or not ui_root.has_any_popup() or not Vector2(popup.x, popup.y).is_equal_approx(Vector2(100.0, 49.0)):
		_fail("GRoot did not position an auto popup above the target at the viewport edge.")
		return

	var submenu := FGUIComponent.new()
	submenu.set_size(40.0, 15.0)
	ui_root.show_popup(submenu, popup, FGUIEnums.POPUP_DOWN)
	if submenu.parent != ui_root or not ui_root.has_any_popup():
		_fail("GRoot did not add nested popups to its popup stack.")
		return
	ui_root.hide_popup(popup)
	if popup.parent != null or submenu.parent != null or ui_root.has_any_popup():
		_fail("GRoot did not close a popup and its nested stack entries.")
		return

	ui_root.show_popup(popup, target, FGUIEnums.POPUP_DOWN)
	ui_root._on_gui_input(_screen_touch(Vector2(5.0, 5.0), true))
	if popup.parent != null or ui_root.has_any_popup():
		_fail("GRoot did not close popups after an outside touch.")
		return

	submenu.dispose()
	popup.dispose()
	ui_root.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _screen_touch(position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = position
	event.index = 0
	event.pressed = pressed
	return event


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
