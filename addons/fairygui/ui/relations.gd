class_name FGUIRelations
extends RefCounted

var owner: FGUIObject
var items: Array = []
var handling: Variant = null
var size_dirty: bool = false


func _init(p_owner: FGUIObject = null) -> void:
	owner = p_owner


func add(target: FGUIObject, relation_type: int, use_percent: bool = false) -> void:
	if target == null:
		return
	var item := _get_item(target)
	if item == null:
		item = FGUIRelationItem.new(owner)
		item.target = target
		items.append(item)
	item.add(relation_type, use_percent)


func remove(target: FGUIObject, relation_type: int = -1) -> void:
	var item := _get_item(target)
	if item == null:
		return
	item.remove(relation_type)
	if item.defs.is_empty():
		items.erase(item)


func clear_for(target: FGUIObject) -> void:
	var item := _get_item(target)
	if item != null:
		items.erase(item)


func contains(target: FGUIObject) -> bool:
	return _get_item(target) != null


func dispose() -> void:
	items.clear()


func on_owner_size_changed(delta_width: float, delta_height: float, apply_pivot: bool) -> void:
	for item in items:
		item.apply_on_self_size_changed(delta_width, delta_height, apply_pivot)


func ensure_relations_size_correct() -> void:
	size_dirty = false
	for item in items:
		if item.target is FGUIComponent:
			item.target.ensure_bounds_correct()


func setup(buffer: FGUIByteBuffer, parent_to_child: bool) -> void:
	var count := buffer.read_i16()
	var target: FGUIObject = null
	for i in count:
		var target_index := buffer.read_i16()
		if target_index == -1:
			target = owner.parent if parent_to_child else owner
		elif owner is FGUIComponent:
			target = owner.get_child_at(target_index)
		if target == null:
			continue
		var item := FGUIRelationItem.new(owner)
		item.target = target
		items.append(item)
		item.internal_add(buffer.read_i8(), buffer.read_bool())


func _get_item(target: FGUIObject) -> FGUIRelationItem:
	for item in items:
		if item.target == target:
			return item
	return null

