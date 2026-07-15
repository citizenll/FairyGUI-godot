@tool
extends VBoxContainer

const EventBindingService := preload("res://addons/fairygui/editor/event_binding_service.gd")

var _view_ref: WeakRef
var _model: Dictionary
var _add_callback: Callable
var _remove_callback: Callable
var _open_callback: Callable
var _toggle_callback: Callable
var _updating_method: bool = false
var _method_dirty: bool = false

var _summary: Label
var _bindings_tree: Tree
var _target_picker: OptionButton
var _event_picker: OptionButton
var _method_edit: LineEdit
var _capture_check: CheckBox
var _action_status: Label
var _add_button: Button
var _remove_button: Button
var _open_button: Button
var _toggle_button: Button


func _init() -> void:
	name = "FairyGUIEventBindingInspector"
	add_theme_constant_override("separation", 4)
	_build_ui()


func configure(
		view: FGUIView,
		model: Dictionary,
		add_callback: Callable,
		remove_callback: Callable,
		open_callback: Callable,
		toggle_callback: Callable
	) -> void:
	_view_ref = weakref(view)
	_model = model
	_add_callback = add_callback
	_remove_callback = remove_callback
	_open_callback = open_callback
	_toggle_callback = toggle_callback
	_populate_bindings()
	_populate_targets()
	_update_summary()


func _build_ui() -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	add_child(header)
	var title := Label.new()
	title.text = "FairyGUI 事件连接"
	title.tooltip_text = "将 FairyGUI 对象发出的事件连接到当前界面脚本中的处理函数。"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_summary = Label.new()
	header.add_child(_summary)
	var help_button := Button.new()
	help_button.flat = true
	help_button.focus_mode = Control.FOCUS_NONE
	help_button.tooltip_text = "选择目标对象和触发事件后，插件会保存连接并生成缺失的处理函数。"
	header.add_child(help_button)
	var theme := EditorInterface.get_editor_theme()
	if theme.has_icon("Help", "EditorIcons"):
		help_button.icon = theme.get_icon("Help", "EditorIcons")

	_bindings_tree = Tree.new()
	_bindings_tree.custom_minimum_size.y = 84.0
	_bindings_tree.columns = 3
	_bindings_tree.column_titles_visible = true
	_bindings_tree.set_column_title(0, "目标对象")
	_bindings_tree.set_column_title(1, "触发事件")
	_bindings_tree.set_column_title(2, "处理函数")
	_bindings_tree.set_column_expand(0, true)
	_bindings_tree.set_column_expand(1, false)
	_bindings_tree.set_column_expand(2, true)
	_bindings_tree.set_column_custom_minimum_width(1, 92)
	_bindings_tree.hide_root = true
	_bindings_tree.select_mode = Tree.SELECT_ROW
	_bindings_tree.item_selected.connect(_on_binding_selected)
	_bindings_tree.item_activated.connect(_on_open_pressed)
	add_child(_bindings_tree)

	var separator := HSeparator.new()
	add_child(separator)
	var create_label := Label.new()
	create_label.text = "新建事件连接"
	add_child(create_label)

	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 4)
	add_child(target_row)
	var target_label := _field_label("目标对象")
	target_row.add_child(target_label)
	_target_picker = OptionButton.new()
	_target_picker.tooltip_text = "选择真实 .fui 层级中的目标对象"
	_target_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_picker.item_selected.connect(_on_target_selected)
	target_row.add_child(_target_picker)

	var event_row := HBoxContainer.new()
	event_row.add_theme_constant_override("separation", 4)
	add_child(event_row)
	var event_label := _field_label("触发事件")
	event_row.add_child(event_label)
	_event_picker = OptionButton.new()
	_event_picker.tooltip_text = "选择目标对象支持的 FairyGUI 事件"
	_event_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event_picker.item_selected.connect(_on_event_selected)
	event_row.add_child(_event_picker)
	_capture_check = CheckBox.new()
	_capture_check.text = "捕获阶段"
	_capture_check.tooltip_text = "高级选项：在事件到达目标对象之前调用处理函数。一般点击事件无需启用。"
	_capture_check.toggled.connect(_on_capture_toggled)
	event_row.add_child(_capture_check)

	var method_row := HBoxContainer.new()
	method_row.add_theme_constant_override("separation", 4)
	add_child(method_row)
	var method_label := _field_label("处理函数")
	method_row.add_child(method_label)
	_method_edit = LineEdit.new()
	_method_edit.placeholder_text = "例如 _on_start_button_clicked"
	_method_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_method_edit.text_changed.connect(_on_method_changed)
	method_row.add_child(_method_edit)
	_add_button = Button.new()
	_add_button.text = "连接并生成函数"
	_add_button.tooltip_text = "保存绑定，并在界面脚本中生成缺失的处理函数"
	_add_button.pressed.connect(_on_add_pressed)
	method_row.add_child(_add_button)
	_action_status = Label.new()
	_action_status.visible = false
	_action_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_action_status)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 4)
	add_child(actions)
	_open_button = Button.new()
	_open_button.text = "打开处理函数"
	_open_button.disabled = true
	_open_button.pressed.connect(_on_open_pressed)
	actions.add_child(_open_button)
	_toggle_button = Button.new()
	_toggle_button.text = "停用"
	_toggle_button.disabled = true
	_toggle_button.pressed.connect(_on_toggle_pressed)
	actions.add_child(_toggle_button)
	_remove_button = Button.new()
	_remove_button.text = "删除"
	_remove_button.disabled = true
	_remove_button.pressed.connect(_on_remove_pressed)
	actions.add_child(_remove_button)
	_apply_icons()


