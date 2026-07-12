extends Node


func _ready() -> void:
	var package_files: Array[String] = []
	var dir := DirAccess.open("res://examples/assets/ui")
	if dir == null:
		_fail("Exported demo asset folder is missing.")
		return
	for file_name in dir.get_files():
		var package_file := file_name
		if package_file.ends_with(".fui.import"):
			package_file = package_file.trim_suffix(".import")
		elif package_file.ends_with(".fui.remap"):
			package_file = package_file.trim_suffix(".remap")
		if package_file.ends_with(".fui") and not package_files.has(package_file):
			package_files.append(package_file)
	if package_files.is_empty():
		_fail("Exported project contains no FairyGUI packages.")
		return
	var loaded_packages: Array[String] = []
	for file_name in package_files:
		var package_path := "res://examples/assets/ui/%s" % file_name.trim_suffix(".fui")
		var package := FGUIPackage.add_package(package_path)
		if package == null or package.items.is_empty():
			_fail("Exported package failed to load: %s" % package_path)
			return
		loaded_packages.append(package.id)
		for item: FGUIPackageItem in package.items:
			if item.type != FGUIEnums.PACKAGE_ITEM_COMPONENT:
				continue
			var component := package.create_object(item.name)
			if component == null:
				_fail("Exported component failed to instantiate: %s/%s" % [package_path, item.name])
				return
			component.dispose()
	for package_id in loaded_packages:
		FGUIPackage.remove_package(package_id)
	for _frame in 3:
		await get_tree().process_frame
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
