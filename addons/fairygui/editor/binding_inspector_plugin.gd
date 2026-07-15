@tool
extends EditorInspectorPlugin

var generate_callback: Callable
var open_callback: Callable


func _can_handle(object: Object) -> bool:
	return object is FGUIPackageResource or object is FGUIView


func _parse_begin(object: Object) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var generate_button := Button.new()
	generate_button.text = "Generate Bindings"
	generate_button.tooltip_text = "Regenerate strongly typed FairyGUI bindings."
	generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generate_button.pressed.connect(_on_generate_pressed.bind(object))
	row.add_child(generate_button)

	if object is FGUIView:
		var open_button := Button.new()
		open_button.text = "Open Binding"
		open_button.tooltip_text = "Open the generated binding script for this component."
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
