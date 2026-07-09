class_name FGUIMovieClip
extends FGUIImage

var playing: bool = true:
	set(value):
		playing = value
		_update_timer()
var frame: int = 0:
	set(value):
		frame = maxi(0, value)
		_apply_frame()
var interval: float = 0.0
var repeat_delay: float = 0.0
var time_scale: float = 1.0:
	set(value):
		time_scale = maxf(0.0001, value)
		_update_timer()
var swing: bool = false
var frames: Array = []

var _timer: Timer
var _reversed: bool = false


func construct_from_resource() -> void:
	if package_item == null:
		return
	content_item = package_item.get_branch()
	source_width = content_item.width
	source_height = content_item.height
	init_width = source_width
	init_height = source_height
	content_item.load()
	frames = content_item.frames
	interval = float(content_item.interval) / 1000.0
	repeat_delay = float(content_item.repeat_delay) / 1000.0
	swing = content_item.swing
	set_size(source_width, source_height)
	_apply_frame()
	_ensure_timer()
	_update_timer()


func dispose() -> void:
	if _timer != null:
		_timer.queue_free()
		_timer = null
	super.dispose()


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
		FGUIEnums.OBJECT_PROP_DELTA_TIME:
			_advance(float(value) / 1000.0)
		_:
			super.set_prop(index, value)


func _ensure_timer() -> void:
	if _timer != null or node == null:
		return
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	node.add_child(_timer)


func _update_timer() -> void:
	if _timer == null:
		return
	if playing and frames.size() > 1 and node != null and node.is_inside_tree():
		_timer.start(_current_frame_delay())
	else:
		_timer.stop()


func _current_frame_delay() -> float:
	if frames.is_empty():
		return 0.1
	var frame_data: Dictionary = frames[clampi(frame, 0, frames.size() - 1)]
	var delay := interval + float(frame_data.get("add_delay", 0)) / 1000.0
	if frame == frames.size() - 1:
		delay += repeat_delay
	return maxf(0.001, delay / time_scale)


func _on_timer_timeout() -> void:
	_advance(_current_frame_delay())
	_update_timer()


func _advance(_delta: float) -> void:
	if frames.is_empty():
		return
	if swing:
		if _reversed:
			frame -= 1
			if frame <= 0:
				frame = 0
				_reversed = false
		else:
			frame += 1
			if frame >= frames.size() - 1:
				frame = frames.size() - 1
				_reversed = true
	else:
		frame = (frame + 1) % frames.size()


func _apply_frame() -> void:
	if image_node == null or frames.is_empty():
		return
	frame = clampi(frame, 0, frames.size() - 1)
	var frame_data: Dictionary = frames[frame]
	var texture: Texture2D = frame_data.get("texture")
	if texture != null:
		image_node.texture = texture
