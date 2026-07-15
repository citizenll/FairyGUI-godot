@tool
extends EditorInspectorPlugin

var generate_callback: Callable
var open_callback: Callable
var preview_callback: Callable


func _can_handle(object: Object) -> bool:
	return object is FGUIPackageResource or object is FGUIView


func _parse_begin(object: Object) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var generate_button := Button.new()
	generate_button.text = "生成绑定"
	generate_button.tooltip_text = "重新生成 FairyGUI 强类型绑定。"
	generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_button.pressed.connect(_on_generate_pressed.bind(object))
	row.add_child(generate_button)

	var preview_button := Button.new()
	preview_button.text = "打开预览"
	preview_button.tooltip_text = "在 GUI 预览面板中打开此 FairyGUI 包或组件。"
	preview_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_button.pressed.connect(_on_preview_pressed.bind(object))
	row.add_child(preview_button)

	if object is FGUIView:
		var open_button := Button.new()
		open_button.text = "打开绑定"
		open_button.tooltip_text = "打开此组件生成的绑定脚本。"
		open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open_button.pressed.connect(_on_open_pressed.bind(object))
		row.add_child(open_button)

	add_custom_control(row)


func _on_generate_pressed(object: Object) -> void:
	if generate_callback.is_valid():
		generate_callback.call(object)


func _on_open_pressed(object: Object) -> void:
	if open_callback.is_valid():
		open_callback.call(object)


func _on_preview_pressed(object: Object) -> void:
	if preview_callback.is_valid():
		preview_callback.call(object)
