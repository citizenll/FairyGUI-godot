extends SceneTree


func _initialize() -> void:
	var parent := FGUIComponent.new()
	parent.set_size(100, 100)
	var child := FGUIObject.new()
	child.set_size(20, 20)
	child.set_xy(10, 10)
	parent.add_child(child)

	child.add_relation(parent, FGUIEnums.RELATION_WIDTH)
	parent.set_size(150, 100)
	if absf(child.width - 70.0) > 0.1:
		push_error("Relation width tracking failed: %s" % child.width)
		quit(1)
		return

	var target := FGUIObject.new()
	target.set_size(10, 10)
	target.set_xy(5, 5)
	parent.add_child(target)
	var follower := FGUIObject.new()
	follower.set_size(10, 10)
	follower.set_xy(20, 20)
	parent.add_child(follower)
	follower.add_relation(target, FGUIEnums.RELATION_LEFT_LEFT)
	target.x += 15
	if absf(follower.x - 35.0) > 0.1:
		push_error("Relation XY tracking failed: %s" % follower.x)
		quit(1)
		return

	var parsed_child := FGUIObject.new()
	parsed_child.set_size(10, 10)
	parent.add_child(parsed_child)
	var bytes := PackedByteArray([
		1,
		255, 255,
		1,
		FGUIEnums.RELATION_HEIGHT,
		0
	])
	parsed_child.relations.setup(FGUIByteBuffer.new(bytes), false)
	parent.height = 130
	if absf(parsed_child.height - 40.0) > 0.1:
		push_error("Relation setup parsing failed: %s" % parsed_child.height)
		quit(1)
		return

	parent.dispose()
	await process_frame
	quit(0)
