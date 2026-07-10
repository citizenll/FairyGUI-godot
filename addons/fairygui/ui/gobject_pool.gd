class_name FGUIObjectPool
extends RefCounted

var _pool: Dictionary = {}
var _count: int = 0

var count: int:
	get:
		return _count


func get_object(url: String) -> FGUIObject:
	url = FGUIPackage.normalize_url(url)
	if url == "":
		return null
	var list: Array = _pool.get(url, [])
	if not list.is_empty():
		_count = maxi(0, _count - 1)
		return list.pop_front()
	return FGUIPackage.create_object_from_url(url)


func return_object(obj: FGUIObject) -> void:
	if obj == null:
		return
	obj.remove_from_parent()
	var url := obj.resource_url
	if url == "":
		return
	if not _pool.has(url):
		_pool[url] = []
	_pool[url].append(obj)
	_count += 1


func clear() -> void:
	for list: Array in _pool.values():
		for obj: FGUIObject in list:
			obj.dispose()
	_pool.clear()
	_count = 0
