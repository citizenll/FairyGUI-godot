class_name FGUIAsyncOperation
extends RefCounted

var callback: Callable
var result: FGUIObject
var is_running: bool = false

var _generation: int = 0
var _package_name: String = ""
var _resource_name: String = ""
var _url: String = ""
var _from_url: bool = false


func create_object(package_name: String, resource_name: String) -> void:
	_package_name = package_name
	_resource_name = resource_name
	_url = ""
	_from_url = false
	_schedule()


func create_object_from_url(url: String) -> void:
	_package_name = ""
	_resource_name = ""
	_url = url
	_from_url = true
	_schedule()


func cancel() -> void:
	_generation += 1
	is_running = false
	callback = Callable()
	_package_name = ""
	_resource_name = ""
	_url = ""


func _schedule() -> void:
	_generation += 1
	result = null
	is_running = true
	var token := _generation
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		_complete(token)
		return
	tree.process_frame.connect(Callable(self, "_complete").bind(token), CONNECT_ONE_SHOT)


func _complete(token: int) -> void:
	if token != _generation or not is_running:
		return
	if _from_url:
		result = FGUIPackage.create_object_from_url(_url)
	else:
		var pkg := FGUIPackage.get_by_name(_package_name)
		result = pkg.create_object(_resource_name) if pkg != null else null
	is_running = false
	if callback.is_valid():
		callback.call(result)
