@tool
extends EditorInspectorPlugin

var locate_callback: Callable
var rebind_callback: Callable


func _can_handle(object: Object) -> bool:
	return object is Node and (object as Node).has_meta("fgui_target_proxy")


func _parse_begin(object: Object) -> void:
	var panel := VBoxContainer.new()
	panel.name = "FairyGUITargetInspector"
	panel.add_theme_constant_override("separation", 4)

	var target_label := Label.new()
	target_label.text = "目标：%s" % str(object.call("get_target_label"))
	target_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	target_label.tooltip_text = target_label.text
	panel.add_child(target_label)

	var status := Label.new()
	status.text = str(object.call("get_status_text"))
	status.add_theme_color_override("font_color", _status_color(status.text))
	panel.add_child(status)

	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(actions)

	var locate_button := Button.new()
	locate_button.text = "在预览中定位"
	locate_button.tooltip_text = "打开所属 FGUIView 的 GUI 预览并选中当前目标。"
	locate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	locate_button.disabled = object.get("target_ref") == null or object.call("get_view") == null
	locate_button.pressed.connect(_on_locate_pressed.bind(object))
	actions.add_child(locate_button)

	var rebind_button := Button.new()
	rebind_button.text = "选择目标" if object.get("target_ref") == null else "更换目标"
	rebind_button.tooltip_text = "打开 GUI 预览，选择对象后点击“暴露节点”完成绑定。"
	rebind_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rebind_button.disabled = object.call("get_view") == null
	rebind_button.pressed.connect(_on_rebind_pressed.bind(object))
	actions.add_child(rebind_button)

	add_custom_control(panel)


func _parse_property(
		object: Object,
		_type: Variant.Type,
		name: String,
		_hint_type: PropertyHint,
		_hint_string: String,
		_usage_flags: int,
		_wide: bool
	) -> bool:
	return _can_handle(object) and name == "target_ref"


func _on_locate_pressed(object: Object) -> void:
	if locate_callback.is_valid():
		locate_callback.call(object)


func _on_rebind_pressed(object: Object) -> void:
	if rebind_callback.is_valid():
		rebind_callback.call(object)


func _status_color(status: String) -> Color:
	var theme := EditorInterface.get_editor_theme()
	var color_name := "success_color" if status.begins_with("已连接") else "warning_color"
	if theme.has_color(color_name, "Editor"):
		return theme.get_color(color_name, "Editor")
	return Color(0.4, 0.85, 0.5) if color_name == "success_color" else Color(1.0, 0.7, 0.3)
