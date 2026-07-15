@tool
extends EditorImportPlugin

func _get_importer_name() -> String:
	return "fairygui.package"


func _get_visible_name() -> String:
	return "FairyGUI Package"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["fui"])


func _get_save_extension() -> String:
	return "res"


func _get_resource_type() -> String:
	# ResourceLoader matches this against the serialized native type. The attached
	# script still provides FGUIPackageResource to typed Inspector fields.
	return "Resource"


func _get_preset_count() -> int:
	return 1


func _get_preset_name(_preset_index: int) -> String:
	return "Default"


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return [{
		"name": "codegen/enabled",
		"default_value": true,
	}]


func _get_import_order() -> int:
	return 0


func _get_format_version() -> int:
	return 5


func _can_import_threaded() -> bool:
	return true


func _import(source_file: String, save_path: String, _options: Dictionary, _platform_variants: Array[String], _gen_files: Array[String]) -> Error:
	var bytes := FileAccess.get_file_as_bytes(source_file)
	if bytes.size() < 4 or bytes[0] != 0x46 or bytes[1] != 0x47 or bytes[2] != 0x55 or bytes[3] != 0x49:
		push_error("Invalid FairyGUI package: %s" % source_file)
		return ERR_FILE_CORRUPT
	var resource := FGUIPackageResource.new()
	resource.package_data = bytes
	resource.source_path = source_file
	resource.content_hash = FileAccess.get_sha256(source_file)
	resource.codegen_enabled = bool(_options.get("codegen/enabled", true))
	return ResourceSaver.save(resource, "%s.%s" % [save_path, _get_save_extension()], ResourceSaver.FLAG_COMPRESS)
