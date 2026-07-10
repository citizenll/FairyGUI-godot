extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)

	var owner := FGUIComponent.new()
	owner.set_size(240, 120)
	host.add_child(owner.node)
	var pane := FGUIScrollPane.new(owner)
	owner.scroll_pane = pane

	var flags := 1 | 2 | 4 | 8 | 32 | 64 | 256 | 512 | 1024 | 2048
	var setup_bytes := PackedByteArray([FGUIEnums.SCROLL_HORIZONTAL, FGUIEnums.SCROLLBAR_AUTO])
	_append_i32(setup_bytes, flags)
	setup_bytes.append(1)
	_append_i32(setup_bytes, 1)
	_append_i32(setup_bytes, 2)
	_append_i32(setup_bytes, 3)
	_append_i32(setup_bytes, 4)
	for i in 4:
		_append_i16(setup_bytes, FGUIByteBuffer.STRING_NULL)
	pane.setup(FGUIByteBuffer.new(setup_bytes))

	if pane.scroll_type != FGUIEnums.SCROLL_HORIZONTAL or pane.scroll_bar_display != FGUIEnums.SCROLLBAR_AUTO:
		_fail("ScrollPane setup did not parse type/display fields.")
		return
	if not pane.display_on_left or not pane.snap_to_item or not pane.display_in_demand or not pane.page_mode:
		_fail("ScrollPane setup did not parse common flags.")
		return
	if pane.touch_effect or not pane.bounceback_effect or not pane.inertia_disabled or not pane.mask_disabled or not pane.floating or not pane.dont_clip_margin:
		_fail("ScrollPane setup did not parse behavior flags.")
		return
	if pane.scroll_bar_margin.top != 1 or pane.scroll_bar_margin.bottom != 2 or pane.scroll_bar_margin.left != 3 or pane.scroll_bar_margin.right != 4:
		_fail("ScrollPane setup did not parse scroll bar margins.")
		return
	if pane.container.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED or pane.container.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_SHOW_NEVER:
		_fail("ScrollPane native axis modes are incorrect.")
		return
	if pane.container.clip_contents:
		_fail("ScrollPane mask-disabled flag was not applied.")
		return

	pane.set_content_size(800, 100)
	var page_controller := _make_controller(3)
	pane.page_controller = page_controller
	page_controller.selected_index = 1
	pane.handle_controller_changed(page_controller)
	await create_timer(0.4).timeout
	if absf(pane.pos_x - pane.view_width) > 1.5:
		_fail("Page controller did not move the horizontal ScrollPane: %s" % pane.pos_x)
		return
	pane.set_current_page_x(2)
	if page_controller.selected_index != 2:
		_fail("ScrollPane did not update its page controller.")
		return
	pane.page_mode = false
	pane.set_pos(0.0, 0.0)
	pane.set_pos(120.0, 0.0, true)
	await create_timer(0.4).timeout
	if absf(pane.pos_x - 120.0) > 1.5:
		_fail("Animated ScrollPane positioning did not reach the requested offset: %s" % pane.pos_x)
		return
	pane.set_pos(300.0, 0.0, true)
	pane.set_pos(45.0, 0.0)
	await create_timer(0.35).timeout
	if absf(pane.pos_x - 45.0) > 1.5:
		_fail("Immediate ScrollPane positioning did not cancel an active animation: %s" % pane.pos_x)
		return
	var view_target := FGUIObject.new()
	view_target.set_xy(420.0, 0.0)
	view_target.set_size(20.0, 20.0)
	pane.scroll_to_view(view_target, true, true)
	await create_timer(0.4).timeout
	if absf(pane.pos_x - 420.0) > 1.5:
		_fail("Animated scroll_to_view did not reach the target offset: %s" % pane.pos_x)
		return

	var parent := FGUIComponent.new()
	host.add_child(parent.node)
	var linked_controller := _make_controller(2)
	linked_controller.parent = parent
	parent.controllers.append(linked_controller)
	var linked_child := FGUIComponent.new()
	linked_child.set_size(100, 100)
	parent.add_child(linked_child)
	linked_child.scroll_pane = FGUIScrollPane.new(linked_child)
	var after_add_bytes := PackedByteArray([5, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0, 0])
	linked_child.setup_after_add(FGUIByteBuffer.new(after_add_bytes), 0)
	if linked_child.scroll_pane.page_controller != linked_controller:
		_fail("Component setup did not link the ScrollPane page controller.")
		return

	var controls_parent := FGUIComponent.new()
	host.add_child(controls_parent.node)
	var list := FGUIList.new()
	controls_parent.add_child(list)
	for i in 2:
		var button := FGUIButton.new()
		button.set_size(80, 20)
		list.add_child(button)
	var list_controller := _make_controller(2)
	list.selection_controller = list_controller
	controls_parent.add_controller(list_controller)
	list_controller.selected_index = 1
	if list.selected_index != 1:
		_fail("List did not follow its selection controller.")
		return
	list.selected_index = 0
	if list_controller.selected_index != 0:
		_fail("List did not update its selection controller.")
		return

	var combo := FGUIComboBox.new()
	combo.items = ["A", "B"]
	controls_parent.add_child(combo)
	var combo_controller := _make_controller(2)
	combo.selection_controller = combo_controller
	controls_parent.add_controller(combo_controller)
	combo_controller.selected_index = 1
	if combo.selected_index != 1:
		_fail("ComboBox did not follow its selection controller.")
		return
	combo.selected_index = 0
	if combo_controller.selected_index != 0:
		_fail("ComboBox did not update its selection controller.")
		return

	pane.scroll_type = FGUIEnums.SCROLL_VERTICAL
	pane._configure_native_scroll_modes()
	pane.set_content_size(100, 600)
	await process_frame
	var header := FGUIComponent.new()
	var footer := FGUIComponent.new()
	owner.node.add_child(header.node)
	owner.node.add_child(footer.node)
	pane.header = header
	pane.footer = footer
	pane.lock_header(20)
	pane.lock_footer(25)
	await process_frame
	if not header.visible or not footer.visible or absf(pane.container.position.y - 20.0) > 0.1 or absf(pane.view_height - 75.0) > 0.1:
		_fail("ScrollPane refresh locks did not reserve and lay out header/footer space.")
		return
	pane.scroll_bottom()
	if not pane.is_bottom_most():
		_fail("ScrollPane scroll_bottom did not move to the locked viewport bottom.")
		return
	pane.scroll_top()
	if pane.pos_y > 0.1:
		_fail("ScrollPane scroll_top did not return to the top.")
		return
	pane.lock_header(0)
	pane.lock_footer(0)
	if header.visible or footer.visible or absf(pane.view_height - 120.0) > 0.1:
		_fail("ScrollPane did not release refresh lock space.")
		return
	var scroll_bar := FGUIScrollBar.new()
	var track := FGUIObject.new()
	track.set_size(10, 100)
	scroll_bar.add_child(track)
	var grip := FGUIObject.new()
	grip.set_size(10, 20)
	scroll_bar.add_child(grip)
	scroll_bar._bar = track
	scroll_bar._grip = grip
	scroll_bar.set_scroll_pane(pane, true)
	scroll_bar.set_display_percent(pane.view_height / pane.content_height)
	grip.y = track.height - grip.height
	scroll_bar._on_grip_drag_move()
	if not pane.is_bottom_most():
		_fail("Custom scroll bar grip did not drive ScrollPane position.")
		return

	var pull_owner := FGUIComponent.new()
	pull_owner.set_size(100, 100)
	host.add_child(pull_owner.node)
	var pull_pane := FGUIScrollPane.new(pull_owner)
	pull_owner.scroll_pane = pull_pane
	pull_pane.scroll_type = FGUIEnums.SCROLL_VERTICAL
	pull_pane._configure_native_scroll_modes()
	pull_pane.set_content_size(100, 300)
	if not pull_pane.container.gui_input.is_connected(Callable(pull_pane, "_on_container_gui_input")):
		_fail("ScrollPane did not connect its edge-drag input handler.")
		return
	var release_counts := {"down": 0, "up": 0, "end": 0}
	pull_owner.on(FGUIEvents.PULL_DOWN_RELEASE, func() -> void: release_counts["down"] = int(release_counts["down"]) + 1)
	pull_owner.on(FGUIEvents.PULL_UP_RELEASE, func() -> void: release_counts["up"] = int(release_counts["up"]) + 1)
	pull_owner.on(FGUIEvents.SCROLL_END, func() -> void: release_counts["end"] = int(release_counts["end"]) + 1)
	pull_pane._on_container_gui_input(_mouse_button_event(Vector2(50, 50), true))
	pull_pane._on_container_gui_input(_mouse_motion_event(Vector2(50, 75)))
	pull_pane._on_container_gui_input(_mouse_button_event(Vector2(50, 75), false))
	if release_counts["down"] != 1 or release_counts["up"] != 0 or release_counts["end"] != 1:
		_fail("ScrollPane did not dispatch pull-down release at the top edge.")
		return
	pull_pane.scroll_bottom()
	pull_pane._on_container_gui_input(_mouse_button_event(Vector2(50, 50), true))
	pull_pane._on_container_gui_input(_mouse_motion_event(Vector2(50, 20)))
	pull_pane._on_container_gui_input(_mouse_button_event(Vector2(50, 20), false))
	if release_counts["down"] != 1 or release_counts["up"] != 1 or release_counts["end"] != 2:
		_fail("ScrollPane did not dispatch pull-up release at the bottom edge.")
		return
	pull_pane.scroll_top()
	pull_pane._on_container_gui_input(_mouse_button_event(Vector2(50, 50), true))
	pull_pane._on_container_gui_input(_mouse_motion_event(Vector2(50, 57)))
	pull_pane._on_container_gui_input(_mouse_button_event(Vector2(50, 57), false))
	if release_counts["down"] != 1 or release_counts["up"] != 1 or release_counts["end"] != 3:
		_fail("ScrollPane dispatched a pull release below the drag threshold.")
		return
	var wheel_owner := FGUIComponent.new()
	wheel_owner.set_size(100, 100)
	host.add_child(wheel_owner.node)
	var wheel_pane := FGUIScrollPane.new(wheel_owner)
	wheel_owner.scroll_pane = wheel_pane
	wheel_pane.scroll_type = FGUIEnums.SCROLL_BOTH
	wheel_pane._configure_native_scroll_modes()
	wheel_pane.set_content_size(600, 500)
	wheel_pane.mouse_wheel_step = 40.0
	wheel_pane.touch_effect = false
	wheel_pane._on_container_gui_input(_mouse_wheel_event(MOUSE_BUTTON_WHEEL_DOWN, 2.0))
	if absf(wheel_pane.pos_y - 80.0) > 1.5:
		_fail("ScrollPane mouse wheel did not use the configured vertical FairyGUI step: %s" % wheel_pane.pos_y)
		return
	wheel_pane._on_container_gui_input(_mouse_wheel_event(MOUSE_BUTTON_WHEEL_UP))
	if absf(wheel_pane.pos_y - 40.0) > 1.5:
		_fail("ScrollPane mouse wheel did not scroll upward.")
		return
	wheel_pane.set_content_size(600, 100)
	wheel_pane.set_pos(0.0, 0.0)
	wheel_pane._on_container_gui_input(_mouse_wheel_event(MOUSE_BUTTON_WHEEL_DOWN))
	if absf(wheel_pane.pos_x - 40.0) > 1.5:
		_fail("ScrollPane mouse wheel did not select the horizontal-only axis.")
		return
	wheel_pane.page_mode = true
	wheel_pane.set_pos(0.0, 0.0)
	wheel_pane._on_container_gui_input(_mouse_wheel_event(MOUSE_BUTTON_WHEEL_DOWN))
	if absf(wheel_pane.pos_x - wheel_pane.view_width) > 1.5:
		_fail("ScrollPane mouse wheel did not advance by one page.")
		return
	wheel_pane.mouse_wheel_enabled = false
	wheel_pane._on_container_gui_input(_mouse_wheel_event(MOUSE_BUTTON_WHEEL_DOWN))
	if absf(wheel_pane.pos_x - wheel_pane.view_width) > 1.5:
		_fail("ScrollPane ignored mouse_wheel_enabled.")
		return
	var snap_owner := FGUIComponent.new()
	snap_owner.set_size(100.0, 50.0)
	host.add_child(snap_owner.node)
	var snap_pane := FGUIScrollPane.new(snap_owner)
	snap_owner.scroll_pane = snap_pane
	snap_pane.scroll_type = FGUIEnums.SCROLL_HORIZONTAL
	snap_pane._configure_native_scroll_modes()
	snap_pane.set_content_size(400.0, 50.0)
	snap_pane.snap_to_item = true
	var snap_end_count := {"value": 0}
	snap_owner.on(FGUIEvents.SCROLL_END, func() -> void: snap_end_count["value"] += 1)
	for item_x in [0.0, 100.0, 200.0, 320.0]:
		var snap_item := FGUIObject.new()
		snap_item.set_xy(item_x, 0.0)
		snap_item.set_size(80.0, 40.0)
		snap_owner.add_child(snap_item)
	snap_pane.set_pos(160.0, 0.0)
	snap_pane._begin_pull_gesture(Vector2.ZERO, -1)
	snap_pane._track_pull_gesture(Vector2(1.0, 0.0))
	snap_pane._end_pull_gesture()
	await create_timer(0.4).timeout
	if absf(snap_pane.pos_x - 200.0) > 1.5 or snap_end_count["value"] != 1:
		_fail("ScrollPane snap-to-item did not finish at the nearest component item exactly once: pos=%s end=%s" % [snap_pane.pos_x, snap_end_count["value"]])
		return

	var inertia_owner := FGUIComponent.new()
	inertia_owner.set_size(100.0, 100.0)
	host.add_child(inertia_owner.node)
	var inertia_pane := FGUIScrollPane.new(inertia_owner)
	inertia_owner.scroll_pane = inertia_pane
	var inertia_end_count := {"value": 0}
	inertia_owner.on(FGUIEvents.SCROLL_END, func() -> void: inertia_end_count["value"] = int(inertia_end_count["value"]) + 1)
	inertia_pane.scroll_type = FGUIEnums.SCROLL_VERTICAL
	inertia_pane._configure_native_scroll_modes()
	inertia_pane.set_content_size(100.0, 1000.0)
	inertia_pane.deceleration_rate = 0.9
	inertia_pane.set_pos(0.0, 300.0)
	inertia_pane._begin_pull_gesture(Vector2.ZERO, -1)
	inertia_pane._pointer_dragged = true
	inertia_pane._drag_velocity = Vector2(0.0, 1000.0)
	inertia_pane._end_pull_gesture()
	if inertia_pane._scroll_tween == null:
		_fail("ScrollPane did not start inertia after a fast pointer drag.")
		return
	await create_timer(0.9).timeout
	if inertia_pane.pos_y <= 350.0 or inertia_end_count["value"] != 1:
		_fail("ScrollPane inertia did not complete exactly once: pos=%s end=%s" % [inertia_pane.pos_y, inertia_end_count["value"]])
		return
	inertia_pane.inertia_disabled = true
	inertia_pane.set_pos(0.0, 300.0)
	inertia_pane._begin_pull_gesture(Vector2.ZERO, -1)
	inertia_pane._pointer_dragged = true
	inertia_pane._drag_velocity = Vector2(0.0, 1000.0)
	inertia_pane._end_pull_gesture()
	await process_frame
	if absf(inertia_pane.pos_y - 300.0) > 1.5 or inertia_pane._scroll_tween != null or inertia_end_count["value"] != 2:
		_fail("ScrollPane ignored the inertia-disabled package flag or emitted the wrong completion count.")
		return

	scroll_bar.dispose()
	inertia_owner.dispose()
	snap_owner.dispose()
	wheel_owner.dispose()
	pull_owner.dispose()
	controls_parent.dispose()
	parent.dispose()
	owner.dispose()
	view_target.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _make_controller(count: int) -> FGUIController:
	var controller := FGUIController.new()
	for i in count:
		controller.page_ids.append(str(i))
		controller.page_names.append("Page%s" % i)
	controller._selected_index = 0 if count > 0 else -1
	return controller


func _append_i16(bytes: PackedByteArray, value: int) -> void:
	bytes.append((value >> 8) & 0xff)
	bytes.append(value & 0xff)


func _append_i32(bytes: PackedByteArray, value: int) -> void:
	bytes.append((value >> 24) & 0xff)
	bytes.append((value >> 16) & 0xff)
	bytes.append((value >> 8) & 0xff)
	bytes.append(value & 0xff)


func _mouse_button_event(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event


func _mouse_wheel_event(button_index: int, factor: float = 1.0) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = true
	event.factor = factor
	return event


func _mouse_motion_event(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
