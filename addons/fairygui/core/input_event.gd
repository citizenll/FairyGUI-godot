class_name FGUIInputEvent
extends RefCounted

const HOLD_TIME_META := &"_fgui_hold_time"

static var current: FGUIInputEvent
static var _pointer_down_times: Dictionary = {}

var native_event: InputEvent
var hold_time: float = 0.0

var position: Vector2:
	get:
		if native_event is InputEventMouse:
			return (native_event as InputEventMouse).global_position
		if native_event is InputEventScreenTouch:
			return (native_event as InputEventScreenTouch).position
		if native_event is InputEventScreenDrag:
			return (native_event as InputEventScreenDrag).position
		return Vector2.ZERO
var x: float:
	get:
		return position.x
var y: float:
	get:
		return position.y
var key_code: int:
	get:
		return int((native_event as InputEventKey).keycode) if native_event is InputEventKey else KEY_NONE
var echo: bool:
	get:
		return (native_event as InputEventKey).echo if native_event is InputEventKey else false
var character: String:
	get:
		if native_event is InputEventKey and (native_event as InputEventKey).unicode > 0:
			return String.chr((native_event as InputEventKey).unicode)
		return ""
var touch_id: int:
	get:
		if native_event is InputEventScreenTouch:
			return (native_event as InputEventScreenTouch).index
		if native_event is InputEventScreenDrag:
			return (native_event as InputEventScreenDrag).index
		return -1
var button: int:
	get:
		return int((native_event as InputEventMouseButton).button_index) if native_event is InputEventMouseButton else MOUSE_BUTTON_NONE
var click_count: int:
	get:
		if native_event is InputEventMouseButton:
			return 2 if (native_event as InputEventMouseButton).double_click else 1
		return 0
var mouse_wheel_delta: float:
	get:
		if not native_event is InputEventMouseButton:
			return 0.0
		var mouse_event := native_event as InputEventMouseButton
		match mouse_event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				return mouse_event.factor
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				return -mouse_event.factor
		return 0.0
var is_double_click: bool:
	get:
		return click_count > 1 and button == MOUSE_BUTTON_LEFT
var ctrl: bool:
	get:
		return (native_event as InputEventWithModifiers).ctrl_pressed if native_event is InputEventWithModifiers else Input.is_key_pressed(KEY_CTRL)
var shift: bool:
	get:
		return (native_event as InputEventWithModifiers).shift_pressed if native_event is InputEventWithModifiers else Input.is_key_pressed(KEY_SHIFT)
var alt: bool:
	get:
		return (native_event as InputEventWithModifiers).alt_pressed if native_event is InputEventWithModifiers else Input.is_key_pressed(KEY_ALT)
var command: bool:
	get:
		return (native_event as InputEventWithModifiers).meta_pressed if native_event is InputEventWithModifiers else Input.is_key_pressed(KEY_META)
var ctrl_or_cmd: bool:
	get:
		return ctrl or command


func _init(event: InputEvent = null) -> void:
	update(event)


func update(event: InputEvent) -> void:
	native_event = event
	hold_time = 0.0
	if event == null:
		return
	if event.has_meta(HOLD_TIME_META):
		hold_time = float(event.get_meta(HOLD_TIME_META))
		return
	var pointer_id := touch_id
	var now := Time.get_ticks_msec() / 1000.0
	var is_press: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	var is_release: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
		or (event is InputEventScreenTouch and not event.pressed)
	if is_press:
		_pointer_down_times[pointer_id] = now
	elif _pointer_down_times.has(pointer_id):
		hold_time = maxf(0.0, now - float(_pointer_down_times[pointer_id]))
		if is_release:
			_pointer_down_times.erase(pointer_id)
		event.set_meta(HOLD_TIME_META, hold_time)
