class_name FGUIObject
extends RefCounted

const DragInputRelay := preload("res://addons/fairygui/ui/drag_input_relay.gd")

static var _instance_counter: int = 0
static var dragging_object: FGUIObject
static var _last_pointer_position: Vector2 = Vector2.ZERO
static var _has_last_pointer_position: bool = false

var data: Variant
var package_item: FGUIPackageItem
var parent: FGUIComponent
var node: Control
var relations: FGUIRelations
var pixel_hit_test: FGUIPixelHitTest

var id: String:
	get:
		return _id
var name: String:
	get:
		return _name
	set(value):
		_name = value
		if node != null:
			node.name = value if value != "" else _id
var x: float:
	get:
		return _x
	set(value):
		set_xy(value, _y)
var y: float:
	get:
		return _y
	set(value):
		set_xy(_x, value)
var width: float:
	get:
		return _width
	set(value):
		set_size(value, _raw_height)
var height: float:
	get:
		return _height
	set(value):
		set_size(_raw_width, value)
var alpha: float:
	get:
		return _alpha
	set(value):
		_alpha = value
		_handle_alpha_changed()
var visible: bool:
	get:
		return _visible
	set(value):
		_visible = value
		_handle_visible_changed()
		if _group is FGUIGroup and _group.exclude_invisibles:
			_group.set_bounds_changed_flag()
var touchable: bool:
	get:
		return _touchable
	set(value):
		_touchable = value
		_handle_touchable_changed()
var grayed: bool:
	get:
		return _grayed
	set(value):
		_grayed = value
		_handle_grayed_changed()
var enabled: bool:
	get:
		return not _grayed and _touchable
	set(value):
		grayed = not value
		touchable = value
var rotation: float:
	get:
		return _rotation
	set(value):
		_rotation = value
		if node != null:
			node.rotation_degrees = value
var scale_x: float:
	get:
		return _scale.x
	set(value):
		set_scale(value, _scale.y)
var scale_y: float:
	get:
		return _scale.y
	set(value):
		set_scale(_scale.x, value)
var pivot_x: float:
	get:
		return _pivot.x
	set(value):
		set_pivot(value, _pivot.y, _pivot_as_anchor)
var pivot_y: float:
	get:
		return _pivot.y
	set(value):
		set_pivot(_pivot.x, value, _pivot_as_anchor)
var pivot_as_anchor: bool:
	get:
		return _pivot_as_anchor
	set(value):
		set_pivot(_pivot.x, _pivot.y, value)
var sorting_order: int:
	get:
		return _sorting_order
	set(value):
		_sorting_order = maxi(0, value)
		if parent != null:
			parent.child_sorting_order_changed(self)
var group: FGUIObject:
	get:
		return _group
	set(value):
		_group = value
		_handle_visible_changed()
var tooltips: String:
	get:
		return _tooltips
	set(value):
		_tooltips = value
		if node != null:
			node.tooltip_text = value if FGUIConfig.tooltips_win == "" else ""
var x_min: float:
	get:
		return _x
	set(value):
		set_xy(value, _y)
var y_min: float:
	get:
		return _y
	set(value):
		set_xy(_x, value)
var actual_width: float:
	get:
		return width * absf(_scale.x)
var actual_height: float:
	get:
		return height * absf(_scale.y)
var root: FGUIRoot:
	get:
		var current: FGUIObject = self
		while current.parent != null:
			current = current.parent
		return current if current is FGUIRoot else FGUIRoot.inst
var internal_visible: bool:
	get:
		return _internal_visible and (_group == null or _group == self or _group.internal_visible)
var internal_visible2: bool:
	get:
		return _visible and _internal_visible and (_group == null or _group == self or _group.internal_visible2)
var internal_visible3: bool:
	get:
		return _internal_visible and _visible
var drag_bounds: Variant:
	get:
		return _drag_bounds
	set(value):
		_drag_bounds = value if value is Rect2 else null
var dragging: bool:
	get:
		return dragging_object == self
var is_disposed: bool:
	get:
		return node == null
