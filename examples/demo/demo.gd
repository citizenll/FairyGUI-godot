extends Control

const ExportSmokeScript := preload("res://examples/minimal/export_smoke.gd")

const UI_ROOT := "res://examples/assets/ui"
const ICON_ROOT := "res://examples/assets/icons"
const DESIGN_SIZE := Vector2(1136.0, 640.0)
const INACTIVE_POINTER := -2147483648
const DEMO_NAMES: Array[String] = [
	"Basics",
	"Transition",
	"VirtualList",
	"LoopList",
	"HitTest",
	"PullToRefresh",
	"ModalWaiting",
	"Joystick",
	"Bag",
	"Chat",
	"ListEffect",
	"ScrollPane",
	"TreeView",
	"Guide",
	"Cooldown",
]
const BASIC_DEMO_TYPES: Array[String] = [
	"Graph",
	"Image",
	"MovieClip",
	"Text",
	"Loader",
	"List",
	"Grid",
	"Controller",
	"Relation",
	"Clip&Scroll",
	"Component",
	"Label",
	"Button",
	"ComboBox",
	"Slider",
	"ProgressBar",
	"Popup",
	"Window",
	"Depth",
	"Drag&Drop",
]
const EMOJI_TAGS: Array[String] = [
	"88", "am", "bs", "bz", "ch", "cool", "dhq", "dn", "fd", "gz", "han", "hx", "hxiao", "hxiu",
]
const ACTION_CONNECTED_META := &"_fairygui_demo_action_connected"

var _root_ui: FGUIRoot
var _main_package: FGUIPackage
var _current_package: FGUIPackage
var _view: FGUIComponent
var _close_button: FGUIObject
var _current_demo_name := ""
var _session_id := 0
var _pending_navigation := ""
var _navigation_scheduled := false
var _rng := RandomNumberGenerator.new()
var _owned_objects: Array[FGUIObject] = []
var _windows: Array[FGUIWindow] = []
var _tweeners: Array[FGUIGTweener] = []

var _basic_container: UI_BasicsComponent4
var _basic_controller: FGUIController
var _basic_back_button: FGUIObject
var _basic_demo_objects: Dictionary = {}
var _basic_active_type := ""
var _basic_progress_accumulator := 0.0
var _basic_popup_menu: FGUIPopupMenu
var _basic_popup_component: UI_BasicsComponent12
var _basic_window_a: FGUIWindow
var _basic_window_b: FGUIWindow
var _depth_start_position := Vector2.ZERO

var _transition_group: FGUIGroup
var _transition_objects: Dictionary = {}
var _transition_start_value := 0.0
var _transition_end_value := 0.0

var _loop_list: FGUIList

var _pull_list_1: FGUIList
var _pull_list_2: FGUIList

var _modal_window: FGUIWindow

var _joystick_button: FGUIButton
var _joystick_touch_area: FGUIObject
var _joystick_thumb: FGUIObject
var _joystick_center: FGUIObject
var _joystick_text: FGUIObject
var _joystick_initial_center := Vector2.ZERO
var _joystick_start := Vector2.ZERO
var _joystick_pointer_id := INACTIVE_POINTER
var _joystick_radius := 150.0

var _bag_window: FGUIWindow
var _bag_content: UI_BagBagWin
var _bag_list: FGUIList

var _chat_list: FGUIList
var _chat_input: FGUITextInput
var _emoji_select_ui: UI_ChatEmojiSelectUi
var _messages: Array[Dictionary] = []

var _scroll_list: FGUIList

var _guide_layer: UI_GuideGuideLayer


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--fairygui-export-smoke"):
		add_child(ExportSmokeScript.new())
		return
	_rng.randomize()
	_root_ui = FGUIRoot.get_inst()
	_root_ui.attach_to(self)
	_root_ui._disconnect_viewport()
	resized.connect(_layout_demo_root)
	_layout_demo_root()
	_main_package = _ensure_package("MainMenu")
	if _main_package == null:
		push_error("FairyGUI demo could not load MainMenu.fui.")
		return
	_show_main_menu()


func _layout_demo_root() -> void:
	if _root_ui == null or _root_ui.node == null:
		return
	var available := size
	if available.x <= 0.0 or available.y <= 0.0:
		available = get_viewport_rect().size
	var scale_factor := minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y)
	scale_factor = maxf(scale_factor, 0.001)
	_root_ui.set_size(DESIGN_SIZE.x, DESIGN_SIZE.y)
	_root_ui.node.scale = Vector2.ONE * scale_factor
	_root_ui.node.position = (available - DESIGN_SIZE * scale_factor) * 0.5


func _exit_tree() -> void:
	if _root_ui == null:
		return
	_cleanup_current()
	if FGUIPackage.get_by_name("MainMenu") == _main_package:
		FGUIPackage.remove_package_instance(_main_package)
	_main_package = null
	if resized.is_connected(_layout_demo_root):
		resized.disconnect(_layout_demo_root)
	if _root_ui != null and not _root_ui.is_disposed:
		_root_ui.dispose()
	_root_ui = null


func _process(delta: float) -> void:
	if _basic_active_type != "ProgressBar":
		return
	var progress_demo: FGUIComponent = _basic_demo_objects.get("ProgressBar")
	if progress_demo == null or progress_demo.is_disposed:
		return
	_basic_progress_accumulator += delta * 30.0
	if _basic_progress_accumulator < 1.0:
		return
	var amount := floorf(_basic_progress_accumulator)
	_basic_progress_accumulator -= amount
	for child: FGUIObject in progress_demo.children:
		if child is FGUIProgressBar:
			var progress := child as FGUIProgressBar
			progress.value += amount
			if progress.value > progress.max:
				progress.value = progress.min


func _input(event: InputEvent) -> void:
	if _joystick_pointer_id == INACTIVE_POINTER:
		return
	var pointer_id := FGUIToolSet.get_pointer_id(event)
	if pointer_id != _joystick_pointer_id:
		return
	if FGUIToolSet.is_pointer_motion(event):
		_update_joystick(FGUIToolSet.get_pointer_position(event))
	elif FGUIToolSet.is_primary_pointer_release(event):
		_release_joystick()


func open_demo(demo_name: String) -> bool:
	if not DEMO_NAMES.has(demo_name):
		return false
	_start_demo(demo_name)
	return _current_demo_name == demo_name and _view != null


func return_to_menu() -> void:
	_show_main_menu()


func get_current_demo_name() -> String:
	return _current_demo_name


func get_current_view() -> FGUIComponent:
	return _view


func get_demo_names() -> Array[String]:
	return DEMO_NAMES.duplicate()


func get_basic_demo_types() -> Array[String]:
	return BASIC_DEMO_TYPES.duplicate()


func open_basic_demo(demo_type: String) -> bool:
	if _current_demo_name != "Basics" or not BASIC_DEMO_TYPES.has(demo_type):
		return false
	_run_basic_demo(null, demo_type)
	return _basic_active_type == demo_type


func _ensure_package(package_name: String) -> FGUIPackage:
	var loaded := FGUIPackage.get_by_name(package_name)
	if loaded != null:
		return loaded
	return FGUIPackage.add_package("%s/%s" % [UI_ROOT, package_name])


