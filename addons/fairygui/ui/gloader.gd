class_name FGUILoader
extends FGUIObject

const FillRenderer := preload("res://addons/fairygui/ui/fill_renderer.gd")

var texture_rect: TextureRect
var fill_renderer
var content_component: FGUIComponent
var content_movie_clip: FGUIMovieClip
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
var _show_error_sign: bool = true
var show_error_sign: bool:
	get:
		return _show_error_sign
	set(value):
		_show_error_sign = value
		if not _show_error_sign:
			_clear_error_state()
var _playing: bool = true
var playing: bool:
	get:
		return _playing
	set(value):
		_playing = value
		if content_movie_clip != null:
			content_movie_clip.playing = value
var _frame: int = 0
var frame: int:
	get:
		return _frame
	set(value):
		_frame = maxi(0, value)
		if content_movie_clip != null:
			content_movie_clip.frame = _frame
var _time_scale: float = 1.0
var time_scale: float:
	get:
		return _time_scale
	set(value):
		_time_scale = maxf(0.0001, value)
		if content_movie_clip != null:
			content_movie_clip.time_scale = _time_scale
var color: Color = Color.WHITE:
	set(value):
		color = value
		if texture_rect != null:
			texture_rect.modulate = value
		if fill_renderer != null:
			fill_renderer.modulate = value
var fill_method: int = FGUIEnums.FILL_NONE:
	set(value):
		fill_method = value
		_apply_fill()
var fill_origin: int = 0:
	set(value):
		fill_origin = value
		_apply_fill()
var fill_clockwise: bool = true:
	set(value):
		fill_clockwise = value
		_apply_fill()
var fill_amount: float = 1.0:
	set(value):
		fill_amount = clampf(value, 0.0, 1.0)
		_apply_fill()

var _url: String = ""
var _updating_layout: bool = false
var _http_request: HTTPRequest
var _pending_external_url: String = ""
var _load_serial: int = 0
var _active_request_serial: int = -1
var _error_sign: FGUIObject
var _error_sign_pool := FGUIObjectPool.new()
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
	node.tree_entered.connect(_on_display_object_entered_tree)
	texture_rect = TextureRect.new()
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	node.add_child(texture_rect)
	fill_renderer = FillRenderer.new()
	fill_renderer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_renderer.visible = false
	node.add_child(fill_renderer)


func dispose() -> void:
	_clear_content()
	_error_sign_pool.clear()
	if _http_request != null and is_instance_valid(_http_request):
		if _http_request.get_parent() != null:
			_http_request.get_parent().remove_child(_http_request)
		_http_request.queue_free()
	_http_request = null
	super.dispose()


func get_icon() -> String:
	return url


func set_icon(value: String) -> void:
	url = value


func advance(time: float) -> void:
	if content_movie_clip != null:
		content_movie_clip.advance(maxf(0.0, time))


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
		FGUIEnums.OBJECT_PROP_DELTA_TIME:
			advance(float(value) / 1000.0)
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

	var content_object: FGUIObject = content_component if content_component != null else content_movie_clip
	if content_object != null:
		content_object.set_xy(position.x, position.y)
		if use_resize:
			content_object.set_scale(1.0, 1.0)
			content_object.set_size(target_size.x, target_size.y)
		else:
			content_object.set_scale(sx, sy)
	else:
		texture_rect.position = position
		texture_rect.size = target_size
		fill_renderer.position = position
		fill_renderer.size = target_size


func _load_url() -> void:
	_load_serial += 1
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
			_set_texture(content_item.texture)
			if texture_rect.texture == null:
				_set_error_state()
			else:
				update_layout()
		FGUIEnums.PACKAGE_ITEM_MOVIE_CLIP:
			var obj := FGUIPackage.create_object_from_url(item_url)
			if obj is FGUIMovieClip:
				content_movie_clip = obj
				content_movie_clip.playing = _playing
				content_movie_clip.frame = _frame
				content_movie_clip.time_scale = _time_scale
				texture_rect.visible = false
				node.add_child(content_movie_clip.node)
				update_layout()
			else:
				if obj != null:
					obj.dispose()
				_set_error_state()
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
	if path.begins_with("http://") or path.begins_with("https://"):
		_pending_external_url = path
		_start_http_request()
		return
	var resource := load(path)
	if resource is Texture2D:
		_set_texture(resource)
		source_width = resource.get_width()
		source_height = resource.get_height()
		update_layout()
		return
	var image := Image.load_from_file(path)
	if image != null and not image.is_empty():
		_set_texture(ImageTexture.create_from_image(image))
		source_width = image.get_width()
		source_height = image.get_height()
		update_layout()
		return
	_set_error_state()


