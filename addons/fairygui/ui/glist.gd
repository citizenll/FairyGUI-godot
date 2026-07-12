class_name FGUIList
extends FGUIComponent

const VIRTUAL_SIZE_CHUNK_SIZE := 256
const VIRTUAL_PHYSICAL_INDEX_META := &"_fgui_virtual_physical_index"
const VIRTUAL_ITEM_URL_META := &"_fgui_virtual_item_url"

var item_renderer: Callable
var item_provider: Callable
var scroll_item_to_view_on_click: bool = true
var fold_invisible_items: bool = false
var layout: int = FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN:
	set(value):
		layout = value
		_virtual_size_layout_dirty = true
		set_bounds_changed_flag()
var line_count: int = 0:
	set(value):
		if line_count == value:
			return
		line_count = value
		if layout == FGUIEnums.LIST_LAYOUT_FLOW_VERTICAL or layout == FGUIEnums.LIST_LAYOUT_PAGINATION:
			_request_layout_refresh()
var column_count: int = 0:
	set(value):
		if column_count == value:
			return
		column_count = value
		if layout == FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL or layout == FGUIEnums.LIST_LAYOUT_PAGINATION:
			_request_layout_refresh()
var line_gap: int = 0:
	set(value):
		if line_gap == value:
			return
		line_gap = value
		_request_layout_refresh()
var column_gap: int = 0:
	set(value):
		if column_gap == value:
			return
		column_gap = value
		_request_layout_refresh()
var align: int = FGUIEnums.ALIGN_LEFT:
	set(value):
		align = clampi(value, FGUIEnums.ALIGN_LEFT, FGUIEnums.ALIGN_RIGHT)
		_request_layout_refresh()
var vertical_align: int = FGUIEnums.VERT_ALIGN_TOP:
	set(value):
		vertical_align = clampi(value, FGUIEnums.VERT_ALIGN_TOP, FGUIEnums.VERT_ALIGN_BOTTOM)
		_request_layout_refresh()
var default_item: String = "":
	set(value):
		default_item = FGUIPackage.normalize_url(value)
var auto_resize_item: bool = true:
	set(value):
		if auto_resize_item == value:
			return
		auto_resize_item = value
		_request_layout_refresh()
var selection_mode: int = FGUIEnums.LIST_SELECTION_SINGLE
var selection_controller: FGUIController
var item_pool := FGUIObjectPool.new()

var _virtual: bool = false
var _loop: bool = false
var _num_items: int = 0
var _selected_indices: Array[int] = []
var _last_selected_index: int = -1
var _virtual_item_size: Vector2 = Vector2.ZERO
var _virtual_item_size_overrides: Dictionary = {}
var _virtual_chunk_primary_deltas: Dictionary = {}
var _virtual_chunk_item_indices: Dictionary = {}
var _virtual_changed_chunks: Array[int] = []
var _virtual_changed_chunk_prefix: Array[float] = []
var _virtual_primary_total: float = 0.0
var _virtual_cross_size: float = 0.0
var _virtual_size_layout_dirty: bool = true
var _virtual_size_refresh_queued: bool = false
var _virtual_size_content_refresh_pending: bool = false
var _virtual_pending_primary_shift: float = 0.0
var _virtual_first_index: int = 0
var _virtual_real_num_items: int = 0
var _virtual_loop_position_initialized: bool = false
var _refreshing_virtual: bool = false
var _align_offset := Vector2.ZERO

var virtual_item_size: Vector2:
	get:
		return _virtual_item_size
	set(value):
		if not _virtual:
			return
		var next_size := Vector2(maxf(1.0, value.x), maxf(1.0, value.y))
		if _virtual_item_size.is_equal_approx(next_size):
			return
		_virtual_item_size = next_size
		_clear_virtual_item_size_cache()
		_virtual_size_layout_dirty = true
		_virtual_loop_position_initialized = false
		refresh_virtual_list()

var num_items: int:
	get:
		return _num_items if _virtual else children.size()
	set(value):
		if _virtual:
			var next_count := max(0, value)
			if next_count != _num_items:
				_num_items = next_count
				_trim_virtual_item_size_cache()
				_virtual_real_num_items = _num_items * 6 if _loop else _num_items
				_virtual_loop_position_initialized = false
				_virtual_size_layout_dirty = true
				for index in _selected_indices.duplicate():
					if index >= _num_items:
						_selected_indices.erase(index)
			refresh_virtual_list()
		else:
			var target := max(0, value)
			while children.size() < target:
				add_item_from_pool()
			while children.size() > target:
				remove_child_to_pool_at(children.size() - 1)
var selected_index: int:
	get:
		return _selected_indices[0] if not _selected_indices.is_empty() else -1
	set(value):
		clear_selection()
		if value >= 0:
			add_selection(value, false)


func _init() -> void:
	super._init()
	track_bounds = true
	opaque = true


func dispose() -> void:
	item_renderer = Callable()
	item_provider = Callable()
	selection_controller = null
	item_pool.clear()
	super.dispose()


func _handle_size_changed() -> void:
	super._handle_size_changed()
	_request_layout_refresh()


func add_child_at(child: FGUIObject, index: int) -> FGUIObject:
	var added := super.add_child_at(child, index)
	if added is FGUIButton:
		added.selected = false
		added.change_state_on_click = false
	added.on("click", Callable(self, "_click_item").bind(added))
	added.on(FGUIEvents.RIGHT_CLICK, Callable(self, "_right_click_item").bind(added))
	return added


func add_item(url: Variant = null) -> FGUIObject:
	var obj := FGUIPackage.create_object_from_url(_resolve_item_url(url))
	return add_child(obj) if obj != null else null


func add_item_from_pool(url: Variant = null) -> FGUIObject:
	var obj := get_from_pool(_resolve_item_url(url))
	return add_child(obj) if obj != null else null


func get_from_pool(url: String = "") -> FGUIObject:
	var actual_url := _resolve_item_url(url)
	var obj := item_pool.get_object(actual_url)
	if obj != null:
		obj.visible = true
	return obj


func _resolve_item_url(url: Variant) -> String:
	if url == null:
		return default_item
	var value := str(url)
	if value == "":
		return default_item
	return FGUIPackage.normalize_url(value)


func return_to_pool(obj: FGUIObject) -> void:
	item_pool.return_object(obj)


func remove_child_to_pool_at(index: int) -> void:
	var child := remove_child_at(index)
	return_to_pool(child)


func remove_child_to_pool(child: FGUIObject) -> void:
	remove_child(child)
	return_to_pool(child)


func remove_children_to_pool(begin_index: int = 0, end_index: int = -1) -> void:
	if end_index < 0 or end_index >= children.size():
		end_index = children.size() - 1
	for i in range(begin_index, end_index + 1):
		remove_child_to_pool_at(begin_index)


func get_selection(result: Array[int] = []) -> Array[int]:
	result.append_array(_selected_indices)
	return result


func add_selection(index: int, scroll_it_to_view: bool = false) -> void:
	if selection_mode == FGUIEnums.LIST_SELECTION_NONE or index < 0 or index >= num_items:
		return
	if selection_mode == FGUIEnums.LIST_SELECTION_SINGLE:
		clear_selection()
	if not _selected_indices.has(index):
		_selected_indices.append(index)
	_last_selected_index = index
	if _virtual:
		_set_virtual_selection(index, true)
	else:
		var obj := get_child_at(index)
		if obj is FGUIButton:
			obj.selected = true
	if scroll_it_to_view:
		scroll_to_view(index)
	_update_selection_controller(index)


