extends SceneTree


func _initialize() -> void:
	var resource := ResourceLoader.load("res://examples/assets/ui/Basics.fui") as FGUIPackageResource
	if resource == null:
		_fail("Imported .fui did not load as FGUIPackageResource.")
		return
	if resource.package_data.is_empty() or resource.source_path != "res://examples/assets/ui/Basics.fui":
		_fail("Imported .fui resource did not preserve its package data and source path.")
		return
	var resource_script: Script = resource.get_script()
	if resource_script == null or resource_script.get_global_name() != "FGUIPackageResource":
		_fail("Imported .fui resource did not retain its FGUIPackageResource script type.")
		return

	var component_names := resource.get_component_names()
	if component_names.is_empty():
		_fail("Imported .fui resource did not expose component names.")
		return

	var host := Control.new()
	root.add_child(host)
	var view := FGUIView.new()
	host.add_child(view)
	var package_property := _find_property(view, "package")
	if package_property.is_empty() or int(package_property.get("type", -1)) != TYPE_OBJECT:
		_fail("FGUIView does not expose an object package property in the Inspector.")
		return
	view.package = resource
	if view.package != resource:
		_fail("FGUIView package property rejected the imported .fui resource.")
		return
	view.component_name = component_names[0]
	await process_frame
	await process_frame

	var preview := view.get_fairy_object()
	if preview == null or preview.node == null or preview.node.get_parent() != view:
		_fail("FGUIView did not instantiate the selected package component.")
		return
	if view.size.x <= 0.0 or view.size.y <= 0.0:
		_fail("FGUIView did not size an empty Control to its preview content.")
		return

	view.queue_free()
	host.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _find_property(object: Object, property_name: String) -> Dictionary:
	for property: Dictionary in object.get_property_list():
		if property.get("name", "") == property_name:
			return property
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
