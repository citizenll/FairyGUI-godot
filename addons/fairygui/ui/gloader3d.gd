class_name FGUILoader3D
extends FGUIObject

static var content_factory: Callable = Callable()

var content: Node
var content_item: FGUIPackageItem
var canvas_host: Node2D
var control_host: Control
var viewport_container: SubViewportContainer
var viewport: SubViewport
var _content_size: Vector2 = Vector2.ZERO
var _owns_content: bool = true
var _updating_layout: bool = false
var _url: String = ""
var _align: int = FGUIEnums.ALIGN_LEFT
var _valign: int = FGUIEnums.VERT_ALIGN_TOP
var _fill: int = FGUIEnums.LOADER_FILL_NONE
var _shrink_only: bool = false
var _auto_size: bool = false
var _playing: bool = true
var _frame: int = 0
var _loop: bool = false
var _animation_name: String = ""
var _skin_name: String = ""
var _time_scale: float = 1.0
var _color: Color = Color.WHITE

var url: String:
	get:
		return _url
	set(value):
		if _url == value:
			return
		_url = value
		_load_content()
		update_gear(7)
var icon: String:
	get:
		return _url
	set(value):
		url = value
var align: int:
	get:
		return _align
	set(value):
		_align = value
		update_layout()
var valign: int:
	get:
		return _valign
	set(value):
		_valign = value
		update_layout()
var fill: int:
	get:
		return _fill
	set(value):
		_fill = value
		update_layout()
var shrink_only: bool:
	get:
		return _shrink_only
	set(value):
		_shrink_only = value
		update_layout()
var auto_size: bool:
	get:
		return _auto_size
	set(value):
		_auto_size = value
		update_layout()
var playing: bool:
	get:
		return _playing
	set(value):
		_playing = value
		_apply_animation_state()
		update_gear(5)
var frame: int:
	get:
		return _frame
	set(value):
		_frame = maxi(0, value)
		_apply_animation_state()
		update_gear(5)
var loop: bool:
	get:
		return _loop
	set(value):
		_loop = value
		_apply_animation_state()
var animation_name: String:
	get:
		return _animation_name
	set(value):
		_animation_name = value
		_apply_animation_state()
		update_gear(5)
var skin_name: String:
	get:
		return _skin_name
	set(value):
		_skin_name = value
		_apply_skin()
		update_gear(5)
var time_scale: float:
	get:
		return _time_scale
	set(value):
		_time_scale = maxf(0.0001, value)
		_apply_animation_state()
		update_gear(5)
var color: Color:
	get:
		return _color
	set(value):
		_color = value
		_apply_color()
		update_gear(4)
var content_size: Vector2:
	get:
		return _content_size


static func set_content_factory(factory: Callable) -> void:
	content_factory = factory


static func set_skeleton_factory(factory: Callable) -> void:
	set_content_factory(factory)


func _create_display_object() -> void:
	node = Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas_host = Node2D.new()
	canvas_host.visible = false
	node.add_child(canvas_host)
	control_host = Control.new()
	control_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control_host.visible = false
	node.add_child(control_host)
	viewport_container = SubViewportContainer.new()
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport_container.stretch = false
	viewport_container.visible = false
	node.add_child(viewport_container)
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport_container.add_child(viewport)


func dispose() -> void:
	_clear_content()
	super.dispose()


func get_icon() -> String:
	return url


func set_icon(value: String) -> void:
	url = value


func set_content(next_content: Node, next_content_size: Vector2 = Vector2.ZERO, owns_content: bool = true) -> void:
	_clear_content()
	if next_content == null:
		return
	content = next_content
	_owns_content = owns_content
	_content_size = next_content_size if next_content_size.x > 0.0 and next_content_size.y > 0.0 else _measure_content(next_content)
	if _content_size.x > 0.0:
		source_width = _content_size.x
	if _content_size.y > 0.0:
		source_height = _content_size.y
	_attach_content(next_content)
	_apply_color()
	_apply_animation_state()
	_apply_skin()
	update_layout()


func advance(time: float) -> void:
	var animation_player := _find_animation_player(content)
	if animation_player != null:
		animation_player.advance(maxf(0.0, time) * _time_scale)
	elif content != null and content.has_method("advance"):
		content.call("advance", maxf(0.0, time) * _time_scale)


func get_prop(index: int) -> Variant:
	match index:
		FGUIEnums.OBJECT_PROP_COLOR:
			return color
		FGUIEnums.OBJECT_PROP_PLAYING:
			return playing
		FGUIEnums.OBJECT_PROP_FRAME:
			return frame
		FGUIEnums.OBJECT_PROP_TIME_SCALE:
			return time_scale
		_:
			return super.get_prop(index)


