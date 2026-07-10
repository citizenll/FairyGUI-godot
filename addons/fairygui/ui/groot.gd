class_name FGUIRoot
extends FGUIComponent

static var inst: FGUIRoot
static var content_scale_level: int = 0

var content_scale_factor: float = 1.0:
	set(value):
		content_scale_factor = maxf(0.0, value)
		if content_scale_factor >= 3.5:
			content_scale_level = 3
		elif content_scale_factor >= 2.5:
			content_scale_level = 2
		elif content_scale_factor >= 1.5:
			content_scale_level = 1
		else:
			content_scale_level = 0
var _modal_layer: FGUIGraph
var _modal_wait_pane: FGUIObject
var _popup_stack: Array[FGUIObject] = []
var _tooltip_win: FGUIObject
var _default_tooltip_win: FGUIObject
var _focus_object: FGUIObject
var _attached_viewport: Viewport
var volume_scale: float = 1.0:
	set(value):
		volume_scale = maxf(0.0, value)

var modal_layer: FGUIGraph:
	get:
		return _modal_layer
var has_modal_window: bool:
	get:
		return _modal_layer != null and _modal_layer.parent == self
var modal_waiting: bool:
	get:
		return _modal_wait_pane != null and _modal_wait_pane.parent == self

var focus: FGUIObject:
	get:
		if node != null and node.get_viewport() != null:
			var focus_owner := node.get_viewport().gui_get_focus_owner()
			var focused_object := FGUIToolSet.display_object_to_gobject(focus_owner)
			if focused_object != null:
				return focused_object
		return _focus_object
	set(value):
		_focus_object = value
		if value != null and value.node != null and value.node.focus_mode != Control.FOCUS_NONE:
			if value.node.is_inside_tree():
				value.node.grab_focus()
			else:
				value.node.call_deferred("grab_focus")


func _init() -> void:
	super._init()
	inst = self
	name = "GRoot"
	if node != null:
		node.name = "GRoot"
		node.mouse_filter = Control.MOUSE_FILTER_PASS
		node.tree_entered.connect(_connect_viewport)
		node.tree_exiting.connect(_disconnect_viewport)


static func get_inst() -> FGUIRoot:
	if inst == null:
		inst = FGUIRoot.new()
	return inst


func attach_to(parent_node: Node) -> void:
	if parent_node == null or node == null:
		return
	if node.get_parent() != parent_node:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		parent_node.add_child(node)
	_connect_viewport()


func show_window(window: FGUIWindow) -> void:
	if window == null:
		return
	if window.parent != self:
		add_child(window)
	else:
		set_child_index(window, children.size() - 1)
	window._show_from_root()
	window.request_focus()
	if window.x > width:
		window.x = width - window.width
	elif window.x + window.width < 0.0:
		window.x = 0.0
	if window.y > height:
		window.y = height - window.height
	elif window.y + window.height < 0.0:
		window.y = 0.0
	_adjust_modal_layer()


func hide_window(window: FGUIWindow) -> void:
	if window == null:
		return
	window._hide_from_root()
	if window.parent == self:
		remove_child(window)
	_adjust_modal_layer()


func hide_window_immediately(window: FGUIWindow) -> void:
	hide_window(window)


func close_all_except_modals() -> void:
	for child: FGUIObject in children.duplicate():
		if child is FGUIWindow and not (child as FGUIWindow).modal:
			hide_window(child as FGUIWindow)


func close_all_windows() -> void:
	for child: FGUIObject in children.duplicate():
		if child is FGUIWindow:
			hide_window(child as FGUIWindow)


func get_top_window() -> FGUIWindow:
	for index in range(children.size() - 1, -1, -1):
		var child: FGUIObject = children[index]
		if child is FGUIWindow:
			return child as FGUIWindow
	return null


func bring_to_front(window: FGUIWindow) -> void:
	if window != null and window.parent == self:
		set_child_index(window, children.size() - 1)
		_adjust_modal_layer()


