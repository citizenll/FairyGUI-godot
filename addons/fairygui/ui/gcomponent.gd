class_name FGUIComponent
extends FGUIObject

var children: Array = []
var controllers: Array = []
var transitions: Array = []
var margin: FGUIMargin = FGUIMargin.new()
var opaque: bool = false
var track_bounds: bool = false
var children_render_order: int = FGUIEnums.CHILDREN_RENDER_ASCENT
var apex_index: int = 0
var scroll_pane: FGUIScrollPane
var hit_test_child: FGUIObject
var _mask: FGUIObject
var _reversed_mask: bool = false
var mask: FGUIObject:
	get:
		return _mask
	set(value):
		set_mask(value, _reversed_mask)
var reversed_mask: bool:
	get:
		return _reversed_mask
	set(value):
		set_mask(_mask, value)

var _building_display_list: bool = false
var _bounds_changed: bool = false
var _content_node: Control

var num_children: int:
	get:
		return children.size()
var view_width: float:
	get:
		return scroll_pane.view_width if scroll_pane != null else width - margin.left - margin.right
	set(value):
		if scroll_pane != null:
			scroll_pane.view_width = value
		else:
			width = value + margin.left + margin.right
var view_height: float:
	get:
		return scroll_pane.view_height if scroll_pane != null else height - margin.top - margin.bottom
	set(value):
		if scroll_pane != null:
			scroll_pane.view_height = value
		else:
			height = value + margin.top + margin.bottom


func add_child(child: FGUIObject) -> FGUIObject:
	return add_child_at(child, children.size())


func _create_display_object() -> void:
	node = FGUIMaskContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_PASS


func dispose() -> void:
	set_mask(null)
	hit_test_child = null
	for transition: FGUITransition in transitions:
		transition.dispose()
	transitions.clear()
	for controller: FGUIController in controllers:
		controller.parent = null
		controller.actions.clear()
	controllers.clear()
	for child: FGUIObject in children.duplicate():
		child.dispose()
	children.clear()
	if scroll_pane != null:
		scroll_pane.dispose()
		scroll_pane = null
	_content_node = null
	super.dispose()


func add_child_at(child: FGUIObject, index: int) -> FGUIObject:
	if child == null:
		push_error("FairyGUI child is null.")
		return null
	index = clampi(index, 0, children.size())
	if child.parent != null:
		child.parent.remove_child(child)
	child.parent = self
	children.insert(index, child)
	_add_child_node(child, index)
	return child


func remove_child(child: FGUIObject, dispose_child: bool = false) -> FGUIObject:
	var index := children.find(child)
	if index == -1:
		return child
	if child == _mask:
		set_mask(null)
	children.remove_at(index)
	if child == hit_test_child:
		hit_test_child = null
	var container := _get_content_node()
	if child.node != null and child.node.get_parent() == container:
		FGUIToolSet.detach_color_filter(child.node, node)
		container.remove_child(child.node)
	child.parent = null
	if dispose_child:
		child.dispose()
	return child


func remove_child_at(index: int, dispose_child: bool = false) -> FGUIObject:
	var child := get_child_at(index)
	if child == null:
		return null
	return remove_child(child, dispose_child)


func remove_children(begin_index: int = 0, end_index: int = -1, dispose_child: bool = false) -> void:
	if end_index < 0 or end_index >= children.size():
		end_index = children.size() - 1
	for i in range(begin_index, end_index + 1):
		remove_child_at(begin_index, dispose_child)


func get_child_index(child: FGUIObject) -> int:
	return children.find(child)


func set_child_index(child: FGUIObject, index: int) -> void:
	var old_index := children.find(child)
	if old_index == -1:
		return
	children.remove_at(old_index)
	index = clampi(index, 0, children.size())
	children.insert(index, child)
	_rebuild_native_display_list()


func get_child_at(index: int) -> FGUIObject:
	if index < 0 or index >= children.size():
		return null
	return children[index]


func get_child(child_name: String) -> FGUIObject:
	for child in children:
		if child.name == child_name:
			return child
	return null


func get_child_by_id(child_id: String) -> FGUIObject:
	for child in children:
		if child.id == child_id:
			return child
	return null


func get_child_by_path(path: String) -> FGUIObject:
	var parts := path.split(".")
	var current: FGUIComponent = self
	var result: FGUIObject = null
	for i in parts.size():
		result = current.get_child(parts[i])
		if result == null:
			return null
		if i < parts.size() - 1:
			if result is FGUIComponent:
				current = result
			else:
				return null
	return result


func get_controller_at(index: int) -> FGUIController:
	if index < 0 or index >= controllers.size():
		return null
	return controllers[index]


