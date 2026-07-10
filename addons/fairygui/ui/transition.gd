class_name FGUITransition
extends RefCounted

const ACTION_XY := 0
const ACTION_SIZE := 1
const ACTION_SCALE := 2
const ACTION_PIVOT := 3
const ACTION_ALPHA := 4
const ACTION_ROTATION := 5
const ACTION_COLOR := 6
const ACTION_ANIMATION := 7
const ACTION_VISIBLE := 8
const ACTION_SOUND := 9
const ACTION_TRANSITION := 10
const ACTION_SHAKE := 11
const ACTION_COLOR_FILTER := 12
const ACTION_SKEW := 13
const ACTION_TEXT := 14
const ACTION_ICON := 15

const OPTION_IGNORE_DISPLAY_CONTROLLER := 1
const OPTION_AUTO_STOP_DISABLED := 2
const OPTION_AUTO_STOP_AT_END := 4

var owner: FGUIComponent
var name: String = ""
var playing: bool = false
var paused: bool = false
var raw_items: Array = []

var time_scale: float:
	get:
		return _time_scale
	set(value):
		_time_scale = maxf(0.0001, value)
		for tween in _active_tweens:
			if is_instance_valid(tween):
				tween.set_speed_scale(_time_scale)
		for transition: FGUITransition in _active_child_transitions:
			if is_instance_valid(transition):
				transition.time_scale = _time_scale
		if playing:
			for item in _items:
				if int(item.get("type", -1)) != ACTION_ANIMATION:
					continue
				var target: FGUIObject = item.get("target")
				if target != null:
					target.set_prop(FGUIEnums.OBJECT_PROP_TIME_SCALE, _time_scale)

var total_duration: float:
	get:
		return _total_duration

var _items: Array[Dictionary] = []
var _options: int = 0
var _auto_play: bool = false
var _auto_play_times: int = 1
var _auto_play_delay: float = 0.0
var _time_scale: float = 1.0
var _total_duration: float = 0.0
var _total_times: int = 1
var _start_time: float = 0.0
var _end_time: float = -1.0
var _reversed: bool = false
var _owner_base: Vector2 = Vector2.ZERO
var _on_complete: Callable
var _play_id: int = 0
var _active_tweens: Array[Tween] = []
var _active_child_transitions: Array[FGUITransition] = []


func _init(p_owner: FGUIComponent = null) -> void:
	owner = p_owner


func play(on_complete: Callable = Callable(), times: int = 1, delay: float = 0.0, start_time: float = 0.0, end_time: float = -1.0) -> void:
	_play(on_complete, times, delay, start_time, end_time, false)


func play_reverse(on_complete: Callable = Callable(), times: int = 1, delay: float = 0.0, start_time: float = 0.0, end_time: float = -1.0) -> void:
	_play(on_complete, times, delay, start_time, end_time, true)


func change_play_times(value: int) -> void:
	_total_times = value


func set_auto_play(value: bool, times: int = -1, delay: float = 0.0) -> void:
	_auto_play = value
	_auto_play_times = times
	_auto_play_delay = delay
	if _auto_play and owner != null and owner.node != null and owner.node.is_inside_tree():
		play(Callable(), _auto_play_times, _auto_play_delay)
	elif not _auto_play:
		stop(false, true)


func stop(set_to_complete: bool = true, process_callback: bool = false) -> void:
	if not playing:
		return
	_play_id += 1
	playing = false
	paused = false
	for tween in _active_tweens:
		if is_instance_valid(tween):
			tween.kill()
	_active_tweens.clear()
	for item in _items:
		if int(item["type"]) == ACTION_SHAKE:
			_reset_shake(item)
	var child_transitions := _active_child_transitions.duplicate()
	_active_child_transitions.clear()
	for transition: FGUITransition in child_transitions:
		if is_instance_valid(transition):
			transition.stop(set_to_complete, false)
	_release_display_locks()
	if set_to_complete:
		_apply_complete_state()
	var callback := _on_complete
	_on_complete = Callable()
	if process_callback and callback.is_valid():
		callback.call()


func set_paused(value: bool) -> void:
	if not playing or paused == value:
		return
	paused = value
	for tween in _active_tweens:
		if not is_instance_valid(tween):
			continue
		if paused:
			tween.pause()
		else:
			tween.play()
	for transition: FGUITransition in _active_child_transitions:
		if is_instance_valid(transition):
			transition.set_paused(value)
	for item in _items:
		if int(item.get("type", -1)) != ACTION_ANIMATION:
			continue
		var target: FGUIObject = item.get("target")
		if target == null:
			continue
		var animation_value: Dictionary = item.get("value", {})
		if paused:
			animation_value["flag"] = bool(target.get_prop(FGUIEnums.OBJECT_PROP_PLAYING))
			target.set_prop(FGUIEnums.OBJECT_PROP_PLAYING, false)
		else:
			target.set_prop(FGUIEnums.OBJECT_PROP_PLAYING, bool(animation_value.get("flag", true)))


