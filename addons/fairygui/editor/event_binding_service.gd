@tool
extends RefCounted

const BusinessScriptGenerator := preload("res://addons/fairygui/editor/business_script_generator.gd")
const EventBinding := preload("res://addons/fairygui/ui/event_binding.gd")

const META_PREFERRED_TARGET := "_fairygui_event_binding_target"
const EVENT_DEFINITIONS := {
	FGUIEvents.CLICK: {"constant": "CLICK", "label": "点击", "suffix": "clicked"},
	FGUIEvents.RIGHT_CLICK: {"constant": "RIGHT_CLICK", "label": "右键点击", "suffix": "right_clicked"},
	FGUIEvents.TOUCH_BEGIN: {"constant": "TOUCH_BEGIN", "label": "按下", "suffix": "touch_began"},
	FGUIEvents.TOUCH_END: {"constant": "TOUCH_END", "label": "释放", "suffix": "touch_ended"},
	FGUIEvents.ROLL_OVER: {"constant": "ROLL_OVER", "label": "鼠标进入", "suffix": "roll_over"},
	FGUIEvents.ROLL_OUT: {"constant": "ROLL_OUT", "label": "鼠标移出", "suffix": "roll_out"},
	FGUIEvents.STATE_CHANGED: {"constant": "STATE_CHANGED", "label": "状态改变", "suffix": "changed"},
	FGUIEvents.CLICK_ITEM: {"constant": "CLICK_ITEM", "label": "点击列表项", "suffix": "item_clicked"},
	FGUIEvents.RIGHT_CLICK_ITEM: {"constant": "RIGHT_CLICK_ITEM", "label": "右键列表项", "suffix": "item_right_clicked"},
	FGUIEvents.SCROLL: {"constant": "SCROLL", "label": "滚动", "suffix": "scrolled"},
	FGUIEvents.SCROLL_END: {"constant": "SCROLL_END", "label": "滚动结束", "suffix": "scroll_ended"},
	FGUIEvents.PULL_DOWN_RELEASE: {"constant": "PULL_DOWN_RELEASE", "label": "下拉释放", "suffix": "pull_down_released"},
	FGUIEvents.PULL_UP_RELEASE: {"constant": "PULL_UP_RELEASE", "label": "上拉释放", "suffix": "pull_up_released"},
	FGUIEvents.DROP: {"constant": "DROP", "label": "接收拖放", "suffix": "dropped"},
	FGUIEvents.DRAG_START: {"constant": "DRAG_START", "label": "开始拖动", "suffix": "drag_started"},
	FGUIEvents.DRAG_MOVE: {"constant": "DRAG_MOVE", "label": "拖动", "suffix": "dragged"},
	FGUIEvents.DRAG_END: {"constant": "DRAG_END", "label": "结束拖动", "suffix": "drag_ended"},
	FGUIEvents.CLICK_LINK: {"constant": "CLICK_LINK", "label": "点击链接", "suffix": "link_clicked"},
	FGUIEvents.FOCUS_IN: {"constant": "FOCUS_IN", "label": "获得焦点", "suffix": "focus_entered"},
	FGUIEvents.FOCUS_OUT: {"constant": "FOCUS_OUT", "label": "失去焦点", "suffix": "focus_exited"},
	FGUIEvents.SUBMIT: {"constant": "SUBMIT", "label": "提交文本", "suffix": "submitted"},
	FGUIEvents.PLAY_END: {"constant": "PLAY_END", "label": "播放结束", "suffix": "play_ended"},
	FGUIEvents.GRIP_TOUCH_END: {"constant": "GRIP_TOUCH_END", "label": "滑块释放", "suffix": "grip_released"},
}


