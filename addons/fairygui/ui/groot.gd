class_name FGUIRoot
extends FGUIComponent

static var inst: FGUIRoot

var content_scale_factor: float = 1.0


func _init() -> void:
	super._init()
	inst = self
	name = "GRoot"
	if node != null:
		node.name = "GRoot"
		node.mouse_filter = Control.MOUSE_FILTER_PASS


static func get_inst() -> FGUIRoot:
	if inst == null:
		inst = FGUIRoot.new()
	return inst


func attach_to(parent_node: Node) -> void:
	if parent_node == null or node == null:
		return
	if node.get_parent() != parent_node:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		parent_node.add_child(node)
	_update_size_from_viewport()


func show_window(window: FGUIWindow) -> void:
	if window == null:
		return
	add_child(window)
	window.show()


func hide_window(window: FGUIWindow) -> void:
	if window == null:
		return
	window.hide()
	window.remove_from_parent()


func show_popup(popup: FGUIObject, target: FGUIObject = null, _dir: int = FGUIEnums.POPUP_AUTO) -> void:
	if popup == null:
		return
	add_child(popup)
	if target != null:
		popup.set_xy(target.x, target.y + target.height)


func hide_popup(popup: FGUIObject = null) -> void:
	if popup != null:
		popup.remove_from_parent()


func _update_size_from_viewport() -> void:
	if node == null:
		return
	var viewport := node.get_viewport()
	if viewport != null:
		set_size(viewport.get_visible_rect().size.x, viewport.get_visible_rect().size.y)
