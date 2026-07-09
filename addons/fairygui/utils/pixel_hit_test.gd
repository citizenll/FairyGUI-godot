class_name FGUIPixelHitTest
extends RefCounted

var data: FGUIPixelHitTestData
var offset_x: float = 0.0
var offset_y: float = 0.0
var scale_x: float = 1.0
var scale_y: float = 1.0


func _init(p_data: FGUIPixelHitTestData = null, p_offset_x: float = 0.0, p_offset_y: float = 0.0) -> void:
	data = p_data
	offset_x = p_offset_x
	offset_y = p_offset_y


func contains(x: float, y: float) -> bool:
	if data == null or data.pixel_width <= 0:
		return false
	var px := floori((x / maxf(scale_x, 0.0001) - offset_x) * data.scale)
	var py := floori((y / maxf(scale_y, 0.0001) - offset_y) * data.scale)
	if px < 0 or py < 0 or px >= data.pixel_width:
		return false
	var pos := py * data.pixel_width + px
	var byte_pos := floori(float(pos) / 8.0)
	var bit_pos := pos % 8
	if byte_pos < 0 or byte_pos >= data.pixels.size():
		return false
	return ((int(data.pixels[byte_pos]) >> bit_pos) & 1) == 1
