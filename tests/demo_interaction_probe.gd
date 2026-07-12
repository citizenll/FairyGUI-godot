extends SceneTree

const TRANSITION_RESOURCES := ["BOSS", "BOSS_SKILL", "TRAP", "GoodHit", "PowerUp", "PathDemo"]

var _demo: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1136, 640)
	var packed := load("res://demo.tscn") as PackedScene
	if packed == null:
		_fail("Root demo.tscn could not be loaded for interaction coverage.")
		return
	_demo = packed.instantiate() as Control
	root.add_child(_demo)
	await _wait_frames(4)
	if not await _test_basics():
		return
	if not await _test_transitions():
		return
	if not await _test_lists_and_hit_testing():
		return
	if not await _test_refresh_waiting_and_joystick():
		return
	if not await _test_bag_chat_and_effects():
		return
	if not await _test_scroll_tree_guide_and_cooldown():
		return
	_demo.queue_free()
	await _wait_frames(8)
	quit(0)


func _test_basics() -> bool:
	var view := await _open_demo("Basics")
	if view == null:
		return false
	var container := view.get_child("container") as FGUIComponent
	var controller := view.get_controller("c1")
	for demo_type: String in _demo.get_basic_demo_types():
		var button := view.get_child("btn_%s" % demo_type)
		if button == null:
			_fail("Basics button is missing: %s" % demo_type)
			return false
		await _native_click(button)
		await _wait_frames(2)
		if controller == null or controller.selected_index != 1 or container.num_children != 1:
			_fail(
				"Basics button did not open its panel: %s (rect=%s visible=%s tree_visible=%s in_tree=%s touchable=%s mouse_filter=%s listener=%s controller=%s children=%s group=%s group_visible=%s)"
				% [
					demo_type,
					button.node.get_global_rect(),
					button.visible,
					button.node.is_visible_in_tree(),
					button.node.is_inside_tree(),
					button.touchable,
					button.node.mouse_filter,
					button.has_event_listener("click"),
					controller.selected_index if controller != null else -1,
					container.num_children,
					button.group.name if button.group != null else "<none>",
					button.group.node.is_visible_in_tree() if button.group != null else false,
				]
			)
			return false
		var panel := container.get_child_at(0) as FGUIComponent
		if panel == null or panel.package_item == null or panel.package_item.name != "Demo_%s" % demo_type:
			_fail("Basics opened the wrong panel for %s." % demo_type)
			return false
		if not await _exercise_basic_panel(demo_type, panel):
			return false
		await _native_click(view.get_child("btn_Back"))
		await _wait_frames(2)
		if controller.selected_index != 0:
			_fail("Basics back button did not restore the feature list after %s." % demo_type)
			return false
	_demo.return_to_menu()
	await _wait_frames(3)
	return true


