class_name FGUIGearSize
extends FGUIGearBase

var default_value: Dictionary = {}
var storage: Dictionary = {}


func init() -> void:
	default_value = {"size": Vector2(owner.width, owner.height), "scale": owner._scale}


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
	owner.set_size(size.x, size.y)
	owner.set_scale(scale.x, scale.y)


func update_state() -> void:
	storage[_active_page_id()] = {"size": Vector2(owner.width, owner.height), "scale": owner._scale}

