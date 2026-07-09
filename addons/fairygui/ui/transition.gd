class_name FGUITransition
extends RefCounted

var owner: FGUIComponent
var name: String = ""
var playing: bool = false
var time_scale: float = 1.0
var raw_items: Array = []


func _init(p_owner: FGUIComponent = null) -> void:
	owner = p_owner


func play(on_complete: Callable = Callable(), times: int = 1, delay: float = 0.0) -> void:
	playing = true
	if delay > 0.0 and owner != null and owner.node != null:
		await owner.node.get_tree().create_timer(delay).timeout
	playing = false
	if on_complete.is_valid():
		on_complete.call()


func stop(set_to_complete: bool = false, process_callback: bool = false) -> void:
	playing = false


func setup(buffer: FGUIByteBuffer) -> void:
	name = _string_or_empty(buffer.read_s())
	var count := buffer.read_i16()
	for i in count:
		var next_pos := buffer.read_i16() + buffer.pos
		raw_items.append({"pos": buffer.pos})
		buffer.pos = next_pos


func _string_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)
