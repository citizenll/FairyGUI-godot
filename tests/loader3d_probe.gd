extends SceneTree

const Loader3D := preload("res://addons/fairygui/ui/gloader3d.gd")


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var loader := Loader3D.new()
	host.add_child(loader.node)
	var factory_loader := FGUIObjectFactory.new_object(FGUIEnums.OBJECT_LOADER_3D)
	if factory_loader == null or factory_loader.get_script() != Loader3D:
		_fail("UIObjectFactory did not create Loader3D instances for OBJECT_LOADER_3D.")
		return
	factory_loader.dispose()
	loader.set_size(100.0, 50.0)
	var canvas_content := Node2D.new()
	loader.set_content(canvas_content, Vector2(20.0, 10.0))
	if canvas_content.get_parent() != loader.canvas_host or not loader.canvas_host.position.is_equal_approx(Vector2(0.0, 0.0)):
		_fail("Loader3D did not attach CanvasItem content to its canvas host.")
		return
	loader.align = FGUIEnums.ALIGN_CENTER
	loader.valign = FGUIEnums.VERT_ALIGN_MIDDLE
	if not loader.canvas_host.position.is_equal_approx(Vector2(40.0, 20.0)):
		_fail("Loader3D did not align unscaled canvas content.")
		return
	loader.fill = FGUIEnums.LOADER_FILL_SCALE
	if not loader.canvas_host.position.is_equal_approx(Vector2.ZERO) or not loader.canvas_host.scale.is_equal_approx(Vector2(5.0, 5.0)):
		_fail("Loader3D did not apply loader fill scaling to canvas content.")
		return
	loader.auto_size = true
	if not is_equal_approx(loader.width, 20.0) or not is_equal_approx(loader.height, 10.0):
		_fail("Loader3D auto-size did not use content dimensions.")
		return

	loader.auto_size = false
	loader.set_size(64.0, 32.0)
	var control_content := Control.new()
	loader.set_content(control_content, Vector2(16.0, 8.0))
	if control_content.get_parent() != loader.control_host or not loader.control_host.visible:
		_fail("Loader3D did not attach Control content to its control host.")
		return
	loader.fill = FGUIEnums.LOADER_FILL_NONE
	loader.align = FGUIEnums.ALIGN_CENTER
	loader.valign = FGUIEnums.VERT_ALIGN_MIDDLE
	if not loader.control_host.position.is_equal_approx(Vector2(24.0, 12.0)):
		_fail("Loader3D did not lay out Control content.")
		return

	var node3d := Node3D.new()
	loader.set_content(node3d, Vector2(32.0, 18.0))
	if node3d.get_parent() != loader.viewport or not loader.viewport_container.visible or loader.viewport.size != Vector2i(32, 18):
		_fail("Loader3D did not route Node3D content through a SubViewport.")
		return

	Loader3D.set_content_factory(_create_factory_content)
	var factory_result: Variant = loader._create_factory_content("test-source")
	if not (factory_result is Dictionary) or not (factory_result.get("node") is Node2D):
		_fail("Loader3D content factory was not invoked for adapter content.")
		return
	var factory_node: Node = factory_result.get("node")
	factory_node.free()
	Loader3D.set_content_factory(Callable())

	loader.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _create_factory_content(source: Variant) -> Dictionary:
	return {"node": Node2D.new(), "size": Vector2(12.0, 6.0), "owns_content": true, "source": source}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