func _show_main_menu() -> void:
	_cleanup_current()
	_current_demo_name = "MainMenu"
	_current_package = _main_package
	var menu := UI_MainMenuMain.create_instance(_main_package)
	_view = menu
	if menu == null:
		push_error("FairyGUI demo MainMenu/Main is missing.")
		return
	_root_ui.add_child(menu)
	menu.make_full_screen()
	_bind_menu_button(menu.n_1, "Basics")
	_bind_menu_button(menu.n_2, "Transition")
	_bind_menu_button(menu.n_4, "VirtualList")
	_bind_menu_button(menu.n_5, "LoopList")
	_bind_menu_button(menu.n_6, "HitTest")
	_bind_menu_button(menu.n_7, "PullToRefresh")
	_bind_menu_button(menu.n_8, "ModalWaiting")
	_bind_menu_button(menu.n_9, "Joystick")
	_bind_menu_button(menu.n_10, "Bag")
	_bind_menu_button(menu.n_11, "Chat")
	_bind_menu_button(menu.n_12, "ListEffect")
	_bind_menu_button(menu.n_13, "ScrollPane")
	_bind_menu_button(menu.n_14, "TreeView")
	_bind_menu_button(menu.n_15, "Guide")
	_bind_menu_button(menu.n_16, "Cooldown")


func _bind_menu_button(button: FGUIObject, demo_name: String) -> void:
	if button != null:
		button.on("click", Callable(self, "_on_menu_button_clicked").bind(demo_name))


func _on_menu_button_clicked(_event: Variant, demo_name: String) -> void:
	_queue_navigation(demo_name)


func _queue_navigation(target: String) -> void:
	_pending_navigation = target
	if _navigation_scheduled:
		return
	_navigation_scheduled = true
	call_deferred("_flush_navigation")


func _flush_navigation() -> void:
	_navigation_scheduled = false
	var target := _pending_navigation
	_pending_navigation = ""
	if target == "" or not is_inside_tree():
		return
	if target == "MainMenu":
		_show_main_menu()
	else:
		_start_demo(target)


func _start_demo(demo_name: String) -> void:
	_cleanup_current()
	_current_demo_name = demo_name
	_current_package = _ensure_package(demo_name)
	if _current_package == null:
		push_error("FairyGUI demo package failed to load: %s" % demo_name)
		_show_main_menu()
		return
	_configure_demo_before_create(demo_name)
	_view = _create_demo_view(demo_name)
	if _view == null:
		push_error("FairyGUI demo component is missing: %s/Main" % demo_name)
		_show_main_menu()
		return
	_root_ui.add_child(_view)
	_view.make_full_screen()
	match demo_name:
		"Basics":
			_setup_basics()
		"Transition":
			_setup_transition()
		"VirtualList":
			_setup_virtual_list()
		"LoopList":
			_setup_loop_list()
		"PullToRefresh":
			_setup_pull_to_refresh()
		"ModalWaiting":
			_setup_modal_waiting()
		"Joystick":
			_setup_joystick()
		"Bag":
			_setup_bag()
		"Chat":
			_setup_chat()
		"ListEffect":
			_setup_list_effect()
		"ScrollPane":
			_setup_scroll_pane()
		"TreeView":
			_setup_tree_view()
		"Guide":
			_setup_guide()
		"Cooldown":
			_setup_cooldown()
	_add_close_button()


func _create_demo_view(demo_name: String) -> FGUIComponent:
	match demo_name:
		"Basics": return UI_BasicsMain.create_instance(_current_package)
		"Transition": return UI_TransitionMain.create_instance(_current_package)
		"VirtualList": return UI_VirtualListMain.create_instance(_current_package)
		"LoopList": return UI_LoopListMain.create_instance(_current_package)
		"HitTest": return UI_HitTestMain.create_instance(_current_package)
		"PullToRefresh": return UI_PullToRefreshMain.create_instance(_current_package)
		"ModalWaiting": return UI_ModalWaitingMain.create_instance(_current_package)
		"Joystick": return UI_JoystickMain.create_instance(_current_package)
		"Bag": return UI_BagMain.create_instance(_current_package)
		"Chat": return UI_ChatMain.create_instance(_current_package)
		"ListEffect": return UI_ListEffectMain.create_instance(_current_package)
		"ScrollPane": return UI_ScrollPaneMain.create_instance(_current_package)
		"TreeView": return UI_TreeViewMain.create_instance(_current_package)
		"Guide": return UI_GuideMain.create_instance(_current_package)
		"Cooldown": return UI_CooldownMain.create_instance(_current_package)
		_: return null


func _configure_demo_before_create(demo_name: String) -> void:
	if demo_name == "Basics":
		FGUIConfig.vertical_scroll_bar = "ui://Basics/ScrollBar_VT"
		FGUIConfig.horizontal_scroll_bar = "ui://Basics/ScrollBar_HZ"
		FGUIConfig.popup_menu = "ui://Basics/PopupMenu"
		FGUIConfig.button_sound = FGUIPackage.get_item_asset_by_url("ui://Basics/click") as AudioStream
	elif demo_name == "ModalWaiting":
		FGUIConfig.global_modal_waiting = "ui://ModalWaiting/GlobalModalWaiting"
		FGUIConfig.window_modal_waiting = "ui://ModalWaiting/WindowModalWaiting"


func _add_close_button() -> void:
	_close_button = UI_MainMenuCloseButton.create_instance(_main_package)
	if _close_button == null:
		return
	_close_button.set_xy(_root_ui.width - _close_button.width - 10.0, _root_ui.height - _close_button.height - 10.0)
	_close_button.add_relation(_root_ui, FGUIEnums.RELATION_RIGHT_RIGHT)
	_close_button.add_relation(_root_ui, FGUIEnums.RELATION_BOTTOM_BOTTOM)
	_close_button.sorting_order = 100000
	_close_button.on("click", Callable(self, "_on_demo_closed"))
	_root_ui.add_child(_close_button)


func _on_demo_closed(_event: Variant = null) -> void:
	_queue_navigation("MainMenu")


