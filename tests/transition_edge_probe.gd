extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)

	var offstage_owner := FGUIComponent.new()
	offstage_owner.alpha = 0.0
	var offstage_transition := FGUITransition.new(offstage_owner)
	offstage_transition._items = [_alpha_item("", 0.06, 0.0, 1.0)]
	var offstage_completed := [false]
	offstage_transition.play(func() -> void: offstage_completed[0] = true)
	var offstage_wait := 0.0
	while not offstage_completed[0] and offstage_wait < 0.5:
		await create_timer(0.02).timeout
		offstage_wait += 0.02
	if not offstage_completed[0] or absf(offstage_owner.alpha - 1.0) > 0.05:
		_fail(host, [offstage_transition], [offstage_owner], "Off-stage manual transitions did not complete: completed=%s alpha=%s." % [offstage_completed[0], offstage_owner.alpha])
		return

	var owner := FGUIComponent.new()
	owner.set_xy(10.0, 20.0)
	owner.set_size(200.0, 100.0)
	host.add_child(owner.node)
	var child := FGUIObject.new()
	child.set_size(20.0, 20.0)
	owner.add_child(child)

	var speed_transition := FGUITransition.new(owner)
	speed_transition._items = [_xy_item(child.id, 0.16, Vector2.ZERO, Vector2(100.0, 0.0))]
	var speed_completed := [false]
	speed_transition.play(func() -> void: speed_completed[0] = true)
	await create_timer(0.04).timeout
	speed_transition.time_scale = 0.0
	var frozen_x := child.x
	await create_timer(0.08).timeout
	if absf(child.x - frozen_x) > 0.5 or not speed_transition.playing:
		_fail(host, [offstage_transition, speed_transition], [offstage_owner, owner], "Transition time_scale=0 did not freeze active tweens.")
		return
	speed_transition.time_scale = 3.0
	var wait_time := 0.0
	while not speed_completed[0] and wait_time < 0.5:
		await create_timer(0.02).timeout
		wait_time += 0.02
	if not speed_completed[0] or absf(child.x - 100.0) > 0.5:
		_fail(host, [offstage_transition, speed_transition], [offstage_owner, owner], "A transition did not resume after restoring a zero time scale.")
		return

	var owner_percent_transition := FGUITransition.new(owner)
	owner_percent_transition._items = [_xy_item("", 0.02, Vector2(0.1, 0.2), Vector2(0.2, 0.3), true)]
	owner_percent_transition.play()
	await create_timer(0.06).timeout
	if absf(owner.x - 10.2) > 0.05 or absf(owner.y - 20.3) > 0.05:
		_fail(host, [offstage_transition, speed_transition, owner_percent_transition], [offstage_owner, owner], "Owner-relative XY values were incorrectly treated as child percentages: %s,%s" % [owner.x, owner.y])
		return

	child.blend_mode = FGUIEnums.BLEND_MULTIPLY
	var filter_transition := FGUITransition.new(owner)
	filter_transition._items = [_filter_item(child.id, 0.08, Vector4(0.4, 0.2, -0.2, 0.1), Vector4.ZERO)]
	var filter_completed := [false]
	filter_transition.play(func() -> void: filter_completed[0] = true)
	await create_timer(0.04).timeout
	if not child.node.has_meta("_fgui_filter_values"):
		_fail(host, [offstage_transition, speed_transition, owner_percent_transition, filter_transition], [offstage_owner, owner], "Transition color filters were not applied during tweening.")
		return
	await create_timer(0.08).timeout
	var restored_material := child.node.material as ShaderMaterial
	if not filter_completed[0] or child.node.has_meta("_fgui_filter_values") or restored_material == null or restored_material.shader.code.find("render_mode blend_mul;") == -1:
		_fail(host, [offstage_transition, speed_transition, owner_percent_transition, filter_transition], [offstage_owner, owner], "A zero color-filter endpoint did not restore the target blend material.")
		return

	var clipped_end_hooks := [0]
	var clipped_item := _alpha_item(child.id, 0.04, 0.0, 1.0, 2, true)
	clipped_item["tween_config"]["end_hook"] = func() -> void: clipped_end_hooks[0] += 1
	var clipped_transition := FGUITransition.new(owner)
	clipped_transition._items = [clipped_item]
	child.alpha = 0.0
	var clipped_completed := [false]
	clipped_transition.play(func() -> void: clipped_completed[0] = true, 1, 0.0, 0.0, 0.06)
	await create_timer(0.12).timeout
	if not clipped_completed[0] or absf(child.alpha - 0.5) > 0.12 or clipped_end_hooks[0] != 0:
		_fail(host, [offstage_transition, speed_transition, owner_percent_transition, filter_transition, clipped_transition], [offstage_owner, owner], "Repeated yoyo playback did not stop at its exact end-time breakpoint: %s" % child.alpha)
		return
	var infinite_item := _alpha_item(child.id, 0.04, 0.0, 1.0, -1, false)
	var infinite_transition := FGUITransition.new(owner)
	infinite_transition._items = [infinite_item]
	child.alpha = 0.0
	var infinite_completed := [false]
	infinite_transition.play(func() -> void: infinite_completed[0] = true, 1, 0.0, 0.0, 0.1)
	await create_timer(0.16).timeout
	if not infinite_completed[0] or absf(child.alpha - 0.5) > 0.15:
		_fail(host, [offstage_transition, speed_transition, owner_percent_transition, filter_transition, clipped_transition, infinite_transition], [offstage_owner, owner], "An infinite item tween did not honor a finite transition end time: %s" % child.alpha)
		return

	var clip := FGUIMovieClip.new()
	clip.frames = [{"add_delay": 0, "texture": null}, {"add_delay": 0, "texture": null}, {"add_delay": 0, "texture": null}]
	clip.interval = 0.08
	owner.add_child(clip)
	clip.frame = 0
	clip.time_scale = 0.0
	await create_timer(0.08).timeout
	if clip.frame != 0:
		_fail(host, [offstage_transition, speed_transition, owner_percent_transition, filter_transition, clipped_transition, infinite_transition], [offstage_owner, owner], "MovieClip time_scale=0 did not freeze frame playback.")
		return
	clip.time_scale = 1.0
	var frame_wait := 0.0
	while clip.frame == 0 and frame_wait < 0.3:
		await create_timer(0.03).timeout
		frame_wait += 0.03
	if clip.frame == 0:
		_fail(host, [offstage_transition, speed_transition, owner_percent_transition, filter_transition, clipped_transition, infinite_transition], [offstage_owner, owner], "MovieClip playback did not resume after a zero time scale.")
		return
	var pause_transition := FGUITransition.new(owner)
	pause_transition._items = [
		_animation_item(clip.id, 0.0, true),
		_animation_item(clip.id, 0.0, true),
		_alpha_item(child.id, 0.2, 0.0, 1.0),
	]
	pause_transition.play()
	await create_timer(0.03).timeout
	pause_transition.set_paused(true)
	if clip.playing:
		_fail(host, [offstage_transition, speed_transition, owner_percent_transition, filter_transition, clipped_transition, infinite_transition, pause_transition], [offstage_owner, owner], "Pausing a transition did not pause its animation target.")
		return
	pause_transition.set_paused(false)
	if not clip.playing:
		_fail(host, [offstage_transition, speed_transition, owner_percent_transition, filter_transition, clipped_transition, infinite_transition, pause_transition], [offstage_owner, owner], "Multiple animation items corrupted the paused playback state.")
		return
	pause_transition.set_paused(true)
	pause_transition.stop(false, false)
	if not clip.playing:
		_fail(host, [offstage_transition, speed_transition, owner_percent_transition, filter_transition, clipped_transition, infinite_transition, pause_transition], [offstage_owner, owner], "Stopping a paused transition did not restore animation playback.")
		return

	var reverse_transition := FGUITransition.new(owner)
	var reverse_end_hooks := [0]
	var reverse_item := _alpha_item(child.id, 0.04, 0.0, 1.0)
	reverse_item["tween_config"]["end_hook"] = func() -> void: reverse_end_hooks[0] += 1
	reverse_transition._items = [reverse_item]
	reverse_transition._total_duration = 0.04
	child.alpha = 1.0
	var reverse_completed := [false]
	reverse_transition.play_reverse(func() -> void: reverse_completed[0] = true, 2)
	await create_timer(0.14).timeout
	if not reverse_completed[0] or absf(child.alpha) > 0.05 or reverse_end_hooks[0] != 2:
		_fail(host, [offstage_transition, speed_transition, owner_percent_transition, filter_transition, clipped_transition, infinite_transition, pause_transition, reverse_transition], [offstage_owner, owner], "Reverse playback did not honor repeat count and end hooks.")
		return

	for transition in [offstage_transition, speed_transition, owner_percent_transition, filter_transition, clipped_transition, infinite_transition, pause_transition, reverse_transition]:
		transition.dispose()
	offstage_owner.dispose()
	owner.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _xy_item(target_id: String, duration: float, start: Vector2, finish: Vector2, percent: bool = false) -> Dictionary:
	return {
		"type": FGUITransition.ACTION_XY,
		"time": 0.0,
		"target_id": target_id,
		"target": null,
		"label": "xy",
		"value": {},
		"tween_config": _tween_config(duration, {"b1": true, "b2": true, "b3": percent, "f1": start.x, "f2": start.y}, {"b1": true, "b2": true, "b3": percent, "f1": finish.x, "f2": finish.y}),
		"hook": Callable(),
	}