func _exercise_basic_panel(demo_type: String, panel: FGUIComponent) -> bool:
	match demo_type:
		"Button":
			await _native_click(panel.get_child("n34"))
		"Text":
			var input := panel.get_child("n22")
			input.set_text("FairyGUI Godot")
			await _native_click(panel.get_child("n25"))
			if panel.get_child("n24").get_text() != "FairyGUI Godot":
				_fail("Basics text input copy action was not connected.")
				return false
			panel.get_child("n12").emit_event(FGUIEvents.CLICK_LINK, "https://fairygui.com")
			if not panel.get_child("n12").get_text().contains("fairygui.com"):
				_fail("Basics rich-text link action was not connected.")
				return false
		"Window":
			await _native_click(panel.get_child("n0"))
			await _wait_frames(2)
			var window_a := FGUIRoot.get_inst().get_top_window()
			if window_a == null or (window_a.content_pane.get_child("n6") as FGUIList).num_children != 6:
				_fail("Basics WindowA did not open and populate its list.")
				return false
			await _native_click(window_a.close_button)
			await _wait_frames(2)
			await _native_click(panel.get_child("n1"))
			await _wait_frames(2)
			var window_b := FGUIRoot.get_inst().get_top_window()
			if window_b == null or window_b.content_pane.get_transition("t1") == null:
				_fail("Basics WindowB did not open with its transition.")
				return false
			await _native_click(window_b.close_button)
		"Popup":
			await _native_click(panel.get_child("n0"))
			if not FGUIRoot.get_inst().has_any_popup():
				_fail("Basics popup menu button was not connected.")
				return false
			FGUIRoot.get_inst().hide_popup()
			await _native_click(panel.get_child("n1"))
			if not FGUIRoot.get_inst().has_any_popup():
				_fail("Basics custom popup button was not connected.")
				return false
			FGUIRoot.get_inst().hide_popup()
		"Drag&Drop":
			var source := panel.get_child("b") as FGUIButton
			var target := panel.get_child("c") as FGUIButton
			if source == null or target == null or not source.draggable or not target.has_event_listener(FGUIEvents.DROP):
				_fail("Basics drag/drop handlers were not connected.")
				return false
			await _native_drag_between(source.node, target.node)
			if target.icon != source.icon:
				_fail("Basics drop target did not accept a native mouse drag.")
				return false
		"Depth":
			var depth_container := panel.get_child("n22") as FGUIComponent
			await _native_click(panel.get_child("btn0"))
			await _native_click(panel.get_child("btn1"))
			if depth_container.num_children != 3 or depth_container.get_child_at(2).sorting_order != 200:
				_fail("Basics depth buttons did not add normal and sorted children.")
				return false
		"Grid":
			var list_1 := panel.get_child("list1") as FGUIList
			if list_1.num_children != 6 or (panel.get_child("list2") as FGUIList).num_children != 6:
				_fail("Basics grid renderer did not populate both data grids.")
				return false
			var row := list_1.get_child_at(0) as FGUIButton
			var stars := row.get_child("star") as FGUIProgressBar
			var star_bar := stars.get_child("bar") as FGUIImage
			if star_bar == null or not star_bar.content_item.scale_by_tile \
				or star_bar.image_node.axis_stretch_horizontal != NinePatchRect.AXIS_STRETCH_MODE_TILE \
				or star_bar.image_node.axis_stretch_vertical != NinePatchRect.AXIS_STRETCH_MODE_TILE:
				_fail("Grid star progress image did not retain FairyGUI tiled-image semantics.")
				return false
			var sound_players := {"count": 0}
			FGUIRoot.get_inst().node.child_entered_tree.connect(func(node: Node) -> void:
				if node is AudioStreamPlayer:
					sound_players["count"] += 1
			)
			await _native_click(stars)
			if sound_players["count"] != 1:
				_fail("A single nested Grid click played the button sound %d times." % sound_players["count"])
				return false
		"Slider":
			var slider: FGUISlider
			for child: FGUIObject in panel.children:
				if child is FGUISlider:
					slider = child as FGUISlider
					break
			if slider == null:
				_fail("Basics Slider panel has no slider.")
				return false
			var grip := slider.get_child("grip")
			await _wait_until_stable(slider)
			var initial_y := grip.y
			var initial_value := slider.value
			await _native_drag_control(grip.node, Vector2(50.0, -70.0))
			if grip.draggable or not is_equal_approx(grip.y, initial_y) or is_equal_approx(slider.value, initial_value):
				_fail("Slider grip escaped its track or failed to update from captured pointer movement.")
				return false
		"ProgressBar":
			var progress: FGUIProgressBar
			for child: FGUIObject in panel.children:
				if child is FGUIProgressBar:
					progress = child as FGUIProgressBar
					break
			if progress == null:
				_fail("Basics progress panel has no progress bar.")
				return false
			var previous := progress.value
			await create_timer(0.12).timeout
			if is_equal_approx(progress.value, previous):
				_fail("Basics progress animation did not advance.")
				return false
	return true


func _test_transitions() -> bool:
	for index in TRANSITION_RESOURCES.size():
		var view := await _open_demo("Transition")
		if view == null:
			return false
		await _native_click(view.get_child("btn%d" % index))
		await _wait_frames(3)
		var target_found := false
		for child: FGUIObject in FGUIRoot.get_inst().children:
			if child.package_item != null and child.package_item.name == TRANSITION_RESOURCES[index]:
				target_found = true
				break
		if not target_found:
			_fail("Transition button %d did not attach %s." % [index, TRANSITION_RESOURCES[index]])
			return false
		_demo.return_to_menu()
		await _wait_frames(3)
	return true


