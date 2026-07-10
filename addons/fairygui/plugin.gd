@tool
extends EditorPlugin

const FUIImportPlugin := preload("res://addons/fairygui/editor/fui_import_plugin.gd")

var _fui_importer: EditorImportPlugin


func _enter_tree() -> void:
	_fui_importer = FUIImportPlugin.new()
	add_import_plugin(_fui_importer, true)


func _exit_tree() -> void:
	if _fui_importer != null:
		remove_import_plugin(_fui_importer)
		_fui_importer = null
