class_name FGUILoader
extends FGUIObject

var texture_rect: TextureRect
var _url: String = ""
var url: String:
	set(value):
		_url = value
		_load_url()
	get:
		return _url


func _create_display_object() -> void:
	texture_rect = TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node = texture_rect


func get_icon() -> String:
	return url


func set_icon(value: String) -> void:
	url = value


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_before_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 5):
		return
	var next_url = buffer.read_s()
	if next_url != null:
		url = next_url
	buffer.read_i8()
	buffer.read_i8()
	buffer.read_i8()
	buffer.read_bool()
	buffer.read_i8()
	buffer.read_bool()
	buffer.read_color(true)


func _load_url() -> void:
	if url == "":
		texture_rect.texture = null
		return
	if url.begins_with("ui://"):
		var item := FGUIPackage.get_item_by_url(url)
		texture_rect.texture = item.owner.get_item_asset(item) if item != null else null
	else:
		var resource := load(url)
		texture_rect.texture = resource if resource is Texture2D else null
