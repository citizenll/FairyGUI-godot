@tool
extends RefCounted

const SIGNATURE_VERSION := 1


static func from_bytes(package_data: PackedByteArray, source_path: String = "") -> String:
	if package_data.size() < 4:
		return ""
	var package := FGUIPackage.new()
	package.res_key = _resource_key(source_path)
	package._load_package(FGUIByteBuffer.new(package_data), false, false, false)
	if package.id == "" or package.name == "":
		package.dispose()
		return ""
	var result := from_package(package)
	package.dispose()
	return result


static func from_package(package: FGUIPackage) -> String:
	if package == null:
		return ""
	var dependencies: Array = []
	for dependency: Dictionary in package.dependencies:
		dependencies.append([
			_string_value(dependency.get("id")),
			_string_value(dependency.get("name")),
		])
	dependencies.sort_custom(func(left: Array, right: Array) -> bool:
		return JSON.stringify(left) < JSON.stringify(right)
	)

	var source_types: Array = []
	var components: Array = []
	for item: FGUIPackageItem in package.items:
		source_types.append([
			item.id,
			item.object_type,
		])
		if item.type != FGUIEnums.PACKAGE_ITEM_COMPONENT:
			continue
		components.append([
			item.id,
			item.name,
			item.object_type,
			item.exported,
			_normalize_strings(item.branches),
			_normalize_strings(item.high_resolution),
			_component_members(item),
		])
	source_types.sort_custom(func(left: Array, right: Array) -> bool:
		return JSON.stringify(left) < JSON.stringify(right)
	)

	var schema: Array = [
		SIGNATURE_VERSION,
		package.id,
		package.name,
		dependencies,
		source_types,
		components,
	]
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(JSON.stringify(schema).to_utf8_buffer())
	return context.finish().hex_encode()


static func _component_members(item: FGUIPackageItem) -> Array:
	if item.raw_data == null:
		return [false, [], [], []]
	var buffer := _clone_buffer(item.raw_data)
	var children: Array = []
	if buffer.seek(0, 2):
		var child_count := buffer.read_i16()
		for index in child_count:
			var data_length := buffer.read_i16()
			var begin_position := buffer.pos
			var end_position := begin_position + data_length
			if data_length <= 0 or end_position > buffer.get_length():
				children.append([index, "invalid"])
				break
			if buffer.seek(begin_position, 0):
				var object_type := buffer.read_i8()
				var source_id := _semantic_value(buffer.read_s())
				var source_package_id := _semantic_value(buffer.read_s())
				buffer.read_s()
				children.append([
					index,
					object_type,
					source_id,
					source_package_id,
					_string_value(buffer.read_s()),
				])
			buffer.pos = end_position

	buffer.pos = 0
	var controllers: Array = []
	if buffer.seek(0, 1):
		var controller_count := buffer.read_i16()
		for index in controller_count:
			var next_position := buffer.read_i16() + buffer.pos
			var begin_position := buffer.pos
			if next_position < begin_position or next_position > buffer.get_length():
				controllers.append([index, "invalid"])
				break
			if buffer.seek(begin_position, 0):
				controllers.append([index, _string_value(buffer.read_s())])
			buffer.pos = next_position

	buffer.pos = 0
	var transitions: Array = []
	if buffer.seek(0, 5):
		var transition_count := buffer.read_i16()
		for index in transition_count:
			var next_position := buffer.read_i16() + buffer.pos
			if next_position < buffer.pos or next_position > buffer.get_length():
				transitions.append([index, "invalid"])
				break
			transitions.append([index, _string_value(buffer.read_s())])
			buffer.pos = next_position

	return [true, children, controllers, transitions]


static func _clone_buffer(source: FGUIByteBuffer) -> FGUIByteBuffer:
	var result := FGUIByteBuffer.new(source.data)
	result.string_table = source.string_table
	result.version = source.version
	return result


static func _normalize_strings(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values:
		result.append(_semantic_value(value))
	return result


static func _semantic_value(value: Variant) -> Variant:
	return null if value == null else str(value)


static func _string_value(value: Variant) -> String:
	return "" if value == null else str(value)


static func _resource_key(source_path: String) -> String:
	var normalized := source_path.replace("\\", "/")
	if normalized.ends_with(".fui"):
		return normalized.trim_suffix(".fui")
	return normalized if normalized != "" else "res://__fairygui_binding_signature/package"
