extends SceneTree


func _initialize() -> void:
	var parent := FGUIComponent.new()
	var child := FGUIComponent.new()
	var leaf := FGUIObject.new()
	root.add_child(parent.node)
	parent.add_child(child)
	child.add_child(leaf)
	await process_frame

	var legacy_value: Array = ["unset"]
	leaf.on("legacy", func(value: Variant) -> void: legacy_value[0] = value)
	leaf.emit_event("legacy")
	if legacy_value[0] != null:
		_fail(parent, "Legacy event listeners did not receive a null payload.")
		return

	var order: Array[String] = []
	parent.add_capture("probe", func(context: FGUIEventContext) -> void:
		order.append("parent_capture")
		if context.sender != parent or context.initiator != leaf:
			order.append("invalid_context")
	)
	child.add_capture("probe", func(_context: FGUIEventContext) -> void: order.append("child_capture"))
	leaf.add_capture("probe", func(_context: FGUIEventContext) -> void: order.append("leaf_capture"))
	leaf.add_event_listener("probe", func(context: FGUIEventContext) -> void:
		order.append("leaf")
		if context.data != 7 or not leaf.is_dispatching("probe"):
			order.append("invalid_dispatch")
	)
	child.add_event_listener("probe", func(_context: FGUIEventContext) -> void: order.append("child"))
	parent.add_event_listener("probe", func(_context: FGUIEventContext) -> void: order.append("parent"))
	leaf.bubble_event("probe", 7)
	if order != ["parent_capture", "child_capture", "leaf_capture", "leaf", "child", "parent"]:
		_fail(parent, "Capture/bubble event order is invalid: %s" % [order])
		return

	var stopped: Array[String] = []
	parent.add_capture("stopped", func(_context: FGUIEventContext) -> void: stopped.append("parent_capture"))
	child.add_capture("stopped", func(context: FGUIEventContext) -> void:
		stopped.append("child_capture")
		context.stop_propagation()
	)
	leaf.add_capture("stopped", func(_context: FGUIEventContext) -> void: stopped.append("leaf_capture"))
	leaf.add_event_listener("stopped", func(_context: FGUIEventContext) -> void: stopped.append("leaf"))
	leaf.bubble_event("stopped")
	if stopped != ["parent_capture", "child_capture", "leaf_capture"]:
		_fail(parent, "Capture stop propagation did not suppress bubbling: %s" % [stopped])
		return

	leaf.add_event_listener("prevented", func(context: FGUIEventContext) -> void: context.prevent_default())
	if not leaf.bubble_event("prevented", {"value": 1}):
		_fail(parent, "PreventDefault did not propagate through the dispatch return value.")
		return

	var broadcast_order: Array[String] = []
	parent.add_event_listener("broadcast", func(_context: FGUIEventContext) -> void: broadcast_order.append("parent"))
	child.add_event_listener("broadcast", func(_context: FGUIEventContext) -> void: broadcast_order.append("child"))
	leaf.add_event_listener("broadcast", func(_context: FGUIEventContext) -> void: broadcast_order.append("leaf"))
	parent.broadcast_event("broadcast")
	if broadcast_order != ["parent", "child", "leaf"]:
		_fail(parent, "Broadcast event traversal is invalid: %s" % [broadcast_order])
		return

	var native_event := InputEventMouseButton.new()
	native_event.position = Vector2(12.0, 34.0)
	native_event.global_position = Vector2(12.0, 34.0)
	native_event.button_index = MOUSE_BUTTON_LEFT
	native_event.double_click = true
	var input_valid := [false]
	leaf.add_event_listener(FGUIEvents.CLICK, func(context: FGUIEventContext) -> void:
		input_valid[0] = context.type == FGUIEvents.CLICK and context.input_event != null \
			and context.input_event.native_event == native_event \
			and context.input_event.position == Vector2(12.0, 34.0) \
			and context.input_event.is_double_click
	)
	leaf.emit_event("click", native_event)
	if not input_valid[0]:
		_fail(parent, "Native input events were not exposed through FGUIInputEvent.")
		return

	var native_clicks := {"leaf": 0, "parent": 0}
	leaf.add_event_listener(FGUIEvents.CLICK, func(_context: FGUIEventContext) -> void: native_clicks["leaf"] += 1)
	parent.add_event_listener(FGUIEvents.CLICK, func(_context: FGUIEventContext) -> void: native_clicks["parent"] += 1)
	var release_event := InputEventMouseButton.new()
	release_event.position = Vector2(10.0, 10.0)
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	leaf._on_gui_input(release_event)
	parent._on_gui_input(release_event)
	if native_clicks != {"leaf": 1, "parent": 1}:
		_fail(parent, "Native click bubbling was duplicated during Godot Control propagation: %s" % [native_clicks])
		return

	var captured_counts := {"move": 0, "end": 0}
	var touch_begin_count := [0]
	leaf.add_event_listener(FGUIEvents.TOUCH_BEGIN, func(context: FGUIEventContext) -> void:
		touch_begin_count[0] += 1
		context.capture_touch()
	)
	leaf.add_event_listener(FGUIEvents.TOUCH_MOVE, func(_context: FGUIEventContext) -> void: captured_counts["move"] += 1)
	leaf.add_event_listener(FGUIEvents.TOUCH_END, func(_context: FGUIEventContext) -> void: captured_counts["end"] += 1)
	var press_event := InputEventMouseButton.new()
	press_event.position = Vector2(10.0, 10.0)
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	leaf._on_gui_input(press_event)
	var touch_monitor = FairyGUI.EventTouchMonitor._instance
	if touch_monitor == null:
		_fail(parent, "CaptureTouch did not install a global touch monitor (begin=%d, inside_tree=%s)." % [touch_begin_count[0], leaf.node.is_inside_tree()])
		return
	var inside_motion := InputEventMouseMotion.new()
	inside_motion.position = Vector2(20.0, 20.0)
	touch_monitor._input(inside_motion)
	leaf._on_gui_input(inside_motion)
	if not FairyGUI.EventDispatcher.was_native_event_dispatched(inside_motion, FGUIEvents.TOUCH_MOVE, leaf):
		_fail(parent, "Native touch recipient tracking did not record the target.")
		return
	await process_frame
	var outside_motion := InputEventMouseMotion.new()
	outside_motion.position = Vector2(500.0, 500.0)
	touch_monitor._input(outside_motion)
	await process_frame
	var outside_release := InputEventMouseButton.new()
	outside_release.position = Vector2(500.0, 500.0)
	outside_release.button_index = MOUSE_BUTTON_LEFT
	outside_release.pressed = false
	touch_monitor._input(outside_release)
	await process_frame
	if captured_counts != {"move": 2, "end": 1}:
		_fail(parent, "Captured touch delivery or native-event de-duplication failed: %s" % [captured_counts])
		return
	leaf.stop_drag()

	var controller := FGUIController.new()
	controller.parent = parent
	controller.add_page("first")
	controller.add_page("second")
	var controller_context_valid := [false]
	controller.add_event_listener("onChanged", func(context: FGUIEventContext) -> void:
		controller_context_valid[0] = context.sender == controller and context.data == controller
	)
	controller.selected_index = 1
	if not controller_context_valid[0]:
		controller.dispose()
		_fail(parent, "Controller events did not use EventContext dispatch.")
		return
	controller.dispose()

	parent.dispose()
	await process_frame
	quit(0)


func _fail(parent: FGUIComponent, message: String) -> void:
	push_error(message)
	if parent != null and not parent.is_disposed:
		parent.dispose()
	quit(1)
