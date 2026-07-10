extends SceneTree


func _initialize() -> void:
	if not Engine.is_editor_hint():
		_fail("This probe must run through the Godot editor.")
		return
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
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
