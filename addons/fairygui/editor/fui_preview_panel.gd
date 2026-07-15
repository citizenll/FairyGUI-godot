@tool
extends VBoxContainer

const SelectionOverlay := preload("res://addons/fairygui/editor/fui_preview_selection.gd")

const MIN_ZOOM := 0.10
const MAX_ZOOM := 4.0
const ZOOM_FACTOR := 1.2
const PREVIEW_PADDING := 24.0

var _initialized: bool = false
var _package_resource: FGUIPackageResource
var _component_names := PackedStringArray()
var _current_component: String = ""
var _root_object: FGUIObject
var _selected_object: FGUIObject
var _object_by_id: Dictionary = {}
var _tree_item_by_id: Dictionary = {}
var _node_count: int = 0
var _zoom: float = 1.0
var _content_size := Vector2.ZERO
var _preview_origin := Vector2.ZERO
var _syncing_selection: bool = false
var _panning: bool = false
var _pan_start_mouse := Vector2.ZERO
var _pan_start_scroll := Vector2.ZERO

var _path_label: Label
var _component_picker: OptionButton
var _reload_button: Button
var _filter_edit: LineEdit
var _tree: Tree
var _preview_scroll: ScrollContainer
var _preview_canvas: Control
var _preview_view: FGUIView
var _selection_overlay
var _zoom_out_button: Button
var _zoom_in_button: Button
var _fit_button: Button
var _zoom_label: Label
var _status_label: Label


func _ready() -> void:
	_ensure_ui()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _initialized:
		_apply_editor_theme()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_stop_panning()


func open_package(resource: FGUIPackageResource, preferred_component: String = "") -> void:
	_ensure_ui()
	if resource == null:
		clear_preview()
		return
	_package_resource = resource
	_component_names = resource.get_component_names()
	_path_label.text = resource.get_source_path()
	_path_label.tooltip_text = resource.get_source_path()
	_component_picker.clear()
	for component_name: String in _component_names:
		_component_picker.add_item(component_name)
	_component_picker.disabled = _component_names.is_empty()
	if _component_names.is_empty():
		_current_component = ""
		_clear_hierarchy()
		_preview_view.package = null
		_status_label.text = "未找到可预览的组件"
		return
	var selected_name := preferred_component
	if not _component_names.has(selected_name):
		selected_name = "Main" if _component_names.has("Main") else _component_names[0]
	_current_component = selected_name
	_component_picker.select(_component_names.find(selected_name))
	_show_component(selected_name)