func _alpha_item(target_id: String, duration: float, start: float, finish: float, repeat: int = 0, yoyo: bool = false) -> Dictionary:
	var config := _tween_config(duration, {"f1": start}, {"f1": finish})
	config["repeat"] = repeat
	config["yoyo"] = yoyo
	return {
		"type": FGUITransition.ACTION_ALPHA,
		"time": 0.0,
		"target_id": target_id,
		"target": null,
		"label": "alpha",
		"value": {},
		"tween_config": config,
		"hook": Callable(),
	}


func _filter_item(target_id: String, duration: float, start: Vector4, finish: Vector4) -> Dictionary:
	return {
		"type": FGUITransition.ACTION_COLOR_FILTER,
		"time": 0.0,
		"target_id": target_id,
		"target": null,
		"label": "filter",
		"value": {},
		"tween_config": _tween_config(duration, _vector4_value(start), _vector4_value(finish)),
		"hook": Callable(),
	}


func _animation_item(target_id: String, time: float, playing: bool) -> Dictionary:
	return {
		"type": FGUITransition.ACTION_ANIMATION,
		"time": time,
		"target_id": target_id,
		"target": null,
		"label": "animation",
		"value": {"playing": playing, "frame": -1},
		"tween_config": null,
		"hook": Callable(),
	}


func _tween_config(duration: float, start: Dictionary, finish: Dictionary) -> Dictionary:
	return {
		"duration": duration,
		"ease_type": FGUIEaseType.LINEAR,
		"repeat": 0,
		"yoyo": false,
		"end_label": "end",
		"start_value": start,
		"end_value": finish,
		"end_hook": Callable(),
		"path": null,
		"custom_ease": null,
	}


func _vector4_value(value: Vector4) -> Dictionary:
	return {"f1": value.x, "f2": value.y, "f3": value.z, "f4": value.w}


func _fail(host: Control, transitions: Array, owners: Array, message: String) -> void:
	push_error(message)
	for transition in transitions:
		if transition != null:
			transition.dispose()
	for owner in owners:
		if owner != null and not owner.is_disposed:
			owner.dispose()
	if host != null:
		host.queue_free()
	quit(1)
