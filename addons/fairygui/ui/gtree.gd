class_name FGUITree
extends FGUIList

var root_node := FGUITreeNode.new(true)
var tree_node_render: Callable


func _init() -> void:
	super._init()
	root_node.expanded = true


func get_root_node() -> FGUITreeNode:
	return root_node


func add_selection_by_node(node: FGUITreeNode, scroll_it_to_view: bool = false) -> void:
	if node == null or node.cell == null:
		return
	add_selection(get_child_index(node.cell), scroll_it_to_view)


func get_selected_node() -> FGUITreeNode:
	var index := selected_index
	var obj := get_child_at(index)
	return obj.data if obj != null and obj.data is FGUITreeNode else null


func refresh_tree() -> void:
	remove_children_to_pool()
	_append_node_children(root_node)


func _append_node_children(node: FGUITreeNode) -> void:
	for child in node.children:
		var obj := add_item_from_pool(default_item)
		if obj != null:
			child.cell = obj
			obj.data = child
			if tree_node_render.is_valid():
				tree_node_render.call(child, obj)
		if child.expanded:
			_append_node_children(child)