var source_width: float = 0.0
var source_height: float = 0.0
var init_width: float = 0.0
var init_height: float = 0.0
var min_width: float = 0.0
var min_height: float = 0.0
var max_width: float = 0.0
var max_height: float = 0.0

var _id: String = ""
var _name: String = ""
var _x: float = 0.0
var _y: float = 0.0
var _width: float = 0.0
var _height: float = 0.0
var _raw_width: float = 0.0
var _raw_height: float = 0.0
var _alpha: float = 1.0
var _visible: bool = true
var _touchable: bool = true
var _grayed: bool = false
var _rotation: float = 0.0
var _scale: Vector2 = Vector2.ONE
var _pivot: Vector2 = Vector2.ZERO
var _pivot_as_anchor: bool = false
var _under_construct: bool = false
var _internal_visible: bool = true
var _sorting_order: int = 0
var _group: FGUIObject
var _tooltips: String = ""
var _event_listeners: Dictionary = {}
var _gears: Dictionary = {}
var _gear_locked: bool = false
var _handling_controller: bool = false
var _dragging: bool = false
var _drag_testing: bool = false
var _drag_start_cancelled: bool = false
var _drag_click_suppressed: bool = false
var _drag_pointer_active: bool = false
var _drag_touch_index: int = -1
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_position: Vector2 = Vector2.ZERO
var _drag_start_size: Vector2 = Vector2.ZERO
var _drag_bounds: Variant = null
var _drag_input_relay: Node
var draggable: bool = false
var _size_percent_in_group: float = 0.0


func _init() -> void:
	_id = str(_instance_counter)
	_instance_counter += 1
	relations = FGUIRelations.new(self)
	_create_display_object()
	if node != null:
		node.set_meta("fgui_owner", self)
		node.name = _id
		node.gui_input.connect(_on_gui_input)
		node.mouse_entered.connect(_on_mouse_entered)
		node.mouse_exited.connect(_on_mouse_exited)


func set_xy(new_x: float, new_y: float) -> void:
	if is_equal_approx(_x, new_x) and is_equal_approx(_y, new_y):
		return
	var dx := new_x - _x
	var dy := new_y - _y
	_x = new_x
	_y = new_y
	_handle_xy_changed()
	if self is FGUIGroup:
		(self as FGUIGroup).move_children(dx, dy)
	if group != null and group is FGUIGroup:
		group.set_bounds_changed_flag(true)


func set_size(new_width: float, new_height: float, _ignore_pivot: bool = false) -> void:
	if max_width > 0.0:
		new_width = minf(new_width, max_width)
	if max_height > 0.0:
		new_height = minf(new_height, max_height)
	new_width = maxf(new_width, min_width)
	new_height = maxf(new_height, min_height)
	if is_equal_approx(_raw_width, new_width) and is_equal_approx(_raw_height, new_height):
		return
	var old_width := _raw_width
	var old_height := _raw_height
	_raw_width = new_width
	_raw_height = new_height
	_width = new_width
	_height = new_height
	_handle_size_changed()
	if self is FGUIGroup:
		(self as FGUIGroup).resize_children(_raw_width - old_width, _raw_height - old_height)
	relations.on_owner_size_changed(_raw_width - old_width, _raw_height - old_height, _pivot_as_anchor)
	if parent != null:
		parent.set_bounds_changed_flag()
	if group != null and group is FGUIGroup:
		group.set_bounds_changed_flag()
	emit_event(FGUIEvents.SIZE_CHANGED)


func set_scale(scale_x: float, scale_y: float) -> void:
	_scale = Vector2(scale_x, scale_y)
	if node != null:
		node.scale = _scale


func set_alpha(value: float) -> void:
	alpha = value


func set_visible(value: bool) -> void:
	visible = value


func set_touchable(value: bool) -> void:
	touchable = value


func set_pivot(pivot_x: float, pivot_y: float = 0.0, as_anchor: bool = false) -> void:
	_pivot = Vector2(pivot_x, pivot_y)
	_pivot_as_anchor = as_anchor
	if node != null:
		node.pivot_offset = Vector2(_width * _pivot.x, _height * _pivot.y)
	_handle_xy_changed()


