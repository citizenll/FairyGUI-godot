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
		item.dispose()
		items.erase(item)


func clear_for(target: FGUIObject) -> void:
	var item := _get_item(target)
	if item != null:
		item.dispose()
		items.erase(item)


func contains(target: FGUIObject) -> bool:
	return _get_item(target) != null


func dispose() -> void:
	for item in items:
		item.dispose()
	items.clear()
	handling = null
	owner = null


func on_owner_size_changed(delta_width: float, delta_height: float, apply_pivot: bool) -> void:
	for item in items:
		item.apply_on_self_size_changed(delta_width, delta_height, apply_pivot)


func ensure_relations_size_correct() -> void:
	size_dirty = false
	for item in items:
		item.target.ensure_size_correct()


func setup(buffer: FGUIByteBuffer, parent_to_child: bool) -> void:
	var count := buffer.read_u8()
	var target: FGUIObject = null
	for i in count:
		var target_index := buffer.read_i16()
		if target_index == -1:
			target = owner.parent
		elif parent_to_child and owner is FGUIComponent:
			target = owner.get_child_at(target_index)
		elif owner.parent != null:
			target = owner.parent.get_child_at(target_index)
		var relation_count := buffer.read_u8()
		var item: FGUIRelationItem = null
		if target != null:
			item = FGUIRelationItem.new(owner)
			item.target = target
			items.append(item)
		for j in relation_count:
			var relation_type := buffer.read_u8()
			var use_percent := buffer.read_bool()
			if item != null:
				item.internal_add(relation_type, use_percent)


func _get_item(target: FGUIObject) -> FGUIRelationItem:
	for item in items:
		if item.target == target:
			return item
	return null
