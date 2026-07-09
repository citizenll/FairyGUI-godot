class_name FGUITree
extends FGUIList

var root_node := FGUITreeNode.new(true)
var tree_node_render: Callable
var indent: int = 15
var click_to_expand: int = 0


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


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_before_add(buffer, begin_pos)
	if buffer.seek(begin_pos, 9):
		indent = buffer.read_i32()
		click_to_expand = buffer.read_u8()


func _read_items(buffer: FGUIByteBuffer) -> void:
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
			_apply_node_indent(node, obj)
			_setup_item(buffer, obj)
		buffer.pos = next_pos


func _append_node_children(node: FGUITreeNode) -> void:
	for child in node.children:
		var obj := add_item_from_pool(child.res_url if child.res_url != "" else default_item)
		if obj != null:
			child.cell = obj
			obj.data = child
			_apply_node_indent(child, obj)
			if tree_node_render.is_valid():
				tree_node_render.call(child, obj)
		if child.expanded:
			_append_node_children(child)


func _apply_node_indent(node: FGUITreeNode, obj: FGUIObject) -> void:
	if not (obj is FGUIComponent):
		return
	var indent_object := (obj as FGUIComponent).get_child("indent")
	if indent_object != null:
		indent_object.width = max(0, node.level - 1) * indent
