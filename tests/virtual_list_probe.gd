extends SceneTree


class ProbeList extends FGUIList:
	var recycled: Array[FGUIObject] = []
	var created_count: int = 0


	func get_from_pool(_url: String = "") -> FGUIObject:
		var obj: FGUIObject
		if recycled.is_empty():
			var button := FGUIButton.new()
			button.mode = FGUIEnums.BUTTON_CHECK
			button.set_size(50, 40)
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
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
