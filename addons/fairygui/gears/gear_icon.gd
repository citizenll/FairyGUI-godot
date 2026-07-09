class_name FGUIGearIcon
extends FGUIGearText


func init() -> void:
	default_value = owner.get_icon()


func apply() -> void:
	owner.set_icon(storage.get(_active_page_id(), default_value))


func update_state() -> void:
	storage[_active_page_id()] = owner.get_icon()

