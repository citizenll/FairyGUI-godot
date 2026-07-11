class_name FGUIGearIcon
extends FGUIGearText


func init() -> void:
	default_value = owner.get_icon()
	storage.clear()


func apply() -> void:
	owner._gear_locked = true
	owner.set_icon(storage.get(_active_page_id(), default_value))
	owner._gear_locked = false


func update_state() -> void:
	storage[_active_page_id()] = owner.get_icon()
