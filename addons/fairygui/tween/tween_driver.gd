class_name FGUITweenDriver
extends Node


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	FGUITweenManager.update(delta)
