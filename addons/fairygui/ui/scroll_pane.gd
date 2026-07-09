class_name FGUIScrollPane
extends RefCounted

var owner: FGUIComponent
var container: ScrollContainer
var content: Control
var scroll_type: int = FGUIEnums.SCROLL_BOTH
var bounceback_effect: bool = true
var touch_effect: bool = true
var page_mode: bool = false


func _init(p_owner: FGUIComponent = null) -> void:
	owner = p_owner
	if owner != null:
		_create_nodes()


var pos_x: float:
	get:
		return container.scroll_horizontal if container != null else 0.0
	set(value):
		if container != null:
			container.scroll_horizontal = int(value)


var pos_y: float:
	get:
		return container.scroll_vertical if container != null else 0.0
	set(value):
		if container != null:
			container.scroll_vertical = int(value)


var view_width: float:
	get:
		return owner.width if owner != null else 0.0
	set(value):
		if owner != null:
			owner.width = value


var view_height: float:
	get:
		return owner.height if owner != null else 0.0
	set(value):
		if owner != null:
			owner.height = value


func setup(buffer: FGUIByteBuffer) -> void:
	scroll_type = buffer.read_i8()
	buffer.read_i8()
	buffer.read_i8()
	buffer.read_i8()
	buffer.read_bool()
	buffer.read_bool()
	bounceback_effect = buffer.read_bool()
	touch_effect = buffer.read_bool()
	page_mode = buffer.read_bool()
	if buffer.read_bool():
		buffer.skip(8)
	if buffer.read_bool():
		buffer.skip(8)
	if buffer.read_bool():
		buffer.skip(8)
	if buffer.read_bool():
		buffer.skip(8)
	if buffer.read_bool():
		buffer.skip(4)


func set_content_size(width: float, height: float) -> void:
	if content != null:
		content.custom_minimum_size = Vector2(width, height)
		content.size = Vector2(maxf(content.size.x, width), maxf(content.size.y, height))


func scroll_to_view(obj: FGUIObject, _animated: bool = false, _set_first: bool = false) -> void:
	if obj == null or container == null:
		return
	container.scroll_horizontal = int(obj.x)
	container.scroll_vertical = int(obj.y)


func set_pos(x: float, y: float, _animated: bool = false) -> void:
	pos_x = x
	pos_y = y


func handle_controller_changed(_controller: FGUIController) -> void:
	pass


func on_owner_size_changed() -> void:
	if container != null and owner != null:
		container.size = Vector2(owner.width, owner.height)


func dispose() -> void:
	if container != null:
		container.queue_free()
	container = null
	content = null


func _create_nodes() -> void:
	container = ScrollContainer.new()
	container.name = "ScrollPane"
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.size = Vector2(owner.width, owner.height)
	content = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(content)
	owner.node.add_child(container)