func set_prop(index: int, value: Variant) -> void:
	match index:
		FGUIEnums.OBJECT_PROP_COLOR:
			if value is Color:
				color = value
		FGUIEnums.OBJECT_PROP_PLAYING:
			playing = bool(value)
		FGUIEnums.OBJECT_PROP_FRAME:
			frame = int(value)
		FGUIEnums.OBJECT_PROP_TIME_SCALE:
			time_scale = float(value)
		_:
			super.set_prop(index, value)


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_before_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 5):
		return
	var next_url = buffer.read_s()
	if next_url != null:
		_url = str(next_url)
	align = buffer.read_i8()
	valign = buffer.read_i8()
	fill = buffer.read_i8()
	shrink_only = buffer.read_bool()
	auto_size = buffer.read_bool()
	_animation_name = _string_or_empty(buffer.read_s())
	_skin_name = _string_or_empty(buffer.read_s())
	_playing = buffer.read_bool()
	_frame = maxi(0, buffer.read_i32())
	_loop = buffer.read_bool()
	if buffer.read_bool():
		_color = buffer.read_color()
	if _url != "":
		_load_content()


func update_layout() -> void:
	if _updating_layout:
		return
	var next_size := _content_size
	if next_size.x <= 0.0:
		next_size.x = source_width
	if next_size.y <= 0.0:
		next_size.y = source_height
	if next_size.x <= 0.0:
		next_size.x = 50.0
	if next_size.y <= 0.0:
		next_size.y = 30.0
	if _auto_size:
		_updating_layout = true
		set_size(next_size.x, next_size.y)
		_updating_layout = false
	var scale := Vector2.ONE
	if _fill != FGUIEnums.LOADER_FILL_NONE and next_size.x > 0.0 and next_size.y > 0.0:
		scale = Vector2(width / next_size.x, height / next_size.y)
		match _fill:
			FGUIEnums.LOADER_FILL_SCALE_MATCH_HEIGHT:
				scale.x = scale.y
			FGUIEnums.LOADER_FILL_SCALE_MATCH_WIDTH:
				scale.y = scale.x
			FGUIEnums.LOADER_FILL_SCALE:
				var match_scale := minf(scale.x, scale.y)
				scale = Vector2(match_scale, match_scale)
			FGUIEnums.LOADER_FILL_SCALE_NO_BORDER:
				var cover_scale := maxf(scale.x, scale.y)
				scale = Vector2(cover_scale, cover_scale)
		if _shrink_only:
			scale.x = minf(scale.x, 1.0)
			scale.y = minf(scale.y, 1.0)
	var target_size := next_size * scale
	var position := Vector2.ZERO
	match _align:
		FGUIEnums.ALIGN_CENTER:
			position.x = floorf((width - target_size.x) * 0.5)
		FGUIEnums.ALIGN_RIGHT:
			position.x = width - target_size.x
	match _valign:
		FGUIEnums.VERT_ALIGN_MIDDLE:
			position.y = floorf((height - target_size.y) * 0.5)
		FGUIEnums.VERT_ALIGN_BOTTOM:
			position.y = height - target_size.y
	_apply_content_layout(position, scale, next_size)


func _load_content() -> void:
	_clear_content()
	if _url == "":
		return
	if _url.begins_with("ui://"):
		_load_from_package(_url)
	else:
		_load_external(_url)


func _load_from_package(item_url: String) -> void:
	var item := FGUIPackage.get_item_by_url(item_url)
	if item == null:
		_set_error_state()
		return
	var branch_item := item.get_branch()
	source_width = branch_item.width
	source_height = branch_item.height
	content_item = branch_item.get_high_resolution()
	var resolved_item := content_item
	var source_size := Vector2(source_width, source_height)
	var result := _create_factory_content(resolved_item)
	if _install_factory_result(result, source_size):
		content_item = resolved_item
		return
	if content_item.file != "":
		_load_external(content_item.file)
		return
	_set_error_state()


func _load_external(path: String) -> void:
	if path.begins_with("http://") or path.begins_with("https://"):
		_set_error_state()
		return
	var resource := ResourceLoader.load(path)
	if resource is PackedScene:
		set_content((resource as PackedScene).instantiate())
		return
	if _install_factory_result(_create_factory_content(path)):
		return
	_set_error_state()


