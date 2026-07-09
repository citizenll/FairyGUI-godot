class_name FGUIGraph
extends FGUIObject

var color_rect: ColorRect


func _create_display_object() -> void:
	color_rect = ColorRect.new()
	color_rect.color = Color.TRANSPARENT
	node = color_rect


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_before_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 5):
		return
	var shape_type := buffer.read_i8()
	if shape_type != 0:
		buffer.read_i32()
		var line_color := buffer.read_color(true)
		var fill_color := buffer.read_color(true)
		color_rect.color = fill_color
