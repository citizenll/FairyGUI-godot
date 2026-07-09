class_name FGUIRelationItem
extends RefCounted

var owner: FGUIObject
var target: FGUIObject:
	get:
		return _target
	set(value):
		if _target == value:
			return
		_release_ref_target()
		_target = value
		_add_ref_target()
var defs: Array = []
var _target: FGUIObject
var _target_x: float = 0.0
var _target_y: float = 0.0
var _target_width: float = 0.0
var _target_height: float = 0.0
var _target_init_x: float = 0.0
var _target_init_y: float = 0.0


func _init(p_owner: FGUIObject = null) -> void:
	owner = p_owner


func add(relation_type: int, use_percent: bool = false) -> void:
	for def in defs:
		if def["type"] == relation_type:
			return
	internal_add(relation_type, use_percent)


func internal_add(relation_type: int, use_percent: bool = false) -> void:
	if relation_type == FGUIEnums.RELATION_SIZE:
		internal_add(FGUIEnums.RELATION_WIDTH, use_percent)
		internal_add(FGUIEnums.RELATION_HEIGHT, use_percent)
		return
	var axis := 0 if relation_type <= FGUIEnums.RELATION_RIGHT_RIGHT or relation_type == FGUIEnums.RELATION_WIDTH or (relation_type >= FGUIEnums.RELATION_LEFT_EXT_LEFT and relation_type <= FGUIEnums.RELATION_RIGHT_EXT_RIGHT) else 1
	defs.append({"type": relation_type, "percent": use_percent, "axis": axis})


func remove(relation_type: int = -1) -> void:
	if relation_type == -1:
		defs.clear()
		return
	if relation_type == FGUIEnums.RELATION_SIZE:
		remove(FGUIEnums.RELATION_WIDTH)
		remove(FGUIEnums.RELATION_HEIGHT)
		return
	for i in range(defs.size() - 1, -1, -1):
		if defs[i]["type"] == relation_type:
			defs.remove_at(i)


func apply_on_self_size_changed(delta_width: float, delta_height: float, apply_pivot: bool) -> void:
	if target == null or owner == null:
		return
	var old_x := owner.x
	var old_y := owner.y
	for def in defs:
		match def["type"]:
			FGUIEnums.RELATION_CENTER_CENTER:
				owner.x -= (0.5 - (owner._pivot.x if apply_pivot else 0.0)) * delta_width
			FGUIEnums.RELATION_RIGHT_LEFT, FGUIEnums.RELATION_RIGHT_CENTER, FGUIEnums.RELATION_RIGHT_RIGHT:
				owner.x -= (1.0 - (owner._pivot.x if apply_pivot else 0.0)) * delta_width
			FGUIEnums.RELATION_MIDDLE_MIDDLE:
				owner.y -= (0.5 - (owner._pivot.y if apply_pivot else 0.0)) * delta_height
			FGUIEnums.RELATION_BOTTOM_TOP, FGUIEnums.RELATION_BOTTOM_MIDDLE, FGUIEnums.RELATION_BOTTOM_BOTTOM:
				owner.y -= (1.0 - (owner._pivot.y if apply_pivot else 0.0)) * delta_height
	if not is_equal_approx(old_x, owner.x) or not is_equal_approx(old_y, owner.y):
		_notify_owner_xy_changed(owner.x - old_x, owner.y - old_y)


func dispose() -> void:
	_release_ref_target()
	_target = null
	defs.clear()


