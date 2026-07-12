class_name FGUIComboBox
extends FGUIComponent

var dropdown: FGUIComponent
var items: Array[String] = []:
	set(value):
		items = value.duplicate()
		if items.is_empty():
			selected_index = -1
		elif selected_index < 0:
			selected_index = 0
		elif selected_index >= items.size():
			selected_index = items.size() - 1
		else:
			set_text(items[_selected_index])
			set_icon(icons[_selected_index] if _selected_index < icons.size() else "")
		_items_updated = true
var icons: Array[String] = []:
	set(value):
		icons = value.duplicate()
		if _selected_index >= 0:
			set_icon(icons[_selected_index] if _selected_index < icons.size() else "")
		_items_updated = true
var values: Array[String] = []:
	set(value):
		values = value.duplicate()
		_items_updated = true
var visible_item_count: int = FGUIConfig.default_combo_box_visible_item_count
var popup_direction: int = FGUIEnums.POPUP_AUTO
var selection_controller: FGUIController

var _title_object: FGUIObject
var _icon_object: FGUIObject
var _list: FGUIList
var _selected_index: int = -1
var _button_controller: FGUIController
var _items_updated: bool = true
var _button_touch_index: int = -2
var _down: bool = false
var _over: bool = false

var selected_index: int:
	get:
		return _selected_index
	set(value):
		if _selected_index == value:
			return
		_selected_index = value
		if _selected_index >= 0 and _selected_index < items.size():
			set_text(items[_selected_index])
			set_icon(icons[_selected_index] if _selected_index < icons.size() else "")
		else:
			set_text("")
			set_icon("")
		_update_selection_controller()
var value: String:
	get:
		return values[_selected_index] if _selected_index >= 0 and _selected_index < values.size() else ""
	set(next_value):
		selected_index = values.find(next_value)
var title_color: Color:
	get:
		var field := get_text_field()
		return field.color if field != null else Color.BLACK
	set(value):
		var field := get_text_field()
		if field != null:
			field.color = value
		update_gear(4)
var title_font_size: int:
	get:
		var field := get_text_field()
		return field.font_size if field != null else 0
	set(value):
		var field := get_text_field()
		if field != null:
			field.font_size = value


func dispose() -> void:
	if _list != null:
		_list.off(FGUIEvents.CLICK_ITEM, Callable(self, "_on_dropdown_item_clicked"))
	if dropdown != null and dropdown.node != null and dropdown.node.tree_exited.is_connected(_on_popup_closed):
		dropdown.node.tree_exited.disconnect(_on_popup_closed)
	if dropdown != null:
		if dropdown.parent is FGUIRoot:
			(dropdown.parent as FGUIRoot).hide_popup(dropdown)
		dropdown.dispose()
		dropdown = null
	_list = null
	_title_object = null
	_icon_object = null
	_button_controller = null
	selection_controller = null
	super.dispose()


func construct_extension(buffer: FGUIByteBuffer) -> void:
	_button_controller = get_controller("button")
	_title_object = get_child("title")
	_icon_object = get_child("icon")
	if buffer.seek(0, 6):
		var dropdown_url = buffer.read_s()
		if dropdown_url != null and dropdown_url != "":
			var obj := FGUIPackage.create_object_from_url(str(dropdown_url))
			if obj is FGUIComponent:
				_configure_dropdown(obj)
			else:
				push_warning("FairyGUI ComboBox dropdown must be a component: %s" % dropdown_url)


func _configure_dropdown(dropdown_object: FGUIComponent) -> void:
	if _list != null:
		_list.off(FGUIEvents.CLICK_ITEM, Callable(self, "_on_dropdown_item_clicked"))
	if dropdown != null and dropdown.node != null and dropdown.node.tree_exited.is_connected(_on_popup_closed):
		dropdown.node.tree_exited.disconnect(_on_popup_closed)
	dropdown = dropdown_object
	_list = dropdown.get_child("list") as FGUIList if dropdown != null else null
	if dropdown == null or _list == null:
		push_warning("FairyGUI ComboBox dropdown requires a child list named 'list'.")
		return
	dropdown.name = "_dropdownObject"
	_list.on(FGUIEvents.CLICK_ITEM, Callable(self, "_on_dropdown_item_clicked"))
	_list.add_relation(dropdown, FGUIEnums.RELATION_WIDTH)
	_list.remove_relation(dropdown, FGUIEnums.RELATION_HEIGHT)
	dropdown.add_relation(_list, FGUIEnums.RELATION_HEIGHT)
	dropdown.remove_relation(_list, FGUIEnums.RELATION_WIDTH)
	if dropdown.node != null and not dropdown.node.tree_exited.is_connected(_on_popup_closed):
		dropdown.node.tree_exited.connect(_on_popup_closed)


func get_text() -> String:
	return _title_object.get_text() if _title_object != null else ""


func set_text(value: String) -> void:
	if _title_object != null:
		_title_object.set_text(value)
	update_gear(6)


func get_icon() -> String:
	return _icon_object.get_icon() if _icon_object != null else ""


func set_icon(value: String) -> void:
	if _icon_object != null:
		_icon_object.set_icon(value)
	update_gear(7)


