class_name FGUIWindow
extends FGUIComponent

var content_pane: FGUIComponent
var modal: bool = false
var bring_to_front_on_click: bool = true
var shown: bool = false


func show() -> void:
	shown = true
	visible = true
	on_shown()


func hide() -> void:
	if not shown:
		return
	shown = false
	visible = false
	on_hide()


func toggle_status() -> void:
	if shown:
		hide()
	else:
		show()


func center_on(root: FGUIRoot = null, restraint: bool = false) -> void:
	var target := root if root != null else FGUIRoot.get_inst()
	if target != null:
		set_xy((target.width - width) * 0.5, (target.height - height) * 0.5)
		if restraint:
			add_relation(target, FGUIEnums.RELATION_CENTER_CENTER)
			add_relation(target, FGUIEnums.RELATION_MIDDLE_MIDDLE)


func set_content_pane(value: FGUIComponent) -> void:
	if content_pane == value:
		return
	if content_pane != null:
		remove_child(content_pane)
	content_pane = value
	if content_pane != null:
		add_child(content_pane)
		set_size(content_pane.width, content_pane.height)


func on_init() -> void:
	pass


func on_shown() -> void:
	pass


func on_hide() -> void:
	pass
