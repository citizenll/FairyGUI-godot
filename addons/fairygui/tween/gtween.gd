class_name FGUIGTween
extends RefCounted

static var catch_callback_exceptions: bool = true


static func to(start: float, end: float, duration: float) -> FGUIGTweener:
	return FGUITweenManager.create_tween()._to(start, end, duration)


static func to2(start_x: float, start_y: float, end_x: float, end_y: float, duration: float) -> FGUIGTweener:
	return FGUITweenManager.create_tween()._to2(start_x, start_y, end_x, end_y, duration)


static func to3(start_x: float, start_y: float, start_z: float, end_x: float, end_y: float, end_z: float, duration: float) -> FGUIGTweener:
	return FGUITweenManager.create_tween()._to3(start_x, start_y, start_z, end_x, end_y, end_z, duration)


static func to4(start_x: float, start_y: float, start_z: float, start_w: float, end_x: float, end_y: float, end_z: float, end_w: float, duration: float) -> FGUIGTweener:
	return FGUITweenManager.create_tween()._to4(start_x, start_y, start_z, start_w, end_x, end_y, end_z, end_w, duration)


static func to_color(start: Variant, end: Variant, duration: float) -> FGUIGTweener:
	return FGUITweenManager.create_tween()._to_color(start, end, duration)


static func delayed_call(delay: float) -> FGUIGTweener:
	return FGUITweenManager.create_tween().set_delay(delay)


static func shake(start_x: float, start_y: float, amplitude: float, duration: float) -> FGUIGTweener:
	return FGUITweenManager.create_tween()._shake(start_x, start_y, amplitude, duration)


static func is_tweening(target: Variant, prop_type: Variant = null) -> bool:
	return FGUITweenManager.is_tweening(target, prop_type)


static func kill(target: Variant, complete: bool = false, prop_type: Variant = null) -> bool:
	return FGUITweenManager.kill_tweens(target, complete, prop_type)


static func get_tween(target: Variant, prop_type: Variant = null) -> FGUIGTweener:
	return FGUITweenManager.get_tween(target, prop_type)
