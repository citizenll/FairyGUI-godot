class_name FGUIDragDropManager
extends RefCounted

static var inst: FGUIDragDropManager

var agent: FGUILoader
var source_data: Variant


func _init() -> void:
	agent = FGUILoader.new()
	agent.draggable = true
	agent.visible = false
	inst = self


static func get_inst() -> FGUIDragDropManager:
	if inst == null:
		inst = FGUIDragDropManager.new()
	return inst


func start_drag(source: FGUIObject, icon: String, data: Variant = null, touch_point_id: int = -1) -> void:
	source_data = data
	agent.url = icon
	agent.visible = true
	if source != null and source.root != null:
		source.root.add_child(agent)


func cancel() -> void:
	agent.visible = false
	agent.remove_from_parent()
	source_data = null
