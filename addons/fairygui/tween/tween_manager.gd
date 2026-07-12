class_name FGUITweenManager
extends RefCounted

const TweenDriver := preload("res://addons/fairygui/tween/tween_driver.gd")

static var tweeners: Array[FGUIGTweener] = []
static var _driver: Node


static func create_tween() -> FGUIGTweener:
	_ensure_driver()
	var tweener := FGUIGTweener.new()
	tweeners.append(tweener)
	return tweener


static func update(delta: float) -> void:
	for index in range(tweeners.size() - 1, -1, -1):
		var tweener := tweeners[index]
		if tweener == null:
			tweeners.remove_at(index)
			continue
		if tweener.target is FGUIObject and (tweener.target as FGUIObject).is_disposed:
			tweener.kill(false)
		tweener._step(delta)
		if tweener.killed:
			tweeners.remove_at(index)


static func is_tweening(target: Variant, prop_type: Variant = null) -> bool:
	return get_tween(target, prop_type) != null


static func get_tween(target: Variant, prop_type: Variant = null) -> FGUIGTweener:
	if target == null:
		return null
	for tweener in tweeners:
		if tweener != null and not tweener.killed and tweener.target == target and _property_matches(tweener.prop_type, prop_type):
			return tweener
	return null


static func kill_tweens(target: Variant, complete: bool = false, prop_type: Variant = null) -> bool:
	if target == null:
		return false
	var found := false
	for tweener in tweeners:
		if tweener != null and not tweener.killed and tweener.target == target and _property_matches(tweener.prop_type, prop_type):
			tweener.kill(complete)
			found = true
	return found


static func _property_matches(actual: Variant, requested: Variant) -> bool:
	if requested == null:
		return true
	if typeof(actual) != typeof(requested):
		return false
	return actual == requested


static func _ensure_driver() -> void:
	if _driver != null and is_instance_valid(_driver) and _driver.is_inside_tree():
		return
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return
	var tree := main_loop as SceneTree
	if tree.root == null:
		return
	var driver: Node = TweenDriver.new()
	tree.root.add_child(driver)
	_driver = driver
