extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var ui_root := FGUIRoot.new()
	ui_root.set_size(200.0, 100.0)
	host.add_child(ui_root.node)
	await process_frame
	if ui_root._attached_viewport == null or not ui_root._attached_viewport.size_changed.is_connected(Callable(ui_root, "_on_viewport_size_changed")):
		_fail("GRoot did not connect to viewport size changes.")
		return
	ui_root.set_size(200.0, 100.0)
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

	var tooltip_owner := FGUIObject.new()
	tooltip_owner.tooltips = "Native tooltip"
	if tooltip_owner.node.tooltip_text != "Native tooltip":
		_fail("GObject did not expose native tooltip text without a configured tooltip window.")
		return
	var tooltip := FGUIComponent.new()
	tooltip.set_size(20.0, 10.0)
	ui_root.show_tooltips_win(tooltip, Vector2(195.0, 95.0))
	if tooltip.parent != ui_root or not Vector2(tooltip.x, tooltip.y).is_equal_approx(Vector2(153.0, 84.0)):
		_fail("GRoot did not position a custom tooltip inside the viewport.")
		return
	ui_root.hide_tooltips()
	if tooltip.parent != null:
		_fail("GRoot did not hide a custom tooltip.")
		return
	var input := FGUITextInput.new()
	input.set_size(60.0, 20.0)
	ui_root.add_child(input)
	ui_root.focus = input
	await process_frame
	if ui_root.focus != input or not input.line_edit.has_focus():
		_fail("GRoot did not map focus to the Godot input control.")
		return

	input.dispose()
	tooltip.dispose()
	tooltip_owner.dispose()
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
