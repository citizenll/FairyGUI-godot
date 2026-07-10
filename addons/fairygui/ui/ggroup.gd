class_name FGUIGroup
extends FGUIObject

var layout: int = FGUIEnums.GROUP_LAYOUT_NONE
var line_gap: int = 0
var column_gap: int = 0
var exclude_invisibles: bool = false
var auto_size_disabled: bool = false
var main_grid_index: int = -1
var main_grid_min_size: int = 50

var _bounds_changed: bool = false
var _updating: int = 0


func set_bounds_changed_flag(_position_changed_only: bool = false) -> void:
	_bounds_changed = true


func _handle_visible_changed() -> void:
	super._handle_visible_changed()
	if parent == null:
		return
	for child: FGUIObject in parent.children:
		if child.group == self:
			child._handle_visible_changed()


func ensure_size_correct() -> void:
	ensure_bounds_correct()


func ensure_bounds_correct() -> void:
	if parent == null or not _bounds_changed:
		return
	_bounds_changed = false
	if layout != FGUIEnums.GROUP_LAYOUT_NONE:
		_handle_layout()
	_update_bounds()


func move_children(dx: float, dy: float) -> void:
	if parent == null:
		return
	for child: FGUIObject in parent.children:
		if child.group == self:
			child.set_xy(child.x + dx, child.y + dy)


func resize_children(dw: float, dh: float) -> void:
	if parent == null:
		return
	for child: FGUIObject in parent.children:
		if child.group == self:
			child.set_size(child.width + dw, child.height + dh)


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


func _handle_layout() -> void:
	if parent == null:
		return
	var current := Vector2(x, y)
	for child: FGUIObject in parent.children:
		if child.group != self:
			continue
		if exclude_invisibles and not child.internal_visible3:
			continue
		child.set_xy(current.x, current.y)
		if layout == FGUIEnums.GROUP_LAYOUT_HORIZONTAL:
			current.x += child.width + column_gap
		elif layout == FGUIEnums.GROUP_LAYOUT_VERTICAL:
			current.y += child.height + line_gap


func _update_bounds() -> void:
	if parent == null:
		return
	var rect := Rect2()
	var initialized := false
	for child: FGUIObject in parent.children:
		if child.group != self:
			continue
		if exclude_invisibles and not child.internal_visible3:
			continue
		var child_rect := Rect2(child.x, child.y, child.width, child.height)
		rect = child_rect if not initialized else rect.merge(child_rect)
		initialized = true
	if initialized:
		set_xy(rect.position.x, rect.position.y)
		set_size(rect.size.x, rect.size.y)
