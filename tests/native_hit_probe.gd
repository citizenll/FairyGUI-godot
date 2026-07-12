extends SceneTree


func _initialize() -> void:
	var component := FGUIComponent.new()
	component.set_size(100.0, 80.0)
	if _native_has_point(component.node, Vector2(10.0, 10.0)):
		_fail("A non-opaque component accepted a native hit outside its children.")
		return

	component.opaque = true
	if not _native_has_point(component.node, Vector2(10.0, 10.0)):
		_fail("An opaque component did not accept a native hit inside its bounds.")
		return

	component.opaque = false
	var child := FGUIObject.new()
	child.set_xy(20.0, 15.0)
	child.set_size(30.0, 20.0)
	component.add_child(child)
	if not _native_has_point(component.node, Vector2(25.0, 20.0)) or _native_has_point(component.node, Vector2(5.0, 5.0)):
		_fail("A non-opaque component did not defer native hit testing to its visible children.")
		return

	component.opaque = true
	component.hit_test_child = child
	if not _native_has_point(component.node, Vector2(25.0, 20.0)) or _native_has_point(component.node, Vector2(5.0, 5.0)):
		_fail("Component hit_test_child was not applied to native Control hit testing.")
		return

	component.hit_test_child = null
	component.set_mask(child)
	if not _native_has_point(component.node, Vector2(25.0, 20.0)) or _native_has_point(component.node, Vector2(5.0, 5.0)):
		_fail("Forward masks were not applied to native Control hit testing.")
		return
	component.set_mask(child, true)
	if _native_has_point(component.node, Vector2(25.0, 20.0)) or not _native_has_point(component.node, Vector2(5.0, 5.0)):
		_fail("Reversed masks were not applied to native Control hit testing.")
		return

	var root_object := FGUIRoot.new()
	root_object.set_size(100.0, 80.0)
	if not _native_has_point(root_object.node, Vector2(70.0, 50.0)):
		_fail("GRoot no longer accepted native background input for popup dismissal.")
		return

	component.set_mask(null)
	component.opaque = false
	var host := Control.new()
	host.size = Vector2(280.0, 160.0)
	root.add_child(host)
	host.add_child(component.node)
	var gui_input_count := [0]
	component.node.gui_input.connect(func(_event: InputEvent) -> void: gui_input_count[0] += 1)
	await process_frame
	root.push_input(_mouse_press(Vector2(5.0, 5.0)))
	await process_frame
	if gui_input_count[0] != 0:
		_fail("Godot dispatched GUI input to a non-opaque component outside its children.")
		return
	component.opaque = true
	root.push_input(_mouse_press(Vector2(5.0, 5.0)))
	await process_frame
	if gui_input_count[0] != 1:
		_fail("Godot did not dispatch GUI input to an opaque component inside its bounds.")
		return

	var disposal_parent := FGUIComponent.new()
	disposal_parent.set_xy(110.0, 10.0)
	disposal_parent.set_size(40.0, 40.0)
	var disposal_button := FGUIButton.new()
	disposal_button.set_size(40.0, 40.0)
	disposal_button.opaque = true
	disposal_parent.add_child(disposal_button)
	host.add_child(disposal_parent.node)
	disposal_button.on("click", func(_event: Variant) -> void: disposal_parent.remove_child(disposal_button, true))
	root.push_input(_mouse_press(Vector2(125.0, 25.0)))
	await process_frame
	root.push_input(_mouse_release(Vector2(125.0, 25.0)))
	await process_frame
	if not disposal_button.is_disposed or disposal_parent.num_children != 0:
		_fail("Disposing a detached event emitter during its click callback was not deferred safely.")
		return

	var group_parent := FGUIComponent.new()
	group_parent.set_xy(10.0, 80.0)
	group_parent.set_size(80.0, 30.0)
	var grouped_button := FGUIButton.new()
	grouped_button.set_size(80.0, 30.0)
	grouped_button.opaque = true
	var logical_group := FGUIGroup.new()
	logical_group.set_size(80.0, 30.0)
	group_parent.add_child(grouped_button)
	group_parent.add_child(logical_group)
	grouped_button.group = logical_group
	host.add_child(group_parent.node)
	var grouped_clicks := [0]
	grouped_button.on("click", func(_event: Variant) -> void: grouped_clicks[0] += 1)
	root.push_input(_mouse_press(Vector2(25.0, 95.0)))
	await process_frame
	root.push_input(_mouse_release(Vector2(25.0, 95.0)))
	await process_frame
	if logical_group.node.mouse_filter != Control.MOUSE_FILTER_IGNORE or grouped_clicks[0] != 1:
		_fail("A logical GGroup intercepted input intended for one of its grouped controls.")
		return

	var masked_button := FGUIButton.new()
	masked_button.set_xy(170.0, 10.0)
	masked_button.set_size(80.0, 60.0)
	masked_button.opaque = true
	host.add_child(masked_button.node)
	var reverse_mask_parent := FGUIComponent.new()
	reverse_mask_parent.set_xy(170.0, 10.0)
	reverse_mask_parent.set_size(80.0, 60.0)
	reverse_mask_parent.opaque = true
	var reverse_mask := FGUIGraph.new()
	reverse_mask.set_xy(20.0, 10.0)
	reverse_mask.set_size(30.0, 30.0)
	reverse_mask.draw_rect(0.0, Color.TRANSPARENT, Color.WHITE)
	var mask_content := FGUIGraph.new()
	mask_content.set_size(80.0, 60.0)
	mask_content.draw_rect(0.0, Color.TRANSPARENT, Color.WHITE)
	reverse_mask_parent.add_child(reverse_mask)
	reverse_mask_parent.add_child(mask_content)
	reverse_mask_parent.set_mask(reverse_mask, true)
	host.add_child(reverse_mask_parent.node)
	var masked_button_clicks := [0]
	masked_button.on("click", func(_event: Variant) -> void: masked_button_clicks[0] += 1)
	root.push_input(_mouse_press(Vector2(205.0, 35.0)))
	await process_frame
	root.push_input(_mouse_release(Vector2(205.0, 35.0)))
	await process_frame
	if masked_button_clicks[0] != 1:
		_fail("A reversed mask child blocked native input through its transparent hole.")
		return
	root.push_input(_mouse_press(Vector2(180.0, 65.0)))
	await process_frame
	root.push_input(_mouse_release(Vector2(180.0, 65.0)))
	await process_frame
	if masked_button_clicks[0] != 1:
		_fail("A reversed mask did not block native input outside its transparent hole.")
		return

	root_object.dispose()
	disposal_parent.dispose()
	group_parent.dispose()
	reverse_mask_parent.dispose()
	masked_button.dispose()
	component.dispose()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _native_has_point(control: Control, point: Vector2) -> bool:
	return bool(control.call("_has_point", point))


func _mouse_press(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	event.global_position = position
	return event


func _mouse_release(position: Vector2) -> InputEventMouseButton:
	var event := _mouse_press(position)
	event.pressed = false
	return event
