class_name FGUIGearAnimation
extends FGUIGearBase

var default_value: Dictionary = {"playing": true, "frame": 0}
var storage: Dictionary = {}


func add_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	var value := {"playing": buffer.read_bool(), "frame": buffer.read_i32()}
	if page_id == null:
		default_value = value
	else:
		storage[page_id] = value


func apply() -> void:
	var value: Dictionary = storage.get(_active_page_id(), default_value)
	owner.set_prop(FGUIEnums.OBJECT_PROP_PLAYING, value["playing"])
	owner.set_prop(FGUIEnums.OBJECT_PROP_FRAME, value["frame"])


func update_state() -> void:
	storage[_active_page_id()] = {
		"playing": bool(owner.get_prop(FGUIEnums.OBJECT_PROP_PLAYING)),
		"frame": int(owner.get_prop(FGUIEnums.OBJECT_PROP_FRAME)),
	}

