class_name FGUIController
extends RefCounted

static var _next_page_id: int = 0

var parent: FGUIComponent
var name: String = ""
var _selected_index: int = -1
var previous_index: int = -1
var selected_index: int:
	get:
		return _selected_index
	set(value):
		_set_selected_index(value, true)
var changing: bool = false
var auto_radio_group_depth: bool = false
var actions: Array = []
var _event_listeners: Dictionary = {}
var selected_page_id: String:
	set(value):
		var index := page_ids.find(value)
		if index >= 0:
			_set_selected_index(index, true)
	get:
		return page_ids[_selected_index] if _selected_index >= 0 and _selected_index < page_ids.size() else ""
var selected_page: String:
	get:
		return page_names[_selected_index] if _selected_index >= 0 and _selected_index < page_names.size() else ""
	set(value):
		var index := page_names.find(value)
		_set_selected_index(index if index >= 0 else (0 if not page_names.is_empty() else -1), true)
var opposite_page_id: String:
	set(value):
		var index := page_ids.find(value)
		if index > 0:
			selected_index = 0
		elif page_ids.size() > 1:
			selected_index = 1
var previous_page: String:
	get:
		return page_names[previous_index] if previous_index >= 0 and previous_index < page_names.size() else ""
var previous_page_id: String:
	get:
		return page_ids[previous_index] if previous_index >= 0 and previous_index < page_ids.size() else ""
var page_count: int:
	get:
		return page_ids.size()
var page_ids: Array = []
var page_names: Array = []


func setup(buffer: FGUIByteBuffer) -> void:
	page_ids.clear()
	page_names.clear()
	actions.clear()
	var begin_pos := buffer.pos
	if not buffer.seek(begin_pos, 0):
		return
	name = _string_or_empty(buffer.read_s())
	auto_radio_group_depth = buffer.read_bool()

	if not buffer.seek(begin_pos, 1):
		return
	var count := buffer.read_i16()
	for i in count:
		page_ids.append(buffer.read_s())
		page_names.append(buffer.read_s())

	var home_page_index := 0
	if buffer.version >= 2:
		var home_page_type := buffer.read_i8()
		match home_page_type:
			1:
				home_page_index = buffer.read_i16()
			2:
				home_page_index = max(0, page_names.find(FGUIPackage.branch))
			3:
				home_page_index = max(0, page_names.find(FGUIPackage.get_var(_string_or_empty(buffer.read_s()))))

	if buffer.seek(begin_pos, 2):
		count = buffer.read_i16()
		for i in count:
			var next_pos := buffer.read_i16() + buffer.pos
			var action := FGUIControllerAction.create(buffer.read_i8())
			if action != null:
				action.setup(buffer)
				actions.append(action)
			buffer.pos = next_pos
	_selected_index = home_page_index if page_ids.size() > 0 else -1


func has_page(page_name: String) -> bool:
	return page_names.has(page_name)


func has_page_id(page_id: String) -> bool:
	return page_ids.has(page_id)


func set_selected_index(value: int) -> void:
	_set_selected_index(value, false)


func set_selected_page(value: String) -> void:
	var index := page_names.find(value)
	_set_selected_index(index if index >= 0 else (0 if not page_names.is_empty() else -1), false)


func add_page(page_name: String = "") -> void:
	add_page_at(page_name, page_ids.size())


func add_page_at(page_name: String, index: int) -> void:
	var page_id := "_%s" % _next_page_id
	_next_page_id += 1
	while page_ids.has(page_id):
		page_id = "_%s" % _next_page_id
		_next_page_id += 1
	var insert_index := clampi(index, 0, page_ids.size())
	page_ids.insert(insert_index, page_id)
	page_names.insert(insert_index, page_name)


func remove_page(page_name: String) -> void:
	remove_page_at(page_names.find(page_name))


func remove_page_at(index: int) -> void:
	if index < 0 or index >= page_ids.size():
		return
	page_ids.remove_at(index)
	page_names.remove_at(index)
	if _selected_index >= page_ids.size():
		_set_selected_index(_selected_index - 1, true)
	elif parent != null:
		parent.apply_controller(self)


func clear_pages() -> void:
	page_ids.clear()
	page_names.clear()
	if _selected_index != -1:
		_set_selected_index(-1, true)
	elif parent != null:
		parent.apply_controller(self)


func get_page_id(index: int) -> String:
	return page_ids[index] if index >= 0 and index < page_ids.size() else ""


func get_page_name(index: int) -> String:
	return page_names[index] if index >= 0 and index < page_names.size() else ""


func get_page_index_by_id(page_id: String) -> int:
	return page_ids.find(page_id)


func get_page_id_by_name(page_name: String) -> String:
	var index := page_names.find(page_name)
	return get_page_id(index)


