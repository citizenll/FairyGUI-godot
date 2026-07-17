@tool
extends EditorPlugin

const FUIImportPlugin := preload("res://addons/fairygui/editor/fui_import_plugin.gd")
const BindingCodeGenerator := preload("res://addons/fairygui/editor/binding_codegen.gd")
const BindingInspectorPlugin := preload("res://addons/fairygui/editor/binding_inspector_plugin.gd")
const BindingExportPlugin := preload("res://addons/fairygui/editor/binding_export_plugin.gd")
const FUIPreviewPanel := preload("res://addons/fairygui/editor/fui_preview_panel.gd")
const FUICanvasDropOverlay := preload("res://addons/fairygui/editor/fui_canvas_drop_overlay.gd")
const BusinessScriptGenerator := preload("res://addons/fairygui/editor/business_script_generator.gd")
const EventBinding := preload("res://addons/fairygui/ui/event_binding.gd")
const EventBindingService := preload("res://addons/fairygui/editor/event_binding_service.gd")
const EventHandlerGenerator := preload("res://addons/fairygui/editor/event_handler_generator.gd")
const FairyGUIDebuggerPlugin := preload("res://addons/fairygui/editor/fairygui_debugger_plugin.gd")

const SETTING_AUTO_GENERATE := "fairygui/codegen/auto_generate"
const SETTING_OUTPUT_DIR := "fairygui/codegen/output_dir"
const SETTING_REGISTRY_PATH := "fairygui/codegen/registry_path"
const SETTING_CLASS_PREFIX := "fairygui/codegen/class_prefix"
const SETTING_INCLUDE_DEFAULT_NAMES := "fairygui/codegen/include_default_names"
const SETTING_INCLUDE_INTERNAL_COMPONENTS := "fairygui/codegen/include_internal_components"
const TOOL_MENU_NAME := "Generate FairyGUI Bindings"
const GENERATION_DEBOUNCE_MSEC := 250

var _fui_importer: EditorImportPlugin
var _binding_inspector: EditorInspectorPlugin
var _binding_exporter: EditorExportPlugin
var _preview_panel: Control
var _preview_bottom_button: Button
var _canvas_drop_overlay: Control
var _debugger_plugin: EditorDebuggerPlugin
var _canvas_overlay_install_attempts: int = 0
var _generation_queued: bool = false
var _generation_running: bool = false
var _generation_requested_while_running: bool = false
var _generation_force_queued: bool = false
var _generation_force_requested_while_running: bool = false
var _generation_due_msec: int = 0
var _pending_event_bindings: Dictionary = {}


func _enter_tree() -> void:
	set_process(false)
	_register_project_settings()
	_fui_importer = FUIImportPlugin.new()
	add_import_plugin(_fui_importer, true)

	_binding_inspector = BindingInspectorPlugin.new()
	_binding_inspector.generate_callback = Callable(self, "_on_inspector_generate")
	_binding_inspector.open_callback = Callable(self, "_on_inspector_open")
	_binding_inspector.preview_callback = Callable(self, "_on_inspector_preview")
	_binding_inspector.business_script_callback = Callable(self, "_on_inspector_business_script")
	_binding_inspector.diagnostic_path_callback = Callable(self, "_on_diagnostic_path")
	_binding_inspector.event_model_callback = Callable(self, "_get_event_binding_model")
	_binding_inspector.event_add_callback = Callable(self, "_on_event_binding_add")
	_binding_inspector.event_remove_callback = Callable(self, "_on_event_binding_remove")
	_binding_inspector.event_open_callback = Callable(self, "_on_event_binding_open")
	_binding_inspector.event_toggle_callback = Callable(self, "_on_event_binding_toggle")
	add_inspector_plugin(_binding_inspector)
	_binding_exporter = BindingExportPlugin.new()
	_binding_exporter.generate_callback = Callable(self, "ensure_bindings_current")
	add_export_plugin(_binding_exporter)
	add_tool_menu_item(TOOL_MENU_NAME, Callable(self, "generate_all_bindings"))
	_preview_panel = FUIPreviewPanel.new()
	_preview_bottom_button = add_control_to_bottom_panel(_preview_panel, "GUI预览")
	call_deferred("_configure_preview_bottom_button")
	_debugger_plugin = FairyGUIDebuggerPlugin.new()
	add_debugger_plugin(_debugger_plugin)
	call_deferred("_install_canvas_drop_overlay")

	var filesystem := get_editor_interface().get_resource_filesystem()
	if not filesystem.resources_reimported.is_connected(_on_resources_reimported):
		filesystem.resources_reimported.connect(_on_resources_reimported)


