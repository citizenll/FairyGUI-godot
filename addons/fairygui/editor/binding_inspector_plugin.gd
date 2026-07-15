@tool
extends EditorInspectorPlugin

const BusinessScriptGenerator := preload("res://addons/fairygui/editor/business_script_generator.gd")
const EventBindingInspector := preload("res://addons/fairygui/editor/event_binding_inspector.gd")
const PackageDiagnostics := preload("res://addons/fairygui/editor/package_diagnostics.gd")

var generate_callback: Callable
var open_callback: Callable
var preview_callback: Callable
var business_script_callback: Callable
var diagnostic_path_callback: Callable
var event_model_callback: Callable
var event_add_callback: Callable
var event_remove_callback: Callable
var event_open_callback: Callable
var event_toggle_callback: Callable


func _can_handle(object: Object) -> bool:
	return object is FGUIPackageResource or object is FGUIView


func _parse_begin(object: Object) -> void:
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(row)

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
		var secondary_row := HBoxContainer.new()
		secondary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(secondary_row)

		var open_button := Button.new()
		open_button.text = "打开绑定"
		open_button.tooltip_text = "打开此组件生成的绑定脚本。"
		open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open_button.pressed.connect(_on_open_pressed.bind(object))
		secondary_row.add_child(open_button)

		var business_button := Button.new()
		var user_script := BusinessScriptGenerator.get_user_script(object as FGUIView)
		business_button.text = "打开界面脚本" if user_script != null else "创建界面脚本"
		business_button.tooltip_text = "使用当前 .fui 包和组件的真实绑定创建强类型业务脚本。"
		business_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		business_button.pressed.connect(_on_business_script_pressed.bind(object))
		secondary_row.add_child(business_button)

	add_custom_control(actions)
	if object is FGUIView and event_model_callback.is_valid():
		var event_inspector := EventBindingInspector.new()
		event_inspector.configure(
			object as FGUIView,
			event_model_callback.call(object),
			event_add_callback,
			event_remove_callback,
			event_open_callback,
			event_toggle_callback
		)
		add_custom_control(event_inspector)
	_add_diagnostics(object)


func _parse_property(
		object: Object,
		_type: Variant.Type,
		name: String,
		_hint_type: PropertyHint,
		_hint_string: String,
		_usage_flags: int,
		_wide: bool
	) -> bool:
	return object is FGUIView and name == "event_bindings"


func _on_generate_pressed(object: Object) -> void:
	if generate_callback.is_valid():
		generate_callback.call(object)


func _on_open_pressed(object: Object) -> void:
	if open_callback.is_valid():
		open_callback.call(object)


func _on_preview_pressed(object: Object) -> void:
	if preview_callback.is_valid():
		preview_callback.call(object)


func _on_business_script_pressed(object: Object) -> void:
	if business_script_callback.is_valid():
		business_script_callback.call(object)


func _add_diagnostics(object: Object) -> void:
	var resource: FGUIPackageResource
	var component_name := ""
	if object is FGUIPackageResource:
		resource = object as FGUIPackageResource
	elif object is FGUIView:
		resource = (object as FGUIView).package
		component_name = (object as FGUIView).component_name
	var diagnostics := PackageDiagnostics.new().analyze(resource, component_name)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 2)
	var summary := Label.new()
	if int(diagnostics.error_count) > 0:
		summary.text = "FairyGUI 诊断 · %d 个错误 · %d 个警告" % [
			diagnostics.error_count,
			diagnostics.warning_count,
		]
		summary.add_theme_color_override("font_color", _diagnostic_color("error"))
	elif int(diagnostics.warning_count) > 0:
		summary.text = "FairyGUI 诊断 · %d 个组件 · %d 个警告" % [
			diagnostics.component_count,
			diagnostics.warning_count,
		]
		summary.add_theme_color_override("font_color", _diagnostic_color("warning"))
	else:
		summary.text = "FairyGUI 资源有效 · %d 个组件 · 绑定状态正常" % diagnostics.component_count
		summary.add_theme_color_override("font_color", _diagnostic_color("success"))
	panel.add_child(summary)
	for issue: Dictionary in diagnostics.issues:
		var path := str(issue.get("path", ""))
		var message := str(issue.get("message", ""))
		var severity := str(issue.get("severity", "warning"))
		if path != "" and diagnostic_path_callback.is_valid():
			var button := Button.new()
			button.flat = true
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.text = "• %s" % message
			button.tooltip_text = path
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.add_theme_color_override("font_color", _diagnostic_color(severity))
			button.pressed.connect(_on_diagnostic_path_pressed.bind(path))
			panel.add_child(button)
		else:
			var label := Label.new()
			label.text = "• %s" % message
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.tooltip_text = path
			label.add_theme_color_override("font_color", _diagnostic_color(severity))
			panel.add_child(label)
	add_custom_control(panel)


func _on_diagnostic_path_pressed(path: String) -> void:
	if diagnostic_path_callback.is_valid():
		diagnostic_path_callback.call(path)


func _diagnostic_color(severity: String) -> Color:
	var theme := EditorInterface.get_editor_theme()
	var color_name := "success_color"
	if severity == "error":
		color_name = "error_color"
	elif severity == "warning":
		color_name = "warning_color"
	if theme.has_color(color_name, "Editor"):
		return theme.get_color(color_name, "Editor")
	return Color(0.4, 0.85, 0.5) if severity == "success" else Color(1.0, 0.7, 0.3)