func center(restraint: bool = false) -> void:
	var target: FGUIObject = parent if parent != null else FGUIRoot.inst
	if target == null:
		return
	set_xy((target.width - width) * 0.5, (target.height - height) * 0.5)
	if restraint:
		add_relation(target, FGUIEnums.RELATION_CENTER_CENTER)
		add_relation(target, FGUIEnums.RELATION_MIDDLE_MIDDLE)


func make_full_screen(restraint: bool = true) -> void:
	var target: FGUIObject = parent if parent != null else FGUIRoot.inst
	if target == null:
		return
	set_xy(0.0, 0.0)
	set_size(target.width, target.height)
	if restraint:
		add_relation(target, FGUIEnums.RELATION_SIZE)


func tween_move(end_value: Vector2, duration: float) -> FGUIGTweener:
	return FGUIGTween.to2(x, y, end_value.x, end_value.y, duration).set_target(self, Callable(self, "set_xy"))


func tween_move_x(end_value: float, duration: float) -> FGUIGTweener:
	return FGUIGTween.to(x, end_value, duration).set_target(self, "x")


func tween_move_y(end_value: float, duration: float) -> FGUIGTweener:
	return FGUIGTween.to(y, end_value, duration).set_target(self, "y")


func tween_scale(end_value: Vector2, duration: float) -> FGUIGTweener:
	return FGUIGTween.to2(_scale.x, _scale.y, end_value.x, end_value.y, duration).set_target(self, Callable(self, "set_scale"))


func tween_scale_x(end_value: float, duration: float) -> FGUIGTweener:
	return FGUIGTween.to(_scale.x, end_value, duration).set_target(self, Callable(self, "_set_tween_scale_x"))


func tween_scale_y(end_value: float, duration: float) -> FGUIGTweener:
	return FGUIGTween.to(_scale.y, end_value, duration).set_target(self, Callable(self, "_set_tween_scale_y"))


func tween_resize(end_value: Vector2, duration: float) -> FGUIGTweener:
	return FGUIGTween.to2(width, height, end_value.x, end_value.y, duration).set_target(self, Callable(self, "set_size"))


func tween_fade(end_value: float, duration: float) -> FGUIGTweener:
	return FGUIGTween.to(alpha, end_value, duration).set_target(self, "alpha")


func tween_rotate(end_value: float, duration: float) -> FGUIGTweener:
	return FGUIGTween.to(rotation, end_value, duration).set_target(self, "rotation")


func _set_tween_scale_x(value: float) -> void:
	set_scale(value, _scale.y)


func _set_tween_scale_y(value: float) -> void:
	set_scale(_scale.x, value)


func construct_from_resource() -> void:
	pass


func ensure_size_correct() -> void:
	pass


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	if not buffer.seek(begin_pos, 0):
		return
	buffer.skip(5)
	_id = _string_or_empty(buffer.read_s())
	name = _string_or_empty(buffer.read_s())
	set_xy(buffer.read_i32(), buffer.read_i32())

	if buffer.read_bool():
		init_width = buffer.read_i32()
		init_height = buffer.read_i32()
		set_size(init_width, init_height, true)

	if buffer.read_bool():
		min_width = buffer.read_i32()
		max_width = buffer.read_i32()
		min_height = buffer.read_i32()
		max_height = buffer.read_i32()

	if buffer.read_bool():
		set_scale(buffer.read_float32(), buffer.read_float32())

	if buffer.read_bool():
		buffer.skip(8)

	if buffer.read_bool():
		set_pivot(buffer.read_float32(), buffer.read_float32(), buffer.read_bool())

	alpha = buffer.read_float32()
	_rotation = buffer.read_float32()
	if node != null:
		node.rotation_degrees = _rotation
	visible = buffer.read_bool()
	touchable = buffer.read_bool()
	grayed = buffer.read_bool()
	buffer.read_i8()
	var filter := buffer.read_i8()
	if filter == 1:
		FGUIToolSet.set_color_filter(node, [buffer.read_float32(), buffer.read_float32(), buffer.read_float32(), buffer.read_float32()])
	var user_data = buffer.read_s()
	if user_data != null:
		data = user_data


