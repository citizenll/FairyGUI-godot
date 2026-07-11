class_name FGUIGearXY
extends FGUIGearBase

var positions_in_percent: bool = false
var default_value: Dictionary = {}
var storage: Dictionary = {}


func init() -> void:
	default_value = {
		"pos": Vector2(owner.x, owner.y),
		"percent": _current_percent()
	}
	storage.clear()


func add_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	var value := Vector2(buffer.read_i32(), buffer.read_i32())
	if page_id == null:
		default_value["pos"] = value
	else:
		var entry: Dictionary = storage.get(page_id, {})
		entry["pos"] = value
		if not entry.has("percent"):
			entry["percent"] = Vector2.ZERO
		storage[page_id] = entry


func add_ext_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	var value := Vector2(buffer.read_float32(), buffer.read_float32())
	if page_id == null:
		default_value["percent"] = value
	else:
		var entry: Dictionary = storage.get(page_id, {})
		entry["percent"] = value
		if not entry.has("pos"):
			entry["pos"] = default_value.get("pos", Vector2.ZERO)
		storage[page_id] = entry


func apply() -> void:
	var entry: Dictionary = storage.get(_active_page_id(), default_value)
	var value: Vector2
	if positions_in_percent and owner.parent != null:
		var percent: Vector2 = entry.get("percent", Vector2.ZERO)
		value = Vector2(percent.x * owner.parent.width, percent.y * owner.parent.height)
	else:
		value = entry.get("pos", Vector2.ZERO)
	if _can_tween():
		var active := _active_tweener()
		if active != null:
			if Vector2(active.end_value.x, active.end_value.y).is_equal_approx(value):
				return
			_cancel_tween(true)
		var origin := Vector2(owner.x, owner.y)
		if not origin.is_equal_approx(value):
			var tweener := _start_tween(FGUIGTween.to2(origin.x, origin.y, value.x, value.y, float(tween_config.get("duration", 0.3))))
			tweener.set_update_handler(Callable(self, "_on_tween_update"))
			tweener.set_complete_handler(Callable(self, "_on_tween_complete"))
	else:
		_cancel_tween(false)
		owner._gear_locked = true
		owner.set_xy(value.x, value.y)
		owner._gear_locked = false


func update_state() -> void:
	storage[_active_page_id()] = {"pos": Vector2(owner.x, owner.y), "percent": _current_percent()}


func update_from_relations(dx: float, dy: float) -> void:
	if controller == null or positions_in_percent:
		return
	for page_id in storage.keys():
		var entry: Dictionary = storage[page_id]
		var value: Vector2 = entry.get("pos", Vector2.ZERO)
		entry["pos"] = Vector2(value.x + dx, value.y + dy)
	var default_pos: Vector2 = default_value.get("pos", Vector2.ZERO)
	default_value["pos"] = default_pos + Vector2(dx, dy)
	update_state()


func _on_tween_update(tweener: FGUIGTweener) -> void:
	if owner == null or owner.is_disposed:
		return
	owner._gear_locked = true
	owner.set_xy(tweener.value.x, tweener.value.y)
	owner._gear_locked = false


func _on_tween_complete(tweener: FGUIGTweener) -> void:
	_finish_tween(tweener)


func _current_percent() -> Vector2:
	if owner.parent == null:
		return Vector2.ZERO
	return Vector2(
		owner.x / maxf(owner.parent.width, 0.0001),
		owner.y / maxf(owner.parent.height, 0.0001)
	)
