class_name FGUIButton
extends FGUIComponent

const UP := "up"
const DOWN := "down"
const OVER := "over"
const SELECTED_OVER := "selectedOver"
const DISABLED := "disabled"
const SELECTED_DISABLED := "selectedDisabled"

var mode: int = FGUIEnums.BUTTON_COMMON
var change_state_on_click: bool = true
var linked_popup: FGUIObject
var related_controller: FGUIController
var related_page_id: String = ""
var sound: Variant = null
var sound_volume_scale: float = 1.0

var _title_object: FGUIObject
var _icon_object: FGUIObject
var _button_controller: FGUIController
var _title: String = ""
var _selected_title: String = ""
var _icon: String = ""
var _selected_icon: String = ""
var _selected: bool = false
var _down_effect: int = 0
var _down_effect_value: float = 0.8
var _button_touch_index: int = -2
var _down: bool = false
var _over: bool = false
var _down_scaled: bool = false
var _fire_click_token: int = 0

var selected: bool:
	get:
		return _selected
	set(value):
		if mode == FGUIEnums.BUTTON_COMMON:
			return
		if _selected == value:
			return
		_selected = value
		_refresh_button_state()
		if _title_object != null:
			_title_object.set_text(_selected_title if _selected and _selected_title != "" else _title)
		if _icon_object != null:
			_icon_object.set_icon(_selected_icon if _selected and _selected_icon != "" else _icon)
		if related_controller != null and parent != null and not parent._building_display_list:
			if _selected:
				related_controller.selected_page_id = related_page_id
				if related_controller.auto_radio_group_depth:
					parent.adjust_radio_group_depth(self, related_controller)
			elif mode == FGUIEnums.BUTTON_CHECK and related_controller.selected_page_id == related_page_id:
				related_controller.selected_index = -1
var title: String:
	get:
		return _title
	set(value):
		_title = value
		if _title_object != null:
			_title_object.set_text(_selected_title if _selected and _selected_title != "" else _title)
		update_gear(6)
var selected_title: String:
	get:
		return _selected_title
	set(value):
		_selected_title = value
		if _title_object != null and _selected:
			_title_object.set_text(_selected_title)
var icon: String:
	get:
		return _icon
	set(value):
		_icon = value
		if _icon_object != null:
			_icon_object.set_icon(_selected_icon if _selected and _selected_icon != "" else _icon)
		update_gear(7)
var selected_icon: String:
	get:
		return _selected_icon
	set(value):
		_selected_icon = value
		if _icon_object != null and _selected:
			_icon_object.set_icon(_selected_icon)
var title_color: Color:
	get:
		var field := get_text_field()
		return field.color if field != null else Color.BLACK
	set(value):
		var field := get_text_field()
		if field != null:
			field.color = value
		update_gear(4)
var title_font_size: int:
	get:
		var field := get_text_field()
		return field.font_size if field != null else 0
	set(value):
		var field := get_text_field()
		if field != null:
			field.font_size = value


func _init() -> void:
	super._init()
	sound = FGUIConfig.button_sound
	sound_volume_scale = FGUIConfig.button_sound_volume_scale
	on(FGUIEvents.CLICK, Callable(self, "_handle_click"))


func construct_extension(buffer: FGUIByteBuffer) -> void:
	if buffer.seek(0, 6):
		mode = buffer.read_i8()
		var next_sound = buffer.read_s()
		if next_sound != null:
			sound = str(next_sound)
		sound_volume_scale = buffer.read_float32()
		_down_effect = buffer.read_i8()
		_down_effect_value = buffer.read_float32()
		if _down_effect == 2:
			set_pivot(0.5, 0.5, _pivot_as_anchor)
	_button_controller = get_controller("button")
	_title_object = get_child("title")
	_icon_object = get_child("icon")
	_title = _title_object.get_text() if _title_object != null else ""
	_icon = _icon_object.get_icon() if _icon_object != null else ""
	_refresh_button_state()


func get_text() -> String:
	return title


func set_text(value: String) -> void:
	title = value


func get_icon() -> String:
	return icon


func set_icon(value: String) -> void:
	icon = value


func get_text_field() -> FGUITextField:
	if _title_object is FGUITextField:
		return _title_object
	if _title_object != null and _title_object.has_method("get_text_field"):
		return _title_object.call("get_text_field")
	return null


func set_state(value: String) -> void:
	if _button_controller != null and _button_controller.has_page(value):
		_button_controller.selected_page = value
	var pressed_state := value == DOWN or value == SELECTED_OVER or value == SELECTED_DISABLED
	if _down_effect == 1:
		var tint := Color(_down_effect_value, _down_effect_value, _down_effect_value) if pressed_state else Color.WHITE
		for child: FGUIObject in children:
			if not (child is FGUITextField):
				child.set_prop(FGUIEnums.OBJECT_PROP_COLOR, tint)
	elif _down_effect == 2:
		if pressed_state and not _down_scaled:
			set_scale(scale_x * _down_effect_value, scale_y * _down_effect_value)
			_down_scaled = true
		elif not pressed_state and _down_scaled:
			set_scale(scale_x / _down_effect_value, scale_y / _down_effect_value)
			_down_scaled = false


func fire_click(down_effect: bool = true) -> void:
	if down_effect and mode == FGUIEnums.BUTTON_COMMON:
		_fire_click_token += 1
		set_state(OVER)
		_play_fire_click_effect.call_deferred(_fire_click_token)
	emit_event("click")


func _play_fire_click_effect(token: int) -> void:
	if node == null or not node.is_inside_tree():
		if token == _fire_click_token:
			set_state(UP)
		return
	await node.get_tree().create_timer(0.1).timeout
	if token != _fire_click_token or node == null or not node.is_inside_tree():
		return
	set_state(DOWN)
	await node.get_tree().create_timer(0.1).timeout
	if token == _fire_click_token and node != null:
		set_state(UP)


