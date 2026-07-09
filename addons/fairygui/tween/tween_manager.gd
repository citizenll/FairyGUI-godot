class_name FGUITweenManager
extends RefCounted

static var tweeners: Array = []


static func create_tween() -> FGUIGTweener:
	var tweener := FGUIGTweener.new()
	tweeners.append(tweener)
	return tweener


static func update(delta: float) -> void:
	for i in range(tweeners.size() - 1, -1, -1):
		var tweener: FGUIGTweener = tweeners[i]
		tweener._step(delta)
		if tweener.completed:
			tweeners.remove_at(i)


static func kill_tweens(target: Variant, complete: bool = false) -> void:
	for tweener: FGUIGTweener in tweeners:
		if tweener.target == target:
			tweener.kill(complete)