func build_model(view: FGUIView) -> Dictionary:
	var user_script := BusinessScriptGenerator.get_user_script(view)
	var script_available := user_script != null \
		and user_script.resource_path.begins_with("res://") \
		and FileAccess.file_exists(user_script.resource_path)
	var model := {
		"targets": [],
		"bindings": [],
		"script_available": script_available,
		"preferred_target_key": "",
		"error_count": 0,
		"warning_count": 0,
	}
	if view == null or view.package == null:
		return model

	var temporary_view: FGUIView
	var root_object := view.fairy
	if root_object == null:
		temporary_view = FGUIView.new()
		temporary_view.package = view.package
		temporary_view.component_name = view.component_name
		temporary_view.preview_in_editor = true
		temporary_view.refresh_preview()
		root_object = temporary_view.fairy
	if root_object == null:
		if temporary_view != null:
			temporary_view.free()
		return model

	var target_lookup: Dictionary = {}
	_append_target(root_object, PackedStringArray(), view.component_name, model.targets, target_lookup)
	var preferred: Variant = view.get_meta(META_PREFERRED_TARGET, PackedStringArray())
	if preferred is PackedStringArray:
		model.preferred_target_key = target_path_key(preferred)

	var duplicate_keys: Dictionary = {}
	for index in view.event_bindings.size():
		var binding: EventBinding = view.event_bindings[index]
		if binding == null:
			model.bindings.append({
				"index": index,
				"target": "<empty>",
				"event": "",
				"handler": "",
				"status": "绑定资源为空",
				"severity": "error",
			})
			model.error_count = int(model.error_count) + 1
			continue
		var key := binding.get_key()
		var target_key := target_path_key(binding.target_path)
		var target: Dictionary = target_lookup.get(target_key, {})
		var event := get_event_info(binding.event_name)
		var status := "正常"
		var severity := "success"
		if target.is_empty():
			status = "目标不存在"
			severity = "error"
		elif event.is_empty() or not _target_supports_event(target, binding.event_name):
			status = "目标不支持此事件"
			severity = "warning"
		elif binding.handler == &"":
			status = "处理函数为空"
			severity = "error"
		elif not view.has_method(binding.handler):
			status = "处理函数不存在"
			severity = "warning"
		elif duplicate_keys.has(key):
			status = "重复绑定"
			severity = "warning"
		duplicate_keys[key] = true
		if severity == "error":
			model.error_count = int(model.error_count) + 1
		elif severity == "warning":
			model.warning_count = int(model.warning_count) + 1
		model.bindings.append({
			"index": index,
			"target": str(target.get("label", binding.get_target_label())),
			"event": str(event.get("label", binding.event_name)),
			"event_constant": str(event.get("constant", binding.event_name)),
			"handler": str(binding.handler),
			"capture": binding.capture,
			"enabled": binding.enabled,
			"status": status,
			"severity": severity,
		})

	if temporary_view != null:
		temporary_view.call("_clear_preview")
		temporary_view.free()
	return model


func suggest_handler(target: Dictionary, event_name: String) -> StringName:
	var path: PackedStringArray = target.get("path", PackedStringArray())
	var source_name := str(target.get("component_name", "view")) if path.is_empty() else path[path.size() - 1]
	var token := _identifier_token(source_name)
	if token == "":
		token = "target_%s" % target_path_key(path).md5_text().substr(0, 8)
	var event := get_event_info(event_name)
	var suffix := str(event.get("suffix", "event"))
	return StringName("_on_%s_%s" % [token, suffix])


func get_event_info(event_name: String) -> Dictionary:
	var definition: Dictionary = EVENT_DEFINITIONS.get(event_name, {})
	if definition.is_empty():
		return {}
	var result := definition.duplicate(true)
	result.value = event_name
	return result


func target_path_key(path: PackedStringArray) -> String:
	return JSON.stringify(Array(path))


func _append_target(
		value: FGUIObject,
		path: PackedStringArray,
		component_name: String,
		result: Array,
		lookup: Dictionary
	) -> void:
	if value == null:
		return
	var key := target_path_key(path)
	if lookup.has(key):
		return
	var events := _events_for_object(value)
	var label := "%s（界面根节点）" % component_name if path.is_empty() else str(path[path.size() - 1])
	var target := {
		"key": key,
		"path": path.duplicate(),
		"label": label,
		"path_label": "界面根节点" if path.is_empty() else " / ".join(path),
		"type": _object_type_name(value),
		"component_name": component_name,
		"events": events,
	}
	result.append(target)
	lookup[key] = target
	if not value is FGUIComponent:
		return
	for child: FGUIObject in (value as FGUIComponent).children:
		if child == null or child.name == "":
			continue
		var child_path := path.duplicate()
		child_path.append(child.name)
		_append_target(child, child_path, component_name, result, lookup)


