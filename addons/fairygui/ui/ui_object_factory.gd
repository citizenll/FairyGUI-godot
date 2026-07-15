class_name FGUIObjectFactory
extends RefCounted

const Loader3D := preload("res://addons/fairygui/ui/gloader3d.gd")

static var extensions: Dictionary = {}
static var generated_extensions: Dictionary = {}
static var loader_type: Variant = null
static var loader3d_type: Variant = null
static var _generated_registry_loaded: bool = false
static var _generated_registry_loading: bool = false
static var _generated_registry_force_reload: bool = false

const DEFAULT_GENERATED_REGISTRY_PATH := "res://generated/fairygui/registry.gd"


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


static func clear() -> void:
	extensions.clear()
	generated_extensions.clear()
	loader_type = null
	loader3d_type = null
	_generated_registry_loaded = false
	_generated_registry_loading = false
	_generated_registry_force_reload = false


static func set_generated_extensions(bindings: Dictionary) -> void:
	generated_extensions.clear()
	for key: Variant in bindings:
		var url := str(key)
		var creator: Variant = bindings[key]
		if url == "" or not (creator is Script or creator is Callable or creator is String or creator is StringName):
			continue
		if (creator is String or creator is StringName) and str(creator) == "":
			continue
		generated_extensions[url] = creator
	_generated_registry_loaded = true
	_generated_registry_loading = false
	_generated_registry_force_reload = false


static func reload_generated_extensions() -> void:
	generated_extensions.clear()
	_generated_registry_loaded = false
	_generated_registry_loading = false
	_generated_registry_force_reload = true
	_ensure_generated_extensions()


static func resolve_package_item_extension(item: FGUIPackageItem) -> void:
	if item == null or item.owner == null:
		return
	var by_id := "ui://%s%s" % [item.owner.id, item.id]
	var by_name := "ui://%s/%s" % [item.owner.name, item.name]
	if extensions.has(by_id):
		item.extension_type = extensions[by_id]
	elif extensions.has(by_name):
		item.extension_type = extensions[by_name]
	elif generated_extensions.has(by_id):
		item.extension_type = generated_extensions[by_id]
	elif generated_extensions.has(by_name):
		item.extension_type = generated_extensions[by_name]
	else:
		item.extension_type = null


static func new_object_from_item(item: FGUIPackageItem, user_class: Variant = null) -> FGUIObject:
	if item == null:
		return null
	_ensure_generated_extensions()
	resolve_package_item_extension(item)
	var obj: FGUIObject = null
	if item.type == FGUIEnums.PACKAGE_ITEM_COMPONENT:
		if user_class != null:
			obj = _create_from(user_class)
		elif item.extension_type != null:
			obj = _create_from(item.extension_type)
		if obj != null and not obj is FGUIComponent:
			push_error("FairyGUI package component creator must return FGUIComponent.")
			obj.dispose()
			obj = null
		if obj == null:
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
			var custom_loader := _create_from(loader_type)
			if custom_loader is FGUILoader:
				return custom_loader
			if custom_loader != null:
				push_error("FairyGUI Loader creator must return FGUILoader.")
				custom_loader.dispose()
			return FGUILoader.new()
		FGUIEnums.OBJECT_LOADER_3D:
			var custom_loader3d := _create_from(loader3d_type)
			if custom_loader3d is FGUILoader3D:
				return custom_loader3d
			if custom_loader3d != null:
				push_error("FairyGUI Loader3D creator must return FGUILoader3D.")
				custom_loader3d.dispose()
			return Loader3D.new()
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


static func _create_from(creator: Variant) -> FGUIObject:
	if creator == null:
		return null
	if creator is String or creator is StringName:
		var script_path := str(creator)
		var loaded_script := ResourceLoader.load(script_path) as Script
		if loaded_script == null:
			push_error("FairyGUI object factory script could not be loaded: %s" % script_path)
			return null
		creator = loaded_script
	var value: Variant = null
	if creator is Callable:
		value = creator.call()
	elif creator is Script:
		if not (creator as Script).can_instantiate():
			push_error("FairyGUI object factory script cannot be instantiated: %s" % (creator as Script).resource_path)
			return null
		value = creator.new()
	else:
		push_error("FairyGUI object factory creator must be a Script, Callable, or script resource path.")
		return null
	if value is FGUIObject:
		return value
	if value != null:
		push_error("FairyGUI object factory creator must return FGUIObject.")
	return null


static func _ensure_generated_extensions() -> void:
	if _generated_registry_loaded or _generated_registry_loading:
		return
	# Editor previews render package data only. Generated application scripts are
	# intentionally not executed inside the editor process unless set explicitly.
	if Engine.is_editor_hint():
		_generated_registry_loaded = true
		_generated_registry_force_reload = false
		return
	_generated_registry_loading = true
	var registry_path := str(ProjectSettings.get_setting("fairygui/codegen/registry_path", DEFAULT_GENERATED_REGISTRY_PATH))
	if registry_path != "" and ResourceLoader.exists(registry_path):
		var cache_mode := ResourceLoader.CACHE_MODE_REPLACE if _generated_registry_force_reload else ResourceLoader.CACHE_MODE_REUSE
		var registry_script := ResourceLoader.load(registry_path, "", cache_mode) as Script
		if registry_script == null:
			push_warning("[FairyGUI codegen] Generated registry could not be loaded: %s" % registry_path)
		else:
			if not registry_script.can_instantiate():
				push_warning("[FairyGUI codegen] Generated registry cannot be instantiated: %s" % registry_path)
				_generated_registry_loaded = true
				_generated_registry_loading = false
				_generated_registry_force_reload = false
				return
			var registry_instance: Variant = registry_script.new()
			if registry_instance != null and registry_instance.has_method("get_bindings"):
				var bindings: Variant = registry_instance.call("get_bindings")
				if bindings is Dictionary:
					set_generated_extensions(bindings)
				else:
					push_warning("[FairyGUI codegen] Generated registry returned an invalid binding table: %s" % registry_path)
			else:
				push_warning("[FairyGUI codegen] Generated registry has no get_bindings() method: %s" % registry_path)
	_generated_registry_loaded = true
	_generated_registry_loading = false
	_generated_registry_force_reload = false
