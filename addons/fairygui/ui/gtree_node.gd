class_name FGUITreeNode
extends RefCounted

var data: Variant
var parent: FGUITreeNode
var cell: FGUIObject
var expanded: bool = false
var children: Array[FGUITreeNode] = []

var num_children: int:
	get:
		return children.size()


func _init(has_child: bool = false, node_data: Variant = null) -> void:
	expanded = has_child
	data = node_data


func add_child(child: FGUITreeNode) -> FGUITreeNode:
	return add_child_at(child, children.size())


func add_child_at(child: FGUITreeNode, index: int) -> FGUITreeNode:
	if child.parent != null:
		child.parent.remove_child(child)
	child.parent = self
	children.insert(clampi(index, 0, children.size()), child)
	return child


func remove_child(child: FGUITreeNode) -> void:
	children.erase(child)
	child.parent = null


func get_child_at(index: int) -> FGUITreeNode:
	return children[index] if index >= 0 and index < children.size() else null
