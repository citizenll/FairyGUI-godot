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
var _controls_bound: bool = false


func set_scroll_pane(next_target: FGUIScrollPane, is_vertical: bool) -> void:
	target = next_target
	vertical = is_vertical
	_bind_controls()


func dispose() -> void:
	target = null
	_grip = null
	_bar = null
	_arrow_button1 = null
	_arrow_button2 = null
	super.dispose()


func construct_extension(buffer: FGUIByteBuffer) -> void:
	if buffer.seek(0, 6):
		fixed_grip_size = buffer.read_bool()
	_grip = get_child("grip")
	_bar = get_child("bar")
	_arrow_button1 = get_child("arrow1")
	_arrow_button2 = get_child("arrow2")
	_bind_controls()


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


func _bind_controls() -> void:
	if _controls_bound or _grip == null or _bar == null:
		return
	_controls_bound = true
	_grip.draggable = true
	_grip.on(FGUIEvents.DRAG_MOVE, Callable(self, "_on_grip_drag_move"))
	_bar.on("click", Callable(self, "_on_bar_click"))
	if _arrow_button1 != null:
		_arrow_button1.on("click", Callable(self, "_on_arrow1_click"))
	if _arrow_button2 != null:
		_arrow_button2.on("click", Callable(self, "_on_arrow2_click"))


func _on_grip_drag_move(_event: Variant = null) -> void:
	if target == null or _grip == null or _bar == null:
		return
	var value := 0.0
	if vertical:
		value = (_grip.y - _bar.y) / maxf(1.0, _bar.height - _grip.height)
		target.set_perc_y(value)
	else:
		value = (_grip.x - _bar.x) / maxf(1.0, _bar.width - _grip.width)
		target.set_perc_x(value)
	set_scroll_percent(value)


func _on_bar_click(event: Variant = null) -> void:
	if target == null or _grip == null or _bar == null or not (event is InputEvent):
		return
	var local_position := _bar.global_to_local(FGUIToolSet.get_pointer_position(event))
	if vertical:
		if local_position.y < _grip.y - _bar.y:
			target.scroll_up(4.0)
		else:
			target.scroll_down(4.0)
	else:
		if local_position.x < _grip.x - _bar.x:
			target.scroll_left(4.0)
		else:
			target.scroll_right(4.0)


func _on_arrow1_click(_event: Variant = null) -> void:
	if target == null:
		return
	if vertical:
		target.scroll_up()
	else:
		target.scroll_left()


func _on_arrow2_click(_event: Variant = null) -> void:
	if target == null:
		return
	if vertical:
		target.scroll_down()
	else:
		target.scroll_right()
