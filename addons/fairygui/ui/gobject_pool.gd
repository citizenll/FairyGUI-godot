class_name FGUIObjectPool
extends RefCounted

var _pool: Dictionary = {}


func get_object(url: String) -> FGUIObject:
	url = FGUIPackage.normalize_url(url)
	var list: Array = _pool.get(url, [])
	if not list.is_empty():
		return list.pop_front()
	return FGUIPackage.create_object_from_url(url)


func return_object(obj: FGUIObject) -> void:
	if obj == null:
		return
	obj.remove_from_parent()
	var url := ""
	if obj.package_item != null:
		url = "ui://%s%s" % [obj.package_item.owner.id, obj.package_item.id]
	if url == "":
		obj.dispose()
		return
	if not _pool.has(url):
		_pool[url] = []
	_pool[url].append(obj)


func clear() -> void:
	for list: Array in _pool.values():
		for obj: FGUIObject in list:
			obj.dispose()
	_pool.clear()
