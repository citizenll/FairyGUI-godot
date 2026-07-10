extends SceneTree


func _initialize() -> void:
	var operation := FGUIAsyncOperation.new()
	var state := {"sync": true, "count": 0, "result": true}
	operation.callback = func(value: Variant) -> void:
		if state["sync"]:
			_fail("AsyncOperation callback ran in the initiating call stack.")
			return
		state["count"] += 1
		state["result"] = value
	operation.create_object_from_url("ui://missing")
	if not operation.is_running or state["count"] != 0:
		_fail("AsyncOperation did not defer an outstanding request.")
		return
	state["sync"] = false
	await process_frame
	if operation.is_running or state["count"] != 1 or state["result"] != null:
		_fail("AsyncOperation did not complete deferred invalid-url creation correctly.")
		return

	var canceled := {"count": 0}
	operation.callback = func(_value: Variant) -> void: canceled["count"] += 1
	operation.create_object_from_url("ui://missing")
	operation.cancel()
	await process_frame
	if operation.is_running or canceled["count"] != 0:
		_fail("AsyncOperation cancel did not suppress its pending callback.")
		return

	var pkg := FGUIPackage.add_package("res://examples/assets/ui/Basics")
	if pkg == null:
		_fail("AsyncOperation probe could not load Basics.fui.")
		return
	var expected: FGUIObject = null
	var target_item: FGUIPackageItem = null
	for item: FGUIPackageItem in pkg.items:
		if item.type != FGUIEnums.PACKAGE_ITEM_COMPONENT:
			continue
		var view := pkg.create_object(item.name)
		if view == null:
			continue
		if _count_descendants(view) > 5:
			expected = view
			target_item = item
			break
		view.dispose()
	if target_item == null or expected == null:
		FGUIPackage.remove_package(pkg.id)
		_fail("AsyncOperation probe could not find a multi-node component.")
		return

	var normalized_url_state := {"count": 0, "value": null}
	operation.callback = func(value: Variant) -> void:
		normalized_url_state["count"] = int(normalized_url_state["count"]) + 1
		normalized_url_state["value"] = value
	operation.create_object_from_url("%s/%s" % [pkg.name, target_item.name])
	for _frame in 120:
		if not operation.is_running:
			break
		await process_frame
	if operation.is_running or normalized_url_state["count"] != 1 or not normalized_url_state["value"] is FGUIObject:
		expected.dispose()
		FGUIPackage.remove_package(pkg.id)
		_fail("AsyncOperation did not normalize package-name URLs.")
		return
	(normalized_url_state["value"] as FGUIObject).dispose()

	var url := "ui://%s%s" % [pkg.id, target_item.id]
	var pool := FGUIObjectPool.new()
	var first := FGUIObjectFactory.new_object_from_item(target_item)
	var second := FGUIObjectFactory.new_object_from_item(target_item)
	pool.return_object(first)
	pool.return_object(second)
	if pool.get_object(url) != first or pool.get_object(url) != second:
		expected.dispose()
		FGUIPackage.remove_package(pkg.id)
		_fail("FGUIObjectPool did not preserve FairyGUI FIFO reuse order.")
		return
	first.dispose()
	second.dispose()

	var saved_frame_budget := FGUIConfig.frame_time_for_async_ui_construction
	FGUIConfig.frame_time_for_async_ui_construction = 0.0
	var async_state := {"count": 0, "value": null}
	operation.callback = func(value: Variant) -> void:
		async_state["count"] = int(async_state["count"]) + 1
		async_state["value"] = value
	operation.create_object(pkg.name, target_item.name)
	await process_frame
	if not operation.is_running or async_state["count"] != 0:
		FGUIConfig.frame_time_for_async_ui_construction = saved_frame_budget
		expected.dispose()
		FGUIPackage.remove_package(pkg.id)
		_fail("AsyncOperation did not split a multi-node component across frames.")
		return
	for _frame in 120:
		if not operation.is_running:
			break
		await process_frame
	FGUIConfig.frame_time_for_async_ui_construction = saved_frame_budget
	if operation.is_running or async_state["count"] != 1 or not async_state["value"] is FGUIObject:
		expected.dispose()
		FGUIPackage.remove_package(pkg.id)
		_fail("AsyncOperation did not finish package construction correctly.")
		return
	var actual := async_state["value"] as FGUIObject
	var difference := _compare_tree(expected, actual, "root")
	if difference != "":
		expected.dispose()
		actual.dispose()
		FGUIPackage.remove_package(pkg.id)
		_fail("AsyncOperation result differs from synchronous construction: %s" % difference)
		return
	expected.dispose()
	actual.dispose()

	var canceled_loaded := {"count": 0}
	operation.callback = func(_value: Variant) -> void:
		canceled_loaded["count"] = int(canceled_loaded["count"]) + 1
	FGUIConfig.frame_time_for_async_ui_construction = 0.0
	operation.create_object(pkg.name, target_item.name)
	await process_frame
	operation.cancel()
	await process_frame
	FGUIConfig.frame_time_for_async_ui_construction = saved_frame_budget
	if operation.is_running or canceled_loaded["count"] != 0 or FGUIPackage.constructing != 0:
		FGUIPackage.remove_package(pkg.id)
		_fail("AsyncOperation cancel did not clean up a partially constructed component.")
		return
	FGUIPackage.remove_package(pkg.id)
	var coverage_error := await _verify_all_package_components()
	if coverage_error != "":
		_fail(coverage_error)
		return
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _count_descendants(obj: FGUIObject) -> int:
	var count := 1
	if obj is FGUIComponent:
		for child: FGUIObject in (obj as FGUIComponent).children:
			count += _count_descendants(child)
	return count


