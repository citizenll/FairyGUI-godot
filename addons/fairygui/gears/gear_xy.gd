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
	owner.set_xy(value.x, value.y)


func update_state() -> void:
	storage[_active_page_id()] = {"pos": Vector2(owner.x, owner.y), "percent": _current_percent()}


func update_from_relations(dx: float, dy: float) -> void:
	if positions_in_percent:
		return
	for page_id in storage.keys():
		var entry: Dictionary = storage[page_id]
		var value: Vector2 = entry.get("pos", Vector2.ZERO)
		entry["pos"] = Vector2(value.x + dx, value.y + dy)
	var default_pos: Vector2 = default_value.get("pos", Vector2.ZERO)
	default_value["pos"] = default_pos + Vector2(dx, dy)


func _current_percent() -> Vector2:
	if owner.parent == null:
		return Vector2.ZERO
	return Vector2(
		owner.x / maxf(owner.parent.width, 0.0001),
		owner.y / maxf(owner.parent.height, 0.0001)
	)
