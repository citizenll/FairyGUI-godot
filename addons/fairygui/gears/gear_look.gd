class_name FGUIGearLook
extends FGUIGearBase

var default_value: Dictionary = {}
var storage: Dictionary = {}


func init() -> void:
	default_value = {"alpha": owner.alpha, "rotation": owner.rotation, "grayed": owner.grayed, "touchable": owner.touchable}
	storage.clear()


func add_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	var value := {
		"alpha": buffer.read_float32(),
		"rotation": buffer.read_float32(),
		"grayed": buffer.read_bool(),
		"touchable": buffer.read_bool(),
	}
	if page_id == null:
		default_value = value
	else:
		storage[page_id] = value


func apply() -> void:
	var value: Dictionary = storage.get(_active_page_id(), default_value)
	if _can_tween():
		owner._gear_locked = true
		owner.grayed = value["grayed"]
		owner.touchable = value["touchable"]
		owner._gear_locked = false
		var target := Vector2(float(value["alpha"]), float(value["rotation"]))
		var active := _active_tweener()
		if active != null:
			if Vector2(active.end_value.x, active.end_value.y).is_equal_approx(target):
				return
			_cancel_tween(true)
		var alpha_changed := not is_equal_approx(owner.alpha, target.x)
		var rotation_changed := not is_equal_approx(owner.rotation, target.y)
		if alpha_changed or rotation_changed:
			var tweener := _start_tween(FGUIGTween.to2(owner.alpha, owner.rotation, target.x, target.y, float(tween_config.get("duration", 0.3))))
			tweener.set_user_data((1 if alpha_changed else 0) | (2 if rotation_changed else 0))
			tweener.set_update_handler(Callable(self, "_on_tween_update"))
			tweener.set_complete_handler(Callable(self, "_on_tween_complete"))
	else:
		_cancel_tween(false)
		owner._gear_locked = true
		owner.alpha = value["alpha"]
		owner.rotation = value["rotation"]
		owner.grayed = value["grayed"]
		owner.touchable = value["touchable"]
		owner._gear_locked = false


func update_state() -> void:
	storage[_active_page_id()] = {"alpha": owner.alpha, "rotation": owner.rotation, "grayed": owner.grayed, "touchable": owner.touchable}


func _on_tween_update(tweener: FGUIGTweener) -> void:
	if owner == null or owner.is_disposed:
		return
	var flags := int(tweener.user_data)
	owner._gear_locked = true
	if (flags & 1) != 0:
		owner.alpha = tweener.value.x
	if (flags & 2) != 0:
		owner.rotation = tweener.value.y
	owner._gear_locked = false


func _on_tween_complete(tweener: FGUIGTweener) -> void:
	_finish_tween(tweener)
