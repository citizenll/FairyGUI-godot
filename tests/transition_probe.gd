extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)

	var owner := FGUIComponent.new()
	owner.set_size(200, 120)
	host.add_child(owner.node)

	var child := FGUIObject.new()
	child.set_size(20, 20)
	child.set_xy(0, 0)
	owner.add_child(child)

	var transition := FGUITransition.new(owner)
	transition._items.append({
		"type": FGUITransition.ACTION_XY,
		"time": 0.0,
		"target_id": child.id,
		"target": null,
		"label": "move",
		"value": {},
		"tween_config": {
			"duration": 0.05,
			"ease_type": FGUIEaseType.LINEAR,
			"repeat": 0,
			"yoyo": false,
			"end_label": "move_end",
			"start_value": {"b1": true, "b2": true, "f1": 0.0, "f2": 0.0},
			"end_value": {"b1": true, "b2": true, "f1": 40.0, "f2": 30.0},
			"end_hook": Callable(),
			"path": null
		},
		"hook": Callable()
	})
	transition.raw_items = transition._items

	var completed := [false]
	transition.play(func() -> void: completed[0] = true)
	var waited := 0.0
	while not completed[0] and waited < 1.0:
		await create_timer(0.05).timeout
		waited += 0.05

	if not completed[0]:
		push_error("Transition completion callback was not called.")
		quit(1)
		return
	if absf(child.x - 40.0) > 0.1 or absf(child.y - 30.0) > 0.1:
		push_error("Transition XY tween failed: %s,%s" % [child.x, child.y])
		quit(1)
		return

	var repeat_transition := FGUITransition.new(owner)
	repeat_transition._items.append({
		"type": FGUITransition.ACTION_XY,
		"time": 0.0,
		"target_id": child.id,
		"target": null,
		"label": "repeat_move",
		"value": {},
		"tween_config": {
			"duration": 0.03,
			"ease_type": FGUIEaseType.LINEAR,
			"repeat": 1,
			"yoyo": false,
			"end_label": "repeat_end",
			"start_value": {"b1": true, "b2": true, "f1": 0.0, "f2": 0.0},
			"end_value": {"b1": true, "b2": true, "f1": 30.0, "f2": 10.0},
			"end_hook": Callable(),
			"path": null
		},
		"hook": Callable()
	})
	child.set_xy(0, 0)
	var repeat_completed := [false]
	repeat_transition.play(func() -> void: repeat_completed[0] = true)
	waited = 0.0
	while not repeat_completed[0] and waited < 1.0:
		await create_timer(0.05).timeout
		waited += 0.05
	if not repeat_completed[0] or absf(child.x - 30.0) > 0.1 or absf(child.y - 10.0) > 0.1:
		push_error("Transition repeat tween failed: completed=%s xy=%s,%s" % [repeat_completed[0], child.x, child.y])
		quit(1)
		return

	var yoyo_transition := FGUITransition.new(owner)
	yoyo_transition._items.append({
		"type": FGUITransition.ACTION_XY,
		"time": 0.0,
		"target_id": child.id,
		"target": null,
		"label": "yoyo_move",
		"value": {},
		"tween_config": {
			"duration": 0.03,
			"ease_type": FGUIEaseType.LINEAR,
			"repeat": 1,
			"yoyo": true,
			"end_label": "yoyo_end",
			"start_value": {"b1": true, "b2": true, "f1": 0.0, "f2": 0.0},
			"end_value": {"b1": true, "b2": true, "f1": 30.0, "f2": 10.0},
			"end_hook": Callable(),
			"path": null
		},
		"hook": Callable()
	})
	child.set_xy(0, 0)
	var yoyo_completed := [false]
	yoyo_transition.play(func() -> void: yoyo_completed[0] = true)
	waited = 0.0
	while not yoyo_completed[0] and waited < 1.0:
		await create_timer(0.05).timeout
		waited += 0.05
	if not yoyo_completed[0] or absf(child.x) > 0.1 or absf(child.y) > 0.1:
		push_error("Transition yoyo tween failed: completed=%s xy=%s,%s" % [yoyo_completed[0], child.x, child.y])
		quit(1)
		return

	var speed_transition := FGUITransition.new(owner)
	var speed_item: Dictionary = transition._items[0].duplicate(true)
	speed_item["tween_config"]["duration"] = 0.3
	speed_transition._items.append(speed_item)
	child.set_xy(0, 0)
	var speed_completed := [false]
	speed_transition.play(func() -> void: speed_completed[0] = true)
	await create_timer(0.03).timeout
	speed_transition.time_scale = 8.0
	waited = 0.0
	while not speed_completed[0] and waited < 0.15:
		await create_timer(0.02).timeout
		waited += 0.02
	if not speed_completed[0]:
		push_error("Transition runtime time_scale update failed.")
		quit(1)
		return

	var ease_value: Vector4 = transition._variant_at_tween_elapsed(
		{"type": FGUITransition.ACTION_XY, "tween_config": {"duration": 1.0, "ease_type": FGUIEaseType.QUAD_IN, "repeat": 0, "yoyo": false}},
		{"b1": true, "b2": true, "f1": 0.0, "f2": 0.0},
		{"b1": true, "b2": true, "f1": 100.0, "f2": 0.0},
		0.5
	)
	if absf(ease_value.x - 25.0) > 0.1:
		push_error("Transition ease evaluation failed: %s" % ease_value.x)
		quit(1)
		return
	if absf(FGUIEaseManager.evaluate(FGUIEaseType.QUART_IN, 0.5, 1.0) - 0.0625) > 0.001:
		push_error("QuartIn ease parity failed.")
		quit(1)
		return
	if absf(FGUIEaseManager.evaluate(FGUIEaseType.BACK_IN_OUT, 0.5, 1.0) - 0.5) > 0.001:
		push_error("BackInOut ease parity failed.")
		quit(1)
		return
	if absf(FGUIEaseManager.evaluate(FGUIEaseType.BOUNCE_OUT, 1.0, 1.0) - 1.0) > 0.001:
		push_error("BounceOut ease endpoint failed.")
		quit(1)
		return
	if absf(FGUIEaseManager.evaluate(FGUIEaseType.ELASTIC_OUT, 0.0, 1.0)) > 0.001:
		push_error("ElasticOut ease start endpoint failed.")
		quit(1)
		return

	var nested_component := FGUIComponent.new()
	nested_component.set_size(40, 40)
	owner.add_child(nested_component)
	var nested_transition := FGUITransition.new(nested_component)
	nested_transition.name = "nested"
	nested_transition._items.append(_make_alpha_tween_item(0.12))
	nested_component.transitions.append(nested_transition)

	var parent_transition := FGUITransition.new(owner)
	parent_transition._items.append(_make_nested_transition_item(nested_component.id, 0.0, 1))
	nested_component.alpha = 0.0
	var parent_completed := [false]
	parent_transition.play(func() -> void: parent_completed[0] = true)
	await create_timer(0.03).timeout
	if parent_completed[0]:
		push_error("Parent transition completed before nested transition.")
		quit(1)
		return
	parent_transition.set_paused(true)
	var paused_alpha := nested_component.alpha
	await create_timer(0.05).timeout
	if absf(nested_component.alpha - paused_alpha) > 0.01 or not nested_transition.paused:
		push_error("Nested transition pause propagation failed.")
		quit(1)
		return
	parent_transition.set_paused(false)
	waited = 0.0
	while not parent_completed[0] and waited < 1.0:
		await create_timer(0.03).timeout
		waited += 0.03
	if not parent_completed[0] or absf(nested_component.alpha - 1.0) > 0.05:
		push_error("Nested transition completion tracking failed: completed=%s alpha=%s" % [parent_completed[0], nested_component.alpha])
		quit(1)
		return

	nested_component.alpha = 0.0
	parent_transition.play()
	await create_timer(0.03).timeout
	parent_transition.stop(false, false)
	if nested_transition.playing:
		push_error("Nested transition stop propagation failed.")
		quit(1)
		return

	var stop_marker_transition := FGUITransition.new(owner)
	stop_marker_transition._items.append(_make_nested_transition_item(nested_component.id, 0.0, 1))
	stop_marker_transition._items.append(_make_nested_transition_item(nested_component.id, 0.05, 0))
	nested_component.alpha = 0.0
	var stop_marker_completed := [false]
	stop_marker_transition.play(func() -> void: stop_marker_completed[0] = true)
	waited = 0.0
	while not stop_marker_completed[0] and waited < 1.0:
		await create_timer(0.03).timeout
		waited += 0.03
	if not stop_marker_completed[0] or nested_component.alpha < 0.2 or nested_component.alpha > 0.6:
		push_error("Nested transition stop marker failed: completed=%s alpha=%s" % [stop_marker_completed[0], nested_component.alpha])
		quit(1)
		return

	var source_controller := FGUIController.new()
	source_controller.name = "source"
	source_controller.parent = owner
	source_controller.page_ids = ["source_a", "source_b"]
	source_controller.page_names = ["A", "B"]
	source_controller._selected_index = 0

	var target_controller := FGUIController.new()
	target_controller.name = "target"
	target_controller.parent = owner
	target_controller.page_ids = ["target_a", "target_b"]
	target_controller.page_names = ["A", "B"]
	target_controller._selected_index = 0
	owner.controllers = [source_controller, target_controller]

	var action := FGUIController.FGUIChangePageAction.new()
	action.controller_name = "target"
	action.target_page = "~2"
	source_controller.actions.append(action)
	source_controller.selected_index = 1
	if target_controller.selected_index != 1:
		push_error("Controller ChangePageAction failed.")
		quit(1)
		return

	var clip := FGUIMovieClip.new()
	clip.frames = [{"add_delay": 0, "texture": null}, {"add_delay": 0, "texture": null}]
	clip.frame = 0
	clip.set_prop(FGUIEnums.OBJECT_PROP_DELTA_TIME, 16)
	if clip.frame != 1:
		push_error("MovieClip frame advance failed.")
		quit(1)
		return

	transition.dispose()
	repeat_transition.dispose()
	yoyo_transition.dispose()
	speed_transition.dispose()
	parent_transition.dispose()
	stop_marker_transition.dispose()
	clip.dispose()
	owner.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _make_alpha_tween_item(duration: float) -> Dictionary:
	return {
		"type": FGUITransition.ACTION_ALPHA,
		"time": 0.0,
		"target_id": "",
		"target": null,
		"label": "nested_alpha",
		"value": {},
		"tween_config": {
			"duration": duration,
			"ease_type": FGUIEaseType.LINEAR,
			"repeat": 0,
			"yoyo": false,
			"end_label": "nested_alpha_end",
			"start_value": {"f1": 0.0},
			"end_value": {"f1": 1.0},
			"end_hook": Callable(),
			"path": null
		},
		"hook": Callable()
	}


func _make_nested_transition_item(target_id: String, time: float, play_times: int) -> Dictionary:
	return {
		"type": FGUITransition.ACTION_TRANSITION,
		"time": time,
		"target_id": target_id,
		"target": null,
		"label": "nested_action",
		"value": {"trans_name": "nested", "play_times": play_times},
		"tween_config": null,
		"hook": Callable()
	}
