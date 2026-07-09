extends SceneTree


func _initialize() -> void:
	var data := FGUIPixelHitTestData.new()
	data.pixel_width = 2
	data.scale = 1.0
	data.pixels = PackedByteArray([1])
	var hit_test := FGUIPixelHitTest.new(data, 0, 0)
	if not hit_test.contains(0, 0):
		push_error("Pixel hit test should accept the first bit.")
		quit(1)
		return
	if hit_test.contains(1, 0):
		push_error("Pixel hit test should reject a cleared bit.")
		quit(1)
		return
	quit(0)
