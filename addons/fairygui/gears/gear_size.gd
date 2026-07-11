class_name FGUIGearSize
extends FGUIGearBase

var default_value: Dictionary = {}
var storage: Dictionary = {}


func init() -> void:
	default_value = {"size": Vector2(owner.width, owner.height), "scale": owner._scale}
	storage.clear()


func add_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	var value := {
		"size": Vector2(buffer.read_i32(), buffer.read_i32()),
		"scale": Vector2(buffer.read_float32(), buffer.read_float32()),
	}
	if page_id == null:
		default_value = value
	else:
		storage[page_id] = value


func apply() -> void:
	var value: Dictionary = storage.get(_active_page_id(), default_value)
	var size: Vector2 = value["size"]
	var scale: Vector2 = value["scale"]
	if _can_tween():
		var active := _active_tweener()
		if active != null:
			var active_end := Vector4(active.end_value.x, active.end_value.y, active.end_value.z, active.end_value.w)
			if active_end.is_equal_approx(Vector4(size.x, size.y, scale.x, scale.y)):
				return
			_cancel_tween(true)
		var size_changed := not Vector2(owner.width, owner.height).is_equal_approx(size)
		var scale_changed := not owner._scale.is_equal_approx(scale)
		if size_changed or scale_changed:
			var tweener := _start_tween(FGUIGTween.to4(
				owner.width, owner.height, owner._scale.x, owner._scale.y,
				size.x, size.y, scale.x, scale.y,
				float(tween_config.get("duration", 0.3))
			))
			tweener.set_user_data((1 if size_changed else 0) | (2 if scale_changed else 0))
			tweener.set_update_handler(Callable(self, "_on_tween_update"))
			tweener.set_complete_handler(Callable(self, "_on_tween_complete"))
	else:
		_cancel_tween(false)
		owner._gear_locked = true
		owner.set_size(size.x, size.y, owner.check_gear_controller(1, controller))
		owner.set_scale(scale.x, scale.y)
		owner._gear_locked = false


func update_state() -> void:
	storage[_active_page_id()] = {"size": Vector2(owner.width, owner.height), "scale": owner._scale}


func update_from_relations(dx: float, dy: float) -> void:
	if controller == null:
		return
	for page_id in storage.keys():
		var value: Dictionary = storage[page_id]
		var size: Vector2 = value["size"]
		value["size"] = Vector2(size.x + dx, size.y + dy)
	default_value["size"] = Vector2(default_value["size"].x + dx, default_value["size"].y + dy)
	update_state()


func _on_tween_update(tweener: FGUIGTweener) -> void:
	if owner == null or owner.is_disposed:
		return
	var flags := int(tweener.user_data)
	owner._gear_locked = true
	if (flags & 1) != 0:
		owner.set_size(tweener.value.x, tweener.value.y, owner.check_gear_controller(1, controller))
	if (flags & 2) != 0:
		owner.set_scale(tweener.value.z, tweener.value.w)
	owner._gear_locked = false


func _on_tween_complete(tweener: FGUIGTweener) -> void:
	_finish_tween(tweener)