func remove_selection(index: int) -> void:
	_selected_indices.erase(index)
	if _virtual:
		_set_virtual_selection(index, false)
	else:
		var obj := get_child_at(index) if index >= 0 and index < children.size() else null
		if obj is FGUIButton:
			obj.selected = false


func clear_selection() -> void:
	if _virtual:
		for child: FGUIObject in children:
			if child is FGUIButton:
				child.selected = false
	else:
		for index in _selected_indices.duplicate():
			var obj := get_child_at(index) if index >= 0 and index < children.size() else null
			if obj is FGUIButton:
				obj.selected = false
	_selected_indices.clear()


func select_all() -> void:
	for i in num_items:
		add_selection(i, false)


func select_none() -> void:
	clear_selection()


func select_reverse() -> void:
	if selection_mode == FGUIEnums.LIST_SELECTION_NONE:
		return
	var last_selected := -1
	for index in num_items:
		var selected := not _selected_indices.has(index)
		if selected:
			_selected_indices.append(index)
			last_selected = index
		else:
			_selected_indices.erase(index)
		if _virtual:
			_set_virtual_selection(index, selected)
		else:
			var obj := get_child_at(index)
			if obj is FGUIButton:
				obj.selected = selected
	if last_selected >= 0:
		_last_selected_index = last_selected
		_update_selection_controller(last_selected)


func get_max_item_width() -> float:
	ensure_bounds_correct()
	var result := 0.0
	for child: FGUIObject in children:
		if not fold_invisible_items or child.visible:
			result = maxf(result, child.width)
	return result


func handle_arrow_key(direction: int) -> int:
	var index := selected_index
	if index < 0:
		return -1
	var target_index := -1
	match layout:
		FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN:
			if direction == 1:
				target_index = index - 1
			elif direction == 5:
				target_index = index + 1
		FGUIEnums.LIST_LAYOUT_SINGLE_ROW:
			if direction == 7:
				target_index = index - 1
			elif direction == 3:
				target_index = index + 1
		FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL, FGUIEnums.LIST_LAYOUT_PAGINATION:
			if direction == 7:
				target_index = index - 1
			elif direction == 3:
				target_index = index + 1
			elif direction == 1 or direction == 5:
				if _virtual:
					var columns := _get_virtual_navigation_line_count(true)
					target_index = index + (-columns if direction == 1 else columns)
				else:
					target_index = _find_arrow_neighbor(index, direction, true)
		FGUIEnums.LIST_LAYOUT_FLOW_VERTICAL:
			if direction == 1:
				target_index = index - 1
			elif direction == 5:
				target_index = index + 1
			elif direction == 7 or direction == 3:
				if _virtual:
					var rows := _get_virtual_navigation_line_count(false)
					target_index = index + (-rows if direction == 7 else rows)
				else:
					target_index = _find_arrow_neighbor(index, direction, false)
	if target_index >= 0 and target_index < num_items:
		clear_selection()
		add_selection(target_index, true)
		return target_index
	return -1


func _get_virtual_navigation_line_count(horizontal_flow: bool) -> int:
	_ensure_virtual_item_size()
	var layout_info := _get_virtual_layout_info(maxi(1, _num_items))
	if layout_info.is_empty():
		return 1
	return maxi(1, int(layout_info["columns"] if horizontal_flow else layout_info["rows"]))


func _find_arrow_neighbor(index: int, direction: int, vertical: bool) -> int:
	var current := get_child_at(index)
	if current == null:
		return -1
	var current_primary := current.y if vertical else current.x
	var current_cross := current.x if vertical else current.y
	var negative_direction := direction == 1 or direction == 7
	var best_index := -1
	var best_primary_distance := INF
	var best_cross_distance := INF
	for candidate_index in children.size():
		if candidate_index == index:
			continue
		var candidate: FGUIObject = children[candidate_index]
		var primary := candidate.y if vertical else candidate.x
		if (negative_direction and primary >= current_primary) or (not negative_direction and primary <= current_primary):
			continue
		var primary_distance := absf(primary - current_primary)
		var cross := candidate.x if vertical else candidate.y
		var cross_distance := absf(cross - current_cross)
		if primary_distance < best_primary_distance or (is_equal_approx(primary_distance, best_primary_distance) and cross_distance < best_cross_distance):
			best_index = candidate_index
			best_primary_distance = primary_distance
			best_cross_distance = cross_distance
	return best_index


func resize_to_fit(item_count: int = 0, min_size: int = 0) -> void:
	ensure_bounds_correct()
	var count := num_items if item_count <= 0 else mini(item_count, num_items)
	var resize_height := layout == FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN or layout == FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL
	var next_size := float(min_size)
	if count > 0 and _virtual:
		_ensure_virtual_item_size()
		_ensure_virtual_size_layout()
		if _supports_variable_virtual_primary():
			var last_index := count - 1
			var item_size := _get_cached_virtual_item_size(last_index)
			next_size = _get_virtual_logical_primary_start(last_index) + (item_size.y if resize_height else item_size.x)
		else:
			var layout_info := _get_virtual_layout_info(maxi(1, _num_items))
			var items_per_line := 1
			if layout == FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL or layout == FGUIEnums.LIST_LAYOUT_PAGINATION:
				items_per_line = maxi(1, int(layout_info["columns"]))
			elif layout == FGUIEnums.LIST_LAYOUT_FLOW_VERTICAL:
				items_per_line = maxi(1, int(layout_info["rows"]))
			var line_count := int(ceilf(float(count) / float(items_per_line)))
			if resize_height:
				next_size = float(line_count) * float(layout_info["cell_height"]) + float(maxi(0, line_count - 1) * line_gap)
			else:
				next_size = float(line_count) * float(layout_info["cell_width"]) + float(maxi(0, line_count - 1) * column_gap)
	elif count > 0:
		var index := mini(count, children.size()) - 1
		while index >= 0:
			var child := get_child_at(index)
			if child != null and (not fold_invisible_items or child.visible):
				next_size = (child.y + child.height) if resize_height else (child.x + child.width)
				break
			index -= 1
	next_size = maxf(float(min_size), next_size)
	if resize_height:
		view_height = next_size
	else:
		view_width = next_size


func set_virtual() -> void:
	_set_virtual(false)


func set_virtual_and_loop() -> void:
	_set_virtual(true)


func _set_virtual(loop: bool) -> void:
	if _virtual:
		if _loop != loop:
			push_error("FairyGUI virtual list mode cannot be changed after initialization.")
		return
	if scroll_pane == null:
		push_error("FairyGUI virtual list must be scrollable.")
		return
	if loop and (layout == FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL or layout == FGUIEnums.LIST_LAYOUT_FLOW_VERTICAL):
		push_error("FairyGUI loop virtual lists do not support FlowHorizontal or FlowVertical layouts.")
		return
	_virtual = true
	_loop = loop
	_num_items = 0
	_virtual_real_num_items = 0
	_virtual_first_index = 0
	_virtual_loop_position_initialized = false
	_virtual_item_size = Vector2.ZERO
	_clear_virtual_item_size_cache()
	_virtual_primary_total = 0.0
	_virtual_cross_size = 0.0
	_virtual_size_layout_dirty = true
	_virtual_size_refresh_queued = false
	remove_children_to_pool()
	if _loop:
		scroll_pane.bounceback_effect = false
	refresh_virtual_list()