func dispose() -> void:
	stop(false, false)
	_on_complete = Callable()
	_active_child_transitions.clear()
	for item in _items:
		item["target"] = null
		item["hook"] = Callable()
		if item.has("tween_config") and item["tween_config"] != null:
			item["tween_config"]["end_hook"] = Callable()
	_items.clear()
	raw_items = _items
	owner = null


func set_value(label: String, a: Variant = null, b: Variant = null, c: Variant = null, d: Variant = null) -> void:
	var args := [a, b, c, d]
	var found := false
	for item in _items:
		var value: Dictionary
		if item.get("label", "") == label:
			value = item["tween_config"]["start_value"] if item.get("tween_config") != null else item["value"]
		elif item.get("tween_config") != null and item["tween_config"].get("end_label", "") == label:
			value = item["tween_config"]["end_value"]
		else:
			continue
		found = true
		_set_decoded_value_args(item["type"], value, args)
	if not found:
		push_error("FairyGUI transition label not found: %s" % label)


func set_hook(label: String, callback: Callable) -> void:
	var found := false
	for item in _items:
		if item.get("label", "") == label:
			item["hook"] = callback
			found = true
			break
		if item.get("tween_config") != null and item["tween_config"].get("end_label", "") == label:
			item["tween_config"]["end_hook"] = callback
			found = true
			break
	if not found:
		push_error("FairyGUI transition label not found: %s" % label)


func clear_hooks() -> void:
	for item in _items:
		item["hook"] = Callable()
		if item.get("tween_config") != null:
			item["tween_config"]["end_hook"] = Callable()


func set_target(label: String, new_target: FGUIObject) -> void:
	var found := false
	for item in _items:
		if item.get("label", "") != label:
			continue
		item["target_id"] = "" if new_target == null or new_target == owner else new_target.id
		item["target"] = new_target if playing else null
		found = true
	if not found:
		push_error("FairyGUI transition label not found: %s" % label)


func set_duration(label: String, value: float) -> void:
	var found := false
	for item in _items:
		if item.get("label", "") == label and item.get("tween_config") != null:
			item["tween_config"]["duration"] = maxf(0.0, value)
			found = true
	if not found:
		push_error("FairyGUI transition label not found: %s" % label)
	_recalculate_total_duration()


func get_label_time(label: String) -> float:
	for item in _items:
		if item.get("label", "") == label:
			return item["time"]
		if item.get("tween_config") != null and item["tween_config"].get("end_label", "") == label:
			return item["time"] + item["tween_config"]["duration"]
	return NAN


func update_from_relations(target_id: String, dx: float, dy: float) -> void:
	for item in _items:
		if item["type"] != ACTION_XY or item.get("target_id", "") != target_id:
			continue
		if item.get("tween_config") != null:
			var start_value: Dictionary = item["tween_config"]["start_value"]
			var end_value: Dictionary = item["tween_config"]["end_value"]
			if not bool(start_value.get("b3", false)):
				start_value["f1"] = float(start_value.get("f1", 0.0)) + dx
				start_value["f2"] = float(start_value.get("f2", 0.0)) + dy
			if not bool(end_value.get("b3", false)):
				end_value["f1"] = float(end_value.get("f1", 0.0)) + dx
				end_value["f2"] = float(end_value.get("f2", 0.0)) + dy
		elif not bool(item["value"].get("b3", false)):
			item["value"]["f1"] = float(item["value"].get("f1", 0.0)) + dx
			item["value"]["f2"] = float(item["value"].get("f2", 0.0)) + dy


func on_owner_added_to_stage() -> void:
	if _auto_play and not playing:
		play(Callable(), _auto_play_times, _auto_play_delay)


func on_owner_removed_from_stage() -> void:
	if (_options & OPTION_AUTO_STOP_DISABLED) == 0:
		stop((_options & OPTION_AUTO_STOP_AT_END) != 0, false)


func setup(buffer: FGUIByteBuffer) -> void:
	name = _string_or_empty(buffer.read_s())
	_options = buffer.read_i32()
	_auto_play = buffer.read_bool()
	_auto_play_times = buffer.read_i32()
	_auto_play_delay = buffer.read_float32()

	var count := buffer.read_i16()
	for i in count:
		var data_len := buffer.read_i16()
		var cur_pos := buffer.pos
		buffer.seek(cur_pos, 0)

		var item := {
			"type": buffer.read_i8(),
			"time": buffer.read_float32(),
			"target_id": "",
			"target": null,
			"label": "",
			"value": {},
			"tween_config": null,
			"hook": Callable(),
			"display_lock_token": 0
		}
		var target_index := buffer.read_i16()
		if target_index >= 0 and owner != null:
			var target := owner.get_child_at(target_index)
			if target != null:
				item["target_id"] = target.id
		item["label"] = _string_or_empty(buffer.read_s())

		if buffer.read_bool():
			buffer.seek(cur_pos, 1)
			var tween_config := {
				"duration": buffer.read_float32(),
				"ease_type": buffer.read_i8(),
				"repeat": buffer.read_i32(),
				"yoyo": buffer.read_bool(),
				"end_label": _string_or_empty(buffer.read_s()),
				"start_value": {"b1": true, "b2": true},
				"end_value": {"b1": true, "b2": true},
				"end_hook": Callable(),
				"path": null
			}
			_total_duration = maxf(_total_duration, item["time"] + tween_config["duration"])
			buffer.seek(cur_pos, 2)
			_decode_value(item, buffer, tween_config["start_value"])
			buffer.seek(cur_pos, 3)
			_decode_value(item, buffer, tween_config["end_value"])
			if buffer.version >= 2:
				tween_config["path"] = _read_path(buffer)
			item["tween_config"] = tween_config
		else:
			_total_duration = maxf(_total_duration, item["time"])
			buffer.seek(cur_pos, 2)
			_decode_value(item, buffer, item["value"])

		_items.append(item)
		buffer.pos = cur_pos + data_len
	raw_items = _items