func setup_after_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	if buffer.seek(begin_pos, 1):
		var tips = buffer.read_s()
		if tips != null:
			tooltips = str(tips)
		var group_id := buffer.read_i16()
		if group_id >= 0 and parent != null:
			_group = parent.get_child_at(group_id)

	if buffer.seek(begin_pos, 2):
		var count := buffer.read_i16()
		for i in count:
			var next_pos := buffer.read_i16() + buffer.pos
			var gear := get_gear(buffer.read_i8())
			gear.setup(buffer)
			buffer.pos = next_pos


func get_prop(index: int) -> Variant:
	match index:
		FGUIEnums.OBJECT_PROP_TEXT:
			return get_text()
		FGUIEnums.OBJECT_PROP_ICON:
			return get_icon()
		FGUIEnums.OBJECT_PROP_COLOR:
			return null
		FGUIEnums.OBJECT_PROP_FONT_SIZE:
			return 0
		_:
			return null


func set_prop(index: int, value: Variant) -> void:
	match index:
		FGUIEnums.OBJECT_PROP_TEXT:
			set_text(str(value))
		FGUIEnums.OBJECT_PROP_ICON:
			set_icon(str(value))


func get_text() -> String:
	return ""


func set_text(_value: String) -> void:
	pass


func get_icon() -> String:
	return ""


func set_icon(_value: String) -> void:
	pass


func add_relation(target: FGUIObject, relation_type: int, use_percent: bool = false) -> void:
	relations.add(target, relation_type, use_percent)


func remove_relation(target: FGUIObject, relation_type: int = -1) -> void:
	relations.remove(target, relation_type)


func get_gear(index: int) -> FGUIGearBase:
	if not _gears.has(index):
		_gears[index] = FGUIGearBase.create(self, index)
	return _gears[index]


func update_gear(index: int) -> void:
	if _under_construct or _gear_locked:
		return
	var gear: FGUIGearBase = _gears.get(index)
	if gear != null and gear.controller != null:
		gear.update_state()


func update_gear_from_relations(index: int, dx: float, dy: float) -> void:
	if _under_construct or _gear_locked:
		return
	if index == 1:
		var gear_xy: FGUIGearBase = _gears.get(1)
		if gear_xy is FGUIGearXY:
			gear_xy.update_from_relations(dx, dy)
	elif index == 2:
		var gear_size: FGUIGearBase = _gears.get(2)
		if gear_size is FGUIGearSize:
			gear_size.update_from_relations(dx, dy)


func add_display_lock() -> int:
	var gear: FGUIGearBase = _gears.get(0)
	var display_gear: FGUIGearDisplay = gear as FGUIGearDisplay
	if display_gear != null and display_gear.controller != null:
		var token: int = display_gear.add_lock()
		check_gear_display()
		return token
	return 0


func release_display_lock(token: int) -> void:
	var gear: FGUIGearBase = _gears.get(0)
	var display_gear: FGUIGearDisplay = gear as FGUIGearDisplay
	if token != 0 and display_gear != null and display_gear.controller != null:
		display_gear.release_lock(token)
		check_gear_display()


func handle_controller_changed(controller: FGUIController) -> void:
	_handling_controller = true
	for gear in _gears.values():
		if gear.controller == controller:
			gear.apply()
	_handling_controller = false
	check_gear_display()


func check_gear_display() -> void:
	if _handling_controller:
		return
	var visible_by_gear := true
	var display_gear: FGUIGearBase = _gears.get(0)
	if display_gear is FGUIGearDisplay:
		visible_by_gear = (display_gear as FGUIGearDisplay).connected
	var display_gear2: FGUIGearBase = _gears.get(8)
	if display_gear2 is FGUIGearDisplay2:
		visible_by_gear = (display_gear2 as FGUIGearDisplay2).evaluate(visible_by_gear)
	if _internal_visible != visible_by_gear:
		_internal_visible = visible_by_gear
		_handle_visible_changed()
		if _group is FGUIGroup and _group.exclude_invisibles:
			_group.set_bounds_changed_flag()


