extends SceneTree

const TargetScript := preload("res://addons/fairygui/ui/fgui_target.gd")

const BACKGROUND := Color(0.05, 0.05, 0.05, 1.0)
const GREEN := Color(0.1, 0.9, 0.2, 1.0)
const BLUE := Color(0.1, 0.3, 0.95, 1.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Target hierarchy render probe requires a graphical display driver.")
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(96, 64)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var background := ColorRect.new()
	background.size = Vector2(viewport.size)
	background.color = BACKGROUND
	viewport.add_child(background)
	var scene_host := Control.new()
	scene_host.size = Vector2(viewport.size)
	viewport.add_child(scene_host)

	var fui_parent := Control.new()
	fui_parent.position = Vector2(10.0, 10.0)
	fui_parent.size = Vector2(40.0, 40.0)
	fui_parent.clip_contents = true
	scene_host.add_child(fui_parent)

	var graph := FGUIGraph.new()
	graph.set_xy(10.0, 10.0)
	graph.set_size(30.0, 30.0)
	graph.draw_rect(0.0, Color.TRANSPARENT, Color.RED)
	fui_parent.add_child(graph.node)

	var later_sibling := ColorRect.new()
	later_sibling.position = Vector2(25.0, 10.0)
	later_sibling.size = Vector2(10.0, 30.0)
	later_sibling.color = BLUE
	fui_parent.add_child(later_sibling)

	var target := TargetScript.new() as Control
	var attachment := ColorRect.new()
	attachment.name = "Attachment"
	attachment.size = Vector2(45.0, 30.0)
	attachment.color = GREEN
	target.add_child(attachment)
	scene_host.add_child(target)
	await process_frame
	target.set_process(false)
	target._resolved_object = graph
	await _wait_target_frames(target, 3)

	var hierarchy_image := viewport.get_texture().get_image()
	if hierarchy_image == null or hierarchy_image.is_empty():
		_fail("Target hierarchy renderer returned an empty image.")
		return
	var hierarchy_inside := hierarchy_image.get_pixel(25, 30)
	var hierarchy_overlap := hierarchy_image.get_pixel(40, 30)
	var hierarchy_outside := hierarchy_image.get_pixel(55, 30)
	if not _color_near(hierarchy_inside, GREEN) \
			or not _color_near(hierarchy_overlap, BLUE) \
			or not _color_near(hierarchy_outside, BACKGROUND):
		_fail("Default attachment rendering did not preserve FUI order and clipping: %s / %s / %s." % [
			hierarchy_inside,
			hierarchy_overlap,
			hierarchy_outside,
		])
		return
	if attachment.get_parent() != target or not target.call("is_hierarchy_rendering_active"):
		_fail("Hierarchy rendering changed the Godot scene parent or failed to activate.")
		return
	target.set("attachment_behind_target", true)
	await _wait_target_frames(target, 2)
	var behind_image := viewport.get_texture().get_image()
	if not _color_near(behind_image.get_pixel(25, 30), Color.RED):
		_fail("Behind-target attachment rendering did not draw below the FUI target.")
		return
	target.set("attachment_behind_target", false)
	await _wait_target_frames(target, 2)

	target.set("attachment_mode", 1)
	await _wait_target_frames(target, 3)
	var overlay_image := viewport.get_texture().get_image()
	var overlay_overlap := overlay_image.get_pixel(40, 30)
	var overlay_outside := overlay_image.get_pixel(55, 30)
	if not _color_near(overlay_overlap, GREEN) or not _color_near(overlay_outside, GREEN):
		_fail("Overlay attachment mode did not restore global overlay rendering: %s / %s." % [
			overlay_overlap,
			overlay_outside,
		])
		return
	target.set("attachment_mode", 0)
	await _wait_target_frames(target, 3)
	var restored_image := viewport.get_texture().get_image()
	if not _color_near(restored_image.get_pixel(40, 30), BLUE) \
			or not _color_near(restored_image.get_pixel(55, 30), BACKGROUND):
		_fail("Restoring hierarchy mode did not restore FUI order and clipping.")
		return

	target.queue_free()
	graph.dispose()
	viewport.queue_free()
	await process_frame
	quit(0)


func _wait_target_frames(target: Control, count: int) -> void:
	for _frame in count:
		target.call("_sync_proxy")
		await process_frame


func _color_near(actual: Color, expected: Color, tolerance: float = 0.12) -> bool:
	return absf(actual.r - expected.r) <= tolerance \
		and absf(actual.g - expected.g) <= tolerance \
		and absf(actual.b - expected.b) <= tolerance \
		and absf(actual.a - expected.a) <= tolerance


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
