class_name FGUIGearXY
extends FGUIGearBase

var default_value: Vector2 = Vector2.ZERO
var storage: Dictionary = {}


func init() -> void:
	default_value = Vector2(owner.x, owner.y)


func add_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	var value := Vector2(buffer.read_i32(), buffer.read_i32())
	if page_id == null:
		default_value = value
	else:
		storage[page_id] = value


func apply() -> void:
	var value: Vector2 = storage.get(_active_page_id(), default_value)
	owner.set_xy(value.x, value.y)


func update_state() -> void:
	storage[_active_page_id()] = Vector2(owner.x, owner.y)

