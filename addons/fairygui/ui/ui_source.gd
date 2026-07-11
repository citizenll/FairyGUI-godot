class_name FGUIUISource
extends RefCounted

var file_name: String = ""
var loaded: bool = false


func load(_callback: Callable) -> void:
	push_error("FGUIUISource.load must be implemented by the UI source.")


func cancel() -> void:
	pass
