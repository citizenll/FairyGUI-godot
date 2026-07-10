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
	var url := obj.resource_url
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