func refresh_virtual_list(force_update: bool = true) -> void:
	if not _virtual:
		return
	if _refreshing_virtual:
		return
	_refreshing_virtual = true
	var adjust_content_while_scrolling := _virtual_size_content_refresh_pending
	var pending_primary_shift := _virtual_pending_primary_shift
	_virtual_size_content_refresh_pending = false
	_virtual_pending_primary_shift = 0.0
	if _num_items <= 0:
		remove_children_to_pool()
		_virtual_real_num_items = 0
		_virtual_first_index = 0
		_virtual_loop_position_initialized = false
		_align_offset = Vector2.ZERO
		if scroll_pane != null:
			scroll_pane.set_content_size(0, 0)
		_refreshing_virtual = false
		return
	_ensure_virtual_item_size()
	var variable_layout_changed := _supports_variable_virtual_primary() and _virtual_size_layout_dirty
	_ensure_virtual_size_layout()
	_virtual_real_num_items = _num_items * 6 if _loop else _num_items
	var layout_info := _get_virtual_layout_info(_virtual_real_num_items)
	if layout_info.is_empty():
		_refreshing_virtual = false
		return
	_align_offset = _get_align_offset(Vector2(float(layout_info["content_width"]), float(layout_info["content_height"])))
	var horizontal := bool(layout_info["horizontal"])
	var span := float(layout_info["primary_span"])
	var variable_primary := bool(layout_info.get("variable_primary", false))
	if scroll_pane != null:
		var next_content_width := float(layout_info["content_width"])
		var next_content_height := float(layout_info["content_height"])
		if adjust_content_while_scrolling:
			scroll_pane.change_content_size_on_scrolling(
				next_content_width - scroll_pane.content_width,
				next_content_height - scroll_pane.content_height,
				pending_primary_shift if horizontal else 0.0,
				pending_primary_shift if not horizontal else 0.0
			)
		elif absf(next_content_width - scroll_pane.content_width) > 0.01 or absf(next_content_height - scroll_pane.content_height) > 0.01:
			scroll_pane.set_content_size(next_content_width, next_content_height)
		if _loop:
			_update_virtual_loop_position(horizontal, float(layout_info.get("loop_segment_span", float(_num_items) * span)))
	var scroll_pos := scroll_pane.pos_x if horizontal and scroll_pane != null else (scroll_pane.pos_y if scroll_pane != null else 0.0)
	var visible_count: int
	var previous_first_index := _virtual_first_index
	if variable_primary:
		_virtual_first_index = _get_virtual_first_physical_index(scroll_pos)
		visible_count = _get_variable_visible_count(_virtual_first_index, scroll_pos, float(layout_info["view_primary"]))
	else:
		var group_count := int(layout_info["group_count"])
		var items_per_group := int(layout_info["items_per_group"])
		var first_group := clampi(int(floorf(scroll_pos / span)), 0, maxi(0, group_count - 1))
		_virtual_first_index = mini(_virtual_real_num_items - 1, first_group * items_per_group)
		visible_count = mini(_virtual_real_num_items - _virtual_first_index, (int(ceilf(float(layout_info["view_primary"]) / span)) + 2) * items_per_group)
	if not force_update and not adjust_content_while_scrolling and not variable_layout_changed and _virtual_children_match_range(_virtual_first_index, visible_count):
		_refreshing_virtual = false
		return
	var desired_end := _virtual_first_index + visible_count
	var existing_items: Dictionary = {}
	for child_index in range(children.size() - 1, -1, -1):
		var child: FGUIObject = children[child_index]
		var physical_index := _get_virtual_child_physical_index(child)
		if physical_index < _virtual_first_index or physical_index >= desired_end or existing_items.has(physical_index):
			remove_child_to_pool_at(child_index)
		else:
			existing_items[physical_index] = child
	var item_sizes_changed := false
	for offset in visible_count:
		var physical_index := _virtual_first_index + offset
		var item_index := _physical_to_item_index(physical_index)
		var obj: FGUIObject = existing_items.get(physical_index)
		var needs_render := force_update or obj == null
		var url := _get_virtual_child_url(obj) if obj != null and not force_update else _resolve_virtual_item_url(item_index)
		if obj != null and _get_virtual_child_url(obj) != url:
			remove_child_to_pool(obj)
			obj = null
			needs_render = true
		if obj == null:
			obj = add_item_from_pool(url)
			if obj == null:
				continue
			_set_virtual_child_metadata(obj, physical_index, url)
		else:
			_set_virtual_child_metadata(obj, physical_index, url)
		if needs_render and variable_primary:
			_apply_cached_virtual_item_size(obj, item_index)
		if needs_render:
			_apply_virtual_auto_size(obj, layout_info)
		if needs_render and item_renderer.is_valid():
			item_renderer.call(item_index, obj)
		if obj != null:
			if variable_primary and needs_render:
				var previous_size := _get_cached_virtual_item_size(item_index)
				if _record_virtual_item_size(item_index, obj):
					item_sizes_changed = true
					if physical_index == _virtual_first_index and previous_first_index > _virtual_first_index:
						_virtual_pending_primary_shift += (obj.width - previous_size.x) if horizontal else (obj.height - previous_size.y)
			obj.data = item_index
			if obj is FGUIButton:
				obj.selected = _selected_indices.has(item_index)
			var item_position := _get_virtual_item_position(physical_index, layout_info)
			obj.set_xy(item_position.x, item_position.y)
			set_child_index(obj, mini(offset, children.size() - 1))
	_refreshing_virtual = false
	if item_sizes_changed:
		_queue_virtual_size_refresh()


func _resolve_virtual_item_url(item_index: int) -> String:
	var value: Variant = item_provider.call(item_index) if item_provider.is_valid() else default_item
	return _resolve_item_url(value)


func _get_virtual_child_physical_index(obj: FGUIObject) -> int:
	if obj == null or obj.node == null or not obj.node.has_meta(VIRTUAL_PHYSICAL_INDEX_META):
		return -1
	return int(obj.node.get_meta(VIRTUAL_PHYSICAL_INDEX_META))


func _get_virtual_child_url(obj: FGUIObject) -> String:
	if obj == null or obj.node == null or not obj.node.has_meta(VIRTUAL_ITEM_URL_META):
		return ""
	return str(obj.node.get_meta(VIRTUAL_ITEM_URL_META))


func _set_virtual_child_metadata(obj: FGUIObject, physical_index: int, url: String) -> void:
	if obj == null or obj.node == null:
		return
	obj.node.set_meta(VIRTUAL_PHYSICAL_INDEX_META, physical_index)
	obj.node.set_meta(VIRTUAL_ITEM_URL_META, url)


func _virtual_children_match_range(first_index: int, count: int) -> bool:
	if children.size() != count:
		return false
	for child_index in count:
		if _get_virtual_child_physical_index(children[child_index]) != first_index + child_index:
			return false
	return true


