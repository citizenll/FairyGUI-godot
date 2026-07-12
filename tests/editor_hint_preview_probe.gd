extends SceneTree


func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("This probe must run through the Godot editor.")
		return
	await process_frame
	var resource_filesystem := EditorInterface.get_resource_filesystem()
	while resource_filesystem != null and (resource_filesystem.is_scanning() or resource_filesystem.is_importing()):
		await process_frame
	var baseline_cache: Dictionary = {}
	for cache_key in FGUIPackageResource._package_cache:
		var entry: Dictionary = FGUIPackageResource._package_cache[cache_key]
		baseline_cache[cache_key] = int(entry.get("references", 0))
	var resource := ResourceLoader.load("res://examples/assets/ui/Basics.fui") as FGUIPackageResource
	if resource == null:
		_fail("Godot editor did not resolve Basics.fui as an imported package resource.")
		return
	var component_names := resource.get_component_names()
	if component_names.is_empty():
		_fail("Imported package did not provide a preview component.")
		return

	var host := Control.new()
	root.add_child(host)
	var view := FGUIView.new()
	host.add_child(view)
	view.package = resource
	view.component_name = component_names[0]
	await process_frame
	await process_frame

	var preview := view.get_fairy_object()
	if preview == null or preview.node == null:
		_fail("FGUIView did not create an editor preview.")
		return
	if preview.node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("FGUIView editor preview still captures editor input.")
		return

	view.queue_free()
	host.queue_free()
	await process_frame
	await process_frame
	if FGUIPackageResource._package_cache.size() != baseline_cache.size():
		_fail("FGUIView editor preview retained imported package references after cleanup.")
		return
	for cache_key in baseline_cache:
		if not FGUIPackageResource._package_cache.has(cache_key):
			_fail("FGUIView editor preview removed an unrelated package cache entry.")
			return
		var entry: Dictionary = FGUIPackageResource._package_cache[cache_key]
		if int(entry.get("references", 0)) != int(baseline_cache[cache_key]):
			_fail("FGUIView editor preview changed an unrelated package reference count.")
			return
	for _frame in 3:
		await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
