class_name FGUIComboBox
extends FGUIComponent

var dropdown: FGUIComponent
var items: Array[String] = []:
	set(value):
		items = value
		if selected_index < 0 and not items.is_empty():
			selected_index = 0
var icons: Array[String] = []
var values: Array[String] = []
var visible_item_count: int = 0
var popup_direction: int = FGUIEnums.POPUP_AUTO
var selection_controller: FGUIController

var _title_object: FGUIObject
var _icon_object: FGUIObject
var _list: FGUIList
var _selected_index: int = -1

var selected_index: int:
	get:
		return _selected_index
	set(value):
		if _selected_index == value:
			return
		_selected_index = value
		if _selected_index >= 0 and _selected_index < items.size():
			set_text(items[_selected_index])
			if _selected_index < icons.size():
				set_icon(icons[_selected_index])
		else:
			set_text("")
			set_icon("")
		if selection_controller != null and _selected_index < selection_controller.page_count:
			selection_controller.selected_index = _selected_index
var value: String:
	get:
		return values[_selected_index] if _selected_index >= 0 and _selected_index < values.size() else ""
	set(next_value):
		selected_index = values.find(next_value)


func dispose() -> void:
	if dropdown != null:
		dropdown.dispose()
		dropdown = null
	_list = null
	_title_object = null
	_icon_object = null
	selection_controller = null
	super.dispose()


func construct_extension(buffer: FGUIByteBuffer) -> void:
	_title_object = get_child("title")
	_icon_object = get_child("icon")
	if buffer.seek(0, 6):
		var dropdown_url = buffer.read_s()
		if dropdown_url != null and dropdown_url != "":
			var obj := FGUIPackage.create_object_from_url(str(dropdown_url))
			if obj is FGUIComponent:
				dropdown = obj
				_list = dropdown.get_child("list") as FGUIList


func get_text() -> String:
	return _title_object.get_text() if _title_object != null else ""


func set_text(value: String) -> void:
	if _title_object != null:
		_title_object.set_text(value)


func get_icon() -> String:
	return _icon_object.get_icon() if _icon_object != null else ""


func set_icon(value: String) -> void:
	if _icon_object != null:
		_icon_object.set_icon(value)


func setup_after_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_after_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 6):
		return
	if buffer.read_i8() != package_item.object_type:
		return
	var item_count := buffer.read_i16()
	for i in item_count:
		var next_pos := buffer.read_i16() + buffer.pos
		items.append(_string_or_empty(buffer.read_s()))
		values.append(_string_or_empty(buffer.read_s()))
		var icon_value = buffer.read_s()
		if icon_value != null:
			icons.append(str(icon_value))
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


func get_text_field() -> FGUITextField:
	if _title_object is FGUITextField:
		return _title_object
	if _title_object != null and _title_object.has_method("get_text_field"):
		return _title_object.call("get_text_field")
	return null


func _on_gui_input(event: InputEvent) -> void:
	super._on_gui_input(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if dropdown != null:
			FGUIRoot.get_inst().show_popup(dropdown, self, popup_direction)


func _string_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)
