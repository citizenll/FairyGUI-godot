class_name FGUIScrollPane
extends RefCounted

const SCROLL_TWEEN_DURATION := 0.3
const INERTIA_MIN_VELOCITY := 60.0
const INERTIA_MIN_DURATION := 0.12
const INERTIA_MAX_DURATION := 0.8

var owner: FGUIComponent
var container: ScrollContainer
var content: Control
var scroll_type: int = FGUIEnums.SCROLL_BOTH
var scroll_bar_display: int = FGUIEnums.SCROLLBAR_VISIBLE
var scroll_bar_margin := FGUIMargin.new()
var display_on_left: bool = false
var snap_to_item: bool = false
var display_in_demand: bool = false
var bounceback_effect: bool = true
var touch_effect: bool = true
var page_mode: bool = false
var inertia_disabled: bool = false
var deceleration_rate: float = FGUIConfig.default_scroll_deceleration_rate
var mask_disabled: bool = false
var floating: bool = false
var dont_clip_margin: bool = false
var content_width: float = 0.0
var content_height: float = 0.0
var horizontal_scroll_bar: FGUIScrollBar
var vertical_scroll_bar: FGUIScrollBar
var header: FGUIComponent
var footer: FGUIComponent
var page_controller: FGUIController
var header_locked_size: float = 0.0
var footer_locked_size: float = 0.0

var _suppress_native_scroll: bool = false
var _handling_scroll: bool = false
var _updating_page_controller: bool = false
var _pointer_dragging: bool = false
var _pointer_dragged: bool = false
var _drag_touch_index: int = -1
var _last_drag_position := Vector2.ZERO
var _last_drag_scroll_position := Vector2.ZERO
var _drag_velocity := Vector2.ZERO
var _last_drag_scroll_time_ms: int = 0
var _pull_down_distance: float = 0.0
var _pull_up_distance: float = 0.0
var _scroll_tween: Tween
var _tweening_scroll: bool = false


func _init(p_owner: FGUIComponent = null) -> void:
	owner = p_owner
	bounceback_effect = FGUIConfig.default_scroll_bounce_effect
	touch_effect = FGUIConfig.default_scroll_touch_effect
	if owner != null:
		_create_nodes()


var pos_x: float:
	get:
		return container.scroll_horizontal if container != null else 0.0
	set(value):
		if container != null:
			container.scroll_horizontal = int(_clamp_x(value))


var pos_y: float:
	get:
		return container.scroll_vertical if container != null else 0.0
	set(value):
		if container != null:
			container.scroll_vertical = int(_clamp_y(value))


var view_width: float:
	get:
		return container.size.x if container != null else (owner.width if owner != null else 0.0)
	set(value):
		if owner != null:
			owner.width += value - view_width


var view_height: float:
	get:
		return container.size.y if container != null else (owner.height if owner != null else 0.0)
	set(value):
		if owner != null:
			owner.height += value - view_height


func setup(buffer: FGUIByteBuffer) -> void:
	scroll_type = buffer.read_i8()
	scroll_bar_display = buffer.read_i8()
	var flags := buffer.read_i32()
	if buffer.read_bool():
		scroll_bar_margin.top = buffer.read_i32()
		scroll_bar_margin.bottom = buffer.read_i32()
		scroll_bar_margin.left = buffer.read_i32()
		scroll_bar_margin.right = buffer.read_i32()
	var vertical_url := _string_or_empty(buffer.read_s())
	var horizontal_url := _string_or_empty(buffer.read_s())
	var header_url := _string_or_empty(buffer.read_s())
	var footer_url := _string_or_empty(buffer.read_s())

	display_on_left = (flags & 1) != 0
	snap_to_item = (flags & 2) != 0
	display_in_demand = (flags & 4) != 0
	page_mode = (flags & 8) != 0
	if (flags & 16) != 0:
		touch_effect = true
	elif (flags & 32) != 0:
		touch_effect = false
	if (flags & 64) != 0:
		bounceback_effect = true
	elif (flags & 128) != 0:
		bounceback_effect = false
	inertia_disabled = (flags & 256) != 0
	mask_disabled = (flags & 512) != 0
	floating = (flags & 1024) != 0
	dont_clip_margin = (flags & 2048) != 0

	if scroll_bar_display == FGUIEnums.SCROLLBAR_DEFAULT:
		scroll_bar_display = FGUIConfig.default_scroll_bar_display
	_configure_native_scroll_modes()
	_create_scroll_bar(vertical_url if vertical_url != "" else FGUIConfig.vertical_scroll_bar, true)
	_create_scroll_bar(horizontal_url if horizontal_url != "" else FGUIConfig.horizontal_scroll_bar, false)
	header = _create_refresh_component(header_url, "Header")
	footer = _create_refresh_component(footer_url, "Footer")
	_layout_scroll_bars()


