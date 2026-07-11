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
	host.size = Vector2(160.0, 120.0)
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

	root_object.dispose()
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
