class_name FGUIWindow
extends FGUIComponent

var _content_pane: FGUIComponent
var content_pane: FGUIComponent:
	get:
		return _content_pane
	set(value):
		set_content_pane(value)
var _modal: bool = false
var modal: bool:
	get:
		return _modal
	set(value):
		if _modal == value:
			return
		_modal = value
		var root := parent as FGUIRoot
		if root != null:
			root._adjust_modal_layer()
var bring_to_front_on_click: bool = FGUIConfig.bring_window_to_front_on_click
var shown: bool = false
var _frame: FGUIComponent
var frame: FGUIComponent:
	get:
		return _frame
var _content_area: FGUIObject
var content_area: FGUIObject:
	get:
		return _content_area
	set(value):
		_content_area = value
var _drag_area: FGUIObject
var drag_area: FGUIObject:
	get:
		return _drag_area
	set(value):
		_set_drag_area(value)
var _close_button: FGUIObject
var _modal_wait_pane: FGUIObject
var _inited: bool = false
var _loading: bool = false
var _requesting_cmd: int = 0
var _ui_sources: Array[FGUIUISource] = []

var close_button: FGUIObject:
	get:
		return _close_button
	set(value):
		if _close_button == value:
			return
		if _close_button != null:
			_close_button.off("click", Callable(self, "_close_button_clicked"))
		_close_button = value
		if _close_button != null:
			_close_button.on("click", Callable(self, "_close_button_clicked"))
var is_showing: bool:
	get:
		return parent != null and visible
var is_top: bool:
	get:
		return is_showing and parent.get_child_index(self) == parent.num_children - 1
var modal_waiting: bool:
	get:
		return _modal_wait_pane != null and _modal_wait_pane.parent == self
var modal_waiting_pane: FGUIObject:
	get:
		return _modal_wait_pane


func add_ui_source(source: FGUIUISource) -> void:
	if source != null:
		_ui_sources.append(source)


func show() -> void:
	show_on(FGUIRoot.get_inst())


func show_on(root: FGUIRoot) -> void:
	if root != null:
		root.show_window(self)


func hide() -> void:
	if is_showing:
		do_hide_animation()


func hide_immediately() -> void:
	var root := parent as FGUIRoot
	if root != null:
		root.hide_window_immediately(self)
	else:
		_hide_from_root()


func _show_from_root() -> void:
	if shown:
		visible = true
		return
	shown = true
	visible = true
	if not _inited:
		init()
	else:
		do_show_animation()


func _hide_from_root() -> void:
	if not shown:
		return
	close_modal_wait()
	shown = false
	visible = false
	on_hide()


func toggle_status() -> void:
	if is_top:
		hide()
	else:
		show()


func center_on(root: FGUIRoot = null, restraint: bool = false) -> void:
	var target := root if root != null else FGUIRoot.get_inst()
	if target != null:
		set_xy(roundf((target.width - width) * 0.5), roundf((target.height - height) * 0.5))
		if restraint:
			add_relation(target, FGUIEnums.RELATION_CENTER_CENTER)
			add_relation(target, FGUIEnums.RELATION_MIDDLE_MIDDLE)


func bring_to_front() -> void:
	var root := parent as FGUIRoot
	if root != null:
		root.bring_to_front(self)


func set_content_pane(value: FGUIComponent) -> void:
	if _content_pane == value:
		return
	if _content_pane != null:
		_content_pane.remove_relation(self, FGUIEnums.RELATION_SIZE)
		remove_child(_content_pane)
	_content_pane = value
	_frame = null
	close_button = null
	drag_area = null
	content_area = null
	if _content_pane != null:
		add_child(_content_pane)
		set_size(_content_pane.width, _content_pane.height)
		_content_pane.add_relation(self, FGUIEnums.RELATION_SIZE)
		if _content_pane.get_child("frame") is FGUIComponent:
			_frame = _content_pane.get_child("frame") as FGUIComponent
			close_button = _frame.get_child("closeButton")
			drag_area = _frame.get_child("dragArea")
			content_area = _frame.get_child("contentArea")


