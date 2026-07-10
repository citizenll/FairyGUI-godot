extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var fgui_root := FGUIRoot.new()
	host.add_child(fgui_root.node)
	var object := FGUIObject.new()
	object.set_size(20.0, 10.0)
	object.set_pivot(0.5, 0.5, true)
	object.set_xy(100.0, 50.0)
	fgui_root.add_child(object)
	await process_frame

	if not object.local_to_global(Vector2.ZERO).is_equal_approx(Vector2(100.0, 50.0)):
		_fail("Pivot-anchor local_to_global did not preserve FairyGUI coordinates.")
		return
	if not object.global_to_local(Vector2(100.0, 50.0)).is_equal_approx(Vector2.ZERO):
		_fail("Pivot-anchor global_to_local did not invert FairyGUI coordinates.")
		return
	var global_rect := object.local_to_global_rect(Rect2(0.0, 0.0, 20.0, 10.0))
	if not global_rect.is_equal_approx(Rect2(100.0, 50.0, 20.0, 10.0)) or not object.global_to_local_rect(global_rect).is_equal_approx(Rect2(0.0, 0.0, 20.0, 10.0)):
		_fail("GObject rectangle coordinate conversion was not reversible.")
		return
	if not object._global_to_node_local(object.node.get_global_rect().position).is_equal_approx(Vector2.ZERO):
		_fail("Physical node-local conversion did not preserve hit-test coordinates.")
		return

	object.request_focus()
	if fgui_root.focus != object:
		_fail("GObject request_focus did not update the FairyGUI root focus.")
		return
	var transformed := object.transform_point(Vector2(5.0, 5.0), fgui_root)
	if not fgui_root.transform_point(transformed, object).is_equal_approx(Vector2(5.0, 5.0)):
		_fail("GObject transform_point did not round-trip between coordinate spaces.")
		return

	fgui_root.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