func scroll_to_view(index: int, animated: bool = false, set_first: bool = false) -> void:
	if _virtual:
		if index < 0 or index >= _num_items:
			return
		_ensure_virtual_item_size()
		_ensure_virtual_size_layout()
		if scroll_pane != null:
			_virtual_real_num_items = _num_items * 6 if _loop else _num_items
			var layout_info := _get_virtual_layout_info(_virtual_real_num_items)
			if layout_info.is_empty():
				return
			var horizontal := bool(layout_info["horizontal"])
			var variable_primary := bool(layout_info.get("variable_primary", false))
			var physical_index := _nearest_variable_physical_item_index(index, horizontal) if variable_primary else _nearest_physical_item_index(index, layout_info, horizontal)
			scroll_pane.scroll_to_view(_get_virtual_item_rect(physical_index, layout_info), animated, set_first)
		return
	var obj := get_child_at(index)
	if scroll_pane != null and obj != null:
		scroll_pane.scroll_to_view(obj, animated, set_first)


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_before_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 5):
		return
	layout = buffer.read_i8()
	selection_mode = buffer.read_i8()
	align = buffer.read_i8()
	vertical_align = buffer.read_i8()
	line_gap = buffer.read_i16()
	column_gap = buffer.read_i16()
	line_count = buffer.read_i16()
	column_count = buffer.read_i16()
	auto_resize_item = buffer.read_bool()
	children_render_order = buffer.read_i8()
	apex_index = buffer.read_i16()
	if buffer.read_bool():
		margin.top = buffer.read_i32()
		margin.bottom = buffer.read_i32()
		margin.left = buffer.read_i32()
		margin.right = buffer.read_i32()
	var overflow := buffer.read_i8()
	if overflow == FGUIEnums.OVERFLOW_SCROLL:
		var saved_pos := buffer.pos
		if buffer.seek(begin_pos, 7):
			setup_scroll(buffer)
		buffer.pos = saved_pos
	else:
		setup_overflow(overflow)
	if buffer.read_bool():
		buffer.skip(8)
	if buffer.version >= 2:
		scroll_item_to_view_on_click = buffer.read_bool()
		fold_invisible_items = buffer.read_bool()
	if buffer.seek(begin_pos, 8):
		var value = buffer.read_s()
		if value != null:
			default_item = str(value)
		_read_items(buffer)


func setup_after_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_after_add(buffer, begin_pos)
	if buffer.seek(begin_pos, 6):
		var controller_index := buffer.read_i16()
		if controller_index >= 0 and parent != null:
			selection_controller = parent.get_controller_at(controller_index)


func handle_controller_changed(controller: FGUIController) -> void:
	super.handle_controller_changed(controller)
	if selection_controller == controller:
		selected_index = controller.selected_index


func update_bounds() -> void:
	_bounds_changed = false
	if _virtual:
		return
	var cur := Vector2.ZERO
	var max_size := Vector2.ZERO
	var line_size := Vector2.ZERO
	var items_in_line := 0
	var view_limit := Vector2(maxf(1.0, view_width), maxf(1.0, view_height))
	for child: FGUIObject in children:
		if fold_invisible_items and not child.visible:
			continue
		match layout:
			FGUIEnums.LIST_LAYOUT_SINGLE_ROW:
				if auto_resize_item and view_height > 0.0:
					child.height = view_height
				child.set_xy(cur.x, 0)
				cur.x += child.width + column_gap
				max_size.y = maxf(max_size.y, child.height)
			FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL:
				var should_wrap := items_in_line > 0 and (cur.x + child.width > view_limit.x or (column_count > 0 and items_in_line >= column_count))
				if should_wrap:
					max_size.x = maxf(max_size.x, cur.x - column_gap)
					cur.x = 0.0
					cur.y += line_size.y + line_gap
					line_size = Vector2.ZERO
					items_in_line = 0
				child.set_xy(cur.x, cur.y)
				cur.x += child.width + column_gap
				line_size.y = maxf(line_size.y, child.height)
				items_in_line += 1
				max_size.y = maxf(max_size.y, cur.y + line_size.y)
			FGUIEnums.LIST_LAYOUT_FLOW_VERTICAL:
				var should_wrap := items_in_line > 0 and (cur.y + child.height > view_limit.y or (line_count > 0 and items_in_line >= line_count))
				if should_wrap:
					max_size.y = maxf(max_size.y, cur.y - line_gap)
					cur.y = 0.0
					cur.x += line_size.x + column_gap
					line_size = Vector2.ZERO
					items_in_line = 0
				child.set_xy(cur.x, cur.y)
				cur.y += child.height + line_gap
				line_size.x = maxf(line_size.x, child.width)
				items_in_line += 1
				max_size.x = maxf(max_size.x, cur.x + line_size.x)
			FGUIEnums.LIST_LAYOUT_PAGINATION:
				var cell_w := maxf(1.0, child.width + column_gap)
				var cell_h := maxf(1.0, child.height + line_gap)
				var cols := column_count if column_count > 0 else maxi(1, int(floorf((view_limit.x + column_gap) / cell_w)))
				var rows := line_count if line_count > 0 else maxi(1, int(floorf((view_limit.y + line_gap) / cell_h)))
				var page_capacity := maxi(1, cols * rows)
				var index := items_in_line
				var page := int(floori(index / page_capacity))
				var page_index := index % page_capacity
				var col := page_index % cols
				var row := int(floori(page_index / cols))
				child.set_xy(page * view_limit.x + col * cell_w, row * cell_h)
				max_size.x = maxf(max_size.x, (page + 1) * view_limit.x)
				max_size.y = maxf(max_size.y, view_limit.y)
				items_in_line += 1
			_:
				if auto_resize_item and view_width > 0.0:
					child.width = view_width
				child.set_xy(0, cur.y)
				cur.y += child.height + line_gap
				max_size.x = maxf(max_size.x, child.width)
	if layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW:
		max_size.x = maxf(0, cur.x - column_gap)
	elif layout == FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN:
		max_size.y = maxf(0, cur.y - line_gap)
	elif layout == FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL:
		max_size.x = maxf(max_size.x, cur.x - column_gap)
	elif layout == FGUIEnums.LIST_LAYOUT_FLOW_VERTICAL:
		max_size.y = maxf(max_size.y, cur.y - line_gap)
	_align_offset = _get_align_offset(max_size)
	if not _align_offset.is_zero_approx():
		for child: FGUIObject in children:
			if fold_invisible_items and not child.visible:
				continue
			child.set_xy(child.x + _align_offset.x, child.y + _align_offset.y)
	if scroll_pane != null:
		scroll_pane.set_content_size(max_size.x, max_size.y)


func _read_items(buffer: FGUIByteBuffer) -> void:
	var count := buffer.read_i16()
	for i in count:
		var next_pos := buffer.read_i16() + buffer.pos
		var url = buffer.read_s()
		if url == null:
			url = default_item
		var obj := get_from_pool(str(url))
		if obj != null:
			add_child(obj)
			_setup_item(buffer, obj)
		buffer.pos = next_pos


func _setup_item(buffer: FGUIByteBuffer, obj: FGUIObject) -> void:
	var value = buffer.read_s()
	if value != null:
		obj.set_text(str(value))
	value = buffer.read_s()
	if value != null and obj is FGUIButton:
		obj.selected_title = str(value)
	value = buffer.read_s()
	if value != null:
		obj.set_icon(str(value))
	value = buffer.read_s()
	if value != null and obj is FGUIButton:
		obj.selected_icon = str(value)
	value = buffer.read_s()
	if value != null:
		obj.name = str(value)
	if obj is FGUIComponent:
		var component := obj as FGUIComponent
		var count := buffer.read_i16()
		for i in count:
			var controller_name = buffer.read_s()
			var page_id = buffer.read_s()
			var controller := component.get_controller(_string_or_empty(controller_name))
			if controller != null:
				controller.selected_page_id = _string_or_empty(page_id)
		if buffer.version >= 2:
			count = buffer.read_i16()
			for i in count:
				var target := _string_or_empty(buffer.read_s())
				var property_id := buffer.read_i16()
				var prop_value = buffer.read_s()
				var child := component.get_child_by_path(target)
				if child != null:
					child.set_prop(property_id, prop_value)