func _play(on_complete: Callable, times: int, delay: float, start_time: float, end_time: float, reversed: bool) -> void:
	if playing:
		stop(true, true)
	_total_times = times
	_reversed = reversed
	_start_time = maxf(0.0, start_time)
	_end_time = end_time
	_on_complete = on_complete
	paused = false
	playing = true
	_play_id += 1
	_resolve_targets()
	var token := _play_id
	_start_after_delay.call_deferred(token, maxf(0.0, delay))


func _start_after_delay(token: int, delay: float) -> void:
	if token != _play_id or not playing:
		return
	if not _has_tree():
		_apply_complete_state()
		_finish_playback(token)
		return
	if delay > 0.0:
		var delay_tween := _make_tween()
		if delay_tween == null:
			_apply_complete_state()
			_finish_playback(token)
			return
		delay_tween.tween_interval(delay)
		delay_tween.finished.connect(Callable(self, "_on_start_delay_finished").bind(token, delay_tween))
		return
	_internal_play(token)


func _on_start_delay_finished(token: int, tween: Tween) -> void:
	_active_tweens.erase(tween)
	if token != _play_id or not playing:
		return
	_internal_play(token)


func _internal_play(token: int) -> void:
	_owner_base = Vector2(owner.x, owner.y) if owner != null else Vector2.ZERO
	_acquire_display_locks()
	var scheduled := 0
	var need_skip_animations := false
	var indices := range(_items.size())
	if _reversed:
		indices = range(_items.size() - 1, -1, -1)
	for i in indices:
		var item: Dictionary = _items[i]
		if item.get("target") == null:
			continue
		if not _reversed and int(item["type"]) == ACTION_ANIMATION and _start_time > 0.0 and float(item["time"]) <= _start_time:
			need_skip_animations = true
			continue
		if _schedule_item(item, token):
			scheduled += 1
	if need_skip_animations:
		_skip_animations()
	if scheduled == 0:
		_check_all_complete(token)


func _schedule_item(item: Dictionary, token: int) -> bool:
	var config = item.get("tween_config")
	var action_time := _get_item_play_time(item)
	if int(item["type"]) == ACTION_SHAKE:
		return _schedule_shake(item, token, action_time)
	if config != null:
		var duration := float(config["duration"])
		var repeat := int(config.get("repeat", 0))
		var total_span := _get_tween_total_span(duration, repeat)
		var offset := maxf(0.0, _start_time - action_time)
		var end_limit := _end_time if _end_time >= 0.0 else INF
		if action_time > end_limit:
			return false
		if total_span < INF and offset >= total_span:
			var complete_start := _get_tween_start_value(item).duplicate(true)
			var complete_end := _get_tween_end_value(item).duplicate(true)
			_prepare_missing_tween_values(item, complete_start, complete_end)
			_apply_tween_variant(_variant_at_tween_elapsed(item, complete_start, complete_end, total_span), item, complete_start)
			_call_hook(item, true)
			return false
		var play_duration := total_span - offset
		if end_limit < INF:
			play_duration = minf(play_duration, end_limit - action_time - offset)
		if play_duration <= 0.0:
			return false
		var delay := maxf(0.0, action_time - _start_time)
		var start_value := _get_tween_start_value(item).duplicate(true)
		var end_value := _get_tween_end_value(item).duplicate(true)
		_prepare_missing_tween_values(item, start_value, end_value)
		if repeat < 0 and end_limit == INF:
			return _schedule_infinite_tween_cycle(item, token, delay, offset, start_value, end_value, true)
		var tween := _make_tween()
		if tween == null:
			return false
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_callback(Callable(self, "_call_hook").bind(item, false))
		tween.tween_method(Callable(self, "_apply_tween_elapsed").bind(item, start_value, end_value), offset, offset + play_duration, play_duration)
		if total_span < INF and offset + play_duration >= total_span - 0.0001:
			tween.tween_callback(Callable(self, "_call_hook").bind(item, true))
		tween.finished.connect(Callable(self, "_on_item_tween_finished").bind(token, tween))
		return true

	if action_time <= _start_time:
		_apply_value(item, item["value"])
		_call_hook(item, false)
		return false
	if _end_time >= 0.0 and action_time > _end_time:
		return false
	var delayed := _make_tween()
	if delayed == null:
		return false
	delayed.tween_interval(action_time - _start_time)
	delayed.tween_callback(Callable(self, "_on_delayed_item").bind(item, token))
	delayed.finished.connect(Callable(self, "_on_item_tween_finished").bind(token, delayed))
	return true


