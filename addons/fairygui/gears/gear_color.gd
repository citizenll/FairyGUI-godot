class_name FGUIGearColor
extends FGUIGearBase

var default_value: Dictionary = {}
var storage: Dictionary = {}


func init() -> void:
	default_value = {"color": owner.get_prop(FGUIEnums.OBJECT_PROP_COLOR), "outline": owner.get_prop(FGUIEnums.OBJECT_PROP_OUTLINE_COLOR)}
	storage.clear()


func add_status(page_id: Variant, buffer: FGUIByteBuffer) -> void:
	var value := {"color": buffer.read_color(true), "outline": buffer.read_color(true)}
	if page_id == null:
		default_value = value
	else:
		storage[page_id] = value


func apply() -> void:
	var value: Dictionary = storage.get(_active_page_id(), default_value)
	if _can_tween():
		owner._gear_locked = true
		owner.set_prop(FGUIEnums.OBJECT_PROP_OUTLINE_COLOR, value["outline"])
		owner._gear_locked = false
		var target_color: Color = value["color"]
		var active := _active_tweener()
		if active != null:
			if active.end_value.color.is_equal_approx(target_color):
				return
			_cancel_tween(true)
		var current_color = owner.get_prop(FGUIEnums.OBJECT_PROP_COLOR)
		if current_color is Color and not current_color.is_equal_approx(target_color):
			var tweener := _start_tween(FGUIGTween.to_color(current_color as Color, target_color, float(tween_config.get("duration", 0.3))))
			tweener.set_update_handler(Callable(self, "_on_tween_update"))
			tweener.set_complete_handler(Callable(self, "_on_tween_complete"))
	else:
		_cancel_tween(false)
		owner._gear_locked = true
		owner.set_prop(FGUIEnums.OBJECT_PROP_COLOR, value["color"])
		owner.set_prop(FGUIEnums.OBJECT_PROP_OUTLINE_COLOR, value["outline"])
		owner._gear_locked = false


func update_state() -> void:
	storage[_active_page_id()] = {"color": owner.get_prop(FGUIEnums.OBJECT_PROP_COLOR), "outline": owner.get_prop(FGUIEnums.OBJECT_PROP_OUTLINE_COLOR)}


func _on_tween_update(tweener: FGUIGTweener) -> void:
	if owner == null or owner.is_disposed:
		return
	owner._gear_locked = true
	owner.set_prop(FGUIEnums.OBJECT_PROP_COLOR, tweener.value.color)
	owner._gear_locked = false


func _on_tween_complete(tweener: FGUIGTweener) -> void:
	_finish_tween(tweener)
