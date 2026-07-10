extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var component := FGUIComponent.new()
	component.set_size(80.0, 60.0)
	host.add_child(component.node)
	var a := _make_child("a")
	var b := _make_child("b")
	var c := _make_child("c")
	component.add_child(a)
	component.add_child(b)
	component.add_child(c)
	await process_frame

	if component.hit_test(Vector2(10.0, 10.0)) != c:
		_fail("Ascent render order did not hit the last logical child.")
		return
	component.children_render_order = FGUIEnums.CHILDREN_RENDER_DESCENT
	await process_frame
	if component.node.get_child(0) != c.node or component.node.get_child(2) != a.node or component.hit_test(Vector2(10.0, 10.0)) != a:
		_fail("Descent render order did not reorder native controls and hit testing.")
		return
	component.children_render_order = FGUIEnums.CHILDREN_RENDER_ARCH
	component.apex_index = 1
	await process_frame
	if component.node.get_child(0) != a.node or component.node.get_child(1) != c.node or component.node.get_child(2) != b.node or component.hit_test(Vector2(10.0, 10.0)) != b:
		_fail("Arch render order did not honor the apex index.")
		return

	if component.set_child_index_before(c, 1) != 1 or component.get_child_at(1) != c:
		_fail("set_child_index_before did not place the child before its target index.")
		return
	component.swap_children(a, b)
	if component.get_child_at(0) != b or component.get_child_at(2) != a:
		_fail("swap_children did not exchange logical child positions.")
		return
	component.swap_children_at(0, 2)
	if component.get_child_at(0) != a or component.get_child_at(2) != b:
		_fail("swap_children_at did not exchange logical child positions.")
		return

	var group := FGUIGroup.new()
	group.name = "group"
	component.add_child(group)
	a.group = group
	if component.get_child_in_group("a", group) != a or component.get_visible_child("a") != a:
		_fail("Component group and visible-child lookup failed.")
		return
	a.visible = false
	if component.get_visible_child("a") != null:
		_fail("get_visible_child returned a hidden child.")
		return
	a.visible = true
	var nested := FGUIComponent.new()
	component.add_child(nested)
	var nested_leaf := FGUIObject.new()
	nested.add_child(nested_leaf)
	if not component.is_ancestor_of(nested_leaf) or nested.is_ancestor_of(a):
		_fail("Component ancestor lookup returned an incorrect hierarchy result.")
		return
	var scroll_component := FGUIComponent.new()
	scroll_component.set_size(80.0, 60.0)
	host.add_child(scroll_component.node)
	var existing_child := _make_child("existing")
	scroll_component.add_child(existing_child)
	scroll_component.scroll_pane = FGUIScrollPane.new(scroll_component)
	scroll_component._content_node = scroll_component.scroll_pane.content
	scroll_component._rebuild_native_display_list()
	scroll_component.set_bounds_changed_flag()
	if existing_child.node.get_parent() != scroll_component.scroll_pane.content:
		_fail("Switching to a ScrollPane did not reparent existing child controls.")
		return
	scroll_component.ensure_bounds_correct()
	if absf(scroll_component.scroll_pane.content_width - 40.0) > 0.1:
		_fail("ScrollPane content bounds did not include an existing child.")
		return
	scroll_component.remove_child(existing_child)
	scroll_component.ensure_bounds_correct()
	if scroll_component.scroll_pane.content_width > 0.1 or scroll_component.scroll_pane.content_height > 0.1:
		_fail("ScrollPane content bounds did not shrink after removing all children.")
		return
	existing_child.dispose()

	var controller := FGUIController.new()
	component.add_controller(controller)
	component.remove_controller(controller)
	if controller.parent != null or component.controllers.has(controller):
		_fail("remove_controller did not detach the controller.")
		return

	var sorting_component := FGUIComponent.new()
	host.add_child(sorting_component.node)
	var normal := _make_child("normal")
	var high := _make_child("high")
	high.sorting_order = 10
	var low := _make_child("low")
	low.sorting_order = 5
	sorting_component.add_child(normal)
	sorting_component.add_child(high)
	sorting_component.add_child(low)
	if sorting_component.get_child_at(0) != normal or sorting_component.get_child_at(1) != low or sorting_component.get_child_at(2) != high:
		_fail("Sorting children were not inserted after regular children in order.")
		return
	sorting_component.set_child_index(low, 0)
	if sorting_component.get_child_at(1) != low:
		_fail("set_child_index changed a sorting child's reserved position.")
		return
	high.sorting_order = 1
	if sorting_component.get_child_at(1) != high or sorting_component.get_child_at(2) != low:
		_fail("Changing a sorting order did not reorder sorting children.")
		return
	high.sorting_order = 0
	if sorting_component.get_child_at(0) != normal or sorting_component.get_child_at(1) != high or sorting_component.get_child_at(2) != low:
		_fail("Clearing a sorting order did not return the child to the regular range.")
		return

	sorting_component.dispose()
	scroll_component.dispose()
	component.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _make_child(child_name: String) -> FGUIObject:
	var child := FGUIObject.new()
	child.name = child_name
	child.set_size(40.0, 40.0)
	return child


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
