extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var owner := FGUIComponent.new()
	owner.set_size(240.0, 160.0)
	host.add_child(owner.node)
	var child := FGUITextField.new()
	child.set_size(20.0, 20.0)
	child.color = Color.RED
	child.stroke_color = Color.BLACK
	owner.add_child(child)

	var controller := FGUIController.new()
	controller.parent = owner
	controller.page_ids = ["a", "b"]
	controller.page_names = ["A", "B"]
	controller._selected_index = 0
	owner.controllers.append(controller)
	var parsed_color_gear := FGUIGearColor.new(child)
	parsed_color_gear.init()
	parsed_color_gear.add_status("encoded", FGUIByteBuffer.new(PackedByteArray([255, 0, 0, 64, 0, 255, 0, 32])))
	if absf((parsed_color_gear.storage["encoded"]["color"] as Color).a - 64.0 / 255.0) > 0.001 or absf((parsed_color_gear.storage["encoded"]["outline"] as Color).a - 32.0 / 255.0) > 0.001:
		parsed_color_gear.dispose()
		_fail(owner, "GearColor package parsing discarded color alpha values.")
		return
	parsed_color_gear.dispose()

	var xy := child.get_gear(1) as FGUIGearXY
	xy.controller = controller
	xy.storage = {
		"a": {"pos": Vector2.ZERO, "percent": Vector2.ZERO},
		"b": {"pos": Vector2(100.0, 40.0), "percent": Vector2.ZERO},
	}
	_enable_tween(xy)
	var size := child.get_gear(2) as FGUIGearSize
	size.controller = controller
	size.storage = {
		"a": {"size": Vector2(20.0, 20.0), "scale": Vector2.ONE},
		"b": {"size": Vector2(40.0, 30.0), "scale": Vector2(1.5, 0.5)},
	}
	_enable_tween(size)
	var look := child.get_gear(3) as FGUIGearLook
	look.controller = controller
	look.storage = {
		"a": {"alpha": 1.0, "rotation": 0.0, "grayed": false, "touchable": true},
		"b": {"alpha": 0.4, "rotation": 90.0, "grayed": true, "touchable": false},
	}
	_enable_tween(look)
	var color := child.get_gear(4) as FGUIGearColor
	color.controller = controller
	color.storage = {
		"a": {"color": Color.RED, "outline": Color.BLACK},
		"b": {"color": Color.BLUE, "outline": Color.GREEN},
	}
	_enable_tween(color)

	# Create the display gear last to verify controller handling still applies it first.
	var display := child.get_gear(0) as FGUIGearDisplay
	display.controller = controller
	display.pages = ["a"]
	child.handle_controller_changed(controller)

	var stopped_gears: Array = []
	child.on(FGUIEvents.GEAR_STOP, func(gear: FGUIGearBase) -> void: stopped_gears.append(gear))
	controller.selected_index = 1
	if not child.node.visible or not child.grayed or child.touchable or child.stroke_color != Color.GREEN:
		_fail(owner, "Gear tween did not apply immediate look/outline state or acquire a display lock.")
		return
	for gear: FGUIGearBase in [xy, size, look, color]:
		var active_tweener: FGUIGTweener = gear._active_tweener()
		if active_tweener == null:
			_fail(owner, "Gear tween did not create all expected runtime tweeners.")
			return
		active_tweener.seek(0.08)
	if child.x <= 0.0 or child.x >= 100.0 or child.width <= 20.0 or child.width >= 40.0 or child.alpha <= 0.4 or child.alpha >= 1.0:
		_fail(owner, "Gear tween did not interpolate its active values: x=%s width=%s alpha=%s" % [child.x, child.width, child.alpha])
		return
	var waited := 0.0
	while stopped_gears.size() < 4 and waited < 1.0:
		await create_timer(0.03).timeout
		waited += 0.03
	if stopped_gears.size() != 4 or not stopped_gears.has(xy) or not stopped_gears.has(size) or not stopped_gears.has(look) or not stopped_gears.has(color):
		_fail(owner, "Gear tween completion events were not emitted exactly once per tween: %s" % stopped_gears.size())
		return
	if not Vector2(child.x, child.y).is_equal_approx(Vector2(100.0, 40.0)) or not Vector2(child.width, child.height).is_equal_approx(Vector2(40.0, 30.0)):
		_fail(owner, "Gear tween did not finish at its position and size targets.")
		return
	if not child._scale.is_equal_approx(Vector2(1.5, 0.5)) or not is_equal_approx(child.alpha, 0.4) or not is_equal_approx(child.rotation, 90.0) or not child.color.is_equal_approx(Color.BLUE):
		_fail(owner, "Gear tween did not finish at its scale, look, and color targets.")
		return
	if child.node.visible:
		_fail(owner, "Gear tween display locks were not released after all tweens completed.")
		return

	FGUIGearBase.disable_all_tween_effect = true
	var previous_stop_count := stopped_gears.size()
	controller.selected_index = 0
	if not Vector2(child.x, child.y).is_equal_approx(Vector2.ZERO) or child.width != 20.0 or child.height != 20.0 or child.alpha != 1.0 or child.color != Color.RED:
		_fail(owner, "Disabling all gear tween effects did not apply controller state immediately.")
		return
	if stopped_gears.size() != previous_stop_count or not child.node.visible:
		_fail(owner, "Immediate gear application emitted tween completion or left display state stale.")
		return
	FGUIGearBase.disable_all_tween_effect = false

	controller.selected_index = 1
	if xy._active_tweener() == null or size._active_tweener() == null or look._active_tweener() == null or color._active_tweener() == null:
		_fail(owner, "Gear tweens did not restart after global suppression was cleared.")
		return
	FGUIGearBase.disable_all_tween_effect = true
	controller.selected_index = 0
	for gear: FGUIGearBase in [xy, size, look, color]:
		if gear._active_tweener() != null:
			_fail(owner, "Immediate gear application did not cancel an active tween.")
			return
	if stopped_gears.size() != previous_stop_count or not child.node.visible or child.x != 0.0 or child.color != Color.RED:
		_fail(owner, "Cancelling active gear tweens left stale state or emitted completion events.")
		return
	FGUIGearBase.disable_all_tween_effect = false

	owner.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _enable_tween(gear: FGUIGearBase) -> void:
	gear.tween_config["tween"] = true
	gear.tween_config["ease_type"] = FGUIEaseType.LINEAR
	gear.tween_config["duration"] = 0.12
	gear.tween_config["delay"] = 0.02


func _fail(owner: FGUIComponent, message: String) -> void:
	FGUIGearBase.disable_all_tween_effect = false
	push_error(message)
	if owner != null and not owner.is_disposed:
		owner.dispose()
	quit(1)