func _exit_tree() -> void:
	set_process(false)
	_generation_queued = false
	_generation_requested_while_running = false
	_generation_force_queued = false
	_generation_force_requested_while_running = false
	_pending_event_bindings.clear()
	if _canvas_drop_overlay != null:
		_canvas_drop_overlay.queue_free()
		_canvas_drop_overlay = null
	if _debugger_plugin != null:
		remove_debugger_plugin(_debugger_plugin)
		_debugger_plugin = null
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.resources_reimported.is_connected(_on_resources_reimported):
		filesystem.resources_reimported.disconnect(_on_resources_reimported)
	remove_tool_menu_item(TOOL_MENU_NAME)
	if _preview_panel != null:
		_preview_panel.call("clear_preview")
		remove_control_from_bottom_panel(_preview_panel)
		_preview_panel.queue_free()
		_preview_panel = null
		_preview_bottom_button = null
	if _binding_exporter != null:
		remove_export_plugin(_binding_exporter)
		_binding_exporter = null
	if _binding_inspector != null:
		remove_inspector_plugin(_binding_inspector)
		_binding_inspector = null
	if _fui_importer != null:
		remove_import_plugin(_fui_importer)
		_fui_importer = null


func ensure_bindings_current() -> Dictionary:
	return generate_all_bindings(false)


func generate_all_bindings(force: bool = true) -> Dictionary:
	if _generation_running:
		_generation_requested_while_running = true
		_generation_force_requested_while_running = _generation_force_requested_while_running or force
		return {"ok": false, "busy": true}
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.is_scanning() or filesystem.is_importing() or filesystem.get_filesystem() == null:
		_queue_generation(force)
		return {"ok": false, "busy": true, "reason": "filesystem_not_ready"}
	_generation_queued = false
	_generation_force_queued = false
	set_process(false)
	_generation_running = true

	var resource_paths := _collect_codegen_resources()
	var generator := BindingCodeGenerator.new()
	var output_dir := str(ProjectSettings.get_setting(SETTING_OUTPUT_DIR, BindingCodeGenerator.DEFAULT_OUTPUT_DIR))
	var registry_path := str(ProjectSettings.get_setting(
		SETTING_REGISTRY_PATH,
		"%s/%s" % [output_dir.trim_suffix("/"), BindingCodeGenerator.REGISTRY_FILE]
	))
	var class_prefix := str(ProjectSettings.get_setting(SETTING_CLASS_PREFIX, "UI_"))
	var include_default_names := bool(ProjectSettings.get_setting(SETTING_INCLUDE_DEFAULT_NAMES, false))
	var include_internal_components := bool(ProjectSettings.get_setting(SETTING_INCLUDE_INTERNAL_COMPONENTS, false))
	if not force:
		var freshness := generator.check_current(
			resource_paths,
			output_dir,
			class_prefix,
			include_default_names,
			registry_path,
			include_internal_components
		)
		if bool(freshness.get("current", false)):
			var skipped_result := _skipped_generation_result(freshness)
			_generation_running = false
			_finish_generation_cycle()
			return skipped_result
	var result: Dictionary = generator.generate(
		resource_paths,
		output_dir,
		class_prefix,
		include_default_names,
		registry_path,
		include_internal_components
	)
	_report_generation(result, resource_paths.size())
	_generation_running = false

	if bool(result.get("ok", false)) and _generation_changes_scripts(result):
		filesystem.scan_sources()
		call_deferred("_reload_generated_bindings")

	_finish_generation_cycle()
	return result


