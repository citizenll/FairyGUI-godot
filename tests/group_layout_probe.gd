extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var parent := FGUIComponent.new()
	parent.set_size(300.0, 200.0)
	host.add_child(parent.node)

	var horizontal_group := FGUIGroup.new()
	parent.add_child(horizontal_group)
	var first := _create_child(parent, horizontal_group, Vector2(20.0, 10.0), Vector2(30.0, 0.0))
	var second := _create_child(parent, horizontal_group, Vector2(30.0, 10.0), Vector2(90.0, 0.0))
	horizontal_group.layout = FGUIEnums.GROUP_LAYOUT_HORIZONTAL
	horizontal_group.column_gap = 5
	horizontal_group.ensure_bounds_correct()
	if not _approximately(horizontal_group.x, 0.0) or not _approximately(horizontal_group.width, 55.0):
		_fail("Horizontal group did not derive its initial bounds.")
		return
	if not _approximately(first.x, 0.0) or not _approximately(second.x, 25.0):
		_fail("Horizontal group did not lay out its children.")
		return

	horizontal_group.set_xy(10.0, 12.0)
	if not _approximately(first.x, 10.0) or not _approximately(first.y, 12.0) or not _approximately(second.x, 35.0):
		_fail("Moving a group did not move its children.")
		return
	horizontal_group.auto_size_disabled = true
	horizontal_group.set_size(105.0, 20.0)
	if not _approximately(first.width, 40.0) or not _approximately(second.width, 60.0):
		_fail("Horizontal group did not distribute resized width by child proportions.")
		return
	if not _approximately(first.height, 20.0) or not _approximately(second.height, 20.0) or not _approximately(second.x, 55.0):
		_fail("Horizontal group did not resize the cross axis or relayout children.")
		return
	horizontal_group.alpha = 0.4
	if not _approximately(first.alpha, 0.4) or not _approximately(second.alpha, 0.4):
		_fail("Group alpha did not propagate to children.")
		return
	horizontal_group.exclude_invisibles = true
	first.visible = false
	horizontal_group.ensure_bounds_correct()
	if not _approximately(first.width, 40.0) or not _approximately(second.width, 105.0) or not _approximately(second.x, 10.0):
		_fail("Horizontal group did not exclude invisible children during resize layout.")
		return

	var main_group := FGUIGroup.new()
	parent.add_child(main_group)
	var main_child := _create_child(parent, main_group, Vector2(10.0, 10.0), Vector2(0.0, 80.0))
	var fixed_child := _create_child(parent, main_group, Vector2(10.0, 10.0), Vector2(0.0, 80.0))
	main_group.layout = FGUIEnums.GROUP_LAYOUT_HORIZONTAL
	main_group.auto_size_disabled = true
	main_group.column_gap = 5
	main_group.main_grid_index = 0
	main_group.main_grid_min_size = 30
	main_group.set_size(80.0, 10.0)
	if not _approximately(main_child.width, 65.0) or not _approximately(fixed_child.width, 10.0) or not _approximately(fixed_child.x, 70.0):
		_fail("Horizontal group main grid did not consume extra width correctly.")
		return

	var vertical_group := FGUIGroup.new()
	parent.add_child(vertical_group)
	var top := _create_child(parent, vertical_group, Vector2(10.0, 10.0), Vector2(150.0, 0.0))
	var bottom := _create_child(parent, vertical_group, Vector2(10.0, 30.0), Vector2(150.0, 50.0))
	vertical_group.layout = FGUIEnums.GROUP_LAYOUT_VERTICAL
	vertical_group.line_gap = 5
	vertical_group.ensure_bounds_correct()
	vertical_group.auto_size_disabled = true
	vertical_group.set_size(10.0, 105.0)
	if not _approximately(top.height, 25.0) or not _approximately(bottom.height, 75.0) or not _approximately(bottom.y, 30.0):
		_fail("Vertical group did not distribute resized height by child proportions.")
		return

	parent.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _create_child(parent: FGUIComponent, group: FGUIGroup, size: Vector2, position: Vector2) -> FGUIObject:
	var child := FGUIObject.new()
	child.set_size(size.x, size.y)
	child.set_xy(position.x, position.y)
	parent.add_child(child)
	child.group = group
	return child


func _approximately(actual: float, expected: float) -> bool:
	return absf(actual - expected) <= 0.1


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
