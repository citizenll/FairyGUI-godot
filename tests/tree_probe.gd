extends SceneTree


class ProbeTree extends FGUITree:
	var recycled: Array[FGUIObject] = []


	func get_from_pool(_url: String = "") -> FGUIObject:
		var obj: FGUIObject
		if recycled.is_empty():
			var button := FGUIButton.new()
			button.mode = FGUIEnums.BUTTON_CHECK
			button.set_size(120, 24)
			var expanded_controller := FGUIController.new()
			expanded_controller.name = "expanded"
			expanded_controller.add_page("collapsed")
			expanded_controller.add_page("expanded")
			expanded_controller.selected_index = 0
			button.add_controller(expanded_controller)
			obj = button
		else:
			obj = recycled.pop_back()
		obj.visible = true
		return obj


	func return_to_pool(obj: FGUIObject) -> void:
		if obj == null:
			return
		obj.remove_from_parent()
		recycled.append(obj)


	func dispose() -> void:
		for obj: FGUIObject in recycled:
			obj.dispose()
		recycled.clear()
		super.dispose()


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var tree := ProbeTree.new()
	tree.set_size(160, 120)
	host.add_child(tree.node)
	tree.tree_node_render = func(node: FGUITreeNode, item: FGUIObject) -> void:
		item.set_text(str(node.data))
	var expand_events: Array = []
	tree.tree_node_will_expand = func(node: FGUITreeNode, expanded: bool) -> void:
		expand_events.append([node, expanded])

	var folder := FGUITreeNode.new(true, "Folder")
	if folder.expanded:
		_fail("New tree folders must be collapsed until explicitly expanded.")
		return
	folder.expanded = true
	var first_leaf := FGUITreeNode.new(false, "First")
	folder.add_child(first_leaf)
	tree.root_node.add_child(folder)
	if tree.num_children != 2 or tree.get_child_at(0).data != folder or tree.get_child_at(1).data != first_leaf or tree.get_child_at(0).tree_node != folder:
		_fail("Tree did not create visible cells for inserted expanded nodes.")
		return
	if tree.get_child_at(0).get_text() != "Folder":
		_fail("Tree renderer was not called for a visible node.")
		return
	if expand_events.is_empty() or expand_events[0][0] != folder or not expand_events[0][1]:
		_fail("Attaching a pre-expanded tree node did not invoke tree_node_will_expand.")
		return

	var expanded_controller := (folder.cell as FGUIComponent).get_controller("expanded")
	expanded_controller.selected_index = 0
	if tree.num_children != 1 or first_leaf.cell != null:
		_fail("The expanded controller did not collapse its tree folder.")
		return
	expanded_controller = (folder.cell as FGUIComponent).get_controller("expanded")
	expanded_controller.selected_index = 1
	if tree.num_children != 2 or first_leaf.cell == null:
		_fail("The expanded controller did not restore its tree folder descendants.")
		return

	tree.click_to_expand = 1
	tree._click_item(null, folder.cell)
	if folder.expanded or tree.num_children != 1:
		_fail("Click-to-expand did not toggle a folder.")
		return
	tree.select_node(first_leaf)
	if not folder.expanded or tree.get_selected_node() != first_leaf:
		_fail("Selecting a tree node did not reveal and select it.")
		return

	var second_leaf := FGUITreeNode.new(false, "Second")
	folder.add_child(second_leaf)
	if tree.num_children != 3:
		_fail("Adding a node after tree construction did not refresh the visible list.")
		return
	folder.swap_children_at(0, 1)
	if tree.get_child_at(1).data != second_leaf or tree.get_child_at(2).data != first_leaf:
		_fail("Swapping tree children by index did not update visible ordering.")
		return
	folder.swap_children(first_leaf, second_leaf)
	if tree.get_child_at(1).data != first_leaf or tree.get_child_at(2).data != second_leaf:
		_fail("Swapping tree child objects did not restore visible ordering.")
		return
	folder.set_child_index(second_leaf, 0)
	if tree.get_child_at(1).data != second_leaf:
		_fail("Moving a tree node did not update visible ordering.")
		return
	folder.remove_child(second_leaf)
	if tree.num_children != 2:
		_fail("Removing a tree node did not update visible cells.")
		return

	var collapsed_folder := FGUITreeNode.new(true, "Collapsed")
	var hidden_leaf := FGUITreeNode.new(false, "Hidden")
	collapsed_folder.add_child(hidden_leaf)
	tree.root_node.add_child(collapsed_folder)
	if tree.num_children != 3 or hidden_leaf.cell != null:
		_fail("A newly attached collapsed folder exposed its descendants.")
		return

	tree.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
