extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var owner := FGUIComponent.new()
	owner.set_size(120.0, 80.0)
	owner.scroll_pane = FGUIScrollPane.new(owner)
	host.add_child(owner.node)
	var pane := owner.scroll_pane
	pane.set_content_size(260.0, 220.0)
	await process_frame

	pane._begin_pull_gesture(Vector2(20.0, 20.0), -1)
	pane._track_pull_gesture(Vector2(20.0, 60.0))
	if pane._elastic_offset.y <= 0.0 or pane.content.position.y <= 0.0:
		_fail("ScrollPane did not render edge resistance while pulling past its leading edge.")
		return
	pane._end_pull_gesture()
	await create_timer(0.35).timeout
	if not pane._elastic_offset.is_zero_approx() or not pane.content.position.is_zero_approx():
		_fail("ScrollPane did not return elastic content to its logical origin after release.")
		return

	pane.bounceback_effect = false
	pane._begin_pull_gesture(Vector2(20.0, 20.0), -1)
	pane._track_pull_gesture(Vector2(20.0, 60.0))
	if not pane._elastic_offset.is_zero_approx() or not pane.content.position.is_zero_approx():
		_fail("ScrollPane rendered elastic resistance when bounceback_effect was disabled.")
		return
	pane.cancel_dragging()

	owner.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
