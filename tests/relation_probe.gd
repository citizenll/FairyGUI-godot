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

	var runtime_width_owner := FGUIComponent.new()
	runtime_width_owner.source_width = 100
	runtime_width_owner.set_size(150, 50)
	parent.add_child(runtime_width_owner)
	var runtime_width_target := FGUIObject.new()
	runtime_width_target.init_width = 20
	runtime_width_target.set_size(30, 10)
	runtime_width_owner.add_child(runtime_width_target)
	runtime_width_owner.add_relation(runtime_width_target, FGUIEnums.RELATION_WIDTH)
	runtime_width_target.width = 40
	if absf(runtime_width_owner.width - 160.0) > 0.1:
		push_error("Runtime parent-to-child width relation used construction dimensions: %s" % runtime_width_owner.width)
		quit(1)
		return

	var constructed_width_owner := FGUIComponent.new()
	constructed_width_owner.source_width = 100
	constructed_width_owner.set_size(150, 50)
	constructed_width_owner._under_construct = true
	parent.add_child(constructed_width_owner)
	var constructed_width_target := FGUIObject.new()
	constructed_width_target.init_width = 20
	constructed_width_target.set_size(30, 10)
	constructed_width_owner.add_child(constructed_width_target)
	constructed_width_owner.add_relation(constructed_width_target, FGUIEnums.RELATION_WIDTH)
	constructed_width_target.width = 40
	constructed_width_owner._under_construct = false
	if absf(constructed_width_owner.width - 120.0) > 0.1:
		push_error("Construction parent-to-child width relation lost source dimensions: %s" % constructed_width_owner.width)
		quit(1)
		return

	var runtime_ext_owner := FGUIComponent.new()
	runtime_ext_owner.set_size(100, 100)
	parent.add_child(runtime_ext_owner)
	var runtime_ext_target := FGUIObject.new()
	runtime_ext_target.set_xy(10, 15)
	runtime_ext_target.set_size(20, 20)
	runtime_ext_owner.add_child(runtime_ext_target)
	runtime_ext_owner.add_relation(runtime_ext_target, FGUIEnums.RELATION_RIGHT_EXT_RIGHT, true)
	runtime_ext_owner.add_relation(runtime_ext_target, FGUIEnums.RELATION_BOTTOM_EXT_BOTTOM, true)
	runtime_ext_target.set_size(40, 40)
	if absf(runtime_ext_owner.width - 190.0) > 0.1 or absf(runtime_ext_owner.height - 185.0) > 0.1:
		push_error("Runtime percent extension relations used construction formulas: %s,%s" % [runtime_ext_owner.width, runtime_ext_owner.height])
		quit(1)
		return

	var group := FGUIGroup.new()
	parent.add_child(group)
	var grouped_target := FGUIObject.new()
	grouped_target.set_size(20, 20)
	parent.add_child(grouped_target)
	var grouped_follower := FGUIObject.new()
	grouped_follower.set_size(20, 20)
	grouped_follower.group = group
	parent.add_child(grouped_follower)
	grouped_follower.add_relation(grouped_target, FGUIEnums.RELATION_WIDTH)
	group._updating = 1
	grouped_target.width = 30
	group._updating = 0
	if absf(grouped_follower.width - 20.0) > 0.1:
		push_error("Group layout did not suppress relation size updates: %s" % grouped_follower.width)
		quit(1)
		return
	grouped_target.width = 40
	if absf(grouped_follower.width - 30.0) > 0.1:
		push_error("Suppressed relation size update did not refresh its target baseline: %s" % grouped_follower.width)
		quit(1)
		return

	parent.dispose()
	await process_frame
	quit(0)
