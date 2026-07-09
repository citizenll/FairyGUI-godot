class_name FGUIController
extends RefCounted

var parent: FGUIComponent
var name: String = ""
var _selected_index: int = -1
var previous_index: int = -1
var selected_index: int:
	get:
		return _selected_index
	set(value):
		if value >= page_ids.size():
			value = page_ids.size() - 1
		if value < -1:
			value = -1
		if _selected_index == value:
			return
		previous_index = _selected_index
		_selected_index = value
		if parent != null:
			parent.apply_controller(self)
var _selected_page_id: String = ""
var changing: bool = false
var auto_radio_group_depth: bool = false
var selected_page_id: String:
	set(value):
		_selected_page_id = value
		var index := page_ids.find(value)
		if index != -1:
			selected_index = index
	get:
		return page_ids[_selected_index] if _selected_index >= 0 and _selected_index < page_ids.size() else ""
var selected_page: String:
	get:
		return page_names[_selected_index] if _selected_index >= 0 and _selected_index < page_names.size() else ""
	set(value):
		var index := page_names.find(value)
		if index != -1:
			selected_index = index
var previous_page: String:
	get:
		return page_names[previous_index] if previous_index >= 0 and previous_index < page_names.size() else ""
var page_count: int:
	get:
		return page_ids.size()
var page_ids: Array = []
var page_names: Array = []


func setup(buffer: FGUIByteBuffer) -> void:
	var begin_pos := buffer.pos
	if not buffer.seek(begin_pos, 0):
		return
	name = _string_or_empty(buffer.read_s())
	auto_radio_group_depth = buffer.read_bool()

	if not buffer.seek(begin_pos, 1):
		return
	var count := buffer.read_i16()
	for i in count:
		page_ids.append(buffer.read_s())
		page_names.append(buffer.read_s())

	var home_page_index := 0
	if buffer.version >= 2:
		var home_page_type := buffer.read_i8()
		match home_page_type:
			1:
				home_page_index = buffer.read_i16()
			2:
				home_page_index = max(0, page_names.find(FGUIPackage.get_var("branch")))
			3:
				home_page_index = max(0, page_names.find(FGUIPackage.get_var(_string_or_empty(buffer.read_s()))))

	if buffer.seek(begin_pos, 2):
		count = buffer.read_i16()
		for i in count:
			var next_pos := buffer.read_i16() + buffer.pos
			buffer.pos = next_pos
	if auto_radio_group_depth:
		pass
	selected_index = home_page_index if page_ids.size() > 0 else -1


func has_page(page_name: String) -> bool:
	return page_names.has(page_name)


func has_page_id(page_id: String) -> bool:
	return page_ids.has(page_id)


func set_selected_index(value: int) -> void:
	selected_index = value


func get_page_id(index: int) -> String:
	return page_ids[index] if index >= 0 and index < page_ids.size() else ""


func get_page_name(index: int) -> String:
	return page_names[index] if index >= 0 and index < page_names.size() else ""


func get_page_index_by_id(page_id: String) -> int:
	return page_ids.find(page_id)


func get_page_id_by_name(page_name: String) -> String:
	var index := page_names.find(page_name)
	return get_page_id(index)


func _string_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)