func _queue_generation(force: bool = false) -> void:
	if _generation_running:
		_generation_requested_while_running = true
		_generation_force_requested_while_running = _generation_force_requested_while_running or force
		return
	_generation_queued = true
	_generation_force_queued = _generation_force_queued or force
	_generation_due_msec = Time.get_ticks_msec() + GENERATION_DEBOUNCE_MSEC
	set_process(true)


func _process(_delta: float) -> void:
	if not _generation_queued:
		set_process(false)
		return
	if Time.get_ticks_msec() < _generation_due_msec:
		return
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.is_scanning() or filesystem.is_importing() or filesystem.get_filesystem() == null:
		return
	_run_queued_generation()


func _run_queued_generation() -> void:
	if not is_inside_tree() or not _generation_queued:
		return
	var force := _generation_force_queued
	_generation_queued = false
	_generation_force_queued = false
	set_process(false)
	generate_all_bindings(force)


func _on_resources_reimported(paths: PackedStringArray) -> void:
	if _preview_panel != null and paths.has(str(_preview_panel.call("get_current_resource_path"))):
		_preview_panel.call_deferred("reload_current")
	if not bool(ProjectSettings.get_setting(SETTING_AUTO_GENERATE, true)):
		return
	for path: String in paths:
		if path.get_extension().to_lower() == "fui":
			_queue_generation(false)
			return


func _on_inspector_generate(object: Object) -> void:
	generate_all_bindings()
	object.notify_property_list_changed()


func _on_inspector_preview(object: Object) -> void:
	if object is FGUIPackageResource:
		_open_preview(object as FGUIPackageResource)
	elif object is FGUIView:
		var view := object as FGUIView
		_open_preview(view.package, view.component_name, view)


func _on_inspector_open(object: Object) -> void:
	if not object is FGUIView:
		return
	var path := _binding_path_for_view(object as FGUIView)
	if path == "":
		var result := generate_all_bindings()
		if not bool(result.get("ok", false)):
			return
		path = _binding_path_for_view(object as FGUIView)
	if path == "" or not ResourceLoader.exists(path):
		push_warning("[FairyGUI codegen] Binding script is not available yet. Wait for the filesystem scan and try again.")
		return
	var script := ResourceLoader.load(path) as Script
	if script != null:
		get_editor_interface().edit_script(script)


func _on_inspector_business_script(object: Object) -> void:
	if not object is FGUIView:
		return
	var view := object as FGUIView
	var existing_script := BusinessScriptGenerator.get_user_script(view)
	if existing_script != null:
		get_editor_interface().edit_script(existing_script)
		return
	if view.package == null:
		push_error("[FairyGUI editor] 请先为 FGUIView 配置 .fui 包。")
		return
	_prepare_business_script.call_deferred(weakref(view), 0, true)


func _prepare_business_script(view_ref: WeakRef, attempt: int, use_undo: bool) -> void:
	var view := view_ref.get_ref() as FGUIView
	if view == null or not is_inside_tree():
		return
	var filesystem := get_editor_interface().get_resource_filesystem()
	if (filesystem.is_scanning() or filesystem.is_importing()) and attempt < 240:
		_prepare_business_script.call_deferred(view_ref, attempt + 1, use_undo)
		return
	var generator := BusinessScriptGenerator.new()
	var binding := generator.resolve_binding(view.package, view.component_name)
	if not bool(binding.ok) or not bool(binding.current):
		var generation := generate_all_bindings()
		if bool(generation.get("busy", false)) and attempt < 240:
			_prepare_business_script.call_deferred(view_ref, attempt + 1, use_undo)
			return
		if not bool(generation.get("ok", false)):
			push_error("[FairyGUI editor] 无法为当前 .fui 生成强类型绑定。")
			return
	var scene_root := get_editor_interface().get_edited_scene_root()
	var scene_path := scene_root.scene_file_path if scene_root != null else ""
	var result := generator.create_for_view(view, scene_path)
	if not bool(result.ok):
		push_error("[FairyGUI editor] 无法创建界面脚本：%s" % result.error)
		return
	get_editor_interface().get_resource_filesystem().scan_sources()
	_attach_business_script_when_ready.call_deferred(
		weakref(view),
		str(result.script_path),
		view.get_script() as Script,
		use_undo,
		0
	)