func _cleanup_current() -> void:
	_session_id += 1
	_basic_active_type = ""
	_basic_progress_accumulator = 0.0
	_stop_joystick_state()
	for tweener: FGUIGTweener in _tweeners:
		if tweener != null and not tweener.killed:
			tweener.kill()
	_tweeners.clear()
	if FGUIDragDropManager.inst != null:
		FGUIDragDropManager.inst.cancel()
	if _root_ui != null and not _root_ui.is_disposed:
		_root_ui.hide_popup()
		_root_ui.close_modal_wait()
		_root_ui.remove_children(0, -1, true)
	if _basic_popup_menu != null:
		_basic_popup_menu.dispose()
		_basic_popup_menu = null
	for window: FGUIWindow in _windows:
		if window != null and not window.is_disposed:
			window.dispose()
	_windows.clear()
	for object: FGUIObject in _owned_objects:
		if object != null and not object.is_disposed:
			object.dispose()
	_owned_objects.clear()
	FGUIConfig.vertical_scroll_bar = ""
	FGUIConfig.horizontal_scroll_bar = ""
	FGUIConfig.popup_menu = ""
	FGUIConfig.button_sound = null
	FGUIConfig.global_modal_waiting = ""
	FGUIConfig.window_modal_waiting = ""
	if _current_package != null and _current_package != _main_package and FGUIPackage.get_by_name(_current_package.name) == _current_package:
		FGUIPackage.remove_package_instance(_current_package)
	_current_package = null
	_view = null
	_close_button = null
	_basic_container = null
	_basic_controller = null
	_basic_back_button = null
	_basic_demo_objects.clear()
	_basic_popup_component = null
	_basic_window_a = null
	_basic_window_b = null
	_transition_group = null
	_transition_objects.clear()
	_loop_list = null
	_pull_list_1 = null
	_pull_list_2 = null
	_modal_window = null
	_joystick_button = null
	_joystick_touch_area = null
	_joystick_thumb = null
	_joystick_center = null
	_joystick_text = null
	_bag_window = null
	_bag_content = null
	_bag_list = null
	_chat_list = null
	_chat_input = null
	_emoji_select_ui = null
	_messages.clear()
	_scroll_list = null
	_guide_layer = null


func _remember_object(object: FGUIObject) -> FGUIObject:
	if object != null and not _owned_objects.has(object):
		_owned_objects.append(object)
	return object


func _remember_window(window: FGUIWindow) -> FGUIWindow:
	if window != null and not _windows.has(window):
		_windows.append(window)
	return window


func _remember_tweener(tweener: FGUIGTweener) -> FGUIGTweener:
	if tweener != null:
		_tweeners.append(tweener)
	return tweener


# Basics

func _setup_basics() -> void:
	var view := _view as UI_BasicsMain
	if view == null:
		return
	_basic_back_button = view.btn_back
	if _basic_back_button != null:
		_basic_back_button.visible = false
		_basic_back_button.on("click", Callable(self, "_basic_back_clicked"))
	_basic_container = view.container
	_basic_controller = view.c_1
	_bind_basic_button(view.btn_graph, "Graph")
	_bind_basic_button(view.btn_image, "Image")
	_bind_basic_button(view.btn_movie_clip, "MovieClip")
	_bind_basic_button(view.btn_text, "Text")
	_bind_basic_button(view.btn_loader, "Loader")
	_bind_basic_button(view.btn_list, "List")
	_bind_basic_button(view.btn_grid, "Grid")
	_bind_basic_button(view.btn_controller, "Controller")
	_bind_basic_button(view.btn_relation, "Relation")
	_bind_basic_button(view.btn_clip_scroll, "Clip&Scroll")
	_bind_basic_button(view.btn_component, "Component")
	_bind_basic_button(view.btn_label, "Label")
	_bind_basic_button(view.btn_button, "Button")
	_bind_basic_button(view.btn_combo_box, "ComboBox")
	_bind_basic_button(view.btn_slider, "Slider")
	_bind_basic_button(view.btn_progress_bar, "ProgressBar")
	_bind_basic_button(view.btn_popup, "Popup")
	_bind_basic_button(view.btn_window, "Window")
	_bind_basic_button(view.btn_depth, "Depth")
	_bind_basic_button(view.btn_drag_drop, "Drag&Drop")


func _bind_basic_button(button: FGUIObject, demo_type: String) -> void:
	if button != null:
		button.on("click", Callable(self, "_run_basic_demo").bind(demo_type))


func _basic_back_clicked(_event: Variant = null) -> void:
	if _basic_controller != null:
		_basic_controller.selected_index = 0
	if _basic_back_button != null:
		_basic_back_button.visible = false
	_basic_active_type = ""


func _run_basic_demo(_event: Variant, demo_type: String) -> void:
	if _basic_container == null or not BASIC_DEMO_TYPES.has(demo_type):
		return
	var demo := _basic_demo_objects.get(demo_type) as FGUIComponent
	var created := false
	if demo == null or demo.is_disposed:
		demo = _current_package.create_object("Demo_%s" % demo_type) as FGUIComponent
		if demo == null:
			return
		_basic_demo_objects[demo_type] = demo
		_remember_object(demo)
		created = true
	_basic_container.remove_children()
	_basic_container.add_child(demo)
	if _basic_controller != null:
		_basic_controller.selected_index = 1
	if _basic_back_button != null:
		_basic_back_button.visible = true
	_basic_active_type = demo_type
	if not created:
		return
	match demo_type:
		"Button":
			_setup_basic_button(demo)
		"Text":
			_setup_basic_text(demo)
		"Window":
			_setup_basic_window(demo)
		"Popup":
			_setup_basic_popup(demo)
		"Drag&Drop":
			_setup_basic_drag_drop(demo)
		"Depth":
			_setup_basic_depth(demo)
		"Grid":
			_setup_basic_grid(demo)


func _setup_basic_button(demo: FGUIComponent) -> void:
	var typed_demo := demo as UI_BasicsDemoButton
	var button := typed_demo.n_34 if typed_demo != null else null
	if button != null:
		button.on("click", Callable(self, "_basic_button_clicked"))


func _basic_button_clicked(_event: Variant = null) -> void:
	print("FairyGUI Basics: click button")


func _setup_basic_text(demo: FGUIComponent) -> void:
	var typed_demo := demo as UI_BasicsDemoText
	if typed_demo == null:
		return
	var link_text := typed_demo.n_12
	if link_text != null:
		link_text.on(FGUIEvents.CLICK_LINK, Callable(self, "_basic_link_clicked"))
	var copy_button := typed_demo.n_25
	if copy_button != null:
		copy_button.on("click", Callable(self, "_basic_copy_input"))


func _basic_link_clicked(link: Variant) -> void:
	var demo := _basic_demo_objects.get("Text") as UI_BasicsDemoText
	if demo == null:
		return
	demo.n_12.set_text("[color=#FF0000]你点击了链接[/color]：%s" % str(link))


func _basic_copy_input(_event: Variant = null) -> void:
	var demo := _basic_demo_objects.get("Text") as UI_BasicsDemoText
	if demo == null:
		return
	var input := demo.n_22
	var output := demo.n_24
	if input != null and output != null:
		output.set_text(input.get_text())


func _setup_basic_window(demo: FGUIComponent) -> void:
	var typed_demo := demo as UI_BasicsDemoWindow
	if typed_demo == null:
		return
	var button_a := typed_demo.n_0
	var button_b := typed_demo.n_1
	if button_a != null:
		button_a.on("click", Callable(self, "_show_basic_window_a"))
	if button_b != null:
		button_b.on("click", Callable(self, "_show_basic_window_b"))


func _show_basic_window_a(_event: Variant = null) -> void:
	if _basic_window_a == null or _basic_window_a.is_disposed:
		_basic_window_a = _remember_window(FGUIWindow.new())
		_basic_window_a.content_pane = UI_BasicsWindowA.create_instance(_current_package)
		_basic_window_a.center_on(_root_ui)
	var content := _basic_window_a.content_pane as UI_BasicsWindowA
	var list := content.n_6 if content != null else null
	if list != null:
		list.remove_children_to_pool()
		for index in 6:
			var item := list.add_item_from_pool() as FGUIButton
			if item != null:
				item.title = str(index)
				item.icon = FGUIPackage.get_item_url("Basics", "r4")
	_basic_window_a.show_on(_root_ui)


