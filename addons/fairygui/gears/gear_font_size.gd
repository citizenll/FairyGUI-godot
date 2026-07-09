class_name FGUIGearFontSize
extends FGUIGearBase

var default_value: int = 0
var storage: Dictionary = {}


func init() -> void:
	default_value = int(owner.get_prop(FGUIEnums.OBJECT_PROP_FONT_SIZE))


func add_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	var value := buffer.read_i32()
	if page_id == null:
		default_value = value
	else:
		storage[page_id] = value


func apply() -> void:
	owner.set_prop(FGUIEnums.OBJECT_PROP_FONT_SIZE, storage.get(_active_page_id(), default_value))


func update_state() -> void:
	storage[_active_page_id()] = int(owner.get_prop(FGUIEnums.OBJECT_PROP_FONT_SIZE))

