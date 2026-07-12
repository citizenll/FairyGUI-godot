extends SceneTree


class StressList extends FGUIList:
	var recycled: Array[FGUIObject] = []
	var created_count := 0
	var requested_urls: Array[String] = []
	var item_size := Vector2(80.0, 20.0)


	func get_from_pool(url: String = "") -> FGUIObject:
		requested_urls.append(url)
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

	var list := _create_list(host, Vector2(240.0, 100.0), FGUIEnums.SCROLL_VERTICAL, FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN)
	list.line_gap = 1
	var stats := {"renderer_calls": 0, "provider_generation": 0}
	list.item_provider = func(index: int) -> String:
		return "item-%s-%s" % [stats["provider_generation"], index % 2]
	list.item_renderer = func(index: int, item: FGUIObject) -> void:
		stats["renderer_calls"] = int(stats["renderer_calls"]) + 1
		item.set_size(80.0, 20.0)
		item.set_text(str(index))
	list.set_virtual()
	var started_at := Time.get_ticks_msec()
	list.num_items = 1_000_000
	await process_frame
	var setup_elapsed := Time.get_ticks_msec() - started_at
	if setup_elapsed > 5000:
		_fail("Million-item virtual list setup exceeded 5 seconds: %s ms." % setup_elapsed)
		return
	if absf(list.scroll_pane.content_height - 20_999_999.0) > 0.1:
		_fail("Million-item virtual list content height is incorrect: %s" % list.scroll_pane.content_height)
		return
	if not list._virtual_item_size_overrides.is_empty() or not list._virtual_changed_chunks.is_empty():
		_fail("Uniform million-item list allocated variable-size cache entries.")
		return
	if list.children.size() > 8 or list.created_count > 8:
		_fail("Million-item virtual list exceeded its bounded viewport allocation: %s/%s" % [list.children.size(), list.created_count])
		return

	var calls_before_same_cell := int(stats["renderer_calls"])
	list.scroll_pane.set_pos(0.0, 1.0)
	await process_frame
	if int(stats["renderer_calls"]) != calls_before_same_cell:
		_fail("Scrolling inside one virtual cell rerendered unchanged items.")
		return
	list.scroll_pane.set_pos(0.0, 21.0)
	await process_frame
	if int(stats["renderer_calls"]) - calls_before_same_cell > 2 or list.created_count > 8:
		_fail("One-cell scrolling did not incrementally recycle the visible range.")
		return

	list.scroll_pane.set_pos(0.0, 10_500_000.0)
	await process_frame
	if list.get_first_child_in_view() != 500_000:
		_fail("Million-item virtual list failed to seek to its midpoint: %s" % list.get_first_child_in_view())
		return
	if list.children.size() > 8 or list.created_count > 8:
		_fail("Million-item midpoint seek allocated extra item objects.")
		return
	list.scroll_to_view(999_999, false, true)
	await process_frame
	if list.item_index_to_child_index(999_999) < 0 or list.children.size() > 8:
		_fail("Million-item virtual list failed to expose its last logical item.")
		return

	list.add_selection(999_999)
	list.num_items = 100_000
	await process_frame
	if list.selected_index != -1:
		_fail("Shrinking a huge virtual list did not trim out-of-range selection.")
		return
	if absf(list.scroll_pane.content_height - 2_099_999.0) > 0.1 or list.children.size() > 8:
		_fail("Huge virtual list shrink did not update its bounded layout.")
		return
	list.num_items = 1_000_000
	await process_frame
	var created_before_refresh := list.created_count
	var calls_before_refresh := int(stats["renderer_calls"])
	stats["provider_generation"] = 1
	list.refresh_virtual_list()
	if int(stats["renderer_calls"]) - calls_before_refresh != list.children.size() or list.created_count != created_before_refresh:
		_fail("Forced virtual-list refresh did not reuse and rerender only visible objects: calls=%s children=%s created=%s/%s." % [int(stats["renderer_calls"]) - calls_before_refresh, list.children.size(), list.created_count, created_before_refresh])
		return
	for child: FGUIObject in list.children:
		if not list._get_virtual_child_url(child).begins_with("item-1-"):
			_fail("Forced virtual-list refresh retained a stale provider resource URL.")
			return
	list.dispose()

	var variable_list := _create_list(host, Vector2(120.0, 100.0), FGUIEnums.SCROLL_VERTICAL, FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN)
	variable_list.line_gap = 1
	var variable_state := {"enabled": true}
	variable_list.item_renderer = func(index: int, item: FGUIObject) -> void:
		var height := 20.0
		if bool(variable_state["enabled"]) and index == 0:
			height = 30.0
		elif bool(variable_state["enabled"]) and index == 500_000:
			height = 35.0
		item.set_size(80.0, height)
	variable_list.set_virtual()
	variable_list.num_items = 1_000_000
	await process_frame
	await process_frame
	if variable_list._virtual_item_size_overrides.size() != 1 or absf(variable_list.scroll_pane.content_height - 21_000_009.0) > 0.1:
		_fail("Sparse variable-size cache did not record the first measured override: overrides=%s height=%s total=%s dirty=%s queued=%s." % [variable_list._virtual_item_size_overrides.size(), variable_list.scroll_pane.content_height, variable_list._virtual_primary_total, variable_list._virtual_size_layout_dirty, variable_list._virtual_size_refresh_queued])
		return
	variable_list.scroll_to_view(500_000, false, true)
	await process_frame
	await process_frame
	if variable_list.get_first_child_in_view() != 500_000:
		_fail("Sparse million-item list failed to seek with a leading size override.")
		return
	if variable_list._virtual_item_size_overrides.size() != 2 or absf(variable_list.scroll_pane.content_height - 21_000_024.0) > 0.1:
		_fail("Sparse variable-size cache did not retain distant measured overrides.")
		return
	if variable_list._virtual_changed_chunks.size() != 2:
		_fail("Sparse variable-size cache allocated unexpected chunk metadata.")
		return
	variable_list.invalidate_virtual_item_size(0)
	await process_frame
	if variable_list._virtual_item_size_overrides.size() != 1 or absf(variable_list.scroll_pane.content_height - 21_000_014.0) > 0.1:
		_fail("Single virtual item size invalidation did not rebuild sparse prefixes.")
		return
	variable_state["enabled"] = false
	variable_list.invalidate_virtual_item_sizes()
	await process_frame
	await process_frame
	if not variable_list._virtual_item_size_overrides.is_empty() or absf(variable_list.scroll_pane.content_height - 20_999_999.0) > 0.1:
		_fail("Full virtual item size invalidation did not restore uniform layout.")
		return
	variable_list.dispose()

	var loop_list := _create_list(host, Vector2(120.0, 20.0), FGUIEnums.SCROLL_HORIZONTAL, FGUIEnums.LIST_LAYOUT_SINGLE_ROW)
	loop_list.column_gap = 1
	loop_list.item_renderer = func(_index: int, item: FGUIObject) -> void:
		item.set_size(80.0, 20.0)
	loop_list.set_virtual_and_loop()
	loop_list.num_items = 100_000
	await process_frame
	if loop_list._virtual_real_num_items != 600_000 or loop_list.children.size() > 4 or loop_list.created_count > 4:
		_fail("Large looping virtual list did not keep six logical copies with bounded objects.")
		return
	if not loop_list._virtual_item_size_overrides.is_empty():
		_fail("Large uniform loop allocated per-item size entries.")
		return
	loop_list.dispose()

	host.queue_free()
	await process_frame
	quit(0)


func _create_list(host: Control, size: Vector2, scroll_type: int, list_layout: int) -> StressList:
	var list := StressList.new()
	list.set_size(size.x, size.y)
	host.add_child(list.node)
	list.scroll_pane = FGUIScrollPane.new(list)
	list._content_node = list.scroll_pane.content
	list.scroll_pane.scroll_type = scroll_type
	list.scroll_pane._configure_native_scroll_modes()
	list.layout = list_layout
	list.auto_resize_item = false
	return list


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
