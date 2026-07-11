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
	await process_frame
	await process_frame
	if not list.opaque or not Vector2(list.get_child_at(0).x, list.get_child_at(0).y).is_equal_approx(Vector2.ZERO) or not Vector2(list.get_child_at(1).x, list.get_child_at(1).y).is_equal_approx(Vector2(0.0, 20.0)):
		_fail("Regular lists did not retain their default opaque bounds-tracked column layout.")
		return
	list.set_size(90.0, 100.0)
	await process_frame
	await process_frame
	if absf(list.get_child_at(0).width - 90.0) > 0.1 or absf(list.get_child_at(1).width - 90.0) > 0.1:
		_fail("Regular lists did not relayout auto-resized items after a size change.")
		return

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
	var width_list := FGUIList.new()
	width_list.auto_resize_item = false
	host.add_child(width_list.node)
	var narrow_item := FGUIObject.new()
	narrow_item.set_size(30.0, 10.0)
	width_list.add_child(narrow_item)
	var wide_item := FGUIObject.new()
	wide_item.set_size(50.0, 10.0)
	width_list.add_child(wide_item)
	await process_frame
	await process_frame
	if absf(width_list.get_max_item_width() - 50.0) > 0.01:
		_fail("List get_max_item_width did not return the widest visible item.")
		return
	width_list.dispose()
	list.selection_mode = FGUIEnums.LIST_SELECTION_SINGLE
	list.layout = FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL
	list.column_count = 2
	list.auto_resize_item = false
	for item: FGUIObject in list.children:
		item.set_size(30.0, 20.0)
	list.set_size(100.0, 100.0)
	list.update_bounds()
	list.selected_index = 1
	if list.handle_arrow_key(5) != 3 or list.selected_index != 3:
		_fail("List down-arrow navigation did not preserve the flow-layout column.")
		return
	if list.handle_arrow_key(1) != 1 or list.selected_index != 1:
		_fail("List up-arrow navigation did not return to the preceding flow-layout row.")
		return
	var previous_view_width := list.view_width
	list.resize_to_fit(3)
	if absf(list.view_height - 40.0) > 0.1 or absf(list.view_width - previous_view_width) > 0.1:
		_fail("Flow-horizontal resize_to_fit did not resize the vertical list axis: %s,%s" % [list.view_width, list.view_height])
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
	await process_frame
	await process_frame
	if not Vector2(aligned_item.x, aligned_item.y).is_equal_approx(Vector2(80.0, 0.0)):
		_fail("List alignment changes did not refresh ordinary list layout at frame end.")
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