func _attach_business_script_when_ready(
		view_ref: WeakRef,
		script_path: String,
		previous_script: Script,
		use_undo: bool,
		attempt: int
	) -> void:
	var view := view_ref.get_ref() as FGUIView
	if view == null or not is_inside_tree():
		return
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.is_scanning() and attempt < 240:
		_attach_business_script_when_ready.call_deferred(
			view_ref,
			script_path,
			previous_script,
			use_undo,
			attempt + 1
		)
		return
	var script := ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if script == null:
		push_error("[FairyGUI editor] 界面脚本无法加载：%s" % script_path)
		return
	var state := _capture_view_configuration(view)
	if use_undo:
		var scene_root := get_editor_interface().get_edited_scene_root()
		var undo_redo := get_undo_redo()
		undo_redo.create_action("创建 FairyGUI 界面脚本", UndoRedo.MERGE_DISABLE, scene_root if scene_root != null else view)
		undo_redo.add_do_method(self, "_apply_view_script", view, script, state)
		undo_redo.add_undo_method(self, "_apply_view_script", view, previous_script, state)
		undo_redo.commit_action()
		get_editor_interface().edit_script(script)
	else:
		_apply_view_script(view, script, state)


func _capture_view_configuration(view: FGUIView) -> Dictionary:
	return {
		"package": view.package,
		"component_name": view.component_name,
		"component_script": view.component_script,
		"preview_in_editor": view.preview_in_editor,
		"resize_to_content": view.resize_to_content,
		"match_control_size": view.match_control_size,
		"event_bindings": view.event_bindings.duplicate(),
	}


func _apply_view_script(view: FGUIView, script: Script, state: Dictionary) -> void:
	if view == null:
		return
	view.call("_clear_preview")
	view.call("_disconnect_event_binding_resources")
	view.set_script(script)
	view.package = state.get("package") as FGUIPackageResource
	view.component_name = str(state.get("component_name", ""))
	view.component_script = state.get("component_script") as Script
	view.preview_in_editor = bool(state.get("preview_in_editor", true))
	view.resize_to_content = bool(state.get("resize_to_content", true))
	view.match_control_size = bool(state.get("match_control_size", false))
	_set_view_event_bindings(view, state.get("event_bindings", []))
	view.notify_property_list_changed()


func _get_event_binding_model(object: Object) -> Dictionary:
	if not object is FGUIView:
		return {}
	var view := object as FGUIView
	var model := EventBindingService.new().build_model(view)
	model.pending = _pending_event_bindings.has(str(view.get_instance_id()))
	return model


func _on_event_binding_add(
		object: Object,
		target_path: PackedStringArray,
		event_name: String,
		handler: StringName,
		capture: bool
	) -> void:
	if not object is FGUIView:
		return
	var view := object as FGUIView
	var binding := EventBinding.new()
	binding.target_path = target_path
	binding.event_name = event_name
	binding.handler = handler
	binding.capture = capture
	var operation_key := str(view.get_instance_id())
	if _pending_event_bindings.has(operation_key):
		_show_editor_toast("事件连接正在处理中，请稍候。", 1)
		return
	_pending_event_bindings[operation_key] = true
	_complete_event_binding.call_deferred(weakref(view), binding, operation_key, 0)


