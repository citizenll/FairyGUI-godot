extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var fgui_root := FGUIRoot.new()
	host.add_child(fgui_root.node)
	var object := FGUIObject.new()
	object.set_size(20.0, 10.0)
	object.set_pivot(0.5, 0.5, true)
	object.pivot_x = 0.25
	object.pivot_y = 0.75
	if not object.pivot_as_anchor or not is_equal_approx(object.pivot_x, 0.25) or not is_equal_approx(object.pivot_y, 0.75):
		_fail("GObject pivot property accessors did not preserve the anchor state.")
		return
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
	object.scale_x = 1.5
	object.scale_y = 0.5
	if not is_equal_approx(object.scale_x, 1.5) or not is_equal_approx(object.scale_y, 0.5):
		_fail("GObject scale property accessors did not update both axes.")
		return
	object.set_scale(1.0, 1.0)

	object.request_focus()
	if fgui_root.focus != object:
		_fail("GObject request_focus did not update the FairyGUI root focus.")
		return
	var transformed := object.transform_point(Vector2(5.0, 5.0), fgui_root)
	if not fgui_root.transform_point(transformed, object).is_equal_approx(Vector2(5.0, 5.0)):
		_fail("GObject transform_point did not round-trip between coordinate spaces.")
		return
	var full_parent := FGUIComponent.new()
	full_parent.set_size(320.0, 180.0)
	fgui_root.add_child(full_parent)
	var full_screen := FGUIObject.new()
	full_parent.add_child(full_screen)
	full_screen.make_full_screen()
	if not Vector2(full_screen.width, full_screen.height).is_equal_approx(Vector2(320.0, 180.0)):
		_fail("GObject make_full_screen did not fill its parent.")
		return
	full_parent.set_size(400.0, 200.0)
	if not Vector2(full_screen.width, full_screen.height).is_equal_approx(Vector2(400.0, 200.0)):
		_fail("GObject make_full_screen did not retain its size relation.")
		return

	object.tween_move(Vector2(20.0, 30.0), 0.04)
	await create_timer(0.1).timeout
	if not Vector2(object.x, object.y).is_equal_approx(Vector2(20.0, 30.0)):
		_fail("GObject tween_move did not use the GTween runtime.")
		return
	object.tween_scale(Vector2(2.0, 3.0), 0.04)
	object.tween_resize(Vector2(40.0, 30.0), 0.04)
	object.tween_fade(0.4, 0.04)
	object.tween_rotate(45.0, 0.04)
	await create_timer(0.1).timeout
	if not object.node.scale.is_equal_approx(Vector2(2.0, 3.0)) or not Vector2(object.width, object.height).is_equal_approx(Vector2(40.0, 30.0)) or absf(object.alpha - 0.4) > 0.01 or absf(object.rotation - 45.0) > 0.01:
		_fail("GObject tween convenience methods did not update their target properties.")
		return

	fgui_root.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