func _click_item(_event: Variant, item: FGUIObject) -> void:
	_dispatch_item_event(_event, item, FGUIEvents.CLICK_ITEM)


func _right_click_item(_event: Variant, item: FGUIObject) -> void:
	_dispatch_item_event(_event, item, FGUIEvents.RIGHT_CLICK_ITEM)


func _dispatch_item_event(event: Variant, item: FGUIObject, event_name: String) -> void:
	var index := int(item.data) if _virtual and item.data != null else get_child_index(item)
	if index == -1:
		return
	_set_selection_on_event(index, item, event)
	if scroll_item_to_view_on_click:
		scroll_to_view(index)
	emit_event(event_name, item)


func _set_selection_on_event(index: int, item: FGUIObject, event: Variant) -> void:
	if not (item is FGUIButton) or selection_mode == FGUIEnums.LIST_SELECTION_NONE:
		return
	var shift_pressed: bool = false
	var ctrl_pressed: bool = false
	if event is InputEventWithModifiers:
		shift_pressed = event.shift_pressed
		ctrl_pressed = event.ctrl_pressed
	var is_selected := _selected_indices.has(index)
	if selection_mode == FGUIEnums.LIST_SELECTION_SINGLE:
		if not is_selected:
			_clear_selection_except(index)
			add_selection(index)
		_last_selected_index = index
		if _selected_indices.has(index):
			_update_selection_controller(index)
		return

	var preserve_last_index := false
	if shift_pressed and not is_selected and _last_selected_index >= 0:
		var selection_anchor := _last_selected_index
		var start_index := mini(selection_anchor, index)
		var end_index := mini(maxi(selection_anchor, index), num_items - 1)
		for selection_index in range(start_index, end_index + 1):
			add_selection(selection_index)
		_last_selected_index = selection_anchor
		preserve_last_index = true
	elif ctrl_pressed or selection_mode == FGUIEnums.LIST_SELECTION_MULTIPLE_SINGLE_CLICK:
		if is_selected:
			remove_selection(index)
		else:
			add_selection(index)
	else:
		_clear_selection_except(index)
		if not is_selected:
			add_selection(index)

	if not preserve_last_index:
		_last_selected_index = index
	if _selected_indices.has(index):
		_update_selection_controller(index)


func _clear_selection_except(index: int) -> void:
	for selected_index_value in _selected_indices.duplicate():
		if selected_index_value != index:
			remove_selection(selected_index_value)


func get_first_child_in_view() -> int:
	if _virtual:
		return _physical_to_item_index(_virtual_first_index)
	var horizontal := layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW
	var scroll_pos := scroll_pane.pos_x if horizontal and scroll_pane != null else (scroll_pane.pos_y if scroll_pane != null else 0.0)
	for index in children.size():
		var child: FGUIObject = children[index]
		var end := (child.x + child.width) if horizontal else (child.y + child.height)
		if end > scroll_pos:
			return index
	return -1


func get_snapping_position_with_dir(x_value: float, y_value: float, x_dir: int, y_dir: int) -> Vector2:
	if not _virtual:
		return super.get_snapping_position_with_dir(x_value, y_value, x_dir, y_dir)
	if _num_items <= 0:
		return Vector2.ZERO
	_ensure_virtual_item_size()
	_ensure_virtual_size_layout()
	_virtual_real_num_items = _num_items * 6 if _loop else _num_items
	var layout_info := _get_virtual_layout_info(_virtual_real_num_items)
	if layout_info.is_empty():
		return Vector2(x_value, y_value)
	if bool(layout_info["horizontal"]):
		return Vector2(_get_virtual_snapping_primary(x_value, x_dir, layout_info), y_value)
	return Vector2(x_value, _get_virtual_snapping_primary(y_value, y_dir, layout_info))


func _get_virtual_snapping_primary(value: float, direction: int, layout_info: Dictionary) -> float:
	var horizontal := bool(layout_info["horizontal"])
	var span := maxf(1.0, float(layout_info["primary_span"]))
	var primary_size := span if int(layout_info["layout"]) == FGUIEnums.LIST_LAYOUT_PAGINATION else float(layout_info["cell_width"] if horizontal else layout_info["cell_height"])
	var start := 0.0
	var next_start := start
	if bool(layout_info.get("variable_primary", false)):
		var physical_index := _get_virtual_first_physical_index(value)
		start = _get_virtual_primary_start(physical_index)
		primary_size = _get_virtual_primary_size(physical_index)
		next_start = _get_virtual_primary_start(physical_index + 1) if physical_index + 1 < _virtual_real_num_items else start
	else:
		var group_count := maxi(1, int(layout_info["group_count"]))
		var group_index := clampi(int(floorf(value / span)), 0, group_count - 1)
		start = float(group_index) * span
		next_start = float(group_index + 1) * span if group_index + 1 < group_count else start
	var delta := maxf(0.0, value - start)
	if next_start > start and _should_snap_to_next(direction, delta, maxf(1.0, primary_size)):
		return next_start
	return start


func _should_snap_to_next(direction: int, delta: float, size: float) -> bool:
	var threshold := clampf(FGUIConfig.default_scroll_snapping_threshold, 0.0, 1.0)
	return (direction < 0 and delta > threshold * size) or (direction > 0 and delta > (1.0 - threshold) * size) or (direction == 0 and delta > size * 0.5)


func child_index_to_item_index(index: int) -> int:
	if not _virtual:
		return index
	if index < 0 or index >= children.size():
		return -1
	var value = children[index].data
	return int(value) if value != null else -1


func item_index_to_child_index(index: int) -> int:
	if not _virtual:
		return index
	for child_index in children.size():
		if children[child_index].data != null and int(children[child_index].data) == index:
			return child_index
	return -1


func _supports_variable_virtual_primary() -> bool:
	return _virtual and (layout == FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN or layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW)


func invalidate_virtual_item_size(index: int) -> void:
	invalidate_virtual_item_sizes(index, index)


func invalidate_virtual_item_sizes(begin_index: int = 0, end_index: int = -1) -> void:
	if not _virtual or _num_items <= 0:
		return
	begin_index = clampi(begin_index, 0, _num_items - 1)
	end_index = _num_items - 1 if end_index < 0 else clampi(end_index, begin_index, _num_items - 1)
	if begin_index == 0 and end_index == _num_items - 1:
		_clear_virtual_item_size_cache()
	else:
		for item_index_value in _virtual_item_size_overrides.keys():
			var item_index := int(item_index_value)
			if item_index >= begin_index and item_index <= end_index:
				_virtual_item_size_overrides.erase(item_index_value)
		_virtual_size_layout_dirty = true
	_virtual_loop_position_initialized = false
	refresh_virtual_list()


func _clear_virtual_item_size_cache() -> void:
	_virtual_item_size_overrides.clear()
	_virtual_chunk_primary_deltas.clear()
	_virtual_chunk_item_indices.clear()
	_virtual_changed_chunks.clear()
	_virtual_changed_chunk_prefix.clear()
	_virtual_size_layout_dirty = true


func _trim_virtual_item_size_cache() -> void:
	for item_index_value in _virtual_item_size_overrides.keys():
		if int(item_index_value) >= _num_items:
			_virtual_item_size_overrides.erase(item_index_value)
	_virtual_size_layout_dirty = true