func _complete_event_binding(
		view_ref: WeakRef,
		binding: EventBinding,
		operation_key: String,
		attempt: int
	) -> void:
	var view := view_ref.get_ref() as FGUIView
	if view == null or not is_inside_tree():
		_pending_event_bindings.erase(operation_key)
		return
	var filesystem := get_editor_interface().get_resource_filesystem()
	if filesystem.is_scanning() or filesystem.is_importing():
		if attempt < 240:
			_complete_event_binding.call_deferred(view_ref, binding, operation_key, attempt + 1)
			return
		_finish_event_binding_operation(
			view,
			operation_key,
			false,
			"Godot 仍在扫描资源，请稍后重试。"
		)
		return
	var duplicate_index := _find_event_binding(view, binding.get_key())
	var handler_result := EventHandlerGenerator.new().ensure_handler(view, binding.handler)
	if not bool(handler_result.get("ok", false)):
		_finish_event_binding_operation(
			view,
			operation_key,
			false,
			"无法生成事件处理函数：%s" % handler_result.get("error", "")
		)
		return
	if duplicate_index >= 0:
		_open_event_handler(handler_result)
		var duplicate_message := "此事件已经连接，已打开处理函数。"
		if bool(handler_result.get("created", false)):
			duplicate_message = "此事件已经连接，已补全并打开处理函数。"
		elif bool(handler_result.get("saved_editor_changes", false)):
			duplicate_message = "此事件已经连接，已保存并打开处理函数。"
		_finish_event_binding_operation(
			view,
			operation_key,
			true,
			duplicate_message
		)
		return
	var previous: Array[EventBinding] = []
	previous.assign(view.event_bindings)
	var next: Array[EventBinding] = []
	next.assign(view.event_bindings)
	next.append(binding)
	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("连接 FairyGUI 事件", UndoRedo.MERGE_DISABLE, scene_root if scene_root != null else view)
	undo_redo.add_do_method(self, "_set_view_event_bindings", view, next)
	undo_redo.add_undo_method(self, "_set_view_event_bindings", view, previous)
	undo_redo.commit_action()
	_open_event_handler(handler_result)
	var success_message := "已连接事件。"
	if bool(handler_result.get("created", false)):
		success_message = "已连接事件并生成处理函数。"
	if bool(handler_result.get("saved_editor_changes", false)):
		success_message = "已保存界面脚本，%s" % success_message
	_finish_event_binding_operation(view, operation_key, true, success_message)


func _find_event_binding(view: FGUIView, key: String) -> int:
	for index in view.event_bindings.size():
		var existing: EventBinding = view.event_bindings[index]
		if existing != null and existing.get_key() == key:
			return index
	return -1


func _finish_event_binding_operation(
		view: FGUIView,
		operation_key: String,
		success: bool,
		message: String
	) -> void:
	_pending_event_bindings.erase(operation_key)
	if success:
		_show_editor_toast(message, 0)
	else:
		push_error("[FairyGUI editor] %s" % message)
		_show_editor_toast("FairyGUI 事件连接失败", 2, message)
	if view != null:
		view.notify_property_list_changed()


func _show_editor_toast(message: String, severity: int, tooltip: String = "") -> void:
	var editor_interface := get_editor_interface()
	if editor_interface != null and editor_interface.has_method("get_editor_toaster"):
		var toaster: Object = editor_interface.call("get_editor_toaster")
		if toaster != null and toaster.has_method("push_toast"):
			toaster.call("push_toast", message, severity, tooltip)


func _on_event_binding_remove(object: Object, index: int) -> void:
	if not object is FGUIView:
		return
	var view := object as FGUIView
	if index < 0 or index >= view.event_bindings.size():
		return
	var previous: Array[EventBinding] = []
	previous.assign(view.event_bindings)
	var next: Array[EventBinding] = []
	next.assign(view.event_bindings)
	next.remove_at(index)
	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo_redo := get_undo_redo()
	undo_redo.create_action("移除 FairyGUI 事件绑定", UndoRedo.MERGE_DISABLE, scene_root if scene_root != null else view)
	undo_redo.add_do_method(self, "_set_view_event_bindings", view, next)
	undo_redo.add_undo_method(self, "_set_view_event_bindings", view, previous)
	undo_redo.commit_action()


