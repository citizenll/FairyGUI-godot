extends SceneTree


class ProbeItem extends FGUIObject:
	var item_text: String = ""
	var item_icon: String = ""

	func get_text() -> String:
		return item_text

	func set_text(value: String) -> void:
		item_text = value

	func get_icon() -> String:
		return item_icon

	func set_icon(value: String) -> void:
		item_icon = value


class ProbeList extends FGUIList:
	func get_from_pool(_url: String = "") -> FGUIObject:
		var item := ProbeItem.new()
		item.set_size(100.0, 20.0)
		return item

	func return_to_pool(obj: FGUIObject) -> void:
		obj.dispose()


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var root_object := FGUIRoot.new()
	root_object.set_size(400.0, 300.0)
	host.add_child(root_object.node)

	var combo := FGUIComboBox.new()
	combo.set_xy(50.0, 80.0)
	combo.set_size(120.0, 30.0)
	root_object.add_child(combo)

	var title := FGUITextField.new()
	title.name = "title"
	combo.add_child(title)
	combo._title_object = title
	var icon := ProbeItem.new()
	icon.name = "icon"
	combo.add_child(icon)
	combo._icon_object = icon

	var button_controller := FGUIController.new()
	button_controller.name = "button"
	for page_name in [FGUIButton.UP, FGUIButton.OVER, FGUIButton.DOWN]:
		button_controller.page_ids.append(page_name)
		button_controller.page_names.append(page_name)
	button_controller._selected_index = 0
	combo.add_controller(button_controller)
	combo._button_controller = button_controller

	var dropdown := FGUIComponent.new()
	dropdown.set_size(120.0, 20.0)
	var list := ProbeList.new()
	list.name = "list"
	list.set_size(120.0, 20.0)
	dropdown.add_child(list)
	combo._configure_dropdown(dropdown)

	combo.visible_item_count = 2
	combo.values = ["v1", "v2", "v3"]
	combo.icons = ["i1", "i2", "i3"]
	combo.items = ["One", "Two", "Three"]
	if combo.selected_index != 0 or combo.get_text() != "One" or combo.get_icon() != "i1" or combo.value != "v1":
		_fail(root_object, combo, "ComboBox data assignment did not select and display the first item.")
		return

	combo.title_color = Color("336699")
	combo.title_font_size = 19
	combo.set_prop(FGUIEnums.OBJECT_PROP_OUTLINE_COLOR, Color("aa2200"))
	if combo.get_prop(FGUIEnums.OBJECT_PROP_COLOR) != Color("336699") or combo.get_prop(FGUIEnums.OBJECT_PROP_FONT_SIZE) != 19 or combo.get_prop(FGUIEnums.OBJECT_PROP_OUTLINE_COLOR) != Color("aa2200"):
		_fail(root_object, combo, "ComboBox title style properties did not reach its text field.")
		return

	var changed_count := [0]
	combo.on(FGUIEvents.STATE_CHANGED, func(_item: Variant) -> void: changed_count[0] += 1)
	combo.show_dropdown()
	await process_frame
	if dropdown.parent != root_object or list.children.size() != 3 or absf(list.height - 40.0) > 0.1 or absf(dropdown.width - combo.width) > 0.1:
		_fail(root_object, combo, "ComboBox did not build and size its dropdown list.")
		return
	if button_controller.selected_page != FGUIButton.DOWN:
		_fail(root_object, combo, "ComboBox did not enter its down state while the dropdown was open.")
		return
	var second_item := list.get_child_at(1) as ProbeItem
	if second_item == null or second_item.name != "v2" or second_item.get_text() != "Two" or second_item.get_icon() != "i2":
		_fail(root_object, combo, "ComboBox dropdown item data was not populated correctly.")
		return
	list._click_item(null, second_item)
	await process_frame
	if combo.selected_index != 1 or combo.value != "v2" or combo.get_text() != "Two" or combo.get_icon() != "i2" or dropdown.parent != null or changed_count[0] != 1:
		_fail(root_object, combo, "ComboBox dropdown selection did not commit and close exactly once.")
		return
	if button_controller.selected_page != FGUIButton.UP:
		_fail(root_object, combo, "ComboBox did not restore its up state after the dropdown closed.")
		return

	combo.items = ["Only"]
	combo.icons = []
	combo.values = ["only"]
	if combo.selected_index != 0 or combo.get_text() != "Only" or combo.get_icon() != "" or combo.value != "only":
		_fail(root_object, combo, "ComboBox did not clamp and refresh selection after replacing its data.")
		return
	combo.show_dropdown()
	await process_frame
	if list.children.size() != 1 or (list.get_child_at(0) as ProbeItem).get_text() != "Only":
		_fail(root_object, combo, "ComboBox did not rebuild a dirty dropdown list.")
		return
	combo.show_dropdown()
	await process_frame
	if dropdown.parent != null or button_controller.selected_page != FGUIButton.UP:
		_fail(root_object, combo, "ComboBox dropdown toggle did not close and restore state.")
		return

	combo.show_dropdown()
	await process_frame
	combo.dispose()
	if root_object.has_any_popup():
		_fail(root_object, combo, "Disposing an open ComboBox left a stale popup in GRoot.")
		return
	root_object.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(root_object: FGUIRoot, combo: FGUIComboBox, message: String) -> void:
	push_error(message)
	if combo != null and not combo.is_disposed:
		combo.dispose()
	if root_object != null and not root_object.is_disposed:
		root_object.dispose()
	quit(1)