func get_controller(controller_name: String) -> FGUIController:
	for controller in controllers:
		if controller.name == controller_name:
			return controller
	return null


func add_controller(controller: FGUIController) -> void:
	if controller == null:
		return
	controller.parent = self
	controllers.append(controller)
	apply_controller(controller)


func get_transition(transition_name: String) -> FGUITransition:
	for transition in transitions:
		if transition.name == transition_name:
			return transition
	return null


func get_transition_at(index: int) -> FGUITransition:
	if index < 0 or index >= transitions.size():
		return null
	return transitions[index]


func apply_controller(controller: FGUIController) -> void:
	for child in children:
		child.handle_controller_changed(controller)
	controller.run_actions()


func handle_controller_changed(controller: FGUIController) -> void:
	super.handle_controller_changed(controller)
	if scroll_pane != null:
		scroll_pane.handle_controller_changed(controller)


func apply_all_controllers() -> void:
	for controller in controllers:
		apply_controller(controller)


func ensure_bounds_correct() -> void:
	if _bounds_changed:
		update_bounds()


func ensure_size_correct() -> void:
	ensure_bounds_correct()


func get_snapping_position(x_value: float, y_value: float) -> Vector2:
	return get_snapping_position_with_dir(x_value, y_value, 0, 0)


func get_snapping_position_with_dir(x_value: float, y_value: float, _x_dir: int, _y_dir: int) -> Vector2:
	if children.is_empty():
		return Vector2.ZERO
	ensure_bounds_correct()
	return Vector2(_snap_axis_position(x_value, false), _snap_axis_position(y_value, true))


func _snap_axis_position(value: float, vertical: bool) -> float:
	if is_zero_approx(value):
		return value
	var previous: FGUIObject = null
	for child: FGUIObject in children:
		var position := child.y if vertical else child.x
		if value < position:
			if previous == null:
				return 0.0
			var previous_position := previous.y if vertical else previous.x
			var previous_size := previous.actual_height if vertical else previous.actual_width
			return previous_position if value < previous_position + previous_size * 0.5 else position
		previous = child
	if previous == null:
		return 0.0
	return previous.y if vertical else previous.x


func set_bounds_changed_flag() -> void:
	_bounds_changed = true


func update_bounds() -> void:
	_bounds_changed = false
	if children.is_empty():
		return
	var max_pos := Vector2.ZERO
	for child in children:
		max_pos.x = maxf(max_pos.x, child.x + child.width * absf(child._scale.x))
		max_pos.y = maxf(max_pos.y, child.y + child.height * absf(child._scale.y))
	if scroll_pane != null:
		scroll_pane.set_content_size(max_pos.x, max_pos.y)


func child_sorting_order_changed(_child: FGUIObject) -> void:
	children.sort_custom(func(a: FGUIObject, b: FGUIObject) -> bool:
		return a.sorting_order < b.sorting_order
	)
	_rebuild_native_display_list()


func construct_from_resource() -> void:
	construct_from_resource2([], 0)


func construct_from_resource2(object_pool: Array = [], pool_index: int = 0) -> void:
	if package_item == null:
		return
	var content_item := package_item.get_branch()
	var buffer: FGUIByteBuffer = content_item.raw_data
	if buffer == null:
		return

	buffer.seek(0, 0)
	_under_construct = true
	source_width = buffer.read_i32()
	source_height = buffer.read_i32()
	init_width = source_width
	init_height = source_height
	set_size(source_width, source_height)

	if buffer.read_bool():
		min_width = buffer.read_i32()
		max_width = buffer.read_i32()
		min_height = buffer.read_i32()
		max_height = buffer.read_i32()

	if buffer.read_bool():
		set_pivot(buffer.read_float32(), buffer.read_float32(), buffer.read_bool())

	if buffer.read_bool():
		margin.top = buffer.read_i32()
		margin.bottom = buffer.read_i32()
		margin.left = buffer.read_i32()
		margin.right = buffer.read_i32()

	var overflow := buffer.read_i8()
	if overflow == FGUIEnums.OVERFLOW_HIDDEN and node != null:
		node.clip_contents = true
	elif overflow == FGUIEnums.OVERFLOW_SCROLL:
		var saved_pos := buffer.pos
		if node != null:
			node.clip_contents = true
		if buffer.seek(0, 7):
			setup_scroll(buffer)
		buffer.pos = saved_pos
	else:
		setup_overflow(overflow)

	if buffer.read_bool():
		buffer.skip(8)

	_building_display_list = true
	_setup_controllers(buffer)
	_setup_children(buffer, content_item, object_pool, pool_index)
	_setup_component_relations(buffer)
	_setup_children_relations(buffer)
	_setup_children_after_add(buffer)
	_setup_component_metadata(buffer, content_item)
	_setup_transitions(buffer)
	if content_item.object_type != FGUIEnums.OBJECT_COMPONENT:
		construct_extension(buffer)

	_building_display_list = false
	_under_construct = false
	_rebuild_native_display_list()
	apply_all_controllers()