func _schedule_shake(item: Dictionary, token: int, action_time: float) -> bool:
	var value: Dictionary = item["value"]
	var duration := maxf(0.0, float(value.get("duration", 0.0)))
	var end_limit := _end_time if _end_time >= 0.0 else INF
	if action_time > end_limit:
		return false
	_reset_shake(item)
	var offset := maxf(0.0, _start_time - action_time)
	if duration <= 0.0 or offset >= duration:
		return false
	var play_duration := duration - offset
	if end_limit < INF:
		play_duration = minf(play_duration, end_limit - action_time - offset)
	if play_duration <= 0.0:
		return false
	var tween := _make_tween()
	if tween == null:
		return false
	var delay := maxf(0.0, action_time - _start_time)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(Callable(self, "_call_hook").bind(item, false))
	tween.tween_method(Callable(self, "_apply_shake_elapsed").bind(item, duration, float(value.get("amplitude", 0.0))), offset, offset + play_duration, play_duration)
	tween.tween_callback(Callable(self, "_reset_shake").bind(item))
	tween.finished.connect(Callable(self, "_on_item_tween_finished").bind(token, tween))
	return true


func _make_tween() -> Tween:
	if not _has_tree():
		return null
	var tween := owner.node.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_speed_scale(_time_scale)
	_active_tweens.append(tween)
	return tween


func _schedule_infinite_tween_cycle(item: Dictionary, token: int, delay: float, offset: float, start_value: Dictionary, end_value: Dictionary, call_start_hook: bool) -> bool:
	var config: Dictionary = item["tween_config"]
	var duration := float(config.get("duration", 0.0))
	if duration <= 0.0:
		return false
	var next_offset := (floorf(offset / duration) + 1.0) * duration
	if next_offset <= offset:
		next_offset = offset + duration
	var tween := _make_tween()
	if tween == null:
		return false
	if delay > 0.0:
		tween.tween_interval(delay)
	if call_start_hook:
		tween.tween_callback(Callable(self, "_call_hook").bind(item, false))
	var segment_duration := maxf(0.0001, next_offset - offset)
	tween.tween_method(Callable(self, "_apply_tween_elapsed").bind(item, start_value, end_value), offset, next_offset, segment_duration)
	tween.finished.connect(Callable(self, "_on_infinite_tween_cycle_finished").bind(token, tween, item, next_offset, start_value, end_value))
	return true


func _on_delayed_item(item: Dictionary, token: int) -> void:
	if token != _play_id or not playing:
		return
	_apply_value(item, item["value"])
	_call_hook(item, false)


func _skip_animations() -> void:
	var processed: Dictionary = {}
	for i in _items.size():
		var item: Dictionary = _items[i]
		if processed.has(i) or int(item["type"]) != ACTION_ANIMATION or float(item["time"]) > _start_time:
			continue
		var target: FGUIObject = item.get("target")
		if target == null:
			continue
		var frame := int(target.get_prop(FGUIEnums.OBJECT_PROP_FRAME))
		var play_start_time := 0.0 if bool(target.get_prop(FGUIEnums.OBJECT_PROP_PLAYING)) else -1.0
		var play_total_time := 0.0
		for j in range(i, _items.size()):
			var animation_item: Dictionary = _items[j]
			if int(animation_item["type"]) != ACTION_ANIMATION or animation_item.get("target") != target or float(animation_item["time"]) > _start_time:
				continue
			processed[j] = true
			var value: Dictionary = animation_item["value"]
			var item_time := float(animation_item["time"])
			var next_frame := int(value.get("frame", -1))
			if next_frame >= 0:
				frame = next_frame
				play_start_time = item_time if bool(value.get("playing", true)) else -1.0
				play_total_time = 0.0
			elif bool(value.get("playing", true)):
				if play_start_time < 0.0:
					play_start_time = item_time
			elif play_start_time >= 0.0:
				play_total_time += item_time - play_start_time
				play_start_time = -1.0
			_call_hook(animation_item, false)
		if play_start_time >= 0.0:
			play_total_time += _start_time - play_start_time
		target.set_prop(FGUIEnums.OBJECT_PROP_PLAYING, play_start_time >= 0.0)
		target.set_prop(FGUIEnums.OBJECT_PROP_FRAME, frame)
		if play_total_time > 0.0:
			target.set_prop(FGUIEnums.OBJECT_PROP_DELTA_TIME, play_total_time * 1000.0)


func _on_item_tween_finished(token: int, tween: Tween) -> void:
	_active_tweens.erase(tween)
	if token != _play_id or not playing:
		return
	_check_all_complete(token)


func _on_child_transition_finished(token: int, transition: FGUITransition) -> void:
	_active_child_transitions.erase(transition)
	if token != _play_id or not playing:
		return
	_check_all_complete(token)


