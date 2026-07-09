class_name FGUIGearDisplay2
extends FGUIGearDisplay

var condition: int = 0


func add_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	super.add_status(page_id, buffer)


func evaluate(default_visible: bool) -> bool:
	var selected := pages.has(_active_page_id())
	return default_visible and selected if condition == 0 else default_visible or selected

