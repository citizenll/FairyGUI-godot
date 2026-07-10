@tool
class_name FGUIPackageResource
extends Resource

static var _package_cache: Dictionary = {}
static var _cache_key_by_instance: Dictionary = {}

@export_storage var package_data: PackedByteArray = PackedByteArray()
@export_storage var source_path: String = ""
@export_storage var content_hash: String = ""


func get_source_path() -> String:
	return source_path if source_path != "" else resource_path


func get_package_data() -> PackedByteArray:
	return package_data


func get_component_names() -> PackedStringArray:
	var pkg := acquire_package()
	if pkg == null:
		return PackedStringArray()
	var result := PackedStringArray()
	for item: FGUIPackageItem in pkg.items:
		if item.type == FGUIEnums.PACKAGE_ITEM_COMPONENT:
			result.append(item.name)
	release_package(pkg)
	return result


func acquire_package() -> FGUIPackage:
	if package_data.is_empty():
		return null
	var package_path := get_source_path()
	if package_path == "":
		package_path = "res://__fairygui_embedded/%s.fui" % get_instance_id()
	var hash: String = content_hash if content_hash != "" else _hash_bytes(package_data)
	var cache_key := "%s::%s" % [package_path, hash]
	if _package_cache.has(cache_key):
		var cached: Dictionary = _package_cache[cache_key]
		cached["references"] = int(cached["references"]) + 1
		_package_cache[cache_key] = cached
		return cached["package"]

	var normalized_path := package_path if package_path.ends_with(".fui") else package_path + ".fui"
	var res_key := normalized_path.trim_suffix(".fui")
	var pkg := FGUIPackage.get_by_id(res_key)
	var owned := false
	if pkg == null or pkg.source_hash != hash:
		pkg = FGUIPackage.add_package(normalized_path, package_data)
		owned = pkg != null
	if pkg == null:
		return null

	_package_cache[cache_key] = {
		"package": pkg,
		"references": 1,
		"owned": owned,
	}
	_cache_key_by_instance[pkg.get_instance_id()] = cache_key
	return pkg


static func release_package(pkg: FGUIPackage) -> void:
	if pkg == null:
		return
	var instance_id := pkg.get_instance_id()
	var cache_key: String = _cache_key_by_instance.get(instance_id, "")
	if cache_key == "" or not _package_cache.has(cache_key):
		return
	var cached: Dictionary = _package_cache[cache_key]
	cached["references"] = int(cached["references"]) - 1
	if int(cached["references"]) > 0:
		_package_cache[cache_key] = cached
		return
	_package_cache.erase(cache_key)
	_cache_key_by_instance.erase(instance_id)
	if bool(cached["owned"]):
		FGUIPackage.remove_package_instance(pkg)


static func _hash_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()