func reload_current() -> void:
	if _package_resource == null:
		return
	var source_path := _package_resource.resource_path
	if source_path == "":
		source_path = _package_resource.get_source_path()
	var preferred_component := _current_component
	_preview_view.package = null
	var reloaded := ResourceLoader.load(source_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if reloaded is FGUIPackageResource:
		open_package(reloaded as FGUIPackageResource, preferred_component)


func clear_preview() -> void:
	_ensure_ui()
	_package_resource = null
	_component_names.clear()
	_current_component = ""
	_path_label.text = ""
	_path_label.tooltip_text = ""
	_component_picker.clear()
	_component_picker.disabled = true
	_preview_view.package = null
	_preview_view.component_name = ""
	_clear_hierarchy()
	_status_label.text = "双击 .fui 文件以打开 GUI 预览"


func get_current_resource_path() -> String:
	if _package_resource == null:
		return ""
	return _package_resource.resource_path if _package_resource.resource_path != "" else _package_resource.get_source_path()


func get_current_component() -> String:
	return _current_component


func get_component_names() -> PackedStringArray:
	return _component_names.duplicate()


func get_preview_object() -> FGUIObject:
	return _root_object


func get_selected_object() -> FGUIObject:
	return _selected_object


func get_hierarchy_node_count() -> int:
	return _node_count


func get_hierarchy_tree() -> Tree:
	return _tree


func select_object(value: FGUIObject, reveal_in_tree: bool = true) -> void:
	_select_object(value, reveal_in_tree, true)


func pick_object_at(global_position: Vector2) -> FGUIObject:
	var picked := _selection_overlay.pick_object_at(global_position) as FGUIObject
	if picked != null:
		_on_preview_object_picked(picked)
	return picked


func _ensure_ui() -> void:
	if _initialized:
		return
	_initialized = true
	name = "FairyGUIPreview"
	custom_minimum_size = Vector2(0.0, 360.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 6)
	add_child(toolbar)

	_path_label = Label.new()
	_path_label.custom_minimum_size.x = 180.0
	_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	toolbar.add_child(_path_label)

	_component_picker = OptionButton.new()
	_component_picker.custom_minimum_size.x = 180.0
	_component_picker.tooltip_text = "选择包内组件"
	_component_picker.item_selected.connect(_on_component_selected)
	toolbar.add_child(_component_picker)

	_reload_button = Button.new()
	_reload_button.tooltip_text = "重新加载"
	_reload_button.pressed.connect(reload_current)
	toolbar.add_child(_reload_button)

	var toolbar_spacer := Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)

	_zoom_out_button = Button.new()
	_zoom_out_button.tooltip_text = "缩小"
	_zoom_out_button.pressed.connect(func() -> void: _zoom_at_view_center(_zoom / ZOOM_FACTOR))
	toolbar.add_child(_zoom_out_button)

	_zoom_label = Label.new()
	_zoom_label.custom_minimum_size.x = 56.0
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar.add_child(_zoom_label)

	_zoom_in_button = Button.new()
	_zoom_in_button.tooltip_text = "放大"
	_zoom_in_button.pressed.connect(func() -> void: _zoom_at_view_center(_zoom * ZOOM_FACTOR))
	toolbar.add_child(_zoom_in_button)

	_fit_button = Button.new()
	_fit_button.tooltip_text = "适应窗口"
	_fit_button.pressed.connect(_fit_preview)
	toolbar.add_child(_fit_button)

	var split := HSplitContainer.new()
	split.split_offset = 320
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)

	var hierarchy_panel := PanelContainer.new()
	hierarchy_panel.custom_minimum_size.x = 260.0
	split.add_child(hierarchy_panel)
	var hierarchy_box := VBoxContainer.new()
	hierarchy_panel.add_child(hierarchy_box)

	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = "筛选节点"
	_filter_edit.clear_button_enabled = true
	_filter_edit.text_changed.connect(_on_filter_changed)
	hierarchy_box.add_child(_filter_edit)

	_tree = Tree.new()
	_tree.columns = 2
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "节点")
	_tree.set_column_title(1, "类型")
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 110)
	_tree.select_mode = Tree.SELECT_ROW
	_tree.allow_reselect = true
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_tree_item_selected)
	hierarchy_box.add_child(_tree)

	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(preview_panel)

	_preview_scroll = ScrollContainer.new()
	_preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_preview_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_preview_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_scroll.resized.connect(_layout_preview)
	_preview_scroll.gui_input.connect(_on_preview_gui_input)
	preview_panel.add_child(_preview_scroll)

	_preview_canvas = Control.new()
	_preview_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_scroll.add_child(_preview_canvas)

	_preview_view = FGUIView.new()
	_preview_view.preview_in_editor = true
	_preview_view.resize_to_content = true
	_preview_view.match_control_size = false
	_preview_view.fairy_ready.connect(_on_preview_ready)
	_preview_canvas.add_child(_preview_view)

	_selection_overlay = SelectionOverlay.new()
	_selection_overlay.object_picked.connect(_on_preview_object_picked)
	_preview_canvas.add_child(_selection_overlay)

	_status_label = Label.new()
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_status_label)

	_set_zoom(1.0)
	_apply_editor_theme()
	clear_preview()


func _apply_editor_theme() -> void:
	var editor_theme := EditorInterface.get_editor_theme()
	_set_button_icon(_reload_button, editor_theme, "Reload")
	_set_button_icon(_zoom_out_button, editor_theme, "ZoomLess")
	_set_button_icon(_zoom_in_button, editor_theme, "ZoomMore")
	_set_button_icon(_fit_button, editor_theme, "ZoomReset")
	if _filter_edit != null and editor_theme.has_icon("Search", "EditorIcons"):
		_filter_edit.right_icon = editor_theme.get_icon("Search", "EditorIcons")