func _test_lists_and_hit_testing() -> bool:
	var view := await _open_demo("VirtualList")
	if view == null:
		return false
	var virtual_list := view.get_child("mailList") as FGUIList
	await _native_click(view.get_child("n6"))
	if virtual_list.selected_index != 500:
		_fail("Virtual list selection button did not select item 500.")
		return false
	await _native_click(view.get_child("n7"))
	if not is_zero_approx(virtual_list.scroll_pane.pos_y):
		_fail("Virtual list top button did not return to the first row.")
		return false
	virtual_list.clear_selection()
	await _native_drag_control(virtual_list.scroll_pane.container, Vector2(0.0, -140.0))
	if virtual_list.scroll_pane.pos_y <= 0.0 or virtual_list.selected_index != -1:
		_fail("Virtual list mouse drag did not scroll cleanly without clicking an item.")
		return false
	await _native_click(view.get_child("n8"))
	if virtual_list.scroll_pane.pos_y <= 0.0:
		_fail("Virtual list bottom button did not move to the final rows.")
		return false
	_demo.return_to_menu()
	await _wait_frames(2)

	view = await _open_demo("LoopList")
	if view == null:
		return false
	var loop_list := view.get_child("list") as FGUIList
	var loop_start := loop_list.scroll_pane.pos_x
	await _native_drag_control(loop_list.scroll_pane.container, Vector2(-180.0, 0.0))
	await _wait_frames(3)
	if loop_list.scroll_pane.pos_x <= loop_start or view.get_child("n3").get_text().is_empty() or loop_list.num_children == 0:
		_fail("Loop list scroll effect did not update its visible items and index.")
		return false
	_demo.return_to_menu()
	await _wait_frames(2)

	view = await _open_demo("HitTest")
	if view == null:
		return false
	for child_name in ["n30", "n31", "n32", "n35"]:
		await _native_click(view.get_child(child_name))
	_demo.return_to_menu()
	await _wait_frames(2)
	return true


func _test_refresh_waiting_and_joystick() -> bool:
	var view := await _open_demo("PullToRefresh")
	if view == null:
		return false
	var list_1 := view.get_child("list1") as FGUIList
	var header := list_1.scroll_pane.header
	await _native_drag_control(list_1.scroll_pane.container, Vector2(0.0, 220.0), 10)
	if header.get_controller("c1").selected_index != 2 or list_1.scroll_pane.header_locked_size <= 0.0:
		_fail("Native pull-down refresh did not lock and update the header.")
		return false
	var list_2 := view.get_child("list2") as FGUIList
	list_2.scroll_pane.scroll_bottom()
	await _native_drag_control(list_2.scroll_pane.container, Vector2(0.0, -220.0), 10)
	if list_2.scroll_pane.footer_locked_size <= 0.0:
		_fail("Native pull-up refresh did not lock the footer.")
		return false
	_demo.return_to_menu()
	await _wait_frames(2)

	view = await _open_demo("ModalWaiting")
	if view == null or not FGUIRoot.get_inst().modal_waiting:
		_fail("Modal waiting demo did not show the global wait pane.")
		return false
	FGUIRoot.get_inst().close_modal_wait()
	await _wait_frames(2)
	await _native_click(view.get_child("n0"))
	await _wait_frames(2)
	var window := FGUIRoot.get_inst().get_top_window()
	if window == null:
		_fail("Modal waiting demo did not open its test window.")
		return false
	await _native_click(window.content_pane.get_child("n1"))
	if not window.modal_waiting:
		_fail("Modal waiting window did not show its local wait pane.")
		return false
	_demo.return_to_menu()
	await _wait_frames(2)

	view = await _open_demo("Joystick")
	if view == null:
		return false
	var touch_area := view.get_child("joystick_touch")
	var start := touch_area.node.get_global_rect().get_center()
	root.push_input(_mouse_button(start, true))
	await process_frame
	var end := start + Vector2(70.0, -40.0)
	root.push_input(_mouse_motion(end, end - start, MOUSE_BUTTON_MASK_LEFT))
	await _wait_frames(2)
	if view.get_child("n9").get_text().is_empty():
		_fail("Joystick drag did not publish its movement angle.")
		return false
	root.push_input(_mouse_button(end, false))
	await _wait_frames(2)
	if not view.get_child("n9").get_text().is_empty():
		_fail("Joystick release did not clear its movement angle.")
		return false
	_demo.return_to_menu()
	await _wait_frames(2)
	return true