func global_to_local(point: Vector2) -> Vector2:
	var local := _global_to_node_local(point)
	if _pivot_as_anchor:
		local -= Vector2(_width * _pivot.x, _height * _pivot.y)
	return local


func local_to_global(point: Vector2) -> Vector2:
	var local := point
	if _pivot_as_anchor:
		local += Vector2(_width * _pivot.x, _height * _pivot.y)
	return node.get_global_transform() * local if node != null else local


func local_to_global_rect(rect: Rect2) -> Rect2:
	var start := local_to_global(rect.position)
	var end := local_to_global(rect.end)
	return Rect2(start, end - start).abs()


func global_to_local_rect(rect: Rect2) -> Rect2:
	var start := global_to_local(rect.position)
	var end := global_to_local(rect.end)
	return Rect2(start, end - start).abs()


func transform_point(point: Vector2, target_space: FGUIObject) -> Vector2:
	return target_space.global_to_local(local_to_global(point)) if target_space != null else point


func transform_rect(rect: Rect2, target_space: FGUIObject) -> Rect2:
	return target_space.global_to_local_rect(local_to_global_rect(rect)) if target_space != null else rect


func local_to_root(point: Vector2) -> Vector2:
	var root_object := root
	return transform_point(point, root_object) if root_object != null else point


func root_to_local(point: Vector2) -> Vector2:
	var root_object := root
	return root_object.transform_point(point, self) if root_object != null else point


func request_focus() -> void:
	var root_object := root
	if root_object != null:
		root_object.focus = self


func hit_test(view_point: Vector2, force_test: bool = false) -> FGUIObject:
	if node == null or (not force_test and (not touchable or not internal_visible2)):
		return null
	var local_point := _global_to_node_local(view_point)
	if local_point.x < 0.0 or local_point.y < 0.0 or local_point.x > width or local_point.y > height:
		return null
	if pixel_hit_test != null and not pixel_hit_test.contains(local_point.x, local_point.y):
		return null
	return self


func _global_to_node_local(point: Vector2) -> Vector2:
	return node.get_global_transform().affine_inverse() * point if node != null else point


func on(event_name: String, callable: Callable) -> void:
	if not _event_listeners.has(event_name):
		_event_listeners[event_name] = []
	_event_listeners[event_name].append(callable)


func off(event_name: String, callable: Callable) -> void:
	if not _event_listeners.has(event_name):
		return
	_event_listeners[event_name].erase(callable)


func emit_event(event_name: String, payload: Variant = null) -> void:
	if not _event_listeners.has(event_name):
		return
	for callable: Callable in _event_listeners[event_name].duplicate():
		if callable.is_valid():
			if payload == null:
				callable.call()
			else:
				callable.call(payload)


func on_click(callable: Callable) -> void:
	on("click", callable)


func off_click(callable: Callable) -> void:
	off("click", callable)


func has_click_listener() -> bool:
	return _event_listeners.has("click") and not _event_listeners["click"].is_empty()


func has_event_listener(event_name: String) -> bool:
	return _event_listeners.has(event_name) and not _event_listeners[event_name].is_empty()


static func get_last_pointer_position() -> Vector2:
	return _last_pointer_position if _has_last_pointer_position else Vector2.ZERO


func start_drag(touch_point_id: int = -1) -> void:
	if node == null or not node.is_inside_tree() or dragging_object == self:
		return
	_drag_testing = false
	_drag_start_cancelled = false
	_drag_click_suppressed = true
	_drag_pointer_active = true
	_begin_drag(get_last_pointer_position(), touch_point_id)


func stop_drag() -> void:
	if dragging_object == self:
		_end_drag(null, false)
	else:
		_drag_testing = false
		_drag_start_cancelled = true
		_drag_click_suppressed = true
		_drag_pointer_active = false
		_drag_touch_index = -1


func remove_from_parent() -> void:
	if parent != null:
		parent.remove_child(self)