func _set_button_icon(button: Button, editor_theme: Theme, icon_name: String) -> void:
	if button != null and editor_theme.has_icon(icon_name, "EditorIcons"):
		button.icon = editor_theme.get_icon(icon_name, "EditorIcons")


func _show_component(component_name: String) -> void:
	if _package_resource == null or not _component_names.has(component_name):
		return
	_current_component = component_name
	_clear_hierarchy()
	_status_label.text = "正在加载 %s..." % component_name
	var changed := _preview_view.package != _package_resource or _preview_view.component_name != component_name
	_preview_view.package = _package_resource
	_preview_view.component_name = component_name
	if not changed:
		_preview_view.refresh_preview()


func _on_component_selected(index: int) -> void:
	if index < 0 or index >= _component_names.size():
		return
	_show_component(_component_names[index])


func _on_preview_ready(value: FGUIObject) -> void:
	_root_object = value
	_content_size = Vector2(maxf(1.0, value.width), maxf(1.0, value.height))
	_preview_view.size = _content_size
	_selection_overlay.set_root_object(value)
	_build_hierarchy(value)
	_select_object(value, true, false)
	_status_label.text = "%s · %d 个节点 · %.0f × %.0f" % [
		_current_component,
		_node_count,
		_content_size.x,
		_content_size.y,
	]
	call_deferred("_fit_preview")


func _clear_hierarchy() -> void:
	_root_object = null
	_selected_object = null
	_object_by_id.clear()
	_tree_item_by_id.clear()
	_node_count = 0
	_content_size = Vector2.ZERO
	if _tree != null:
		_tree.clear()
	if _selection_overlay != null:
		_selection_overlay.set_root_object(null)
	_layout_preview()


func _build_hierarchy(root: FGUIObject) -> void:
	_tree.clear()
	_object_by_id.clear()
	_tree_item_by_id.clear()
	_node_count = 0
	_append_object(root, null)
	_on_filter_changed(_filter_edit.text)


func _append_object(value: FGUIObject, parent_item: TreeItem) -> void:
	if value == null:
		return
	var item := _tree.create_item(parent_item)
	var object_id := value.get_instance_id()
	var display_name := value.name
	if value == _root_object and _current_component != "":
		display_name = _current_component
	if display_name == "":
		display_name = value.id if value.id != "" else "<unnamed>"
	var type_name := _object_type_name(value)
	item.set_text(0, display_name)
	item.set_text(1, type_name)
	item.set_metadata(0, object_id)
	item.set_tooltip_text(0, _object_tooltip(value, display_name, type_name))
	item.set_tooltip_text(1, item.get_tooltip_text(0))
	var icon := _object_icon(value)
	if icon != null:
		item.set_icon(0, icon)
	item.collapsed = false
	_object_by_id[object_id] = value
	_tree_item_by_id[object_id] = item
	_node_count += 1
	if value is FGUIComponent:
		for child: FGUIObject in (value as FGUIComponent).children:
			_append_object(child, item)


func _object_type_name(value: FGUIObject) -> String:
	if value is FGUIComponent and value.package_item != null and value.package_item.name != "":
		return value.package_item.name
	if value is FGUITree:
		return "Tree"
	if value is FGUIList:
		return "List"
	if value is FGUIComboBox:
		return "ComboBox"
	if value is FGUISlider:
		return "Slider"
	if value is FGUIProgressBar:
		return "ProgressBar"
	if value is FGUIScrollBar:
		return "ScrollBar"
	if value is FGUIButton:
		return "Button"
	if value is FGUILabel:
		return "Label"
	if value is FGUITextInput:
		return "TextInput"
	if value is FGUIRichTextField:
		return "RichText"
	if value is FGUITextField:
		return "Text"
	if value is FGUIMovieClip:
		return "MovieClip"
	if value is FGUIImage:
		return "Image"
	if value is FGUILoader3D:
		return "Loader3D"
	if value is FGUILoader:
		return "Loader"
	if value is FGUIGraph:
		return "Graph"
	if value is FGUIGroup:
		return "Group"
	if value is FGUIComponent:
		return "Component"
	return "Object"


