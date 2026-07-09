class_name FGUIPixelHitTestData
extends RefCounted

var pixel_width: int = 0
var scale: float = 1.0
var pixels: PackedByteArray = PackedByteArray()


func load(buffer: FGUIByteBuffer) -> void:
	buffer.read_i32()
	pixel_width = buffer.read_i32()
	var packed_scale := max(1, buffer.read_u8())
	scale = 1.0 / float(packed_scale)
	var length := buffer.read_i32()
	pixels = PackedByteArray()
	pixels.resize(maxi(0, length))
	for i in length:
		pixels[i] = buffer.read_u8()
