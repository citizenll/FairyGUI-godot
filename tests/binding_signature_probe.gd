extends SceneTree

const PACKAGE_PATH := "res://examples/assets/ui/VirtualList.fui"
const BindingSignature := preload("res://addons/fairygui/core/binding_signature.gd")


func _initialize() -> void:
	for file_name: String in DirAccess.get_files_at("res://examples/assets/ui"):
		if file_name.get_extension().to_lower() != "fui":
			continue
		var path := "res://examples/assets/ui/%s" % file_name
		if BindingSignature.from_bytes(FileAccess.get_file_as_bytes(path), path) == "":
			_fail("Could not compute a binding signature from %s." % path)
			return
	var bytes := FileAccess.get_file_as_bytes(PACKAGE_PATH)
	var byte_signature := BindingSignature.from_bytes(bytes, PACKAGE_PATH)
	if byte_signature == "":
		_fail("Could not compute a binding signature from VirtualList.fui.")
		return
	var imported := ResourceLoader.load(PACKAGE_PATH) as FGUIPackageResource
	if imported == null or imported.get_binding_hash() != byte_signature:
		_fail("The imported package does not contain the current binding signature.")
		return

	var package := FGUIPackage.new()
	package.res_key = PACKAGE_PATH.trim_suffix(".fui")
	package._load_package(FGUIByteBuffer.new(bytes), false, false, false)
	var package_signature := BindingSignature.from_package(package)
	if package_signature != byte_signature:
		package.dispose()
		_fail("Byte and parsed-package binding signatures differ.")
		return

	var component: FGUIPackageItem
	for item: FGUIPackageItem in package.items:
		if item.type == FGUIEnums.PACKAGE_ITEM_COMPONENT and item.name == "Main":
			component = item
			break
	if component == null:
		package.dispose()
		_fail("VirtualList.fui does not contain the Main component.")
		return

	component.width += 1
	if BindingSignature.from_package(package) != package_signature:
		package.dispose()
		_fail("A layout-only size change invalidated the binding signature.")
		return
	component.name += "Renamed"
	if BindingSignature.from_package(package) == package_signature:
		package.dispose()
		_fail("A public component rename did not invalidate the binding signature.")
		return
	package.dispose()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