func _ensure_virtual_size_layout() -> void:
	if not _supports_variable_virtual_primary() or not _virtual_size_layout_dirty:
		return
	_virtual_chunk_primary_deltas.clear()
	_virtual_chunk_item_indices.clear()
	_virtual_changed_chunks.clear()
	_virtual_changed_chunk_prefix.clear()
	var gap := float(column_gap if layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW else line_gap)
	var default_primary := _get_virtual_default_primary_size()
	var default_cross := _get_virtual_default_cross_size()
	_virtual_primary_total = float(_num_items) * default_primary + float(maxi(0, _num_items - 1)) * gap
	_virtual_cross_size = default_cross
	for item_index_value in _virtual_item_size_overrides.keys():
		var item_index := int(item_index_value)
		if item_index < 0 or item_index >= _num_items:
			_virtual_item_size_overrides.erase(item_index_value)
			continue
		var item_size: Vector2 = _virtual_item_size_overrides[item_index_value]
		var primary_delta := _get_virtual_primary_size_from_vector(item_size) - default_primary
		var chunk_index := item_index / VIRTUAL_SIZE_CHUNK_SIZE
		_virtual_chunk_primary_deltas[chunk_index] = float(_virtual_chunk_primary_deltas.get(chunk_index, 0.0)) + primary_delta
		var chunk_items: Array = _virtual_chunk_item_indices.get(chunk_index, [])
		chunk_items.append(item_index)
		_virtual_chunk_item_indices[chunk_index] = chunk_items
		_virtual_primary_total += primary_delta
		_virtual_cross_size = maxf(_virtual_cross_size, _get_virtual_cross_size_from_vector(item_size))
	for chunk_index_value in _virtual_chunk_item_indices.keys():
		var chunk_index := int(chunk_index_value)
		var chunk_items: Array = _virtual_chunk_item_indices[chunk_index_value]
		chunk_items.sort()
		_virtual_changed_chunks.append(chunk_index)
	_virtual_changed_chunks.sort()
	var running_delta := 0.0
	for chunk_index in _virtual_changed_chunks:
		running_delta += float(_virtual_chunk_primary_deltas.get(chunk_index, 0.0))
		_virtual_changed_chunk_prefix.append(running_delta)
	_virtual_size_layout_dirty = false


func _get_cached_virtual_item_size(item_index: int) -> Vector2:
	return _virtual_item_size_overrides.get(item_index, _virtual_item_size)


func _apply_cached_virtual_item_size(obj: FGUIObject, item_index: int) -> void:
	var item_size := _get_cached_virtual_item_size(item_index)
	obj.set_size(item_size.x, item_size.y)


func _record_virtual_item_size(item_index: int, obj: FGUIObject) -> bool:
	if item_index < 0 or item_index >= _num_items:
		return false
	var next_size := Vector2(maxf(1.0, obj.width), maxf(1.0, obj.height))
	if _get_cached_virtual_item_size(item_index).is_equal_approx(next_size):
		return false
	if _virtual_item_size.is_equal_approx(next_size):
		_virtual_item_size_overrides.erase(item_index)
	else:
		_virtual_item_size_overrides[item_index] = next_size
	_virtual_size_layout_dirty = true
	if _loop:
		_virtual_loop_position_initialized = false
	return true


func _queue_virtual_size_refresh() -> void:
	if _virtual_size_refresh_queued:
		return
	_virtual_size_refresh_queued = true
	call_deferred("_refresh_virtual_after_size_change")


func _refresh_virtual_after_size_change() -> void:
	_virtual_size_refresh_queued = false
	if _virtual:
		_virtual_size_content_refresh_pending = scroll_pane != null and (
			scroll_pane._pointer_dragging
			or scroll_pane._scroll_tween != null
			or scroll_pane.pos_x > 0.5
			or scroll_pane.pos_y > 0.5
		)
		refresh_virtual_list(false)


func _get_virtual_content_primary(_physical_count: int) -> float:
	if _num_items <= 0:
		return 0.0
	if not _loop:
		return _virtual_primary_total
	var gap := float(column_gap if layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW else line_gap)
	return maxf(0.0, _get_virtual_loop_segment_span() * 6.0 - gap)


func _get_virtual_loop_segment_span() -> float:
	var gap := float(column_gap if layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW else line_gap)
	return _virtual_primary_total + gap


func _get_virtual_default_primary_size() -> float:
	return _get_virtual_primary_size_from_vector(_virtual_item_size)


func _get_virtual_default_cross_size() -> float:
	return _get_virtual_cross_size_from_vector(_virtual_item_size)


func _get_virtual_primary_size_from_vector(item_size: Vector2) -> float:
	return maxf(1.0, item_size.x if layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW else item_size.y)


func _get_virtual_cross_size_from_vector(item_size: Vector2) -> float:
	return maxf(1.0, item_size.y if layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW else item_size.x)


func _get_virtual_primary_delta_before(item_index: int) -> float:
	if item_index <= 0 or _virtual_changed_chunks.is_empty():
		return 0.0
	var chunk_index := item_index / VIRTUAL_SIZE_CHUNK_SIZE
	var low := 0
	var high := _virtual_changed_chunks.size()
	while low < high:
		var mid := (low + high) / 2
		if _virtual_changed_chunks[mid] < chunk_index:
			low = mid + 1
		else:
			high = mid
	var delta := _virtual_changed_chunk_prefix[low - 1] if low > 0 else 0.0
	var chunk_items: Array = _virtual_chunk_item_indices.get(chunk_index, [])
	var default_primary := _get_virtual_default_primary_size()
	for override_index_value in chunk_items:
		var override_index := int(override_index_value)
		if override_index >= item_index:
			break
		var item_size: Vector2 = _virtual_item_size_overrides.get(override_index, _virtual_item_size)
		delta += _get_virtual_primary_size_from_vector(item_size) - default_primary
	return delta


func _get_virtual_logical_primary_start(item_index: int) -> float:
	item_index = clampi(item_index, 0, _num_items)
	var gap := float(column_gap if layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW else line_gap)
	return float(item_index) * (_get_virtual_default_primary_size() + gap) + _get_virtual_primary_delta_before(item_index)


func _get_virtual_primary_start(physical_index: int) -> float:
	if _num_items <= 0:
		return 0.0
	var logical_index := _physical_to_item_index(physical_index)
	if logical_index < 0 or logical_index >= _num_items:
		return 0.0
	var copy_index := physical_index / _num_items if _loop else 0
	return float(copy_index) * _get_virtual_loop_segment_span() + _get_virtual_logical_primary_start(logical_index)


func _get_virtual_primary_size(physical_index: int) -> float:
	var item_size := _get_cached_virtual_item_size(_physical_to_item_index(physical_index))
	return maxf(1.0, item_size.x if layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW else item_size.y)


func _get_virtual_first_physical_index(position: float) -> int:
	if _num_items <= 0:
		return 0
	var copy_index := 0
	var local_position := maxf(0.0, position)
	if _loop:
		var segment_span := maxf(1.0, _get_virtual_loop_segment_span())
		copy_index = clampi(int(floorf(local_position / segment_span)), 0, 5)
		local_position -= float(copy_index) * segment_span
	var low := 0
	var high := _num_items
	while low < high:
		var mid := (low + high) / 2
		if _get_virtual_logical_primary_start(mid) <= local_position:
			low = mid + 1
		else:
			high = mid
	var logical_index := clampi(low - 1, 0, _num_items - 1)
	return mini(_virtual_real_num_items - 1, copy_index * _num_items + logical_index)


