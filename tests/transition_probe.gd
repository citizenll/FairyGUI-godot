extends SceneTree


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)

	var owner := FGUIComponent.new()
	owner.set_size(200, 120)
	host.add_child(owner.node)

	var child := FGUIObject.new()
	child.set_size(20, 20)
	child.set_xy(0, 0)
	owner.add_child(child)

	var transition := FGUITransition.new(owner)
	transition._items.append({
		"type": FGUITransition.ACTION_XY,
		"time": 0.0,
		"target_id": child.id,
		"target": null,
		"label": "move",
		"value": {},
		"tween_config": {
			"duration": 0.05,
			"ease_type": FGUIEaseType.LINEAR,
			"repeat": 0,
			"yoyo": false,
			"end_label": "move_end",
			"start_value": {"b1": true, "b2": true, "f1": 0.0, "f2": 0.0},
			"end_value": {"b1": true, "b2": true, "f1": 40.0, "f2": 30.0},
			"end_hook": Callable(),
			"path": null
		},
		"hook": Callable()
	})
	transition.raw_items = transition._items

	var completed := [false]
	transition.play(func() -> void: completed[0] = true)
	await create_timer(0.15).timeout

	if not completed[0]:
		push_error("Transition completion callback was not called.")
		quit(1)
		return
	if absf(child.x - 40.0) > 0.1 or absf(child.y - 30.0) > 0.1:
		push_error("Transition XY tween failed: %s,%s" % [child.x, child.y])
		quit(1)
		return

	var source_controller := FGUIController.new()
	source_controller.name = "source"
	source_controller.parent = owner
	source_controller.page_ids = ["source_a", "source_b"]
	source_controller.page_names = ["A", "B"]
	source_controller._selected_index = 0

	var target_controller := FGUIController.new()
	target_controller.name = "target"
	target_controller.parent = owner
	target_controller.page_ids = ["target_a", "target_b"]
	target_controller.page_names = ["A", "B"]
	target_controller._selected_index = 0
	owner.controllers = [source_controller, target_controller]

	var action := FGUIController.FGUIChangePageAction.new()
	action.controller_name = "target"
	action.target_page = "~2"
	source_controller.actions.append(action)
	source_controller.selected_index = 1
	if target_controller.selected_index != 1:
		push_error("Controller ChangePageAction failed.")
		quit(1)
		return

	var clip := FGUIMovieClip.new()
	clip.frames = [{"add_delay": 0, "texture": null}, {"add_delay": 0, "texture": null}]
	clip.frame = 0
	clip.set_prop(FGUIEnums.OBJECT_PROP_DELTA_TIME, 16)
	if clip.frame != 1:
		push_error("MovieClip frame advance failed.")
		quit(1)
		return

	quit(0)
