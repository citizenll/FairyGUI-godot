extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var child := ColorRect.new()
	var grandchild := ColorRect.new()
	child.size = Vector2(16, 16)
	grandchild.size = Vector2(8, 8)
	child.color = Color.RED
	grandchild.color = Color.GREEN
	host.add_child(child)
	child.add_child(grandchild)
	var original_material := CanvasItemMaterial.new()
	child.material = original_material

	var parent_values := Vector4(0.1, 0.2, -0.3, 0.4)
	FGUIToolSet.set_color_filter(host, parent_values)
	await process_frame
	var parent_material := host.material as ShaderMaterial
	if parent_material == null or child.material != parent_material or grandchild.material != parent_material:
		push_error("Color filter was not applied to the CanvasItem subtree.")
		quit(1)
		return
	if parent_material.get_shader_parameter("fgui_filter") != parent_values:
		push_error("Color filter shader parameters were not applied.")
		quit(1)
		return

	var child_values := Vector4(-0.2, 0.1, 0.5, -0.4)
	FGUIToolSet.set_color_filter(child, child_values)
	var child_material := child.material as ShaderMaterial
	if child_material == null or child_material == parent_material or grandchild.material != child_material:
		push_error("Nested color filter material stack failed.")
		quit(1)
		return
	FGUIToolSet.set_color_filter(child, null)
	if child.material != parent_material or grandchild.material != parent_material:
		push_error("Nested color filter did not restore the parent filter.")
		quit(1)
		return

	FGUIToolSet.set_color_filter(host, true)
	if not bool(parent_material.get_shader_parameter("fgui_grayed")):
		push_error("Grayed state was not combined with the color filter.")
		quit(1)
		return
	FGUIToolSet.set_color_filter(host, null)
	if host.material != parent_material:
		push_error("Removing color adjustment also removed the active grayed filter.")
		quit(1)
		return
	FGUIToolSet.set_color_filter(host, false)
	if host.material != null or child.material != original_material or grandchild.material != null:
		push_error("Color filter did not restore original materials.")
		quit(1)
		return

	var fgui_object := FGUIObject.new()
	host.add_child(fgui_object.node)
	var transition := FGUITransition.new()
	var transition_values := {"f1": 0.2, "f2": -0.1, "f3": 0.4, "f4": 0.3}
	transition._apply_value({"type": FGUITransition.ACTION_COLOR_FILTER, "target": fgui_object}, transition_values)
	var transition_material := fgui_object.node.material as ShaderMaterial
	if transition_material == null or transition_material.get_shader_parameter("fgui_filter") != Vector4(0.2, -0.1, 0.4, 0.3):
		push_error("Transition color filter action was not applied.")
		quit(1)
		return
	FGUIToolSet.set_color_filter(fgui_object.node, null)
	fgui_object.dispose()

	host.queue_free()
	await process_frame
	quit(0)
