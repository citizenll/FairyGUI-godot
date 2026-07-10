extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var image := FGUIImage.new()
	host.add_child(image.node)
	image.blend_mode = FGUIEnums.BLEND_ADD
	var direct_material := image.node.material as CanvasItemMaterial
	if direct_material == null or direct_material.blend_mode != CanvasItemMaterial.BLEND_MODE_ADD:
		_fail("FairyGUI additive blend mode was not applied to a leaf render control.")
		return
	image.grayed = true
	var filtered_material := image.node.material as ShaderMaterial
	if filtered_material == null or filtered_material.shader == null or filtered_material.shader.code.find("render_mode blend_add;") == -1:
		_fail("Additive blend mode was not preserved when a color filter was applied.")
		return
	image.grayed = false
	direct_material = image.node.material as CanvasItemMaterial
	if direct_material == null or direct_material.blend_mode != CanvasItemMaterial.BLEND_MODE_ADD:
		_fail("Additive blend mode was not restored after removing a color filter.")
		return
	image.blend_mode = 99
	if image.blend_mode != FGUIEnums.BLEND_NORMAL or image.node.material != null:
		_fail("Unsupported FairyGUI blend modes should fall back to normal blending.")
		return

	var field := FGUITextField.new()
	host.add_child(field.node)
	field.blend_mode = FGUIEnums.BLEND_ADD
	field.ubb_enabled = true
	if not (field.node.material is CanvasItemMaterial) or (field.node.material as CanvasItemMaterial).blend_mode != CanvasItemMaterial.BLEND_MODE_ADD:
		_fail("Text renderer changes did not preserve FairyGUI additive blend mode.")
		return
	field.grayed = true
	if not (field.node.material is ShaderMaterial) or (field.node.material as ShaderMaterial).shader.code.find("render_mode blend_add;") == -1:
		_fail("Text renderer color filters did not preserve FairyGUI additive blend mode.")
		return

	field.dispose()
	image.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