func handle_controller_changed(controller: FGUIController) -> void:
	super.handle_controller_changed(controller)
	if related_controller == controller:
		selected = related_page_id == controller.selected_page_id


func setup_after_add(buffer: FGUIByteBuffer, begin_pos: int) -> void:
	super.setup_after_add(buffer, begin_pos)
	if not buffer.seek(begin_pos, 6):
		return
	if buffer.read_i8() != package_item.object_type:
		return
	var value = buffer.read_s()
	if value != null:
		title = str(value)
	value = buffer.read_s()
	if value != null:
		selected_title = str(value)
	value = buffer.read_s()
	if value != null:
		icon = str(value)
	value = buffer.read_s()
	if value != null:
		selected_icon = str(value)
	if buffer.read_bool():
		title_color = buffer.read_color()
	var size := buffer.read_i32()
	if size != 0:
		title_font_size = size
	var controller_index := buffer.read_i16()
	if controller_index >= 0 and parent != null:
		related_controller = parent.get_controller_at(controller_index)
	value = buffer.read_s()
	if value != null:
		related_page_id = str(value)
	value = buffer.read_s()
	if value != null:
		sound = str(value)
	if buffer.read_bool():
		sound_volume_scale = buffer.read_float32()
	selected = buffer.read_bool()


func get_prop(index: int) -> Variant:
	match index:
		FGUIEnums.OBJECT_PROP_SELECTED:
			return selected
		FGUIEnums.OBJECT_PROP_COLOR:
			return title_color
		FGUIEnums.OBJECT_PROP_OUTLINE_COLOR:
			var field := get_text_field()
			return field.stroke_color if field != null else Color.BLACK
		FGUIEnums.OBJECT_PROP_FONT_SIZE:
			return title_font_size
		_:
			return super.get_prop(index)


func set_prop(index: int, value: Variant) -> void:
	match index:
		FGUIEnums.OBJECT_PROP_SELECTED:
			selected = bool(value)
		FGUIEnums.OBJECT_PROP_COLOR:
			if value is Color:
				title_color = value
		FGUIEnums.OBJECT_PROP_OUTLINE_COLOR:
			var field := get_text_field()
			if field != null and value is Color:
				field.stroke_color = value
		FGUIEnums.OBJECT_PROP_FONT_SIZE:
			title_font_size = int(value)
		_:
			super.set_prop(index, value)


func _on_gui_input(event: InputEvent) -> void:
	if FGUIToolSet.is_primary_pointer_press(event):
		_button_touch_index = FGUIToolSet.get_pointer_id(event)
		_down = true
		if mode == FGUIEnums.BUTTON_COMMON:
			_refresh_button_state()
		if linked_popup != null:
			var root_object := root
			if root_object != null:
				root_object._check_popups(FGUIToolSet.get_pointer_position(event))
		_toggle_linked_popup()
		if linked_popup != null and node != null:
			node.accept_event()
	elif FGUIToolSet.is_primary_pointer_release(event) and _button_touch_index == FGUIToolSet.get_pointer_id(event):
		_down = false
		if mode == FGUIEnums.BUTTON_COMMON:
			_refresh_button_state()
	super._on_gui_input(event)
	if FGUIToolSet.is_primary_pointer_release(event) and _button_touch_index == FGUIToolSet.get_pointer_id(event):
		_button_touch_index = -2


func _handle_click(event: Variant) -> void:
	match mode:
		FGUIEnums.BUTTON_CHECK:
			if change_state_on_click:
				selected = not selected
				emit_event(FGUIEvents.STATE_CHANGED, event)
		FGUIEnums.BUTTON_RADIO:
			if change_state_on_click and not selected:
				selected = true
				emit_event(FGUIEvents.STATE_CHANGED, event)
		_:
			if related_controller != null:
				related_controller.selected_page_id = related_page_id
	if sound != null:
		root.play_one_shot_sound(sound, sound_volume_scale)


func _handle_roll_over() -> void:
	super._handle_roll_over()
	_over = true
	if not _down:
		_refresh_button_state()


func _handle_roll_out() -> void:
	super._handle_roll_out()
	_over = false
	if not _down:
		_refresh_button_state()


func _handle_grayed_changed() -> void:
	if _button_controller != null and _button_controller.has_page(DISABLED):
		_refresh_button_state()
	else:
		super._handle_grayed_changed()


func _refresh_button_state() -> void:
	var has_disabled := _button_controller != null and _button_controller.has_page(DISABLED)
	if grayed and has_disabled:
		set_state(SELECTED_DISABLED if _selected and _button_controller.has_page(SELECTED_DISABLED) else DISABLED)
		return
	if _down and mode == FGUIEnums.BUTTON_COMMON:
		set_state(DOWN)
	elif _selected:
		set_state(SELECTED_OVER if _over and _button_controller != null and _button_controller.has_page(SELECTED_OVER) else DOWN)
	else:
		set_state(OVER if _over and _button_controller != null and _button_controller.has_page(OVER) else UP)


func _toggle_linked_popup() -> void:
	if linked_popup == null:
		return
	if linked_popup is FGUIWindow:
		(linked_popup as FGUIWindow).toggle_status()
		return
	var root_object := root
	if root_object != null:
		root_object.toggle_popup(linked_popup, self)


func dispose() -> void:
	_fire_click_token += 1
	if _down_scaled:
		set_state(UP)
	linked_popup = null
	related_controller = null
	_button_controller = null
	_title_object = null
	_icon_object = null
	super.dispose()
