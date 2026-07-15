extends SceneTree

const SCENE_PATH := "res://examples/editor_preview/test.tscn"
const PACKAGE_PATH := "res://examples/assets/ui/Basics.fui"
const PluginScript := preload("res://addons/fairygui/plugin.gd")
const PreviewPanel := preload("res://addons/fairygui/editor/fui_preview_panel.gd")
const BusinessScriptGenerator := preload("res://addons/fairygui/editor/business_script_generator.gd")
const EventBindingService := preload("res://addons/fairygui/editor/event_binding_service.gd")

var _scene_root: Node
var _view: FGUIView
var _script_path: String
var _binding_action_created: bool = false


func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("Event binding editor probe must run through the Godot editor.")
		return
	_run.call_deferred()


func _run() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	while filesystem != null and (filesystem.is_scanning() or filesystem.is_importing()):
		await process_frame
	EditorInterface.open_scene_from_path(SCENE_PATH)
	for _frame in 20:
		await process_frame
	_scene_root = EditorInterface.get_edited_scene_root()
	var plugin := _find_node_by_script(root, PluginScript)
	var preview_panel := _find_node_by_script(root, PreviewPanel)
	var resource := ResourceLoader.load(PACKAGE_PATH) as FGUIPackageResource
	if _scene_root == null or plugin == null or preview_panel == null or resource == null:
		_fail("FairyGUI phase two editor services were not available.")
		return

	_view = FGUIView.new()
	_view.name = "PhaseTwoEventProbe"
	_view.package = resource
	_view.component_name = "Main"
	var service := EventBindingService.new()
	var detached_model := service.build_model(_view)
	if _find_target(detached_model.get("targets", []), PackedStringArray(["btn_Button"])).is_empty():
		_fail("Event binding targets were unavailable before the editor preview entered the scene tree.")
		return
	_scene_root.add_child(_view)
	_view.owner = _scene_root
	for _frame in 4:
		await process_frame
	var generator := BusinessScriptGenerator.new()
	var created := generator.create_for_view(_view, "res://tests/_phase_two_scene.tscn")
	if not bool(created.get("ok", false)):
		_fail("Could not create the phase two business script: %s" % created.get("error", ""))
		return
	_script_path = str(created.script_path)
	filesystem.scan_sources()
	while filesystem.is_scanning() or filesystem.is_importing():
		await process_frame
	var business_script := ResourceLoader.load(_script_path, "", ResourceLoader.CACHE_MODE_REPLACE) as Script
	if business_script == null:
		_fail("Could not load the phase two business script.")
		return
	_view.call("_clear_preview")
	_view.set_script(business_script)
	_view.package = resource
	_view.component_name = "Main"
	_view.preview_in_editor = true
	_view.refresh_preview()
	for _frame in 4:
		await process_frame
	EditorInterface.edit_script(business_script, -1, 0, true)
	for _frame in 4:
		await process_frame
	var open_code_edit := _find_open_code_edit(business_script)
	if open_code_edit == null:
		_fail("Could not open the generated business script in ScriptEditor.")
		return
	var unsaved_marker := "var unsaved_editor_probe: int = 7"
	var unsaved_source := open_code_edit.get_text().rstrip("\r\n") + "\n\n%s\n" % unsaved_marker
	open_code_edit.set_text(unsaved_source)
	if not EditorInterface.get_script_editor().get_unsaved_files().has(_script_path):
		_fail("The test could not create an unsaved ScriptEditor buffer.")
		return
	if business_script.source_code.contains(unsaved_marker):
		_fail("Tool script validation unexpectedly synchronized the unsaved editor buffer.")
		return

	var model := service.build_model(_view)
	var button_target := _find_target(model.get("targets", []), PackedStringArray(["btn_Button"]))
	if button_target.is_empty():
		_fail("Real Basics.fui button target was not exposed for event binding.")
		return
	var handler := service.suggest_handler(button_target, FGUIEvents.CLICK)
	if handler != &"_on_btn_button_clicked":
		_fail("Event handler suggestion was not deterministic: %s" % handler)
		return
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(_view)
	for _frame in 8:
		await process_frame
	var event_inspector := _find_node_by_name(root, "FairyGUIEventBindingInspector")
	if event_inspector == null:
		_fail("FGUIView Inspector did not create the event binding controls.")
		return
	var initial_target_picker := event_inspector.get("_target_picker") as OptionButton
	if not _select_target(
			event_inspector,
			initial_target_picker,
			service.target_path_key(PackedStringArray(["btn_Button"]))
		):
		_fail("Inspector did not expose the real Basics.fui button target.")
		return
	var initial_event_picker := event_inspector.get("_event_picker") as OptionButton
	if not _select_event(event_inspector, initial_event_picker, FGUIEvents.CLICK):
		_fail("Inspector did not expose the button click event.")
		return
	var initial_add_button := event_inspector.get("_add_button") as Button
	if initial_add_button == null or initial_add_button.disabled:
		_fail("Inspector did not enable the connect-and-generate action.")
		return
	initial_add_button.emit_signal("pressed")
	if initial_add_button.text != "处理中..." or not initial_add_button.disabled:
		_fail("Inspector click did not enter a visible pending state.")
		return
	plugin.call(
		"_on_event_binding_add",
		_view,
		PackedStringArray(["btn_Button"]),
		FGUIEvents.CLICK,
		handler,
		false
	)
	var pending_model: Dictionary = plugin.call("_get_event_binding_model", _view)
	if not bool(pending_model.get("pending", false)):
		_fail("Event connection did not expose its pending state to the Inspector.")
		return
	for _frame in 8:
		await process_frame
	if _view.event_bindings.size() != 1:
		_fail("Inspector event action did not serialize the binding on FGUIView.")
		return
	_binding_action_created = true
	if not (plugin.get("_pending_event_bindings") as Dictionary).is_empty():
		_fail("Event connection operation did not clear its pending state.")
		return
	if _view.package == null or _view.package.get_source_path() != PACKAGE_PATH or _view.component_name != "Main":
		_fail("Generating an event handler cleared the FGUIView package configuration.")
		return
	var source := FileAccess.get_file_as_string(_script_path)
	if source.count("func _on_btn_button_clicked(") != 1 \
			or not source.contains(unsaved_marker) \
			or not business_script.source_code.contains(unsaved_marker) \
			or not _view.has_method(handler):
		_fail("Event action did not generate one valid handler function.")
		return
	open_code_edit = _find_open_code_edit(business_script)
	if open_code_edit == null \
			or not open_code_edit.get_text().contains(unsaved_marker) \
			or open_code_edit.get_text().count("func _on_btn_button_clicked(") != 1:
		_fail("Event generation did not synchronize the open ScriptEditor buffer.")
		return
	if EditorInterface.get_script_editor().get_unsaved_files().has(_script_path):
		_fail("The committed ScriptEditor buffer was still marked as unsaved.")
		return
	EditorInterface.get_script_editor().save_all_scripts()
	source = FileAccess.get_file_as_string(_script_path)
	if not source.contains(unsaved_marker) or source.count("func _on_btn_button_clicked(") != 1:
		_fail("Saving scripts after generation overwrote the generated handler.")
		return
	if FileAccess.file_exists(_script_path + ".fairygui_tmp") \
			or FileAccess.file_exists(_script_path + ".fairygui_backup"):
		_fail("Event handler generation left transactional files behind.")
		return
	if not _remove_handler_from_business_script(business_script, "_on_btn_button_clicked"):
		_fail("Could not prepare missing duplicate handler coverage.")
		return
	plugin.call(
		"_on_event_binding_add",
		_view,
		PackedStringArray(["btn_Button"]),
		FGUIEvents.CLICK,
		handler,
		false
	)
	for _frame in 8:
		await process_frame
	source = FileAccess.get_file_as_string(_script_path)
	if _view.event_bindings.size() != 1 \
			or source.count("func _on_btn_button_clicked(") != 1 \
			or not _view.has_method(handler):
		_fail("Reconnecting an existing event did not restore its missing handler.")
		return
	model = service.build_model(_view)
	var rows: Array = model.get("bindings", [])
	if rows.size() != 1 or str((rows[0] as Dictionary).get("severity", "")) != "success":
		_fail("Valid event binding did not pass editor diagnostics: %s" % [rows])
		return

	var history := _scene_history()
	history.undo()
	await process_frame
	if not _view.event_bindings.is_empty():
		_fail("Event binding did not integrate with scene Undo.")
		return
	history.redo()
	await process_frame
	if _view.event_bindings.size() != 1:
		_fail("Event binding did not integrate with scene Redo.")
		return
	plugin.call("_on_event_binding_open", _view, 0)
	for _frame in 4:
		await process_frame
	source = FileAccess.get_file_as_string(_script_path)
	if source.count("func _on_btn_button_clicked(") != 1:
		_fail("Opening an existing event handler generated a duplicate function.")
		return
	plugin.call("_on_event_binding_toggle", _view, 0)
	await process_frame
	if _view.event_bindings[0].enabled:
		_fail("Inspector did not disable the selected event binding.")
		return
	_scene_history().undo()
	await process_frame
	if not _view.event_bindings[0].enabled:
		_fail("Event binding enable state did not integrate with Undo.")
		return

	preview_panel.call("open_package", resource, "Main", _view)
	for _frame in 8:
		await process_frame
	var preview_root := preview_panel.call("get_preview_object") as FGUIComponent
	var preview_button := preview_root.get_child("btn_Button") if preview_root != null else null
	if preview_button == null:
		_fail("GUI preview could not locate the event target.")
		return
	preview_panel.call("select_object", preview_button, true)
	await process_frame
	var bind_button := preview_panel.get("_bind_event_button") as Button
	if bind_button == null or bind_button.disabled:
		_fail("GUI preview did not enable preview-to-event binding for its FGUIView context.")
		return
	preview_panel.call("_on_bind_event_pressed")
	for _frame in 8:
		await process_frame
	var preferred: Variant = _view.get_meta(EventBindingService.META_PREFERRED_TARGET, PackedStringArray())
	if not preferred is PackedStringArray or preferred != PackedStringArray(["btn_Button"]):
		_fail("GUI preview did not transfer the selected target to the Inspector.")
		return
	event_inspector = _find_node_by_name(root, "FairyGUIEventBindingInspector")
	if event_inspector == null:
		_fail("FGUIView Inspector did not create the phase two event binding panel.")
		return
	var target_picker := event_inspector.get("_target_picker") as OptionButton
	var selected_target: Variant = target_picker.get_item_metadata(target_picker.selected) if target_picker != null else null
	if not selected_target is Dictionary or str(selected_target.get("key", "")) != service.target_path_key(PackedStringArray(["btn_Button"])):
		_fail("Inspector event panel did not select the target chosen in GUI preview.")
		return
	var event_picker := event_inspector.get("_event_picker") as OptionButton
	if not _select_event(event_inspector, event_picker, FGUIEvents.CLICK):
		_fail("Inspector did not expose the click event for the selected button.")
		return
	var add_button := event_inspector.get("_add_button") as Button
	if add_button == null or add_button.disabled or add_button.text != "打开已有处理函数":
		_fail("Existing event connection did not expose a deterministic open/repair action: %s" % [{
			"button": add_button.text if add_button != null else "<missing>",
			"disabled": add_button.disabled if add_button != null else true,
			"method": (event_inspector.get("_method_edit") as LineEdit).text,
			"pending": (event_inspector.get("_model") as Dictionary).get("pending", false),
		}])
		return

	_cleanup()
	quit(0)


