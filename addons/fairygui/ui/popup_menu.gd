class_name FGUIPopupMenu
extends RefCounted

var content_pane: FGUIComponent
var list: FGUIList
var item_count: int:
	get:
		return list.num_children if list != null else 0


func _init(resource_url: String = "") -> void:
	var url := resource_url if resource_url != "" else FGUIConfig.popup_menu
	if url == "":
		return
	var obj := FGUIPackage.create_object_from_url(url)
	if obj is FGUIComponent:
		_configure_content(obj)
	else:
		push_warning("FairyGUI PopupMenu resource must resolve to a component: %s" % url)


func _configure_content(next_content_pane: FGUIComponent) -> void:
	if list != null:
		list.off(FGUIEvents.CLICK_ITEM, Callable(self, "_on_click_item"))
	if content_pane != null and content_pane.node != null and content_pane.node.tree_entered.is_connected(_on_added_to_stage):
		content_pane.node.tree_entered.disconnect(_on_added_to_stage)
	content_pane = next_content_pane
	list = content_pane.get_child("list") as FGUIList if content_pane != null else null
	if content_pane == null or list == null:
		push_warning("FairyGUI PopupMenu requires a child list named 'list'.")
		return
	list.remove_children_to_pool()
	list.add_relation(content_pane, FGUIEnums.RELATION_WIDTH)
	list.remove_relation(content_pane, FGUIEnums.RELATION_HEIGHT)
	content_pane.add_relation(list, FGUIEnums.RELATION_HEIGHT)
	list.on(FGUIEvents.CLICK_ITEM, Callable(self, "_on_click_item"))
	if content_pane.node != null and not content_pane.node.tree_entered.is_connected(_on_added_to_stage):
		content_pane.node.tree_entered.connect(_on_added_to_stage)


func dispose() -> void:
	if list != null:
		list.off(FGUIEvents.CLICK_ITEM, Callable(self, "_on_click_item"))
	if content_pane != null and content_pane.node != null and content_pane.node.tree_entered.is_connected(_on_added_to_stage):
		content_pane.node.tree_entered.disconnect(_on_added_to_stage)
	if content_pane != null:
		if content_pane.parent is FGUIRoot:
			(content_pane.parent as FGUIRoot).hide_popup(content_pane)
		content_pane.dispose()
	content_pane = null
	list = null


func add_item(caption: String, callback: Callable = Callable()) -> FGUIButton:
	if list == null:
		return null
	var item := list.add_item_from_pool()
	if not item is FGUIButton:
		if item != null:
			list.remove_child_to_pool(item)
		push_warning("FairyGUI PopupMenu item resource must be a button.")
		return null
	return _prepare_item(item as FGUIButton, caption, callback)


func add_item_at(caption: String, index: int, callback: Callable = Callable()) -> FGUIButton:
	if list == null:
		return null
	var item := list.get_from_pool()
	if not item is FGUIButton:
		if item != null:
			list.return_to_pool(item)
		push_warning("FairyGUI PopupMenu item resource must be a button.")
		return null
	list.add_child_at(item, clampi(index, 0, list.num_children))
	return _prepare_item(item as FGUIButton, caption, callback)


func _prepare_item(item: FGUIButton, caption: String, callback: Callable) -> FGUIButton:
	item.title = caption
	item.data = callback
	item.grayed = false
	var checked_controller := item.get_controller("checked")
	if checked_controller != null:
		checked_controller.selected_index = 0
	return item


func add_separator() -> void:
	if list == null:
		return
	if FGUIConfig.popup_menu_separator == "":
		push_warning("FGUIConfig.popup_menu_separator is not configured.")
		return
	list.add_item_from_pool(FGUIConfig.popup_menu_separator)


func add_seperator() -> void:
	add_separator()


func get_item_name(index: int) -> String:
	var item := list.get_child_at(index) if list != null else null
	return item.name if item != null else ""


func set_item_text(item_name: String, caption: String) -> void:
	var item := _get_button(item_name)
	if item != null:
		item.title = caption


func set_item_visible(item_name: String, visible: bool) -> void:
	var item := _get_button(item_name)
	if item != null and item.visible != visible:
		item.visible = visible
		list.set_bounds_changed_flag()


func set_item_grayed(item_name: String, grayed: bool) -> void:
	var item := _get_button(item_name)
	if item != null:
		item.grayed = grayed


func set_item_checkable(item_name: String, checkable: bool) -> void:
	var controller := _get_checked_controller(item_name)
	if controller == null:
		return
	if checkable:
		if controller.selected_index == 0:
			controller.selected_index = 1
	else:
		controller.selected_index = 0


func set_item_checked(item_name: String, checked: bool) -> void:
	var controller := _get_checked_controller(item_name)
	if controller != null:
		controller.selected_index = 2 if checked else 1


func is_item_checked(item_name: String) -> bool:
	var controller := _get_checked_controller(item_name)
	return controller != null and controller.selected_index == 2


func remove_item(item_name: String) -> bool:
	if list == null:
		return false
	var item := list.get_child(item_name)
	if item == null:
		return false
	list.remove_child_to_pool_at(list.get_child_index(item))
	return true


func clear_items() -> void:
	if list != null:
		list.remove_children_to_pool()


func _get_button(item_name: String) -> FGUIButton:
	var item := list.get_child(item_name) if list != null else null
	return item as FGUIButton


func _get_checked_controller(item_name: String) -> FGUIController:
	var item := _get_button(item_name)
	return item.get_controller("checked") if item != null else null


func show(target: FGUIObject = null, dir: int = FGUIEnums.POPUP_AUTO) -> void:
	if content_pane == null:
		return
	var root_object := target.root if target != null else FGUIRoot.get_inst()
	if root_object != null:
		root_object.show_popup(content_pane, null if target is FGUIRoot else target, dir)


func _on_added_to_stage() -> void:
	if list == null:
		return
	list.selected_index = -1
	list.resize_to_fit(100000, 10)


func _on_click_item(item: Variant) -> void:
	if item is FGUIButton:
		_activate_item.call_deferred(item)


func _activate_item(item: FGUIButton) -> void:
	if item == null or item.is_disposed:
		return
	if item.grayed:
		if list != null:
			list.selected_index = -1
		return
	var checked_controller := item.get_controller("checked")
	if checked_controller != null and checked_controller.selected_index != 0:
		checked_controller.selected_index = 2 if checked_controller.selected_index == 1 else 1
	if content_pane != null and content_pane.parent is FGUIRoot:
		(content_pane.parent as FGUIRoot).hide_popup(content_pane)
	var callback = item.data
	if callback is Callable and (callback as Callable).is_valid():
		(callback as Callable).call()
