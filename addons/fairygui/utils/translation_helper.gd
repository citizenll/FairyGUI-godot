class_name FGUITranslationHelper
extends RefCounted

static var strings: Dictionary = {}


static func load_from_xml(source: String) -> void:
	strings.clear()
	var parser := XMLParser.new()
	if parser.open_buffer(source.to_utf8_buffer()) != OK:
		push_error("FairyGUI translation XML could not be parsed.")
		return
	var current_key := ""
	var current_text := ""
	var in_string := false
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				if parser.get_node_name() == "string":
					current_key = parser.get_named_attribute_value_safe("name")
					current_text = ""
					in_string = true
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				if in_string:
					current_text += parser.get_node_data()
			XMLParser.NODE_ELEMENT_END:
				if in_string and parser.get_node_name() == "string":
					_add_string(current_key, current_text)
					in_string = false


static func clear() -> void:
	strings.clear()


static func translate_component(item: FGUIPackageItem) -> void:
	if item == null or item.owner == null or item.raw_data == null:
		return
	var component_strings: Dictionary = strings.get(item.owner.id + item.id, {})
	if component_strings.is_empty():
		return
	var buffer := item.raw_data
	if not buffer.seek(0, 2):
		return
	var child_count := buffer.read_i16()
	for _child_index in child_count:
		var data_length := buffer.read_i16()
		var current_position := buffer.pos
		if data_length <= 0:
			continue
		if not buffer.seek(current_position, 0):
			buffer.pos = current_position + data_length
			continue
		var base_type := buffer.read_i8()
		var object_type := base_type
		buffer.skip(4)
		var element_id := _string_or_empty(buffer.read_s())
		if object_type == FGUIEnums.OBJECT_COMPONENT and buffer.seek(current_position, 6):
			object_type = buffer.read_i8()

		if buffer.seek(current_position, 1):
			_write_if_present(buffer, component_strings, element_id + "-tips")

		if buffer.seek(current_position, 2):
			_translate_text_gears(buffer, component_strings, element_id)

		if base_type == FGUIEnums.OBJECT_COMPONENT and buffer.version >= 2 and buffer.seek(current_position, 4):
			_translate_component_properties(buffer, component_strings, element_id)

		match object_type:
			FGUIEnums.OBJECT_TEXT, FGUIEnums.OBJECT_RICH_TEXT, FGUIEnums.OBJECT_INPUT_TEXT:
				if component_strings.has(element_id) and buffer.seek(current_position, 6):
					buffer.write_s(str(component_strings[element_id]))
				if component_strings.has(element_id + "-prompt") and buffer.seek(current_position, 4):
					buffer.write_s(str(component_strings[element_id + "-prompt"]))
			FGUIEnums.OBJECT_LIST, FGUIEnums.OBJECT_TREE:
				_translate_list_items(buffer, current_position, component_strings, element_id, object_type)
			FGUIEnums.OBJECT_LABEL:
				_translate_label(buffer, current_position, component_strings, element_id, object_type)
			FGUIEnums.OBJECT_BUTTON:
				_translate_button(buffer, current_position, component_strings, element_id, object_type)
			FGUIEnums.OBJECT_COMBO_BOX:
				_translate_combo_box(buffer, current_position, component_strings, element_id, object_type)

		buffer.pos = current_position + data_length


static func _add_string(key: String, value: String) -> void:
	var separator := key.find("-")
	if separator < 0:
		return
	var component_key := key.substr(0, separator)
	var entry_key := key.substr(separator + 1)
	var component_strings: Dictionary = strings.get(component_key, {})
	component_strings[entry_key] = value
	strings[component_key] = component_strings


static func _translate_text_gears(buffer: FGUIByteBuffer, component_strings: Dictionary, element_id: String) -> void:
	var gear_count := buffer.read_i16()
	for gear_index in gear_count:
		var next_position := buffer.read_u16() + buffer.pos
		if buffer.read_i8() == 6:
			buffer.skip(2)
			var value_count := buffer.read_i16()
			for value_index in value_count:
				var page := buffer.read_s()
				if page != null:
					_write_if_present(buffer, component_strings, "%s-texts_%s" % [element_id, value_index])
			if buffer.read_bool():
				_write_if_present(buffer, component_strings, element_id + "-texts_def")
		buffer.pos = next_position


static func _translate_component_properties(buffer: FGUIByteBuffer, component_strings: Dictionary, element_id: String) -> void:
	buffer.skip(2)
	buffer.skip(4 * buffer.read_u16())
	var property_count := buffer.read_u16()
	for _property_index in property_count:
		var target := _string_or_empty(buffer.read_s())
		var property_id := buffer.read_u16()
		if property_id == FGUIEnums.OBJECT_PROP_TEXT:
			_write_if_present(buffer, component_strings, "%s-cp-%s" % [element_id, target])
		else:
			buffer.skip(2)


static func _translate_list_items(buffer: FGUIByteBuffer, current_position: int, component_strings: Dictionary, element_id: String, object_type: int) -> void:
	if not buffer.seek(current_position, 8):
		return
	buffer.skip(2)
	var item_count := buffer.read_u16()
	for item_index in item_count:
		var next_position := buffer.read_u16() + buffer.pos
		buffer.skip(2)
		if object_type == FGUIEnums.OBJECT_TREE:
			buffer.skip(2)
		_write_if_present(buffer, component_strings, "%s-%s" % [element_id, item_index])
		_write_if_present(buffer, component_strings, "%s-%s-0" % [element_id, item_index])
		if buffer.version >= 2:
			buffer.skip(6)
			buffer.skip(buffer.read_u16() * 4)
			var property_count := buffer.read_u16()
			for _property_index in property_count:
				var target := _string_or_empty(buffer.read_s())
				var property_id := buffer.read_u16()
				if property_id == FGUIEnums.OBJECT_PROP_TEXT:
					_write_if_present(buffer, component_strings, "%s-%s-%s" % [element_id, item_index, target])
				else:
					buffer.skip(2)
		buffer.pos = next_position


static func _translate_label(buffer: FGUIByteBuffer, current_position: int, component_strings: Dictionary, element_id: String, object_type: int) -> void:
	if not buffer.seek(current_position, 6) or buffer.read_i8() != object_type:
		return
	_write_if_present(buffer, component_strings, element_id)
	buffer.skip(2)
	if buffer.read_bool():
		buffer.skip(4)
	buffer.skip(4)
	if buffer.read_bool():
		_write_if_present(buffer, component_strings, element_id + "-prompt")


static func _translate_button(buffer: FGUIByteBuffer, current_position: int, component_strings: Dictionary, element_id: String, object_type: int) -> void:
	if not buffer.seek(current_position, 6) or buffer.read_i8() != object_type:
		return
	_write_if_present(buffer, component_strings, element_id)
	_write_if_present(buffer, component_strings, element_id + "-0")


static func _translate_combo_box(buffer: FGUIByteBuffer, current_position: int, component_strings: Dictionary, element_id: String, object_type: int) -> void:
	if not buffer.seek(current_position, 6) or buffer.read_i8() != object_type:
		return
	var item_count := buffer.read_i16()
	for item_index in item_count:
		var next_position := buffer.read_i16() + buffer.pos
		_write_if_present(buffer, component_strings, "%s-%s" % [element_id, item_index])
		buffer.pos = next_position
	_write_if_present(buffer, component_strings, element_id)


static func _write_if_present(buffer: FGUIByteBuffer, component_strings: Dictionary, key: String) -> void:
	if component_strings.has(key):
		buffer.write_s(str(component_strings[key]))
	else:
		buffer.skip(2)


static func _string_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)
