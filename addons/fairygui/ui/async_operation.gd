class_name FGUIAsyncOperation
extends RefCounted

var callback: Callable
var result: FGUIObject


func create_object(package_name: String, resource_name: String) -> void:
	var pkg := FGUIPackage.get_by_name(package_name)
	result = pkg.create_object(resource_name) if pkg != null else null
	if callback.is_valid():
		callback.call(result)


func create_object_from_url(url: String) -> void:
	result = FGUIPackage.create_object_from_url(url)
	if callback.is_valid():
		callback.call(result)


func cancel() -> void:
	callback = Callable()
