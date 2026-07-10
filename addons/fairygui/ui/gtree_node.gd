class_name FGUITreeNode
extends RefCounted

var data: Variant
var res_url: String = ""
var parent: FGUITreeNode
var cell: FGUIObject
var _expanded: bool = false
var _is_folder: bool = false
var _tree: FGUITree
var children: Array[FGUITreeNode] = []

var num_children: int:
	get:
		return children.size()
var is_folder: bool:
	get:
		return _is_folder
var expanded: bool:
	get:
		return _expanded
	set(value):
		if not _is_folder or _expanded == value:
			return
		_expanded = value
		if _tree != null:
			_tree._node_expanded_changed(self)
var level: int:
	get:
		var value := 0
		var current := parent
		while current != null:
			value += 1
			current = current.parent
		return value
var tree: FGUITree:
	get:
		return _tree
var text: String:
	get:
		return cell.get_text() if cell != null else ""
	set(value):
		if cell != null:
			cell.set_text(value)
var icon: String:
	get:
		return cell.get_icon() if cell != null else ""
	set(value):
		if cell != null:
			cell.set_icon(value)


func _init(has_child: bool = false, node_data: Variant = null, node_res_url: String = "") -> void:
	_is_folder = has_child
	_expanded = has_child
	data = node_data
	res_url = node_res_url


func dispose() -> void:
	for child: FGUITreeNode in children.duplicate():
		child.dispose()
	children.clear()
	if cell != null and cell.data == self:
		cell.data = null
	cell = null
	parent = null
	_tree = null
	data = null
	res_url = ""


func add_child(child: FGUITreeNode) -> FGUITreeNode:
	return add_child_at(child, children.size())


func add_child_at(child: FGUITreeNode, index: int) -> FGUITreeNode:
	if child == null:
		push_error("FairyGUI tree node is null.")
		return null
	if not _is_folder:
		push_error("Cannot add children to a leaf tree node.")
		return null
	index = clampi(index, 0, children.size())
	if child.parent == self:
		set_child_index(child, index)
		return child
	if child.parent != null:
		child.parent.remove_child(child)
	child.parent = self
	children.insert(index, child)
	child._set_tree(_tree)
	if _tree != null:
		_tree._node_inserted(child)
	return child


func remove_child(child: FGUITreeNode) -> FGUITreeNode:
	var index := children.find(child)
	return remove_child_at(index) if index != -1 else child


func get_child_at(index: int) -> FGUITreeNode:
	return children[index] if index >= 0 and index < children.size() else null


func remove_child_at(index: int) -> FGUITreeNode:
	var child := get_child_at(index)
	if child == null:
		return null
	children.remove_at(index)
	child.parent = null
	child._set_tree(null)
	if _tree != null:
		_tree._node_removed(child)
	return child


func remove_children(begin_index: int = 0, end_index: int = -1) -> void:
	if end_index < 0 or end_index >= children.size():
		end_index = children.size() - 1
	for i in range(begin_index, end_index + 1):
		remove_child_at(begin_index)


func get_child_index(child: FGUITreeNode) -> int:
	return children.find(child)


func get_prev_sibling() -> FGUITreeNode:
	if parent == null:
		return null
	var index := parent.get_child_index(self)
	return parent.get_child_at(index - 1) if index > 0 else null


func get_next_sibling() -> FGUITreeNode:
	if parent == null:
		return null
	var index := parent.get_child_index(self)
	return parent.get_child_at(index + 1)


func set_child_index(child: FGUITreeNode, index: int) -> void:
	var old_index := children.find(child)
	if old_index == -1:
		push_error("Tree node is not a child of this parent.")
		return
	index = clampi(index, 0, children.size() - 1)
	if old_index == index:
		return
	children.remove_at(old_index)
	children.insert(index, child)
	if _tree != null:
		_tree._node_moved(child)


func swap_children(child_a: FGUITreeNode, child_b: FGUITreeNode) -> void:
	var index_a := children.find(child_a)
	var index_b := children.find(child_b)
	if index_a == -1 or index_b == -1:
		push_error("Tree node is not a child of this parent.")
		return
	children[index_a] = child_b
	children[index_b] = child_a
	if _tree != null:
		_tree._node_moved(child_a)


func expand_to_root() -> void:
	var current: FGUITreeNode = self
	while current != null:
		current.expanded = true
		current = current.parent


func _set_tree(value: FGUITree) -> void:
	_tree = value
	for child in children:
		child._set_tree(value)
