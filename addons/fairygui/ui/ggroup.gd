class_name FGUIGroup
extends FGUIObject

var layout: int = FGUIEnums.GROUP_LAYOUT_NONE:
	set(value):
		if layout == value:
			return
		layout = value
		set_bounds_changed_flag()
var line_gap: int = 0:
	set(value):
		if line_gap == value:
			return
		line_gap = value
		set_bounds_changed_flag(true)
var column_gap: int = 0:
	set(value):
		if column_gap == value:
			return
		column_gap = value
		set_bounds_changed_flag(true)
var exclude_invisibles: bool = false:
	set(value):
		if exclude_invisibles == value:
			return
		exclude_invisibles = value
		set_bounds_changed_flag()
var auto_size_disabled: bool = false
var main_grid_index: int = -1:
	set(value):
		if main_grid_index == value:
			return
		main_grid_index = value
		set_bounds_changed_flag()
var main_grid_min_size: int = 50:
	set(value):
		if main_grid_min_size == value:
			return
		main_grid_min_size = value
		set_bounds_changed_flag()

var _bounds_changed: bool = false
var _percent_ready: bool = false
var _main_child_index: int = -1
var _total_size: float = 0.0
var _num_children: int = 0
var _updating: int = 0


func _create_display_object() -> void:
	super._create_display_object()
	# GGroup is a logical layout object. Its bounds must never block the
	# controls it groups, even when the package leaves touchable enabled.
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _handle_touchable_changed() -> void:
	if node != null:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE


func dispose() -> void:
	_bounds_changed = false
	super.dispose()


func set_bounds_changed_flag(position_changed_only: bool = false) -> void:
	if _updating != 0 or parent == null:
		return
	if not position_changed_only:
		_percent_ready = false
	if _bounds_changed:
		return
	_bounds_changed = true
	if layout != FGUIEnums.GROUP_LAYOUT_NONE:
		call_deferred("ensure_bounds_correct")


func _handle_alpha_changed() -> void:
	super._handle_alpha_changed()
	if _under_construct or parent == null:
		return
	for child: FGUIObject in parent.children:
		if child.group == self:
			child.alpha = alpha


func _handle_visible_changed() -> void:
	super._handle_visible_changed()
	if parent == null:
		return
	for child: FGUIObject in parent.children:
		if child.group == self:
			child._handle_visible_changed()


func ensure_size_correct() -> void:
	if parent == null or not _bounds_changed or layout == FGUIEnums.GROUP_LAYOUT_NONE:
		return
	_bounds_changed = false
	if auto_size_disabled:
		resize_children(0.0, 0.0)
	else:
		_handle_layout()
		_update_bounds()


func ensure_bounds_correct() -> void:
	if parent == null or not _bounds_changed:
		return
	_bounds_changed = false
	if layout == FGUIEnums.GROUP_LAYOUT_NONE:
		_update_bounds()
	elif auto_size_disabled:
		resize_children(0.0, 0.0)
	else:
		_handle_layout()
		_update_bounds()


func move_children(dx: float, dy: float) -> void:
	if (_updating & 1) != 0 or parent == null:
		return
	_updating |= 1
	for child: FGUIObject in parent.children:
		if child.group == self:
			child.set_xy(child.x + dx, child.y + dy)
	_updating &= 2


