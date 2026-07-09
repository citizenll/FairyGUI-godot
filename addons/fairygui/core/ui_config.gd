class_name FGUIConfig
extends RefCounted

static var default_font: String = ""
static var window_modal_waiting: String = ""
static var global_modal_waiting: String = ""
static var modal_layer_color: Color = Color(0.129, 0.129, 0.129, 0.2)
static var button_sound: AudioStream
static var button_sound_volume_scale: float = 1.0
static var horizontal_scroll_bar: String = ""
static var vertical_scroll_bar: String = ""
static var default_scroll_step: float = 25.0
static var default_scroll_deceleration_rate: float = 0.967
static var default_scroll_bar_display: int = FGUIEnums.SCROLLBAR_VISIBLE
static var default_scroll_touch_effect: bool = true
static var default_scroll_bounce_effect: bool = true
static var default_scroll_snapping_threshold: float = 0.1
static var default_scroll_paging_threshold: float = 0.3
static var popup_menu: String = ""
static var popup_menu_separator: String = ""
static var loader_error_sign: String = ""
static var tooltips_win: String = ""
static var default_combo_box_visible_item_count: int = 10
static var touch_scroll_sensitivity: float = 20.0
static var touch_drag_sensitivity: float = 10.0
static var click_drag_sensitivity: float = 2.0
static var bring_window_to_front_on_click: bool = true
static var frame_time_for_async_ui_construction: float = 2.0
static var texture_linear_sampling: bool = true
static var package_file_extension: String = "fui"

