extends SceneTree


func _initialize() -> void:
	var expected := "hello fairy deflate testhello fairy deflate testhello fairy deflate test".to_utf8_buffer()
	var zlib_bytes := PackedByteArray([120, 156, 203, 72, 205, 201, 201, 87, 72, 75, 204, 44, 170, 84, 72, 73, 77, 203, 73, 44, 73, 85, 40, 73, 45, 46, 201, 32, 81, 28, 0, 230, 247, 27, 109])
	var raw_bytes := PackedByteArray([203, 72, 205, 201, 201, 87, 72, 75, 204, 44, 170, 84, 72, 73, 77, 203, 73, 44, 73, 85, 40, 73, 45, 46, 201, 32, 81, 28, 0])
	var zlib_result := zlib_bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	var raw_result := FGUIRawInflate.decompress(raw_bytes)
	if zlib_result != expected:
		push_error("Godot zlib deflate probe failed.")
		quit(1)
		return
	if raw_result != expected:
		push_error("FairyGUI raw deflate probe failed.")
		quit(1)
		return
	quit(0)