func resize_children(dw: float, dh: float) -> void:
	if layout == FGUIEnums.GROUP_LAYOUT_NONE or (_updating & 2) != 0 or parent == null:
		return
	_updating |= 2
	if _bounds_changed:
		_bounds_changed = false
		if not auto_size_disabled:
			_update_bounds()
			return

	if not _percent_ready:
		_percent_ready = true
		_num_children = 0
		_total_size = 0.0
		_main_child_index = -1
		var group_child_index := 0
		for child_index in parent.num_children:
			var child := parent.get_child_at(child_index)
			if child.group != self:
				continue
			if not exclude_invisibles or child.internal_visible3:
				if group_child_index == main_grid_index:
					_main_child_index = child_index
				_num_children += 1
				_total_size += child.width if layout == FGUIEnums.GROUP_LAYOUT_HORIZONTAL else child.height
			group_child_index += 1

		if _main_child_index != -1:
			var main_child := parent.get_child_at(_main_child_index)
			var main_size := main_child.width if layout == FGUIEnums.GROUP_LAYOUT_HORIZONTAL else main_child.height
			_total_size += float(main_grid_min_size) - main_size
			main_child._size_percent_in_group = float(main_grid_min_size) / _total_size if _total_size > 0.0 else 0.0

		for child_index in parent.num_children:
			var child := parent.get_child_at(child_index)
			if child.group != self or child_index == _main_child_index:
				continue
			var child_size := child.width if layout == FGUIEnums.GROUP_LAYOUT_HORIZONTAL else child.height
			child._size_percent_in_group = child_size / _total_size if _total_size > 0.0 else 0.0

	var remain_size: float
	var remain_percent := 1.0
	var prior_handled := false
	if layout == FGUIEnums.GROUP_LAYOUT_HORIZONTAL:
		remain_size = width - float(_num_children - 1) * float(column_gap)
		if _main_child_index != -1 and remain_size >= _total_size:
			var main_child := parent.get_child_at(_main_child_index)
			main_child.set_size(remain_size - (_total_size - float(main_grid_min_size)), main_child._raw_height + dh, true)
			remain_size -= main_child.width
			remain_percent -= main_child._size_percent_in_group
			prior_handled = true
		var cur_x := x
		for child_index in parent.num_children:
			var child := parent.get_child_at(child_index)
			if child.group != self:
				continue
			if exclude_invisibles and not child.internal_visible3:
				child.set_size(child._raw_width, child._raw_height + dh, true)
				continue
			if not prior_handled or child_index != _main_child_index:
				var child_width := roundi(child._size_percent_in_group / remain_percent * remain_size) if remain_percent > 0.0 else 0.0
				child.set_size(child_width, child._raw_height + dh, true)
				remain_percent -= child._size_percent_in_group
				remain_size -= child.width
			child.x_min = cur_x
			if child.width != 0.0:
				cur_x += child.width + float(column_gap)
	else:
		remain_size = height - float(_num_children - 1) * float(line_gap)
		if _main_child_index != -1 and remain_size >= _total_size:
			var main_child := parent.get_child_at(_main_child_index)
			main_child.set_size(main_child._raw_width + dw, remain_size - (_total_size - float(main_grid_min_size)), true)
			remain_size -= main_child.height
			remain_percent -= main_child._size_percent_in_group
			prior_handled = true
		var cur_y := y
		for child_index in parent.num_children:
			var child := parent.get_child_at(child_index)
			if child.group != self:
				continue
			if exclude_invisibles and not child.internal_visible3:
				child.set_size(child._raw_width + dw, child._raw_height, true)
				continue
			if not prior_handled or child_index != _main_child_index:
				var child_height := roundi(child._size_percent_in_group / remain_percent * remain_size) if remain_percent > 0.0 else 0.0
				child.set_size(child._raw_width + dw, child_height, true)
				remain_percent -= child._size_percent_in_group
				remain_size -= child.height
			child.y_min = cur_y
			if child.height != 0.0:
				cur_y += child.height + float(line_gap)
	_updating &= 1


func setup_before_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_before_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 5):
		return
	layout = buffer.read_i8()
	line_gap = buffer.read_i32()
	column_gap = buffer.read_i32()
	if buffer.version >= 2:
		exclude_invisibles = buffer.read_bool()
		auto_size_disabled = buffer.read_bool()
		main_grid_index = buffer.read_i16()


func setup_after_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_after_add(buffer, begin_pos)
	if not visible:
		_handle_visible_changed()


func _handle_layout() -> void:
	if parent == null:
		return
	_updating |= 1
	if layout == FGUIEnums.GROUP_LAYOUT_HORIZONTAL:
		var cur_x := x
		for child: FGUIObject in parent.children:
			if child.group != self or (exclude_invisibles and not child.internal_visible3):
				continue
			child.x_min = cur_x
			if child.width != 0.0:
				cur_x += child.width + float(column_gap)
	elif layout == FGUIEnums.GROUP_LAYOUT_VERTICAL:
		var cur_y := y
		for child: FGUIObject in parent.children:
			if child.group != self or (exclude_invisibles and not child.internal_visible3):
				continue
			child.y_min = cur_y
			if child.height != 0.0:
				cur_y += child.height + float(line_gap)
	_updating &= 2


func _update_bounds() -> void:
	if parent == null:
		return
	var min_position := Vector2(INF, INF)
	var max_position := Vector2(-INF, -INF)
	var has_child := false
	for child: FGUIObject in parent.children:
		if child.group != self or (exclude_invisibles and not child.internal_visible3):
			continue
		min_position.x = minf(min_position.x, child.x_min)
		min_position.y = minf(min_position.y, child.y_min)
		max_position.x = maxf(max_position.x, child.x_min + child.width)
		max_position.y = maxf(max_position.y, child.y_min + child.height)
		has_child = true
	var next_width := max_position.x - min_position.x if has_child else 0.0
	var next_height := max_position.y - min_position.y if has_child else 0.0
	if has_child:
		_updating |= 1
		set_xy(min_position.x, min_position.y)
		_updating &= 2
	if (_updating & 2) == 0:
		_updating |= 2
		set_size(next_width, next_height)
		_updating &= 1
	else:
		_updating &= 1
		resize_children(width - next_width, height - next_height)
