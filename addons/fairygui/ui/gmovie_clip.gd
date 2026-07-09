class_name FGUIMovieClip
extends FGUIImage

var playing: bool = true
var frame: int = 0
var interval: float = 0.0
var repeat_delay: float = 0.0
var time_scale: float = 1.0


func construct_from_resource() -> void:
	super.construct_from_resource()
	if node != null:
		node.set_process(true)


func get_prop(index: int) -> Variant:
	match index:
		FGUIEnums.OBJECT_PROP_PLAYING:
			return playing
		FGUIEnums.OBJECT_PROP_FRAME:
			return frame
		FGUIEnums.OBJECT_PROP_TIME_SCALE:
			return time_scale
		_:
			return super.get_prop(index)


func set_prop(index: int, value: Variant) -> void:
	match index:
		FGUIEnums.OBJECT_PROP_PLAYING:
			playing = bool(value)
		FGUIEnums.OBJECT_PROP_FRAME:
			frame = int(value)
		FGUIEnums.OBJECT_PROP_TIME_SCALE:
			time_scale = float(value)
		_:
			super.set_prop(index, value)
