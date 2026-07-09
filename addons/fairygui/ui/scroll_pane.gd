class_name FGUIScrollPane
extends RefCounted

var owner: FGUIComponent
var container: ScrollContainer
var content: Control
var scroll_type: int = FGUIEnums.SCROLL_BOTH
var bounceback_effect: bool = true
var touch_effect: bool = true
var page_mode: bool = false
var content_width: float = 0.0
var content_height: float = 0.0


func _init(p_owner: FGUIComponent = null) -> void:
	owner = p_owner
	if owner != null:
		_create_nodes()


var pos_x: float:
	get:
		return container.scroll_horizontal if container != null else 0.0
	set(value):
		if container != null:
			container.scroll_horizontal = int(_clamp_x(value))


var pos_y: float:
	get:
		return container.scroll_vertical if container != null else 0.0
	set(value):
		if container != null:
			container.scroll_vertical = int(_clamp_y(value))


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
	content_width = maxf(0.0, width)
	content_height = maxf(0.0, height)
	if content != null:
		content.custom_minimum_size = Vector2(content_width, content_height)
		content.size = Vector2(content_width, content_height)
	pos_x = pos_x
	pos_y = pos_y


func scroll_to_view(obj: FGUIObject, _animated: bool = false, set_first: bool = false) -> void:
	if obj == null or container == null:
		return
	var target_x := pos_x
	var target_y := pos_y
	if set_first or obj.x < pos_x:
		target_x = obj.x
	elif obj.x + obj.width > pos_x + view_width:
		target_x = obj.x + obj.width - view_width
	if set_first or obj.y < pos_y:
		target_y = obj.y
	elif obj.y + obj.height > pos_y + view_height:
		target_y = obj.y + obj.height - view_height
	set_pos(target_x, target_y)


func set_pos(x: float, y: float, _animated: bool = false) -> void:
	if page_mode:
		x = roundf(x / maxf(view_width, 1.0)) * maxf(view_width, 1.0)
		y = roundf(y / maxf(view_height, 1.0)) * maxf(view_height, 1.0)
	pos_x = _clamp_x(x)
	pos_y = _clamp_y(y)
	_on_native_scroll()


func set_perc_x(value: float, animated: bool = false) -> void:
	set_pos((content_width - view_width) * clampf(value, 0.0, 1.0), pos_y, animated)


func set_perc_y(value: float, animated: bool = false) -> void:
	set_pos(pos_x, (content_height - view_height) * clampf(value, 0.0, 1.0), animated)


func scroll_left(ratio: float = 1.0, animated: bool = false) -> void:
	set_pos(pos_x - FGUIConfig.default_scroll_step * ratio, pos_y, animated)


func scroll_right(ratio: float = 1.0, animated: bool = false) -> void:
	set_pos(pos_x + FGUIConfig.default_scroll_step * ratio, pos_y, animated)


func scroll_up(ratio: float = 1.0, animated: bool = false) -> void:
	set_pos(pos_x, pos_y - FGUIConfig.default_scroll_step * ratio, animated)


func scroll_down(ratio: float = 1.0, animated: bool = false) -> void:
	set_pos(pos_x, pos_y + FGUIConfig.default_scroll_step * ratio, animated)


func is_right_most() -> bool:
	return pos_x >= maxf(0.0, content_width - view_width)


func is_bottom_most() -> bool:
	return pos_y >= maxf(0.0, content_height - view_height)


func current_page_x() -> int:
	return int(roundf(pos_x / maxf(view_width, 1.0)))


func current_page_y() -> int:
	return int(roundf(pos_y / maxf(view_height, 1.0)))


func set_current_page_x(value: int, animated: bool = false) -> void:
	set_pos(float(value) * view_width, pos_y, animated)


func set_current_page_y(value: int, animated: bool = false) -> void:
	set_pos(pos_x, float(value) * view_height, animated)


func handle_controller_changed(_controller: FGUIController) -> void:
	pass


func on_owner_size_changed() -> void:
	if container != null and owner != null:
		container.size = Vector2(owner.width, owner.height)
		set_pos(pos_x, pos_y)


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
	container.get_h_scroll_bar().value_changed.connect(func(_value: float) -> void: _on_native_scroll())
	container.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _on_native_scroll())
	owner.node.add_child(container)


func _clamp_x(value: float) -> float:
	return clampf(value, 0.0, maxf(0.0, content_width - view_width))


func _clamp_y(value: float) -> float:
	return clampf(value, 0.0, maxf(0.0, content_height - view_height))


func _on_native_scroll() -> void:
	if owner is FGUIList and owner._virtual and not owner._refreshing_virtual:
		owner.refresh_virtual_list()
	if owner != null:
		owner.emit_event(FGUIEvents.SCROLL)
