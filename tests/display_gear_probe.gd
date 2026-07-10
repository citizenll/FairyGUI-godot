extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var owner := FGUIComponent.new()
	owner.set_size(160.0, 100.0)
	host.add_child(owner.node)
	var child := FGUIObject.new()
	child.set_size(20.0, 20.0)
	owner.add_child(child)

	var controller := FGUIController.new()
	controller.parent = owner
	controller.page_ids = ["hidden", "shown"]
	controller.page_names = ["Hidden", "Shown"]
	controller._selected_index = 0
	owner.controllers.append(controller)

	var display_gear := child.get_gear(0) as FGUIGearDisplay
	display_gear.controller = controller
	display_gear.pages = ["shown"]
	var display_gear2 := child.get_gear(8) as FGUIGearDisplay2
	display_gear2.controller = controller
	display_gear2.pages = ["hidden"]
	display_gear2.condition = 0
	child.handle_controller_changed(controller)
	if child.node.visible:
		_fail("GearDisplay2 AND condition did not honor GearDisplay visibility.")
		return
	display_gear2.condition = 1
	child.handle_controller_changed(controller)
	if not child.node.visible:
		_fail("GearDisplay2 OR condition did not restore visibility.")
		return

	display_gear2.condition = 0
	display_gear2.pages.clear()
	child.handle_controller_changed(controller)
	if child.node.visible:
		_fail("GearDisplay did not hide the inactive controller page.")
		return
	var lock_token := child.add_display_lock()
	if lock_token == 0 or not child.node.visible:
		_fail("GearDisplay lock did not keep an inactive child visible.")
		return
	child.release_display_lock(lock_token + 1)
	if not child.node.visible:
		_fail("GearDisplay released a mismatched lock token.")
		return
	child.release_display_lock(lock_token)
	if child.node.visible:
		_fail("GearDisplay did not hide the child after releasing its display lock.")
		return

	var transition := FGUITransition.new(owner)
	transition._options = FGUITransition.OPTION_IGNORE_DISPLAY_CONTROLLER
	transition._items.append({
		"type": FGUITransition.ACTION_ALPHA,
		"time": 0.0,
		"target_id": child.id,
		"target": null,
		"label": "fade",
		"value": {},
		"tween_config": {
			"duration": 0.25,
			"ease_type": FGUIEaseType.LINEAR,
			"repeat": 0,
			"yoyo": false,
			"end_label": "fade_end",
			"start_value": {"f1": 1.0},
			"end_value": {"f1": 0.5},
			"end_hook": Callable(),
			"path": null,
		},
		"hook": Callable(),
		"display_lock_token": 0,
	})
	var transition_complete := [false]
	transition.play(func() -> void: transition_complete[0] = true)
	await create_timer(0.03).timeout
	if not child.node.visible:
		_fail("Transition ignore-display-controller option did not acquire a display lock.")
		return
	var waited := 0.0
	while not transition_complete[0] and waited < 1.0:
		await create_timer(0.02).timeout
		waited += 0.02
	if not transition_complete[0] or child.node.visible:
		_fail("Transition did not release its display lock after completion.")
		return

	var group := FGUIGroup.new()
	owner.add_child(group)
	child.group = group
	controller._selected_index = 1
	child.handle_controller_changed(controller)
	if not child.node.visible:
		_fail("GearDisplay did not show the active controller page.")
		return
	group.visible = false
	if child.node.visible:
		_fail("Group visibility did not propagate to grouped children.")
		return
	group.visible = true
	if not child.node.visible:
		_fail("Grouped child did not restore visibility with its group.")
		return

	transition.dispose()
	owner.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