func _test_bag_chat_and_effects() -> bool:
	var view := await _open_demo("Bag")
	if view == null:
		return false
	await _native_click(view.get_child("bagBtn"))
	await _wait_frames(3)
	var bag_window := FGUIRoot.get_inst().get_top_window()
	var bag_list := bag_window.content_pane.get_child("list") as FGUIList if bag_window != null else null
	if bag_window == null or bag_list == null or bag_list.num_items != 45 or bag_list.num_children == 0:
		_fail("Bag window did not open and populate its virtual item list.")
		return false
	await _native_click(bag_list.get_child_at(0))
	if bag_window.content_pane.get_child("n13").get_text().is_empty():
		_fail("Bag item click did not update the selected item details.")
		return false
	_demo.return_to_menu()
	await _wait_frames(2)

	view = await _open_demo("Chat")
	if view == null:
		return false
	var input := view.get_child("input1") as FGUITextInput
	input.set_text("Godot [:88]")
	await _native_click(view.get_child("btnSend1"))
	var chat_list := view.get_child("list") as FGUIList
	if chat_list.num_items == 0 or not input.get_text().is_empty():
		_fail("Chat send button did not append and clear the message.")
		return false
	await _native_click(view.get_child("btnEmoji1"))
	if not FGUIRoot.get_inst().has_any_popup():
		_fail("Chat emoji button did not open the picker.")
		return false
	var emoji_popup: FGUIComponent
	for child: FGUIObject in FGUIRoot.get_inst().children:
		if child.package_item != null and child.package_item.name == "EmojiSelectUI":
			emoji_popup = child as FGUIComponent
			break
	if emoji_popup == null:
		_fail("Chat emoji picker component was not attached.")
		return false
	var emoji_list := emoji_popup.get_child("list") as FGUIList
	await _native_click(emoji_list.get_child_at(0))
	if input.get_text().is_empty():
		_fail("Chat emoji selection did not append its token.")
		return false
	_demo.return_to_menu()
	await _wait_frames(2)

	view = await _open_demo("ListEffect")
	if view == null:
		return false
	var effect_list := view.get_child("mailList") as FGUIList
	if effect_list.num_children != 10:
		_fail("List effect demo did not create all mail rows.")
		return false
	await create_timer(0.08).timeout
	_demo.return_to_menu()
	await _wait_frames(2)
	return true


func _test_scroll_tree_guide_and_cooldown() -> bool:
	var view := await _open_demo("ScrollPane")
	if view == null:
		return false
	var list := view.get_child("list") as FGUIList
	if list.num_children == 0:
		_fail("Scroll pane demo did not render virtual rows.")
		return false
	var row := list.get_child_at(0) as FGUIButton
	await _native_drag_control(row.scroll_pane.container, Vector2(-180.0, 0.0))
	await _wait_frames(2)
	if row.scroll_pane.pos_x <= 0.0:
		_fail("Scroll pane row did not reveal its actions from a horizontal mouse drag.")
		return false
	await _native_click(row.get_child("b0"))
	if not view.get_child("txt").get_text().begins_with("Stick Item"):
		_fail("Scroll pane row action was not connected.")
		return false
	_demo.return_to_menu()
	await _wait_frames(2)

	view = await _open_demo("TreeView")
	if view == null:
		return false
	var tree_1 := view.get_child("tree") as FGUITree
	var tree_2 := view.get_child("tree2") as FGUITree
	if tree_1.num_children == 0 or tree_2.root_node.num_children != 2:
		_fail("Tree demo did not retain the package tree and build the runtime tree.")
		return false
	await _native_click(tree_1.get_child_at(0))
	_demo.return_to_menu()
	await _wait_frames(2)

	view = await _open_demo("Guide")
	if view == null:
		return false
	await _native_click(view.get_child("n2"))
	var guide_layer: FGUIComponent
	for child: FGUIObject in FGUIRoot.get_inst().children:
		if child.package_item != null and child.package_item.name == "GuideLayer":
			guide_layer = child as FGUIComponent
			break
	if guide_layer == null:
		_fail("Guide button did not attach the guide layer.")
		return false
	await create_timer(0.55).timeout
	await _native_click(view.get_child("bagBtn"))
	if guide_layer.parent != null:
		_fail("Guide target click did not dismiss the guide layer.")
		return false
	_demo.return_to_menu()
	await _wait_frames(2)

	view = await _open_demo("Cooldown")
	if view == null:
		return false
	var cooldown := view.get_child("b0") as FGUIProgressBar
	var bar := cooldown.get_child("bar") as FGUIImage
	var previous_fill := bar.fill_amount
	await create_timer(0.18).timeout
	if is_equal_approx(bar.fill_amount, previous_fill):
		_fail("Cooldown tween did not advance its radial fill.")
		return false
	_demo.return_to_menu()
	await _wait_frames(2)
	return true


