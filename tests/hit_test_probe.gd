extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var component := FGUIComponent.new()
	component.opaque = true
	component.set_size(100.0, 100.0)
	host.add_child(component.node)
	var back := FGUIObject.new()
	back.set_xy(10.0, 10.0)
	back.set_size(40.0, 40.0)
	component.add_child(back)
	var front := FGUIObject.new()
	front.set_xy(20.0, 20.0)
	front.set_size(40.0, 40.0)
	component.add_child(front)
	await process_frame

	if component.hit_test(Vector2(25.0, 25.0)) != front:
		_fail("Component hit_test did not return the topmost child.")
		return
	front.touchable = false
	if component.hit_test(Vector2(25.0, 25.0)) != back or component.hit_test(Vector2(25.0, 25.0), true) != front:
		_fail("Component hit_test did not honor touchability and force_test.")
		return
	front.touchable = true
	front.visible = false
	if component.hit_test(Vector2(25.0, 25.0)) != back:
		_fail("Component hit_test did not skip invisible children.")
		return
	front.visible = true
	if component.hit_test(Vector2(90.0, 90.0)) != component or component.hit_test(Vector2(110.0, 90.0)) != null:
		_fail("Opaque component hit_test did not handle empty and outside areas.")
		return

	component.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