func get_page_name_by_id(page_id: String) -> String:
	var index := page_ids.find(page_id)
	return get_page_name(index)


func run_actions() -> void:
	for action in actions:
		action.run(self, previous_page_id, selected_page_id)


func on(event_name: String, callable: Callable) -> void:
	if not callable.is_valid():
		return
	if not _event_listeners.has(event_name):
		_event_listeners[event_name] = []
	_event_listeners[event_name].append(callable)


func off(event_name: String, callable: Callable) -> void:
	if _event_listeners.has(event_name):
		_event_listeners[event_name].erase(callable)


func has_event_listener(event_name: String) -> bool:
	return _event_listeners.has(event_name) and not _event_listeners[event_name].is_empty()


func dispose() -> void:
	parent = null
	actions.clear()
	_event_listeners.clear()


func _set_selected_index(value: int, emit_change: bool) -> void:
	var next_index := value
	if next_index >= page_ids.size():
		next_index = page_ids.size() - 1
	if next_index < -1:
		next_index = -1
	if _selected_index == next_index:
		return
	changing = true
	previous_index = _selected_index
	_selected_index = next_index
	if parent != null:
		parent.apply_controller(self)
	if emit_change:
		_emit_event(FGUIEvents.STATE_CHANGED)
	changing = false


func _emit_event(event_name: String) -> void:
	if not _event_listeners.has(event_name):
		return
	for callable: Callable in _event_listeners[event_name].duplicate():
		if callable.is_valid():
			callable.call(self)


func _string_or_empty(value: Variant) -> String:
	return "" if value == null else str(value)


class FGUIControllerAction:
	extends RefCounted

	var from_page: Array = []
	var to_page: Array = []

	static func create(action_type: int) -> FGUIControllerAction:
		match action_type:
			0:
				return FGUIPlayTransitionAction.new()
			1:
				return FGUIChangePageAction.new()
			_:
				return null

	func run(controller: FGUIController, previous_page_id: String, current_page_id: String) -> void:
		var from_matches := from_page.is_empty() or from_page.has(previous_page_id)
		var to_matches := to_page.is_empty() or to_page.has(current_page_id)
		if from_matches and to_matches:
			enter(controller)
		else:
			leave(controller)

	func enter(_controller: FGUIController) -> void:
		pass

	func leave(_controller: FGUIController) -> void:
		pass

	func setup(buffer: FGUIByteBuffer) -> void:
		var count := buffer.read_i16()
		from_page.clear()
		for i in count:
			from_page.append(buffer.read_s())
		count = buffer.read_i16()
		to_page.clear()
		for i in count:
			to_page.append(buffer.read_s())


class FGUIPlayTransitionAction:
	extends FGUIControllerAction

	var transition_name: String = ""
	var play_times: int = 1
	var delay: float = 0.0
	var stop_on_exit: bool = false
	var _current_transition: FGUITransition

	func enter(controller: FGUIController) -> void:
		if controller.parent == null:
			return
		var transition := controller.parent.get_transition(transition_name)
		if transition == null:
			return
		if _current_transition != null and _current_transition.playing:
			transition.change_play_times(play_times)
		else:
			transition.play(Callable(), play_times, delay)
		_current_transition = transition

	func leave(_controller: FGUIController) -> void:
		if stop_on_exit and _current_transition != null:
			_current_transition.stop()
			_current_transition = null

	func setup(buffer: FGUIByteBuffer) -> void:
		super.setup(buffer)
		var value = buffer.read_s()
		transition_name = "" if value == null else str(value)
		play_times = buffer.read_i32()
		delay = buffer.read_float32()
		stop_on_exit = buffer.read_bool()


class FGUIChangePageAction:
	extends FGUIControllerAction

	var object_id: String = ""
	var controller_name: String = ""
	var target_page: String = ""

	func enter(controller: FGUIController) -> void:
		if controller_name == "" or controller.parent == null:
			return
		var component: FGUIComponent = controller.parent
		if object_id != "":
			var obj := controller.parent.get_child_by_id(object_id)
			if obj is FGUIComponent:
				component = obj
			else:
				return
		var target_controller := component.get_controller(controller_name)
		if target_controller == null or target_controller == controller or target_controller.changing:
			return
		if target_page == "~1":
			if controller.selected_index < target_controller.page_count:
				target_controller.selected_index = controller.selected_index
		elif target_page == "~2":
			target_controller.selected_page = controller.selected_page
		else:
			target_controller.selected_page_id = target_page

	func setup(buffer: FGUIByteBuffer) -> void:
		super.setup(buffer)
		var value = buffer.read_s()
		object_id = "" if value == null else str(value)
		value = buffer.read_s()
		controller_name = "" if value == null else str(value)
		value = buffer.read_s()
		target_page = "" if value == null else str(value)