func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 68.0
	return label


func _apply_icons() -> void:
	var theme := EditorInterface.get_editor_theme()
	_set_icon(_add_button, theme, "Add")
	_set_icon(_open_button, theme, "Script")
	_set_icon(_toggle_button, theme, "GuiVisibilityVisible")
	_set_icon(_remove_button, theme, "Remove")


func _set_icon(button: Button, theme: Theme, icon_name: String) -> void:
	if button != null and theme.has_icon(icon_name, "EditorIcons"):
		button.icon = theme.get_icon(icon_name, "EditorIcons")


func _populate_bindings() -> void:
	_bindings_tree.clear()
	var root := _bindings_tree.create_item()
	var rows: Array = _model.get("bindings", [])
	var first_item: TreeItem
	if rows.is_empty():
		var empty_item := _bindings_tree.create_item(root)
		empty_item.set_text(0, "尚未连接事件")
		empty_item.set_custom_color(0, _muted_color())
	for row: Dictionary in rows:
		var item := _bindings_tree.create_item(root)
		if first_item == null:
			first_item = item
		var target_label := str(row.get("target", ""))
		if not bool(row.get("enabled", true)):
			target_label = "[停用] %s" % target_label
		item.set_text(0, target_label)
		item.set_text(1, str(row.get("event", "")))
		item.set_text(2, str(row.get("handler", "")))
		item.set_metadata(0, int(row.get("index", -1)))
		item.set_metadata(1, bool(row.get("enabled", true)))
		var tooltip := "%s\n事件常量：FGUIEvents.%s%s" % [
			row.get("status", ""),
			row.get("event_constant", ""),
			"\n捕获阶段" if bool(row.get("capture", false)) else "",
		]
		for column in 3:
			item.set_tooltip_text(column, tooltip)
		var severity := str(row.get("severity", "success"))
		if severity != "success":
			var color := _status_color(severity)
			for column in 3:
				item.set_custom_color(column, color)
	_remove_button.disabled = true
	_open_button.disabled = true
	_toggle_button.disabled = true
	if first_item != null:
		first_item.select(0)
		_on_binding_selected()


