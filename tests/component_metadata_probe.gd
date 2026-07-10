extends SceneTree


func _initialize() -> void:
	var component := FGUIComponent.new()
	if component.display_list_container != component.node:
		_fail("Component display_list_container did not expose its default native container.")
		return
	var raw := FGUIByteBuffer.new(PackedByteArray([
		5, 1,
		0, 0, 0, 0, 0, 0, 0, 0,
		0, 12,
		0, 0,
	]))
	raw.string_table = ["component metadata"]
	raw.pos = 3
	var item := FGUIPackageItem.new()
	item.raw_data = raw
	component.package_item = item
	if component.base_user_data != "component metadata" or raw.pos != 3:
		_fail("Component base_user_data did not read block metadata without mutating package data.")
		return
	component.dispose()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
