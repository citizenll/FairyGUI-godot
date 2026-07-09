class_name FGUILoader
extends FGUIObject

var texture_rect: TextureRect
var content_component: FGUIComponent
var content_item: FGUIPackageItem
var align: int = FGUIEnums.ALIGN_LEFT:
	set(value):
		align = value
		update_layout()
var valign: int = FGUIEnums.VERT_ALIGN_TOP:
	set(value):
		valign = value
		update_layout()
var fill: int = FGUIEnums.LOADER_FILL_NONE:
	set(value):
		fill = value
		update_layout()
var shrink_only: bool = false:
	set(value):
		shrink_only = value
		update_layout()
var auto_size: bool = false:
	set(value):
		auto_size = value
		update_layout()
var use_resize: bool = false:
	set(value):
		use_resize = value
		update_layout()
var show_error_sign: bool = true
var playing: bool = true
var frame: int = 0
var time_scale: float = 1.0
var color: Color = Color.WHITE:
	set(value):
		color = value
		if texture_rect != null:
			texture_rect.modulate = value
var fill_method: int = FGUIEnums.FILL_NONE
var fill_origin: int = 0
var fill_clockwise: bool = true
var fill_amount: float = 1.0

var _url: String = ""
var _updating_layout: bool = false
var url: String:
	set(value):
		if _url == value:
			return
		_url = value
		_load_url()
		update_gear(7)
	get:
		return _url


func _create_display_object() -> void:
	node = Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_PASS
	texture_rect = TextureRect.new()
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	node.add_child(texture_rect)


func dispose() -> void:
	_clear_content()
	super.dispose()


func get_icon() -> String:
	return url


func set_icon(value: String) -> void:
	url = value


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
	show_error_sign = buffer.read_bool()
	playing = buffer.read_bool()
	frame = buffer.read_i32()
	if buffer.read_bool():
		color = buffer.read_color()
	fill_method = buffer.read_i8()
	if fill_method != FGUIEnums.FILL_NONE:
		fill_origin = buffer.read_i8()
		fill_clockwise = buffer.read_bool()
		fill_amount = buffer.read_float32()
	if buffer.version >= 7:
		use_resize = buffer.read_bool()
	if _url != "":
		_load_url()


func update_layout() -> void:
	if texture_rect == null or _updating_layout:
		return
	var content_size := Vector2(source_width, source_height)
	if content_size.x <= 0.0:
		content_size.x = 50.0
	if content_size.y <= 0.0:
		content_size.y = 30.0

	if auto_size:
		_updating_layout = true
		set_size(content_size.x, content_size.y)
		_updating_layout = false

	var target_size := content_size
	var sx := 1.0
	var sy := 1.0
	if fill != FGUIEnums.LOADER_FILL_NONE and content_size.x > 0.0 and content_size.y > 0.0:
		sx = width / content_size.x
		sy = height / content_size.y
		match fill:
			FGUIEnums.LOADER_FILL_SCALE_MATCH_HEIGHT:
				sx = sy
			FGUIEnums.LOADER_FILL_SCALE_MATCH_WIDTH:
				sy = sx
			FGUIEnums.LOADER_FILL_SCALE:
				var min_scale := minf(sx, sy)
				sx = min_scale
				sy = min_scale
			FGUIEnums.LOADER_FILL_SCALE_NO_BORDER:
				var max_scale := maxf(sx, sy)
				sx = max_scale
				sy = max_scale
			FGUIEnums.LOADER_FILL_SCALE_FREE:
				pass
		if shrink_only:
			sx = minf(sx, 1.0)
			sy = minf(sy, 1.0)
		target_size = Vector2(content_size.x * sx, content_size.y * sy)

	var position := Vector2.ZERO
	match align:
		FGUIEnums.ALIGN_CENTER:
			position.x = floorf((width - target_size.x) * 0.5)
		FGUIEnums.ALIGN_RIGHT:
			position.x = width - target_size.x
	match valign:
		FGUIEnums.VERT_ALIGN_MIDDLE:
			position.y = floorf((height - target_size.y) * 0.5)
		FGUIEnums.VERT_ALIGN_BOTTOM:
			position.y = height - target_size.y

	if content_component != null:
		content_component.set_xy(position.x, position.y)
		if use_resize:
			content_component.set_size(target_size.x, target_size.y)
		else:
			content_component.set_scale(sx, sy)
	else:
		texture_rect.position = position
		texture_rect.size = target_size


func _load_url() -> void:
	_clear_content()
	if url == "":
		return
	if url.begins_with("ui://"):
		_load_from_package(url)
	else:
		_load_external(url)


func _load_from_package(item_url: String) -> void:
	content_item = FGUIPackage.get_item_by_url(item_url)
	if content_item == null:
		_set_error_state()
		return
	content_item = content_item.get_branch().get_high_resolution()
	content_item.load()
	source_width = content_item.width
	source_height = content_item.height
	match content_item.type:
		FGUIEnums.PACKAGE_ITEM_IMAGE, FGUIEnums.PACKAGE_ITEM_ATLAS:
			texture_rect.texture = content_item.texture
			if texture_rect.texture == null:
				_set_error_state()
			else:
				update_layout()
		FGUIEnums.PACKAGE_ITEM_MOVIE_CLIP:
			if content_item.frames.is_empty():
				_set_error_state()
			else:
				texture_rect.texture = content_item.frames[0].get("texture")
				update_layout()
		FGUIEnums.PACKAGE_ITEM_COMPONENT:
			var obj := FGUIPackage.create_object_from_url(item_url)
			if obj is FGUIComponent:
				content_component = obj
				texture_rect.visible = false
				node.add_child(content_component.node)
				update_layout()
			else:
				if obj != null:
					obj.dispose()
				_set_error_state()
		_:
			_set_error_state()


func _load_external(path: String) -> void:
	var resource := load(path)
	if resource is Texture2D:
		texture_rect.texture = resource
		source_width = resource.get_width()
		source_height = resource.get_height()
		update_layout()
	else:
		_set_error_state()


func _clear_content() -> void:
	if texture_rect != null:
		texture_rect.texture = null
		texture_rect.visible = true
	if content_component != null:
		content_component.dispose()
		content_component = null
	content_item = null


func _set_error_state() -> void:
	if show_error_sign:
		push_warning("FairyGUI loader content not found or unsupported: %s" % url)


func _handle_size_changed() -> void:
	super._handle_size_changed()
	update_layout()
