extends SceneTree


class ProbeList extends FGUIList:
	var recycled: Array[FGUIObject] = []
	var created_count: int = 0
	var item_size := Vector2(50.0, 40.0)


	func get_from_pool(_url: String = "") -> FGUIObject:
		var obj: FGUIObject
		if recycled.is_empty():
			var button := FGUIButton.new()
			button.mode = FGUIEnums.BUTTON_CHECK
			button.set_size(item_size.x, item_size.y)
			obj = button
			created_count += 1
		else:
			obj = recycled.pop_back()
		obj.visible = true
		return obj


	func return_to_pool(obj: FGUIObject) -> void:
		if obj == null:
			return
		obj.remove_from_parent()
		recycled.append(obj)


	func dispose() -> void:
		for obj: FGUIObject in recycled:
			obj.dispose()
		recycled.clear()
		super.dispose()


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)

	var list := ProbeList.new()
	list.set_size(180, 40)
	host.add_child(list.node)
	list.scroll_pane = FGUIScrollPane.new(list)
	list._content_node = list.scroll_pane.content
	list.scroll_pane.scroll_type = FGUIEnums.SCROLL_HORIZONTAL
	list.scroll_pane._configure_native_scroll_modes()
	list.layout = FGUIEnums.LIST_LAYOUT_SINGLE_ROW
	list.column_gap = 2

	var provider_indices: Array[int] = []
	var renderer_indices: Array[int] = []
	list.item_provider = func(index: int) -> String:
		provider_indices.append(index)
		return ""
	list.item_renderer = func(index: int, item: FGUIObject) -> void:
		renderer_indices.append(index)
		item.set_text(str(index))

	list.set_virtual_and_loop()
	list.num_items = 5
	await process_frame

	var span := 52.0
	var expected_content_width := 5.0 * 6.0 * span - 2.0
	if list._virtual_real_num_items != 30 or absf(list.scroll_pane.content_width - expected_content_width) > 0.1:
		_fail("Loop list did not allocate six physical copies.")
		return
	if absf(list.scroll_pane.pos_x - 15.0 * span) > 1.1:
		_fail("Loop list did not start from the middle physical copy: %s" % list.scroll_pane.pos_x)
		return
	if list.get_first_child_in_view() != 0:
		_fail("Loop list first visible item should map to logical index zero.")
		return
	if list.children.is_empty() or list.child_index_to_item_index(0) != 0 or list.item_index_to_child_index(2) < 0:
		_fail("Loop list child and item index mapping is incorrect.")
		return
	for index in provider_indices + renderer_indices:
		if index < 0 or index >= list.num_items:
			_fail("Loop renderer/provider received a physical rather than logical index: %s" % index)
			return

	list.add_selection(2)
	var selected_child_index := list.item_index_to_child_index(2)
	if selected_child_index < 0 or not (list.get_child_at(selected_child_index) as FGUIButton).selected:
		_fail("Virtual loop selection did not update the visible logical item.")
		return

	list.scroll_pane.set_pos(4.0 * span + 10.0, 0)
	await process_frame
	if list.scroll_pane.pos_x < 3.0 * span or list.get_first_child_in_view() != 4:
		_fail("Loop list did not recenter the leading physical copies.")
		return

	list.scroll_to_view(3)
	await process_frame
	if list.get_first_child_in_view() != 3:
		_fail("Loop list scroll_to_view did not select the nearest logical copy.")
		return

	list.scroll_pane.set_pos(list.scroll_pane.content_width - list.scroll_pane.view_width - 1.0, 0)
	await process_frame
	if list.scroll_pane.pos_x >= 4.0 * 5.0 * span or list.get_first_child_in_view() != 1:
		_fail("Loop list did not recenter the trailing physical copies.")
		return
	if list.created_count > 7:
		_fail("Virtual loop list did not recycle item objects: %s created." % list.created_count)
		return

	list.dispose()

	var variable_column := _create_virtual_list(
		host,
		Vector2(100.0, 100.0),
		FGUIEnums.SCROLL_VERTICAL,
		FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN,
		Vector2(50.0, 20.0)
	)
	variable_column.auto_resize_item = false
	variable_column.line_gap = 2
	var column_heights := [20.0, 35.0, 25.0, 40.0]
	variable_column.item_renderer = func(index: int, item: FGUIObject) -> void:
		item.set_size(50.0, column_heights[index])
	variable_column.set_virtual()
	variable_column.num_items = column_heights.size()
	await process_frame
	await process_frame
	if absf(variable_column.scroll_pane.content_height - 126.0) > 0.1:
		_fail("Variable-height virtual column list content size is incorrect: %s" % variable_column.scroll_pane.content_height)
		return
	if not _expect_item_position(variable_column, 1, Vector2(0.0, 22.0), "variable column item 1"):
		return
	if not _expect_item_position(variable_column, 2, Vector2(0.0, 59.0), "variable column item 2"):
		return
	if not _expect_item_position(variable_column, 3, Vector2(0.0, 86.0), "variable column item 3"):
		return
	variable_column.scroll_to_view(3)
	await process_frame
	if variable_column.get_first_child_in_view() != 1:
		_fail("Variable-height virtual column list did not use cached item positions for scroll_to_view.")
		return
	variable_column.dispose()

	var variable_loop_row := _create_virtual_list(
		host,
		Vector2(100.0, 20.0),
		FGUIEnums.SCROLL_HORIZONTAL,
		FGUIEnums.LIST_LAYOUT_SINGLE_ROW,
		Vector2(30.0, 20.0)
	)
	variable_loop_row.auto_resize_item = false
	variable_loop_row.column_gap = 2
	var row_widths := [30.0, 50.0, 20.0]
	variable_loop_row.item_renderer = func(index: int, item: FGUIObject) -> void:
		item.set_size(row_widths[index], 20.0)
	variable_loop_row.set_virtual_and_loop()
	variable_loop_row.num_items = row_widths.size()
	await process_frame
	await process_frame
	if absf(variable_loop_row.scroll_pane.content_width - 634.0) > 0.1:
		_fail("Variable-width loop list content size is incorrect: %s" % variable_loop_row.scroll_pane.content_width)
		return
	if absf(variable_loop_row.scroll_pane.pos_x - 318.0) > 1.1 or variable_loop_row.get_first_child_in_view() != 0:
		_fail("Variable-width loop list did not recenter at the logical first item.")
		return
	variable_loop_row.scroll_to_view(2)
	await process_frame
	if variable_loop_row.get_first_child_in_view() != 2:
		_fail("Variable-width loop list did not use cached widths for scroll_to_view.")
		return
	variable_loop_row.dispose()

	var large_variable_column := _create_virtual_list(
		host,
		Vector2(100.0, 100.0),
		FGUIEnums.SCROLL_VERTICAL,
		FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN,
		Vector2(50.0, 20.0)
	)
	large_variable_column.auto_resize_item = false
	large_variable_column.line_gap = 1
	large_variable_column.set_virtual()
	large_variable_column.num_items = 10000
	await process_frame
	if large_variable_column.children.size() > 8 or large_variable_column.created_count > 8:
		_fail("Large virtual list instantiated more item objects than its viewport requires.")
		return
	if absf(large_variable_column.scroll_pane.content_height - 209999.0) > 0.1:
		_fail("Large virtual list content height is incorrect.")
		return
	large_variable_column.scroll_pane.set_pos(0.0, 105000.0)
	await process_frame
	if large_variable_column.get_first_child_in_view() != 5000 or large_variable_column.created_count > 8:
		_fail("Large virtual list did not seek through cached item positions without extra allocations.")
		return
	large_variable_column.dispose()

	var flow_horizontal := _create_virtual_list(
		host,
		Vector2(130.0, 20.0),
		FGUIEnums.SCROLL_VERTICAL,
		FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL,
		Vector2(50.0, 20.0)
	)
	flow_horizontal.column_gap = 5
	flow_horizontal.line_gap = 4
	flow_horizontal.column_count = 2
	flow_horizontal.set_virtual()
	flow_horizontal.num_items = 5
	await process_frame
	if absf(flow_horizontal.scroll_pane.content_width - 105.0) > 0.1 or absf(flow_horizontal.scroll_pane.content_height - 68.0) > 0.1:
		_fail("Flow-horizontal virtual list content size is incorrect.")
		return
	if not _expect_item_position(flow_horizontal, 0, Vector2(0.0, 0.0), "flow-horizontal item 0"):
		return
	if not _expect_item_position(flow_horizontal, 1, Vector2(55.0, 0.0), "flow-horizontal item 1"):
		return
	if not _expect_item_position(flow_horizontal, 2, Vector2(0.0, 24.0), "flow-horizontal item 2"):
		return
	flow_horizontal.scroll_pane.set_pos(0.0, 25.0)
	await process_frame
	if flow_horizontal.get_first_child_in_view() != 2:
		_fail("Flow-horizontal virtual list did not recycle by row.")
		return
	flow_horizontal.scroll_to_view(4)
	await process_frame
	if flow_horizontal.get_first_child_in_view() != 4:
		_fail("Flow-horizontal virtual list scroll_to_view did not target the row.")
		return
	flow_horizontal.dispose()

	var flow_vertical := _create_virtual_list(
		host,
		Vector2(30.0, 60.0),
		FGUIEnums.SCROLL_HORIZONTAL,
		FGUIEnums.LIST_LAYOUT_FLOW_VERTICAL,
		Vector2(30.0, 20.0)
	)
	flow_vertical.column_gap = 4
	flow_vertical.line_gap = 3
	flow_vertical.line_count = 2
	flow_vertical.set_virtual()
	flow_vertical.num_items = 5
	await process_frame
	if absf(flow_vertical.scroll_pane.content_width - 98.0) > 0.1 or absf(flow_vertical.scroll_pane.content_height - 43.0) > 0.1:
		_fail("Flow-vertical virtual list content size is incorrect.")
		return
	if not _expect_item_position(flow_vertical, 0, Vector2(0.0, 0.0), "flow-vertical item 0"):
		return
	if not _expect_item_position(flow_vertical, 1, Vector2(0.0, 23.0), "flow-vertical item 1"):
		return
	if not _expect_item_position(flow_vertical, 2, Vector2(34.0, 0.0), "flow-vertical item 2"):
		return
	flow_vertical.scroll_pane.set_pos(35.0, 0.0)
	await process_frame
	if flow_vertical.get_first_child_in_view() != 2:
		_fail("Flow-vertical virtual list did not recycle by column.")
		return
	flow_vertical.scroll_to_view(4)
	await process_frame
	if flow_vertical.get_first_child_in_view() != 4:
		_fail("Flow-vertical virtual list scroll_to_view did not target the column.")
		return
	flow_vertical.dispose()

	var pagination := _create_virtual_list(
		host,
		Vector2(100.0, 60.0),
		FGUIEnums.SCROLL_HORIZONTAL,
		FGUIEnums.LIST_LAYOUT_PAGINATION,
		Vector2(30.0, 20.0)
	)
	pagination.column_gap = 2
	pagination.line_gap = 3
	pagination.column_count = 3
	pagination.line_count = 2
	pagination.set_virtual()
	pagination.num_items = 7
	await process_frame
	if absf(pagination.scroll_pane.content_width - 200.0) > 0.1 or absf(pagination.scroll_pane.content_height - 60.0) > 0.1:
		_fail("Pagination virtual list content size is incorrect.")
		return
	if not _expect_item_position(pagination, 5, Vector2(64.0, 23.0), "pagination item 5"):
		return
	pagination.scroll_pane.set_pos(100.0, 0.0)
	await process_frame
	if pagination.get_first_child_in_view() != 6:
		_fail("Pagination virtual list did not recycle by page.")
		return
	if not _expect_item_position(pagination, 6, Vector2(100.0, 0.0), "pagination item 6"):
		return
	pagination.scroll_to_view(5)
	await process_frame
	if pagination.get_first_child_in_view() != 0:
		_fail("Pagination virtual list scroll_to_view did not target the page.")
		return
	pagination.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _create_virtual_list(host: Control, size: Vector2, scroll_type: int, list_layout: int, item_size: Vector2) -> ProbeList:
	var list := ProbeList.new()
	list.item_size = item_size
	list.set_size(size.x, size.y)
	host.add_child(list.node)
	list.scroll_pane = FGUIScrollPane.new(list)
	list._content_node = list.scroll_pane.content
	list.scroll_pane.scroll_type = scroll_type
	list.scroll_pane._configure_native_scroll_modes()
	list.layout = list_layout
	return list


func _expect_item_position(list: ProbeList, item_index: int, expected: Vector2, label: String) -> bool:
	var child_index := list.item_index_to_child_index(item_index)
	if child_index < 0:
		_fail("%s was not rendered." % label)
		return false
	var item := list.get_child_at(child_index)
	if absf(item.x - expected.x) > 0.1 or absf(item.y - expected.y) > 0.1:
		_fail("%s has position (%s, %s), expected (%s, %s)." % [label, item.x, item.y, expected.x, expected.y])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