func set_content_size(width: float, height: float) -> void:
	content_width = maxf(0.0, width)
	content_height = maxf(0.0, height)
	_layout_scroll_bars()
	if content != null:
		content.custom_minimum_size = Vector2(content_width, content_height)
		content.size = Vector2(content_width, content_height)
	_sync_native_ranges()
	set_pos(pos_x, pos_y)


func scroll_to_view(obj: FGUIObject, animated: bool = false, set_first: bool = false) -> void:
	if obj == null or container == null:
		return
	var target_x := pos_x
	var target_y := pos_y
	if set_first or obj.x < pos_x:
		target_x = obj.x
	elif obj.x + obj.width > pos_x + view_width:
		target_x = obj.x + obj.width - view_width
	if set_first or obj.y < pos_y:
		target_y = obj.y
	elif obj.y + obj.height > pos_y + view_height:
		target_y = obj.y + obj.height - view_height
	set_pos(target_x, target_y, animated)


func set_pos(x: float, y: float, animated: bool = false) -> void:
	if page_mode:
		x = roundf(x / maxf(view_width, 1.0)) * maxf(view_width, 1.0)
		y = roundf(y / maxf(view_height, 1.0)) * maxf(view_height, 1.0)
	var target := Vector2(_clamp_x(x), _clamp_y(y))
	if animated and _can_animate_scroll(target):
		_start_scroll_tween(target)
		return
	_cancel_scroll_tween()
	_set_pos_immediate(target)


func _set_pos_immediate(value: Vector2) -> void:
	_suppress_native_scroll = true
	pos_x = value.x
	pos_y = value.y
	_suppress_native_scroll = false
	_on_native_scroll()


func _can_animate_scroll(target: Vector2) -> bool:
	return container != null and owner != null and owner.node != null and owner.node.is_inside_tree() and not Vector2(pos_x, pos_y).is_equal_approx(target)


func _start_scroll_tween(target: Vector2, duration: float = SCROLL_TWEEN_DURATION) -> void:
	_cancel_scroll_tween()
	if owner == null or owner.node == null:
		_set_pos_immediate(target)
		return
	var tween := owner.node.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	_scroll_tween = tween
	tween.tween_method(Callable(self, "_set_pos_from_tween"), Vector2(pos_x, pos_y), target, maxf(duration, 0.001))
	tween.finished.connect(Callable(self, "_on_scroll_tween_finished").bind(tween))


func _set_pos_from_tween(value: Vector2) -> void:
	_tweening_scroll = true
	_set_pos_immediate(value)
	_tweening_scroll = false


func _on_scroll_tween_finished(tween: Tween) -> void:
	if tween != _scroll_tween:
		return
	_scroll_tween = null
	if owner != null:
		owner.emit_event(FGUIEvents.SCROLL_END)


func _cancel_scroll_tween() -> void:
	if _scroll_tween != null and is_instance_valid(_scroll_tween):
		_scroll_tween.kill()
	_scroll_tween = null


func set_perc_x(value: float, animated: bool = false) -> void:
	set_pos((content_width - view_width) * clampf(value, 0.0, 1.0), pos_y, animated)


func set_perc_y(value: float, animated: bool = false) -> void:
	set_pos(pos_x, (content_height - view_height) * clampf(value, 0.0, 1.0), animated)


func scroll_left(ratio: float = 1.0, animated: bool = false) -> void:
	set_pos(pos_x - (view_width if page_mode else FGUIConfig.default_scroll_step) * ratio, pos_y, animated)


func scroll_right(ratio: float = 1.0, animated: bool = false) -> void:
	set_pos(pos_x + (view_width if page_mode else FGUIConfig.default_scroll_step) * ratio, pos_y, animated)


