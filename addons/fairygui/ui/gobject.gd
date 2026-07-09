class_name FGUIObject
extends RefCounted

static var _instance_counter: int = 0

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
var _dragging: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_position: Vector2 = Vector2.ZERO
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


func set_xy(new_x: float, new_y: float) -> void:
	if is_equal_approx(_x, new_x) and is_equal_approx(_y, new_y):
		return
	_x = new_x
	_y = new_y
	_handle_xy_changed()
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
		buffer.skip(16)
	var user_data = buffer.read_s()
	if user_data != null:
		data = user_data


func setup_after_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	if buffer.seek(begin_pos, 1):
		var tips = buffer.read_s()
		if tips != null:
			_tooltips = tips
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


func handle_controller_changed(controller: FGUIController) -> void:
	for gear in _gears.values():
		if gear.controller == controller:
			gear.apply()
	check_gear_display()


func check_gear_display() -> void:
	var visible_by_gear := true
	var gear: FGUIGearBase = _gears.get(0)
	if gear is FGUIGearDisplay:
		visible_by_gear = gear.connected
	_internal_visible = visible_by_gear
	_handle_visible_changed()


func global_to_local(point: Vector2) -> Vector2:
	return node.get_global_transform().affine_inverse() * point if node != null else point


func local_to_global(point: Vector2) -> Vector2:
	return node.get_global_transform() * point if node != null else point


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


func remove_from_parent() -> void:
	if parent != null:
		parent.remove_child(self)


func dispose() -> void:
	remove_from_parent()
	relations.dispose()
	if node != null:
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
		node.visible = _visible and _internal_visible


func _handle_touchable_changed() -> void:
	if node != null:
		node.mouse_filter = Control.MOUSE_FILTER_PASS if _touchable else Control.MOUSE_FILTER_IGNORE


func _handle_grayed_changed() -> void:
	if node != null:
		FGUIToolSet.set_color_filter(node, _grayed)


func _on_gui_input(event: InputEvent) -> void:
	if not _touchable:
		return
	if event is InputEventMouse and pixel_hit_test != null and not pixel_hit_test.contains(event.position.x, event.position.y):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_start_mouse = event.global_position
			_drag_start_position = node.global_position if node != null else Vector2.ZERO
			if draggable:
				_dragging = true
				emit_event(FGUIEvents.DRAG_START, event)
		else:
			if _dragging:
				_dragging = false
				emit_event(FGUIEvents.DRAG_END, event)
			else:
				emit_event("click", event)
	elif event is InputEventMouseMotion and _dragging and draggable and node != null:
		var delta: Vector2 = event.global_position - _drag_start_mouse
		node.global_position = _drag_start_position + delta
		_x = node.position.x
		_y = node.position.y
		emit_event(FGUIEvents.DRAG_MOVE, event)


func _string_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)
