@tool
extends Control

signal component_dropped(package_path: String, component_name: String, canvas_position: Vector2)

var _accepting_drag: bool = false


func _ready() -> void:
	name = "FairyGUICanvasDropOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4096
	set_process(true)


func _process(_delta: float) -> void:
	var accepting := false
	var viewport := get_viewport()
	if viewport != null and viewport.gui_is_dragging():
		accepting = not extract_drop_request(viewport.gui_get_drag_data()).is_empty()
	if accepting == _accepting_drag:
		return
	_accepting_drag = accepting
	mouse_filter = Control.MOUSE_FILTER_STOP if accepting else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not extract_drop_request(data).is_empty()


func _drop_data(at_position: Vector2, data: Variant) -> void:
	var request := extract_drop_request(data)
	if request.is_empty():
		return
	var canvas_position := at_position
	var editor_viewport := EditorInterface.get_editor_viewport_2d()
	if editor_viewport != null:
		canvas_position = editor_viewport.get_global_canvas_transform().affine_inverse() * at_position
	component_dropped.emit(
		str(request.package_path),
		str(request.get("component_name", "")),
		canvas_position
	)


func _draw() -> void:
	if not _accepting_drag:
		return
	var theme := EditorInterface.get_editor_theme()
	var accent := theme.get_color("accent_color", "Editor") if theme.has_color("accent_color", "Editor") else Color(0.3, 0.65, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(accent, 0.08), true)
	draw_rect(Rect2(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0), accent, false, 2.0)


func extract_drop_request(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {}
	var dictionary := data as Dictionary
	var type := str(dictionary.get("type", ""))
	if type == "fairygui_component":
		var package_path := str(dictionary.get("package_path", ""))
		if package_path.get_extension().to_lower() != "fui" or not ResourceLoader.exists(package_path):
			return {}
		return {
			"package_path": package_path,
			"component_name": str(dictionary.get("component_name", "")),
		}
	if type != "files":
		return {}
	var files := PackedStringArray()
	var files_value: Variant = dictionary.get("files", PackedStringArray())
	if files_value is PackedStringArray:
		files = files_value
	elif files_value is Array:
		for file_value: Variant in files_value:
			files.append(str(file_value))
	if files.size() != 1:
		return {}
	var path := str(files[0])
	if path.get_extension().to_lower() != "fui" or not ResourceLoader.exists(path):
		return {}
	return {"package_path": path, "component_name": ""}
