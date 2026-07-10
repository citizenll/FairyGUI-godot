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
	await process_frame
	if absf(pane.pos_x - pane.view_width) > 1.5:
		_fail("Page controller did not move the horizontal ScrollPane: %s" % pane.pos_x)
		return
	pane.set_current_page_x(2)
	if page_controller.selected_index != 2:
		_fail("ScrollPane did not update its page controller.")
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

	pane.page_mode = false
	pane.scroll_type = FGUIEnums.SCROLL_VERTICAL
	pane._configure_native_scroll_modes()
	pane.set_content_size(100, 600)
	await process_frame
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

	scroll_bar.dispose()
	controls_parent.dispose()
	parent.dispose()
	owner.dispose()
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


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
