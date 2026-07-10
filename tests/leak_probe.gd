extends SceneTree


func _initialize() -> void:
	var initial_orphans := {}
	for object_id in Node.get_orphan_node_ids():
		initial_orphans[object_id] = true

	var loaded_packages: Array[String] = []
	var dir := DirAccess.open("res://examples/assets/ui")
	if dir == null:
		push_error("Demo asset folder is missing.")
		quit(1)
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".fui"):
			continue
		var package_path := "res://examples/assets/ui/%s" % file_name.trim_suffix(".fui")
		var pkg := FGUIPackage.add_package(package_path)
		if pkg == null:
			push_error("Package failed to load: %s" % package_path)
			quit(1)
			return
		loaded_packages.append(pkg.id)
		for item: FGUIPackageItem in pkg.items:
			if item.type != FGUIEnums.PACKAGE_ITEM_COMPONENT:
				continue
			var view := pkg.create_object(item.name)
			if view != null:
				view.dispose()

	for package_id in loaded_packages:
		FGUIPackage.remove_package(package_id)
	for i in 3:
		await process_frame

	var leaked := 0
	for object_id in Node.get_orphan_node_ids():
		if initial_orphans.has(object_id):
			continue
		var object := instance_from_id(object_id)
		if not (object is Node):
			continue
		var leaked_node := object as Node
		var owner_name := ""
		var package_name := ""
		var item_name := ""
		if leaked_node.has_meta("fgui_owner"):
			var fgui_owner: Variant = leaked_node.get_meta("fgui_owner")
			if fgui_owner != null:
				var owner_script: Script = fgui_owner.get_script()
				owner_name = owner_script.get_global_name() if owner_script != null else fgui_owner.get_class()
				var package_item: Variant = fgui_owner.get("package_item")
				if package_item != null:
					item_name = package_item.name
					if package_item.owner != null:
						package_name = package_item.owner.name
		print("LEAK_NODE class=%s name=%s queued=%s owner=%s package=%s item=%s" % [leaked_node.get_class(), leaked_node.name, leaked_node.is_queued_for_deletion(), owner_name, package_name, item_name])
		leaked += 1
	print("LEAK_NODE_COUNT=%s" % leaked)
	if leaked != 0:
		push_error("FairyGUI smoke disposal leaked %s orphan nodes." % leaked)
		quit(1)
		return
	quit(0)