func _set_drag_area(value: FGUIObject) -> void:
	if _drag_area == value:
		return
	if _drag_area != null:
		_drag_area.draggable = false
		_drag_area.off(FGUIEvents.DRAG_START, Callable(self, "_drag_area_drag_started"))
	_drag_area = value
	if _drag_area != null:
		if _drag_area is FGUIGraph and (_drag_area as FGUIGraph).type == FGUIGraph.TYPE_EMPTY:
			(_drag_area as FGUIGraph).draw_rect(0.0, Color.TRANSPARENT, Color.TRANSPARENT)
		_drag_area.draggable = true
		_drag_area.on(FGUIEvents.DRAG_START, Callable(self, "_drag_area_drag_started"))


func show_modal_wait(requesting_cmd: int = 0) -> void:
	if requesting_cmd != 0:
		_requesting_cmd = requesting_cmd
	if _modal_wait_pane == null and FGUIConfig.window_modal_waiting != "":
		_modal_wait_pane = FGUIPackage.create_object_from_url(FGUIConfig.window_modal_waiting)
	if _modal_wait_pane == null:
		return
	_layout_modal_wait_pane()
	if _modal_wait_pane.parent != self:
		add_child(_modal_wait_pane)


func close_modal_wait(requesting_cmd: int = 0) -> bool:
	if requesting_cmd != 0 and requesting_cmd != _requesting_cmd:
		return false
	_requesting_cmd = 0
	if _modal_wait_pane != null and _modal_wait_pane.parent == self:
		remove_child(_modal_wait_pane)
	return true


func _layout_modal_wait_pane() -> void:
	if _modal_wait_pane == null:
		return
	if content_area != null:
		var content_position := global_to_local(content_area.local_to_global(Vector2.ZERO))
		_modal_wait_pane.set_xy(content_position.x, content_position.y)
		_modal_wait_pane.set_size(content_area.width, content_area.height)
	else:
		_modal_wait_pane.set_xy(0, 0)
		_modal_wait_pane.set_size(width, height)


func _on_gui_input(event: InputEvent) -> void:
	if shown and bring_to_front_on_click and FGUIToolSet.is_primary_pointer_press(event):
		bring_to_front()
	super._on_gui_input(event)


func _close_button_clicked(_event: Variant = null) -> void:
	hide()


func _drag_area_drag_started(event: Variant = null) -> void:
	if _drag_area != null:
		_drag_area.stop_drag()
	var input_event := event as InputEvent
	start_drag(FGUIToolSet.get_pointer_id(input_event) if input_event != null else -1)


func init() -> void:
	if _inited or _loading or is_disposed:
		return
	var needs_loading := false
	for source: FGUIUISource in _ui_sources:
		if not source.loaded:
			needs_loading = true
			break
	if not needs_loading:
		_finish_init()
		return
	_loading = true
	for source: FGUIUISource in _ui_sources:
		if not source.loaded:
			source.load(Callable(self, "_ui_load_complete"))
	_ui_load_complete()


func _ui_load_complete() -> void:
	if not _loading or is_disposed:
		return
	for source: FGUIUISource in _ui_sources:
		if not source.loaded:
			return
	_loading = false
	_finish_init()


func _finish_init() -> void:
	if _inited or is_disposed:
		return
	_inited = true
	on_init()
	if is_showing:
		do_show_animation()


func do_show_animation() -> void:
	on_shown()


func do_hide_animation() -> void:
	hide_immediately()


func _handle_size_changed() -> void:
	super._handle_size_changed()
	if modal_waiting:
		_layout_modal_wait_pane()


func dispose() -> void:
	if is_disposed:
		return
	var was_loading := _loading
	_loading = false
	if was_loading:
		for source: FGUIUISource in _ui_sources:
			source.cancel()
	hide_immediately()
	close_button = null
	drag_area = null
	if _modal_wait_pane != null and _modal_wait_pane.parent == null:
		_modal_wait_pane.dispose()
	_ui_sources.clear()
	super.dispose()
	_content_pane = null
	_frame = null
	_content_area = null
	_modal_wait_pane = null
	shown = false


func on_init() -> void:
	pass


func on_shown() -> void:
	pass


func on_hide() -> void:
	pass