func _clear_content() -> void:
	_cancel_external_request()
	_clear_error_state()
	if texture_rect != null:
		_set_texture(null)
	if content_component != null:
		content_component.dispose()
		content_component = null
	if content_movie_clip != null:
		content_movie_clip.dispose()
		content_movie_clip = null
	content_item = null


func _on_display_object_entered_tree() -> void:
	if _pending_external_url != "" and _pending_external_url == _url:
		_start_http_request()


func _start_http_request() -> void:
	if _pending_external_url == "" or node == null or not node.is_inside_tree():
		return
	if _http_request == null or not is_instance_valid(_http_request):
		_http_request = HTTPRequest.new()
		_http_request.request_completed.connect(_on_http_request_completed)
		node.add_child(_http_request)
	var request_error := _http_request.request(_pending_external_url)
	if request_error != OK:
		_pending_external_url = ""
		_active_request_serial = -1
		_set_error_state()
		return
	_active_request_serial = _load_serial


func _cancel_external_request() -> void:
	_pending_external_url = ""
	_active_request_serial = -1
	if _http_request != null and is_instance_valid(_http_request):
		_http_request.cancel_request()


func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var request_url := _pending_external_url
	var request_serial := _active_request_serial
	_pending_external_url = ""
	_active_request_serial = -1
	if request_serial != _load_serial or request_url == "" or request_url != _url:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_set_error_state()
		return
	var texture := _decode_external_texture(body, request_url)
	if texture == null:
		_set_error_state()
		return
	_set_texture(texture)
	source_width = texture.get_width()
	source_height = texture.get_height()
	update_layout()


func _decode_external_texture(data: PackedByteArray, source: String) -> Texture2D:
	if data.is_empty():
		return null
	var image := Image.new()
	var source_path := source.get_slice("?", 0).get_slice("#", 0)
	var extension := source_path.get_extension().to_lower()
	var error := ERR_FILE_UNRECOGNIZED
	match extension:
		"png":
			error = image.load_png_from_buffer(data)
		"jpg", "jpeg":
			error = image.load_jpg_from_buffer(data)
		"webp":
			error = image.load_webp_from_buffer(data)
		"bmp":
			error = image.load_bmp_from_buffer(data)
		"tga":
			error = image.load_tga_from_buffer(data)
		"svg":
			error = image.load_svg_from_buffer(data)
	if error != OK:
		error = image.load_png_from_buffer(data)
	if error != OK:
		error = image.load_jpg_from_buffer(data)
	if error != OK:
		error = image.load_webp_from_buffer(data)
	if error != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _set_error_state() -> void:
	if not _show_error_sign:
		return
	if _error_sign == null and FGUIConfig.loader_error_sign != "":
		_error_sign = _error_sign_pool.get_object(FGUIConfig.loader_error_sign)
	if _error_sign == null or _error_sign.node == null:
		push_warning("FairyGUI loader content not found or unsupported: %s" % url)
		return
	_error_sign.set_size(width, height)
	if _error_sign.node.get_parent() != node:
		node.add_child(_error_sign.node)


func _clear_error_state() -> void:
	if _error_sign == null:
		return
	if _error_sign.node != null and _error_sign.node.get_parent() == node:
		node.remove_child(_error_sign.node)
	_error_sign_pool.return_object(_error_sign)
	_error_sign = null


func _set_texture(texture: Texture2D) -> void:
	if texture_rect == null:
		return
	texture_rect.texture = texture
	_apply_fill()


func _apply_fill() -> void:
	if texture_rect == null or fill_renderer == null:
		return
	var use_fill := fill_method != FGUIEnums.FILL_NONE and texture_rect.texture != null
	texture_rect.visible = not use_fill
	fill_renderer.visible = use_fill
	fill_renderer.modulate = color
	fill_renderer.configure(texture_rect.texture, fill_method, fill_origin, fill_clockwise, fill_amount)


func _handle_size_changed() -> void:
	super._handle_size_changed()
	update_layout()
	if _error_sign != null:
		_error_sign.set_size(width, height)