func _on_infinite_tween_cycle_finished(token: int, tween: Tween, item: Dictionary, next_offset: float, start_value: Dictionary, end_value: Dictionary) -> void:
	_active_tweens.erase(tween)
	if token != _play_id or not playing:
		return
	_schedule_infinite_tween_cycle(item, token, 0.0, next_offset, start_value, end_value, false)


func _check_all_complete(token: int) -> void:
	if token != _play_id or not playing:
		return
	if _active_tweens.is_empty() and _active_child_transitions.is_empty():
		_finish_playback(token)


func _finish_playback(token: int) -> void:
	if token != _play_id or not playing:
		return
	if _total_times < 0:
		_internal_play(token)
		return
	_total_times -= 1
	if _total_times > 0:
		_internal_play(token)
		return
	playing = false
	_release_display_locks()
	var callback := _on_complete
	_on_complete = Callable()
	if callback.is_valid():
		callback.call()


func _resolve_targets() -> void:
	for i in _items.size():
		var item: Dictionary = _items[i]
		var target_id := String(item.get("target_id", ""))
		if target_id == "":
			item["target"] = owner
		else:
			item["target"] = owner.get_child_by_id(target_id) if owner != null else null
		if item["type"] != ACTION_TRANSITION:
			continue
		var value: Dictionary = item["value"]
		value["stop_time"] = -1.0
		var nested_transition: FGUITransition = null
		if item["target"] != null:
			var target: FGUIObject = item["target"]
			if target is FGUIComponent:
				var component := target as FGUIComponent
				nested_transition = component.get_transition(String(value.get("trans_name", "")))
				if nested_transition == self:
					nested_transition = null
		if nested_transition != null and int(value.get("play_times", 1)) == 0:
			var found_start := false
			for j in range(i - 1, -1, -1):
				var previous: Dictionary = _items[j]
				if previous["type"] == ACTION_TRANSITION and previous["value"].get("trans") == nested_transition:
					previous["value"]["stop_time"] = float(item["time"]) - float(previous["time"])
					found_start = true
					break
			if found_start:
				nested_transition = null
			else:
				value["stop_time"] = 0.0
		value["trans"] = nested_transition


func _acquire_display_locks() -> void:
	if (_options & OPTION_IGNORE_DISPLAY_CONTROLLER) == 0:
		return
	for item in _items:
		if int(item.get("display_lock_token", 0)) != 0:
			continue
		var target: FGUIObject = item.get("target")
		if target != null and target != owner:
			item["display_lock_token"] = target.add_display_lock()


func _release_display_locks() -> void:
	for item in _items:
		var token := int(item.get("display_lock_token", 0))
		if token == 0:
			continue
		var target: FGUIObject = item.get("target")
		if target != null:
			target.release_display_lock(token)
		item["display_lock_token"] = 0


func _apply_tween_variant(value: Variant, item: Dictionary, start_value: Dictionary = {}) -> void:
	var actual := _value_from_variant(item["type"], value)
	if item.get("tween_config") != null and item["tween_config"].get("path") != null:
		var point: Vector2 = item["tween_config"]["path"].get_point_at(clampf(value.w, 0.0, 1.0)) if value is Vector4 else Vector2.ZERO
		actual["f1"] = point.x + float(start_value.get("f1", 0.0))
		actual["f2"] = point.y + float(start_value.get("f2", 0.0))
	_apply_value(item, actual)


func _apply_tween_elapsed(elapsed: float, item: Dictionary, start_value: Dictionary, end_value: Dictionary) -> void:
	_apply_tween_variant(_variant_at_tween_elapsed(item, start_value, end_value, elapsed), item, start_value)


func _apply_shake_elapsed(elapsed: float, item: Dictionary, duration: float, amplitude: float) -> void:
	var strength := amplitude * (1.0 - clampf(elapsed / maxf(duration, 0.0001), 0.0, 1.0))
	var value: Dictionary = item["value"]
	value["offset_x"] = strength if randf() > 0.5 else -strength
	value["offset_y"] = strength if randf() > 0.5 else -strength
	_apply_value(item, value)


func _reset_shake(item: Dictionary) -> void:
	var value: Dictionary = item.get("value", {})
	if value.is_empty():
		return
	value["offset_x"] = 0.0
	value["offset_y"] = 0.0
	if item.get("target") != null:
		_apply_value(item, value)
	value["last_offset_x"] = 0.0
	value["last_offset_y"] = 0.0


