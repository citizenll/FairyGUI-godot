extends SceneTree


func _initialize() -> void:
	var resource := FGUIPackageResource.new()
	resource.package_data = PackedByteArray([0x46, 0x47, 0x55, 0x49])
	resource.source_path = "res://probe.fui"
	resource.content_hash = "probe"

	var binary_path := "user://fairygui_package_probe.res"
	var text_path := "user://fairygui_package_probe.tres"
	if ResourceSaver.save(resource, binary_path, ResourceSaver.FLAG_COMPRESS) != OK:
		_fail("Failed to save compressed package resource.")
		return
	if ResourceSaver.save(resource, text_path) != OK:
		_fail("Failed to save text package resource.")
		return
	var binary_loaded := ResourceLoader.load(binary_path)
	var text_loaded := ResourceLoader.load(text_path)
	if not (binary_loaded is FGUIPackageResource):
		_fail("Compressed package resource did not load as FGUIPackageResource.")
		return
	if not (text_loaded is FGUIPackageResource):
		_fail("Text package resource did not load as FGUIPackageResource.")
		return
	var typed_binary := binary_loaded as FGUIPackageResource
	if typed_binary.package_data != resource.package_data or typed_binary.source_path != resource.source_path:
		_fail("Package resource data was not preserved through save/load.")
		return
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