func _get_variable_visible_count(first_physical_index: int, scroll_position: float, view_primary: float) -> int:
	var visible_end := scroll_position + maxf(1.0, view_primary) + maxf(1.0, _virtual_item_size.x if layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW else _virtual_item_size.y)
	var count := 0
	for physical_index in range(first_physical_index, _virtual_real_num_items):
		if physical_index > first_physical_index and _get_virtual_primary_start(physical_index) > visible_end:
			break
		count += 1
	return count


func _nearest_variable_physical_item_index(item_index: int, horizontal: bool) -> int:
	if not _loop or _num_items <= 0:
		return item_index
	var scroll_position := scroll_pane.pos_x if horizontal else scroll_pane.pos_y
	var nearest := item_index
	var nearest_distance := INF
	for copy_index in 6:
		var physical_index := item_index + copy_index * _num_items
		var distance := absf(_get_virtual_primary_start(physical_index) - scroll_position)
		if distance < nearest_distance:
			nearest = physical_index
			nearest_distance = distance
	return nearest


func _get_virtual_layout_info(item_count: int) -> Dictionary:
	if item_count <= 0:
		return {}
	var viewport_width := maxf(1.0, view_width if view_width > 0.0 else width)
	var viewport_height := maxf(1.0, view_height if view_height > 0.0 else height)
	var cell_width := maxf(1.0, _virtual_item_size.x)
	var cell_height := maxf(1.0, _virtual_item_size.y)
	if auto_resize_item:
		if layout == FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN:
			cell_width = viewport_width
		elif layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW:
			cell_height = viewport_height
		elif layout == FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL and column_count > 0:
			cell_width = maxf(1.0, (viewport_width - float(column_gap * (column_count - 1))) / float(column_count))
		elif layout == FGUIEnums.LIST_LAYOUT_FLOW_VERTICAL and line_count > 0:
			cell_height = maxf(1.0, (viewport_height - float(line_gap * (line_count - 1))) / float(line_count))
		elif layout == FGUIEnums.LIST_LAYOUT_PAGINATION:
			if column_count > 0:
				cell_width = maxf(1.0, (viewport_width - float(column_gap * (column_count - 1))) / float(column_count))
			if line_count > 0:
				cell_height = maxf(1.0, (viewport_height - float(line_gap * (line_count - 1))) / float(line_count))
	var horizontal_span := maxf(1.0, cell_width + float(column_gap))
	var vertical_span := maxf(1.0, cell_height + float(line_gap))
	if _supports_variable_virtual_primary():
		var loop_segment_span := _get_virtual_loop_segment_span()
		if layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW:
			return {
				"layout": layout,
				"horizontal": true,
				"variable_primary": true,
				"primary_span": horizontal_span,
				"loop_segment_span": loop_segment_span,
				"items_per_group": 1,
				"group_count": item_count,
				"view_primary": viewport_width,
				"content_width": _get_virtual_content_primary(item_count),
				"content_height": maxf(cell_height, _virtual_cross_size),
				"cell_width": cell_width,
				"cell_height": cell_height,
				"horizontal_span": horizontal_span,
				"vertical_span": vertical_span,
				"columns": 1,
				"rows": 1,
				"view_width": viewport_width,
				"view_height": viewport_height,
			}
		return {
			"layout": FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN,
			"horizontal": false,
			"variable_primary": true,
			"primary_span": vertical_span,
			"loop_segment_span": loop_segment_span,
			"items_per_group": 1,
			"group_count": item_count,
			"view_primary": viewport_height,
			"content_width": maxf(cell_width, _virtual_cross_size),
			"content_height": _get_virtual_content_primary(item_count),
			"cell_width": cell_width,
			"cell_height": cell_height,
			"horizontal_span": horizontal_span,
			"vertical_span": vertical_span,
			"columns": 1,
			"rows": 1,
			"view_width": viewport_width,
			"view_height": viewport_height,
		}

	match layout:
		FGUIEnums.LIST_LAYOUT_SINGLE_ROW:
			return {
				"layout": layout,
				"horizontal": true,
				"primary_span": horizontal_span,
				"items_per_group": 1,
				"group_count": item_count,
				"view_primary": viewport_width,
				"content_width": maxf(cell_width, float(item_count) * horizontal_span - float(column_gap)),
				"content_height": cell_height,
				"cell_width": cell_width,
				"cell_height": cell_height,
				"horizontal_span": horizontal_span,
				"vertical_span": vertical_span,
				"columns": 1,
				"rows": 1,
				"view_width": viewport_width,
				"view_height": viewport_height,
			}
		FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL:
			var columns := column_count if column_count > 0 else maxi(1, int(floorf((viewport_width + float(column_gap)) / horizontal_span)))
			var rows := maxi(1, int(ceilf(float(item_count) / float(columns))))
			return {
				"layout": layout,
				"horizontal": false,
				"primary_span": vertical_span,
				"items_per_group": columns,
				"group_count": rows,
				"view_primary": viewport_height,
				"content_width": maxf(cell_width, float(columns) * horizontal_span - float(column_gap)),
				"content_height": maxf(cell_height, float(rows) * vertical_span - float(line_gap)),
				"cell_width": cell_width,
				"cell_height": cell_height,
				"horizontal_span": horizontal_span,
				"vertical_span": vertical_span,
				"columns": columns,
				"rows": rows,
				"view_width": viewport_width,
				"view_height": viewport_height,
			}
		FGUIEnums.LIST_LAYOUT_FLOW_VERTICAL:
			var rows := line_count if line_count > 0 else maxi(1, int(floorf((viewport_height + float(line_gap)) / vertical_span)))
			var columns := maxi(1, int(ceilf(float(item_count) / float(rows))))
			return {
				"layout": layout,
				"horizontal": true,
				"primary_span": horizontal_span,
				"items_per_group": rows,
				"group_count": columns,
				"view_primary": viewport_width,
				"content_width": maxf(cell_width, float(columns) * horizontal_span - float(column_gap)),
				"content_height": maxf(cell_height, float(rows) * vertical_span - float(line_gap)),
				"cell_width": cell_width,
				"cell_height": cell_height,
				"horizontal_span": horizontal_span,
				"vertical_span": vertical_span,
				"columns": columns,
				"rows": rows,
				"view_width": viewport_width,
				"view_height": viewport_height,
			}
		FGUIEnums.LIST_LAYOUT_PAGINATION:
			var columns := column_count if column_count > 0 else maxi(1, int(floorf((viewport_width + float(column_gap)) / horizontal_span)))
			var rows := line_count if line_count > 0 else maxi(1, int(floorf((viewport_height + float(line_gap)) / vertical_span)))
			var page_capacity := maxi(1, columns * rows)
			var page_count := maxi(1, int(ceilf(float(item_count) / float(page_capacity))))
			var loop_segment_span := (float(page_count) * viewport_width + float(column_gap)) / 6.0 if _loop else 0.0
			return {
				"layout": layout,
				"horizontal": true,
				"primary_span": viewport_width,
				"loop_segment_span": loop_segment_span,
				"items_per_group": page_capacity,
				"group_count": page_count,
				"view_primary": viewport_width,
				"content_width": float(page_count) * viewport_width,
				"content_height": viewport_height,
				"cell_width": cell_width,
				"cell_height": cell_height,
				"horizontal_span": horizontal_span,
				"vertical_span": vertical_span,
				"columns": columns,
				"rows": rows,
				"view_width": viewport_width,
				"view_height": viewport_height,
			}
		_:
			return {
				"layout": FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN,
				"horizontal": false,
				"primary_span": vertical_span,
				"items_per_group": 1,
				"group_count": item_count,
				"view_primary": viewport_height,
				"content_width": cell_width,
				"content_height": maxf(cell_height, float(item_count) * vertical_span - float(line_gap)),
				"cell_width": cell_width,
				"cell_height": cell_height,
				"horizontal_span": horizontal_span,
				"vertical_span": vertical_span,
				"columns": 1,
				"rows": 1,
				"view_width": viewport_width,
				"view_height": viewport_height,
			}


