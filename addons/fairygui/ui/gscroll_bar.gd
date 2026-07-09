class_name FGUIScrollBar
extends FGUIComponent

var target: FGUIScrollPane
var vertical: bool = false
var fixed_grip_size: bool = false
var scroll_percent: float = 0.0
var grip_dragging: bool = false

var _grip: FGUIObject
var _bar: FGUIObject
var _arrow_button1: FGUIObject
var _arrow_button2: FGUIObject


func set_scroll_pane(next_target: FGUIScrollPane, is_vertical: bool) -> void:
	target = next_target
	vertical = is_vertical


func construct_extension(buffer: FGUIByteBuffer) -> void:
	if buffer.seek(0, 6):
		fixed_grip_size = buffer.read_bool()
	_grip = get_child("grip")
	_bar = get_child("bar")
	_arrow_button1 = get_child("arrow1")
	_arrow_button2 = get_child("arrow2")


func set_display_percent(value: float) -> void:
	if _grip == null or _bar == null:
		return
	if vertical:
		if not fixed_grip_size:
			_grip.height = floor(value * _bar.height)
		_grip.y = _bar.y + (_bar.height - _grip.height) * scroll_percent
	else:
		if not fixed_grip_size:
			_grip.width = floor(value * _bar.width)
		_grip.x = _bar.x + (_bar.width - _grip.width) * scroll_percent
	_grip.visible = value > 0.0 and value < 1.0


func set_scroll_percent(value: float) -> void:
	scroll_percent = FGUIToolSet.clamp01(value)
	if _grip == null or _bar == null:
		return
	if vertical:
		_grip.y = _bar.y + (_bar.height - _grip.height) * scroll_percent
	else:
		_grip.x = _bar.x + (_bar.width - _grip.width) * scroll_percent


func get_min_size() -> float:
	if vertical:
		return (_arrow_button1.height if _arrow_button1 != null else 0.0) + (_arrow_button2.height if _arrow_button2 != null else 0.0)
	return (_arrow_button1.width if _arrow_button1 != null else 0.0) + (_arrow_button2.width if _arrow_button2 != null else 0.0)
