extends SceneTree

const MENU_BINDINGS := {
	"n1": "Basics",
	"n2": "Transition",
	"n4": "VirtualList",
	"n5": "LoopList",
	"n6": "HitTest",
	"n7": "PullToRefresh",
	"n8": "ModalWaiting",
	"n9": "Joystick",
	"n10": "Bag",
	"n11": "Chat",
	"n12": "ListEffect",
	"n13": "ScrollPane",
	"n14": "TreeView",
	"n15": "Guide",
	"n16": "Cooldown",
}

var _demo: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1136, 640)
	var packed := load("res://demo.tscn") as PackedScene
	if packed == null:
		_fail("Root demo.tscn could not be loaded.")
		return
	_demo = packed.instantiate() as Control
	if _demo == null:
		_fail("Root demo.tscn did not instantiate as Control.")
		return
	root.add_child(_demo)
	await _wait_frames(4)
	if _demo.get_current_demo_name() != "MainMenu" or _demo.get_current_view() == null:
		_fail("FairyGUI demo did not start at MainMenu.")
		return
	for button_name: String in MENU_BINDINGS:
		var button: FGUIObject = _demo.get_current_view().get_child(button_name)
		if button == null:
			_fail("MainMenu button is missing: %s" % button_name)
			return
		await _native_click(button)
		await _wait_frames(2)
		if _demo.get_current_demo_name() != str(MENU_BINDINGS[button_name]):
			_fail("MainMenu button %s did not open %s." % [button_name, MENU_BINDINGS[button_name]])
			return
		var close_button := _find_close_button()
		if close_button == null:
			_fail("Demo close button was not attached for %s." % MENU_BINDINGS[button_name])
			return
		await _native_click(close_button)
		await _wait_frames(2)
		if _demo.get_current_demo_name() != "MainMenu":
			_fail("Demo close button did not return from %s." % MENU_BINDINGS[button_name])
			return

	for demo_name: String in _demo.get_demo_names():
		if not _demo.open_demo(demo_name):
			_fail("Demo failed to open: %s" % demo_name)
			return
		await _wait_frames(3)
		if _demo.get_current_demo_name() != demo_name or _demo.get_current_view() == null:
			_fail("Demo view was not retained: %s" % demo_name)
			return
		if demo_name == "Basics":
			for demo_type: String in _demo.get_basic_demo_types():
				if not _demo.open_basic_demo(demo_type):
					_fail("Basics sub-demo failed to open: %s" % demo_type)
					return
				await process_frame
		elif demo_name == "Transition":
			_demo.get_current_view().get_child("btn0").emit_event("click")
			await _wait_frames(2)
		elif demo_name == "VirtualList":
			_demo.get_current_view().get_child("n6").emit_event("click")
			await _wait_frames(2)
		elif demo_name == "ModalWaiting":
			_demo.get_current_view().get_child("n0").emit_event("click")
			await _wait_frames(2)
		elif demo_name == "Bag":
			_demo.get_current_view().get_child("bagBtn").emit_event("click")
			await _wait_frames(2)
		elif demo_name == "Chat":
			var input := _demo.get_current_view().get_child("input1") as FGUITextInput
			input.set_text("Godot [:88]")
			_demo.get_current_view().get_child("btnSend1").emit_event("click")
			await _wait_frames(2)
		elif demo_name == "Guide":
			_demo.get_current_view().get_child("n2").emit_event("click")
			await _wait_frames(2)
		_demo.return_to_menu()
		await _wait_frames(3)
		if _demo.get_current_demo_name() != "MainMenu":
			_fail("Demo did not return to MainMenu after %s." % demo_name)
			return

	_demo.queue_free()
	await _wait_frames(8)
	quit(0)


func _wait_frames(count: int) -> void:
	for _index in count:
		await process_frame


func _native_click(object: FGUIObject) -> void:
	var position := object.node.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await process_frame
	root.push_input(_mouse_button(position, true))
	await process_frame
	root.push_input(_mouse_button(position, false))
	await process_frame


func _find_close_button() -> FGUIObject:
	for child: FGUIObject in FGUIRoot.get_inst().children:
		if child.sorting_order == 100000:
			return child
	return null


func _mouse_button(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event


func _fail(message: String) -> void:
	push_error(message)
	if _demo != null and is_instance_valid(_demo):
		_demo.queue_free()
	quit(1)
