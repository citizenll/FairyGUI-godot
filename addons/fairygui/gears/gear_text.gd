class_name FGUIGearText
extends FGUIGearBase

var default_value: String = ""
var storage: Dictionary = {}


func init() -> void:
	default_value = owner.get_text()
	storage.clear()


func add_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	var value := str(buffer.read_s())
	if page_id == null:
		default_value = value
	else:
		storage[page_id] = value


func apply() -> void:
	owner._gear_locked = true
	owner.set_text(storage.get(_active_page_id(), default_value))
	owner._gear_locked = false


func update_state() -> void:
	storage[_active_page_id()] = owner.get_text()
