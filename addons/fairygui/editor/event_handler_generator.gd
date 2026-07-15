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
		"refresh_open_editor": false,
		"saved_editor_changes": false,
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
	var disk_result := _read_file(script_path)
	if not bool(disk_result.get("ok", false)):
		result.error = "无法读取界面脚本：%s" % disk_result.get("error", "")
		return result
	var disk_source := str(disk_result.get("source", ""))
	var loaded_source := script.source_code
	var code_edit := _find_open_code_edit(script)
	var source := code_edit.get_text() if code_edit != null else disk_source
	var existing_line := find_handler_line(source, method_name)
	var created := existing_line < 0
	var next_source := source
	var handler_line := existing_line
	if created:
		var newline := "\r\n" if source.contains("\r\n") else "\n"
		if not next_source.ends_with("\n"):
			next_source += newline
		if not next_source.ends_with(newline + newline):
			next_source += newline
		handler_line = next_source.count("\n")
		next_source += "func %s(_event: FGUIEventContext) -> void:%s\tpass%s" % [
			method_name,
			newline,
			newline,
		]

	var needs_commit := next_source != disk_source \
			or next_source != loaded_source \
			or not view.has_method(handler)
	if not needs_commit:
		result.ok = true
		result.script = script
		result.line = existing_line
		return result

	var validation := GDScript.new()
	validation.source_code = next_source
	var validation_error := validation.reload()
	if validation_error != OK:
		result.error = "界面脚本校验失败，未创建事件连接：%s" % error_string(validation_error)
		return result
	var wrote_file := next_source != disk_source
	if wrote_file:
		var write_error := _replace_file_atomically(script_path, next_source)
		if write_error != OK:
			result.error = "无法更新界面脚本：%s" % error_string(write_error)
			return result

	script.source_code = next_source
	var reload_error := script.reload(true)
	if reload_error != OK:
		var restore_error := OK
		if wrote_file:
			restore_error = _restore_backup(script_path)
		script.source_code = loaded_source
		var source_restore_error := script.reload(true)
		result.error = "界面脚本重新加载失败：%s" % error_string(reload_error)
		if wrote_file and restore_error != OK:
			result.error += "；恢复原文件也失败：%s" % error_string(restore_error)
		if source_restore_error != OK:
			result.error += "；恢复脚本资源也失败：%s" % error_string(source_restore_error)
		return result
	if wrote_file:
		_remove_if_exists(ProjectSettings.globalize_path(script_path) + ".fairygui_backup")
	if code_edit != null:
		_sync_open_code_edit(code_edit, next_source)
		result.refresh_open_editor = true
		result.saved_editor_changes = source != disk_source
	var script_editor := EditorInterface.get_script_editor()
	if script_editor != null:
		script_editor.update_docs_from_script(script)
	script.emit_changed()
	result.ok = true
	result.created = created
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


func _read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"error": error_string(FileAccess.get_open_error()),
		}
	var source := file.get_as_text()
	file.close()
	return {
		"ok": true,
		"source": source,
	}


func _find_open_code_edit(script: Script) -> CodeEdit:
	if not Engine.is_editor_hint():
		return null
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null:
		return null
	var open_scripts := script_editor.get_open_scripts()
	var open_editors := script_editor.get_open_script_editors()
	var count := mini(open_scripts.size(), open_editors.size())
	for index in count:
		var open_script := open_scripts[index] as Script
		if open_script == null:
			continue
		if open_script != script and open_script.resource_path != script.resource_path:
			continue
		var editor := open_editors[index] as ScriptEditorBase
		if editor == null:
			return null
		return editor.get_base_editor() as CodeEdit
	return null


func _sync_open_code_edit(code_edit: CodeEdit, source: String) -> void:
	if code_edit == null:
		return
	var caret_line := code_edit.get_caret_line()
	var caret_column := code_edit.get_caret_column()
	var horizontal_scroll := code_edit.scroll_horizontal
	var vertical_scroll := code_edit.scroll_vertical
	if code_edit.get_text() != source:
		code_edit.set_text(source)
	code_edit.set_caret_line(clampi(caret_line, 0, maxi(code_edit.get_line_count() - 1, 0)))
	code_edit.set_caret_column(caret_column)
	code_edit.scroll_horizontal = horizontal_scroll
	code_edit.scroll_vertical = vertical_scroll
	code_edit.tag_saved_version()


func _replace_file_atomically(path: String, content: String) -> Error:
	var absolute_path := ProjectSettings.globalize_path(path)
	var temporary_path := absolute_path + ".fairygui_tmp"
	var backup_path := absolute_path + ".fairygui_backup"
	_remove_if_exists(temporary_path)
	if FileAccess.file_exists(backup_path):
		if FileAccess.file_exists(absolute_path):
			_remove_if_exists(backup_path)
		else:
			var recover_error := DirAccess.rename_absolute(backup_path, absolute_path)
			if recover_error != OK:
				return recover_error
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
	return OK


func _restore_backup(path: String) -> Error:
	var absolute_path := ProjectSettings.globalize_path(path)
	var backup_path := absolute_path + ".fairygui_backup"
	if not FileAccess.file_exists(backup_path):
		return ERR_FILE_NOT_FOUND
	_remove_if_exists(absolute_path)
	return DirAccess.rename_absolute(backup_path, absolute_path)


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
