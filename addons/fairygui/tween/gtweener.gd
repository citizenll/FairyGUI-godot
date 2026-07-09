class_name FGUIGTweener
extends RefCounted

var start_value := FGUITweenValue.new()
var end_value := FGUITweenValue.new()
var value := FGUITweenValue.new()
var duration: float = 0.0
var delay: float = 0.0
var ease_type: int = FGUIEaseType.QUAD_OUT
var target: Variant
var user_data: Variant
var completed: bool = false
var elapsed: float = 0.0
var on_update: Callable
var on_complete: Callable


func set_delay(value_delay: float) -> FGUIGTweener:
	delay = value_delay
	return self


func set_ease(value_ease: int) -> FGUIGTweener:
	ease_type = value_ease
	return self


func set_target(value_target: Variant) -> FGUIGTweener:
	target = value_target
	return self


func set_user_data(value_user_data: Variant) -> FGUIGTweener:
	user_data = value_user_data
	return self


func set_update_handler(callable: Callable) -> FGUIGTweener:
	on_update = callable
	return self


func set_complete_handler(callable: Callable) -> FGUIGTweener:
	on_complete = callable
	return self


func kill(complete: bool = false) -> void:
	if complete:
		_update(duration)
	completed = true


func _step(delta: float) -> void:
	if completed:
		return
	elapsed += delta
	if elapsed < delay:
		return
	_update(minf(elapsed - delay, duration))
	if elapsed - delay >= duration:
		completed = true
		if on_complete.is_valid():
			on_complete.call(self)


func _update(time: float) -> void:
	var ratio := FGUIEaseManager.evaluate(ease_type, time, duration)
	value.x = lerpf(start_value.x, end_value.x, ratio)
	value.y = lerpf(start_value.y, end_value.y, ratio)
	value.z = lerpf(start_value.z, end_value.z, ratio)
	value.w = lerpf(start_value.w, end_value.w, ratio)
	if on_update.is_valid():
		on_update.call(self)

