extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)

	var component := FGUIComponent.new()
	component.set_size(100.0, 80.0)
	component.scroll_pane = FGUIScrollPane.new(component)
	host.add_child(component.node)

	var child := FGUIObject.new()
	child.set_size(20.0, 10.0)
	child.set_xy(180.0, 30.0)
	component.add_child(child)
	await process_frame
	await process_frame
	if not Vector2(component.scroll_pane.content_width, component.scroll_pane.content_height).is_equal_approx(Vector2(200.0, 40.0)):
		_fail("Deferred component bounds did not size ScrollPane content after adding a child.")
		return

	child.set_xy(260.0, 55.0)
	await process_frame
	await process_frame
	if not Vector2(component.scroll_pane.content_width, component.scroll_pane.content_height).is_equal_approx(Vector2(280.0, 65.0)):
		_fail("Deferred component bounds did not update after moving a child.")
		return

	component.remove_child(child)
	await process_frame
	await process_frame
	if not Vector2(component.scroll_pane.content_width, component.scroll_pane.content_height).is_zero_approx():
		_fail("Deferred component bounds did not shrink ScrollPane content after removing its last child.")
		return

	child.dispose()
	component.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