func _on_event_binding_open(object: Object, index: int) -> void:
	if not object is FGUIView:
		return
	var view := object as FGUIView
	if index < 0 or index >= view.event_bindings.size():
		return
	var binding: EventBinding = view.event_bindings[index]
	if binding == null or binding.handler == &"":
		return
	var result := EventHandlerGenerator.new().ensure_handler(view, binding.handler)
	if not bool(result.get("ok", false)):
		push_error("[FairyGUI editor] 无法打开事件处理函数：%s" % result.get("error", ""))
		return
	_open_event_handler(result)


func _on_event_binding_toggle(object: Object, index: int) -> void:
	if not object is FGUIView:
		return
	var view := object as FGUIView
	if index < 0 or index >= view.event_bindings.size():
		return
	var original: EventBinding = view.event_bindings[index]
	if original == null:
		return
	var replacement := original.duplicate(true) as EventBinding
	if replacement == null:
		return
	replacement.enabled = not original.enabled
	var previous: Array[EventBinding] = []
	previous.assign(view.event_bindings)
	var next: Array[EventBinding] = []
	next.assign(view.event_bindings)
	next[index] = replacement
	var scene_root := get_editor_interface().get_edited_scene_root()
	var undo_redo := get_undo_redo()
	var action_name := "启用 FairyGUI 事件绑定" if replacement.enabled else "停用 FairyGUI 事件绑定"
	undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, scene_root if scene_root != null else view)
	undo_redo.add_do_method(self, "_set_view_event_bindings", view, next)
	undo_redo.add_undo_method(self, "_set_view_event_bindings", view, previous)
	undo_redo.commit_action()


func _set_view_event_bindings(view: FGUIView, values: Array) -> void:
	if view == null:
		return
	var typed: Array[EventBinding] = []
	for value: Variant in values:
		if value is EventBinding:
			typed.append(value as EventBinding)
	view.event_bindings = typed
	view.notify_property_list_changed()


func _open_event_handler(result: Dictionary) -> void:
	var script := result.get("script") as Script
	if script == null:
		return
	if bool(result.get("refresh_open_editor", false)):
		var close_error := get_editor_interface().get_script_editor().close_file(script.resource_path)
		if close_error != OK and close_error != ERR_FILE_NOT_FOUND:
			push_warning("[FairyGUI editor] 无法刷新已打开的界面脚本：%s" % error_string(close_error))
	get_editor_interface().edit_script(script, int(result.get("line", -1)), 0, true)


func _on_diagnostic_path(path: String) -> void:
	if path == "":
		return
	var target := path
	while target.begins_with("res://") \
			and not ResourceLoader.exists(target) \
			and not FileAccess.file_exists(target) \
			and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(target)) \
			and target != "res://":
		target = target.get_base_dir()
	get_editor_interface().get_file_system_dock().navigate_to_path(target)


func _handles(object: Object) -> bool:
	return object is FGUIPackageResource


func _edit(object: Object) -> void:
	if object is FGUIPackageResource:
		_open_preview(object as FGUIPackageResource)


func _make_visible(visible: bool) -> void:
	if visible and _preview_panel != null:
		make_bottom_panel_item_visible(_preview_panel)


func _open_preview(
		resource: FGUIPackageResource,
		component_name: String = "",
		context_view: FGUIView = null
	) -> void:
	if resource == null or _preview_panel == null:
		return
	_preview_panel.call("open_package", resource, component_name, context_view)
	make_bottom_panel_item_visible(_preview_panel)


func _configure_preview_bottom_button() -> void:
	if _preview_bottom_button == null:
		return
	var editor_theme := EditorInterface.get_editor_theme()
	if editor_theme.has_icon("Control", "EditorIcons"):
		_preview_bottom_button.icon = editor_theme.get_icon("Control", "EditorIcons")


