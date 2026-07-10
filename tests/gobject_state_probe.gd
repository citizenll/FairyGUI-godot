extends SceneTree


func _initialize() -> void:
	var parent := FGUIComponent.new()
	root.add_child(parent.node)
	var child := FGUIObject.new()
	parent.add_child(child)
	child.set_size(100.0, 80.0)
	child.set_xy(30.0, 40.0)
	child.set_pivot(0.5, 0.25, false)
	child.set_size(120.0, 60.0)
	if not Vector2(child.x, child.y).is_equal_approx(Vector2(20.0, 45.0)):
		_fail("GObject size changes did not preserve a non-anchor pivot position.")
		return
	child.set_pivot(0.5, 0.5, true)
	child.set_size(100.0, 100.0)
	child.set_xy(50.0, 50.0)
	child.x_min = 10.0
	child.y_min = 20.0
	if not Vector2(child.x, child.y).is_equal_approx(Vector2(60.0, 70.0)) or not Vector2(child.x_min, child.y_min).is_equal_approx(Vector2(10.0, 20.0)):
		_fail("GObject x_min/y_min did not account for an anchor pivot.")
		return
	child.min_width = 120.0
	child.set_size(80.0, 100.0)
	if not is_equal_approx(child.width, 120.0) or not is_equal_approx(child._raw_width, 80.0):
		_fail("GObject size constraints did not retain FairyGUI raw dimensions.")
		return
	child.min_width = 0.0
	child.set_size(81.0, child._raw_height)
	if not is_equal_approx(child.width, 81.0) or not is_equal_approx(child._raw_width, 81.0):
		_fail("GObject next size requests did not use unconstrained raw dimensions after constraints changed.")
		return

	var controller := FGUIController.new()
	controller.add_page("state")
	controller.selected_index = 0
	var page_id := controller.selected_page_id
	var gear_xy := child.get_gear(1) as FGUIGearXY
	var gear_size := child.get_gear(2) as FGUIGearSize
	var gear_look := child.get_gear(3) as FGUIGearLook
	gear_xy.controller = controller
	gear_size.controller = controller
	gear_look.controller = controller
	gear_xy.init()
	gear_size.init()
	gear_look.init()
	child.set_xy(12.0, 16.0)
	child.set_size(90.0, 70.0)
	child.set_scale(1.5, 0.75)
	child.alpha = 0.4
	child.rotation = 45.0
	child.grayed = true
	child.touchable = false
	var xy_state: Dictionary = gear_xy.storage.get(page_id, {})
	var size_state: Dictionary = gear_size.storage.get(page_id, {})
	var look_state: Dictionary = gear_look.storage.get(page_id, {})
	if xy_state.get("pos", Vector2.ZERO) != Vector2(12.0, 16.0):
		_fail("GObject position changes did not update GearXY state.")
		return
	if size_state.get("size", Vector2.ZERO) != Vector2(90.0, 70.0) or size_state.get("scale", Vector2.ZERO) != Vector2(1.5, 0.75):
		_fail("GObject size and scale changes did not update GearSize state.")
		return
	if not is_equal_approx(float(look_state.get("alpha", 0.0)), 0.4) or not is_equal_approx(float(look_state.get("rotation", 0.0)), 45.0) or not bool(look_state.get("grayed", false)) or bool(look_state.get("touchable", true)):
		_fail("GObject look changes did not update GearLook state.")
		return

	parent.track_bounds = true
	parent._bounds_changed = false
	child.set_xy(18.0, 16.0)
	if not parent._bounds_changed:
		_fail("GObject position changes did not invalidate parent bounds.")
		return

	parent.dispose()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