func _populate_targets() -> void:
	_target_picker.clear()
	var selected_index := 0
	var preferred_key := str(_model.get("preferred_target_key", ""))
	var targets: Array = _model.get("targets", [])
	for index in targets.size():
		var target: Dictionary = targets[index]
		_target_picker.add_item("%s · %s" % [target.get("label", ""), target.get("type", "")])
		_target_picker.set_item_metadata(index, target)
		_target_picker.get_popup().set_item_tooltip(index, "FUI 路径：%s" % target.get("path_label", "界面根节点"))
		if str(target.get("key", "")) == preferred_key:
			selected_index = index
	_target_picker.disabled = targets.is_empty()
	if not targets.is_empty():
		_target_picker.select(selected_index)
	_populate_events()
	_refresh_add_action()


func _populate_events() -> void:
	_event_picker.clear()
	var target := _selected_target()
	for event: Dictionary in target.get("events", []):
		var index := _event_picker.item_count
		_event_picker.add_item(str(event.get("label", "")))
		_event_picker.set_item_metadata(index, event)
		_event_picker.get_popup().set_item_tooltip(index, "FGUIEvents.%s" % event.get("constant", ""))
	_event_picker.disabled = _event_picker.item_count == 0
	if _event_picker.item_count > 0:
		_event_picker.select(0)
	_method_dirty = false
	_update_suggested_method()
	_refresh_add_action()


func _update_summary() -> void:
	var count := (_model.get("bindings", []) as Array).size()
	var errors := int(_model.get("error_count", 0))
	var warnings := int(_model.get("warning_count", 0))
	if errors > 0:
		_summary.text = "%d 项，%d 个错误" % [count, errors]
		_summary.add_theme_color_override("font_color", _status_color("error"))
	elif warnings > 0:
		_summary.text = "%d 项，%d 个警告" % [count, warnings]
		_summary.add_theme_color_override("font_color", _status_color("warning"))
	else:
		_summary.text = "%d 项正常" % count if count > 0 else "暂无连接"
		_summary.add_theme_color_override("font_color", _status_color("success"))


func _on_target_selected(_index: int) -> void:
	_populate_events()


func _on_event_selected(_index: int) -> void:
	if not _method_dirty:
		_update_suggested_method()
	_refresh_add_action()


func _on_method_changed(_value: String) -> void:
	if not _updating_method:
		_method_dirty = true
	_refresh_add_action()


func _on_capture_toggled(_enabled: bool) -> void:
	_refresh_add_action()


func _update_suggested_method() -> void:
	var target := _selected_target()
	var event := _selected_event()
	if target.is_empty() or event.is_empty():
		return
	var service := EventBindingService.new()
	_updating_method = true
	_method_edit.text = str(service.suggest_handler(target, str(event.get("value", ""))))
	_method_edit.caret_column = _method_edit.text.length()
	_method_edit.remove_theme_color_override("font_color")
	_method_edit.tooltip_text = ""
	_updating_method = false
	_refresh_add_action()


func _refresh_add_action() -> void:
	if _add_button == null:
		return
	_add_button.text = "连接并生成函数"
	_add_button.tooltip_text = "保存事件连接，并在界面脚本中生成缺失的处理函数"
	if bool(_model.get("pending", false)):
		_add_button.disabled = true
		_add_button.text = "处理中..."
		_set_action_status("正在等待 Godot 完成脚本更新...", "success")
		return
	if not bool(_model.get("script_available", false)):
		_add_button.disabled = true
		_set_action_status("请先使用上方“创建界面脚本”。", "warning")
		return
	var target := _selected_target()
	var event := _selected_event()
	if target.is_empty() or event.is_empty():
		_add_button.disabled = true
		_set_action_status("当前组件没有可连接的目标或事件。", "warning")
		return
	var method_name := _method_edit.text.strip_edges()
	if not method_name.is_valid_ascii_identifier():
		_add_button.disabled = true
		_set_action_status("处理函数名称无效。", "error")
		return
	_add_button.disabled = false
	if _has_matching_binding(target, event, method_name, _capture_check.button_pressed):
		_add_button.text = "打开已有处理函数"
		_add_button.tooltip_text = "此事件已经连接；打开现有函数，函数缺失时自动补全"
		_set_action_status("此事件已经连接。", "success")
	else:
		_set_action_status("", "success")


