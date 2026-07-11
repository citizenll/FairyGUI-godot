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

	var auto_owner := FGUIComponent.new()
	auto_owner.alpha = 0.0
	var auto_transition := FGUITransition.new(auto_owner)
	auto_transition._auto_play = true
	auto_transition._auto_play_times = 1
	auto_transition._items.append(_make_alpha_tween_item(0.04))
	auto_owner.transitions.append(auto_transition)
	host.add_child(auto_owner.node)
	await create_timer(0.12).timeout
	if auto_transition.playing or absf(auto_owner.alpha - 1.0) > 0.05:
		push_error("Transition auto-play did not run when its component entered the stage.")
		quit(1)
		return

	var stage_owner := FGUIComponent.new()
	stage_owner.alpha = 0.0
	var stage_transition := FGUITransition.new(stage_owner)
	stage_transition._auto_play = true
	stage_transition._auto_play_times = 1
	stage_transition._items.append(_make_alpha_tween_item(0.5))
	stage_owner.transitions.append(stage_transition)
	host.add_child(stage_owner.node)
	await process_frame
	await process_frame
	if not stage_transition.playing:
		push_error("Transition auto-play did not start before the component left the stage.")
		quit(1)
		return
	host.remove_child(stage_owner.node)
	await process_frame
	if stage_transition.playing:
		push_error("Transition did not stop when its component left the stage.")
		quit(1)
		return
	stage_owner.dispose()
	auto_owner.dispose()

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

	var delayed_capture_transition := FGUITransition.new(owner)
	delayed_capture_transition._items.append({
		"type": FGUITransition.ACTION_XY,
		"time": 0.08,
		"target_id": child.id,
		"target": null,
		"label": "capture_delayed_xy",
		"value": {},
		"tween_config": {
			"duration": 0.3,
			"ease_type": FGUIEaseType.LINEAR,
			"repeat": 0,
			"yoyo": false,
			"end_label": "capture_delayed_xy_end",
			"start_value": {"b1": false, "b2": true, "f1": 0.0, "f2": 0.0},
			"end_value": {"b1": true, "b2": true, "f1": 100.0, "f2": 0.0},
			"end_hook": Callable(),
			"path": null
		},
		"hook": Callable()
	})
	child.set_xy(10.0, 0.0)
	delayed_capture_transition.play()
	await create_timer(0.03).timeout
	child.set_xy(60.0, 0.0)
	await create_timer(0.11).timeout
	if child.x < 55.0:
		push_error("Transition delayed tween did not capture its missing start value at action time: %s" % child.x)
		quit(1)
		return
	delayed_capture_transition.stop(false, false)

	var instant_hook_transition := FGUITransition.new(owner)
	var instant_start_hook_count := [0]
	var instant_end_hook_count := [0]
	instant_hook_transition._items.append({
		"type": FGUITransition.ACTION_ALPHA,
		"time": 0.0,
		"target_id": child.id,
		"target": null,
		"label": "instant_alpha",
		"value": {},
		"tween_config": {
			"duration": 0.0,
			"ease_type": FGUIEaseType.LINEAR,
			"repeat": 0,
			"yoyo": false,
			"end_label": "instant_alpha_end",
			"start_value": {"f1": 0.25},
			"end_value": {"f1": 0.75},
			"end_hook": func() -> void: instant_end_hook_count[0] += 1,
			"path": null
		},
		"hook": func() -> void: instant_start_hook_count[0] += 1
	})
	child.alpha = 0.0
	instant_hook_transition.play()
	await process_frame
	if absf(child.alpha - 0.75) > 0.01 or instant_start_hook_count[0] != 1 or instant_end_hook_count[0] != 1:
		push_error("Transition zero-duration tween did not apply hooks and final state exactly once.")
		quit(1)
		return

	var instant_repeat_transition := FGUITransition.new(owner)
	var instant_repeat_count := [0]
	var instant_repeat_item: Dictionary = instant_hook_transition._items[0].duplicate(true)
	instant_repeat_item["label"] = "instant_repeat"
	instant_repeat_item["tween_config"]["end_label"] = "instant_repeat_end"
	instant_repeat_item["hook"] = func() -> void: instant_repeat_count[0] += 1
	instant_repeat_item["tween_config"]["end_hook"] = Callable()
	instant_repeat_transition._items.append(instant_repeat_item)
	var instant_repeat_completed := [false]
	instant_repeat_transition.play(func() -> void: instant_repeat_completed[0] = true, 3)
	var instant_repeat_frames := 0
	while not instant_repeat_completed[0] and instant_repeat_frames < 8:
		await process_frame
		instant_repeat_frames += 1
	if not instant_repeat_completed[0] or instant_repeat_count[0] != 3:
		push_error("Transition zero-task repeat did not complete across deferred cycles: completed=%s hooks=%s" % [instant_repeat_completed[0], instant_repeat_count[0]])
		quit(1)
		return

	var instant_infinite_transition := FGUITransition.new(owner)
	var instant_infinite_count := [0]
	var instant_infinite_item: Dictionary = instant_hook_transition._items[0].duplicate(true)
	instant_infinite_item["label"] = "instant_infinite"
	instant_infinite_item["tween_config"]["end_label"] = "instant_infinite_end"
	instant_infinite_item["hook"] = func() -> void: instant_infinite_count[0] += 1
	instant_infinite_item["tween_config"]["end_hook"] = Callable()
	instant_infinite_transition._items.append(instant_infinite_item)
	instant_infinite_transition.play(Callable(), -1)
	for frame in 3:
		await process_frame
	if not instant_infinite_transition.playing or instant_infinite_count[0] < 2:
		push_error("Transition zero-task infinite repeat did not stay active across frames: hooks=%s" % instant_infinite_count[0])
		quit(1)
		return
	instant_infinite_transition.stop(false, false)

	child.set_size(20.0, 20.0)
	child.set_pivot(0.5, 0.5, true)
	var property_transition := FGUITransition.new(owner)
	property_transition._items.append({
		"type": FGUITransition.ACTION_SIZE,
		"time": 0.0,
		"target_id": child.id,
		"target": null,
		"label": "partial_size",
		"value": {"b1": false, "b2": true, "f1": 0.0, "f2": 45.0},
		"tween_config": null,
		"hook": Callable()
	})
	property_transition._items.append({
		"type": FGUITransition.ACTION_PIVOT,
		"time": 0.0,
		"target_id": child.id,
		"target": null,
		"label": "pivot",
		"value": {"b1": true, "b2": true, "f1": 0.25, "f2": 0.75},
		"tween_config": null,
		"hook": Callable()
	})
	property_transition.play()
	await process_frame
	if absf(child.width - 20.0) > 0.1 or absf(child.height - 45.0) > 0.1 or not child.pivot_as_anchor:
		push_error("Transition property actions did not preserve partial size or pivot anchor state.")
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

	var shake_transition := FGUITransition.new(owner)
	shake_transition._items.append({
		"type": FGUITransition.ACTION_SHAKE,
		"time": 0.0,
		"target_id": child.id,
		"target": null,
		"label": "shake",
		"value": {"amplitude": 8.0, "duration": 0.2},
		"tween_config": null,
		"hook": Callable()
	})
	var shake_origin := Vector2(10, 10)
	child.set_xy(shake_origin.x, shake_origin.y)
	shake_transition.play()
	await create_timer(0.05).timeout
	if Vector2(child.x, child.y).is_equal_approx(shake_origin):
		push_error("Transition shake did not move the target.")
		quit(1)
		return
	shake_transition.stop(false, false)
	if not Vector2(child.x, child.y).is_equal_approx(shake_origin):
		push_error("Transition shake did not reset after stop: %s,%s" % [child.x, child.y])
		quit(1)
		return
	var shake_completed := [false]
	shake_transition.play(func() -> void: shake_completed[0] = true, 1, 0.0, 0.0, 0.05)
	waited = 0.0
	while not shake_completed[0] and waited < 1.0:
		await create_timer(0.03).timeout
		waited += 0.03
	if not shake_completed[0] or not Vector2(child.x, child.y).is_equal_approx(shake_origin):
		push_error("Transition shake breakpoint did not reset the target.")
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

	var straight_path := FGUIGPath.new()
	straight_path.create([
		FGUIGPathPoint.new_point(0.0, 0.0, FGUIGPath.CURVE_STRAIGHT),
		FGUIGPathPoint.new_point(20.0, 0.0, FGUIGPath.CURVE_STRAIGHT)
	])
	if not straight_path.get_point_at(0.5).is_equal_approx(Vector2(10.0, 0.0)):
		push_error("Transition straight path evaluation failed.")
		quit(1)
		return
	var quadratic_path := FGUIGPath.new()
	quadratic_path.create([
		FGUIGPathPoint.new_bezier_point(0.0, 0.0, 10.0, 20.0),
		FGUIGPathPoint.new_point(20.0, 0.0, FGUIGPath.CURVE_STRAIGHT)
	])
	if not quadratic_path.get_point_at(0.5).is_equal_approx(Vector2(10.0, 10.0)):
		push_error("Transition quadratic path evaluation failed: %s" % quadratic_path.get_point_at(0.5))
		quit(1)
		return
	var cubic_path := FGUIGPath.new()
	cubic_path.create([
		FGUIGPathPoint.new_cubic_bezier_point(0.0, 0.0, 0.0, 20.0, 20.0, 20.0),
		FGUIGPathPoint.new_point(20.0, 0.0, FGUIGPath.CURVE_STRAIGHT)
	])
	if not cubic_path.get_point_at(0.5).is_equal_approx(Vector2(10.0, 15.0)):
		push_error("Transition cubic path evaluation failed: %s" % cubic_path.get_point_at(0.5))
		quit(1)
		return
	var spline_path := FGUIGPath.new()
	spline_path.create([
		FGUIGPathPoint.new_point(0.0, 0.0),
		FGUIGPathPoint.new_point(10.0, 20.0),
		FGUIGPathPoint.new_point(20.0, 0.0)
	])
	if not spline_path.get_point_at(0.0).is_equal_approx(Vector2.ZERO) or not spline_path.get_point_at(1.0).is_equal_approx(Vector2(20.0, 0.0)):
		push_error("Transition Catmull-Rom path endpoints failed.")
		quit(1)
		return

	var path_transition := FGUITransition.new(owner)
	var path_item := {
		"type": FGUITransition.ACTION_XY,
		"target": child,
		"target_id": child.id,
		"value": {},
		"tween_config": {
			"duration": 1.0,
			"ease_type": FGUIEaseType.LINEAR,
			"repeat": 0,
			"yoyo": false,
			"path": quadratic_path,
		}
	}
	var path_start := {"b1": true, "b2": true, "f1": 100.0, "f2": 50.0}
	var path_end := {"b1": true, "b2": true, "f1": 120.0, "f2": 50.0}
	child.set_xy(0.0, 0.0)
	path_transition._apply_tween_elapsed(0.5, path_item, path_start, path_end)
	if absf(child.x - 110.0) > 0.1 or absf(child.y - 60.0) > 0.1:
		push_error("Transition path did not preserve the tween start offset: %s,%s" % [child.x, child.y])
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
	clip.frames = [
		{"add_delay": 0, "texture": null},
		{"add_delay": 0, "texture": null},
		{"add_delay": 0, "texture": null},
		{"add_delay": 0, "texture": null},
	]
	clip.interval = 0.1
	clip.repeat_delay = 0.0
	clip.swing = false
	clip.rewind()
	clip.advance(0.31)
	if clip.frame != 3:
		push_error("MovieClip advance did not consume elapsed time across multiple frames: %s" % clip.frame)
		quit(1)
		return
	clip.rewind()
	clip.swing = true
	clip.advance(0.61)
	if clip.frame != 0:
		push_error("MovieClip swing advance did not reverse at both ends: %s" % clip.frame)
		quit(1)
		return
	clip.frames = [{"add_delay": 0, "texture": null}, {"add_delay": 0, "texture": null}]
	clip.interval = 0.1
	clip.repeat_delay = 0.2
	clip.swing = false
	clip.rewind()
	clip.advance(0.21)
	if clip.frame != 0:
		push_error("MovieClip advance did not complete the first loop.")
		quit(1)
		return
	clip.advance(0.29)
	if clip.frame != 0:
		push_error("MovieClip repeat delay was not applied after a loop.")
		quit(1)
		return
	clip.advance(0.31)
	if clip.frame != 1:
		push_error("MovieClip repeat delay did not release the next frame.")
		quit(1)
		return
	clip.set_play_settings(0, 1, 1, 0)
	clip._advance_playback_frame()
	if clip.frame != 1 or clip._play_status != 2:
		push_error("MovieClip play settings did not enter its ending state.")
		quit(1)
		return
	clip._advance_playback_frame()
	if clip.frame != 0 or clip._play_status != 3:
		push_error("MovieClip play settings did not stop at the requested end frame.")
		quit(1)
		return

	var animation_clip := FGUIMovieClip.new()
	animation_clip.frames = [
		{"add_delay": 0, "texture": null},
		{"add_delay": 0, "texture": null},
		{"add_delay": 0, "texture": null},
		{"add_delay": 0, "texture": null},
	]
	animation_clip.interval = 0.1
	animation_clip.playing = false
	owner.add_child(animation_clip)
	var animation_seek_transition := FGUITransition.new(owner)
	animation_seek_transition._items = [
		{
			"type": FGUITransition.ACTION_ANIMATION,
			"time": 0.0,
			"target_id": animation_clip.id,
			"target": null,
			"label": "animation_start",
			"value": {"playing": true, "frame": 0},
			"tween_config": null,
			"hook": Callable(),
		},
		{
			"type": FGUITransition.ACTION_ANIMATION,
			"time": 0.35,
			"target_id": animation_clip.id,
			"target": null,
			"label": "animation_stop",
			"value": {"playing": false, "frame": -1},
			"tween_config": null,
			"hook": Callable(),
		},
	]
	animation_seek_transition.play(Callable(), 1, 0.0, 0.5)
	await process_frame
	await process_frame
	if animation_clip.playing or animation_clip.frame != 3:
		push_error("Transition start-time seek did not advance animation actions: playing=%s frame=%s" % [animation_clip.playing, animation_clip.frame])
		quit(1)
		return
	var animation_pause_transition := FGUITransition.new(owner)
	animation_pause_transition._items = [
		{
			"type": FGUITransition.ACTION_ANIMATION,
			"time": 0.0,
			"target_id": animation_clip.id,
			"target": null,
			"label": "animation_pause",
			"value": {"playing": true, "frame": 0},
			"tween_config": null,
			"hook": Callable(),
		},
		_make_alpha_tween_item(0.4),
	]
	animation_clip.playing = false
	animation_pause_transition.play()
	await process_frame
	if not animation_pause_transition.playing or not animation_clip.playing:
		push_error("Transition animation action did not begin playback.")
		quit(1)
		return
	animation_pause_transition.time_scale = 2.5
	if absf(animation_clip.time_scale - 2.5) > 0.01:
		push_error("Transition runtime time_scale did not propagate to animation actions.")
		quit(1)
		return
	animation_pause_transition.set_paused(true)
	if not animation_pause_transition.paused or animation_clip.playing:
		push_error("Transition pause did not suspend animation actions.")
		quit(1)
		return
	animation_pause_transition.set_paused(false)
	if animation_pause_transition.paused or not animation_clip.playing:
		push_error("Transition resume did not restore animation action playback.")
		quit(1)
		return
	animation_pause_transition.stop(false, false)

	transition.dispose()
	repeat_transition.dispose()
	delayed_capture_transition.dispose()
	instant_hook_transition.dispose()
	instant_repeat_transition.dispose()
	instant_infinite_transition.dispose()
	property_transition.dispose()
	yoyo_transition.dispose()
	speed_transition.dispose()
	shake_transition.dispose()
	path_transition.dispose()
	parent_transition.dispose()
	stop_marker_transition.dispose()
	animation_seek_transition.dispose()
	animation_pause_transition.dispose()
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