func _show_basic_window_b(_event: Variant = null) -> void:
	if _basic_window_b == null or _basic_window_b.is_disposed:
		_basic_window_b = _remember_window(FGUIWindow.new())
		_basic_window_b.content_pane = UI_BasicsWindowB.create_instance(_current_package)
		_basic_window_b.center_on(_root_ui)
		_basic_window_b.set_pivot(0.5, 0.5)
	_basic_window_b.show_on(_root_ui)
	_basic_window_b.set_scale(0.1, 0.1)
	_remember_tweener(
		FGUIGTween.to2(0.1, 0.1, 1.0, 1.0, 0.3)
			.set_target(_basic_window_b, Callable(_basic_window_b, "set_scale"))
			.set_ease(FGUIEaseType.QUAD_OUT)
	)
	var content := _basic_window_b.content_pane as UI_BasicsWindowB
	var transition := content.t_1 if content != null else null
	if transition != null:
		transition.play()


func _setup_basic_popup(demo: FGUIComponent) -> void:
	var typed_demo := demo as UI_BasicsDemoPopup
	if typed_demo == null:
		return
	_basic_popup_menu = FGUIPopupMenu.new()
	for index in range(1, 5):
		_basic_popup_menu.add_item("Item %d" % index)
	_basic_popup_component = _remember_object(UI_BasicsComponent12.create_instance(_current_package)) as UI_BasicsComponent12
	if _basic_popup_component != null:
		_basic_popup_component.center()
	var button_1 := typed_demo.n_0
	var button_2 := typed_demo.n_1
	if button_1 != null:
		button_1.on("click", Callable(self, "_show_basic_popup_menu").bind(button_1))
	if button_2 != null:
		button_2.on("click", Callable(self, "_show_basic_popup_component"))


func _show_basic_popup_menu(_event: Variant, target: FGUIObject) -> void:
	if _basic_popup_menu != null:
		_basic_popup_menu.show(target, FGUIEnums.POPUP_DOWN)


func _show_basic_popup_component(_event: Variant = null) -> void:
	if _basic_popup_component != null:
		_root_ui.show_popup(_basic_popup_component)


func _setup_basic_drag_drop(demo: FGUIComponent) -> void:
	var typed_demo := demo as UI_BasicsDemoDragDrop
	if typed_demo == null:
		return
	var button_a := typed_demo.a
	if button_a != null:
		button_a.draggable = true
	var button_b := typed_demo.b
	if button_b != null:
		button_b.draggable = true
		button_b.on(FGUIEvents.DRAG_START, Callable(self, "_basic_drag_started").bind(button_b))
	var button_c := typed_demo.c
	if button_c != null:
		button_c.icon = ""
		button_c.on(FGUIEvents.DROP, Callable(self, "_basic_drop_received").bind(button_c))
	var button_d := typed_demo.d
	var bounds := typed_demo.bounds
	if button_d != null and bounds != null:
		button_d.draggable = true
		var rect := bounds.local_to_global_rect(Rect2(0.0, 0.0, bounds.width, bounds.height))
		rect = _root_ui.global_to_local_rect(rect)
		if demo.parent != null:
			rect.position.x -= demo.parent.x
		button_d.drag_bounds = rect


func _basic_drag_started(event: Variant, button: FGUIButton) -> void:
	button.stop_drag()
	var native_event := event as InputEvent
	var pointer_id := FGUIToolSet.get_pointer_id(native_event) if native_event != null else -1
	FGUIDragDropManager.get_inst().start_drag(button, button.icon, button.icon, pointer_id)


func _basic_drop_received(data: Variant, button: FGUIButton) -> void:
	button.icon = str(data)


func _setup_basic_depth(demo: FGUIComponent) -> void:
	var typed_demo := demo as UI_BasicsDemoDepth
	if typed_demo == null:
		return
	var container := typed_demo.n_22 as UI_BasicsComponent13
	if container == null:
		return
	var fixed_object := container.n_0
	if fixed_object == null:
		return
	fixed_object.sorting_order = 100
	fixed_object.draggable = true
	for child: FGUIObject in container.children.duplicate():
		if child != fixed_object:
			container.remove_child(child, true)
	_depth_start_position = Vector2(fixed_object.x, fixed_object.y)
	var normal_button := typed_demo.btn_0
	var sorted_button := typed_demo.btn_1
	if normal_button != null:
		normal_button.on("click", Callable(self, "_add_depth_graph").bind(false))
	if sorted_button != null:
		sorted_button.on("click", Callable(self, "_add_depth_graph").bind(true))


func _add_depth_graph(_event: Variant, high_order: bool) -> void:
	var demo := _basic_demo_objects.get("Depth") as UI_BasicsDemoDepth
	if demo == null:
		return
	var container := demo.n_22 as UI_BasicsComponent13
	if container == null:
		return
	_depth_start_position += Vector2(10.0, 10.0)
	var graph := FGUIGraph.new()
	graph.set_xy(_depth_start_position.x, _depth_start_position.y)
	graph.set_size(150.0, 150.0)
	graph.draw_rect(1.0, Color.BLACK, Color.GREEN if high_order else Color.RED)
	if high_order:
		graph.sorting_order = 200
	container.add_child(graph)


func _setup_basic_grid(demo: FGUIComponent) -> void:
	var typed_demo := demo as UI_BasicsDemoGrid
	if typed_demo == null:
		return
	var names := [
		"苹果手机操作系统", "安卓手机操作系统", "微软手机操作系统",
		"微软桌面操作系统", "苹果桌面操作系统", "未知操作系统",
	]
	var colors := [Color.YELLOW, Color.RED, Color.WHITE, Color.BLUE]
	var list_1 := typed_demo.list_1
	if list_1 != null:
		list_1.remove_children_to_pool()
		for index in names.size():
			var item := list_1.add_item_from_pool() as UI_BasicsGridItem
			if item == null:
				continue
			item.t_0.set_text(str(index + 1))
			item.t_1.set_text(names[index])
			var color_text := item.t_2
			if color_text != null:
				color_text.color = colors[_rng.randi_range(0, colors.size() - 1)]
			var stars := item.star
			if stars != null:
				stars.value = float(_rng.randi_range(1, 3)) / 3.0 * 100.0
	var list_2 := typed_demo.list_2
	if list_2 != null:
		list_2.remove_children_to_pool()
		for index in names.size():
			var item := list_2.add_item_from_pool() as UI_BasicsGridItem2
			if item == null:
				continue
			var checkbox := item.cb
			if checkbox != null:
				checkbox.selected = false
			item.t_1.set_text(names[index])
			var movie_clip := item.mc
			if movie_clip != null:
				movie_clip.playing = index % 2 == 0
			item.t_3.set_text(str(_rng.randi_range(0, 9999)))


# Transition