func _get_virtual_item_position(physical_index: int, layout_info: Dictionary) -> Vector2:
	var list_layout := int(layout_info["layout"])
	if bool(layout_info.get("variable_primary", false)):
		var variable_position := Vector2(_get_virtual_primary_start(physical_index), 0.0) if list_layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW else Vector2(0.0, _get_virtual_primary_start(physical_index))
		return variable_position + _align_offset
	var horizontal_span := float(layout_info["horizontal_span"])
	var vertical_span := float(layout_info["vertical_span"])
	var position := Vector2.ZERO
	match list_layout:
		FGUIEnums.LIST_LAYOUT_SINGLE_ROW:
			position = Vector2(float(physical_index) * horizontal_span, 0.0)
		FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL:
			var columns := int(layout_info["columns"])
			position = Vector2(float(physical_index % columns) * horizontal_span, float(physical_index / columns) * vertical_span)
		FGUIEnums.LIST_LAYOUT_FLOW_VERTICAL:
			var rows := int(layout_info["rows"])
			position = Vector2(float(physical_index / rows) * horizontal_span, float(physical_index % rows) * vertical_span)
		FGUIEnums.LIST_LAYOUT_PAGINATION:
			var page_capacity := int(layout_info["items_per_group"])
			var page := physical_index / page_capacity
			var page_index := physical_index % page_capacity
			var columns := int(layout_info["columns"])
			position = Vector2(
				float(page) * float(layout_info["view_width"]) + float(page_index % columns) * horizontal_span,
				float(page_index / columns) * vertical_span
			)
		_:
			position = Vector2(0.0, float(physical_index) * vertical_span)
	return position + _align_offset


func _get_virtual_item_rect(physical_index: int, layout_info: Dictionary) -> Rect2:
	var item_index := _physical_to_item_index(physical_index)
	var item_size := _get_cached_virtual_item_size(item_index) if bool(layout_info.get("variable_primary", false)) else Vector2(float(layout_info["cell_width"]), float(layout_info["cell_height"]))
	if layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW and auto_resize_item:
		item_size.y = maxf(1.0, view_height)
	elif layout == FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN and auto_resize_item:
		item_size.x = maxf(1.0, view_width)
	return Rect2(_get_virtual_item_position(physical_index, layout_info), item_size)


func _apply_virtual_auto_size(obj: FGUIObject, layout_info: Dictionary) -> void:
	if not auto_resize_item:
		return
	var next_size := Vector2(obj.width, obj.height)
	match layout:
		FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN:
			next_size.x = float(layout_info["cell_width"])
		FGUIEnums.LIST_LAYOUT_SINGLE_ROW:
			next_size.y = float(layout_info["cell_height"])
		FGUIEnums.LIST_LAYOUT_FLOW_HORIZONTAL:
			if column_count > 0:
				next_size.x = float(layout_info["cell_width"])
		FGUIEnums.LIST_LAYOUT_FLOW_VERTICAL:
			if line_count > 0:
				next_size.y = float(layout_info["cell_height"])
		FGUIEnums.LIST_LAYOUT_PAGINATION:
			if column_count > 0:
				next_size.x = float(layout_info["cell_width"])
			if line_count > 0:
				next_size.y = float(layout_info["cell_height"])
	obj.set_size(next_size.x, next_size.y, true)


func _get_align_offset(content_size: Vector2) -> Vector2:
	var offset := Vector2.ZERO
	var view_size := Vector2(maxf(0.0, view_width), maxf(0.0, view_height))
	if content_size.x < view_size.x:
		if align == FGUIEnums.ALIGN_CENTER:
			offset.x = floorf((view_size.x - content_size.x) * 0.5)
		elif align == FGUIEnums.ALIGN_RIGHT:
			offset.x = view_size.x - content_size.x
	if content_size.y < view_size.y:
		if vertical_align == FGUIEnums.VERT_ALIGN_MIDDLE:
			offset.y = floorf((view_size.y - content_size.y) * 0.5)
		elif vertical_align == FGUIEnums.VERT_ALIGN_BOTTOM:
			offset.y = view_size.y - content_size.y
	return offset


func _request_layout_refresh() -> void:
	_virtual_size_layout_dirty = true
	if _virtual:
		refresh_virtual_list()
	elif scroll_pane == null and not track_bounds:
		update_bounds()
	else:
		set_bounds_changed_flag()


func _physical_to_item_index(physical_index: int) -> int:
	if _num_items <= 0:
		return -1
	return physical_index % _num_items if _loop else physical_index


func _nearest_physical_item_index(item_index: int, layout_info: Dictionary, horizontal: bool) -> int:
	if not _loop or _num_items <= 0:
		return item_index
	var scroll_pos := scroll_pane.pos_x if horizontal else scroll_pane.pos_y
	var span := maxf(1.0, float(layout_info["primary_span"]))
	var items_per_group := maxi(1, int(layout_info["items_per_group"]))
	var nearest := item_index
	var nearest_distance := INF
	for copy_index in 6:
		var physical_index := item_index + copy_index * _num_items
		var primary_start := float(physical_index / items_per_group) * span
		var distance := absf(primary_start - scroll_pos)
		if distance < nearest_distance:
			nearest = physical_index
			nearest_distance = distance
	return nearest


func _update_virtual_loop_position(horizontal: bool, segment_span: float) -> void:
	if scroll_pane == null or _num_items <= 0:
		return
	var segment := segment_span
	if segment <= 0.0:
		return
	var max_position := maxf(0.0, (scroll_pane.content_width - scroll_pane.view_width) if horizontal else (scroll_pane.content_height - scroll_pane.view_height))
	var current_position := scroll_pane.pos_x if horizontal else scroll_pane.pos_y
	var target_position := current_position
	if not _virtual_loop_position_initialized:
		target_position = clampf(segment * 3.0, 0.0, max_position)
		_virtual_loop_position_initialized = true
	elif current_position < segment and current_position + segment * 3.0 <= max_position:
		target_position += segment * 3.0
	elif current_position > segment * 4.0 and current_position - segment * 3.0 >= 0.0:
		target_position -= segment * 3.0
	if not is_equal_approx(target_position, current_position):
		if horizontal:
			scroll_pane.set_pos(target_position, scroll_pane.pos_y)
		else:
			scroll_pane.set_pos(scroll_pane.pos_x, target_position)


func _set_virtual_selection(index: int, selected: bool) -> void:
	for child: FGUIObject in children:
		if child is FGUIButton and child.data != null and int(child.data) == index:
			child.selected = selected


func _update_selection_controller(index: int) -> void:
	if selection_controller == null or selection_controller.changing or index >= selection_controller.page_count:
		return
	var controller := selection_controller
	selection_controller = null
	controller.selected_index = index
	selection_controller = controller


func _ensure_virtual_item_size() -> void:
	if _virtual_item_size.x > 0.0 and _virtual_item_size.y > 0.0:
		return
	var obj := get_from_pool(default_item)
	if obj == null:
		_virtual_item_size = Vector2(maxf(1.0, width), maxf(1.0, height))
		return
	_virtual_item_size = Vector2(maxf(1.0, obj.width), maxf(1.0, obj.height))
	return_to_pool(obj)
