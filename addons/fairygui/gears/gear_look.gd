class_name FGUIGearLook
extends FGUIGearBase

var default_value: Dictionary = {}
var storage: Dictionary = {}


func init() -> void:
	default_value = {"alpha": owner.alpha, "rotation": owner.rotation, "grayed": owner.grayed, "touchable": owner.touchable}


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
	owner.alpha = value["alpha"]
	owner.rotation = value["rotation"]
	owner.grayed = value["grayed"]
	owner.touchable = value["touchable"]


func update_state() -> void:
	storage[_active_page_id()] = {"alpha": owner.alpha, "rotation": owner.rotation, "grayed": owner.grayed, "touchable": owner.touchable}