func _object_icon(value: FGUIObject) -> Texture2D:
	var icon_name := "Control"
	if value is FGUITree:
		icon_name = "Tree"
	elif value is FGUIList:
		icon_name = "ItemList"
	elif value is FGUIButton:
		icon_name = "Button"
	elif value is FGUITextField:
		icon_name = "Label"
	elif value is FGUIImage or value is FGUILoader:
		icon_name = "TextureRect"
	elif value is FGUIGraph:
		icon_name = "GraphNode"
	var editor_theme := EditorInterface.get_editor_theme()
	return editor_theme.get_icon(icon_name, "EditorIcons") if editor_theme.has_icon(icon_name, "EditorIcons") else null


func _object_tooltip(value: FGUIObject, display_name: String, type_name: String) -> String:
	return "%s (%s)\nID: %s\n位置: %.0f, %.0f\n尺寸: %.0f × %.0f" % [
		display_name,
		type_name,
		value.id,
		value.x,
		value.y,
		value.width,
		value.height,
	]


func _on_tree_item_selected() -> void:
	if _syncing_selection:
		return
	var item := _tree.get_selected()
	if item == null:
		return
	var metadata: Variant = item.get_metadata(0)
	if metadata == null:
		return
	var object_id := int(metadata)
	var value := _object_by_id.get(object_id) as FGUIObject
	if value != null:
		_select_object(value, false, true)


func _on_preview_object_picked(value: FGUIObject) -> void:
	var mapped := value
	while mapped != null and not _tree_item_by_id.has(mapped.get_instance_id()):
		mapped = mapped.parent
	if mapped != null:
		_select_object(mapped, true, false)


func _select_object(value: FGUIObject, reveal_in_tree: bool, center_preview: bool) -> void:
	if value == null or value.is_disposed:
		return
	_selected_object = value
	_selection_overlay.set_selected_object(value)
	var item := _tree_item_by_id.get(value.get_instance_id()) as TreeItem
	if reveal_in_tree and item != null:
		if _filter_edit.text != "" and not item.is_visible_in_tree():
			_filter_edit.clear()
		var parent := item.get_parent()
		while parent != null:
			parent.collapsed = false
			parent = parent.get_parent()
		_syncing_selection = true
		item.select(0)
		_tree.scroll_to_item(item, true)
		_syncing_selection = false
	_status_label.text = "%s · %s · %.0f, %.0f · %.0f × %.0f" % [
		value.name if value.name != "" else value.id,
		_object_type_name(value),
		value.x,
		value.y,
		value.width,
		value.height,
	]
	if center_preview:
		call_deferred("_center_selected_object")


func _on_filter_changed(query: String) -> void:
	var root := _tree.get_root()
	if root != null:
		_filter_tree_item(root, query.strip_edges().to_lower())


func _filter_tree_item(item: TreeItem, query: String) -> bool:
	var child_match := false
	var child := item.get_first_child()
	while child != null:
		child_match = _filter_tree_item(child, query) or child_match
		child = child.get_next()
	var own_text := "%s %s" % [item.get_text(0), item.get_text(1)]
	var own_match := query == "" or own_text.to_lower().contains(query)
	item.visible = own_match or child_match
	if query != "" and child_match:
		item.collapsed = false
	return item.visible


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	if _zoom_label != null:
		_zoom_label.text = "%d%%" % int(round(_zoom * 100.0))
	_layout_preview()


func _zoom_at_view_center(value: float) -> void:
	if _preview_scroll == null:
		_set_zoom(value)
		return
	_zoom_around(value, _preview_scroll.size * 0.5)