func _setup_transition() -> void:
	var view := _view as UI_TransitionMain
	if view == null:
		return
	_transition_group = view.g_0
	_transition_objects["BOSS"] = _remember_object(UI_TransitionBoss.create_instance(_current_package))
	_transition_objects["BOSS_SKILL"] = _remember_object(UI_TransitionBossSkill.create_instance(_current_package))
	_transition_objects["TRAP"] = _remember_object(UI_TransitionTrap.create_instance(_current_package))
	_transition_objects["GoodHit"] = _remember_object(UI_TransitionGoodHit.create_instance(_current_package))
	_transition_objects["PowerUp"] = _remember_object(UI_TransitionPowerUp.create_instance(_current_package))
	_transition_objects["PathDemo"] = _remember_object(UI_TransitionPathDemo.create_instance(_current_package))
	var power_up := _transition_objects.get("PowerUp") as UI_TransitionPowerUp
	if power_up != null:
		var transition := power_up.t_0
		if transition != null:
			transition.set_hook("play_num_now", Callable(self, "_transition_play_number"))
	var buttons: Array[FGUIObject] = [view.btn_0, view.btn_1, view.btn_2, view.btn_3, view.btn_4, view.btn_5]
	for index in buttons.size():
		buttons[index].on("click", Callable(self, "_transition_button_clicked").bind(index))


func _transition_button_clicked(_event: Variant, index: int) -> void:
	match index:
		0:
			_play_transition_component(_transition_objects.get("BOSS") as FGUIComponent)
		1:
			_play_transition_component(_transition_objects.get("BOSS_SKILL") as FGUIComponent)
		2:
			_play_transition_component(_transition_objects.get("TRAP") as FGUIComponent)
		3:
			var good_hit := _transition_objects.get("GoodHit") as FGUIComponent
			if good_hit != null:
				good_hit.set_xy(_root_ui.width - good_hit.width - 20.0, 100.0)
			_play_transition_component(good_hit, 3)
		4:
			_play_power_up()
		5:
			_play_transition_component(_transition_objects.get("PathDemo") as FGUIComponent)


func _play_transition_component(target: FGUIComponent, times: int = 1) -> void:
	if target == null or target.is_disposed:
		return
	if _transition_group != null:
		_transition_group.visible = false
	_root_ui.add_child(target)
	var transition := target.get_transition("t0")
	if transition == null:
		_transition_finished(target, _session_id)
		return
	transition.play(Callable(self, "_transition_finished").bind(target, _session_id), times)


func _play_power_up() -> void:
	var power_up := _transition_objects.get("PowerUp") as UI_TransitionPowerUp
	if power_up == null:
		return
	power_up.set_xy(20.0, _root_ui.height - power_up.height - 100.0)
	_transition_start_value = 10000.0
	var added := _rng.randi_range(1001, 3000)
	_transition_end_value = _transition_start_value + added
	power_up.value.set_text(str(int(_transition_start_value)))
	power_up.add_value.set_text("+%d" % added)
	_play_transition_component(power_up)


func _transition_play_number() -> void:
	_remember_tweener(
		FGUIGTween.to(_transition_start_value, _transition_end_value, 0.3)
			.set_ease(FGUIEaseType.LINEAR)
			.set_update_handler(Callable(self, "_transition_number_updated"))
	)


func _transition_number_updated(tweener: FGUIGTweener) -> void:
	var power_up := _transition_objects.get("PowerUp") as UI_TransitionPowerUp
	if power_up != null and not power_up.is_disposed:
		power_up.value.set_text(str(int(floorf(tweener.value.x))))


func _transition_finished(target: FGUIComponent, session: int) -> void:
	if session != _session_id:
		return
	if _transition_group != null:
		_transition_group.visible = true
	if target != null and target.parent == _root_ui:
		_root_ui.remove_child(target)


# Lists

func _setup_virtual_list() -> void:
	var view := _view as UI_VirtualListMain
	if view == null:
		return
	var list := view.mail_list
	if list == null:
		return
	list.set_virtual()
	list.item_renderer = Callable(self, "_render_virtual_mail")
	list.num_items = 1000
	var select_button := view.n_6
	var top_button := view.n_7
	var bottom_button := view.n_8
	if select_button != null:
		select_button.on("click", func(_event: Variant) -> void: list.add_selection(500, true))
	if top_button != null:
		top_button.on("click", func(_event: Variant) -> void: list.scroll_pane.scroll_top())
	if bottom_button != null:
		bottom_button.on("click", func(_event: Variant) -> void: list.scroll_pane.scroll_bottom())


func _render_virtual_mail(index: int, object: FGUIObject) -> void:
	_configure_mail_item(object, index, true)


func _configure_mail_item(object: FGUIObject, index: int, include_index: bool) -> void:
	var item := object as FGUIButton
	if item == null:
		return
	item.title = "%sMail title here" % ("%d " % index if include_index else "")
	var time_text: FGUITextField
	var read_controller: FGUIController
	var fetched_controller: FGUIController
	if object is UI_VirtualListMailItem:
		var virtual_item := object as UI_VirtualListMailItem
		time_text = virtual_item.time_text
		read_controller = virtual_item.is_read
		fetched_controller = virtual_item.c_1
	elif object is UI_ListEffectMailItem:
		var effect_item := object as UI_ListEffectMailItem
		time_text = effect_item.time_text
		read_controller = effect_item.is_read
		fetched_controller = effect_item.c_1
	if time_text != null:
		time_text.set_text("5 Nov 2015 16:24:33")
	if read_controller != null:
		read_controller.selected_index = 1 if index % 2 == 0 else 0
	if fetched_controller != null:
		fetched_controller.selected_index = 1 if index % 3 == 0 else 0


func _setup_loop_list() -> void:
	var view := _view as UI_LoopListMain
	if view == null:
		return
	_loop_list = view.list
	if _loop_list == null:
		return
	_loop_list.set_virtual_and_loop()
	_loop_list.item_renderer = Callable(self, "_render_loop_item")
	_loop_list.num_items = 5
	_loop_list.on(FGUIEvents.SCROLL, Callable(self, "_update_loop_list_effect"))
	_update_loop_list_effect()


func _render_loop_item(index: int, object: FGUIObject) -> void:
	var item := object as UI_LoopListItem
	if item == null:
		return
	item.set_pivot(0.5, 0.5)
	item.icon = FGUIPackage.get_item_url("LoopList", "n%d" % (index + 1))


func _update_loop_list_effect(_event: Variant = null) -> void:
	if _loop_list == null or _loop_list.scroll_pane == null:
		return
	var middle_x := _loop_list.scroll_pane.pos_x + _loop_list.view_width * 0.5
	for child: FGUIObject in _loop_list.children:
		var distance := absf(middle_x - child.x - child.width * 0.5)
		var scale := 1.0 if distance > child.width else 1.0 + (1.0 - distance / child.width) * 0.24
		child.set_scale(scale, scale)
	var view := _view as UI_LoopListMain
	var label := view.n_3 if view != null else null
	if label != null and _loop_list.num_items > 0:
		label.set_text(str((_loop_list.get_first_child_in_view() + 1) % _loop_list.num_items))