func scroll_up(ratio: float = 1.0, animated: bool = false) -> void:
	set_pos(pos_x, pos_y - (view_height if page_mode else FGUIConfig.default_scroll_step) * ratio, animated)


func scroll_down(ratio: float = 1.0, animated: bool = false) -> void:
	set_pos(pos_x, pos_y + (view_height if page_mode else FGUIConfig.default_scroll_step) * ratio, animated)


func scroll_top(animated: bool = false) -> void:
	set_pos(pos_x, 0.0, animated)


func scroll_bottom(animated: bool = false) -> void:
	set_pos(pos_x, maxf(0.0, content_height - view_height), animated)


func scroll_leftmost(animated: bool = false) -> void:
	set_pos(0.0, pos_y, animated)


func scroll_rightmost(animated: bool = false) -> void:
	set_pos(maxf(0.0, content_width - view_width), pos_y, animated)


func lock_header(size: float) -> void:
	var next_size := maxf(0.0, size)
	if is_equal_approx(header_locked_size, next_size):
		return
	header_locked_size = next_size
	_layout_scroll_bars()
	set_pos(pos_x, pos_y)


func lock_footer(size: float) -> void:
	var next_size := maxf(0.0, size)
	if is_equal_approx(footer_locked_size, next_size):
		return
	footer_locked_size = next_size
	_layout_scroll_bars()
	set_pos(pos_x, pos_y)


func is_right_most() -> bool:
	return pos_x >= maxf(0.0, content_width - view_width)


func is_bottom_most() -> bool:
	return pos_y >= maxf(0.0, content_height - view_height)


func is_child_in_view(obj: FGUIObject) -> bool:
	if obj == null:
		return false
	return obj.x + obj.width > pos_x and obj.x < pos_x + view_width and obj.y + obj.height > pos_y and obj.y < pos_y + view_height


func current_page_x() -> int:
	return int(roundf(pos_x / maxf(view_width, 1.0)))


func current_page_y() -> int:
	return int(roundf(pos_y / maxf(view_height, 1.0)))


func set_current_page_x(value: int, animated: bool = false) -> void:
	set_pos(float(value) * view_width, pos_y, animated)


func set_current_page_y(value: int, animated: bool = false) -> void:
	set_pos(pos_x, float(value) * view_height, animated)


func handle_controller_changed(controller: FGUIController) -> void:
	if page_controller != controller or _updating_page_controller:
		return
	if scroll_type == FGUIEnums.SCROLL_HORIZONTAL:
		set_current_page_x(controller.selected_index, true)
	else:
		set_current_page_y(controller.selected_index, true)


func on_owner_size_changed() -> void:
	if container != null and owner != null:
		_layout_scroll_bars()
		set_pos(pos_x, pos_y)


func dispose() -> void:
	_cancel_scroll_tween()
	page_controller = null
	header_locked_size = 0.0
	footer_locked_size = 0.0
	if horizontal_scroll_bar != null:
		horizontal_scroll_bar.dispose()
		horizontal_scroll_bar = null
	if vertical_scroll_bar != null:
		vertical_scroll_bar.dispose()
		vertical_scroll_bar = null
	if header != null:
		header.dispose()
		header = null
	if footer != null:
		footer.dispose()
		footer = null
	if container != null:
		if container.is_inside_tree():
			container.queue_free()
		else:
			container.free()
	container = null
	content = null
	owner = null


func _create_nodes() -> void:
	container = ScrollContainer.new()
	container.name = "ScrollPane"
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	container.size = Vector2(owner.width, owner.height)
	content = Control.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(content)
	container.gui_input.connect(_on_container_gui_input)
	container.get_h_scroll_bar().value_changed.connect(func(_value: float) -> void: _on_native_scroll())
	container.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _on_native_scroll())
	owner.node.add_child(container)
	_configure_native_scroll_modes()
	_layout_scroll_bars()


func _configure_native_scroll_modes() -> void:
	if container == null:
		return
	container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if scroll_type != FGUIEnums.SCROLL_VERTICAL else ScrollContainer.SCROLL_MODE_DISABLED
	container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER if scroll_type != FGUIEnums.SCROLL_HORIZONTAL else ScrollContainer.SCROLL_MODE_DISABLED
	container.clip_contents = not mask_disabled
	container.scroll_deadzone = int(FGUIConfig.touch_scroll_sensitivity)