func _apply_value(item: Dictionary, source_value: Dictionary) -> void:
	var target: FGUIObject = item.get("target")
	if target == null:
		return
	var value := source_value.duplicate(true)
	target._gear_locked = true
	match int(item["type"]):
		ACTION_XY:
			var bx := bool(value.get("b1", true))
			var by := bool(value.get("b2", true))
			var vx := float(value.get("f1", target.x))
			var vy := float(value.get("f2", target.y))
			if target == owner:
				vx += _owner_base.x
				vy += _owner_base.y
			elif bool(value.get("b3", false)) and owner != null:
				vx *= owner.width
				vy *= owner.height
			if bx and by:
				target.set_xy(vx, vy)
			elif bx:
				target.x = vx
			elif by:
				target.y = vy
		ACTION_SIZE:
			var target_width := float(value.get("f1", target.width)) if bool(value.get("b1", true)) else target.width
			var target_height := float(value.get("f2", target.height)) if bool(value.get("b2", true)) else target.height
			target.set_size(target_width, target_height)
		ACTION_PIVOT:
			target.set_pivot(float(value.get("f1", 0.0)), float(value.get("f2", 0.0)), target.pivot_as_anchor)
		ACTION_ALPHA:
			target.alpha = float(value.get("f1", target.alpha))
		ACTION_ROTATION:
			target.rotation = float(value.get("f1", target.rotation))
		ACTION_SCALE:
			target.set_scale(float(value.get("f1", 1.0)), float(value.get("f2", 1.0)))
		ACTION_COLOR:
			target.set_prop(FGUIEnums.OBJECT_PROP_COLOR, value.get("f1", Color.WHITE))
		ACTION_ANIMATION:
			if int(value.get("frame", -1)) >= 0:
				target.set_prop(FGUIEnums.OBJECT_PROP_FRAME, int(value["frame"]))
			target.set_prop(FGUIEnums.OBJECT_PROP_PLAYING, bool(value.get("playing", true)))
			target.set_prop(FGUIEnums.OBJECT_PROP_TIME_SCALE, _time_scale)
		ACTION_VISIBLE:
			target.visible = bool(value.get("visible", true))
		ACTION_SOUND:
			if playing and float(item.get("time", 0.0)) >= _start_time:
				var root_object := target.root
				if root_object != null:
					root_object.play_one_shot_sound(String(value.get("sound", "")), float(value.get("volume", 1.0)))
		ACTION_TRANSITION:
			_play_nested_transition(item, value)
		ACTION_SHAKE:
			var offset := Vector2(float(value.get("offset_x", 0.0)), float(value.get("offset_y", 0.0)))
			var last := Vector2(float(value.get("last_offset_x", 0.0)), float(value.get("last_offset_y", 0.0)))
			target.set_xy(target.x - last.x + offset.x, target.y - last.y + offset.y)
			source_value["last_offset_x"] = offset.x
			source_value["last_offset_y"] = offset.y
		ACTION_COLOR_FILTER:
			FGUIToolSet.set_color_filter(target.node, [value.get("f1", 0.0), value.get("f2", 0.0), value.get("f3", 0.0), value.get("f4", 0.0)])
		ACTION_TEXT:
			target.set_text(String(value.get("text", "")))
		ACTION_ICON:
			target.set_icon(String(value.get("text", "")))
	target._gear_locked = false


func _play_nested_transition(item: Dictionary, value: Dictionary) -> void:
	if not playing or value.get("trans") == null:
		return
	var transition: FGUITransition = value["trans"]
	var start_time := maxf(0.0, _start_time - float(item.get("time", 0.0)))
	var end_time := _end_time - float(item.get("time", 0.0)) if _end_time >= 0.0 else -1.0
	var stop_time := float(value.get("stop_time", -1.0))
	if stop_time >= 0.0 and (end_time < 0.0 or end_time > stop_time):
		end_time = stop_time
	var token := _play_id
	_active_child_transitions.append(transition)
	transition.time_scale = _time_scale
	transition._play(Callable(self, "_on_child_transition_finished").bind(token, transition), int(value.get("play_times", 1)), 0.0, start_time, end_time, _reversed)


func _apply_complete_state() -> void:
	var indices := range(_items.size())
	if _reversed:
		indices = range(_items.size() - 1, -1, -1)
	for i in indices:
		var item: Dictionary = _items[i]
		if item.get("target") == null:
			continue
		if item.get("tween_config") != null:
			var start_value := _get_tween_start_value(item).duplicate(true)
			var end_value := _get_tween_end_value(item).duplicate(true)
			_prepare_missing_tween_values(item, start_value, end_value)
			var span := _get_tween_total_span(float(item["tween_config"]["duration"]), int(item["tween_config"].get("repeat", 0)))
			_apply_tween_variant(_variant_at_tween_elapsed(item, start_value, end_value, span if span < INF else float(item["tween_config"]["duration"])), item, start_value)
		else:
			_apply_value(item, item["value"])


func _get_item_play_time(item: Dictionary) -> float:
	var time := float(item["time"])
	if not _reversed:
		return time
	var duration := float(item["tween_config"]["duration"]) if item.get("tween_config") != null else 0.0
	if int(item["type"]) == ACTION_SHAKE:
		duration = float(item["value"].get("duration", 0.0))
	return _total_duration - time - duration


func _get_tween_start_value(item: Dictionary) -> Dictionary:
	return item["tween_config"]["end_value"] if _reversed else item["tween_config"]["start_value"]


func _get_tween_end_value(item: Dictionary) -> Dictionary:
	return item["tween_config"]["start_value"] if _reversed else item["tween_config"]["end_value"]