func _adjust_modal_layer() -> void:
	var modal_window: FGUIWindow = null
	for index in range(children.size() - 1, -1, -1):
		var child: FGUIObject = children[index]
		if child is FGUIWindow and child.modal and child.shown:
			modal_window = child as FGUIWindow
			break
	if modal_window == null:
		if _modal_layer != null and _modal_layer.parent == self:
			remove_child(_modal_layer)
		return
	if _modal_layer == null:
		_modal_layer = FGUIGraph.new()
		_modal_layer.color_rect.color = FGUIConfig.modal_layer_color
		_modal_layer.touchable = true
		_modal_layer.node.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.set_size(width, height)
	if _modal_layer.parent != self:
		add_child_at(_modal_layer, get_child_index(modal_window))
	else:
		set_child_index_before(_modal_layer, get_child_index(modal_window))
	if _modal_wait_pane != null and _modal_wait_pane.parent == self:
		set_child_index(_modal_wait_pane, children.size() - 1)


func _handle_size_changed() -> void:
	super._handle_size_changed()
	if _modal_layer != null:
		_modal_layer.set_size(width, height)


func dispose() -> void:
	_popup_stack.clear()
	_focus_object = null
	_disconnect_viewport()
	if _tooltip_win != null and _tooltip_win.parent == self:
		remove_child(_tooltip_win)
	_tooltip_win = null
	if _default_tooltip_win != null and _default_tooltip_win.parent == null:
		_default_tooltip_win.dispose()
	_default_tooltip_win = null
	if _modal_wait_pane != null and _modal_wait_pane.parent == null:
		_modal_wait_pane.dispose()
	_modal_wait_pane = null
	if _modal_layer != null and _modal_layer.parent != self:
		_modal_layer.dispose()
	_modal_layer = null
	if inst == self:
		inst = null
	super.dispose()


func show_popup(popup: FGUIObject, target: FGUIObject = null, direction: int = FGUIEnums.POPUP_AUTO) -> void:
	if popup == null:
		return
	var existing_index := _popup_stack.find(popup)
	if existing_index >= 0:
		_close_popups_from(existing_index)
	_popup_stack.append(popup)
	if target != null:
		var current: FGUIObject = target
		while current != null:
			if current.parent == self:
				popup.sorting_order = max(popup.sorting_order, current.sorting_order)
				break
			current = current.parent
	add_child(popup)
	_adjust_modal_layer()
	if target != null:
		var target_position := global_to_local(target.local_to_global(Vector2.ZERO))
		var x := target_position.x
		var y := target_position.y + target.height
		if x + popup.width > width:
			x = target_position.x + target.width - popup.width
		if direction == FGUIEnums.POPUP_UP or (direction == FGUIEnums.POPUP_AUTO and y + popup.height > height):
			y = target_position.y - popup.height - 1.0
			if y < 0.0:
				y = 0.0
				x += target.width * 0.5
		popup.set_xy(clampf(x, 0.0, maxf(0.0, width - popup.width)), clampf(y, 0.0, maxf(0.0, height - popup.height)))


func toggle_popup(popup: FGUIObject, target: FGUIObject = null, direction: int = FGUIEnums.POPUP_AUTO) -> void:
	if _popup_stack.has(popup):
		hide_popup(popup)
	else:
		show_popup(popup, target, direction)


func hide_popup(popup: FGUIObject = null) -> void:
	if popup == null:
		_close_popups_from(0)
		return
	var popup_index := _popup_stack.find(popup)
	if popup_index >= 0:
		_close_popups_from(popup_index)
	elif popup.parent == self:
		remove_child(popup)


func has_any_popup() -> bool:
	return not _popup_stack.is_empty()


func _on_gui_input(event: InputEvent) -> void:
	if FGUIToolSet.is_primary_pointer_press(event):
		hide_tooltips()
		_check_popups(FGUIToolSet.get_pointer_position(event))
	super._on_gui_input(event)


func _check_popups(global_position: Vector2) -> void:
	if _popup_stack.is_empty():
		return
	var keep_index := -1
	for index in _popup_stack.size():
		var popup := _popup_stack[index]
		if popup != null and popup.parent == self and popup.node != null and popup.node.get_global_rect().has_point(global_position):
			keep_index = index
	if keep_index < 0:
		_close_popups_from(0)
	elif keep_index + 1 < _popup_stack.size():
		_close_popups_from(keep_index + 1)


func _close_popups_from(index: int) -> void:
	for popup_index in range(_popup_stack.size() - 1, index - 1, -1):
		var popup := _popup_stack[popup_index]
		_popup_stack.remove_at(popup_index)
		_close_popup(popup)


