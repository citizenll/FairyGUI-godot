extends Control

const ExportSmokeScript := preload("res://examples/minimal/export_smoke.gd")


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--fairygui-export-smoke"):
		add_child(ExportSmokeScript.new())
		return
	var pkg := FGUIPackage.add_package("res://examples/assets/ui/VirtualList")
	if pkg == null:
		return
	var view := pkg.create_object("Main")
	if view == null:
		return
	add_child(view.node)
	view.node.position = Vector2(40, 40)
	var list := view.get_child("mailList") as FGUIList
	if list == null:
		return
	list.set_virtual()
	list.item_renderer = _render_mail_item
	list.num_items = 1000
	var select_button: FGUIObject = view.get_child("n6")
	if select_button != null:
		select_button.on("click", func(_event: Variant) -> void: list.add_selection(500, true))
	var top_button: FGUIObject = view.get_child("n7")
	if top_button != null:
		top_button.on("click", func(_event: Variant) -> void: list.scroll_pane.scroll_top())
	var bottom_button: FGUIObject = view.get_child("n8")
	if bottom_button != null:
		bottom_button.on("click", func(_event: Variant) -> void: list.scroll_pane.scroll_bottom())


func _render_mail_item(index: int, obj: FGUIObject) -> void:
	var item := obj as FGUIButton
	if item == null:
		return
	item.title = "%d Mail title here" % index
	var time_text: FGUIObject = item.get_child("timeText")
	if time_text != null:
		time_text.set_text("5 Nov 2015 16:24:33")
	var read_controller := item.get_controller("IsRead")
	if read_controller != null:
		read_controller.selected_index = 1 if index % 2 == 0 else 0
	var fetched_controller := item.get_controller("c1")
	if fetched_controller != null:
		fetched_controller.selected_index = 1 if index % 3 == 0 else 0