func _prepare_missing_tween_values(item: Dictionary, start_value: Dictionary, end_value: Dictionary) -> void:
	var target: FGUIObject = item.get("target")
	if target == null:
		return
	match int(item["type"]):
		ACTION_XY:
			if not bool(start_value.get("b1", true)):
				start_value["f1"] = target.x - (_owner_base.x if target == owner else 0.0)
			elif bool(start_value.get("b3", false)) and owner != null:
				start_value["f1"] = float(start_value["f1"]) * owner.width
			if not bool(start_value.get("b2", true)):
				start_value["f2"] = target.y - (_owner_base.y if target == owner else 0.0)
			elif bool(start_value.get("b3", false)) and owner != null:
				start_value["f2"] = float(start_value["f2"]) * owner.height
			if not bool(end_value.get("b1", true)):
				end_value["f1"] = start_value.get("f1", target.x)
			elif bool(end_value.get("b3", false)) and owner != null:
				end_value["f1"] = float(end_value["f1"]) * owner.width
			if not bool(end_value.get("b2", true)):
				end_value["f2"] = start_value.get("f2", target.y)
			elif bool(end_value.get("b3", false)) and owner != null:
				end_value["f2"] = float(end_value["f2"]) * owner.height
		ACTION_SIZE:
			if not bool(start_value.get("b1", true)):
				start_value["f1"] = target.width
			if not bool(start_value.get("b2", true)):
				start_value["f2"] = target.height
			if not bool(end_value.get("b1", true)):
				end_value["f1"] = start_value["f1"]
			if not bool(end_value.get("b2", true)):
				end_value["f2"] = start_value["f2"]


func _variant_at_ratio(item: Dictionary, start_value: Dictionary, end_value: Dictionary, ratio: float) -> Variant:
	ratio = clampf(ratio, 0.0, 1.0)
	var type := int(item["type"])
	match type:
		ACTION_XY, ACTION_SIZE, ACTION_SCALE, ACTION_PIVOT, ACTION_SKEW:
			return Vector4(
				lerpf(float(start_value.get("f1", 0.0)), float(end_value.get("f1", 0.0)), ratio),
				lerpf(float(start_value.get("f2", 0.0)), float(end_value.get("f2", 0.0)), ratio),
				0.0,
				ratio
			)
		ACTION_ALPHA, ACTION_ROTATION:
			return lerpf(float(start_value.get("f1", 0.0)), float(end_value.get("f1", 0.0)), ratio)
		ACTION_COLOR:
			var start_color: Color = start_value.get("f1", Color.WHITE)
			var end_color: Color = end_value.get("f1", Color.WHITE)
			return start_color.lerp(end_color, ratio)
		ACTION_COLOR_FILTER:
			return Vector4(
				lerpf(float(start_value.get("f1", 0.0)), float(end_value.get("f1", 0.0)), ratio),
				lerpf(float(start_value.get("f2", 0.0)), float(end_value.get("f2", 0.0)), ratio),
				lerpf(float(start_value.get("f3", 0.0)), float(end_value.get("f3", 0.0)), ratio),
				lerpf(float(start_value.get("f4", 0.0)), float(end_value.get("f4", 0.0)), ratio)
			)
		_:
			return ratio


func _variant_at_tween_elapsed(item: Dictionary, start_value: Dictionary, end_value: Dictionary, elapsed: float) -> Variant:
	var config: Dictionary = item["tween_config"]
	var duration := float(config.get("duration", 0.0))
	if duration <= 0.0:
		return _variant_at_ratio(item, start_value, end_value, 1.0)
	var tt := maxf(0.0, elapsed)
	var repeat := int(config.get("repeat", 0))
	var reversed_cycle := false
	if repeat != 0:
		var round := int(floorf(tt / duration))
		tt -= duration * float(round)
		if bool(config.get("yoyo", false)):
			reversed_cycle = round % 2 == 1
		if repeat > 0 and repeat - round < 0:
			if bool(config.get("yoyo", false)):
				reversed_cycle = repeat % 2 == 1
			tt = duration
	elif tt >= duration:
		tt = duration
	var eased_time := duration - tt if reversed_cycle else tt
	var ratio := FGUIEaseManager.evaluate(int(config.get("ease_type", FGUIEaseType.QUAD_OUT)), eased_time, duration)
	return _variant_at_ratio(item, start_value, end_value, ratio)


func _get_tween_total_span(duration: float, repeat: int) -> float:
	if duration <= 0.0:
		return 0.0
	if repeat < 0:
		return INF
	return duration * float(repeat + 1)


func _value_from_variant(type: int, value: Variant) -> Dictionary:
	match type:
		ACTION_XY, ACTION_SIZE, ACTION_SCALE, ACTION_PIVOT, ACTION_SKEW:
			return {"b1": true, "b2": true, "f1": value.x, "f2": value.y}
		ACTION_ALPHA, ACTION_ROTATION:
			return {"f1": float(value)}
		ACTION_COLOR:
			return {"f1": value}
		ACTION_COLOR_FILTER:
			return {"f1": value.x, "f2": value.y, "f3": value.z, "f4": value.w}
		_:
			return {}


