class_name FGUITreeNode
extends RefCounted

var data: Variant
var res_url: String = ""
var parent: FGUITreeNode
var cell: FGUIObject
var expanded: bool = false
var children: Array[FGUITreeNode] = []

var num_children: int:
	get:
		return children.size()
var level: int:
	get:
		var value := 0
		var current := parent
		while current != null:
			value += 1
			current = current.parent
		return value


func _init(has_child: bool = false, node_data: Variant = null, node_res_url: String = "") -> void:
	expanded = has_child
	data = node_data
	res_url = node_res_url


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
