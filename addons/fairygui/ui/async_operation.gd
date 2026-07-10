class_name FGUIAsyncOperation
extends RefCounted

const _BATCH_SIZE := 5

var callback: Callable
var result: FGUIObject
var is_running: bool = false

var _generation: int = 0
var _item_list: Array[Dictionary] = []
var _object_pool: Array[FGUIObject] = []
var _index: int = 0


func create_object(package_name: String, resource_name: String) -> void:
	var pkg := FGUIPackage.get_by_name(package_name)
	_start(pkg.get_item_by_name(resource_name) if pkg != null else null)


func create_object_from_url(url: String) -> void:
	_start(FGUIPackage.get_item_by_url(FGUIPackage.normalize_url(url)))


func cancel() -> void:
	_generation += 1
	_dispose_pending_objects()
	_item_list.clear()
	_index = 0
	is_running = false
	callback = Callable()


func _start(item: FGUIPackageItem) -> void:
	_generation += 1
	_dispose_pending_objects()
	_item_list.clear()
	_index = 0
	result = null
	is_running = true
	if item != null:
		var display_item := {
			"package_item": item,
			"object_type": item.object_type,
			"child_count": 0,
			"list_item_count": 0,
		}
		if item.type == FGUIEnums.PACKAGE_ITEM_COMPONENT:
			display_item["child_count"] = _collect_component_children(item)
		_item_list.append(display_item)
	_queue_run(_generation)


func _queue_run(token: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_run(token, false)
		return
	tree.process_frame.connect(Callable(self, "_run").bind(token, true), CONNECT_ONE_SHOT)


func _run(token: int, can_defer: bool) -> void:
	if token != _generation or not is_running:
		return
	var frame_started := Time.get_ticks_msec()
	while _index < _item_list.size():
		_create_display_object(_item_list[_index])
		_index += 1
		if can_defer and _index % _BATCH_SIZE == 0 and float(Time.get_ticks_msec() - frame_started) >= maxf(0.0, FGUIConfig.frame_time_for_async_ui_construction):
			_queue_run(token)
			return
	_finish(token)


func _finish(token: int) -> void:
	if token != _generation or not is_running:
		return
	result = _object_pool[0] if not _object_pool.is_empty() else null
	_object_pool.clear()
	_item_list.clear()
	_index = 0
	is_running = false
	if callback.is_valid():
		callback.call(result)


func _create_display_object(display_item: Dictionary) -> void:
	var item: FGUIPackageItem = display_item.get("package_item")
	var obj: FGUIObject = null
	if item != null:
		obj = FGUIObjectFactory.new_object_from_item(item)
		if obj == null:
			return
		_object_pool.append(obj)
		FGUIPackage.constructing += 1
		if item.type == FGUIEnums.PACKAGE_ITEM_COMPONENT and obj is FGUIComponent:
			var child_count := int(display_item.get("child_count", 0))
			var pool_start := _object_pool.size() - child_count - 1
			if pool_start >= 0:
				(obj as FGUIComponent).construct_from_resource2(_object_pool, pool_start)
				_remove_pool_range(pool_start, child_count)
			else:
				push_error("FairyGUI async component display list is inconsistent.")
				obj.construct_from_resource()
		else:
			obj.construct_from_resource()
		FGUIPackage.constructing -= 1
		return

	obj = FGUIObjectFactory.new_object(int(display_item.get("object_type", FGUIEnums.OBJECT_COMPONENT)))
	if obj == null:
		return
	_object_pool.append(obj)
	var list_item_count := int(display_item.get("list_item_count", 0))
	if obj is FGUIList and list_item_count > 0:
		var pool_start := _object_pool.size() - list_item_count - 1
		if pool_start < 0:
			push_error("FairyGUI async list display list is inconsistent.")
			return
		var list := obj as FGUIList
		for offset in list_item_count:
			list.item_pool.return_object(_object_pool[pool_start + offset])
		_remove_pool_range(pool_start, list_item_count)


func _remove_pool_range(start: int, count: int) -> void:
	for _offset in count:
		_object_pool.remove_at(start)


func _collect_component_children(item: FGUIPackageItem) -> int:
	var content_item := item.get_branch()
	var buffer := content_item.raw_data
	if buffer == null or not buffer.seek(0, 2):
		return 0
	var child_count := maxi(0, buffer.read_i16())
	for _child_index in child_count:
		var data_len := buffer.read_i16()
		var begin_pos := buffer.pos
		if not buffer.seek(begin_pos, 0):
			buffer.pos = begin_pos + data_len
			continue
		var object_type := buffer.read_i8()
		var src = buffer.read_s()
		var package_id = buffer.read_s()
		buffer.pos = begin_pos
		var package_item: FGUIPackageItem = null
		if src != null:
			var pkg: FGUIPackage = FGUIPackage.get_by_id(str(package_id)) if package_id != null else content_item.owner
			if pkg != null:
				package_item = pkg.get_item_by_id(str(src))
		var display_item := {
			"package_item": package_item,
			"object_type": object_type,
			"child_count": 0,
			"list_item_count": 0,
		}
		if package_item != null and package_item.type == FGUIEnums.PACKAGE_ITEM_COMPONENT:
			display_item["child_count"] = _collect_component_children(package_item)
		elif src == null and object_type == FGUIEnums.OBJECT_LIST:
			display_item["list_item_count"] = _collect_list_children(buffer)
		_item_list.append(display_item)
		buffer.pos = begin_pos + data_len
	return child_count


func _collect_list_children(buffer: FGUIByteBuffer) -> int:
	if not buffer.seek(buffer.pos, 8):
		return 0
	var default_item = buffer.read_s()
	var list_item_count := 0
	var item_count := maxi(0, buffer.read_i16())
	for _item_index in item_count:
		var next_pos := buffer.read_i16() + buffer.pos
		var url = buffer.read_s()
		if url == null:
			url = default_item
		if url != null and str(url) != "":
			var item := FGUIPackage.get_item_by_url(str(url))
			if item != null:
				var display_item := {
					"package_item": item,
					"object_type": item.object_type,
					"child_count": 0,
					"list_item_count": 0,
				}
				if item.type == FGUIEnums.PACKAGE_ITEM_COMPONENT:
					display_item["child_count"] = _collect_component_children(item)
				_item_list.append(display_item)
				list_item_count += 1
		buffer.pos = next_pos
	return list_item_count


func _dispose_pending_objects() -> void:
	for obj: FGUIObject in _object_pool.duplicate():
		if obj != null:
			obj.dispose()
	_object_pool.clear()
