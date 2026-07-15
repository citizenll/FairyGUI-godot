extends SceneTree

const PreviewPanel := preload("res://addons/fairygui/editor/fui_preview_panel.gd")
const PACKAGE_PATH := "res://examples/assets/ui/Basics.fui"


func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("GUI preview panel probe must run through the Godot editor.")
		return
	_run.call_deferred()


func _run() -> void:
	var resource_filesystem := EditorInterface.get_resource_filesystem()
	while resource_filesystem != null and (resource_filesystem.is_scanning() or resource_filesystem.is_importing()):
		await process_frame
	var resource := ResourceLoader.load(PACKAGE_PATH) as FGUIPackageResource
	if resource == null:
		_fail("Could not load Basics.fui for GUI preview coverage.")
		return

	var panel: Variant = _find_node_by_name(root, "FairyGUIPreview")
	if panel == null or panel.get_script() != PreviewPanel:
		_fail("FairyGUI editor plugin did not register the GUI preview bottom panel.")
		return
	EditorInterface.edit_resource(resource)
	for _frame in 20:
		if panel.get_preview_object() != null:
			break
		await process_frame
	var preview := panel.get_preview_object() as FGUIObject
	if preview == null or panel.get_current_component() != "Main":
		_fail("GUI preview panel did not construct Basics/Main.")
		return
	if not panel.get_component_names().has("Main") or panel.get_component_names().size() < 10:
		_fail("GUI preview panel did not expose the package component list.")
		return
	var expected_count := _count_objects(preview)
	if panel.get_hierarchy_node_count() != expected_count or expected_count < 20:
		_fail("GUI preview hierarchy was incomplete: %d of %d nodes." % [
			panel.get_hierarchy_node_count(),
			expected_count,
		])
		return
	if absf(panel._component_picker.global_position.x - panel._preview_scroll.global_position.x) > 8.0:
		_fail("Component picker was not aligned with the preview canvas.")
		return

	var first_child := (preview as FGUIComponent).get_child_at(0) if preview is FGUIComponent else null
	if first_child == null:
		_fail("Basics/Main did not expose a selectable child.")
		return
	var first_item := _find_item(panel.get_hierarchy_tree().get_root(), first_child.get_instance_id())
	if first_item == null:
		_fail("GUI preview hierarchy did not map a FairyGUI child to a TreeItem.")
		return
	first_item.select(0)
	panel._on_tree_item_selected()
	if panel.get_selected_object() != first_child:
		_fail("Tree selection did not update the preview selection.")
		return

	var global_center := preview.local_to_global(Vector2(preview.width, preview.height) * 0.5)
	var picked: FGUIObject = panel.pick_object_at(global_center)
	if picked == null or panel.get_selected_object() != picked:
		_fail("Preview picking did not update the hierarchy selection.")
		return
	var selected_item: TreeItem = panel.get_hierarchy_tree().get_selected()
	if selected_item == null or int(selected_item.get_metadata(0)) != picked.get_instance_id():
		_fail("Preview picking did not reveal the selected TreeItem.")
		return

	var preview_scroll: ScrollContainer = panel._preview_scroll
	panel._set_zoom(1.0)
	await process_frame
	await process_frame
	preview_scroll.scroll_horizontal = 120
	preview_scroll.scroll_vertical = 80
	var zoom_focus := preview_scroll.size * 0.5
	var point_before: Vector2 = (
		Vector2(preview_scroll.scroll_horizontal, preview_scroll.scroll_vertical)
		+ zoom_focus
		- panel._preview_origin
	) / float(panel._zoom)
	var wheel_event := InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_event.pressed = true
	wheel_event.factor = 1.0
	wheel_event.position = zoom_focus
	panel._on_preview_gui_input(wheel_event)
	await process_frame
	await process_frame
	if float(panel._zoom) <= 1.0:
		_fail("Mouse wheel did not zoom the GUI preview.")
		return
	var point_after: Vector2 = (
		Vector2(preview_scroll.scroll_horizontal, preview_scroll.scroll_vertical)
		+ zoom_focus
		- panel._preview_origin
	) / float(panel._zoom)
	if point_before.distance_to(point_after) > 2.0:
		_fail("Mouse wheel zoom did not preserve the FairyGUI point under the cursor.")
		return

	panel._set_zoom(2.0)
	await process_frame
	await process_frame
	preview_scroll.scroll_horizontal = 180
	preview_scroll.scroll_vertical = 140
	var pan_start := Vector2(preview_scroll.scroll_horizontal, preview_scroll.scroll_vertical)
	var middle_press := InputEventMouseButton.new()
	middle_press.button_index = MOUSE_BUTTON_MIDDLE
	middle_press.pressed = true
	middle_press.position = Vector2(160.0, 120.0)
	panel._on_preview_gui_input(middle_press)
	var middle_motion := InputEventMouseMotion.new()
	middle_motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	middle_motion.position = Vector2(120.0, 90.0)
	panel._on_preview_gui_input(middle_motion)
	var pan_end := Vector2(preview_scroll.scroll_horizontal, preview_scroll.scroll_vertical)
	if pan_end.distance_to(pan_start + Vector2(40.0, 30.0)) > 2.0:
		_fail("Middle mouse dragging did not pan the GUI preview.")
		return
	var middle_release := InputEventMouseButton.new()
	middle_release.button_index = MOUSE_BUTTON_MIDDLE
	middle_release.pressed = false
	middle_release.position = middle_motion.position
	panel._on_preview_gui_input(middle_release)
	if bool(panel._panning):
		_fail("Middle mouse release did not stop GUI preview panning.")
		return

	panel.clear_preview()
	await process_frame
	await process_frame
	quit(0)


func _count_objects(value: FGUIObject) -> int:
	var count := 1
	if value is FGUIComponent:
		for child: FGUIObject in (value as FGUIComponent).children:
			count += _count_objects(child)
	return count


func _find_item(item: TreeItem, object_id: int) -> TreeItem:
	if item == null:
		return null
	var metadata: Variant = item.get_metadata(0)
	if metadata != null and int(metadata) == object_id:
		return item
	var child := item.get_first_child()
	while child != null:
		var found := _find_item(child, object_id)
		if found != null:
			return found
		child = child.get_next()
	return null


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child: Node in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