func _open_demo(demo_name: String) -> FGUIComponent:
	if not _demo.open_demo(demo_name):
		_fail("Could not open demo for interaction coverage: %s" % demo_name)
		return null
	await _wait_frames(3)
	return _demo.get_current_view()


func _native_click(object: FGUIObject) -> void:
	if object == null or object.node == null:
		return
	await _wait_until_stable(object)
	if object.node == null:
		return
	var position := object.node.get_global_rect().get_center()
	root.push_input(_mouse_motion(position, Vector2.ZERO))
	await process_frame
	position = object.node.get_global_rect().get_center()
	root.push_input(_mouse_button(position, true))
	await process_frame
	root.push_input(_mouse_button(position, false))
	await process_frame


func _native_drag_control(control: Control, delta: Vector2, steps: int = 8) -> void:
	if control == null:
		return
	await _wait_control_stable(control)
	var start := control.get_global_rect().get_center()
	await _native_drag_positions(start, start + delta, steps)


func _native_drag_between(source: Control, target: Control, steps: int = 8) -> void:
	if source == null or target == null:
		return
	await _wait_control_stable(source)
	await _wait_control_stable(target)
	await _native_drag_positions(source.get_global_rect().get_center(), target.get_global_rect().get_center(), steps)


func _native_drag_positions(start: Vector2, finish: Vector2, steps: int) -> void:
	root.push_input(_mouse_motion(start, Vector2.ZERO))
	await process_frame
	root.push_input(_mouse_button(start, true))
	await process_frame
	var previous := start
	for step in maxi(1, steps):
		var position := start.lerp(finish, float(step + 1) / float(maxi(1, steps)))
		root.push_input(_mouse_motion(position, position - previous, MOUSE_BUTTON_MASK_LEFT))
		previous = position
		await process_frame
	root.push_input(_mouse_button(finish, false))
	await _wait_frames(3)


func _wait_until_stable(object: FGUIObject, max_frames: int = 45) -> void:
	if object == null or object.node == null:
		return
	var previous := object.node.get_global_rect()
	var stable_frames := 0
	for _frame in max_frames:
		await process_frame
		if object.node == null:
			return
		var current := object.node.get_global_rect()
		if current.position.is_equal_approx(previous.position) and current.size.is_equal_approx(previous.size):
			stable_frames += 1
			if stable_frames >= 2:
				return
		else:
			stable_frames = 0
		previous = current


func _wait_control_stable(control: Control, max_frames: int = 45) -> void:
	if control == null:
		return
	var previous := control.get_global_rect()
	var stable_frames := 0
	for _frame in max_frames:
		await process_frame
		if not is_instance_valid(control):
			return
		var current := control.get_global_rect()
		if current.position.is_equal_approx(previous.position) and current.size.is_equal_approx(previous.size):
			stable_frames += 1
			if stable_frames >= 2:
				return
		else:
			stable_frames = 0
		previous = current


func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event


func _mouse_motion(position: Vector2, relative: Vector2, button_mask: int = 0) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = button_mask
	return event


func _wait_frames(count: int) -> void:
	for _index in count:
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	if _demo != null and is_instance_valid(_demo):
		_demo.queue_free()
	quit(1)