func _setup_pull_to_refresh() -> void:
	var view := _view as UI_PullToRefreshMain
	if view == null:
		return
	_pull_list_1 = view.list_1
	_pull_list_2 = view.list_2
	if _pull_list_1 != null:
		_pull_list_1.item_renderer = Callable(self, "_render_pull_down_item")
		_pull_list_1.set_virtual()
		_pull_list_1.num_items = 1
		_pull_list_1.on(FGUIEvents.PULL_DOWN_RELEASE, Callable(self, "_pull_down_released"))
		var header := _pull_list_1.scroll_pane.header as UI_PullToRefreshHeader
		if header != null:
			header.on(FGUIEvents.SIZE_CHANGED, Callable(self, "_pull_header_size_changed").bind(header))
			_pull_header_size_changed(null, header)
	if _pull_list_2 != null:
		_pull_list_2.item_renderer = Callable(self, "_render_pull_up_item")
		_pull_list_2.set_virtual()
		_pull_list_2.num_items = 1
		_pull_list_2.on(FGUIEvents.PULL_UP_RELEASE, Callable(self, "_pull_up_released"))


func _render_pull_down_item(index: int, item: FGUIObject) -> void:
	item.set_text("Item %d" % (_pull_list_1.num_items - index - 1))


func _render_pull_up_item(index: int, item: FGUIObject) -> void:
	item.set_text("Item %d" % index)


func _pull_header_size_changed(_event: Variant, header: UI_PullToRefreshHeader) -> void:
	var controller := header.c_1
	if controller == null or controller.selected_index in [2, 3]:
		return
	controller.selected_index = 1 if header.height > header.source_height else 0


func _pull_down_released(_event: Variant = null) -> void:
	if _pull_list_1 == null or _pull_list_1.scroll_pane.header == null:
		return
	var header := _pull_list_1.scroll_pane.header as UI_PullToRefreshHeader
	if header == null:
		return
	var controller := header.c_1
	if controller == null or controller.selected_index != 1:
		return
	controller.selected_index = 2
	_pull_list_1.scroll_pane.lock_header(header.source_height)
	_finish_pull_down(_session_id, header)


func _finish_pull_down(session: int, header: UI_PullToRefreshHeader) -> void:
	await get_tree().create_timer(2.0).timeout
	if session != _session_id or _pull_list_1 == null or header == null or header.is_disposed:
		return
	_pull_list_1.num_items += 5
	header.c_1.selected_index = 3
	_pull_list_1.scroll_pane.lock_header(35.0)
	await get_tree().create_timer(2.0).timeout
	if session != _session_id or _pull_list_1 == null or header == null or header.is_disposed:
		return
	header.c_1.selected_index = 0
	_pull_list_1.scroll_pane.lock_header(0.0)


func _pull_up_released(_event: Variant = null) -> void:
	if _pull_list_2 == null or _pull_list_2.scroll_pane.footer == null:
		return
	var footer := _pull_list_2.scroll_pane.footer as UI_PullToRefreshFooter
	if footer == null:
		return
	var controller := footer.c_1
	if controller != null:
		controller.selected_index = 1
	_pull_list_2.scroll_pane.lock_footer(footer.source_height)
	_finish_pull_up(_session_id, footer)


func _finish_pull_up(session: int, footer: UI_PullToRefreshFooter) -> void:
	await get_tree().create_timer(2.0).timeout
	if session != _session_id or _pull_list_2 == null or footer == null or footer.is_disposed:
		return
	_pull_list_2.num_items += 5
	var controller := footer.c_1
	if controller != null:
		controller.selected_index = 0
	_pull_list_2.scroll_pane.lock_footer(0.0)


# Waiting, joystick, bag and chat

func _setup_modal_waiting() -> void:
	var view := _view as UI_ModalWaitingMain
	var button := view.n_0 if view != null else null
	if button != null:
		button.on("click", Callable(self, "_show_modal_test_window"))
	_root_ui.show_modal_wait()
	_finish_global_modal_wait(_session_id)


func _finish_global_modal_wait(session: int) -> void:
	await get_tree().create_timer(3.0).timeout
	if session == _session_id and _root_ui != null:
		_root_ui.close_modal_wait()


func _show_modal_test_window(_event: Variant = null) -> void:
	if _modal_window == null or _modal_window.is_disposed:
		_modal_window = _remember_window(FGUIWindow.new())
		_modal_window.content_pane = UI_ModalWaitingTestWin.create_instance(_current_package)
		_modal_window.center_on(_root_ui)
		var content := _modal_window.content_pane as UI_ModalWaitingTestWin
		var start_button := content.n_1 if content != null else null
		if start_button != null:
			start_button.on("click", Callable(self, "_start_window_modal_wait"))
	_modal_window.show_on(_root_ui)


func _start_window_modal_wait(_event: Variant = null) -> void:
	if _modal_window == null:
		return
	_modal_window.show_modal_wait()
	_finish_window_modal_wait(_session_id, _modal_window)


func _finish_window_modal_wait(session: int, window: FGUIWindow) -> void:
	await get_tree().create_timer(3.0).timeout
	if session == _session_id and window != null and not window.is_disposed:
		window.close_modal_wait()


func _setup_joystick() -> void:
	var view := _view as UI_JoystickMain
	if view == null:
		return
	_joystick_button = view.joystick
	_joystick_touch_area = view.joystick_touch
	_joystick_center = view.joystick_center
	_joystick_text = view.n_9
	if _joystick_button == null or _joystick_touch_area == null or _joystick_center == null:
		return
	_joystick_button.change_state_on_click = false
	var joystick := _joystick_button as UI_JoystickCircle
	_joystick_thumb = joystick.thumb if joystick != null else null
	_joystick_initial_center = Vector2(
		_joystick_center.x + _joystick_center.width * 0.5,
		_joystick_center.y + _joystick_center.height * 0.5
	)
	_joystick_touch_area.on(FGUIEvents.TOUCH_BEGIN, Callable(self, "_joystick_pressed"))


func _joystick_pressed(event: Variant) -> void:
	if _joystick_pointer_id != INACTIVE_POINTER or not (event is InputEvent):
		return
	var native_event := event as InputEvent
	_joystick_pointer_id = FGUIToolSet.get_pointer_id(native_event)
	var global_position := FGUIToolSet.get_pointer_position(native_event)
	var root_position := _root_ui.global_to_local(global_position)
	var touch_rect := _root_ui.global_to_local_rect(
		_joystick_touch_area.local_to_global_rect(Rect2(0.0, 0.0, _joystick_touch_area.width, _joystick_touch_area.height))
	)
	root_position.x = clampf(root_position.x, touch_rect.position.x, touch_rect.end.x)
	root_position.y = clampf(root_position.y, touch_rect.position.y, touch_rect.end.y)
	_joystick_start = root_position
	_joystick_button.selected = true
	_joystick_center.visible = true
	_joystick_center.set_xy(root_position.x - _joystick_center.width * 0.5, root_position.y - _joystick_center.height * 0.5)
	_joystick_button.set_xy(root_position.x - _joystick_button.width * 0.5, root_position.y - _joystick_button.height * 0.5)
	_update_joystick(global_position)


