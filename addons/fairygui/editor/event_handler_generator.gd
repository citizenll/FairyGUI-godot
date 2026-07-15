@tool
extends RefCounted

const BusinessScriptGenerator := preload("res://addons/fairygui/editor/business_script_generator.gd")


func ensure_handler(view: FGUIView, handler: StringName) -> Dictionary:
	var result := {
		"ok": false,
		"created": false,
		"error": "",
		"script": null,
		"line": -1,
	}
	if view == null:
		result.error = "FGUIView 不存在。"
		return result
	var method_name := str(handler)
	if not method_name.is_valid_ascii_identifier():
		result.error = "处理函数名称不是有效的 GDScript 标识符：%s" % method_name
		return result
	var script := BusinessScriptGenerator.get_user_script(view) as GDScript
	if script == null:
		result.error = "请先创建并挂载界面脚本。"
		return result
	var script_path := script.resource_path
	if not script_path.begins_with("res://") or not FileAccess.file_exists(script_path):
		result.error = "界面脚本不是可写入的项目文件：%s" % script_path
		return result
	var source := script.source_code
	if source == "":
		source = FileAccess.get_file_as_string(script_path)
	var existing_line := find_handler_line(source, method_name)
	if existing_line >= 0 or view.has_method(handler):
		result.ok = true
		result.script = script
		result.line = existing_line
		return result

	var newline := "\r\n" if source.contains("\r\n") else "\n"
	var next_source := source
	if not next_source.ends_with("\n"):
		next_source += newline
	if not next_source.ends_with(newline + newline):
		next_source += newline
	var handler_line := next_source.count("\n")
	next_source += "func %s(_event: FGUIEventContext) -> void:%s\tpass%s" % [
		method_name,
		newline,
		newline,
	]
	var validation := GDScript.new()
	validation.source_code = next_source
	var validation_error := validation.reload()
	if validation_error != OK:
		result.error = "生成处理函数后脚本校验失败：%s" % error_string(validation_error)
		return result
	var write_error := _replace_file_atomically(script_path, next_source)
	if write_error != OK:
		result.error = "无法更新界面脚本：%s" % error_string(write_error)
		return result

	script.source_code = next_source
	var reload_error := script.reload(true)
	if reload_error != OK:
		result.error = "界面脚本已写入，但重新加载失败：%s" % error_string(reload_error)
		return result
	script.emit_changed()
	result.ok = true
	result.created = true
	result.script = script
	result.line = handler_line
	return result


func find_handler_line(source: String, handler: String) -> int:
	var lines := source.split("\n")
	var prefix := "func %s(" % handler
	for index in lines.size():
		if str(lines[index]).strip_edges().begins_with(prefix):
			return index
	return -1


func _replace_file_atomically(path: String, content: String) -> Error:
	var absolute_path := ProjectSettings.globalize_path(path)
	var temporary_path := absolute_path + ".fairygui_tmp"
	var backup_path := absolute_path + ".fairygui_backup"
	_remove_if_exists(temporary_path)
	_remove_if_exists(backup_path)
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.close()

	var backup_error := DirAccess.rename_absolute(absolute_path, backup_path)
	if backup_error != OK:
		_remove_if_exists(temporary_path)
		return backup_error
	var install_error := DirAccess.rename_absolute(temporary_path, absolute_path)
	if install_error != OK:
		DirAccess.rename_absolute(backup_path, absolute_path)
		_remove_if_exists(temporary_path)
		return install_error
	_remove_if_exists(backup_path)
	return OK


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
