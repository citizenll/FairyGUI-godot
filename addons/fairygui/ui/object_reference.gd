@tool
class_name FGUIObjectRef
extends Resource

var _package_id: String = ""
var _package_name: String = ""
var _component_id: String = ""
var _component_name: String = ""
var _child_ids := PackedStringArray()
var _child_names := PackedStringArray()

@export_storage var package_id: String:
	get:
		return _package_id
	set(value):
		if _package_id == value:
			return
		_package_id = value
		emit_changed()

@export_storage var package_name: String:
	get:
		return _package_name
	set(value):
		if _package_name == value:
			return
		_package_name = value
		emit_changed()

@export_storage var component_id: String:
	get:
		return _component_id
	set(value):
		if _component_id == value:
			return
		_component_id = value
		emit_changed()

@export_storage var component_name: String:
	get:
		return _component_name
	set(value):
		if _component_name == value:
			return
		_component_name = value
		emit_changed()

@export_storage var child_ids: PackedStringArray:
	get:
		return _child_ids
	set(value):
		if _child_ids == value:
			return
		_child_ids = value.duplicate()
		emit_changed()

@export_storage var child_names: PackedStringArray:
	get:
		return _child_names
	set(value):
		if _child_names == value:
			return
		_child_names = value.duplicate()
		emit_changed()


func _init() -> void:
	resource_local_to_scene = true


static func from_object(root: FGUIObject, target: FGUIObject) -> Resource:
	if not is_persistent_target(root, target):
		return null
	var result := new()
	if root.package_item != null and root.package_item.owner != null:
		result.package_id = str(root.package_item.owner.id)
		result.package_name = str(root.package_item.owner.name)
		result.component_id = root.package_item.id
		result.component_name = root.package_item.name
	var ids := PackedStringArray()
	var names := PackedStringArray()
	var current := target
	while current != null and current != root:
		ids.insert(0, current.id)
		names.insert(0, current.name)
		current = current.parent
	if current != root:
		return null
	result.child_ids = ids
	result.child_names = names
	return result


static func is_persistent_target(root: FGUIObject, target: FGUIObject) -> bool:
	if root == null or target == null or root.is_disposed or target.is_disposed:
		return false
	var current := target
	while current != null and current != root:
		if current.id == "" and current.name == "":
			return false
		if current.parent is FGUIList or current.parent is FGUITree:
			return false
		current = current.parent
	return current == root


func resolve(root: FGUIObject) -> FGUIObject:
	if root == null or root.is_disposed or not _matches_root(root):
		return null
	var current := root
	var segment_count := maxi(_child_ids.size(), _child_names.size())
	for index in segment_count:
		if not current is FGUIComponent:
			return null
		var component := current as FGUIComponent
		var child_id := _child_ids[index] if index < _child_ids.size() else ""
		var child_name := _child_names[index] if index < _child_names.size() else ""
		var next := component.get_child_by_id(child_id) if child_id != "" else null
		if next == null and child_name != "":
			next = _unique_named_child(component, child_name)
		if next == null:
			return null
		current = next
	return current


func get_display_path() -> String:
	if _child_names.is_empty():
		return _component_name if _component_name != "" else "ui"
	var parts := PackedStringArray()
	for index in _child_names.size():
		var segment := _child_names[index]
		if segment == "" and index < _child_ids.size():
			segment = _child_ids[index]
		parts.append(segment if segment != "" else "<unnamed>")
	return "%s/%s" % [
		_component_name if _component_name != "" else "ui",
		"/".join(parts),
	]


func get_key() -> String:
	var segments := PackedStringArray()
	var segment_count := maxi(_child_ids.size(), _child_names.size())
	for index in segment_count:
		var child_id := _child_ids[index] if index < _child_ids.size() else ""
		var child_name := _child_names[index] if index < _child_names.size() else ""
		segments.append(child_id if child_id != "" else "name:%s" % child_name)
	return "%s\n%s\n%s" % [
		_package_id if _package_id != "" else _package_name,
		_component_id if _component_id != "" else _component_name,
		JSON.stringify(Array(segments)),
	]


func _matches_root(root: FGUIObject) -> bool:
	if root.package_item == null or root.package_item.owner == null:
		return _package_id == "" and _component_id == ""
	var package_matches := _package_id == "" or str(root.package_item.owner.id) == _package_id
	if not package_matches:
		package_matches = _package_name != "" and str(root.package_item.owner.name) == _package_name
	if not package_matches:
		return false
	var component_matches := _component_id == "" or root.package_item.id == _component_id
	if not component_matches:
		component_matches = _component_name != "" and root.package_item.name == _component_name
	return component_matches


static func _unique_named_child(component: FGUIComponent, child_name: String) -> FGUIObject:
	var result: FGUIObject
	for child: FGUIObject in component.children:
		if child.name != child_name:
			continue
		if result != null:
			return null
		result = child
	return result
