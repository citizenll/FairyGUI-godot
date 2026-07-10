class_name FGUIWindow
extends FGUIComponent

var content_pane: FGUIComponent
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
var frame: FGUIComponent
var content_area: FGUIObject
var _close_button: FGUIObject
var _modal_wait_pane: FGUIObject
var _inited: bool = false
var _requesting_cmd: int = 0

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
		return parent != null
var is_top: bool:
	get:
		return parent != null and parent.get_child_index(self) == parent.num_children - 1
var modal_waiting: bool:
	get:
		return _modal_wait_pane != null and _modal_wait_pane.parent == self


func show() -> void:
	show_on(FGUIRoot.get_inst())


func show_on(root: FGUIRoot) -> void:
	if root != null:
		root.show_window(self)


func hide() -> void:
	var root := parent as FGUIRoot
	if root != null:
		root.hide_window(self)
	else:
		_hide_from_root()


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
		_inited = true
		on_init()
	on_shown()


func _hide_from_root() -> void:
	if not shown:
		return
	close_modal_wait()
	shown = false
	visible = false
	on_hide()


func toggle_status() -> void:
	if is_showing:
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
	if content_pane == value:
		return
	if content_pane != null:
		remove_child(content_pane)
	content_pane = value
	frame = null
	close_button = null
	content_area = null
	if content_pane != null:
		add_child(content_pane)
		set_size(content_pane.width, content_pane.height)
		if content_pane.get_child("frame") is FGUIComponent:
			frame = content_pane.get_child("frame") as FGUIComponent
			close_button = frame.get_child("closeButton")
			content_area = frame.get_child("contentArea")


func show_modal_wait(requesting_cmd: int = 0) -> void:
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
		_modal_wait_pane.set_xy(content_area.x, content_area.y)
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


func dispose() -> void:
	hide_immediately()
	close_button = null
	content_pane = null
	frame = null
	content_area = null
	if _modal_wait_pane != null:
		if _modal_wait_pane.parent == self:
			remove_child(_modal_wait_pane)
		_modal_wait_pane.dispose()
	_modal_wait_pane = null
	super.dispose()


func on_init() -> void:
	pass


func on_shown() -> void:
	pass


func on_hide() -> void:
	pass