func _create_factory_content(source: Variant) -> Variant:
	return content_factory.call(source) if content_factory.is_valid() else null


func _install_factory_result(result: Variant, fallback_size: Vector2 = Vector2.ZERO) -> bool:
	if result is Node:
		set_content(result, fallback_size)
		return true
	if result is Dictionary:
		var next_content = result.get("node")
		if next_content is Node:
			var next_size: Vector2 = result.get("size", Vector2.ZERO)
			if next_size.x <= 0.0 or next_size.y <= 0.0:
				next_size = fallback_size
			set_content(next_content, next_size, bool(result.get("owns_content", true)))
			return true
	return false


func _attach_content(next_content: Node) -> void:
	if next_content.get_parent() != null:
		next_content.get_parent().remove_child(next_content)
	canvas_host.visible = false
	control_host.visible = false
	viewport_container.visible = false
	if next_content is Node3D:
		viewport.add_child(next_content)
		viewport_container.visible = true
	elif next_content is Control:
		control_host.add_child(next_content)
		control_host.visible = true
	else:
		canvas_host.add_child(next_content)
		canvas_host.visible = true


func _clear_content() -> void:
	if content != null:
		if content.get_parent() != null:
			content.get_parent().remove_child(content)
		if _owns_content:
			if content.is_inside_tree():
				content.queue_free()
			else:
				content.free()
	content = null
	content_item = null
	_content_size = Vector2.ZERO
	_owns_content = true
	if canvas_host != null:
		canvas_host.visible = false
	if control_host != null:
		control_host.visible = false
	if viewport_container != null:
		viewport_container.visible = false


func _apply_content_layout(position: Vector2, scale: Vector2, unscaled_size: Vector2) -> void:
	if content == null:
		return
	if content is Node3D:
		viewport_container.position = position
		viewport_container.size = unscaled_size
		viewport_container.scale = scale
		viewport.size = Vector2i(maxi(1, roundi(unscaled_size.x)), maxi(1, roundi(unscaled_size.y)))
	elif content is Control:
		control_host.position = position
		control_host.scale = scale
		control_host.size = unscaled_size
		var control_content := content as Control
		if control_content.size == Vector2.ZERO:
			control_content.size = unscaled_size
	else:
		canvas_host.position = position
		canvas_host.scale = scale


func _measure_content(next_content: Node) -> Vector2:
	if next_content is Control:
		return (next_content as Control).size
	if next_content is Sprite2D and (next_content as Sprite2D).texture != null:
		return (next_content as Sprite2D).texture.get_size()
	return Vector2.ZERO


func _apply_color() -> void:
	if canvas_host != null:
		canvas_host.modulate = _color
	if control_host != null:
		control_host.modulate = _color
	if viewport_container != null:
		viewport_container.modulate = _color


func _apply_animation_state() -> void:
	var animation_player := _find_animation_player(content)
	if animation_player != null:
		animation_player.speed_scale = _time_scale
		if _animation_name != "" and animation_player.has_animation(_animation_name):
			animation_player.play(_animation_name)
			if not _playing:
				animation_player.pause()
				animation_player.seek(float(_frame) / 60.0, true)
	elif content != null:
		_set_content_property("playing", _playing)
		_set_content_property("frame", _frame)
		_set_content_property("time_scale", _time_scale)
		_set_content_property("speed_scale", _time_scale)
		_set_content_property("loop", _loop)
		if _animation_name != "":
			if content.has_method("set_animation"):
				content.call("set_animation", _animation_name)
			else:
				_set_content_property("animation", _animation_name)


func _apply_skin() -> void:
	if content == null or _skin_name == "":
		return
	if content.has_method("show_skin_by_name"):
		content.call("show_skin_by_name", _skin_name)
	elif content.has_method("set_skin"):
		content.call("set_skin", _skin_name)
	elif content.has_method("set_skin_name"):
		content.call("set_skin_name", _skin_name)
	else:
		_set_content_property("skin", _skin_name)


func _set_content_property(property_name: String, value: Variant) -> void:
	if content == null:
		return
	for property in content.get_property_list():
		if str(property.get("name", "")) == property_name:
			content.set(property_name, value)
			return


func _find_animation_player(current: Node) -> AnimationPlayer:
	if current == null:
		return null
	if current is AnimationPlayer:
		return current as AnimationPlayer
	for child in current.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _handle_size_changed() -> void:
	super._handle_size_changed()
	update_layout()


func _set_error_state() -> void:
	push_warning("FairyGUI Loader3D content not found or unsupported: %s" % _url)


func _string_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)
