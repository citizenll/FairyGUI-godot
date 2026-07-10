class_name FGUIMovieClip
extends FGUIImage

var playing: bool:
	get:
		return _playing
	set(value):
		if _playing == value:
			return
		_playing = value
		_update_timer()
		update_gear(5)
var frame: int:
	get:
		return _frame
	set(value):
		var next_frame := maxi(0, value)
		if not _frames.is_empty():
			next_frame = clampi(next_frame, 0, _frames.size() - 1)
		if _frame == next_frame:
			return
		_frame = next_frame
		_frame_elapsed = 0.0
		_apply_frame()
		update_gear(5)
var interval: float = 0.0
var repeat_delay: float = 0.0
var time_scale: float:
	get:
		return _time_scale
	set(value):
		_time_scale = maxf(0.0001, value)
		_update_timer()
var swing: bool = false
var frames: Array:
	get:
		return _frames
	set(value):
		_frames = value.duplicate()
		if _frames.is_empty():
			_frame = 0
			_play_end = -1
			_play_end_at = -1
		else:
			_frame = clampi(_frame, 0, _frames.size() - 1)
			if _play_end < 0 or _play_end >= _frames.size():
				_play_end = _frames.size() - 1
			if _play_end_at < 0 or _play_end_at >= _frames.size():
				_play_end_at = _play_end
		_frame_elapsed = 0.0
		_reversed = false
		_repeated_count = 0
		_apply_frame()
		_update_timer()

var _playing: bool = true
var _frame: int = 0
var _time_scale: float = 1.0
var _frames: Array = []
var _timer: Timer
var _reversed: bool = false
var _repeated_count: int = 0
var _frame_elapsed: float = 0.0
var _play_start: int = 0
var _play_end: int = -1
var _play_times: int = 0
var _play_end_at: int = -1
var _play_status: int = 0


func _create_display_object() -> void:
	super._create_display_object()
	image_node.tree_entered.connect(_on_node_entered_tree)
	image_node.tree_exiting.connect(_on_node_exiting_tree)


func construct_from_resource() -> void:
	if package_item == null:
		return
	content_item = package_item.get_branch()
	source_width = content_item.width
	source_height = content_item.height
	init_width = source_width
	init_height = source_height
	content_item.load()
	interval = float(content_item.interval) / 1000.0
	repeat_delay = float(content_item.repeat_delay) / 1000.0
	swing = content_item.swing
	frames = content_item.frames
	set_size(source_width, source_height)
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
			advance(float(value) / 1000.0)
		_:
			super.set_prop(index, value)


func rewind() -> void:
	_frame = 0
	_frame_elapsed = 0.0
	_reversed = false
	_repeated_count = 0
	_apply_frame()


func sync_status(other: FGUIMovieClip) -> void:
	if other == null:
		return
	_frame = other._frame
	_frame_elapsed = other._frame_elapsed
	_reversed = other._reversed
	_repeated_count = other._repeated_count
	_apply_frame()


func set_play_settings(start: int = 0, end_frame: int = -1, times: int = 0, end_at: int = -1) -> void:
	_play_start = maxi(0, start)
	_play_end = end_frame
	if _play_end < 0 or _play_end >= _frames.size():
		_play_end = _frames.size() - 1
	_play_times = maxi(0, times)
	_play_end_at = end_at if end_at >= 0 else _play_end
	if not _frames.is_empty():
		_play_start = clampi(_play_start, 0, _frames.size() - 1)
		_play_end_at = clampi(_play_end_at, 0, _frames.size() - 1)
	_play_status = 0
	frame = _play_start


func advance(time: float) -> void:
	if _frames.is_empty():
		return
	var begin_frame := _frame
	var begin_reversed := _reversed
	var remaining := maxf(0.0, time)
	var backup_time := remaining
	while true:
		var frame_duration := _get_frame_duration()
		if frame_duration <= 0.0:
			_step_frame()
			_frame_elapsed = 0.0
			break
		if remaining < frame_duration:
			_frame_elapsed = 0.0
			break
		remaining -= frame_duration
		_step_frame()
		if _frame == begin_frame and _reversed == begin_reversed:
			var round_time := backup_time - remaining
			if round_time > 0.0:
				remaining -= floorf(remaining / round_time) * round_time
	_apply_frame()


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
	if playing and _play_status != 3 and _frames.size() > 1 and node != null and node.is_inside_tree():
		_timer.start(_current_frame_delay())
	else:
		_timer.stop()


func _current_frame_delay() -> float:
	if _frames.is_empty():
		return 0.1
	return maxf(0.001, _get_frame_duration() / time_scale)


func _on_timer_timeout() -> void:
	if not playing or _frames.is_empty() or _play_status == 3:
		return
	_advance_playback_frame()
	_apply_frame()
	_update_timer()


func _on_node_entered_tree() -> void:
	call_deferred("_update_timer")


func _on_node_exiting_tree() -> void:
	if _timer != null:
		_timer.stop()


func _get_frame_duration() -> float:
	if _frames.is_empty():
		return 0.0
	var frame_data: Dictionary = _frames[clampi(_frame, 0, _frames.size() - 1)]
	var delay := interval + float(frame_data.get("add_delay", 0)) / 1000.0
	if _frame == 0 and _repeated_count > 0:
		delay += repeat_delay
	return delay


func _step_frame() -> void:
	if swing:
		if _reversed:
			_frame -= 1
			if _frame <= 0:
				_frame = 0
				_repeated_count += 1
				_reversed = not _reversed
		else:
			_frame += 1
			if _frame > _frames.size() - 1:
				_frame = maxi(0, _frames.size() - 2)
				_repeated_count += 1
				_reversed = not _reversed
	else:
		_frame += 1
		if _frame > _frames.size() - 1:
			_frame = 0
			_repeated_count += 1


func _advance_playback_frame() -> void:
	_step_frame()
	if _play_status == 1:
		_frame = _play_start
		_frame_elapsed = 0.0
		_play_status = 0
	elif _play_status == 2:
		_frame = _play_end_at
		_frame_elapsed = 0.0
		_play_status = 3
	elif _frame == _play_end:
		if _play_times > 0:
			_play_times -= 1
			_play_status = 2 if _play_times == 0 else 1
		elif _play_start != 0:
			_play_status = 1


func _apply_frame() -> void:
	if image_node == null or _frames.is_empty():
		return
	_frame = clampi(_frame, 0, _frames.size() - 1)
	var frame_data: Dictionary = _frames[_frame]
	var texture_value: Variant = frame_data.get("texture")
	image_node.texture = texture_value if texture_value is Texture2D else null
