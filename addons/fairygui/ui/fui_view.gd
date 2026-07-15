@tool
class_name FGUIView
extends Control

signal fairy_ready(value: FGUIObject)

var _package_resource: FGUIPackageResource
var _component_name: String = ""
var _preview_object: FGUIObject
var _preview_package: FGUIPackage
var _dependency_packages: Array[FGUIPackage] = []
var _component_names := PackedStringArray()
var _refresh_queued: bool = false

@export var package: FGUIPackageResource:
	get:
		return _package_resource
	set(value):
		if _package_resource == value:
			return
		_disconnect_package_changed()
		_package_resource = value
		_connect_package_changed()
		_component_names.clear()
		notify_property_list_changed()
		_queue_preview_refresh()

@export var component_name: String:
	get:
		return _component_name
	set(value):
		if _component_name == value:
			return
		_component_name = value
		_queue_preview_refresh()

@export var component_script: Script:
	set(value):
		component_script = value
		_queue_preview_refresh()

@export var preview_in_editor: bool = true:
	set(value):
		preview_in_editor = value
		_queue_preview_refresh()

@export var resize_to_content: bool = true:
	set(value):
		resize_to_content = value
		_queue_preview_refresh()

@export var match_control_size: bool = false:
	set(value):
		match_control_size = value
		_layout_preview()

var fairy: FGUIObject:
	get:
		return _preview_object


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connect_package_changed()
	if Engine.is_editor_hint():
		_queue_preview_refresh()
	else:
		_refresh_preview()


func _exit_tree() -> void:
	_clear_preview()
	_disconnect_package_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_preview()


func _validate_property(property: Dictionary) -> void:
	if property.name == "component_name":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(_component_names)


func refresh_preview() -> void:
	_refresh_preview()


func get_fairy_object() -> FGUIObject:
	return _preview_object


func _queue_preview_refresh() -> void:
	if not is_inside_tree() or _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_refresh_preview")


func _refresh_preview() -> void:
	_refresh_queued = false
	_clear_preview()
	if _package_resource == null:
		return
	if Engine.is_editor_hint() and not preview_in_editor:
		return

	_preview_package = _package_resource.acquire_package()
	if _preview_package == null:
		return
	_acquire_dependency_packages(_preview_package, {})
	_component_names.clear()
	for item: FGUIPackageItem in _preview_package.items:
		if item.type == FGUIEnums.PACKAGE_ITEM_COMPONENT:
			_component_names.append(item.name)
	notify_property_list_changed()
	if _component_names.is_empty():
		return

	var selected_name := _component_name
	if not _component_names.has(selected_name):
		selected_name = "Main" if _component_names.has("Main") else _component_names[0]
		_component_name = selected_name
		notify_property_list_changed()
	_preview_object = _preview_package.create_object(selected_name, component_script)
	if _preview_object == null or _preview_object.node == null:
		return
	add_child(_preview_object.node)
	if Engine.is_editor_hint():
		_set_editor_mouse_filter(_preview_object.node)
	_layout_preview()
	fairy_ready.emit(_preview_object)


func _clear_preview() -> void:
	if _preview_object != null:
		_preview_object.dispose()
		_preview_object = null
	for pkg in _dependency_packages:
		FGUIPackageResource.release_package(pkg)
	_dependency_packages.clear()
	if _preview_package != null:
		FGUIPackageResource.release_package(_preview_package)
		_preview_package = null


func _layout_preview() -> void:
	if _preview_object == null:
		return
	_preview_object.set_xy(0, 0)
	if match_control_size and size.x > 0.0 and size.y > 0.0:
		_preview_object.set_size(size.x, size.y)
	elif resize_to_content:
		var content_size := Vector2(_preview_object.width, _preview_object.height)
		if content_size.x > 0.0 and content_size.y > 0.0:
			custom_minimum_size = content_size
			if size.x <= 0.0 or size.y <= 0.0:
				size = content_size


func _acquire_dependency_packages(pkg: FGUIPackage, visited: Dictionary) -> void:
	if pkg == null:
		return
	visited[pkg.id] = true
	var base_dir := _package_resource.get_source_path().get_base_dir()
	for dependency: Dictionary in pkg.dependencies:
		var dependency_id := str(dependency.get("id", ""))
		if dependency_id != "" and visited.has(dependency_id):
			continue
		var dependency_name := str(dependency.get("name", ""))
		if dependency_name == "":
			continue
		var dependency_path := "%s/%s.fui" % [base_dir, dependency_name]
		if not ResourceLoader.exists(dependency_path):
			continue
		var dependency_resource := ResourceLoader.load(dependency_path)
		if not (dependency_resource is FGUIPackageResource):
			continue
		var typed_resource := dependency_resource as FGUIPackageResource
		var dependency_package: FGUIPackage = typed_resource.acquire_package()
		if dependency_package == null:
			continue
		_dependency_packages.append(dependency_package)
		_acquire_dependency_packages(dependency_package, visited)


func _connect_package_changed() -> void:
	if _package_resource != null and not _package_resource.changed.is_connected(_on_package_changed):
		_package_resource.changed.connect(_on_package_changed)


func _disconnect_package_changed() -> void:
	if _package_resource != null and _package_resource.changed.is_connected(_on_package_changed):
		_package_resource.changed.disconnect(_on_package_changed)


func _on_package_changed() -> void:
	_queue_preview_refresh()


func _set_editor_mouse_filter(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_set_editor_mouse_filter(child)
