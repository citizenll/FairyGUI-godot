@tool
extends VBoxContainer

signal refresh_requested
signal object_selected(object_id: int)

var _tree: Tree
var _status: Label


func _ready() -> void:
	name = "FairyGUI"
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	var refresh_button := Button.new()
	refresh_button.text = "刷新"
	refresh_button.tooltip_text = "从正在运行的游戏重新读取 FairyGUI 逻辑树。"
	refresh_button.pressed.connect(func() -> void: refresh_requested.emit())
	toolbar.add_child(refresh_button)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.text = "等待游戏运行"
	toolbar.add_child(_status)

	_tree = Tree.new()
	_tree.columns = 3
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "节点")
	_tree.set_column_title(1, "类型")
	_tree.set_column_title(2, "尺寸")
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, true)
	_tree.set_column_expand(2, false)
	_tree.set_column_custom_minimum_width(2, 120)
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_item_selected)
	add_child(_tree)


func set_snapshot(snapshot: Dictionary) -> void:
	_tree.clear()
	var root := _tree.create_item()
	for view_value: Variant in snapshot.get("views", []):
		if not view_value is Dictionary:
			continue
		var view := view_value as Dictionary
		var view_item := _tree.create_item(root)
		view_item.set_text(0, str(view.get("name", "FGUIView")))
		view_item.set_text(1, "FGUIView · %s" % str(view.get("component_name", "")))
		view_item.set_tooltip_text(0, str(view.get("node_path", "")))
		var object_root: Variant = view.get("root", {})
		if object_root is Dictionary:
			_append_object(view_item, object_root as Dictionary)
	_status.text = "%d 个视图 · %d 个 FairyGUI 对象" % [
		int(snapshot.get("view_count", 0)),
		int(snapshot.get("object_count", 0)),
	]


func set_running(running: bool) -> void:
	if not running:
		_tree.clear()
		_status.text = "等待游戏运行"
	else:
		_status.text = "正在读取 FairyGUI 逻辑树…"


func _append_object(parent: TreeItem, value: Dictionary) -> void:
	var item := _tree.create_item(parent)
	item.set_text(0, str(value.get("name", "<unnamed>")))
	item.set_text(1, str(value.get("type", "FGUIObject")))
	item.set_text(2, "%.0f × %.0f" % [float(value.get("width", 0.0)), float(value.get("height", 0.0))])
	item.set_metadata(0, int(value.get("object_id", 0)))
	item.set_tooltip_text(0, "位置 %.0f, %.0f · %s" % [
		float(value.get("x", 0.0)),
		float(value.get("y", 0.0)),
		"可见" if bool(value.get("visible", true)) else "隐藏",
	])
	for child: Variant in value.get("children", []):
		if child is Dictionary:
			_append_object(item, child as Dictionary)


func _on_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var object_id := int(item.get_metadata(0))
	if object_id != 0:
		object_selected.emit(object_id)