func setup_after_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_after_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 6):
		return
	if buffer.read_i8() != package_item.object_type:
		return
	items.clear()
	values.clear()
	icons.clear()
	var item_count := buffer.read_i16()
	for i in item_count:
		var next_pos := buffer.read_i16() + buffer.pos
		items.append(_string_or_empty(buffer.read_s()))
		values.append(_string_or_empty(buffer.read_s()))
		var icon_value = buffer.read_s()
		icons.append(_string_or_empty(icon_value))
		buffer.pos = next_pos
	var text_value = buffer.read_s()
	if text_value != null:
		set_text(str(text_value))
		_selected_index = items.find(str(text_value))
	elif not items.is_empty():
		_selected_index = 0
		set_text(items[0])
	else:
		_selected_index = -1
	var icon_value = buffer.read_s()
	if icon_value != null:
		set_icon(str(icon_value))
	if buffer.read_bool():
		var field := get_text_field()
		if field != null:
			field.color = buffer.read_color()
	var count := buffer.read_i32()
	if count > 0:
		visible_item_count = count
	popup_direction = buffer.read_i8()
	var controller_index := buffer.read_i16()
	if controller_index >= 0 and parent != null:
		selection_controller = parent.get_controller_at(controller_index)
	if buffer.version >= 5:
		var click_sound = buffer.read_s()
		var click_sound_volume := buffer.read_float32()
		_set_click_sound(click_sound, click_sound_volume)
	_items_updated = true


func handle_controller_changed(controller: FGUIController) -> void:
	super.handle_controller_changed(controller)
	if selection_controller == controller:
		selected_index = controller.selected_index


func get_text_field() -> FGUITextField:
	if _title_object is FGUITextField:
		return _title_object
	if _title_object != null and _title_object.has_method("get_text_field"):
		return _title_object.call("get_text_field")
	return null


func get_prop(index: int) -> Variant:
	match index:
		FGUIEnums.OBJECT_PROP_TEXT:
			return get_text()
		FGUIEnums.OBJECT_PROP_ICON:
			return get_icon()
		FGUIEnums.OBJECT_PROP_COLOR:
			return title_color
		FGUIEnums.OBJECT_PROP_OUTLINE_COLOR:
			var field := get_text_field()
			return field.stroke_color if field != null else Color.BLACK
		FGUIEnums.OBJECT_PROP_FONT_SIZE:
			return title_font_size
		_:
			return super.get_prop(index)


func set_prop(index: int, prop_value: Variant) -> void:
	match index:
		FGUIEnums.OBJECT_PROP_TEXT:
			set_text(str(prop_value))
		FGUIEnums.OBJECT_PROP_ICON:
			set_icon(str(prop_value))
		FGUIEnums.OBJECT_PROP_COLOR:
			if prop_value is Color:
				title_color = prop_value
		FGUIEnums.OBJECT_PROP_OUTLINE_COLOR:
			var field := get_text_field()
			if field != null and prop_value is Color:
				field.stroke_color = prop_value
		FGUIEnums.OBJECT_PROP_FONT_SIZE:
			title_font_size = int(prop_value)
		_:
			super.set_prop(index, prop_value)


func _update_selection_controller() -> void:
	if selection_controller == null or selection_controller.changing or _selected_index >= selection_controller.page_count:
		return
	var controller := selection_controller
	selection_controller = null
	controller.selected_index = _selected_index
	selection_controller = controller


func show_dropdown() -> void:
	if dropdown == null or _list == null:
		return
	if _items_updated:
		_items_updated = false
		_list.remove_children_to_pool()
		for index in items.size():
			var item := _list.add_item_from_pool()
			if item == null:
				continue
			item.name = values[index] if index < values.size() else ""
			item.set_text(items[index])
			item.set_icon(icons[index] if index < icons.size() else "")
		_list.resize_to_fit(visible_item_count)
	_list.selected_index = -1
	dropdown.width = width
	_list.ensure_bounds_correct()
	var root_object := root
	if root_object == null:
		root_object = FGUIRoot.get_inst()
	root_object.toggle_popup(dropdown, self, popup_direction)
	if dropdown.parent != null:
		set_state(FGUIButton.DOWN)


func set_state(value: String) -> void:
	if _button_controller != null and _button_controller.has_page(value):
		_button_controller.selected_page = value


func _on_dropdown_item_clicked(item: Variant) -> void:
	if not item is FGUIObject or _list == null:
		return
	var index := _list.get_child_index(item)
	if index >= 0:
		_commit_dropdown_selection.call_deferred(index, item)


func _commit_dropdown_selection(index: int, item: FGUIObject) -> void:
	if dropdown != null and dropdown.parent is FGUIRoot:
		(dropdown.parent as FGUIRoot).hide_popup(dropdown)
	_selected_index = -1
	selected_index = index
	emit_event(FGUIEvents.STATE_CHANGED, item)


func _on_popup_closed() -> void:
	_down = false
	_button_touch_index = -2
	set_state(FGUIButton.OVER if _over else FGUIButton.UP)


func _on_gui_input(event: InputEvent) -> void:
	if FGUIToolSet.is_primary_pointer_press(event):
		_button_touch_index = FGUIToolSet.get_pointer_id(event)
		_down = true
		var root_object := root
		if root_object != null:
			root_object._check_popups(FGUIToolSet.get_pointer_position(event))
		show_dropdown()
		if node != null:
			node.accept_event()
	elif FGUIToolSet.is_primary_pointer_release(event) and _button_touch_index == FGUIToolSet.get_pointer_id(event):
		_down = false
		_button_touch_index = -2
		if dropdown == null or dropdown.parent == null:
			set_state(FGUIButton.OVER if _over else FGUIButton.UP)
	super._on_gui_input(event)


func _handle_roll_over() -> void:
	super._handle_roll_over()
	_over = true
	if not _down and (dropdown == null or dropdown.parent == null):
		set_state(FGUIButton.OVER)


func _handle_roll_out() -> void:
	super._handle_roll_out()
	_over = false
	if not _down and (dropdown == null or dropdown.parent == null):
		set_state(FGUIButton.UP)


func _string_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)