func _find_target(targets: Array, path: PackedStringArray) -> Dictionary:
	var key := EventBindingService.new().target_path_key(path)
	for target: Dictionary in targets:
		if str(target.get("key", "")) == key:
			return target
	return {}


func _select_target(inspector: Node, picker: OptionButton, target_key: String) -> bool:
	if picker == null:
		return false
	for index in picker.item_count:
		var target: Variant = picker.get_item_metadata(index)
		if target is Dictionary and str(target.get("key", "")) == target_key:
			picker.select(index)
			inspector.call("_on_target_selected", index)
			return true
	return false


func _select_event(inspector: Node, picker: OptionButton, event_name: String) -> bool:
	if picker == null:
		return false
	for index in picker.item_count:
		var event: Variant = picker.get_item_metadata(index)
		if event is Dictionary and str(event.get("value", "")) == event_name:
			picker.select(index)
			inspector.call("_on_event_selected", index)
			return true
	return false


func _remove_handler_from_business_script(script: GDScript, handler: String) -> bool:
	var code_edit := _find_open_code_edit(script)
	var source := code_edit.get_text() if code_edit != null else script.source_code
	var marker := "\nfunc %s(" % handler
	var position := source.find(marker)
	if position < 0:
		return false
	var next_source := source.left(position).rstrip("\r\n") + "\n"
	var file := FileAccess.open(_script_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(next_source)
	file.close()
	if code_edit != null:
		code_edit.set_text(next_source)
		code_edit.tag_saved_version()
	script.source_code = next_source
	return script.reload(true) == OK and not _view.has_method(StringName(handler))


func _find_open_code_edit(script: Script) -> CodeEdit:
	var script_editor := EditorInterface.get_script_editor()
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
		return editor.get_base_editor() as CodeEdit if editor != null else null
	return null


func _scene_history() -> UndoRedo:
	var manager := EditorInterface.get_editor_undo_redo()
	return manager.get_history_undo_redo(manager.get_object_history_id(_scene_root))


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _find_node_by_script(node: Node, script: Script) -> Node:
	if node.get_script() == script:
		return node
	for child: Node in node.get_children():
		var found := _find_node_by_script(child, script)
		if found != null:
			return found
	return null


func _cleanup() -> void:
	if _binding_action_created and _scene_root != null:
		var history := _scene_history()
		if history.has_undo():
			history.undo()
		_binding_action_created = false
	if _view != null:
		_view.queue_free()
		_view = null
	if _script_path != "":
		EditorInterface.get_script_editor().close_file(_script_path)
		_remove_file(_script_path)
		_remove_file(_script_path + ".uid")
		_remove_file(_script_path + ".fairygui_tmp")
		_remove_file(_script_path + ".fairygui_backup")


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	push_error(message)
	_cleanup()
	quit(1)
