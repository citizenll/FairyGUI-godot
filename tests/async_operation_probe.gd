extends SceneTree


func _initialize() -> void:
	var operation := FGUIAsyncOperation.new()
	var state := {"sync": true, "count": 0, "result": true}
	operation.callback = func(value: Variant) -> void:
		if state["sync"]:
			_fail("AsyncOperation callback ran in the initiating call stack.")
			return
		state["count"] += 1
		state["result"] = value
	operation.create_object_from_url("ui://missing")
	if not operation.is_running or state["count"] != 0:
		_fail("AsyncOperation did not defer an outstanding request.")
		return
	state["sync"] = false
	await process_frame
	if operation.is_running or state["count"] != 1 or state["result"] != null:
		_fail("AsyncOperation did not complete deferred invalid-url creation correctly.")
		return

	var canceled := {"count": 0}
	operation.callback = func(_value: Variant) -> void: canceled["count"] += 1
	operation.create_object_from_url("ui://missing")
	operation.cancel()
	await process_frame
	if operation.is_running or canceled["count"] != 0:
		_fail("AsyncOperation cancel did not suppress its pending callback.")
		return
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