func _compare_tree(expected: FGUIObject, actual: FGUIObject, path: String) -> String:
	if expected.get_script() != actual.get_script():
		return "%s type" % path
	if expected.package_item != actual.package_item:
		return "%s package item" % path
	if expected.name != actual.name:
		return "%s name" % path
	if not is_equal_approx(expected.x, actual.x) or not is_equal_approx(expected.y, actual.y):
		return "%s position" % path
	if not is_equal_approx(expected.width, actual.width) or not is_equal_approx(expected.height, actual.height):
		return "%s size" % path
	if expected.get_text() != actual.get_text() or expected.get_icon() != actual.get_icon():
		return "%s content" % path
	if expected is FGUIComponent or actual is FGUIComponent:
		if not (expected is FGUIComponent and actual is FGUIComponent):
			return "%s component kind" % path
		var expected_component := expected as FGUIComponent
		var actual_component := actual as FGUIComponent
		if expected_component.num_children != actual_component.num_children:
			return "%s child count" % path
		for index in expected_component.num_children:
			var difference := _compare_tree(expected_component.get_child_at(index), actual_component.get_child_at(index), "%s.%s" % [path, index])
			if difference != "":
				return difference
	return ""


func _verify_all_package_components() -> String:
	var dir := DirAccess.open("res://examples/assets/ui")
	if dir == null:
		return "AsyncOperation probe could not open the demo package folder."
	var packages: Array[FGUIPackage] = []
	for file_name in dir.get_files():
		if not file_name.ends_with(".fui"):
			continue
		var package_path := "res://examples/assets/ui/%s" % file_name.trim_suffix(".fui")
		var pkg := FGUIPackage.add_package(package_path)
		if pkg == null:
			_remove_packages(packages)
			return "AsyncOperation probe could not load %s." % package_path
		packages.append(pkg)
	for pkg: FGUIPackage in packages:
		for item: FGUIPackageItem in pkg.items:
			if item.type != FGUIEnums.PACKAGE_ITEM_COMPONENT:
				continue
			var expected := pkg.create_object(item.name)
			if expected == null:
				_remove_packages(packages)
				return "Synchronous package construction failed for %s/%s." % [pkg.name, item.name]
			var state := {"count": 0, "value": null}
			var operation := FGUIAsyncOperation.new()
			operation.callback = func(value: Variant) -> void:
				state["count"] = int(state["count"]) + 1
				state["value"] = value
			operation.create_object(pkg.name, item.name)
			for _frame in 120:
				if not operation.is_running:
					break
				await process_frame
			if operation.is_running or state["count"] != 1 or not state["value"] is FGUIObject:
				expected.dispose()
				operation.cancel()
				_remove_packages(packages)
				return "Async package construction did not finish for %s/%s." % [pkg.name, item.name]
			var actual := state["value"] as FGUIObject
			var difference := _compare_tree(expected, actual, "%s/%s" % [pkg.name, item.name])
			expected.dispose()
			actual.dispose()
			if difference != "":
				_remove_packages(packages)
				return "Async package construction differs for %s/%s: %s" % [pkg.name, item.name, difference]
	_remove_packages(packages)
	return ""


func _remove_packages(packages: Array[FGUIPackage]) -> void:
	for pkg: FGUIPackage in packages:
		FGUIPackage.remove_package(pkg.id)
