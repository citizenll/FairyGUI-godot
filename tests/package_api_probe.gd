extends SceneTree


func _initialize() -> void:
	var text_path := "user://fairygui_misc_asset_probe.txt"
	var file := FileAccess.open(text_path, FileAccess.WRITE)
	if file == null:
		_fail("Could not create the miscellaneous package asset fixture.")
		return
	file.store_string("FairyGUI misc asset")
	file.close()

	var package := FGUIPackage.new()
	package.id = "package"
	package.name = "PackageApiProbe"
	package.set_custom_id("TESTPKG1")

	var atlas := _make_item(package, "atlas", FGUIEnums.PACKAGE_ITEM_ATLAS)
	atlas.file = "res://examples/assets/ui/VirtualList_atlas0.png"
	var image := _make_item(package, "image", FGUIEnums.PACKAGE_ITEM_IMAGE)
	var misc := _make_item(package, "misc", FGUIEnums.PACKAGE_ITEM_MISC)
	misc.file = text_path
	package.items = [image, atlas, misc]
	package._items_by_id = {image.id: image, atlas.id: atlas, misc.id: misc}
	package._sprites = {
		image.id: {
			"atlas": atlas,
			"rect": Rect2i(0, 0, 8, 8),
			"rotated": false,
			"offset": Vector2i.ZERO,
			"original_size": Vector2i(8, 8),
		}
	}

	if package.get_items() != package.items:
		_cleanup(package, text_path)
		_fail("Package item enumeration did not expose the package item collection.")
		return

	package.load_all_assets()
	if atlas.texture == null or image.texture == null:
		_cleanup(package, text_path)
		_fail("Package bulk asset loading did not decode atlas and image resources.")
		return
	if misc.misc_asset != "FairyGUI misc asset":
		_cleanup(package, text_path)
		_fail("Miscellaneous text assets were not loaded from the package item path.")
		return
	if FGUIPackage.get_item_asset_by_url("ui://TESTPKG1image") != image.texture:
		_cleanup(package, text_path)
		_fail("Static package asset URL lookup did not return the decoded item asset.")
		return

	var callback_state := {"called": false, "error": -1, "item": null}
	package.get_item_asset_async(misc, func(error: Variant, loaded_item: FGUIPackageItem) -> void:
		callback_state["called"] = true
		callback_state["error"] = error
		callback_state["item"] = loaded_item
	)
	if not callback_state["called"] or callback_state["error"] != null or callback_state["item"] != misc:
		_cleanup(package, text_path)
		_fail("Supported asynchronous asset lookup did not complete with the package item.")
		return

	var movie_clip := _make_item(package, "movie", FGUIEnums.PACKAGE_ITEM_MOVIE_CLIP)
	movie_clip.decoded = true
	movie_clip.frames = [{"texture": image.texture}]
	var sound := _make_item(package, "sound", FGUIEnums.PACKAGE_ITEM_SOUND)
	sound.decoded = true
	sound.audio = AudioStreamWAV.new()
	var font := _make_item(package, "font", FGUIEnums.PACKAGE_ITEM_FONT)
	font.decoded = true
	font.bitmap_font = FGUIBitmapFont.new()
	package.items.append_array([movie_clip, sound, font])

	package.unload_assets()
	if atlas.decoded or atlas.texture != null or image.decoded or image.texture != null:
		_cleanup(package, text_path)
		_fail("Package asset unloading did not release atlas and image resources.")
		return
	if misc.decoded or misc.misc_asset != null or movie_clip.decoded or not movie_clip.frames.is_empty():
		_cleanup(package, text_path)
		_fail("Package asset unloading did not reset miscellaneous or movie-clip resources.")
		return
	if sound.decoded or sound.audio != null or font.decoded or font.bitmap_font != null:
		_cleanup(package, text_path)
		_fail("Package asset unloading did not reset sound or bitmap-font resources.")
		return

	if package.get_item_asset(image) == null or package.get_item_asset(misc) != "FairyGUI misc asset":
		_cleanup(package, text_path)
		_fail("Package assets could not be decoded again after unloading.")
		return

	_cleanup(package, text_path)
	quit(0)


func _make_item(package: FGUIPackage, item_id: String, item_type: int) -> FGUIPackageItem:
	var item := FGUIPackageItem.new()
	item.owner = package
	item.id = item_id
	item.name = item_id
	item.type = item_type
	return item


func _cleanup(package: FGUIPackage, text_path: String) -> void:
	package.set_custom_id("")
	package.dispose()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(text_path))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
