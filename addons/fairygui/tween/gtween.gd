class_name FGUIGTween
extends RefCounted


static func to(start: float, end: float, duration: float) -> FGUIGTweener:
	var tweener := FGUITweenManager.create_tween()
	tweener.start_value.set_value(start)
	tweener.end_value.set_value(end)
	tweener.duration = duration
	return tweener


static func to2(start_x: float, start_y: float, end_x: float, end_y: float, duration: float) -> FGUIGTweener:
	var tweener := FGUITweenManager.create_tween()
	tweener.start_value.set_value(start_x, start_y)
	tweener.end_value.set_value(end_x, end_y)
	tweener.duration = duration
	return tweener


static func delayed_call(delay: float) -> FGUIGTweener:
	var tweener := FGUITweenManager.create_tween()
	tweener.duration = 0.0
	tweener.delay = delay
	return tweener


static func kill(target: Variant, complete: bool = false) -> void:
	FGUITweenManager.kill_tweens(target, complete)

