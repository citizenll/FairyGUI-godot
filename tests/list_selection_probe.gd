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
	list.select_reverse()
	if list.get_selection() != [0, 2, 4]:
		_fail("List select_reverse did not invert the selected item set.")
		return
	list.get_child_at(4).width = 50.0
	if absf(list.get_max_item_width() - 50.0) > 0.01:
		_fail("List get_max_item_width did not return the widest visible item.")
		return
	list.selection_mode = FGUIEnums.LIST_SELECTION_SINGLE
	list.layout = FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL
	list.column_count = 2
	list.auto_resize_item = false
	list.set_size(100.0, 100.0)
	list.update_bounds()
	list.selected_index = 1
	list.handle_arrow_key(5)
	if list.selected_index != 3:
		_fail("List down-arrow navigation did not preserve the flow-layout column.")
		return
	list.handle_arrow_key(1)
	if list.selected_index != 1:
		_fail("List up-arrow navigation did not return to the preceding flow-layout row.")
		return
	var aligned_list := FGUIList.new()
	aligned_list.layout = FGUIEnums.LIST_LAYOUT_SINGLE_ROW
	aligned_list.auto_resize_item = false
	aligned_list.align = FGUIEnums.ALIGN_CENTER
	aligned_list.vertical_align = FGUIEnums.VERT_ALIGN_BOTTOM
	aligned_list.set_size(100.0, 60.0)
	host.add_child(aligned_list.node)
	var aligned_item := FGUIObject.new()
	aligned_item.set_size(20.0, 10.0)
	aligned_list.add_child(aligned_item)
	aligned_list.update_bounds()
	if not Vector2(aligned_item.x, aligned_item.y).is_equal_approx(Vector2(40.0, 50.0)):
		_fail("List alignment did not offset ordinary list content within the viewport.")
		return
	aligned_list.align = FGUIEnums.ALIGN_RIGHT
	aligned_list.vertical_align = FGUIEnums.VERT_ALIGN_TOP
	if not Vector2(aligned_item.x, aligned_item.y).is_equal_approx(Vector2(80.0, 0.0)):
		_fail("List alignment changes did not refresh ordinary list layout immediately.")
		return
	aligned_list.dispose()

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