func _has_matching_binding(
		target: Dictionary,
		event: Dictionary,
		method_name: String,
		capture: bool
	) -> bool:
	var target_key := str(target.get("key", ""))
	var event_name := str(event.get("value", ""))
	for row: Dictionary in _model.get("bindings", []):
		if str(row.get("target_key", "")) == target_key \
				and str(row.get("event_name", "")) == event_name \
				and str(row.get("handler", "")) == method_name \
				and bool(row.get("capture", false)) == capture:
			return true
	return false


func _set_action_status(message: String, severity: String) -> void:
	if _action_status == null:
		return
	_action_status.text = message
	_action_status.visible = message != ""
	if message != "":
		_action_status.add_theme_color_override("font_color", _status_color(severity))


func _on_add_pressed() -> void:
	var view := _view_ref.get_ref() as FGUIView if _view_ref != null else null
	var target := _selected_target()
	var event := _selected_event()
	var method_name := _method_edit.text.strip_edges()
	if view == null or target.is_empty() or event.is_empty():
		return
	if not method_name.is_valid_ascii_identifier():
		_method_edit.add_theme_color_override("font_color", _status_color("error"))
		_method_edit.tooltip_text = "请输入有效的 GDScript 函数名"
		return
	_method_edit.remove_theme_color_override("font_color")
	_method_edit.tooltip_text = ""
	if _add_callback.is_valid():
		_add_button.disabled = true
		_add_button.text = "处理中..."
		_set_action_status("正在更新界面脚本和场景连接...", "success")
		_add_callback.call(
			view,
			target.get("path", PackedStringArray()),
			str(event.get("value", "")),
			StringName(method_name),
			_capture_check.button_pressed
		)
	else:
		_refresh_add_action()


func _on_binding_selected() -> void:
	var selected := _bindings_tree.get_selected()
	var has_selection := selected != null and int(selected.get_metadata(0)) >= 0
	_remove_button.disabled = not has_selection
	_open_button.disabled = not has_selection
	_toggle_button.disabled = not has_selection
	if has_selection:
		_toggle_button.text = "停用" if bool(selected.get_metadata(1)) else "启用"


func _on_remove_pressed() -> void:
	var view := _view_ref.get_ref() as FGUIView if _view_ref != null else null
	var selected := _bindings_tree.get_selected()
	if view == null or selected == null or not _remove_callback.is_valid():
		return
	_remove_callback.call(view, int(selected.get_metadata(0)))


func _on_toggle_pressed() -> void:
	var view := _view_ref.get_ref() as FGUIView if _view_ref != null else null
	var selected := _bindings_tree.get_selected()
	if view == null or selected == null or not _toggle_callback.is_valid():
		return
	_toggle_callback.call(view, int(selected.get_metadata(0)))


func _on_open_pressed() -> void:
	var view := _view_ref.get_ref() as FGUIView if _view_ref != null else null
	var selected := _bindings_tree.get_selected()
	if view == null or selected == null or not _open_callback.is_valid():
		return
	_open_callback.call(view, int(selected.get_metadata(0)))


func _selected_target() -> Dictionary:
	if _target_picker.item_count == 0 or _target_picker.selected < 0:
		return {}
	var value: Variant = _target_picker.get_item_metadata(_target_picker.selected)
	return value if value is Dictionary else {}


func _selected_event() -> Dictionary:
	if _event_picker.item_count == 0 or _event_picker.selected < 0:
		return {}
	var value: Variant = _event_picker.get_item_metadata(_event_picker.selected)
	return value if value is Dictionary else {}


func _status_color(severity: String) -> Color:
	var theme := EditorInterface.get_editor_theme()
	var color_name := "success_color"
	if severity == "error":
		color_name = "error_color"
	elif severity == "warning":
		color_name = "warning_color"
	return theme.get_color(color_name, "Editor") if theme.has_color(color_name, "Editor") else Color.WHITE


func _muted_color() -> Color:
	var theme := EditorInterface.get_editor_theme()
	return theme.get_color("font_disabled_color", "Editor") \
		if theme.has_color("font_disabled_color", "Editor") else Color(0.6, 0.6, 0.6)
