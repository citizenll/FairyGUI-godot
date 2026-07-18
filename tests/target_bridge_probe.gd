extends SceneTree

const PACKAGE_PATH := "res://examples/assets/ui/Joystick.fui"
const ObjectReference := preload("res://addons/fairygui/ui/object_reference.gd")
const TargetScript := preload("res://addons/fairygui/ui/fgui_target.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _verify_ambiguous_name_rejection():
		_fail("FGUIObjectRef accepted an ambiguous name fallback.")
		return
	var resource := ResourceLoader.load(PACKAGE_PATH) as FGUIPackageResource
	if resource == null:
		_fail("Could not load Joystick.fui.")
		return
	var view := FGUIView.new()
	view.package = resource
	view.component_name = "Main"
	root.add_child(view)
	for _frame in 4:
		await process_frame
	var component := view.fairy as FGUIComponent
	var image := component.get_child("joystick_center") as FGUIImage if component != null else null
	if image == null or image.get_material_target() == null:
		_fail("Joystick/Main did not expose the joystick_center image.")
		return
	var original_canvas := image.get_material_target()
	var original_material: Material = original_canvas.material

	var reference := ObjectReference.from_object(component, image)
	if reference == null or reference.call("resolve", component) != image:
		_fail("FGUIObjectRef could not resolve a stable image target.")
		return
	var fallback_reference := reference.duplicate(true)
	fallback_reference.child_ids = PackedStringArray(["missing-id"])
	if fallback_reference.call("resolve", component) != image:
		_fail("FGUIObjectRef did not use its unique-name migration fallback.")
		return

	var target := TargetScript.new() as Control
	var attachment := ColorRect.new()
	attachment.name = "Attachment"
	attachment.size = Vector2(12.0, 12.0)
	target.add_child(attachment)
	var particles := GPUParticles2D.new()
	particles.name = "Particles"
	particles.amount = 1
	particles.emitting = false
	target.add_child(particles)
	target.set("target_ref", reference)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { COLOR = texture(TEXTURE, UV); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	if not _verify_scene_roundtrip(resource, reference, material):
		_fail("FGUITarget scene serialization did not preserve its reference and material.")
		return
	target.set("material_override", material)
	view.add_child(target)
	for _frame in 3:
		await process_frame
	if target.call("get_resolved_object") != image:
		_fail("FGUITarget did not resolve its FUI object.")
		return
	if not target.call("is_preserving_fui_hierarchy") \
			or not target.call("is_hierarchy_rendering_active") \
			or target.z_index != 0 \
			or attachment.get_parent() != target or particles.get_parent() != target:
		_fail("FGUITarget did not preserve the FUI render hierarchy by default.")
		return
	if original_canvas.material != material:
		_fail("FGUITarget did not apply the ShaderMaterial override.")
		return
	if target.size.distance_to(image.node.size) > 0.1 \
			or target.global_position.distance_to(image.node.global_position) > 0.1:
		_fail("FGUITarget did not mirror the target transform and size.")
		return
	target.set("enabled", false)
	await process_frame
	if target.visible or original_canvas.material != original_material:
		_fail("Disabling FGUITarget did not hide attachments and restore the material.")
		return
	target.set("enabled", true)
	await process_frame
	if original_canvas.material != material:
		_fail("Re-enabling FGUITarget did not restore its material override.")
		return
	target.set("attachment_mode", 1)
	await process_frame
	if target.call("is_hierarchy_rendering_active") or target.z_index != 1:
		_fail("FGUITarget overlay attachment mode did not restore scene render parenting.")
		return
	target.set("attachment_mode", 0)
	await process_frame
	if not target.call("is_hierarchy_rendering_active") or target.z_index != 0:
		_fail("FGUITarget did not restore FUI hierarchy attachment mode.")
		return

	var invalid_reference := reference.duplicate(true)
	invalid_reference.child_ids = PackedStringArray(["missing-id"])
	invalid_reference.child_names = PackedStringArray(["missing-name"])
	target.set("hide_when_missing", false)
	target.set("target_ref", invalid_reference)
	await process_frame
	if target.call("get_resolved_object") != null \
			or original_canvas.material != original_material or not target.visible:
		_fail("FGUITarget did not restore the previous material after unbinding.")
		return
	target.set("hide_when_missing", true)
	await process_frame
	if target.visible:
		_fail("FGUITarget did not hide an unresolved target when requested.")
		return

	target.set("target_ref", reference)
	await process_frame
	var previous_object := target.call("get_resolved_object") as FGUIObject
	view.refresh_preview()
	for _frame in 4:
		await process_frame
	var rebuilt_object := target.call("get_resolved_object") as FGUIObject
	if rebuilt_object == null or rebuilt_object == previous_object:
		_fail("FGUITarget did not rebind after FGUIView rebuilt its preview.")
		return
	if rebuilt_object.get_material_target().material != material:
		_fail("FGUITarget did not reapply its material after preview rebuild.")
		return
	if attachment.get_parent() != target or particles.get_parent() != target \
			or not attachment.is_inside_tree() or not particles.is_inside_tree() \
			or not target.call("is_hierarchy_rendering_active"):
		_fail("FGUITarget lost its scene-owned attachment during FUI rebuild.")
		return

	var rebuilt_canvas := rebuilt_object.get_material_target()
	target.queue_free()
	await process_frame
	if rebuilt_canvas.material != original_material:
		_fail("Removing FGUITarget did not restore the FUI material.")
		return
	view.queue_free()
	await process_frame
	quit(0)


func _verify_ambiguous_name_rejection() -> bool:
	var component := FGUIComponent.new()
	var first := FGUIObject.new()
	first.name = "duplicate"
	component.add_child(first)
	var second := FGUIObject.new()
	second.name = "duplicate"
	component.add_child(second)
	var reference := ObjectReference.new()
	reference.child_ids = PackedStringArray(["missing-id"])
	reference.child_names = PackedStringArray(["duplicate"])
	var valid := reference.call("resolve", component) == null
	component.dispose()
	return valid


func _verify_scene_roundtrip(
		resource: FGUIPackageResource,
		reference: Resource,
		material: Material
	) -> bool:
	var scene_root := Control.new()
	scene_root.name = "TargetBridgeScene"
	var view := FGUIView.new()
	view.name = "View"
	view.package = resource
	view.component_name = "Main"
	scene_root.add_child(view)
	view.owner = scene_root
	var target := TargetScript.new() as Control
	target.name = "ImageTarget"
	target.set("target_ref", reference)
	target.set("material_override", material)
	target.set("attachment_behind_target", true)
	view.add_child(target)
	target.owner = scene_root
	var attachment := GPUParticles2D.new()
	attachment.name = "Particles"
	attachment.emitting = false
	target.add_child(attachment)
	attachment.owner = scene_root
	var packed := PackedScene.new()
	if packed.pack(scene_root) != OK:
		scene_root.free()
		return false
	var path := "user://fairygui_target_bridge_probe.tscn"
	if ResourceSaver.save(packed, path) != OK:
		scene_root.free()
		return false
	scene_root.free()
	var loaded := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var instance := loaded.instantiate() if loaded != null else null
	var loaded_target := instance.get_node_or_null("View/ImageTarget") if instance != null else null
	var loaded_attachment := instance.get_node_or_null("View/ImageTarget/Particles") if instance != null else null
	var valid: bool = loaded_target != null \
		and loaded_attachment != null \
		and loaded_attachment.get_parent() == loaded_target \
		and loaded_target.get_script() == TargetScript \
		and loaded_target.get("target_ref") != null \
		and loaded_target.get("target_ref").call("get_key") == reference.call("get_key") \
		and loaded_target.get("material_override") is ShaderMaterial \
		and bool(loaded_target.get("attachment_behind_target")) \
		and loaded_target.call("is_preserving_fui_hierarchy")
	if instance != null:
		instance.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return valid


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
