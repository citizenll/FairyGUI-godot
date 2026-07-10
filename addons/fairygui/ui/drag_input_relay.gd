class_name FGUIDragInputRelay
extends Node

var target: FGUIObject


func _ready() -> void:
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if target == null:
		queue_free()
		return
	target._on_global_drag_input(event)