func dispose() -> void:
	if is_disposed:
		return
	stop_drag()
	remove_from_parent()
	if relations != null:
		relations.dispose()
		relations = null
	for gear: FGUIGearBase in _gears.values():
		gear.dispose()
	_gears.clear()
	_event_listeners.clear()
	_group = null
	pixel_hit_test = null
	package_item = null
	data = null
	if node != null:
		node.remove_meta("fgui_owner")
		if node.is_inside_tree():
			node.queue_free()
		else:
			node.free()
		node = null


func _create_display_object() -> void:
	node = Control.new()
	node.mouse_filter = Control.MOUSE_FILTER_PASS


func _handle_xy_changed() -> void:
	if node != null:
		var next_pos := Vector2(_x, _y)
		if _pivot_as_anchor:
			next_pos -= Vector2(_width * _pivot.x, _height * _pivot.y)
		node.position = next_pos
	emit_event(FGUIEvents.XY_CHANGED)


func _handle_size_changed() -> void:
	if node != null:
		node.size = Vector2(_width, _height)
		node.pivot_offset = Vector2(_width * _pivot.x, _height * _pivot.y)
	if pixel_hit_test != null:
		if source_width > 0.0:
			pixel_hit_test.scale_x = _width / source_width
		if source_height > 0.0:
			pixel_hit_test.scale_y = _height / source_height


func _handle_alpha_changed() -> void:
	if node != null:
		var color := node.modulate
		color.a = _alpha
		node.modulate = color


func _handle_visible_changed() -> void:
	if node != null:
		node.visible = internal_visible2 and not bool(node.get_meta("fgui_mask_hidden", false))


func _handle_touchable_changed() -> void:
	if node != null:
		node.mouse_filter = Control.MOUSE_FILTER_PASS if _touchable else Control.MOUSE_FILTER_IGNORE


func _handle_grayed_changed() -> void:
	if node != null:
		FGUIToolSet.set_color_filter(node, _grayed)


func _on_gui_input(event: InputEvent) -> void:
	if not _touchable:
		return
	var pointer_position := FGUIToolSet.get_pointer_position(event)
	if FGUIToolSet.is_pointer_event(event):
		_last_pointer_position = pointer_position
		_has_last_pointer_position = true
	if FGUIToolSet.is_pointer_event(event) and pixel_hit_test != null:
		var hit_position := _global_to_node_local(pointer_position)
		if not pixel_hit_test.contains(hit_position.x, hit_position.y):
			return
	if FGUIToolSet.is_primary_pointer_press(event):
		_drag_touch_index = FGUIToolSet.get_pointer_id(event)
		_drag_start_mouse = pointer_position
		_drag_start_position = node.get_global_rect().position if node != null else Vector2.ZERO
		_drag_start_size = node.get_global_rect().size if node != null else Vector2.ZERO
		_drag_testing = draggable
		_drag_start_cancelled = false
		_drag_click_suppressed = false
		_drag_pointer_active = true
		return
	if FGUIToolSet.is_primary_pointer_release(event) and not _drag_pointer_active:
		if not _drag_click_suppressed:
			emit_event("click", event)
		return
	if not _drag_pointer_active or not _matches_drag_pointer(event):
		return
	if FGUIToolSet.is_primary_pointer_release(event):
		if dragging_object == self:
			_end_drag(event, true)
		else:
			_drag_testing = false
			_drag_pointer_active = false
			_drag_touch_index = -1
			if not _drag_click_suppressed:
				emit_event("click", event)
		return
	if not FGUIToolSet.is_pointer_motion(event):
		return
	if dragging_object == self:
		if _drag_input_relay == null:
			_update_drag_position(event)
		return
	if not draggable or not _drag_testing:
		return
	var sensitivity := _get_drag_sensitivity(event)
	var delta := pointer_position - _drag_start_mouse
	if absf(delta.x) < sensitivity and absf(delta.y) < sensitivity:
		return
	_drag_testing = false
	_drag_click_suppressed = true
	var previous_dragging := dragging_object
	emit_event(FGUIEvents.DRAG_START, event)
	if _drag_start_cancelled or not draggable:
		return
	if dragging_object != null and dragging_object != previous_dragging:
		return
	_begin_drag(pointer_position, _drag_touch_index, true)
	if dragging_object == self:
		_update_drag_position(event)


