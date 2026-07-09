class_name FGUIGearBase
extends RefCounted

var owner: FGUIObject
var controller: FGUIController
var tween_config: Dictionary = {"tween": false, "ease_type": FGUIEaseType.QUAD_OUT, "duration": 0.3, "delay": 0.0}


static func create(owner: FGUIObject, index: int) -> FGUIGearBase:
	match index:
		0:
			return FGUIGearDisplay.new(owner)
		1:
			return FGUIGearXY.new(owner)
		2:
			return FGUIGearSize.new(owner)
		3:
			return FGUIGearLook.new(owner)
		4:
			return FGUIGearColor.new(owner)
		5:
			return FGUIGearAnimation.new(owner)
		6:
			return FGUIGearText.new(owner)
		7:
			return FGUIGearIcon.new(owner)
		8:
			return FGUIGearDisplay2.new(owner)
		9:
			return FGUIGearFontSize.new(owner)
		_:
			return FGUIGearBase.new(owner)


func _init(p_owner: FGUIObject = null) -> void:
	owner = p_owner


func setup(buffer: FGUIByteBuffer) -> void:
	var controller_index := buffer.read_i16()
	if controller_index >= 0 and owner != null and owner.parent != null:
		controller = owner.parent.get_controller_at(controller_index)
	init()
	var count := buffer.read_i16()
	for i in count:
		var page_id = buffer.read_s()
		add_status(page_id, buffer)
	if buffer.read_bool():
		add_status(null, buffer)
	if buffer.read_bool():
		tween_config["tween"] = true
		tween_config["ease_type"] = buffer.read_i8()
		tween_config["duration"] = buffer.read_float32()
		tween_config["delay"] = buffer.read_float32()


func init() -> void:
	pass


func add_status(_page_id: Variant, _buffer: FGUIByteBuffer) -> void:
	pass


func apply() -> void:
	pass


func update_state() -> void:
	pass


func _active_page_id() -> String:
	return controller.selected_page_id if controller != null else ""