func _apply_on_xy_changed(def: Dictionary, dx: float, dy: float) -> void:
	var tmp: float
	match int(def["type"]):
		FGUIEnums.RELATION_LEFT_LEFT, FGUIEnums.RELATION_LEFT_CENTER, FGUIEnums.RELATION_LEFT_RIGHT, FGUIEnums.RELATION_CENTER_CENTER, FGUIEnums.RELATION_RIGHT_LEFT, FGUIEnums.RELATION_RIGHT_CENTER, FGUIEnums.RELATION_RIGHT_RIGHT:
			owner.x += dx
		FGUIEnums.RELATION_TOP_TOP, FGUIEnums.RELATION_TOP_MIDDLE, FGUIEnums.RELATION_TOP_BOTTOM, FGUIEnums.RELATION_MIDDLE_MIDDLE, FGUIEnums.RELATION_BOTTOM_TOP, FGUIEnums.RELATION_BOTTOM_MIDDLE, FGUIEnums.RELATION_BOTTOM_BOTTOM:
			owner.y += dy
		FGUIEnums.RELATION_LEFT_EXT_LEFT, FGUIEnums.RELATION_LEFT_EXT_RIGHT:
			if owner != target.parent:
				tmp = owner.x_min
				owner.width = owner._raw_width - dx
				owner.x_min = tmp + dx
			else:
				owner.width = owner._raw_width - dx
		FGUIEnums.RELATION_RIGHT_EXT_LEFT, FGUIEnums.RELATION_RIGHT_EXT_RIGHT:
			tmp = owner.x_min
			owner.width = owner._raw_width + dx
			if owner != target.parent:
				owner.x_min = tmp
		FGUIEnums.RELATION_TOP_EXT_TOP, FGUIEnums.RELATION_TOP_EXT_BOTTOM:
			if owner != target.parent:
				tmp = owner.y_min
				owner.height = owner._raw_height - dy
				owner.y_min = tmp + dy
			else:
				owner.height = owner._raw_height - dy
		FGUIEnums.RELATION_BOTTOM_EXT_TOP, FGUIEnums.RELATION_BOTTOM_EXT_BOTTOM:
			tmp = owner.y_min
			owner.height = owner._raw_height + dy
			if owner != target.parent:
				owner.y_min = tmp