func _install_canvas_drop_overlay() -> void:
	if not is_inside_tree() or _canvas_drop_overlay != null:
		return
	var canvas_viewport := _find_editor_control_by_class(get_editor_interface().get_base_control(), "CanvasItemEditorViewport")
	if canvas_viewport == null:
		_canvas_overlay_install_attempts += 1
		if _canvas_overlay_install_attempts < 120:
			call_deferred("_install_canvas_drop_overlay")
		return
	_canvas_drop_overlay = FUICanvasDropOverlay.new()
	_canvas_drop_overlay.connect("component_dropped", Callable(self, "_on_canvas_component_dropped"))
	canvas_viewport.add_child(_canvas_drop_overlay)


func _find_editor_control_by_class(node: Node, target_class: String) -> Control:
	if node is Control and node.get_class() == target_class:
		return node as Control
	for child: Node in node.get_children():
		var found := _find_editor_control_by_class(child, target_class)
		if found != null:
			return found
	return null


func _on_canvas_component_dropped(package_path: String, component_name: String, canvas_position: Vector2) -> void:
	var resource := ResourceLoader.load(package_path) as FGUIPackageResource
	if resource == null:
		push_error("[FairyGUI editor] 无法加载拖入的 .fui：%s" % package_path)
		return
	var component := resource.get_component_info(component_name)
	if component.is_empty():
		push_error("[FairyGUI editor] .fui 中没有可创建的组件：%s" % package_path)
		return
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		push_error("[FairyGUI editor] 请先创建或打开一个 2D 场景。")
		return
	var parent := _drop_parent(scene_root)
	var view := FGUIView.new()
	view.name = str(component.component_name)
	view.package = resource
	view.component_name = str(component.component_name)
	view.preview_in_editor = true
	view.resize_to_content = true
	if parent is CanvasItem:
		view.position = (parent as CanvasItem).get_global_transform().affine_inverse() * canvas_position

	var undo_redo := get_undo_redo()
	var selection := get_editor_interface().get_selection()
	undo_redo.create_action("创建 FairyGUI 视图", UndoRedo.MERGE_DISABLE, scene_root)
	undo_redo.add_do_method(view, "request_ready")
	undo_redo.add_do_method(parent, "add_child", view, true)
	undo_redo.add_do_method(view, "set_owner", scene_root)
	undo_redo.add_do_method(selection, "clear")
	undo_redo.add_do_method(selection, "add_node", view)
	undo_redo.add_undo_method(selection, "clear")
	undo_redo.add_undo_method(parent, "remove_child", view)
	undo_redo.add_do_reference(view)
	undo_redo.commit_action()
	_prepare_business_script.call_deferred(weakref(view), 0, false)


func _drop_parent(scene_root: Node) -> Node:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	if selected.is_empty():
		return scene_root
	var selected_node := selected[0] as Node
	if Input.is_key_pressed(KEY_ALT):
		return scene_root
	if Input.is_key_pressed(KEY_SHIFT):
		return selected_node
	return selected_node.get_parent() if selected_node != scene_root and selected_node.get_parent() != null else scene_root


func _binding_path_for_view(view: FGUIView) -> String:
	if view == null or view.package == null:
		return ""
	var component_name := view.component_name
	if component_name == "":
		var names := view.package.get_component_names()
		component_name = "Main" if names.has("Main") else (names[0] if not names.is_empty() else "")
	var component := view.package.get_component_info(component_name)
	var url := str(component.get("url", ""))
	if url == "":
		return ""
	var output_dir := str(ProjectSettings.get_setting(SETTING_OUTPUT_DIR, BindingCodeGenerator.DEFAULT_OUTPUT_DIR)).trim_suffix("/")
	var manifest_path := "%s/%s" % [output_dir, BindingCodeGenerator.MANIFEST_FILE]
	if not FileAccess.file_exists(manifest_path):
		return ""
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not manifest is Dictionary:
		return ""
	return str(manifest.get("bindings", {}).get(url, ""))


func _collect_codegen_resources() -> PackedStringArray:
	var result := PackedStringArray()
	var filesystem := get_editor_interface().get_resource_filesystem()
	var root := filesystem.get_filesystem()
	if root != null:
		_collect_codegen_resources_from_directory(root, result)
	result.sort()
	return result


