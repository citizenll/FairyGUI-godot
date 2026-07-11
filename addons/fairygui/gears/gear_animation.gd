class_name FGUIGearAnimation
extends FGUIGearBase

var default_value: Dictionary = {"playing": true, "frame": 0}
var storage: Dictionary = {}


func init() -> void:
	default_value = {
		"playing": bool(owner.get_prop(FGUIEnums.OBJECT_PROP_PLAYING)),
		"frame": int(owner.get_prop(FGUIEnums.OBJECT_PROP_FRAME)),
	}
	if owner is FGUILoader3D:
		default_value["animation_name"] = (owner as FGUILoader3D).animation_name
		default_value["skin_name"] = (owner as FGUILoader3D).skin_name
	storage.clear()


func add_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	var value := {"playing": buffer.read_bool(), "frame": buffer.read_i32()}
	if page_id == null:
		default_value = value
	else:
		storage[page_id] = value


func add_ext_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	var value: Dictionary = default_value if page_id == null else storage.get(page_id, {})
	value["animation_name"] = buffer.read_s()
	value["skin_name"] = buffer.read_s()
	if page_id != null:
		storage[page_id] = value


func apply() -> void:
	var value: Dictionary = storage.get(_active_page_id(), default_value)
	owner._gear_locked = true
	owner.set_prop(FGUIEnums.OBJECT_PROP_PLAYING, value["playing"])
	owner.set_prop(FGUIEnums.OBJECT_PROP_FRAME, value["frame"])
	if owner is FGUILoader3D:
		var loader := owner as FGUILoader3D
		if value.get("animation_name") != null:
			loader.animation_name = str(value["animation_name"])
		if value.get("skin_name") != null:
			loader.skin_name = str(value["skin_name"])
	owner._gear_locked = false


func update_state() -> void:
	var value := {
		"playing": bool(owner.get_prop(FGUIEnums.OBJECT_PROP_PLAYING)),
		"frame": int(owner.get_prop(FGUIEnums.OBJECT_PROP_FRAME)),
	}
	if owner is FGUILoader3D:
		value["animation_name"] = (owner as FGUILoader3D).animation_name
		value["skin_name"] = (owner as FGUILoader3D).skin_name
	storage[_active_page_id()] = value
