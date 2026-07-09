class_name FGUIRelationItem
extends RefCounted

var owner: FGUIObject
var target: FGUIObject
var defs: Array = []


func _init(p_owner: FGUIObject = null) -> void:
	owner = p_owner


func add(relation_type: int, use_percent: bool = false) -> void:
	for def in defs:
		if def["type"] == relation_type:
			def["percent"] = use_percent
			return
	internal_add(relation_type, use_percent)


func internal_add(relation_type: int, use_percent: bool = false) -> void:
	if relation_type == FGUIEnums.RELATION_SIZE:
		internal_add(FGUIEnums.RELATION_WIDTH, use_percent)
		internal_add(FGUIEnums.RELATION_HEIGHT, use_percent)
		return
	defs.append({"type": relation_type, "percent": use_percent})


func remove(relation_type: int = -1) -> void:
	if relation_type == -1:
		defs.clear()
		return
	for i in range(defs.size() - 1, -1, -1):
		if defs[i]["type"] == relation_type:
			defs.remove_at(i)


func apply_on_self_size_changed(delta_width: float, delta_height: float, apply_pivot: bool) -> void:
	if target == null or owner == null:
		return
	for def in defs:
		match def["type"]:
			FGUIEnums.RELATION_CENTER_CENTER:
				owner.x += delta_width * 0.5
			FGUIEnums.RELATION_RIGHT_LEFT, FGUIEnums.RELATION_RIGHT_CENTER, FGUIEnums.RELATION_RIGHT_RIGHT:
				owner.x += delta_width
			FGUIEnums.RELATION_MIDDLE_MIDDLE:
				owner.y += delta_height * 0.5
			FGUIEnums.RELATION_BOTTOM_TOP, FGUIEnums.RELATION_BOTTOM_MIDDLE, FGUIEnums.RELATION_BOTTOM_BOTTOM:
				owner.y += delta_height
			FGUIEnums.RELATION_WIDTH:
				owner.width += delta_width
			FGUIEnums.RELATION_HEIGHT:
				owner.height += delta_height
	if apply_pivot:
		owner.set_xy(owner.x, owner.y)

