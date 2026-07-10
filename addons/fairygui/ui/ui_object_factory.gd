class_name FGUIObjectFactory
extends RefCounted

const Loader3D := preload("res://addons/fairygui/ui/gloader3d.gd")

static var extensions: Dictionary = {}
static var loader_type: Variant = null
static var loader3d_type: Variant = null


static func set_extension(url: String, script: Variant) -> void:
	if url == "":
		push_error("Invalid FairyGUI extension URL.")
		return
	var item := FGUIPackage.get_item_by_url(url)
	if item != null:
		item.extension_type = script
	extensions[url] = script


static func set_package_item_extension(url: String, script: Variant) -> void:
	set_extension(url, script)


static func set_loader_extension(script: Variant) -> void:
	loader_type = script


static func set_loader3d_extension(script: Variant) -> void:
	loader3d_type = script


static func resolve_package_item_extension(item: FGUIPackageItem) -> void:
	var by_id := "ui://%s%s" % [item.owner.id, item.id]
	var by_name := "ui://%s/%s" % [item.owner.name, item.name]
	if extensions.has(by_id):
		item.extension_type = extensions[by_id]
	elif extensions.has(by_name):
		item.extension_type = extensions[by_name]


static func new_object_from_item(item: FGUIPackageItem, user_class: Variant = null) -> FGUIObject:
	var obj: FGUIObject = null
	if item.type == FGUIEnums.PACKAGE_ITEM_COMPONENT:
		if user_class != null:
			obj = user_class.new()
		elif item.extension_type != null:
			obj = item.extension_type.new()
		else:
			obj = new_object(item.object_type)
	else:
		obj = new_object(item.object_type)

	if obj != null:
		obj.package_item = item
	return obj


static func new_object(object_type: int) -> FGUIObject:
	match object_type:
		FGUIEnums.OBJECT_IMAGE:
			return FGUIImage.new()
		FGUIEnums.OBJECT_TEXT:
			return FGUITextField.new()
		FGUIEnums.OBJECT_GRAPH:
			return FGUIGraph.new()
		FGUIEnums.OBJECT_LOADER:
			return loader_type.new() if loader_type != null else FGUILoader.new()
		FGUIEnums.OBJECT_LOADER_3D:
			return loader3d_type.new() if loader3d_type != null else Loader3D.new()
		FGUIEnums.OBJECT_GROUP:
			return FGUIGroup.new()
		FGUIEnums.OBJECT_MOVIE_CLIP:
			return FGUIMovieClip.new()
		FGUIEnums.OBJECT_BUTTON:
			return FGUIButton.new()
		FGUIEnums.OBJECT_LABEL:
			return FGUILabel.new()
		FGUIEnums.OBJECT_PROGRESS_BAR:
			return FGUIProgressBar.new()
		FGUIEnums.OBJECT_SLIDER:
			return FGUISlider.new()
		FGUIEnums.OBJECT_SCROLL_BAR:
			return FGUIScrollBar.new()
		FGUIEnums.OBJECT_COMBO_BOX:
			return FGUIComboBox.new()
		FGUIEnums.OBJECT_LIST:
			return FGUIList.new()
		FGUIEnums.OBJECT_TREE:
			return FGUITree.new()
		FGUIEnums.OBJECT_RICH_TEXT:
			return FGUIRichTextField.new()
		FGUIEnums.OBJECT_INPUT_TEXT:
			return FGUITextInput.new()
		FGUIEnums.OBJECT_COMPONENT:
			return FGUIComponent.new()
		_:
			return FGUIObject.new()
