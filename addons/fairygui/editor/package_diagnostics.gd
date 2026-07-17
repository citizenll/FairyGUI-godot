@tool
class_name FGUIPackageDiagnostics
extends RefCounted

const BindingCodeGenerator := preload("res://addons/fairygui/editor/binding_codegen.gd")

const EXTERNAL_ASSET_TYPES := {
	FGUIEnums.PACKAGE_ITEM_ATLAS: true,
	FGUIEnums.PACKAGE_ITEM_SOUND: true,
	FGUIEnums.PACKAGE_ITEM_MISC: true,
	FGUIEnums.PACKAGE_ITEM_SPINE: true,
	FGUIEnums.PACKAGE_ITEM_DRAGON_BONES: true,
}


func analyze(resource: FGUIPackageResource, component_name: String = "") -> Dictionary:
	var result := {
		"ok": false,
		"package_name": "",
		"package_id": "",
		"component_count": 0,
		"issues": [],
		"error_count": 0,
		"warning_count": 0,
	}
	if resource == null:
		_add_issue(result, "error", "尚未配置 FairyGUI 包。")
		return _finish(result)
	if resource.package_data.is_empty():
		_add_issue(result, "error", "导入资源不包含 .fui 数据。", resource.get_source_path())
		return _finish(result)

	var package := resource.acquire_package()
	if package == null:
		_add_issue(result, "error", "无法解析 FairyGUI 包。", resource.get_source_path())
		return _finish(result)
	result.package_name = package.name
	result.package_id = package.id
	var component_names := PackedStringArray()
	for item: FGUIPackageItem in package.items:
		if item.type == FGUIEnums.PACKAGE_ITEM_COMPONENT:
			component_names.append(item.name)
		elif EXTERNAL_ASSET_TYPES.has(item.type) and item.file != "" and not _resource_exists(item.file):
			_add_issue(result, "error", "缺少外部资源：%s" % item.file, item.file)
	result.component_count = component_names.size()
	if component_names.is_empty():
		_add_issue(result, "error", "包中没有可用组件。", resource.get_source_path())
	elif component_name != "" and not component_names.has(component_name):
		_add_issue(result, "error", "当前组件不存在：%s" % component_name, resource.get_source_path())

	var base_dir := resource.get_source_path().get_base_dir()
	for dependency: Dictionary in package.dependencies:
		var dependency_name := str(dependency.get("name", ""))
		if dependency_name == "":
			continue
		var dependency_path := "%s/%s.fui" % [base_dir, dependency_name]
		if not ResourceLoader.exists(dependency_path):
			_add_issue(result, "error", "缺少依赖包：%s" % dependency_name, dependency_path)
			continue
		var dependency_resource := ResourceLoader.load(dependency_path)
		if not dependency_resource is FGUIPackageResource:
			_add_issue(result, "error", "依赖不是有效的 FairyGUI 包：%s" % dependency_name, dependency_path)
			continue
		var dependency_package := (dependency_resource as FGUIPackageResource).acquire_package()
		if dependency_package == null:
			_add_issue(result, "error", "依赖包无法解析：%s" % dependency_name, dependency_path)
		else:
			FGUIPackageResource.release_package(dependency_package)

	FGUIPackageResource.release_package(package)
	_analyze_bindings(resource, component_name, result)
	return _finish(result)


func _analyze_bindings(resource: FGUIPackageResource, component_name: String, result: Dictionary) -> void:
	if not resource.codegen_enabled:
		_add_issue(result, "warning", "此包已关闭强类型代码生成。", resource.get_source_path())
		return
	var output_dir := str(ProjectSettings.get_setting(
		"fairygui/codegen/output_dir",
		BindingCodeGenerator.DEFAULT_OUTPUT_DIR
	)).trim_suffix("/")
	var manifest_path := "%s/%s" % [output_dir, BindingCodeGenerator.MANIFEST_FILE]
	if not FileAccess.file_exists(manifest_path):
		_add_issue(result, "warning", "尚未生成 FairyGUI 绑定清单。", output_dir)
		return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary:
		_add_issue(result, "error", "绑定清单无法解析。", manifest_path)
		return
	var source_path := resource.resource_path if resource.resource_path.get_extension().to_lower() == "fui" else resource.get_source_path()
	var manifest_hash := str(manifest.get("inputs", {}).get(source_path, ""))
	if manifest_hash == "":
		_add_issue(result, "warning", "当前包尚未写入绑定清单。", manifest_path)
	elif manifest_hash != resource.get_binding_hash():
		_add_issue(result, "warning", "绑定已过期，需要重新生成。", manifest_path)

	var component := resource.get_component_info(component_name)
	if component.is_empty():
		return
	var binding_path := str(manifest.get("bindings", {}).get(str(component.url), ""))
	if binding_path == "":
		_add_issue(result, "warning", "当前组件没有生成绑定：%s" % component.component_name, manifest_path)
	elif not FileAccess.file_exists(binding_path):
		_add_issue(result, "error", "绑定脚本不存在：%s" % binding_path, binding_path)


func _resource_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func _add_issue(result: Dictionary, severity: String, message: String, path: String = "") -> void:
	result.issues.append({
		"severity": severity,
		"message": message,
		"path": path,
	})
	if severity == "error":
		result.error_count = int(result.error_count) + 1
	elif severity == "warning":
		result.warning_count = int(result.warning_count) + 1


func _finish(result: Dictionary) -> Dictionary:
	result.ok = int(result.error_count) == 0
	return result
