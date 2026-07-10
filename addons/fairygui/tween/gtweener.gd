class_name FGUIGTweener
extends RefCounted

var start_value := FGUITweenValue.new()
var end_value := FGUITweenValue.new()
var value := FGUITweenValue.new()
var delta_value := FGUITweenValue.new()

var duration: float = 0.0
var delay: float = 0.0
var ease_type: int = FGUIEaseType.QUAD_OUT
var target: Variant
var prop_type: Variant
var user_data: Variant
var elapsed: float = 0.0
var break_point: float = -1.0
var ease_overshoot_or_amplitude: float = 1.70158
var ease_period: float = 0.0
var repeat: int = 0
var yoyo: bool = false
var time_scale: float = 1.0
var snapping: bool = false
var path: FGUIGPath

var on_start: Callable:
	get:
		return _on_start
	set(callback):
		_on_start = callback
var on_update: Callable:
	get:
		return _on_update
	set(callback):
		_on_update = callback
var on_complete: Callable:
	get:
		return _on_complete
	set(callback):
		_on_complete = callback
var completed: bool:
	get:
		return _ended != 0
var all_completed: bool:
	get:
		return _ended == 1
var normalized_time: float:
	get:
		return _normalized_time
var killed: bool:
	get:
		return _killed

var _value_size: int = 0
var _started: bool = false
var _paused: bool = false
var _killed: bool = false
var _ended: int = 0
var _normalized_time: float = 0.0
var _complete_called: bool = false
var _on_start: Callable
var _on_update: Callable
var _on_complete: Callable


func _init() -> void:
	reset()


func reset() -> void:
	duration = 0.0
	delay = 0.0
	ease_type = FGUIEaseType.QUAD_OUT
	target = null
	prop_type = null
	user_data = null
	elapsed = 0.0
	break_point = -1.0
	ease_overshoot_or_amplitude = 1.70158
	ease_period = 0.0
	repeat = 0
	yoyo = false
	time_scale = 1.0
	snapping = false
	path = null
	_value_size = 0
	_started = false
	_paused = false
	_killed = false
	_ended = 0
	_normalized_time = 0.0
	_complete_called = false
	_on_start = Callable()
	_on_update = Callable()
	_on_complete = Callable()
	start_value.set_zero()
	end_value.set_zero()
	value.set_zero()
	delta_value.set_zero()


func set_delay(value_delay: float) -> FGUIGTweener:
	delay = maxf(0.0, value_delay)
	return self


func set_duration(value_duration: float) -> FGUIGTweener:
	duration = maxf(0.0, value_duration)
	return self


func set_breakpoint(value_breakpoint: float) -> FGUIGTweener:
	break_point = value_breakpoint
	return self


func set_ease(value_ease: int) -> FGUIGTweener:
	ease_type = value_ease
	return self


func set_ease_period(value_period: float) -> FGUIGTweener:
	ease_period = value_period
	return self


func set_ease_overshoot_or_amplitude(value_amplitude: float) -> FGUIGTweener:
	ease_overshoot_or_amplitude = value_amplitude
	return self


func set_repeat(value_repeat: int, value_yoyo: bool = false) -> FGUIGTweener:
	repeat = value_repeat
	yoyo = value_yoyo
	return self


func set_time_scale(value_time_scale: float) -> FGUIGTweener:
	time_scale = maxf(0.0, value_time_scale)
	return self


func set_snapping(value_snapping: bool) -> FGUIGTweener:
	snapping = value_snapping
	return self


func set_target(value_target: Variant, value_prop_type: Variant = null) -> FGUIGTweener:
	target = value_target
	prop_type = value_prop_type
	return self


func set_path(value_path: FGUIGPath) -> FGUIGTweener:
	path = value_path
	return self


func set_user_data(value_user_data: Variant) -> FGUIGTweener:
	user_data = value_user_data
	return self


func set_start_handler(callback: Callable) -> FGUIGTweener:
	_on_start = callback
	return self


func set_update_handler(callback: Callable) -> FGUIGTweener:
	_on_update = callback
	return self


func set_complete_handler(callback: Callable) -> FGUIGTweener:
	_on_complete = callback
	return self


func set_paused(value_paused: bool) -> FGUIGTweener:
	_paused = value_paused
	return self


func seek(time: float) -> void:
	if _killed:
		return
	elapsed = maxf(0.0, time)
	if elapsed < delay:
		if _started:
			elapsed = delay
		else:
			return
	_update_values()


func kill(complete: bool = false) -> void:
	if _killed:
		return
	if complete and _ended == 0:
		if break_point >= 0.0:
			elapsed = delay + break_point
		elif repeat >= 0:
			elapsed = delay + duration * float(repeat + 1)
		else:
			elapsed = delay + duration * 2.0
		_update_values()
		_call_complete()
	_killed = true


func _to(start: float, end: float, value_duration: float) -> FGUIGTweener:
	_value_size = 1
	start_value.set_value(start)
	end_value.set_value(end)
	value.set_value(start)
	duration = maxf(0.0, value_duration)
	return self


func _to2(start_x: float, start_y: float, end_x: float, end_y: float, value_duration: float) -> FGUIGTweener:
	_value_size = 2
	start_value.set_value(start_x, start_y)
	end_value.set_value(end_x, end_y)
	value.set_value(start_x, start_y)
	duration = maxf(0.0, value_duration)
	return self