func construct_extension(_buffer: FGUIByteBuffer) -> void:
	pass


func setup_after_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_after_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 4):
		return

	var page_controller_index := buffer.read_i16()
	if page_controller_index >= 0 and scroll_pane != null and parent != null:
		scroll_pane.page_controller = parent.get_controller_at(page_controller_index)
	var count := buffer.read_i16()
	for i in count:
		var controller_name = buffer.read_s()
		var page_id = buffer.read_s()
		for controller in controllers:
			if controller.name == controller_name:
				controller.selected_page_id = page_id

	if buffer.version >= 2:
		count = buffer.read_i16()
		for i in count:
			var target := _string_or_empty(buffer.read_s())
			var property_id := buffer.read_i16()
			var value = buffer.read_s()
			var obj := get_child_by_path(target)
			if obj != null:
				obj.set_prop(property_id, value)


func _setup_controllers(buffer: FGUIByteBuffer) -> void:
	if not buffer.seek(0, 1):
		return
	var count := buffer.read_i16()
	for i in count:
		var next_pos := buffer.read_i16() + buffer.pos
		var controller := FGUIController.new()
		controller.parent = self
		controller.setup(buffer)
		controllers.append(controller)
		buffer.pos = next_pos


func _setup_children(buffer: FGUIByteBuffer, content_item: FGUIPackageItem, object_pool: Array = [], pool_index: int = 0) -> void:
	if not buffer.seek(0, 2):
		return
	var count := buffer.read_i16()
	for i in count:
		var data_len := buffer.read_i16()
		var cur_pos := buffer.pos
		var child: FGUIObject = null
		var pooled_index := pool_index + i
		if pooled_index >= 0 and pooled_index < object_pool.size():
			child = object_pool[pooled_index]
		else:
			buffer.seek(cur_pos, 0)
			var object_type := buffer.read_i8()
			var src = buffer.read_s()
			var pkg_id = buffer.read_s()

			var item: FGUIPackageItem = null
			if src != null:
				var pkg: FGUIPackage = FGUIPackage.get_by_id(pkg_id) if pkg_id != null else content_item.owner
				if pkg != null:
					item = pkg.get_item_by_id(src)

			child = FGUIObjectFactory.new_object_from_item(item) if item != null else FGUIObjectFactory.new_object(object_type)
			if item != null and child != null:
				child.construct_from_resource()
		if child == null:
			child = FGUIObject.new()

		child._under_construct = true
		child.setup_before_add(buffer, cur_pos)
		child.parent = self
		children.append(child)
		buffer.pos = cur_pos + data_len


func _setup_component_relations(buffer: FGUIByteBuffer) -> void:
	if buffer.seek(0, 3):
		relations.setup(buffer, true)


func _setup_children_relations(buffer: FGUIByteBuffer) -> void:
	if not buffer.seek(0, 2):
		return
	buffer.skip(2)
	for child in children:
		var next_pos := buffer.read_i16() + buffer.pos
		if buffer.seek(buffer.pos, 3):
			child.relations.setup(buffer, false)
		buffer.pos = next_pos


func _setup_children_after_add(buffer: FGUIByteBuffer) -> void:
	if not buffer.seek(0, 2):
		return
	buffer.skip(2)
	for child in children:
		var next_pos := buffer.read_i16() + buffer.pos
		child.setup_after_add(buffer, buffer.pos)
		child._under_construct = false
		buffer.pos = next_pos


func _setup_component_metadata(buffer: FGUIByteBuffer, content_item: FGUIPackageItem) -> void:
	if not buffer.seek(0, 4):
		return
	buffer.skip(2)
	opaque = buffer.read_bool()
	var mask_id := buffer.read_i16()
	if mask_id != -1:
		set_mask(get_child_at(mask_id), buffer.read_bool())
	var hit_test_id = buffer.read_s()
	var hit_offset_x := buffer.read_i32()
	var child_hit_index := buffer.read_i32()
	if hit_test_id != null:
		var hit_item: FGUIPackageItem = content_item.owner.get_item_by_id(hit_test_id)
		if hit_item != null and hit_item.pixel_hit_test_data != null:
			pixel_hit_test = FGUIPixelHitTest.new(hit_item.pixel_hit_test_data, hit_offset_x, child_hit_index)
			if source_width > 0.0:
				pixel_hit_test.scale_x = width / source_width
			if source_height > 0.0:
				pixel_hit_test.scale_y = height / source_height
	elif hit_offset_x != 0 and child_hit_index != -1:
		hit_test_child = get_child_at(child_hit_index)


