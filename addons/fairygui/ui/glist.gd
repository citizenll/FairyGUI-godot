class_name FGUIList
extends FGUIComponent

var item_renderer: Callable
var item_provider: Callable
var scroll_item_to_view_on_click: bool = true
var fold_invisible_items: bool = false
var layout: int = FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN:
	set(value):
		layout = value
		set_bounds_changed_flag()
var line_count: int = 0
var column_count: int = 0
var line_gap: int = 0
var column_gap: int = 0
var default_item: String = "":
	set(value):
		default_item = FGUIPackage.normalize_url(value)
var auto_resize_item: bool = true
var selection_mode: int = FGUIEnums.LIST_SELECTION_SINGLE
var selection_controller: FGUIController
var item_pool := FGUIObjectPool.new()

var _virtual: bool = false
var _num_items: int = 0
var _selected_indices: Array[int] = []
var _virtual_item_size: Vector2 = Vector2.ZERO
var _virtual_first_index: int = 0
var _refreshing_virtual: bool = false

var num_items: int:
	get:
		return _num_items if _virtual else children.size()
	set(value):
		if _virtual:
			_num_items = max(0, value)
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


func dispose() -> void:
	item_pool.clear()
	super.dispose()


func add_child_at(child: FGUIObject, index: int) -> FGUIObject:
	var added := super.add_child_at(child, index)
	if added is FGUIButton:
		added.selected = false
		added.change_state_on_click = false
	added.on("click", Callable(self, "_click_item").bind(added))
	return added


func add_item(url: String = "") -> FGUIObject:
	var obj := FGUIPackage.create_object_from_url(url if url != "" else default_item)
	return add_child(obj) if obj != null else null


func add_item_from_pool(url: String = "") -> FGUIObject:
	var obj := get_from_pool(url)
	return add_child(obj) if obj != null else null


func get_from_pool(url: String = "") -> FGUIObject:
	var actual_url := url if url != "" else default_item
	var obj := item_pool.get_object(actual_url)
	if obj != null:
		obj.visible = true
	return obj


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
	var obj := get_child_at(index) if not _virtual else null
	if obj is FGUIButton:
		obj.selected = true
	if scroll_it_to_view:
		scroll_to_view(index)
	_update_selection_controller(index)


func remove_selection(index: int) -> void:
	_selected_indices.erase(index)
	var obj := get_child_at(index) if index >= 0 and index < children.size() else null
	if obj is FGUIButton:
		obj.selected = false


func clear_selection() -> void:
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


func resize_to_fit(item_count: int = 0, min_size: int = 0) -> void:
	ensure_bounds_correct()
	if layout == FGUIEnums.LIST_LAYOUT_SINGLE_COLUMN:
		height = maxf(min_size, _measure_first_items(item_count, false))
	else:
		width = maxf(min_size, _measure_first_items(item_count, true))


func set_virtual() -> void:
	_virtual = true
	_num_items = 0


func set_virtual_and_loop() -> void:
	set_virtual()


func refresh_virtual_list() -> void:
	if not _virtual:
		return
	if _refreshing_virtual:
		return
	_refreshing_virtual = true
	remove_children_to_pool()
	if _num_items <= 0:
		if scroll_pane != null:
			scroll_pane.set_content_size(0, 0)
		_refreshing_virtual = false
		return
	_ensure_virtual_item_size()
	var horizontal := layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW
	var span := (_virtual_item_size.x + column_gap) if horizontal else (_virtual_item_size.y + line_gap)
	span = maxf(1.0, span)
	var scroll_pos := scroll_pane.pos_x if horizontal and scroll_pane != null else (scroll_pane.pos_y if scroll_pane != null else 0.0)
	var view_size := view_width if horizontal else view_height
	if view_size <= 0.0:
		view_size = width if horizontal else height
	_virtual_first_index = clampi(int(floorf(scroll_pos / span)), 0, maxi(0, _num_items - 1))
	var visible_count := mini(_num_items - _virtual_first_index, int(ceilf(view_size / span)) + 2)
	for offset in visible_count:
		var i := _virtual_first_index + offset
		var url := item_provider.call(i) if item_provider.is_valid() else default_item
		var obj := add_item_from_pool(str(url))
		if obj != null and item_renderer.is_valid():
			item_renderer.call(i, obj)
		if obj != null:
			obj.data = i
			if horizontal:
				obj.set_xy(i * span, 0)
			else:
				obj.set_xy(0, i * span)
	if scroll_pane != null:
		if horizontal:
			scroll_pane.set_content_size(_num_items * span - column_gap, _virtual_item_size.y)
		else:
			scroll_pane.set_content_size(_virtual_item_size.x, _num_items * span - line_gap)
	_refreshing_virtual = false


func scroll_to_view(index: int, animated: bool = false, set_first: bool = false) -> void:
	if _virtual:
		_ensure_virtual_item_size()
		if scroll_pane != null:
			if layout == FGUIEnums.LIST_LAYOUT_SINGLE_ROW:
				scroll_pane.set_pos(index * (_virtual_item_size.x + column_gap), scroll_pane.pos_y, animated)
			else:
				scroll_pane.set_pos(scroll_pane.pos_x, index * (_virtual_item_size.y + line_gap), animated)
			refresh_virtual_list()
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
	buffer.read_i8()
	buffer.read_i8()
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


func update_bounds() -> void:
	_bounds_changed = false
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
	var index := int(item.data) if _virtual and item.data != null else get_child_index(item)
	if index == -1:
		return
	if selection_mode == FGUIEnums.LIST_SELECTION_SINGLE:
		selected_index = index
	elif _selected_indices.has(index):
		remove_selection(index)
	else:
		add_selection(index, scroll_item_to_view_on_click)
	emit_event(FGUIEvents.CLICK_ITEM, item)


func _update_selection_controller(index: int) -> void:
	if selection_controller != null and index < selection_controller.page_count:
		selection_controller.selected_index = index


func _measure_first_items(item_count: int, horizontal: bool) -> float:
	var count := children.size() if item_count <= 0 else mini(item_count, children.size())
	var total := 0.0
	for i in count:
		var child := get_child_at(i)
		total += (child.width if horizontal else child.height)
		if i != count - 1:
			total += (column_gap if horizontal else line_gap)
	return total


func _ensure_virtual_item_size() -> void:
	if _virtual_item_size.x > 0.0 and _virtual_item_size.y > 0.0:
		return
	var obj := get_from_pool(default_item)
	if obj == null:
		_virtual_item_size = Vector2(maxf(1.0, width), maxf(1.0, height))
		return
	_virtual_item_size = Vector2(maxf(1.0, obj.width), maxf(1.0, obj.height))
	return_to_pool(obj)
