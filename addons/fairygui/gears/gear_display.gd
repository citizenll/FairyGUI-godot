class_name FGUIGearDisplay
extends FGUIGearBase

var pages: Array = []
var _visible_count: int = 0
var _display_lock_token: int = 1
var connected: bool:
	get:
		return controller == null or _visible_count > 0


func init() -> void:
	pages.clear()
	_visible_count = 0


func add_status(page_id: Variant, _buffer: FGUIByteBuffer) -> void:
	if page_id != null:
		pages.append(page_id)


func apply() -> void:
	_display_lock_token += 1
	if _display_lock_token == 0:
		_display_lock_token = 1
	_visible_count = 1 if pages.is_empty() or pages.has(_active_page_id()) else 0


func add_lock() -> int:
	_visible_count += 1
	return _display_lock_token


func release_lock(token: int) -> void:
	if token == _display_lock_token and _visible_count > 0:
		_visible_count -= 1


func update_state() -> void:
	pass