func _update_joystick(global_position: Vector2) -> void:
	if _joystick_button == null:
		return
	var root_position := _root_ui.global_to_local(global_position)
	var offset := root_position - _joystick_start
	if offset.length() > _joystick_radius:
		offset = offset.normalized() * _joystick_radius
	var angle := rad_to_deg(atan2(offset.y, offset.x)) if not offset.is_zero_approx() else 0.0
	if _joystick_thumb != null:
		_joystick_thumb.rotation = angle + 90.0
	var center := _joystick_start + offset
	_joystick_button.set_xy(center.x - _joystick_button.width * 0.5, center.y - _joystick_button.height * 0.5)
	if _joystick_text != null:
		_joystick_text.set_text(str(int(roundf(angle))))


func _release_joystick() -> void:
	if _joystick_pointer_id == INACTIVE_POINTER:
		return
	_joystick_pointer_id = INACTIVE_POINTER
	if _joystick_text != null:
		_joystick_text.set_text("")
	if _joystick_center != null:
		_joystick_center.visible = false
	if _joystick_thumb != null:
		_joystick_thumb.rotation += 180.0
	if _joystick_button == null:
		return
	_remember_tweener(
		FGUIGTween.to2(
			_joystick_button.x,
			_joystick_button.y,
			_joystick_initial_center.x - _joystick_button.width * 0.5,
			_joystick_initial_center.y - _joystick_button.height * 0.5,
			0.3
		)
			.set_target(_joystick_button, Callable(_joystick_button, "set_xy"))
			.set_ease(FGUIEaseType.CIRC_OUT)
			.set_complete_handler(Callable(self, "_joystick_returned"))
	)


func _joystick_returned(_tweener: FGUIGTweener) -> void:
	if _joystick_button == null or _joystick_button.is_disposed:
		return
	_joystick_button.selected = false
	if _joystick_thumb != null:
		_joystick_thumb.rotation = 0.0
	if _joystick_center != null:
		_joystick_center.visible = true
		_joystick_center.set_xy(
			_joystick_initial_center.x - _joystick_center.width * 0.5,
			_joystick_initial_center.y - _joystick_center.height * 0.5
		)


func _stop_joystick_state() -> void:
	_joystick_pointer_id = INACTIVE_POINTER


func _setup_bag() -> void:
	var view := _view as UI_BagMain
	var button := view.bag_btn if view != null else null
	if button != null:
		button.on("click", Callable(self, "_show_bag_window"))


func _show_bag_window(_event: Variant = null) -> void:
	if _bag_window == null or _bag_window.is_disposed:
		_bag_window = _remember_window(FGUIWindow.new())
		_bag_content = UI_BagBagWin.create_instance(_current_package)
		_bag_window.content_pane = _bag_content
		_bag_window.center_on(_root_ui)
		_bag_list = _bag_content.list if _bag_content != null else null
		if _bag_list != null:
			_bag_list.set_virtual()
			_bag_list.item_renderer = Callable(self, "_render_bag_item")
			_bag_list.on(FGUIEvents.CLICK_ITEM, Callable(self, "_bag_item_clicked"))
	if _bag_list != null:
		_bag_list.num_items = 45
	_bag_window.show_on(_root_ui)


func _render_bag_item(_index: int, object: FGUIObject) -> void:
	object.set_icon("%s/i%d.png" % [ICON_ROOT, _rng.randi_range(0, 9)])
	object.set_text(str(_rng.randi_range(0, 99)))


func _bag_item_clicked(item: Variant) -> void:
	if not (item is FGUIObject) or _bag_window == null:
		return
	var object := item as FGUIObject
	var loader := _bag_content.n_11 if _bag_content != null else null
	var label := _bag_content.n_13 if _bag_content != null else null
	if loader != null:
		loader.set_icon(object.get_icon())
	if label != null:
		label.set_text(object.get_icon())


func _setup_chat() -> void:
	var view := _view as UI_ChatMain
	if view == null:
		return
	_chat_list = view.list
	_chat_input = view.input_1
	if _chat_list != null:
		_chat_list.set_virtual()
		_chat_list.item_provider = Callable(self, "_chat_item_provider")
		_chat_list.item_renderer = Callable(self, "_render_chat_item")
	if _chat_input != null:
		_chat_input.on(FGUIEvents.SUBMIT, Callable(self, "_chat_send"))
	var send_button := view.btn_send_1
	var emoji_button := view.btn_emoji_1
	if send_button != null:
		send_button.on("click", Callable(self, "_chat_send"))
	if emoji_button != null:
		emoji_button.on("click", Callable(self, "_show_emoji_popup").bind(emoji_button))
	_emoji_select_ui = _remember_object(UI_ChatEmojiSelectUi.create_instance(_current_package)) as UI_ChatEmojiSelectUi
	if _emoji_select_ui != null:
		var emoji_list := _emoji_select_ui.list
		if emoji_list != null:
			emoji_list.on(FGUIEvents.CLICK_ITEM, Callable(self, "_emoji_clicked"))


func _chat_send(_event: Variant = null) -> void:
	if _chat_input == null:
		return
	var message := _chat_input.get_text()
	if message.is_empty():
		return
	_add_chat_message("Creator", "r0", message, true)
	_chat_input.set_text("")


func _add_chat_message(sender: String, sender_icon: String, message: String, from_me: bool) -> void:
	if _chat_list == null:
		return
	var was_at_bottom := _chat_list.scroll_pane.is_bottom_most()
	_messages.append({"sender": sender, "icon": sender_icon, "message": message, "from_me": from_me})
	if from_me and (_messages.size() == 1 or _rng.randf() < 0.5):
		_messages.append({
			"sender": "FairyGUI",
			"icon": "r1",
			"message": "Today is a good day. ",
			"from_me": false,
		})
	if _messages.size() > 100:
		_messages = _messages.slice(_messages.size() - 100)
	_chat_list.num_items = _messages.size()
	if was_at_bottom:
		_chat_list.scroll_pane.scroll_bottom()


func _chat_item_provider(index: int) -> String:
	return "ui://Chat/chatRight" if bool(_messages[index]["from_me"]) else "ui://Chat/chatLeft"


func _render_chat_item(index: int, object: FGUIObject) -> void:
	if index < 0 or index >= _messages.size():
		return
	var message: Dictionary = _messages[index]
	var item := object as FGUIButton
	if item == null:
		return
	var text: FGUIRichTextField
	if object is UI_ChatChatLeft:
		var left_item := object as UI_ChatChatLeft
		left_item.ui_name.set_text(str(message["sender"]))
		text = left_item.msg
	elif object is UI_ChatChatRight:
		text = (object as UI_ChatChatRight).msg
	item.icon = FGUIPackage.get_item_url("Chat", str(message["icon"]))
	if text != null:
		text.set_text(_parse_emoji(str(message["message"])))
		text.ensure_size_correct()


func _parse_emoji(message: String) -> String:
	var result := message
	for index in EMOJI_TAGS.size():
		var token := "[:%s]" % EMOJI_TAGS[index]
		if result.contains(token):
			result = result.replace(token, "[img]%s[/img]" % FGUIPackage.get_item_url("Chat", "1f6%02d" % index))
	return result


func _show_emoji_popup(_event: Variant, target: FGUIObject) -> void:
	if _emoji_select_ui != null:
		_root_ui.show_popup(_emoji_select_ui, target, FGUIEnums.POPUP_UP)


