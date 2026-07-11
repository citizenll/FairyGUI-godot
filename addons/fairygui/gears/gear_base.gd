class_name FGUIGearBase
extends RefCounted

var owner: FGUIObject
var controller: FGUIController
var tween_config: Dictionary = {"tween": false, "ease_type": FGUIEaseType.QUAD_OUT, "duration": 0.3, "delay": 0.0, "custom_ease": null}


static func create(owner: FGUIObject, index: int) -> FGUIGearBase:
	match index:
		0:
			return FGUIGearDisplay.new(owner)
		1:
			return FGUIGearXY.new(owner)
		2:
			return FGUIGearSize.new(owner)
		3:
			return FGUIGearLook.new(owner)
		4:
			return FGUIGearColor.new(owner)
		5:
			return FGUIGearAnimation.new(owner)
		6:
			return FGUIGearText.new(owner)
		7:
			return FGUIGearIcon.new(owner)
		8:
			return FGUIGearDisplay2.new(owner)
		9:
			return FGUIGearFontSize.new(owner)
		_:
			return FGUIGearBase.new(owner)


func _init(p_owner: FGUIObject = null) -> void:
	owner = p_owner


func dispose() -> void:
	controller = null
	owner = null
	tween_config.clear()


func setup(buffer: FGUIByteBuffer) -> void:
	var controller_index := buffer.read_i16()
	if controller_index >= 0 and owner != null and owner.parent != null:
		controller = owner.parent.get_controller_at(controller_index)
	init()
	var count := buffer.read_i16()
	if self is FGUIGearDisplay or self is FGUIGearDisplay2:
		var page_ids := buffer.read_s_array(count)
		for page_id in page_ids:
			add_status(page_id, buffer)
	else:
		for i in count:
			var page_id = buffer.read_s()
			if page_id == null:
				continue
			add_status(page_id, buffer)
		if buffer.read_bool():
			add_status(null, buffer)
	if buffer.read_bool():
		tween_config["tween"] = true
		tween_config["ease_type"] = buffer.read_i8()
		tween_config["duration"] = buffer.read_float32()
		tween_config["delay"] = buffer.read_float32()
	if buffer.version >= 2:
		if self is FGUIGearXY:
			var gear_xy := self as FGUIGearXY
			if buffer.read_bool():
				gear_xy.positions_in_percent = true
				for i in count:
					var page_id = buffer.read_s()
					if page_id == null:
						continue
					gear_xy.add_ext_status(page_id, buffer)
				if buffer.read_bool():
					gear_xy.add_ext_status(null, buffer)
		elif self is FGUIGearDisplay2:
			var display2 := self as FGUIGearDisplay2
			display2.condition = buffer.read_u8()
	if buffer.version >= 4 and bool(tween_config.get("tween", false)) and int(tween_config.get("ease_type", -1)) == FGUIEaseType.CUSTOM:
		var custom_path := _read_custom_ease_path(buffer)
		if custom_path != null:
			var custom_ease := FGUICustomEase.new()
			custom_ease.create_from_path(custom_path)
			tween_config["custom_ease"] = custom_ease


func init() -> void:
	pass


func add_status(_page_id: Variant, _buffer: FGUIByteBuffer) -> void:
	pass


func apply() -> void:
	pass


func update_state() -> void:
	pass


func _read_custom_ease_path(buffer: FGUIByteBuffer) -> FGUIGPath:
	var point_count := buffer.read_i32()
	if point_count <= 0:
		return null
	var points: Array = []
	for index in point_count:
		var curve_type := buffer.read_u8()
		match curve_type:
			FGUIGPath.CURVE_BEZIER:
				points.append(FGUIGPathPoint.new_bezier_point(buffer.read_float32(), buffer.read_float32(), buffer.read_float32(), buffer.read_float32()))
			FGUIGPath.CURVE_CUBIC_BEZIER:
				points.append(FGUIGPathPoint.new_cubic_bezier_point(buffer.read_float32(), buffer.read_float32(), buffer.read_float32(), buffer.read_float32(), buffer.read_float32(), buffer.read_float32()))
			_:
				points.append(FGUIGPathPoint.new_point(buffer.read_float32(), buffer.read_float32(), curve_type))
	var path := FGUIGPath.new()
	path.create(points)
	return path


func _active_page_id() -> String:
	return controller.selected_page_id if controller != null else ""
