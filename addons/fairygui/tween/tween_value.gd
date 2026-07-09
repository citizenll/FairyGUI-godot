class_name FGUITweenValue
extends RefCounted

var x: float = 0.0
var y: float = 0.0
var z: float = 0.0
var w: float = 0.0


func set_zero() -> void:
	x = 0.0
	y = 0.0
	z = 0.0
	w = 0.0


func set_value(a: float, b: float = 0.0, c: float = 0.0, d: float = 0.0) -> void:
	x = a
	y = b
	z = c
	w = d

