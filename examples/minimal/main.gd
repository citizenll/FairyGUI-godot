extends Control


func _ready() -> void:
	var pkg := FGUIPackage.add_package("res://examples/assets/ui/VirtualList")
	if pkg == null:
		return
	var view := pkg.create_object("Main")
	if view == null:
		return
	add_child(view.node)
	view.node.position = Vector2(40, 40)
