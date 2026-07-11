extends SceneTree


class CustomComponent extends FGUIComponent:
	var custom_marker: String = "component"


class CustomLoader extends FGUILoader:
	var custom_marker: String = "loader"


class CustomLoader3D extends FGUILoader3D:
	var custom_marker: String = "loader3d"


func _initialize() -> void:
	FGUIObjectFactory.clear()
	var package := FGUIPackage.new()
	package.id = "FACTORY1"
	package.name = "FactoryProbe"
	var item := FGUIPackageItem.new()
	item.owner = package
	item.id = "component"
	item.name = "Component"
	item.type = FGUIEnums.PACKAGE_ITEM_COMPONENT
	item.object_type = FGUIEnums.OBJECT_COMPONENT

	var component_creations := [0]
	FGUIObjectFactory.set_extension("ui://FACTORY1component", func() -> FGUIObject:
		component_creations[0] += 1
		return CustomComponent.new()
	)
	FGUIObjectFactory.resolve_package_item_extension(item)
	var component := FGUIObjectFactory.new_object_from_item(item)
	if not component is CustomComponent or component.package_item != item or component_creations[0] != 1:
		_cleanup(component, null, null, package)
		_fail("UIObjectFactory did not construct a package component through a Callable creator.")
		return

	FGUIObjectFactory.set_loader_extension(func() -> FGUIObject: return CustomLoader.new())
	FGUIObjectFactory.set_loader3d_extension(func() -> FGUIObject: return CustomLoader3D.new())
	var loader := FGUIObjectFactory.new_object(FGUIEnums.OBJECT_LOADER)
	var loader3d := FGUIObjectFactory.new_object(FGUIEnums.OBJECT_LOADER_3D)
	if not loader is CustomLoader or not loader3d is CustomLoader3D:
		_cleanup(component, loader, loader3d, package)
		_fail("UIObjectFactory did not use Callable Loader creators.")
		return

	FGUIObjectFactory.clear()
	FGUIObjectFactory.resolve_package_item_extension(item)
	var default_component := FGUIObjectFactory.new_object_from_item(item)
	var default_loader := FGUIObjectFactory.new_object(FGUIEnums.OBJECT_LOADER)
	var default_loader3d := FGUIObjectFactory.new_object(FGUIEnums.OBJECT_LOADER_3D)
	if item.extension_type != null or not default_component is FGUIComponent or default_component is CustomComponent:
		_cleanup(component, loader, loader3d, package, [default_component, default_loader, default_loader3d])
		_fail("UIObjectFactory.clear did not remove package component creators.")
		return
	if not default_loader is FGUILoader or default_loader is CustomLoader or not default_loader3d is FGUILoader3D or default_loader3d is CustomLoader3D:
		_cleanup(component, loader, loader3d, package, [default_component, default_loader, default_loader3d])
		_fail("UIObjectFactory.clear did not restore default Loader creators.")
		return

	_cleanup(component, loader, loader3d, package, [default_component, default_loader, default_loader3d])
	quit(0)


func _cleanup(component: FGUIObject, loader: FGUIObject, loader3d: FGUIObject, package: FGUIPackage, extra: Array = []) -> void:
	for obj: FGUIObject in [component, loader, loader3d] + extra:
		if obj != null and not obj.is_disposed:
			obj.dispose()
	FGUIObjectFactory.clear()
	package.dispose()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