func _create_scroll_bar(resource_url: String, is_vertical: bool) -> void:
	if resource_url == "" or owner == null or owner.node == null:
		return
	var obj := FGUIPackage.create_object_from_url(resource_url)
	if not (obj is FGUIScrollBar):
		if obj != null:
			obj.dispose()
		push_warning("FairyGUI scroll bar resource is invalid: %s" % resource_url)
		return
	var scroll_bar := obj as FGUIScrollBar
	scroll_bar.set_scroll_pane(self, is_vertical)
	owner.node.add_child(scroll_bar.node)
	if is_vertical:
		vertical_scroll_bar = scroll_bar
	else:
		horizontal_scroll_bar = scroll_bar


func _create_refresh_component(resource_url: String, node_name: String) -> FGUIComponent:
	if resource_url == "" or owner == null or owner.node == null:
		return null
	var obj := FGUIPackage.create_object_from_url(resource_url)
	if not (obj is FGUIComponent):
		if obj != null:
			obj.dispose()
		push_warning("FairyGUI refresh resource is invalid: %s" % resource_url)
		return null
	var component := obj as FGUIComponent
	component.node.name = node_name
	component.visible = false
	owner.node.add_child(component.node)
	return component


func _layout_scroll_bars() -> void:
	if container == null or owner == null:
		return
	var inner_pos := Vector2(owner.margin.left, owner.margin.top)
	var inner_size := Vector2(
		maxf(0.0, owner.width - owner.margin.left - owner.margin.right),
		maxf(0.0, owner.height - owner.margin.top - owner.margin.bottom)
	)
	var vertical_width := vertical_scroll_bar.width if vertical_scroll_bar != null else 0.0
	var horizontal_height := horizontal_scroll_bar.height if horizontal_scroll_bar != null else 0.0
	var allow_vertical := scroll_type != FGUIEnums.SCROLL_HORIZONTAL
	var allow_horizontal := scroll_type != FGUIEnums.SCROLL_VERTICAL
	var show_vertical := vertical_scroll_bar != null and allow_vertical and scroll_bar_display != FGUIEnums.SCROLLBAR_HIDDEN
	var show_horizontal := horizontal_scroll_bar != null and allow_horizontal and scroll_bar_display != FGUIEnums.SCROLLBAR_HIDDEN

	for i in 2:
		var available_width := maxf(0.0, inner_size.x - (vertical_width if show_vertical and not floating else 0.0))
		var available_height := maxf(0.0, inner_size.y - (horizontal_height if show_horizontal and not floating else 0.0))
		if display_in_demand or scroll_bar_display == FGUIEnums.SCROLLBAR_AUTO:
			show_vertical = vertical_scroll_bar != null and allow_vertical and content_height > available_height
			show_horizontal = horizontal_scroll_bar != null and allow_horizontal and content_width > available_width

	var viewport_pos := inner_pos
	var viewport_size := inner_size
	var header_size := header_locked_size if header != null and allow_vertical else 0.0
	var footer_size := footer_locked_size if footer != null and allow_vertical else 0.0
	viewport_pos.y += header_size
	viewport_size.y = maxf(0.0, viewport_size.y - header_size - footer_size)
	if show_vertical and not floating:
		viewport_size.x = maxf(0.0, viewport_size.x - vertical_width)
		if display_on_left:
			viewport_pos.x += vertical_width
	if show_horizontal and not floating:
		viewport_size.y = maxf(0.0, viewport_size.y - horizontal_height)
	container.position = viewport_pos
	container.size = viewport_size
	_sync_native_ranges()

	if header != null:
		header.visible = header_size > 0.0
		if header.visible:
			header.set_size(viewport_size.x, header_size)
			header.set_xy(viewport_pos.x, viewport_pos.y - header_size)
	if footer != null:
		footer.visible = footer_size > 0.0
		if footer.visible:
			footer.set_size(viewport_size.x, footer_size)
			footer.set_xy(viewport_pos.x, viewport_pos.y + viewport_size.y)

	if vertical_scroll_bar != null:
		vertical_scroll_bar.visible = show_vertical
		if show_vertical:
			vertical_scroll_bar.set_size(vertical_width, maxf(0.0, inner_size.y - (horizontal_height if show_horizontal and not floating else 0.0)))
			vertical_scroll_bar.set_xy(
				inner_pos.x if display_on_left else inner_pos.x + inner_size.x - vertical_width,
				inner_pos.y
			)
	if horizontal_scroll_bar != null:
		horizontal_scroll_bar.visible = show_horizontal
		if show_horizontal:
			horizontal_scroll_bar.set_size(maxf(0.0, inner_size.x - (vertical_width if show_vertical and not floating else 0.0)), horizontal_height)
			horizontal_scroll_bar.set_xy(
				inner_pos.x + (vertical_width if show_vertical and display_on_left and not floating else 0.0),
				inner_pos.y + inner_size.y - horizontal_height
			)
	_update_scroll_bars()


