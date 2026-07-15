@tool
class_name FGUIBusinessScriptGenerator
extends RefCounted

const BindingCodeGenerator := preload("res://addons/fairygui/editor/binding_codegen.gd")
const FGUI_VIEW_SCRIPT := "res://addons/fairygui/ui/fui_view.gd"


func resolve_binding(resource: FGUIPackageResource, component_name: String = "") -> Dictionary:
	var result := {
		"ok": false,
		"error": "",
		"component": {},
		"binding_path": "",
		"binding_class": "",
		"current": false,
	}
	if resource == null:
		result.error = "FGUIView 尚未配置 FairyGUI 包。"
		return result
	var component := resource.get_component_info(component_name)
	if component.is_empty():
		result.error = "FairyGUI 包中不存在组件：%s" % (component_name if component_name != "" else "<none>")
		return result
	result.component = component

	var output_dir := str(ProjectSettings.get_setting(
		"fairygui/codegen/output_dir",
		BindingCodeGenerator.DEFAULT_OUTPUT_DIR
	)).trim_suffix("/")
	var manifest_path := "%s/%s" % [output_dir, BindingCodeGenerator.MANIFEST_FILE]
	if not FileAccess.file_exists(manifest_path):
		result.error = "FairyGUI 绑定清单尚未生成。"
		return result
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary:
		result.error = "FairyGUI 绑定清单无法解析：%s" % manifest_path
		return result
	var binding_path := str(manifest.get("bindings", {}).get(str(component.url), ""))
	if binding_path == "":
		result.error = "当前组件没有生成绑定：%s/%s" % [component.package_name, component.component_name]
		return result
	if not FileAccess.file_exists(binding_path):
		result.error = "生成的绑定脚本不存在：%s" % binding_path
		return result
	var binding_class := _read_global_class_name(binding_path)
	if binding_class == "":
		result.error = "生成的绑定脚本没有 class_name：%s" % binding_path
		return result
	result.ok = true
	result.binding_path = binding_path
	result.binding_class = binding_class
	var source_path := resource.resource_path if resource.resource_path.get_extension().to_lower() == "fui" else resource.get_source_path()
	result.current = str(manifest.get("inputs", {}).get(source_path, "")) == resource.content_hash
	return result


func create_for_view(view: FGUIView, scene_path: String) -> Dictionary:
	var binding := resolve_binding(view.package if view != null else null, view.component_name if view != null else "")
	if not bool(binding.ok):
		return binding
	var target_path := suggest_script_path(view, scene_path)
	var source := render_source(binding)
	var validation := GDScript.new()
	validation.source_code = source
	var validation_error := validation.reload()
	if validation_error != OK:
		binding.ok = false
		binding.error = "生成的界面脚本未通过 GDScript 校验：%s" % error_string(validation_error)
		return binding

	var absolute_dir := ProjectSettings.globalize_path(target_path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		binding.ok = false
		binding.error = "无法创建界面脚本目录：%s" % target_path.get_base_dir()
		return binding
	var temporary_path := target_path + ".fairygui_tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		binding.ok = false
		binding.error = "无法写入界面脚本：%s" % target_path
		return binding
	file.store_string(source)
	file.close()
	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path),
		ProjectSettings.globalize_path(target_path)
	)
	if rename_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		binding.ok = false
		binding.error = "无法提交界面脚本：%s" % error_string(rename_error)
		return binding
	binding.script_path = target_path
	binding.source = source
	return binding


func render_source(binding: Dictionary) -> String:
	var component: Dictionary = binding.component
	var mismatch_message := "FairyGUI binding mismatch: %s/%s" % [
		component.package_name,
		component.component_name,
	]
	return "\n".join(PackedStringArray([
		"@tool",
		"extends FGUIView",
		"",
		"const UI_TYPE := preload(%s)" % JSON.stringify(str(binding.binding_path)),
		"",
		"var ui: UI_TYPE",
		"",
		"",
		"func _ready() -> void:",
		"\tsuper._ready()",
		"\tif Engine.is_editor_hint():",
		"\t\treturn",
		"\tui = fairy as UI_TYPE",
		"\tif ui == null:",
		"\t\tpush_error(%s)" % JSON.stringify(mismatch_message),
		"",
	]))


func suggest_script_path(view: FGUIView, scene_path: String) -> String:
	var base_dir := scene_path.get_base_dir() if scene_path.begins_with("res://") else "res://"
	var base_name := str(view.name).to_snake_case().validate_filename() if view != null else "fairygui_view"
	if base_name == "":
		base_name = "fairygui_view"
	var path := "%s/%s.gd" % [base_dir.trim_suffix("/"), base_name]
	var suffix := 2
	while FileAccess.file_exists(path):
		path = "%s/%s_%d.gd" % [base_dir.trim_suffix("/"), base_name, suffix]
		suffix += 1
	return path


static func get_user_script(view: FGUIView) -> Script:
	if view == null:
		return null
	var script := view.get_script() as Script
	if script == null or script.resource_path == FGUI_VIEW_SCRIPT:
		return null
	return script


func _read_global_class_name(path: String) -> String:
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("class_name "):
			return stripped.trim_prefix("class_name ").get_slice(" ", 0).strip_edges()
	return ""