func _setup_transitions(buffer: FGUIByteBuffer) -> void:
	if not buffer.seek(0, 5):
		return
	var count := buffer.read_i16()
	for i in count:
		var next_pos := buffer.read_i16() + buffer.pos
		var transition := FGUITransition.new(self)
		transition.setup(buffer)
		transitions.append(transition)
		buffer.pos = next_pos


func _skip_relation_block(buffer: FGUIByteBuffer) -> void:
	var count := buffer.read_i16()
	for i in count:
		var next_pos := buffer.read_i16() + buffer.pos
		buffer.pos = next_pos


func _add_child_node(child: FGUIObject, index: int) -> void:
	var container := _get_content_node()
	if container == null or child == null or child.node == null:
		return
	container.add_child(child.node)
	if index >= 0 and index < container.get_child_count():
		container.move_child(child.node, index)
	FGUIToolSet.refresh_color_filter(node, true)


func _on_gui_input(event: InputEvent) -> void:
	var pointer_position := FGUIToolSet.get_pointer_position(event)
	if FGUIToolSet.is_pointer_event(event) and hit_test_child != null and not _contains_hit_test_child(pointer_position):
		return
	if FGUIToolSet.is_pointer_event(event) and _mask != null:
		var is_in_mask := _contains_mask(pointer_position)
		if (not _reversed_mask and not is_in_mask) or (_reversed_mask and is_in_mask):
			return
	super._on_gui_input(event)


func _contains_hit_test_child(global_position: Vector2) -> bool:
	var child := hit_test_child
	if child == null or child.node == null or not child.visible:
		return false
	var local_position := child.global_to_local(global_position)
	if child.pixel_hit_test != null:
		return child.pixel_hit_test.contains(local_position.x, local_position.y)
	return Rect2(Vector2.ZERO, Vector2(child.width, child.height)).has_point(local_position)


func set_mask(value: FGUIObject, reversed: bool = false) -> void:
	if _mask == value and _reversed_mask == reversed:
		return
	if _mask != null:
		_mask.off(FGUIEvents.XY_CHANGED, Callable(self, "_refresh_mask"))
		_mask.off(FGUIEvents.SIZE_CHANGED, Callable(self, "_refresh_mask"))
	_mask = value
	_reversed_mask = reversed
	if _mask != null:
		_mask.on(FGUIEvents.XY_CHANGED, Callable(self, "_refresh_mask"))
		_mask.on(FGUIEvents.SIZE_CHANGED, Callable(self, "_refresh_mask"))
	if node is FGUIMaskContainer:
		(node as FGUIMaskContainer).set_mask(_mask, _reversed_mask)


func _refresh_mask(_event: Variant = null) -> void:
	if node is FGUIMaskContainer:
		(node as FGUIMaskContainer).refresh_mask()


func _contains_mask(global_position: Vector2) -> bool:
	if _mask == null or _mask.node == null or not _mask.visible:
		return false
	var local_position := _mask.global_to_local(global_position)
	if _mask.pixel_hit_test != null:
		return _mask.pixel_hit_test.contains(local_position.x, local_position.y)
	return Rect2(Vector2.ZERO, Vector2(_mask.width, _mask.height)).has_point(local_position)


func _rebuild_native_display_list() -> void:
	var container := _get_content_node()
	if container == null:
		return
	for child in children:
		if child.node != null and child.node.get_parent() != container:
			container.add_child(child.node)


func _get_content_node() -> Control:
	return _content_node if _content_node != null else node


func setup_scroll(buffer: FGUIByteBuffer) -> void:
	if scroll_pane == null:
		scroll_pane = FGUIScrollPane.new(self)
	scroll_pane.setup(buffer)
	_content_node = scroll_pane.content


func _handle_size_changed() -> void:
	super._handle_size_changed()
	if scroll_pane != null:
		scroll_pane.on_owner_size_changed()


func setup_overflow(_overflow: int) -> void:
	if margin.left == 0 and margin.top == 0:
		return
	if _content_node == null:
		_content_node = Control.new()
		_content_node.mouse_filter = Control.MOUSE_FILTER_PASS
		node.add_child(_content_node)
	_content_node.position = Vector2(margin.left, margin.top)
