class_name FGUIGearColor
extends FGUIGearBase

var default_value: Dictionary = {}
var storage: Dictionary = {}


func init() -> void:
	default_value = {"color": owner.get_prop(FGUIEnums.OBJECT_PROP_COLOR), "outline": owner.get_prop(FGUIEnums.OBJECT_PROP_OUTLINE_COLOR)}


func add_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	var value := {"color": buffer.read_color(), "outline": buffer.read_color()}
	if page_id == null:
		default_value = value
	else:
		storage[page_id] = value


func apply() -> void:
	var value: Dictionary = storage.get(_active_page_id(), default_value)
	owner.set_prop(FGUIEnums.OBJECT_PROP_COLOR, value["color"])
	owner.set_prop(FGUIEnums.OBJECT_PROP_OUTLINE_COLOR, value["outline"])


func update_state() -> void:
	storage[_active_page_id()] = {"color": owner.get_prop(FGUIEnums.OBJECT_PROP_COLOR), "outline": owner.get_prop(FGUIEnums.OBJECT_PROP_OUTLINE_COLOR)}