func _apply_on_size_changed(def: Dictionary) -> void:
	var pos := 0.0
	var pivot := 0.0
	var delta := 0.0
	var value := 0.0
	var tmp := 0.0
	var percent := bool(def["percent"])
	var axis := int(def["axis"])
	if axis == 0:
		if target != owner.parent:
			pos = target.x
			if target._pivot_as_anchor:
				pivot = target._pivot.x
		delta = (target._width / _target_width) if percent and _target_width != 0.0 else (target._width - _target_width)
	else:
		if target != owner.parent:
			pos = target.y
			if target._pivot_as_anchor:
				pivot = target._pivot.y
		delta = (target._height / _target_height) if percent and _target_height != 0.0 else (target._height - _target_height)

	match int(def["type"]):
		FGUIEnums.RELATION_LEFT_LEFT, FGUIEnums.RELATION_LEFT_CENTER, FGUIEnums.RELATION_LEFT_RIGHT:
			if percent:
				owner.x_min = pos + (owner.x_min - pos) * delta
			else:
				owner.x += delta * (_relation_factor(def["type"]) - pivot)
		FGUIEnums.RELATION_CENTER_CENTER:
			if percent:
				owner.x_min = pos + (owner.x_min + owner._raw_width * 0.5 - pos) * delta - owner._raw_width * 0.5
			else:
				owner.x += delta * (0.5 - pivot)
		FGUIEnums.RELATION_RIGHT_LEFT, FGUIEnums.RELATION_RIGHT_CENTER, FGUIEnums.RELATION_RIGHT_RIGHT:
			if percent:
				owner.x_min = pos + (owner.x_min + owner._raw_width - pos) * delta - owner._raw_width
			else:
				owner.x += delta * (_relation_factor(def["type"]) - pivot)
		FGUIEnums.RELATION_TOP_TOP, FGUIEnums.RELATION_TOP_MIDDLE, FGUIEnums.RELATION_TOP_BOTTOM:
			if percent:
				owner.y_min = pos + (owner.y_min - pos) * delta
			else:
				owner.y += delta * (_relation_factor(def["type"]) - pivot)
		FGUIEnums.RELATION_MIDDLE_MIDDLE:
			if percent:
				owner.y_min = pos + (owner.y_min + owner._raw_height * 0.5 - pos) * delta - owner._raw_height * 0.5
			else:
				owner.y += delta * (0.5 - pivot)
		FGUIEnums.RELATION_BOTTOM_TOP, FGUIEnums.RELATION_BOTTOM_MIDDLE, FGUIEnums.RELATION_BOTTOM_BOTTOM:
			if percent:
				owner.y_min = pos + (owner.y_min + owner._raw_height - pos) * delta - owner._raw_height
			else:
				owner.y += delta * (_relation_factor(def["type"]) - pivot)
		FGUIEnums.RELATION_WIDTH:
			value = owner.source_width - target.init_width if owner == target.parent else owner._raw_width - _target_width
			if percent:
				value *= delta
			if target == owner.parent:
				if owner._pivot_as_anchor:
					tmp = owner.x_min
					owner.set_size(target._width + value, owner._raw_height, true)
					owner.x_min = tmp
				else:
					owner.set_size(target._width + value, owner._raw_height, true)
			else:
				owner.width = target._width + value
		FGUIEnums.RELATION_HEIGHT:
			value = owner.source_height - target.init_height if owner == target.parent else owner._raw_height - _target_height
			if percent:
				value *= delta
			if target == owner.parent:
				if owner._pivot_as_anchor:
					tmp = owner.y_min
					owner.set_size(owner._raw_width, target._height + value, true)
					owner.y_min = tmp
				else:
					owner.set_size(owner._raw_width, target._height + value, true)
			else:
				owner.height = target._height + value
		FGUIEnums.RELATION_LEFT_EXT_LEFT, FGUIEnums.RELATION_LEFT_EXT_RIGHT:
			tmp = owner.x_min
			value = (pos + (tmp - pos) * delta - tmp) if percent else delta * (_relation_factor(def["type"]) - pivot)
			owner.width = owner._raw_width - value
			owner.x_min = tmp + value
		FGUIEnums.RELATION_RIGHT_EXT_LEFT, FGUIEnums.RELATION_RIGHT_EXT_RIGHT:
			tmp = owner.x_min
			if int(def["type"]) == FGUIEnums.RELATION_RIGHT_EXT_RIGHT and owner == target.parent:
				if percent:
					owner.width = pos + target._width - target._width * pivot + (owner.source_width - _target_init_x - target.init_width + target.init_width * pivot) * delta
				else:
					owner.width = owner.source_width + pos - _target_init_x + (target._width - target.init_width) * (1.0 - pivot)
			else:
				value = (pos + (tmp + owner._raw_width - pos) * delta - (tmp + owner._raw_width)) if percent else delta * (_relation_factor(def["type"]) - pivot)
				owner.width = owner._raw_width + value
				owner.x_min = tmp
		FGUIEnums.RELATION_TOP_EXT_TOP, FGUIEnums.RELATION_TOP_EXT_BOTTOM:
			tmp = owner.y_min
			value = (pos + (tmp - pos) * delta - tmp) if percent else delta * (_relation_factor(def["type"]) - pivot)
			owner.height = owner._raw_height - value
			owner.y_min = tmp + value
		FGUIEnums.RELATION_BOTTOM_EXT_TOP, FGUIEnums.RELATION_BOTTOM_EXT_BOTTOM:
			tmp = owner.y_min
			if int(def["type"]) == FGUIEnums.RELATION_BOTTOM_EXT_BOTTOM and owner == target.parent:
				if percent:
					owner.height = pos + target._height - target._height * pivot + (owner.source_height - _target_init_y - target.init_height + target.init_height * pivot) * delta
				else:
					owner.height = owner.source_height + pos - _target_init_y + (target._height - target.init_height) * (1.0 - pivot)
			else:
				value = (pos + (tmp + owner._raw_height - pos) * delta - (tmp + owner._raw_height)) if percent else delta * (_relation_factor(def["type"]) - pivot)
				owner.height = owner._raw_height + value
				owner.y_min = tmp


