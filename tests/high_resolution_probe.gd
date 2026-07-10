extends SceneTree


func _initialize() -> void:
	var previous_level := FGUIRoot.content_scale_level
	var pkg := FGUIPackage.new()
	var source := _make_item(pkg, "source")
	source.high_resolution = ["two_x", "three_x", "four_x"]
	var two_x := _make_item(pkg, "two_x")
	var three_x := _make_item(pkg, "three_x")
	var four_x := _make_item(pkg, "four_x")
	pkg._items_by_id = {
		"source": source,
		"two_x": two_x,
		"three_x": three_x,
		"four_x": four_x,
	}

	FGUIRoot.content_scale_level = 0
	if source.get_high_resolution() != source:
		_cleanup(pkg, previous_level)
		_fail("High-resolution selection did not preserve the source at scale level zero.")
		return
	FGUIRoot.content_scale_level = 1
	if source.get_high_resolution() != two_x:
		_cleanup(pkg, previous_level)
		_fail("High-resolution selection did not resolve the 2x item.")
		return
	FGUIRoot.content_scale_level = 2
	if source.get_high_resolution() != three_x:
		_cleanup(pkg, previous_level)
		_fail("High-resolution selection did not resolve the 3x item.")
		return
	FGUIRoot.content_scale_level = 3
	if source.get_high_resolution() != four_x:
		_cleanup(pkg, previous_level)
		_fail("High-resolution selection did not resolve the 4x item.")
		return
	FGUIRoot.content_scale_level = 4
	if source.get_high_resolution() != source:
		_cleanup(pkg, previous_level)
		_fail("High-resolution selection did not fall back after the configured variants.")
		return

	var root_object := FGUIRoot.new()
	root_object.content_scale_factor = 1.49
	if FGUIRoot.content_scale_level != 0:
		root_object.dispose()
		_cleanup(pkg, previous_level)
		_fail("Root content scale factor did not keep level zero below 1.5x.")
		return
	root_object.content_scale_factor = 1.5
	if FGUIRoot.content_scale_level != 1:
		root_object.dispose()
		_cleanup(pkg, previous_level)
		_fail("Root content scale factor did not select the 2x level.")
		return
	root_object.content_scale_factor = 2.5
	if FGUIRoot.content_scale_level != 2:
		root_object.dispose()
		_cleanup(pkg, previous_level)
		_fail("Root content scale factor did not select the 3x level.")
		return
	root_object.content_scale_factor = 3.5
	if FGUIRoot.content_scale_level != 3:
		root_object.dispose()
		_cleanup(pkg, previous_level)
		_fail("Root content scale factor did not select the 4x level.")
		return
	root_object.dispose()
	_cleanup(pkg, previous_level)
	quit(0)


func _make_item(pkg: FGUIPackage, item_id: String) -> FGUIPackageItem:
	var item := FGUIPackageItem.new()
	item.owner = pkg
	item.id = item_id
	return item


func _cleanup(pkg: FGUIPackage, previous_level: int) -> void:
	FGUIRoot.content_scale_level = previous_level
	pkg.dispose()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
