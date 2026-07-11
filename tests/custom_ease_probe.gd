extends SceneTree


func _initialize() -> void:
	var owner := FGUIComponent.new()
	var transition := FGUITransition.new(owner)
	var buffer := FGUIByteBuffer.new(_make_transition_bytes())
	buffer.version = 4
	transition.setup(buffer)
	if transition.raw_items.size() != 1:
		_fail(transition, "Transition did not parse the custom-ease item.")
		return
	var config: Dictionary = transition.raw_items[0]["tween_config"]
	var custom_ease := config.get("custom_ease") as FGUICustomEase
	if int(config.get("ease_type", -1)) != FGUIEaseType.CUSTOM or custom_ease == null:
		_fail(transition, "Transition did not parse its package-version-4 custom ease path.")
		return
	var ratio := custom_ease.evaluate(0.5)
	if absf(ratio - 0.25) > 0.02:
		_fail(transition, "Parsed custom ease curve evaluated incorrectly: %s" % ratio)
		return
	var gear_buffer := FGUIByteBuffer.new(_make_gear_bytes())
	gear_buffer.version = 4
	var gear := FGUIGearBase.new()
	gear.setup(gear_buffer)
	var gear_custom_ease := gear.tween_config.get("custom_ease") as FGUICustomEase
	if gear_custom_ease == null or absf(gear_custom_ease.evaluate(0.5) - 0.25) > 0.02:
		gear.dispose()
		_fail(transition, "Gear tween configuration did not parse its custom ease path.")
		return
	gear.dispose()
	transition.dispose()
	owner.dispose()
	quit(0)


func _make_transition_bytes() -> PackedByteArray:
	var block0 := PackedByteArray([FGUITransition.ACTION_ALPHA])
	_append_float(block0, 0.0)
	_append_i16(block0, -1)
	_append_u16(block0, FGUIByteBuffer.STRING_EMPTY)
	block0.append(1)

	var block1 := PackedByteArray()
	_append_float(block1, 1.0)
	block1.append(FGUIEaseType.CUSTOM)
	_append_i32(block1, 0)
	block1.append(0)
	_append_u16(block1, FGUIByteBuffer.STRING_EMPTY)

	var block2 := PackedByteArray()
	_append_float(block2, 0.0)

	var block3 := PackedByteArray()
	_append_float(block3, 1.0)
	_append_i32(block3, 0)
	_append_i32(block3, 3)
	_append_path_point(block3, 0.0, 0.0)
	_append_path_point(block3, 0.5, 0.25)
	_append_path_point(block3, 1.0, 1.0)

	var item := PackedByteArray([4, 1])
	var offset := 10
	for block in [block0, block1, block2, block3]:
		_append_u16(item, offset)
		offset += block.size()
	item.append_array(block0)
	item.append_array(block1)
	item.append_array(block2)
	item.append_array(block3)

	var bytes := PackedByteArray()
	_append_u16(bytes, FGUIByteBuffer.STRING_EMPTY)
	_append_i32(bytes, 0)
	bytes.append(0)
	_append_i32(bytes, 1)
	_append_float(bytes, 0.0)
	_append_i16(bytes, 1)
	_append_i16(bytes, item.size())
	bytes.append_array(item)
	return bytes


func _append_path_point(bytes: PackedByteArray, x: float, y: float) -> void:
	bytes.append(FGUIGPath.CURVE_STRAIGHT)
	_append_float(bytes, x)
	_append_float(bytes, y)


func _make_gear_bytes() -> PackedByteArray:
	var bytes := PackedByteArray()
	_append_i16(bytes, -1)
	_append_i16(bytes, 0)
	bytes.append(0)
	bytes.append(1)
	bytes.append(FGUIEaseType.CUSTOM)
	_append_float(bytes, 1.0)
	_append_float(bytes, 0.0)
	_append_i32(bytes, 3)
	_append_path_point(bytes, 0.0, 0.0)
	_append_path_point(bytes, 0.5, 0.25)
	_append_path_point(bytes, 1.0, 1.0)
	return bytes


func _append_u16(bytes: PackedByteArray, value: int) -> void:
	bytes.append((value >> 8) & 0xff)
	bytes.append(value & 0xff)


func _append_i16(bytes: PackedByteArray, value: int) -> void:
	_append_u16(bytes, value & 0xffff)


func _append_i32(bytes: PackedByteArray, value: int) -> void:
	bytes.append((value >> 24) & 0xff)
	bytes.append((value >> 16) & 0xff)
	bytes.append((value >> 8) & 0xff)
	bytes.append(value & 0xff)


func _append_float(bytes: PackedByteArray, value: float) -> void:
	var stream := StreamPeerBuffer.new()
	stream.big_endian = true
	stream.put_float(value)
	bytes.append_array(stream.data_array)


func _fail(transition: FGUITransition, message: String) -> void:
	push_error(message)
	if transition != null:
		var transition_owner := transition.owner
		transition.dispose()
		if transition_owner != null:
			transition_owner.dispose()
	quit(1)