func _events_for_object(value: FGUIObject) -> Array[Dictionary]:
	var names := PackedStringArray()
	if value is FGUIList or value is FGUITree:
		_append_event(names, FGUIEvents.CLICK_ITEM)
		_append_event(names, FGUIEvents.RIGHT_CLICK_ITEM)
	if value is FGUIButton or value is FGUIComboBox or value is FGUISlider or value is FGUITextInput:
		_append_event(names, FGUIEvents.STATE_CHANGED)
	if value is FGUITextInput:
		_append_event(names, FGUIEvents.SUBMIT)
		_append_event(names, FGUIEvents.FOCUS_IN)
		_append_event(names, FGUIEvents.FOCUS_OUT)
	if value is FGUITextField:
		_append_event(names, FGUIEvents.CLICK_LINK)
	if value is FGUIMovieClip:
		_append_event(names, FGUIEvents.PLAY_END)
	if value is FGUISlider:
		_append_event(names, FGUIEvents.GRIP_TOUCH_END)
	if value is FGUIList or (value is FGUIComponent and (value as FGUIComponent).scroll_pane != null):
		_append_event(names, FGUIEvents.SCROLL)
		_append_event(names, FGUIEvents.SCROLL_END)
		_append_event(names, FGUIEvents.PULL_DOWN_RELEASE)
		_append_event(names, FGUIEvents.PULL_UP_RELEASE)
	_append_event(names, FGUIEvents.CLICK)
	_append_event(names, FGUIEvents.RIGHT_CLICK)
	_append_event(names, FGUIEvents.TOUCH_BEGIN)
	_append_event(names, FGUIEvents.TOUCH_END)
	_append_event(names, FGUIEvents.ROLL_OVER)
	_append_event(names, FGUIEvents.ROLL_OUT)
	_append_event(names, FGUIEvents.DROP)
	_append_event(names, FGUIEvents.DRAG_START)
	_append_event(names, FGUIEvents.DRAG_MOVE)
	_append_event(names, FGUIEvents.DRAG_END)
	var result: Array[Dictionary] = []
	for event_name: String in names:
		result.append(get_event_info(event_name))
	return result


func _append_event(result: PackedStringArray, event_name: String) -> void:
	if not result.has(event_name):
		result.append(event_name)


func _target_supports_event(target: Dictionary, event_name: String) -> bool:
	for event: Dictionary in target.get("events", []):
		if str(event.get("value", "")) == event_name:
			return true
	return false


func _identifier_token(value: String) -> String:
	var snake := value.to_snake_case().to_lower()
	var result := ""
	for index in snake.length():
		var code := snake.unicode_at(index)
		var is_letter := (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
		var is_digit := code >= 48 and code <= 57
		if is_letter or is_digit or code == 95:
			result += String.chr(code)
	while result.contains("__"):
		result = result.replace("__", "_")
	result = result.trim_prefix("_").trim_suffix("_")
	if result != "" and result.unicode_at(0) >= 48 and result.unicode_at(0) <= 57:
		result = "node_%s" % result
	return result


func _object_type_name(value: FGUIObject) -> String:
	if value is FGUITree:
		return "树"
	if value is FGUIList:
		return "列表"
	if value is FGUIComboBox:
		return "下拉框"
	if value is FGUISlider:
		return "滑动条"
	if value is FGUIProgressBar:
		return "进度条"
	if value is FGUIButton:
		return "按钮"
	if value is FGUITextInput:
		return "输入框"
	if value is FGUIRichTextField:
		return "富文本"
	if value is FGUITextField:
		return "文本"
	if value is FGUIMovieClip:
		return "动画"
	if value is FGUIImage:
		return "图片"
	if value is FGUILoader3D:
		return "3D 加载器"
	if value is FGUILoader:
		return "加载器"
	if value is FGUIGraph:
		return "图形"
	if value is FGUIGroup:
		return "分组"
	if value is FGUIComponent:
		return "组件"
	return "对象"
