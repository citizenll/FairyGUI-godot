class_name FGUITweenValue
extends RefCounted

var x: float = 0.0
var y: float = 0.0
var z: float = 0.0
var w: float = 0.0
var color: Color = Color.WHITE


func set_zero() -> void:
	x = 0.0
	y = 0.0
	z = 0.0
	w = 0.0
	color = Color.TRANSPARENT


func set_value(a: float, b: float = 0.0, c: float = 0.0, d: float = 0.0) -> void:
	x = a
	y = b
	z = c
	w = d


func set_color(value: Variant) -> void:
	if value is Color:
		color = value
		return
	var packed := int(value)
	var alpha := (packed >> 24) & 0xff
	if alpha == 0 and packed <= 0xffffff:
		alpha = 0xff
	color = Color8((packed >> 16) & 0xff, (packed >> 8) & 0xff, packed & 0xff, alpha)


func get_field(index: int) -> float:
	match index:
		0:
			return x
		1:
			return y
		2:
			return z
		3:
			return w
		_:
			return 0.0


func set_field(index: int, value: float) -> void:
	match index:
		0:
			x = value
		1:
			y = value
		2:
			z = value
		3:
			w = value


func copy_from(source: FGUITweenValue) -> void:
	x = source.x
	y = source.y
	z = source.z
	w = source.w
	color = source.color
