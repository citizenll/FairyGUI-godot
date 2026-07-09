class_name FGUIImage
extends FGUIObject

var _color: Color = Color.WHITE
var color: Color:
	get:
		return _color
	set(value):
		_color = value
		if node != null:
			node.modulate = value

var image_node: NinePatchRect
var flip: int = FGUIEnums.FLIP_NONE
var content_item: FGUIPackageItem


func _create_display_object() -> void:
	image_node = NinePatchRect.new()
	image_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node = image_node


func construct_from_resource() -> void:
	if package_item == null:
		return
	content_item = package_item.get_branch()
	source_width = content_item.width
	source_height = content_item.height
	init_width = source_width
	init_height = source_height
	content_item = content_item.get_high_resolution()
	content_item.load()
	image_node.texture = content_item.texture
	if content_item.has_scale9_grid:
		var grid := content_item.scale9_grid
		image_node.patch_margin_left = grid.position.x
		image_node.patch_margin_top = grid.position.y
		image_node.patch_margin_right = maxi(0, int(source_width) - grid.position.x - grid.size.x)
		image_node.patch_margin_bottom = maxi(0, int(source_height) - grid.position.y - grid.size.y)
	set_size(source_width, source_height)


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_before_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 5):
		return
	if buffer.read_bool():
		color = buffer.read_color()
	flip = buffer.read_i8()
	_apply_flip()
	var fill_method := buffer.read_i8()
	if fill_method != 0:
		buffer.read_i8()
		buffer.read_bool()
		buffer.read_float32()


func get_prop(index: int) -> Variant:
	if index == FGUIEnums.OBJECT_PROP_COLOR:
		return color
	return super.get_prop(index)


func set_prop(index: int, value: Variant) -> void:
	if index == FGUIEnums.OBJECT_PROP_COLOR and value is Color:
		color = value
	else:
		super.set_prop(index, value)


func _apply_flip() -> void:
	var sx := -1.0 if flip == FGUIEnums.FLIP_HORIZONTAL or flip == FGUIEnums.FLIP_BOTH else 1.0
	var sy := -1.0 if flip == FGUIEnums.FLIP_VERTICAL or flip == FGUIEnums.FLIP_BOTH else 1.0
	set_scale(sx, sy)