func _sync_native_ranges() -> void:
	if container == null:
		return
	var was_suppressed := _suppress_native_scroll
	_suppress_native_scroll = true
	var horizontal_native := container.get_h_scroll_bar()
	horizontal_native.max_value = maxf(content_width, view_width)
	horizontal_native.page = view_width
	var vertical_native := container.get_v_scroll_bar()
	vertical_native.max_value = maxf(content_height, view_height)
	vertical_native.page = view_height
	_suppress_native_scroll = was_suppressed


func _clamp_x(value: float) -> float:
	return clampf(value, 0.0, maxf(0.0, content_width - view_width))


func _clamp_y(value: float) -> float:
	return clampf(value, 0.0, maxf(0.0, content_height - view_height))


func _on_native_scroll() -> void:
	if _suppress_native_scroll or _handling_scroll:
		return
	if _scroll_tween != null and not _tweening_scroll:
		_cancel_scroll_tween()
	_handling_scroll = true
	_record_drag_velocity()
	_update_scroll_bars()
	_update_page_controller()
	if owner is FGUIList and owner._virtual and not owner._refreshing_virtual:
		owner.refresh_virtual_list()
	if owner != null:
		owner.emit_event(FGUIEvents.SCROLL)
	_handling_scroll = false


func _on_container_gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		_cancel_scroll_tween()
	if not touch_effect:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_pull_gesture(event.position, -1)
		else:
			_end_pull_gesture()
	elif event is InputEventMouseMotion:
		_track_pull_gesture(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_begin_pull_gesture(event.position, event.index)
		elif _drag_touch_index == event.index:
			_end_pull_gesture()
	elif event is InputEventScreenDrag and _drag_touch_index == event.index:
		_track_pull_gesture(event.position)


func _begin_pull_gesture(pointer_position: Vector2, touch_index: int) -> void:
	_pointer_dragging = true
	_pointer_dragged = false
	_drag_touch_index = touch_index
	_last_drag_position = pointer_position
	_last_drag_scroll_position = Vector2(pos_x, pos_y)
	_drag_velocity = Vector2.ZERO
	_last_drag_scroll_time_ms = Time.get_ticks_msec()
	_pull_down_distance = 0.0
	_pull_up_distance = 0.0


func _track_pull_gesture(pointer_position: Vector2) -> void:
	if not _pointer_dragging:
		return
	var delta := pointer_position - _last_drag_position
	_last_drag_position = pointer_position
	if not is_zero_approx(delta.length_squared()):
		_pointer_dragged = true
	if scroll_type != FGUIEnums.SCROLL_HORIZONTAL:
		_track_pull_axis(delta.y, pos_y, maxf(0.0, content_height - view_height))
	if scroll_type != FGUIEnums.SCROLL_VERTICAL:
		_track_pull_axis(delta.x, pos_x, maxf(0.0, content_width - view_width))


func _track_pull_axis(delta: float, position: float, max_position: float) -> void:
	if is_zero_approx(delta):
		return
	var edge_epsilon := 0.5
	if position <= edge_epsilon and delta > 0.0:
		_pull_down_distance += delta
		_pull_up_distance = maxf(0.0, _pull_up_distance - delta)
	elif position >= max_position - edge_epsilon and delta < 0.0:
		_pull_up_distance -= delta
		_pull_down_distance = maxf(0.0, _pull_down_distance + delta)
	elif delta < 0.0 and _pull_down_distance > 0.0:
		_pull_down_distance = maxf(0.0, _pull_down_distance + delta)
	elif delta > 0.0 and _pull_up_distance > 0.0:
		_pull_up_distance = maxf(0.0, _pull_up_distance - delta)


func _end_pull_gesture() -> void:
	if not _pointer_dragging:
		return
	_pointer_dragging = false
	_drag_touch_index = -1
	if not _pointer_dragged:
		return
	var threshold := maxf(0.0, FGUIConfig.touch_drag_sensitivity)
	var target := _get_settled_scroll_target(_get_inertia_target())
	var defer_scroll_end := false
	if not target.is_equal_approx(Vector2(pos_x, pos_y)):
		var duration := _get_inertia_duration(_drag_velocity) if not inertia_disabled else SCROLL_TWEEN_DURATION
		_start_scroll_tween(target, duration)
		defer_scroll_end = _scroll_tween != null
	if owner != null:
		if _pull_down_distance > threshold:
			owner.emit_event(FGUIEvents.PULL_DOWN_RELEASE)
		elif _pull_up_distance > threshold:
			owner.emit_event(FGUIEvents.PULL_UP_RELEASE)
		if not defer_scroll_end:
			owner.emit_event(FGUIEvents.SCROLL_END)
	_pull_down_distance = 0.0
	_pull_up_distance = 0.0
	_pointer_dragged = false
	_drag_velocity = Vector2.ZERO
	_last_drag_scroll_time_ms = 0


func _record_drag_velocity() -> void:
	if not _pointer_dragging:
		return
	var now := Time.get_ticks_msec()
	var elapsed_ms := now - _last_drag_scroll_time_ms
	var current := Vector2(pos_x, pos_y)
	if elapsed_ms > 0:
		var raw_velocity := (current - _last_drag_scroll_position) / (float(elapsed_ms) * 0.001)
		_drag_velocity = raw_velocity if _drag_velocity.is_zero_approx() else _drag_velocity.lerp(raw_velocity, 0.75)
	_last_drag_scroll_position = current
	_last_drag_scroll_time_ms = now


func _get_inertia_target() -> Vector2:
	var current := Vector2(pos_x, pos_y)
	if inertia_disabled:
		return current
	var duration := _get_inertia_duration(_drag_velocity)
	if is_zero_approx(duration):
		return current
	var target := current + _drag_velocity * duration * 0.4
	return Vector2(_clamp_x(target.x), _clamp_y(target.y))


func _get_inertia_duration(velocity: Vector2) -> float:
	var speed := velocity.length()
	if speed < INERTIA_MIN_VELOCITY:
		return 0.0
	var rate := clampf(deceleration_rate, 0.01, 0.9999)
	var duration := log(INERTIA_MIN_VELOCITY / speed) / log(rate) / 60.0
	return clampf(duration, INERTIA_MIN_DURATION, INERTIA_MAX_DURATION)


func _get_settled_scroll_target(value: Vector2) -> Vector2:
	var target := Vector2(_clamp_x(value.x), _clamp_y(value.y))
	if page_mode:
		target.x = roundf(target.x / maxf(view_width, 1.0)) * maxf(view_width, 1.0)
		target.y = roundf(target.y / maxf(view_height, 1.0)) * maxf(view_height, 1.0)
		return Vector2(_clamp_x(target.x), _clamp_y(target.y))
	if snap_to_item and owner != null:
		var snapped := owner.get_snapping_position_with_dir(target.x, target.y, signi(_drag_velocity.x), signi(_drag_velocity.y))
		return Vector2(_clamp_x(snapped.x), _clamp_y(snapped.y))
	return target


func _update_scroll_bars() -> void:
	if horizontal_scroll_bar != null:
		horizontal_scroll_bar.set_display_percent(minf(1.0, view_width / maxf(content_width, 1.0)))
		horizontal_scroll_bar.set_scroll_percent(pos_x / maxf(content_width - view_width, 1.0))
	if vertical_scroll_bar != null:
		vertical_scroll_bar.set_display_percent(minf(1.0, view_height / maxf(content_height, 1.0)))
		vertical_scroll_bar.set_scroll_percent(pos_y / maxf(content_height - view_height, 1.0))


func _update_page_controller() -> void:
	if page_controller == null or page_controller.changing or _updating_page_controller:
		return
	var index := current_page_x() if scroll_type == FGUIEnums.SCROLL_HORIZONTAL else current_page_y()
	if index < 0 or index >= page_controller.page_count or page_controller.selected_index == index:
		return
	_updating_page_controller = true
	page_controller.selected_index = index
	_updating_page_controller = false


func _string_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)
