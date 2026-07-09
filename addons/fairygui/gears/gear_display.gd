class_name FGUIGearDisplay
extends FGUIGearBase

var pages: Array = []
var connected: bool = true


func add_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	if page_id != null:
		pages.append(page_id)


func apply() -> void:
	connected = pages.is_empty() or pages.has(_active_page_id())
	if owner != null:
		owner._internal_visible = connected
		owner._handle_visible_changed()


func update_state() -> void:
	pass

