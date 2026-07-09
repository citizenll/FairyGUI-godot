extends SceneTree


func _initialize() -> void:
	var classes: Array = [
		FGUIObject,
		FGUIComponent,
		FGUIRoot,
		FGUIWindow,
		FGUIImage,
		FGUIMovieClip,
		FGUITextField,
		FGUIRichTextField,
		FGUITextInput,
		FGUILoader,
		FGUIGraph,
		FGUIGroup,
		FGUILabel,
		FGUIButton,
		FGUIProgressBar,
		FGUISlider,
		FGUIScrollBar,
		FGUIComboBox,
		FGUIList,
		FGUITree,
		FGUITreeNode,
		FGUIObjectPool,
		FGUIPopupMenu,
		FGUIDragDropManager,
		FGUIAsyncOperation,
		FGUITransition,
		FGUIGearBase,
		FGUIGearDisplay,
		FGUIGearXY,
		FGUIGearSize,
		FGUIGearLook,
		FGUIGearColor,
		FGUIGearAnimation,
		FGUIGearText,
		FGUIGearIcon,
		FGUIGearDisplay2,
		FGUIGearFontSize,
		FGUIEaseManager,
		FGUIEaseType,
		FGUIGTween,
		FGUIGTweener,
		FGUITweenManager,
		FGUITweenValue,
		FGUIGPath,
		FGUIGPathPoint,
	]
	if classes.is_empty():
		quit(1)
		return
	var dir := DirAccess.open("res://examples/assets/ui")
	if dir == null:
		push_error("Demo asset folder is missing.")
		quit(1)
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".fui"):
			continue
		var package_path := "res://examples/assets/ui/%s" % file_name.trim_suffix(".fui")
		var pkg := FGUIPackage.add_package(package_path)
		if pkg == null:
			push_error("Package failed to load: %s" % package_path)
			quit(1)
			return
		if pkg.items.is_empty():
			push_error("Package has no items: %s" % package_path)
			quit(1)
			return
		var main_item := pkg.get_item_by_name("Main")
		if main_item != null:
			var view := pkg.create_object("Main")
			if view == null:
				push_error("Main object failed to instantiate: %s" % package_path)
				quit(1)
				return
			view.dispose()
	quit(0)
