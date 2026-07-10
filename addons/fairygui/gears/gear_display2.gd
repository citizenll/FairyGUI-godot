class_name FGUIGearDisplay2
extends FGUIGearBase

var pages: Array = []
var condition: int = 0
var _visible_count: int = 0


func init() -> void:
	pages.clear()
	_visible_count = 0


func add_status(page_id: Variant, _buffer: FGUIByteBuffer) -> void:
	if page_id != null:
		pages.append(page_id)


func apply() -> void:
	_visible_count = 1 if pages.is_empty() or pages.has(_active_page_id()) else 0


func evaluate(default_visible: bool) -> bool:
	var visible_by_gear := controller == null or _visible_count > 0
	return visible_by_gear and default_visible if condition == 0 else visible_by_gear or default_visible