func _decode_value(item: Dictionary, buffer: FGUIByteBuffer, value: Dictionary) -> void:
	match int(item["type"]):
		ACTION_XY, ACTION_SIZE, ACTION_PIVOT, ACTION_SKEW:
			value["b1"] = buffer.read_bool()
			value["b2"] = buffer.read_bool()
			value["f1"] = buffer.read_float32()
			value["f2"] = buffer.read_float32()
			if buffer.version >= 2 and int(item["type"]) == ACTION_XY:
				value["b3"] = buffer.read_bool()
		ACTION_ALPHA, ACTION_ROTATION:
			value["f1"] = buffer.read_float32()
		ACTION_SCALE:
			value["f1"] = buffer.read_float32()
			value["f2"] = buffer.read_float32()
		ACTION_COLOR:
			value["f1"] = buffer.read_color()
		ACTION_ANIMATION:
			value["playing"] = buffer.read_bool()
			value["frame"] = buffer.read_i32()
		ACTION_VISIBLE:
			value["visible"] = buffer.read_bool()
		ACTION_SOUND:
			value["sound"] = _string_or_empty(buffer.read_s())
			value["volume"] = buffer.read_float32()
		ACTION_TRANSITION:
			value["trans_name"] = _string_or_empty(buffer.read_s())
			value["play_times"] = buffer.read_i32()
		ACTION_SHAKE:
			value["amplitude"] = buffer.read_float32()
			value["duration"] = buffer.read_float32()
		ACTION_COLOR_FILTER:
			value["f1"] = buffer.read_float32()
			value["f2"] = buffer.read_float32()
			value["f3"] = buffer.read_float32()
			value["f4"] = buffer.read_float32()
		ACTION_TEXT, ACTION_ICON:
			value["text"] = _string_or_empty(buffer.read_s())


func _read_path(buffer: FGUIByteBuffer) -> FGUIGPath:
	var path_len := buffer.read_i32()
	if path_len <= 0:
		return null
	var points: Array = []
	for i in path_len:
		var curve_type := buffer.read_u8()
		match curve_type:
			1:
				points.append(FGUIGPathPoint.new_bezier_point(buffer.read_float32(), buffer.read_float32(), buffer.read_float32(), buffer.read_float32()))
			2:
				points.append(FGUIGPathPoint.new_cubic_bezier_point(buffer.read_float32(), buffer.read_float32(), buffer.read_float32(), buffer.read_float32(), buffer.read_float32(), buffer.read_float32()))
			_:
				points.append(FGUIGPathPoint.new_point(buffer.read_float32(), buffer.read_float32(), curve_type))
	var path := FGUIGPath.new()
	path.create(points)
	return path


func _set_decoded_value_args(type: int, value: Dictionary, args: Array) -> void:
	match type:
		ACTION_XY, ACTION_SIZE, ACTION_PIVOT, ACTION_SCALE, ACTION_SKEW:
			value["b1"] = true
			value["b2"] = true
			value["f1"] = float(args[0])
			value["f2"] = float(args[1])
		ACTION_ALPHA, ACTION_ROTATION:
			value["f1"] = float(args[0])
		ACTION_COLOR:
			value["f1"] = args[0] if args[0] is Color else Color(args[0])
		ACTION_ANIMATION:
			value["frame"] = int(args[0])
			if args[1] != null:
				value["playing"] = bool(args[1])
		ACTION_VISIBLE:
			value["visible"] = bool(args[0])
		ACTION_SOUND:
			value["sound"] = String(args[0])
			if args[1] != null:
				value["volume"] = float(args[1])
		ACTION_TRANSITION:
			value["trans_name"] = String(args[0])
			if args[1] != null:
				value["play_times"] = int(args[1])
		ACTION_SHAKE:
			value["amplitude"] = float(args[0])
			if args[1] != null:
				value["duration"] = float(args[1])
		ACTION_COLOR_FILTER:
			value["f1"] = float(args[0])
			value["f2"] = float(args[1])
			value["f3"] = float(args[2])
			value["f4"] = float(args[3])
		ACTION_TEXT, ACTION_ICON:
			value["text"] = String(args[0])


func _call_hook(item: Dictionary, tween_end: bool) -> void:
	if tween_end:
		if item.get("tween_config") != null:
			var end_hook: Callable = item["tween_config"].get("end_hook", Callable())
			if end_hook.is_valid():
				end_hook.call()
	else:
		var hook: Callable = item.get("hook", Callable())
		if hook.is_valid() and float(item.get("time", 0.0)) >= _start_time:
			hook.call()


func _recalculate_total_duration() -> void:
	_total_duration = 0.0
	for item in _items:
		var duration := float(item["tween_config"]["duration"]) if item.get("tween_config") != null else 0.0
		_total_duration = maxf(_total_duration, float(item["time"]) + duration)


func _has_tree() -> bool:
	return owner != null and owner.node != null and owner.node.is_inside_tree()


func _string_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)