func _to3(start_x: float, start_y: float, start_z: float, end_x: float, end_y: float, end_z: float, value_duration: float) -> FGUIGTweener:
	_value_size = 3
	start_value.set_value(start_x, start_y, start_z)
	end_value.set_value(end_x, end_y, end_z)
	value.set_value(start_x, start_y, start_z)
	duration = maxf(0.0, value_duration)
	return self


func _to4(start_x: float, start_y: float, start_z: float, start_w: float, end_x: float, end_y: float, end_z: float, end_w: float, value_duration: float) -> FGUIGTweener:
	_value_size = 4
	start_value.set_value(start_x, start_y, start_z, start_w)
	end_value.set_value(end_x, end_y, end_z, end_w)
	value.set_value(start_x, start_y, start_z, start_w)
	duration = maxf(0.0, value_duration)
	return self


func _to_color(start: Variant, end: Variant, value_duration: float) -> FGUIGTweener:
	_value_size = 5
	start_value.set_color(start)
	end_value.set_color(end)
	value.color = start_value.color
	duration = maxf(0.0, value_duration)
	return self


func _shake(start_x: float, start_y: float, amplitude: float, value_duration: float) -> FGUIGTweener:
	_value_size = 6
	start_value.set_value(start_x, start_y, 0.0, amplitude)
	value.set_value(start_x, start_y)
	duration = maxf(0.0, value_duration)
	return self


func _step(delta: float) -> void:
	if _killed or _paused:
		return
	var scaled_delta := delta * time_scale
	if is_zero_approx(scaled_delta):
		return
	if _ended != 0:
		_call_complete()
		_killed = true
		return
	elapsed += scaled_delta
	_update_values()
	if _ended != 0 and not _killed:
		_call_complete()
		_killed = true


func _update_values() -> void:
	_ended = 0
	if _value_size == 0:
		if elapsed >= delay + duration:
			_ended = 1
		return
	if not _started:
		if elapsed < delay:
			return
		_started = true
		_call_start()
		if _killed:
			return

	var tween_time := elapsed - delay
	var reversed_cycle := false
	if break_point >= 0.0 and tween_time >= break_point:
		tween_time = break_point
		_ended = 2
	if duration <= 0.0:
		tween_time = 0.0
		_ended = 1
	elif repeat != 0:
		var round_index := int(floorf(tween_time / duration))
		tween_time -= duration * float(round_index)
		if yoyo:
			reversed_cycle = round_index % 2 == 1
		if repeat > 0 and repeat - round_index < 0:
			if yoyo:
				reversed_cycle = repeat % 2 == 1
			tween_time = duration
			_ended = 1
	elif tween_time >= duration:
		tween_time = duration
		_ended = 1

	_normalized_time = FGUIEaseManager.evaluate(ease_type, duration - tween_time if reversed_cycle else tween_time, duration, ease_overshoot_or_amplitude, ease_period)
	value.set_zero()
	delta_value.set_zero()
	if _value_size == 6:
		if _ended == 0:
			var radius := start_value.w * (1.0 - _normalized_time)
			var offset_x := radius if randf() > 0.5 else -radius
			var offset_y := radius if randf() > 0.5 else -radius
			delta_value.set_value(offset_x, offset_y)
			value.set_value(start_value.x + offset_x, start_value.y + offset_y)
		else:
			value.set_value(start_value.x, start_value.y)
	elif _value_size == 5:
		var next_color := start_value.color.lerp(end_value.color, _normalized_time)
		delta_value.color = next_color - value.color
		value.color = next_color
	elif path != null:
		var point := path.get_point_at(_normalized_time)
		if snapping:
			point = Vector2(roundf(point.x), roundf(point.y))
		delta_value.set_value(point.x - value.x, point.y - value.y)
		value.set_value(point.x, point.y)
	else:
		for index in mini(_value_size, 4):
			var next_value := lerpf(start_value.get_field(index), end_value.get_field(index), _normalized_time)
			if snapping:
				next_value = roundf(next_value)
			delta_value.set_field(index, next_value - value.get_field(index))
			value.set_field(index, next_value)
	_apply_target()
	_call_update()


func _apply_target() -> void:
	if target == null or prop_type == null:
		return
	if prop_type is Callable:
		var callback := prop_type as Callable
		match _value_size:
			1:
				callback.call(value.x)
			2, 6:
				callback.call(value.x, value.y)
			3:
				callback.call(value.x, value.y, value.z)
			4:
				callback.call(value.x, value.y, value.z, value.w)
			5:
				callback.call(value.color)
		return
	var applied_value: Variant = value.color if _value_size == 5 else value.x
	if target is Object:
		(target as Object).set(str(prop_type), applied_value)
	elif target is Dictionary:
		target[prop_type] = applied_value


func _call_start() -> void:
	if _on_start.is_valid():
		_on_start.call(self)


func _call_update() -> void:
	if _on_update.is_valid():
		_on_update.call(self)


func _call_complete() -> void:
	if _complete_called:
		return
	_complete_called = true
	if _on_complete.is_valid():
		_on_complete.call(self)
