class_name FGUIPopupMenu
extends RefCounted

var content_pane: FGUIComponent
var list: FGUIList


func _init(resource_url: String = "") -> void:
	var url := resource_url if resource_url != "" else FGUIConfig.popup_menu
	if url != "":
		var obj := FGUIPackage.create_object_from_url(url)
		if obj is FGUIComponent:
			content_pane = obj
			list = content_pane.get_child("list") as FGUIList


func add_item(caption: String, callback: Callable = Callable()) -> FGUIObject:
	if list == null:
		return null
	var item := list.add_item_from_pool()
	if item != null:
		item.set_text(caption)
		if callback.is_valid():
			item.on("click", callback)
	return item


func add_separator() -> void:
	if list != null and FGUIConfig.popup_menu_separator != "":
		list.add_item_from_pool(FGUIConfig.popup_menu_separator)


func show(target: FGUIObject = null, dir: int = FGUIEnums.POPUP_AUTO) -> void:
	if content_pane != null:
		FGUIRoot.get_inst().show_popup(content_pane, target, dir)
