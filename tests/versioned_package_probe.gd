extends SceneTree


class ProbeRoot extends FGUIRoot:
	var played_sounds: Array[Dictionary] = []


	func play_one_shot_sound(sound: Variant, volume_scale: float = 1.0) -> AudioStreamPlayer:
		played_sounds.append({"sound": sound, "volume": volume_scale})
		return null


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var gui_root := ProbeRoot.new()
	gui_root.set_size(320.0, 200.0)
	host.add_child(gui_root.node)

	var label := FGUILabel.new()
	label.package_item = _make_package_item(FGUIEnums.OBJECT_LABEL)
	var label_buffer := FGUIByteBuffer.new(_make_indexed_block(6, _make_label_block()))
	label_buffer.version = 5
	label_buffer.string_table = ["ui://click_label"]
	label.setup_after_add(label_buffer, 0)
	gui_root.add_child(label)

	var combo := FGUIComboBox.new()
	combo.package_item = _make_package_item(FGUIEnums.OBJECT_COMBO_BOX)
	var combo_buffer := FGUIByteBuffer.new(_make_indexed_block(6, _make_combo_block()))
	combo_buffer.version = 5
	combo_buffer.string_table = ["ui://click_combo"]
	combo.setup_after_add(combo_buffer, 0)
	gui_root.add_child(combo)

	var progress := FGUIProgressBar.new()
	progress.package_item = _make_package_item(FGUIEnums.OBJECT_PROGRESS_BAR)
	var progress_buffer := FGUIByteBuffer.new(_make_indexed_block(6, _make_progress_block()))
	progress_buffer.version = 5
	progress_buffer.string_table = ["ui://click_progress"]
	progress.setup_after_add(progress_buffer, 0)
	gui_root.add_child(progress)

	label.emit_event("click")
	combo.emit_event("click")
	progress.emit_event("click")
	if gui_root.played_sounds.size() != 3 or gui_root.played_sounds[0]["sound"] != "ui://click_label" or not is_equal_approx(gui_root.played_sounds[2]["volume"], 0.4):
		_fail(gui_root, null, "Version-5 control click sounds were not parsed and dispatched.")
		return

	var stage_component := FGUIComponent.new()
	var metadata_buffer := FGUIByteBuffer.new(_make_indexed_block(4, _make_component_metadata_block()))
	metadata_buffer.version = 5
	metadata_buffer.string_table = ["ui://added", "ui://removed"]
	stage_component._setup_component_metadata(metadata_buffer, FGUIPackageItem.new())
	if stage_component._added_to_stage_sound != "ui://added" or stage_component._removed_from_stage_sound != "ui://removed":
		_fail(gui_root, stage_component, "Version-5 component stage sound fields were not parsed: %s / %s" % [stage_component._added_to_stage_sound, stage_component._removed_from_stage_sound])
		return
	gui_root.add_child(stage_component)
	await process_frame
	gui_root.remove_child(stage_component)
	await process_frame
	if gui_root.played_sounds.size() != 5 or gui_root.played_sounds[3]["sound"] != "ui://added" or gui_root.played_sounds[4]["sound"] != "ui://removed":
		_fail(gui_root, stage_component, "Version-5 component stage sounds were not parsed and dispatched: %s" % [gui_root.played_sounds])
		return

	var gear_owner := FGUIComponent.new()
	gui_root.add_child(gear_owner)
	var controller := FGUIController.new()
	controller.parent = gear_owner
	controller.page_ids = ["page"]
	controller.page_names = ["Page"]
	controller._selected_index = 0
	gear_owner.controllers.append(controller)
	var loader := FGUILoader3D.new()
	gear_owner.add_child(loader)
	var animation_gear := loader.get_gear(5) as FGUIGearAnimation
	var gear_buffer := FGUIByteBuffer.new(_make_animation_gear_bytes())
	gear_buffer.version = 6
	gear_buffer.string_table = ["page", "run", "armor"]
	animation_gear.setup(gear_buffer)
	loader.handle_controller_changed(controller)
	if not loader.playing or loader.frame != 7 or loader.animation_name != "run" or loader.skin_name != "armor":
		_fail(gui_root, stage_component, "Version-6 animation gear did not apply Loader3D animation and skin names.")
		return

	var transition := FGUITransition.new(gear_owner)
	var animation_value: Dictionary = {}
	var transition_value_buffer := FGUIByteBuffer.new(_make_transition_animation_value())
	transition_value_buffer.version = 6
	transition_value_buffer.string_table = ["jump", "cloth"]
	transition._decode_value({"type": FGUITransition.ACTION_ANIMATION}, transition_value_buffer, animation_value)
	transition._apply_value({"type": FGUITransition.ACTION_ANIMATION, "target": loader, "time": 0.0}, animation_value)
	if loader.playing or loader.frame != 3 or loader.animation_name != "jump" or loader.skin_name != "cloth":
		transition.dispose()
		_fail(gui_root, stage_component, "Version-6 transition animation value did not apply Loader3D animation and skin names.")
		return
	transition._items = [{"type": FGUITransition.ACTION_ANIMATION, "label": "animation", "value": animation_value, "tween_config": null}]
	transition.set_value("animation", 5, true, "walk", "metal")
	if animation_value["frame"] != 5 or not animation_value["playing"] or animation_value["animation_name"] != "walk" or animation_value["skin_name"] != "metal":
		transition.dispose()
		_fail(gui_root, stage_component, "Transition set_value did not update version-6 animation and skin names.")
		return
	transition.dispose()

	stage_component.dispose()
	gui_root.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _make_label_block() -> PackedByteArray:
	var block := PackedByteArray([FGUIEnums.OBJECT_LABEL])
	_append_u16(block, FGUIByteBuffer.STRING_NULL)
	_append_u16(block, FGUIByteBuffer.STRING_NULL)
	block.append(0)
	_append_i32(block, 0)
	block.append(0)
	_append_u16(block, 0)
	_append_float(block, 0.2)
	return block