func _on_global_drag_input(event: InputEvent) -> void:
	if dragging_object != self or not _matches_drag_pointer(event):
		return
	if FGUIToolSet.is_pointer_event(event):
		_last_pointer_position = FGUIToolSet.get_pointer_position(event)
		_has_last_pointer_position = true
	if FGUIToolSet.is_primary_pointer_release(event):
		_end_drag(event, true)
	elif FGUIToolSet.is_pointer_motion(event):
		_update_drag_position(event)


func _begin_drag(pointer_position: Vector2, touch_point_id: int, preserve_pointer_origin: bool = false) -> void:
	if node == null:
		return
	if dragging_object != null and dragging_object != self:
		dragging_object._end_drag(null, true)
	var global_rect := node.get_global_rect()
	if not preserve_pointer_origin:
		_drag_start_mouse = pointer_position
		_drag_start_position = global_rect.position
		_drag_start_size = global_rect.size
	_drag_touch_index = touch_point_id
	_drag_pointer_active = true
	_dragging = true
	dragging_object = self
	_install_drag_input_relay()


func _end_drag(event: Variant, notify: bool) -> void:
	var was_dragging := dragging_object == self
	if was_dragging:
		dragging_object = null
	_dragging = false
	_drag_testing = false
	_drag_pointer_active = false
	_drag_touch_index = -1
	_remove_drag_input_relay()
	if notify and was_dragging:
		emit_event(FGUIEvents.DRAG_END, event)


func _update_drag_position(event: InputEvent) -> void:
	if node == null or not FGUIToolSet.is_pointer_event(event):
		return
	var pointer_position := FGUIToolSet.get_pointer_position(event)
	var next_global_position := _drag_start_position + pointer_position - _drag_start_mouse
	if _drag_bounds is Rect2:
		var bounds := _get_drag_bounds_global(_drag_bounds as Rect2)
		next_global_position.x = clampf(next_global_position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - _drag_start_size.x))
		next_global_position.y = clampf(next_global_position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - _drag_start_size.y))
	var native_parent := node.get_parent() as Control
	var next_local_position := native_parent.get_global_transform().affine_inverse() * next_global_position if native_parent != null else next_global_position
	if _pivot_as_anchor:
		next_local_position += Vector2(_width * _pivot.x, _height * _pivot.y)
	set_xy(roundf(next_local_position.x), roundf(next_local_position.y))
	emit_event(FGUIEvents.DRAG_MOVE, event)


func _get_drag_bounds_global(bounds: Rect2) -> Rect2:
	var root_object := root
	if root_object == null or root_object.node == null:
		return bounds
	var start := root_object.local_to_global(bounds.position)
	var end := root_object.local_to_global(bounds.end)
	return Rect2(start, end - start).abs()


func _get_drag_sensitivity(event: InputEvent) -> float:
	return maxf(0.0, FGUIConfig.touch_drag_sensitivity if event is InputEventScreenDrag else FGUIConfig.click_drag_sensitivity)


func _matches_drag_pointer(event: InputEvent) -> bool:
	return _drag_touch_index == FGUIToolSet.get_pointer_id(event)


func _install_drag_input_relay() -> void:
	_remove_drag_input_relay()
	if node == null or not node.is_inside_tree():
		return
	var tree := node.get_tree()
	if tree == null or tree.root == null:
		return
	var relay: Node = DragInputRelay.new()
	relay.target = self
	tree.root.add_child(relay)
	_drag_input_relay = relay


func _remove_drag_input_relay() -> void:
	if _drag_input_relay == null:
		return
	if is_instance_valid(_drag_input_relay):
		_drag_input_relay.queue_free()
	_drag_input_relay = null


func _on_mouse_entered() -> void:
	if _tooltips == "" or FGUIConfig.tooltips_win == "":
		return
	var root_object := root
	if root_object != null:
		root_object.show_tooltips(_tooltips)


func _on_mouse_exited() -> void:
	if FGUIConfig.tooltips_win == "":
		return
	var root_object := root
	if root_object != null:
		root_object.hide_tooltips()


func _string_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)
