extends SceneTree


class TweenTarget extends RefCounted:
	var value: float = 0.0
	var vector := Vector2.ZERO
	var color: Color = Color.WHITE


func _initialize() -> void:
	var target := TweenTarget.new()
	var completion := {"value": false}
	var update_count := {"value": 0}
	FGUIGTween.to(0.0, 100.0, 0.05).set_target(target, "value").set_update_handler(func(_tween: FGUIGTweener) -> void: update_count["value"] += 1).set_complete_handler(func(_tween: FGUIGTweener) -> void: completion["value"] = true)
	await create_timer(0.12).timeout
	if absf(target.value - 100.0) > 0.1 or not completion["value"] or update_count["value"] == 0 or FGUIGTween.is_tweening(target, "value"):
		_fail("Automatic scalar GTween progression did not update its target and completion state.")
		return

	var vector_tween := FGUIGTween.to2(0.0, 0.0, 10.0, 20.0, 0.04).set_target(target, func(x: float, y: float) -> void: target.vector = Vector2(x, y))
	await create_timer(0.1).timeout
	if not target.vector.is_equal_approx(Vector2(10.0, 20.0)) or not vector_tween.all_completed:
		_fail("Vector GTween callback target did not receive both values.")
		return
	var vector3_capture := {"value": Vector3.ZERO}
	FGUIGTween.to3(0.0, 0.0, 0.0, 3.0, 4.0, 5.0, 0.04).set_target(target, func(x: float, y: float, z: float) -> void: vector3_capture["value"] = Vector3(x, y, z))
	var vector4_capture := {"value": Vector4.ZERO}
	FGUIGTween.to4(0.0, 0.0, 0.0, 0.0, 1.0, 2.0, 3.0, 4.0, 0.04).set_target(target, func(x: float, y: float, z: float, w: float) -> void: vector4_capture["value"] = Vector4(x, y, z, w))
	FGUIGTween.to_color(Color.RED, Color.BLUE, 0.04).set_target(target, "color")
	await create_timer(0.1).timeout
	if not (vector3_capture["value"] as Vector3).is_equal_approx(Vector3(3.0, 4.0, 5.0)) or not (vector4_capture["value"] as Vector4).is_equal_approx(Vector4(1.0, 2.0, 3.0, 4.0)) or not target.color.is_equal_approx(Color.BLUE):
		_fail("Multi-value or color GTween did not reach its requested endpoint.")
		return
	var path := FGUIGPath.new()
	path.create([
		FGUIGPathPoint.new_point(0.0, 0.0, FGUIGPath.CURVE_STRAIGHT),
		FGUIGPathPoint.new_point(20.0, 10.0, FGUIGPath.CURVE_STRAIGHT),
	])
	FGUIGTween.to2(0.0, 0.0, 0.0, 0.0, 0.04).set_path(path).set_target(target, func(x: float, y: float) -> void: target.vector = Vector2(x, y))
	await create_timer(0.1).timeout
	if not target.vector.is_equal_approx(Vector2(20.0, 10.0)):
		_fail("Path GTween did not use its path endpoint.")
		return

	var repeat_tween := FGUIGTween.to(0.0, 1.0, 0.03).set_repeat(1, true).set_target(target, "value")
	await create_timer(0.12).timeout
	if absf(target.value) > 0.1 or not repeat_tween.all_completed:
		_fail("Yoyo repeat did not return to the start value.")
		return

	var delayed := {"value": false}
	FGUIGTween.delayed_call(0.05).set_complete_handler(func(_tween: FGUIGTweener) -> void: delayed["value"] = true)
	await create_timer(0.02).timeout
	if delayed["value"]:
		_fail("Delayed GTween callback fired before its delay elapsed.")
		return
	await create_timer(0.08).timeout
	if not delayed["value"]:
		_fail("Delayed GTween callback did not fire.")
		return

	var paused := FGUIGTween.to(0.0, 10.0, 0.05).set_target(target, "value").set_paused(true)
	await create_timer(0.07).timeout
	if absf(target.value) > 0.1:
		_fail("Paused GTween advanced while paused.")
		return
	paused.set_paused(false)
	await create_timer(0.08).timeout
	if absf(target.value - 10.0) > 0.1:
		_fail("Paused GTween did not resume.")
		return

	var snapped_values := {"rounded": true}
	FGUIGTween.to(0.0, 9.0, 0.06).set_snapping(true).set_update_handler(func(tween: FGUIGTweener) -> void:
		if not is_equal_approx(tween.value.x, roundf(tween.value.x)):
			snapped_values["rounded"] = false
	)
	await create_timer(0.12).timeout
	if not snapped_values["rounded"]:
		_fail("Snapping GTween produced a fractional update value.")
		return

	var shake_capture := {"value": Vector2.ZERO}
	FGUIGTween.shake(5.0, 7.0, 3.0, 0.05).set_update_handler(func(tween: FGUIGTweener) -> void: shake_capture["value"] = Vector2(tween.value.x, tween.value.y))
	await create_timer(0.1).timeout
	var shake_final: Vector2 = shake_capture["value"]
	if not shake_final.is_equal_approx(Vector2(5.0, 7.0)):
		_fail("Shake GTween did not settle at its start position.")
		return

	var killed := FGUIGTween.to(0.0, 100.0, 1.0).set_target(target, "value")
	if not FGUIGTween.is_tweening(target, "value") or FGUIGTween.get_tween(target, "value") != killed:
		_fail("GTween target lookup did not find an active tween.")
		return
	if not FGUIGTween.kill(target, false, "value"):
		_fail("GTween target kill did not report the active tween.")
		return
	await process_frame
	if FGUIGTween.is_tweening(target, "value"):
		_fail("GTween target kill did not remove the tween.")
		return

	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
