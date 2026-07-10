extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var list := FGUIList.new()
	list.selection_mode = FGUIEnums.LIST_SELECTION_MULTIPLE
	host.add_child(list.node)
	for _index in 5:
		var item := FGUIButton.new()
		item.mode = FGUIEnums.BUTTON_CHECK
		item.set_size(30.0, 20.0)
		list.add_child(item)

	list._click_item(_click_event(), list.get_child_at(1))
	if list.get_selection() != [1]:
		_fail("Multiple list selection did not select the clicked item.")
		return
	list._click_item(_click_event(true), list.get_child_at(3))
	if list.get_selection() != [1, 2, 3]:
		_fail("Shift-click did not select a contiguous item range.")
		return
	list._click_item(_click_event(false, true), list.get_child_at(2))
	if list.get_selection() != [1, 3]:
		_fail("Ctrl-click did not toggle a selected list item.")
		return

	list.selection_mode = FGUIEnums.LIST_SELECTION_MULTIPLE_SINGLE_CLICK
	list.clear_selection()
	list._click_item(_click_event(), list.get_child_at(4))
	list._click_item(_click_event(), list.get_child_at(4))
	if not list.get_selection().is_empty():
		_fail("Multiple-single-click mode did not toggle a list item.")
		return

	list.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _click_event(shift_pressed: bool = false, ctrl_pressed: bool = false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.shift_pressed = shift_pressed
	event.ctrl_pressed = ctrl_pressed
	return event


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