func _close_popup(popup: FGUIObject) -> void:
	if popup == null or popup.parent != self:
		return
	if popup is FGUIWindow:
		hide_window(popup as FGUIWindow)
	else:
		remove_child(popup)


func show_tooltips(message: String) -> void:
	if _default_tooltip_win == null:
		if FGUIConfig.tooltips_win == "":
			return
		_default_tooltip_win = FGUIPackage.create_object_from_url(FGUIConfig.tooltips_win)
	if _default_tooltip_win == null:
		return
	_default_tooltip_win.set_text(message)
	show_tooltips_win(_default_tooltip_win)


func show_tooltips_win(tooltip_win: FGUIObject, global_position: Vector2 = Vector2.INF) -> void:
	if tooltip_win == null:
		return
	hide_tooltips()
	_tooltip_win = tooltip_win
	var pointer_position := global_position
	var offset_from_pointer := pointer_position == Vector2.INF
	if offset_from_pointer and node != null:
		pointer_position = node.get_global_mouse_position()
	var position := global_to_local(pointer_position)
	var x := position.x + (10.0 if offset_from_pointer else 0.0)
	var y := position.y + (20.0 if offset_from_pointer else 0.0)
	if x + tooltip_win.width > width:
		x -= tooltip_win.width + 1.0
		if x < 0.0:
			x = 10.0
	if y + tooltip_win.height > height:
		y -= tooltip_win.height + 1.0
		if x - tooltip_win.width - 1.0 > 0.0:
			x -= tooltip_win.width + 1.0
		if y < 0.0:
			y = 10.0
	tooltip_win.set_xy(x, y)
	add_child(tooltip_win)


func hide_tooltips() -> void:
	if _tooltip_win != null and _tooltip_win.parent == self:
		remove_child(_tooltip_win)
	_tooltip_win = null


func show_modal_wait(message: String = "") -> void:
	var created := false
	if _modal_wait_pane == null and FGUIConfig.global_modal_waiting != "":
		_modal_wait_pane = FGUIPackage.create_object_from_url(FGUIConfig.global_modal_waiting)
		created = _modal_wait_pane != null
	if _modal_wait_pane == null:
		return
	_modal_wait_pane.set_xy(0.0, 0.0)
	_modal_wait_pane.set_size(width, height)
	if created:
		_modal_wait_pane.add_relation(self, FGUIEnums.RELATION_SIZE)
	_modal_wait_pane.set_text(message)
	if _modal_wait_pane.parent != self:
		add_child(_modal_wait_pane)
	_adjust_modal_layer()


func close_modal_wait() -> void:
	if _modal_wait_pane != null and _modal_wait_pane.parent == self:
		remove_child(_modal_wait_pane)
	_adjust_modal_layer()


func play_one_shot_sound(sound: Variant, volume_scale: float = 1.0) -> AudioStreamPlayer:
	var stream: AudioStream
	if sound is AudioStream:
		stream = sound
	elif sound is String:
		var path := String(sound)
		if path.begins_with("ui://"):
			var item := FGUIPackage.get_item_by_url(path)
			if item != null:
				stream = item.owner.get_item_asset(item)
		else:
			var resource := load(path)
			if resource is AudioStream:
				stream = resource
	if stream == null or node == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(0.0001, volume_scale * self.volume_scale))
	node.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


func _update_size_from_viewport() -> void:
	if node == null:
		return
	var viewport := node.get_viewport()
	if viewport != null:
		set_size(viewport.get_visible_rect().size.x, viewport.get_visible_rect().size.y)


func _connect_viewport() -> void:
	if node == null:
		return
	var viewport := node.get_viewport()
	if viewport == _attached_viewport:
		_update_size_from_viewport()
		return
	_disconnect_viewport()
	_attached_viewport = viewport
	if _attached_viewport != null:
		_attached_viewport.size_changed.connect(_on_viewport_size_changed)
	_update_size_from_viewport()


func _disconnect_viewport() -> void:
	if _attached_viewport != null and _attached_viewport.size_changed.is_connected(_on_viewport_size_changed):
		_attached_viewport.size_changed.disconnect(_on_viewport_size_changed)
	_attached_viewport = null


func _on_viewport_size_changed() -> void:
	_update_size_from_viewport()