func _emoji_clicked(item: Variant) -> void:
	if _chat_input != null and item is FGUIObject:
		_chat_input.set_text(_chat_input.get_text() + "[:%s]" % (item as FGUIObject).get_text())


# Effects, scroll panes, trees, guide and cooldown

func _setup_list_effect() -> void:
	var view := _view as UI_ListEffectMain
	var list := view.mail_list if view != null else null
	if list == null:
		return
	list.remove_children_to_pool()
	for index in 10:
		var item := list.add_item_from_pool()
		_configure_mail_item(item, index, false)
	list.ensure_bounds_correct()
	var delay := 0.0
	for item: FGUIObject in list.children:
		if not list.is_child_in_view(item):
			break
		item.visible = false
		var component := item as UI_ListEffectMailItem
		var transition := component.t_0 if component != null else null
		if transition != null:
			transition.play(Callable(), 1, delay)
		delay += 0.2


func _setup_scroll_pane() -> void:
	var view := _view as UI_ScrollPaneMain
	if view == null:
		return
	_scroll_list = view.list
	if _scroll_list == null:
		return
	_scroll_list.item_renderer = Callable(self, "_render_scroll_item")
	_scroll_list.set_virtual()
	_scroll_list.num_items = 1000
	_scroll_list.on(FGUIEvents.TOUCH_BEGIN, Callable(self, "_scroll_list_pressed"))


func _render_scroll_item(index: int, object: FGUIObject) -> void:
	var item := object as UI_ScrollPaneItem
	if item == null:
		return
	item.title = "Item %d" % index
	if item.scroll_pane != null:
		item.scroll_pane.pos_x = 0.0
	_connect_scroll_action(item.b_0, "Stick")
	_connect_scroll_action(item.b_1, "Delete")


func _connect_scroll_action(button: FGUIObject, action: String) -> void:
	if button == null or button.node == null or button.node.has_meta(ACTION_CONNECTED_META):
		return
	button.node.set_meta(ACTION_CONNECTED_META, true)
	button.on("click", Callable(self, "_scroll_action_clicked").bind(button, action))


func _scroll_action_clicked(_event: Variant, button: FGUIObject, action: String) -> void:
	var view := _view as UI_ScrollPaneMain
	var output := view.txt if view != null else null
	if output != null and button.parent != null:
		output.set_text("%s %s" % [action, button.parent.get_text()])


func _scroll_list_pressed(event: Variant) -> void:
	if _scroll_list == null or not (event is InputEvent):
		return
	var hit := _scroll_list.hit_test(FGUIToolSet.get_pointer_position(event as InputEvent))
	for child: FGUIObject in _scroll_list.children:
		var item := child as UI_ScrollPaneItem
		if item == null or item.scroll_pane == null or is_zero_approx(item.scroll_pane.pos_x):
			continue
		var stick := item.b_0
		var delete := item.b_1
		if (stick != null and stick.is_ancestor_of(hit)) or (delete != null and delete.is_ancestor_of(hit)):
			return
		item.scroll_pane.set_pos_x(0.0, true)
		item.scroll_pane.cancel_dragging()
		_scroll_list.scroll_pane.cancel_dragging()
		break


func _setup_tree_view() -> void:
	var view := _view as UI_TreeViewMain
	if view == null:
		return
	var tree_1 := view.tree
	var tree_2 := view.tree_2
	if tree_1 != null:
		tree_1.on(FGUIEvents.CLICK_ITEM, Callable(self, "_tree_item_clicked"))
	if tree_2 == null:
		return
	tree_2.on(FGUIEvents.CLICK_ITEM, Callable(self, "_tree_item_clicked"))
	tree_2.tree_node_render = Callable(self, "_render_tree_node")
	var top := FGUITreeNode.new(true, "I'm a top node")
	tree_2.root_node.add_child(top)
	for index in 5:
		top.add_child(FGUITreeNode.new(false, "Hello %d" % index))
	var folder := FGUITreeNode.new(true, "A folder node")
	top.add_child(folder)
	for index in 5:
		folder.add_child(FGUITreeNode.new(false, "Good %d" % index))
	for index in 3:
		top.add_child(FGUITreeNode.new(false, "World %d" % index))
	tree_2.root_node.add_child(FGUITreeNode.new(false, ["I'm a top node too", "ui://TreeView/heart"]))


func _render_tree_node(node: FGUITreeNode, object: FGUIObject) -> void:
	if node.is_folder:
		object.set_text(str(node.data))
	elif node.data is Array:
		var values := node.data as Array
		object.set_text(str(values[0]))
		object.set_icon(str(values[1]))
	else:
		object.set_text(str(node.data))
		object.set_icon(FGUIPackage.get_item_url("TreeView", "file"))


func _tree_item_clicked(item: Variant) -> void:
	if item is FGUIObject and (item as FGUIObject).tree_node != null:
		print("FairyGUI TreeView: ", (item as FGUIObject).tree_node.text)


func _setup_guide() -> void:
	var view := _view as UI_GuideMain
	if view == null:
		return
	_guide_layer = _remember_object(UI_GuideGuideLayer.create_instance(_current_package)) as UI_GuideGuideLayer
	if _guide_layer == null:
		return
	_guide_layer.make_full_screen()
	_guide_layer.add_relation(_root_ui, FGUIEnums.RELATION_SIZE)
	var bag_button := view.bag_btn
	var show_button := view.n_2
	if bag_button != null:
		bag_button.on("click", Callable(self, "_hide_guide"))
	if show_button != null:
		show_button.on("click", Callable(self, "_show_guide").bind(bag_button))


func _hide_guide(_event: Variant = null) -> void:
	if _guide_layer != null:
		_guide_layer.remove_from_parent()


func _show_guide(_event: Variant, bag_button: FGUIObject) -> void:
	if _guide_layer == null or bag_button == null:
		return
	_root_ui.add_child(_guide_layer)
	var rect := bag_button.local_to_global_rect(Rect2(0.0, 0.0, bag_button.width, bag_button.height))
	rect = _guide_layer.global_to_local_rect(rect)
	var window := _guide_layer.window
	if window == null:
		return
	window.set_size(rect.size.x, rect.size.y)
	_remember_tweener(
		FGUIGTween.to2(window.x, window.y, rect.position.x, rect.position.y, 0.5)
			.set_target(window, Callable(window, "set_xy"))
	)


func _setup_cooldown() -> void:
	var view := _view as UI_CooldownMain
	if view == null:
		return
	var first := view.b_0 as UI_CooldownButton1
	var second := view.b_1 as UI_CooldownButton2
	if first != null:
		var first_icon := first.icon
		if first_icon != null:
			first_icon.set_icon("%s/k0.png" % ICON_ROOT)
		_remember_tweener(FGUIGTween.to(0.0, 100.0, 5.0).set_target(first, Callable(first, "update")).set_repeat(-1))
	if second != null:
		var second_icon := second.icon
		if second_icon != null:
			second_icon.set_icon("%s/k1.png" % ICON_ROOT)
		_remember_tweener(FGUIGTween.to(10.0, 0.0, 10.0).set_target(second, Callable(second, "update")).set_repeat(-1))