func _zoom_around(value: float, focus_position: Vector2) -> void:
	var next_zoom := clampf(value, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, _zoom):
		return
	if _content_size.x <= 0.0 or _content_size.y <= 0.0:
		_set_zoom(next_zoom)
		return
	var current_scroll := Vector2(_preview_scroll.scroll_horizontal, _preview_scroll.scroll_vertical)
	var preview_point := (current_scroll + focus_position - _preview_origin) / _zoom
	_set_zoom(next_zoom)
	var target_scroll := _preview_origin + preview_point * _zoom - focus_position
	_apply_scroll_position(target_scroll)
	call_deferred("_apply_scroll_position", target_scroll)


func _fit_preview() -> void:
	if _content_size.x <= 0.0 or _content_size.y <= 0.0 or _preview_scroll == null:
		return
	var available := _preview_scroll.size - Vector2.ONE * PREVIEW_PADDING * 2.0
	if available.x <= 0.0 or available.y <= 0.0:
		return
	_set_zoom(minf(1.0, minf(available.x / _content_size.x, available.y / _content_size.y)))


func _layout_preview() -> void:
	if not _initialized or _preview_canvas == null:
		return
	var scaled_size := _content_size * _zoom
	var available := _preview_scroll.size if _preview_scroll != null else Vector2.ZERO
	var canvas_size := Vector2(
		maxf(available.x, scaled_size.x + PREVIEW_PADDING * 2.0),
		maxf(available.y, scaled_size.y + PREVIEW_PADDING * 2.0)
	)
	_preview_canvas.custom_minimum_size = canvas_size
	var origin := (canvas_size - scaled_size) * 0.5
	_preview_origin = origin
	_preview_view.position = _preview_origin
	_preview_view.scale = Vector2.ONE * _zoom
	_selection_overlay.position = _preview_origin
	_selection_overlay.size = scaled_size
	_selection_overlay.queue_redraw()


func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed:
				_panning = true
				_pan_start_mouse = mouse_event.position
				_pan_start_scroll = Vector2(
					_preview_scroll.scroll_horizontal,
					_preview_scroll.scroll_vertical
				)
				_preview_scroll.mouse_default_cursor_shape = Control.CURSOR_DRAG
			else:
				_stop_panning()
			_preview_scroll.accept_event()
			return
		if mouse_event.pressed and mouse_event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var wheel_factor := mouse_event.factor if mouse_event.factor > 0.0 else 1.0
			var scale_factor := pow(ZOOM_FACTOR, wheel_factor)
			var next_zoom := _zoom * scale_factor if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP else _zoom / scale_factor
			_zoom_around(next_zoom, mouse_event.position)
			_preview_scroll.accept_event()
			return
	if event is InputEventMouseMotion and _panning:
		var motion_event := event as InputEventMouseMotion
		if (motion_event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) == 0:
			_stop_panning()
			return
		var target_scroll := _pan_start_scroll - (motion_event.position - _pan_start_mouse)
		_apply_scroll_position(target_scroll)
		_preview_scroll.accept_event()


func _apply_scroll_position(value: Vector2) -> void:
	if _preview_scroll == null:
		return
	_preview_scroll.scroll_horizontal = maxi(0, int(round(value.x)))
	_preview_scroll.scroll_vertical = maxi(0, int(round(value.y)))


func _stop_panning() -> void:
	_panning = false
	if _preview_scroll != null:
		_preview_scroll.mouse_default_cursor_shape = Control.CURSOR_ARROW


func _center_selected_object() -> void:
	if _selected_object == null or _selected_object.node == null or _preview_scroll == null:
		return
	var global_center := _selected_object.local_to_global(Vector2(_selected_object.width, _selected_object.height) * 0.5)
	var canvas_center := _preview_canvas.get_global_transform().affine_inverse() * global_center
	_preview_scroll.scroll_horizontal = maxi(0, int(canvas_center.x - _preview_scroll.size.x * 0.5))
	_preview_scroll.scroll_vertical = maxi(0, int(canvas_center.y - _preview_scroll.size.y * 0.5))
