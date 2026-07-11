class_name FGUITree
extends FGUIList

var root_node: FGUITreeNode
var tree_node_render: Callable
var tree_node_will_expand: Callable
var indent: int = 15
var click_to_expand: int = 0
var _refreshing_tree: bool = false
var _suspend_tree_updates: bool = false


func _init() -> void:
	super._init()
	root_node = FGUITreeNode.new(true)
	root_node.expanded = true
	root_node._set_tree(self)


func dispose() -> void:
	if root_node != null:
		root_node._set_tree(null)
		root_node.dispose()
		root_node = null
	tree_node_render = Callable()
	tree_node_will_expand = Callable()
	super.dispose()


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


func get_selected_nodes(result: Array[FGUITreeNode] = []) -> Array[FGUITreeNode]:
	for index in _selected_indices:
		var obj := get_child_at(index)
		if obj != null and obj.data is FGUITreeNode:
			result.append(obj.data)
	return result


func select_node(node: FGUITreeNode, scroll_it_to_view: bool = false) -> void:
	if node == null:
		return
	var current := node.parent
	while current != null:
		current.expanded = true
		current = current.parent
	if node.cell != null:
		add_selection(get_child_index(node.cell), scroll_it_to_view)


func unselect_node(node: FGUITreeNode) -> void:
	if node != null and node.cell != null:
		remove_selection(get_child_index(node.cell))


func expand_all(folder_node: FGUITreeNode = null) -> void:
	var target := root_node if folder_node == null else folder_node
	if target == null:
		return
	target.expanded = true
	for child in target.children:
		if child.is_folder:
			expand_all(child)


func collapse_all(folder_node: FGUITreeNode = null) -> void:
	var target := root_node if folder_node == null else folder_node
	if target == null:
		return
	if target != root_node:
		target.expanded = false
	for child in target.children:
		if child.is_folder:
			collapse_all(child)


func refresh_tree() -> void:
	if _refreshing_tree:
		return
	_refreshing_tree = true
	var selected_nodes := get_selected_nodes()
	_selected_indices.clear()
	_clear_node_cells(root_node)
	remove_children_to_pool()
	_append_node_children(root_node)
	for node in selected_nodes:
		if node.cell != null:
			add_selection(get_child_index(node.cell), false)
	_refreshing_tree = false


func _node_inserted(_node: FGUITreeNode) -> void:
	_request_tree_refresh()


func _node_removed(_node: FGUITreeNode) -> void:
	_request_tree_refresh()


func _node_moved(_node: FGUITreeNode) -> void:
	_request_tree_refresh()


func _node_expanded_changed(node: FGUITreeNode) -> void:
	if node != root_node and tree_node_will_expand.is_valid():
		tree_node_will_expand.call(node, node.expanded)
	_request_tree_refresh()


func _request_tree_refresh() -> void:
	if not _suspend_tree_updates:
		refresh_tree()


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_before_add(buffer, begin_pos)
	if buffer.seek(begin_pos, 9):
		indent = buffer.read_i32()
		click_to_expand = buffer.read_u8()


func _read_items(buffer: FGUIByteBuffer) -> void:
	_suspend_tree_updates = true
	var count := buffer.read_i16()
	var last_node: FGUITreeNode = null
	var previous_level := 0
	for i in count:
		var next_pos := buffer.read_i16() + buffer.pos
		var url = buffer.read_s()
		if url == null:
			url = default_item
			if str(url) == "":
				buffer.pos = next_pos
				continue
		var is_folder := buffer.read_bool()
		var level := buffer.read_u8()
		var node := FGUITreeNode.new(is_folder, null, str(url))
		node.expanded = true
		if i == 0 or last_node == null:
			root_node.add_child(node)
		elif level > previous_level:
			last_node.add_child(node)
		elif level < previous_level:
			for j in range(level, previous_level + 1):
				if last_node.parent != null:
					last_node = last_node.parent
			last_node.add_child(node)
		else:
			last_node.parent.add_child(node)
		last_node = node
		previous_level = level

		var obj := get_from_pool(str(url))
		if obj != null:
			add_child(obj)
			node.cell = obj
			obj.data = node
			_configure_node_cell(node, obj)
			_setup_item(buffer, obj)
		buffer.pos = next_pos
	_suspend_tree_updates = false


func _append_node_children(node: FGUITreeNode) -> void:
	for child in node.children:
		_create_node_cell(child)
		if child.expanded:
			_append_node_children(child)


func _create_node_cell(node: FGUITreeNode) -> void:
	var obj := add_item_from_pool(node.res_url if node.res_url != "" else default_item)
	if obj == null:
		return
	node.cell = obj
	obj.data = node
	_configure_node_cell(node, obj)


func _configure_node_cell(node: FGUITreeNode, obj: FGUIObject) -> void:
	_apply_node_indent(node, obj)
	if obj is FGUIComponent:
		var component := obj as FGUIComponent
		var expanded_controller := component.get_controller("expanded")
		if expanded_controller != null:
			expanded_controller.off(FGUIEvents.STATE_CHANGED, Callable(self, "_expanded_controller_changed"))
			expanded_controller.on(FGUIEvents.STATE_CHANGED, Callable(self, "_expanded_controller_changed"))
			expanded_controller.selected_index = 1 if node.expanded else 0
		var leaf_controller := component.get_controller("leaf")
		if leaf_controller != null:
			leaf_controller.selected_index = 0 if node.is_folder else 1
	if tree_node_render.is_valid():
		tree_node_render.call(node, obj)


func _expanded_controller_changed(controller: FGUIController) -> void:
	if controller == null or controller.parent == null or not (controller.parent.data is FGUITreeNode):
		return
	var tree_node := controller.parent.data as FGUITreeNode
	if tree_node.is_folder:
		tree_node.expanded = controller.selected_index == 1


func _clear_node_cells(node: FGUITreeNode) -> void:
	if node == null:
		return
	node.cell = null
	for child in node.children:
		_clear_node_cells(child)


func _apply_node_indent(node: FGUITreeNode, obj: FGUIObject) -> void:
	if not (obj is FGUIComponent):
		return
	var indent_object := (obj as FGUIComponent).get_child("indent")
	if indent_object != null:
		indent_object.width = max(0, node.level - 1) * indent


func _click_item(event: Variant, item: FGUIObject) -> void:
	if click_to_expand == 1 and item != null and item.data is FGUITreeNode:
		var node := item.data as FGUITreeNode
		if node.is_folder:
			node.expanded = not node.expanded
	super._click_item(event, item)