func _make_combo_block() -> PackedByteArray:
	var block := PackedByteArray([FGUIEnums.OBJECT_COMBO_BOX])
	_append_i16(block, 0)
	_append_u16(block, FGUIByteBuffer.STRING_NULL)
	_append_u16(block, FGUIByteBuffer.STRING_NULL)
	block.append(0)
	_append_i32(block, 0)
	block.append(FGUIEnums.POPUP_AUTO)
	_append_i16(block, -1)
	_append_u16(block, 0)
	_append_float(block, 0.3)
	return block


func _make_progress_block() -> PackedByteArray:
	var block := PackedByteArray([FGUIEnums.OBJECT_PROGRESS_BAR])
	_append_i32(block, 25)
	_append_i32(block, 100)
	_append_i32(block, 0)
	_append_u16(block, 0)
	_append_float(block, 0.4)
	return block


func _make_component_metadata_block() -> PackedByteArray:
	var block := PackedByteArray([0, 0, 0])
	_append_i16(block, -1)
	_append_u16(block, FGUIByteBuffer.STRING_NULL)
	_append_i32(block, 0)
	_append_i32(block, -1)
	_append_u16(block, 0)
	_append_u16(block, 1)
	return block


func _make_animation_gear_bytes() -> PackedByteArray:
	var bytes := PackedByteArray()
	_append_i16(bytes, 0)
	_append_i16(bytes, 1)
	_append_u16(bytes, 0)
	bytes.append(1)
	_append_i32(bytes, 7)
	bytes.append(0)
	bytes.append(0)
	_append_u16(bytes, 0)
	_append_u16(bytes, 1)
	_append_u16(bytes, 2)
	bytes.append(0)
	return bytes


func _make_transition_animation_value() -> PackedByteArray:
	var bytes := PackedByteArray([0])
	_append_i32(bytes, 3)
	_append_u16(bytes, 0)
	_append_u16(bytes, 1)
	return bytes


func _make_indexed_block(block_index: int, block: PackedByteArray) -> PackedByteArray:
	var bytes := PackedByteArray([block_index + 1, 1])
	var header_size := 2 + (block_index + 1) * 2
	for index in range(block_index + 1):
		_append_u16(bytes, header_size if index == block_index else 0)
	bytes.append_array(block)
	return bytes


func _make_package_item(object_type: int) -> FGUIPackageItem:
	var item := FGUIPackageItem.new()
	item.object_type = object_type
	return item


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


func _fail(gui_root: FGUIRoot, detached_component: FGUIComponent, message: String) -> void:
	push_error(message)
	if detached_component != null and not detached_component.is_disposed:
		detached_component.dispose()
	if gui_root != null and not gui_root.is_disposed:
		gui_root.dispose()
	quit(1)
