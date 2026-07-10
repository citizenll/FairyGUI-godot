extends SceneTree


func _initialize() -> void:
	var previous_branch := FGUIPackage.branch
	var pkg := FGUIPackage.new()
	pkg.id = "brnch001"
	pkg.name = "BranchProbe"
	pkg.branches = ["desktop", "mobile"]
	var source := _make_item(pkg, "source")
	source.branches = ["desktop_item", "mobile_item"]
	var desktop_item := _make_item(pkg, "desktop_item")
	var mobile_item := _make_item(pkg, "mobile_item")
	pkg.items = [source, desktop_item, mobile_item]
	pkg._items_by_id = {
		"source": source,
		"desktop_item": desktop_item,
		"mobile_item": mobile_item,
	}
	FGUIPackage._inst_by_id[pkg.id] = pkg
	FGUIPackage._inst_by_name[pkg.name] = pkg

	FGUIPackage.branch = "mobile"
	if pkg.branch_index != 1 or source.get_branch() != mobile_item:
		_cleanup(pkg, previous_branch)
		_fail("UIPackage branch assignment did not update loaded package items.")
		return
	FGUIPackage.set_branch("desktop")
	if FGUIPackage.branch != "desktop" or pkg.branch_index != 0 or source.get_branch() != desktop_item:
		_cleanup(pkg, previous_branch)
		_fail("UIPackage.set_branch did not update the active branch.")
		return
	FGUIPackage.branch = "missing"
	if pkg.branch_index != -1 or source.get_branch() != source:
		_cleanup(pkg, previous_branch)
		_fail("UIPackage branch fallback did not restore the source item.")
		return
	_cleanup(pkg, previous_branch)
	quit(0)


func _make_item(pkg: FGUIPackage, item_id: String) -> FGUIPackageItem:
	var item := FGUIPackageItem.new()
	item.owner = pkg
	item.id = item_id
	return item


func _cleanup(pkg: FGUIPackage, previous_branch: String) -> void:
	FGUIPackage._inst_by_id.erase(pkg.id)
	FGUIPackage._inst_by_name.erase(pkg.name)
	FGUIPackage.branch = previous_branch
	pkg.dispose()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