func _collect_codegen_resources_from_directory(directory: EditorFileSystemDirectory, result: PackedStringArray) -> void:
	for index in directory.get_file_count():
		var path := directory.get_file_path(index)
		if path.get_extension().to_lower() != "fui":
			continue
		var resource: Resource = ResourceLoader.load(path)
		if resource is FGUIPackageResource and (resource as FGUIPackageResource).codegen_enabled:
			result.append(path)
	for index in directory.get_subdir_count():
		_collect_codegen_resources_from_directory(directory.get_subdir(index), result)


func _reload_generated_bindings() -> void:
	if not is_inside_tree():
		return
	if get_editor_interface().get_resource_filesystem().is_scanning():
		call_deferred("_reload_generated_bindings")
		return
	FGUIObjectFactory.reload_generated_extensions()
	var root := get_editor_interface().get_edited_scene_root()
	if root != null:
		_refresh_fui_views(root)


func _refresh_fui_views(node: Node) -> void:
	if node is FGUIView:
		(node as FGUIView).refresh_preview()
	for child: Node in node.get_children():
		_refresh_fui_views(child)


func _finish_generation_cycle() -> void:
	if not _generation_requested_while_running:
		return
	var force := _generation_force_requested_while_running
	_generation_requested_while_running = false
	_generation_force_requested_while_running = false
	_queue_generation(force)


func _skipped_generation_result(freshness: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"skipped": true,
		"reason": freshness.get("reason", "current"),
		"generated_files": PackedStringArray(),
		"removed_files": PackedStringArray(),
		"unchanged_files": PackedStringArray(),
		"warnings": PackedStringArray(),
		"errors": PackedStringArray(),
		"bindings": {},
	}


func _generation_changes_scripts(result: Dictionary) -> bool:
	for key: String in ["generated_files", "removed_files"]:
		for value: Variant in result.get(key, PackedStringArray()):
			if str(value).get_extension().to_lower() == "gd":
				return true
	return false


func _report_generation(result: Dictionary, package_count: int) -> void:
	for warning: String in result.get("warnings", PackedStringArray()):
		push_warning("[FairyGUI codegen] %s" % warning)
	for error: String in result.get("errors", PackedStringArray()):
		push_error("[FairyGUI codegen] %s" % error)
	if bool(result.get("ok", false)):
		print("[FairyGUI codegen] %d package(s), %d generated, %d unchanged, %d removed, %d warning(s)." % [
			package_count,
			result.get("generated_files", PackedStringArray()).size(),
			result.get("unchanged_files", PackedStringArray()).size(),
			result.get("removed_files", PackedStringArray()).size(),
			result.get("warnings", PackedStringArray()).size(),
		])


func _register_project_settings() -> void:
	_register_setting(SETTING_AUTO_GENERATE, true, TYPE_BOOL)
	_register_setting(SETTING_OUTPUT_DIR, BindingCodeGenerator.DEFAULT_OUTPUT_DIR, TYPE_STRING, PROPERTY_HINT_DIR)
	_register_setting(
		SETTING_REGISTRY_PATH,
		"%s/%s" % [BindingCodeGenerator.DEFAULT_OUTPUT_DIR, BindingCodeGenerator.REGISTRY_FILE],
		TYPE_STRING,
		PROPERTY_HINT_FILE,
		"*.gd"
	)
	_register_setting(SETTING_CLASS_PREFIX, "UI_", TYPE_STRING)
	_register_setting(SETTING_INCLUDE_DEFAULT_NAMES, false, TYPE_BOOL)
	_register_setting(SETTING_INCLUDE_INTERNAL_COMPONENTS, false, TYPE_BOOL)


func _register_setting(
		name: String,
		default_value: Variant,
		type: int,
		hint: int = PROPERTY_HINT_NONE,
		hint_string: String = ""
	) -> void:
	if not ProjectSettings.has_setting(name):
		ProjectSettings.set_setting(name, default_value)
	ProjectSettings.set_initial_value(name, default_value)
	ProjectSettings.add_property_info({
		"name": name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	})