func _add_ref_target() -> void:
	if target == null:
		return
	if target != owner.parent:
		target.on(FGUIEvents.XY_CHANGED, Callable(self, "_target_xy_changed"))
	target.on(FGUIEvents.SIZE_CHANGED, Callable(self, "_target_size_changed"))
	target.on(FGUIEvents.SIZE_DELAY_CHANGE, Callable(self, "_target_size_will_change"))
	_target_x = target.x
	_target_y = target.y
	_target_init_x = target.x
	_target_init_y = target.y
	_target_width = target._width
	_target_height = target._height


func _release_ref_target() -> void:
	if target == null:
		return
	target.off(FGUIEvents.XY_CHANGED, Callable(self, "_target_xy_changed"))
	target.off(FGUIEvents.SIZE_CHANGED, Callable(self, "_target_size_changed"))
	target.off(FGUIEvents.SIZE_DELAY_CHANGE, Callable(self, "_target_size_will_change"))


func _target_xy_changed() -> void:
	if owner == null or target == null:
		return
	if owner.relations.handling != null or (owner.group != null and owner.group is FGUIGroup and owner.group._updating > 0):
		_target_x = target.x
		_target_y = target.y
		return
	owner.relations.handling = target
	var old_x := owner.x
	var old_y := owner.y
	var dx := target.x - _target_x
	var dy := target.y - _target_y
	for def in defs:
		_apply_on_xy_changed(def, dx, dy)
	_target_x = target.x
	_target_y = target.y
	if not is_equal_approx(old_x, owner.x) or not is_equal_approx(old_y, owner.y):
		_notify_owner_xy_changed(owner.x - old_x, owner.y - old_y)
	owner.relations.handling = null


func _target_size_changed() -> void:
	if owner == null or target == null:
		return
	if owner.relations.size_dirty:
		owner.relations.ensure_relations_size_correct()
	if owner.relations.handling != null:
		_target_width = target._width
		_target_height = target._height
		return
	owner.relations.handling = target
	var old_x := owner.x
	var old_y := owner.y
	var old_w := owner._raw_width
	var old_h := owner._raw_height
	for def in defs:
		_apply_on_size_changed(def)
	_target_width = target._width
	_target_height = target._height
	if not is_equal_approx(old_x, owner.x) or not is_equal_approx(old_y, owner.y):
		_notify_owner_xy_changed(owner.x - old_x, owner.y - old_y)
	if not is_equal_approx(old_w, owner._raw_width) or not is_equal_approx(old_h, owner._raw_height):
		owner.update_gear_from_relations(2, owner._raw_width - old_w, owner._raw_height - old_h)
	owner.relations.handling = null


func _target_size_will_change() -> void:
	if owner != null:
		owner.relations.size_dirty = true


func _notify_owner_xy_changed(dx: float, dy: float) -> void:
	owner.update_gear_from_relations(1, dx, dy)
	if owner.parent != null:
		for transition in owner.parent.transitions:
			transition.update_from_relations(owner.id, dx, dy)


func _relation_factor(relation_type: int) -> float:
	match relation_type:
		FGUIEnums.RELATION_LEFT_CENTER, FGUIEnums.RELATION_CENTER_CENTER, FGUIEnums.RELATION_RIGHT_CENTER, FGUIEnums.RELATION_TOP_MIDDLE, FGUIEnums.RELATION_MIDDLE_MIDDLE, FGUIEnums.RELATION_BOTTOM_MIDDLE:
			return 0.5
		FGUIEnums.RELATION_LEFT_RIGHT, FGUIEnums.RELATION_RIGHT_RIGHT, FGUIEnums.RELATION_TOP_BOTTOM, FGUIEnums.RELATION_BOTTOM_BOTTOM, FGUIEnums.RELATION_LEFT_EXT_RIGHT, FGUIEnums.RELATION_RIGHT_EXT_RIGHT, FGUIEnums.RELATION_TOP_EXT_BOTTOM, FGUIEnums.RELATION_BOTTOM_EXT_BOTTOM:
			return 1.0
		_:
			return 0.0
