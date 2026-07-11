extends SceneTree


class ProbeList extends FGUIList:
	func get_from_pool(url: String = "") -> FGUIObject:
		if url == "separator":
			var separator := FGUIObject.new()
			separator.set_size(100.0, 4.0)
			return separator
		var button := FGUIButton.new()
		button.set_size(100.0, 20.0)
		var title := FGUITextField.new()
		button.add_child(title)
		button._title_object = title
		var checked := FGUIController.new()
		checked.name = "checked"
		for page_name in ["none", "unchecked", "checked"]:
			checked.page_ids.append(page_name)
			checked.page_names.append(page_name)
		checked._selected_index = 0
		button.add_controller(checked)
		return button

	func return_to_pool(obj: FGUIObject) -> void:
		obj.dispose()


func _initialize() -> void:
	var previous_separator := FGUIConfig.popup_menu_separator
	FGUIConfig.popup_menu_separator = "separator"
	var host := Control.new()
	root.add_child(host)
	var root_object := FGUIRoot.new()
	root_object.set_size(320.0, 240.0)
	host.add_child(root_object.node)
	var target := FGUIObject.new()
	target.set_xy(20.0, 20.0)
	target.set_size(80.0, 20.0)
	root_object.add_child(target)

	var content := FGUIComponent.new()
	content.set_size(120.0, 20.0)
	var list := ProbeList.new()
	list.name = "list"
	list.set_size(120.0, 20.0)
	content.add_child(list)
	var menu := FGUIPopupMenu.new()
	menu._configure_content(content)

	var callbacks := {"a": 0, "b": 0}
	var item_a := menu.add_item("Item A", func() -> void: callbacks["a"] += 1)
	var item_b := menu.add_item_at("Item B", 0, func() -> void: callbacks["b"] += 1)
	if item_a == null or item_b == null:
		_fail(menu, root_object, previous_separator, "PopupMenu did not create button items from its pool.")
		return
	item_a.name = "a"
	item_b.name = "b"
	if menu.item_count != 2 or menu.get_item_name(0) != "b" or menu.get_item_name(1) != "a":
		_fail(menu, root_object, previous_separator, "PopupMenu insertion order or item enumeration is incorrect.")
		return
	menu.set_item_text("b", "Renamed B")
	menu.set_item_visible("b", false)
	menu.set_item_grayed("b", true)
	if item_b.title != "Renamed B" or item_b.visible or not item_b.grayed:
		_fail(menu, root_object, previous_separator, "PopupMenu item text/visibility/grayed setters failed.")
		return
	menu.set_item_checkable("a", true)
	menu.set_item_checked("a", true)
	if not menu.is_item_checked("a"):
		_fail(menu, root_object, previous_separator, "PopupMenu checkable state was not applied.")
		return

	menu.show(target, FGUIEnums.POPUP_DOWN)
	await process_frame
	if content.parent != root_object or list.selected_index != -1 or list.height < 10.0:
		_fail(menu, root_object, previous_separator, "PopupMenu did not reset and size its list when shown.")
		return
	item_b.visible = true
	list._click_item(null, item_b)
	await process_frame
	if content.parent != root_object or callbacks["b"] != 0:
		_fail(menu, root_object, previous_separator, "PopupMenu activated a grayed item or closed unexpectedly.")
		return
	menu.set_item_grayed("b", false)
	list._click_item(null, item_b)
	await process_frame
	if content.parent != null or callbacks["b"] != 1:
		_fail(menu, root_object, previous_separator, "PopupMenu did not close before invoking an enabled item callback.")
		return

	menu.show(target)
	await process_frame
	list._click_item(null, item_a)
	await process_frame
	if callbacks["a"] != 1 or menu.is_item_checked("a") or content.parent != null:
		_fail(menu, root_object, previous_separator, "PopupMenu checkable item activation did not toggle and invoke its callback.")
		return
	menu.set_item_checkable("a", false)
	if item_a.get_controller("checked").selected_index != 0:
		_fail(menu, root_object, previous_separator, "PopupMenu did not disable item checkability.")
		return
	if not menu.remove_item("b") or menu.remove_item("b"):
		_fail(menu, root_object, previous_separator, "PopupMenu remove_item return values are incorrect.")
		return
	menu.add_separator()
	if menu.item_count != 2:
		_fail(menu, root_object, previous_separator, "PopupMenu separator was not added from the configured resource.")
		return
	menu.clear_items()
	if menu.item_count != 0:
		_fail(menu, root_object, previous_separator, "PopupMenu clear_items did not return all rows to the pool.")
		return

	menu.add_item("Dispose", Callable())
	menu.show(target)
	await process_frame
	menu.dispose()
	if root_object.has_any_popup():
		_fail(menu, root_object, previous_separator, "Disposing an open PopupMenu left a stale GRoot popup entry.")
		return
	FGUIConfig.popup_menu_separator = previous_separator
	root_object.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(menu: FGUIPopupMenu, root_object: FGUIRoot, previous_separator: String, message: String) -> void:
	push_error(message)
	FGUIConfig.popup_menu_separator = previous_separator
	if menu != null:
		menu.dispose()
	if root_object != null and not root_object.is_disposed:
		root_object.dispose()
	quit(1)
