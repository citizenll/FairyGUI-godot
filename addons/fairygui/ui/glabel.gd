class_name FGUILabel
extends FGUIComponent

var _title_object: FGUIObject
var _icon_object: FGUIObject

var title: String:
	get:
		return _title_object.get_text() if _title_object != null else ""
	set(value):
		if _title_object != null:
			_title_object.set_text(value)
		update_gear(6)
var icon: String:
	get:
		return _icon_object.get_icon() if _icon_object != null else ""
	set(value):
		if _icon_object != null:
			_icon_object.set_icon(value)
		update_gear(7)
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


func construct_extension(_buffer: FGUIByteBuffer) -> void:
	_title_object = get_child("title")
	_icon_object = get_child("icon")


func get_text() -> String:
	return title


func set_text(value: String) -> void:
	title = value


func get_icon() -> String:
	return icon


func set_icon(value: String) -> void:
	icon = value


func get_text_field() -> FGUITextField:
	if _title_object is FGUITextField:
		return _title_object
	if _title_object != null and _title_object.has_method("get_text_field"):
		return _title_object.call("get_text_field")
	return null


func setup_after_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_after_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 6):
		return
	if buffer.read_i8() != package_item.object_type:
		return
	var next_title = buffer.read_s()
	if next_title != null:
		title = str(next_title)
	var next_icon = buffer.read_s()
	if next_icon != null:
		icon = str(next_icon)
	if buffer.read_bool():
		title_color = buffer.read_color()
	var size := buffer.read_i32()
	if size != 0:
		title_font_size = size


func get_prop(index: int) -> Variant:
	match index:
		FGUIEnums.OBJECT_PROP_TEXT:
			return title
		FGUIEnums.OBJECT_PROP_ICON:
			return icon
		FGUIEnums.OBJECT_PROP_COLOR:
			return title_color
		FGUIEnums.OBJECT_PROP_FONT_SIZE:
			return title_font_size
		_:
			return super.get_prop(index)


func set_prop(index: int, value: Variant) -> void:
	match index:
		FGUIEnums.OBJECT_PROP_TEXT:
			title = str(value)
		FGUIEnums.OBJECT_PROP_ICON:
			icon = str(value)
		FGUIEnums.OBJECT_PROP_COLOR:
			if value is Color:
				title_color = value
		FGUIEnums.OBJECT_PROP_FONT_SIZE:
			title_font_size = int(value)
		_:
			super.set_prop(index, value)
