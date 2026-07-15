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
	if _find_node_by_name(root, "FairyGUICanvasDropOverlay") == null:
		_fail("FairyGUI editor plugin did not install the 2D canvas drop target.")
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
	var selection_overlay: Control = panel._selection_overlay
	if selection_overlay.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("GUI preview selection overlay did not own canvas navigation input.")
		return
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
	wheel_event.position = selection_overlay.get_global_transform().affine_inverse() \
			* (preview_scroll.get_global_transform() * zoom_focus)
	selection_overlay.emit_signal("gui_input", wheel_event)
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
	var pan_press_in_scroll := Vector2(160.0, 120.0)
	middle_press.position = selection_overlay.get_global_transform().affine_inverse() \
			* (preview_scroll.get_global_transform() * pan_press_in_scroll)
	selection_overlay.emit_signal("gui_input", middle_press)
	var middle_motion := InputEventMouseMotion.new()
	middle_motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	var pan_motion_in_scroll := Vector2(120.0, 90.0)
	middle_motion.position = selection_overlay.get_global_transform().affine_inverse() \
			* (preview_scroll.get_global_transform() * pan_motion_in_scroll)
	selection_overlay.emit_signal("gui_input", middle_motion)
	var pan_end := Vector2(preview_scroll.scroll_horizontal, preview_scroll.scroll_vertical)
	if pan_end.distance_to(pan_start + Vector2(40.0, 30.0)) > 2.0:
		_fail("Middle mouse dragging did not pan the GUI preview.")
		return
	var middle_release := InputEventMouseButton.new()
	middle_release.button_index = MOUSE_BUTTON_MIDDLE
	middle_release.pressed = false
	middle_release.position = middle_motion.position
	selection_overlay.emit_signal("gui_input", middle_release)
	if bool(panel._panning):
		_fail("Middle mouse release did not stop GUI preview panning.")
		return

	preview_scroll.scroll_horizontal = 180
	preview_scroll.scroll_vertical = 140
	var routed_pan_start := Vector2(preview_scroll.scroll_horizontal, preview_scroll.scroll_vertical)
	var visible_overlay_rect := selection_overlay.get_global_rect().intersection(preview_scroll.get_global_rect())
	if not visible_overlay_rect.has_area():
		_fail("GUI preview selection overlay was not visible inside its canvas.")
		return
	var routed_press_position := visible_overlay_rect.get_center()
	var routed_press := InputEventMouseButton.new()
	routed_press.button_index = MOUSE_BUTTON_MIDDLE
	routed_press.pressed = true
	routed_press.position = routed_press_position
	routed_press.global_position = routed_press_position
	selection_overlay.get_viewport().push_input(routed_press, true)
	await process_frame
	var routed_motion := InputEventMouseMotion.new()
	routed_motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	routed_motion.position = routed_press_position - Vector2(40.0, 30.0)
	routed_motion.global_position = routed_motion.position
	routed_motion.relative = Vector2(-40.0, -30.0)
	selection_overlay.get_viewport().push_input(routed_motion, true)
	await process_frame
	var routed_pan_end := Vector2(preview_scroll.scroll_horizontal, preview_scroll.scroll_vertical)
	if routed_pan_end.distance_to(routed_pan_start + Vector2(40.0, 30.0)) > 2.0:
		_fail("Viewport-routed middle mouse input did not pan the GUI preview.")
		return
	var routed_release := InputEventMouseButton.new()
	routed_release.button_index = MOUSE_BUTTON_MIDDLE
	routed_release.pressed = false
	routed_release.position = routed_motion.position
	routed_release.global_position = routed_motion.position
	selection_overlay.get_viewport().push_input(routed_release, true)
	await process_frame
	if bool(panel._panning):
		_fail("Viewport-routed middle mouse release did not stop GUI preview panning.")
		return

	var state_target := _find_object_by_name(preview, "btn_Graph")
	if state_target == null:
		_fail("Basics/Main did not expose btn_Graph for preview state coverage.")
		return
	panel.select_object(state_target, true)
	panel._filter_edit.text = "btn_graph"
	panel._on_filter_changed(panel._filter_edit.text)
	panel._set_zoom(2.0)
	await process_frame
	await process_frame
	preview_scroll.scroll_horizontal = 150
	preview_scroll.scroll_vertical = 110
	var state_scroll := Vector2(preview_scroll.scroll_horizontal, preview_scroll.scroll_vertical)
	var root_item := panel.get_hierarchy_tree().get_root() as TreeItem
	var collapsed_item := _find_collapsible_sibling(root_item, panel.get_hierarchy_tree().get_selected())
	var collapsed_path: Array[int] = []
	if collapsed_item != null:
		var collapsed_object := panel._object_by_id.get(int(collapsed_item.get_metadata(0))) as FGUIObject
		collapsed_path = panel._object_index_path(collapsed_object)
		collapsed_item.collapsed = true
	var old_preview_id := preview.get_instance_id()
	panel.reload_current()
	for _frame in 80:
		var current := panel.get_preview_object() as FGUIObject
		if current != null and current.get_instance_id() != old_preview_id and panel.get_selected_object() != null:
			break
		await process_frame
	await process_frame
	await process_frame
	if panel.get_preview_object() == null or panel.get_preview_object().get_instance_id() == old_preview_id:
		_fail("GUI preview reload did not rebuild the component.")
		return
	if panel.get_selected_object().name != "btn_Graph" or panel._filter_edit.text != "btn_graph":
		_fail("GUI preview reload did not restore selection and filter state.")
		return
	if not is_equal_approx(float(panel._zoom), 2.0):
		_fail("GUI preview reload did not restore zoom state.")
		return
	var restored_scroll := Vector2(preview_scroll.scroll_horizontal, preview_scroll.scroll_vertical)
	if restored_scroll.distance_to(state_scroll) > 3.0:
		_fail("GUI preview reload did not restore scroll state: %s vs %s." % [restored_scroll, state_scroll])
		return
	if not collapsed_path.is_empty():
		var restored_collapsed_object := panel._resolve_object_index_path(collapsed_path) as FGUIObject
		var restored_collapsed_item := _find_item(panel.get_hierarchy_tree().get_root(), restored_collapsed_object.get_instance_id())
		if restored_collapsed_item == null or not restored_collapsed_item.collapsed:
			_fail("GUI preview reload did not restore tree collapse state.")
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


func _find_object_by_name(value: FGUIObject, target_name: String) -> FGUIObject:
	if value.name == target_name:
		return value
	if value is FGUIComponent:
		for child: FGUIObject in (value as FGUIComponent).children:
			var found := _find_object_by_name(child, target_name)
			if found != null:
				return found
	return null


func _find_collapsible_sibling(root_item: TreeItem, selected_item: TreeItem) -> TreeItem:
	if root_item == null:
		return null
	var selected_branch := selected_item
	while selected_branch != null and selected_branch.get_parent() != root_item:
		selected_branch = selected_branch.get_parent()
	var child := root_item.get_first_child()
	while child != null:
		if child != selected_branch and child.get_first_child() != null:
			return child
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
