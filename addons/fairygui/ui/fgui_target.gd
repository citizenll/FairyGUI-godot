@tool
class_name FGUITarget
extends Control

const ObjectReference := preload("res://addons/fairygui/ui/object_reference.gd")

signal target_resolved(value: FGUIObject)
signal target_cleared()

enum AttachmentMode {
	FUI_HIERARCHY,
	OVERLAY,
}

var _target_ref: Resource
var _material_override: Material
var _attachment_mode: int = AttachmentMode.FUI_HIERARCHY
var _attachment_behind_target: bool = false
var _enabled: bool = true
var _sync_transform: bool = true
var _sync_size: bool = true
var _sync_visibility: bool = true
var _hide_when_missing: bool = true
var _clip_attachments: bool = false
var _view: FGUIView
var _resolved_object: FGUIObject
var _material_target: CanvasItem
var _previous_material: Material
var _applied_material: Material
var _render_parent_overridden: bool = false
var _render_parent_target: CanvasItem

@export_category("FairyGUI Target")
@export var target_ref: Resource:
	get:
		return _target_ref
	set(value):
		if value != null and value.get_script() != ObjectReference:
			push_warning("FGUITarget target_ref must be an FGUIObjectRef.")
			return
		if _target_ref == value:
			return
		_disconnect_target_ref()
		_target_ref = value
		_connect_target_ref()
		_resolve_target()
		notify_property_list_changed()

@export var material_override: Material:
	get:
		return _material_override
	set(value):
		if _material_override == value:
			return
		_release_material()
		_material_override = value
		_apply_material()

@export_category("Attachment Hierarchy")
@export_enum("Preserve FUI Hierarchy", "Overlay") var attachment_mode: int = AttachmentMode.FUI_HIERARCHY:
	get:
		return _attachment_mode
	set(value):
		var next_mode := clampi(value, AttachmentMode.FUI_HIERARCHY, AttachmentMode.OVERLAY)
		if _attachment_mode == next_mode:
			return
		_restore_scene_render_parent()
		_attachment_mode = next_mode
		_update_attachment_mode()

@export var attachment_behind_target: bool = false:
	get:
		return _attachment_behind_target
	set(value):
		_attachment_behind_target = value
		_update_attachment_mode()

@export_category("Attachment Sync")
@export var enabled: bool = true:
	set(value):
		if _enabled == value:
			enabled = value
			return
		enabled = value
		_enabled = value
		if _enabled:
			_apply_material()
		else:
			_release_material()
		_sync_proxy()

@export var sync_transform: bool = true:
	set(value):
		sync_transform = value
		_sync_transform = value
		_sync_proxy()

@export var sync_size: bool = true:
	set(value):
		sync_size = value
		_sync_size = value
		_sync_proxy()

@export var sync_visibility: bool = true:
	set(value):
		sync_visibility = value
		_sync_visibility = value
		_sync_proxy()

@export var hide_when_missing: bool = true:
	set(value):
		hide_when_missing = value
		_hide_when_missing = value
		_sync_proxy()

@export var clip_attachments: bool = false:
	set(value):
		clip_attachments = value
		_clip_attachments = value
		clip_contents = value


func _init() -> void:
	set_meta("fgui_target_proxy", true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	set_process(true)
	_update_attachment_mode()


func _ready() -> void:
	_enabled = enabled
	_sync_transform = sync_transform
	_sync_size = sync_size
	_sync_visibility = sync_visibility
	_hide_when_missing = hide_when_missing
	_clip_attachments = clip_attachments
	clip_contents = _clip_attachments
	_connect_target_ref()
	_refresh_view_binding()
	_sync_render_hierarchy()


func _exit_tree() -> void:
	_release_target()
	_bind_view(null)
	_disconnect_target_ref()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED or what == NOTIFICATION_UNPARENTED:
		call_deferred("_refresh_view_binding")


func _process(_delta: float) -> void:
	var current_view := _find_view()
	if current_view != _view:
		_bind_view(current_view)
	if _resolved_object == null or _resolved_object.is_disposed:
		if _view != null and _view.fairy != null:
			_resolve_target()
		else:
			_sync_proxy()
		return
	_sync_proxy()
	_refresh_material_target()


func get_view() -> FGUIView:
	return _view


func set_target_reference(value: Resource) -> void:
	target_ref = value


func get_target_reference() -> Resource:
	return _target_ref


func get_resolved_object() -> FGUIObject:
	return _resolved_object


func is_preserving_fui_hierarchy() -> bool:
	return _attachment_mode == AttachmentMode.FUI_HIERARCHY


func is_hierarchy_rendering_active() -> bool:
	return _render_parent_overridden and is_instance_valid(_render_parent_target)


func get_target_label() -> String:
	return _target_ref.get_display_path() if _target_ref != null else "未绑定"


func get_status_text() -> String:
	if _target_ref == null:
		return "尚未选择 FairyGUI 目标"
	if _view == null:
		return "FGUITarget 必须位于 FGUIView 下"
	if _view.fairy == null:
		return "等待 FairyGUI 预览创建"
	if _resolved_object == null or _resolved_object.is_disposed:
		return "当前 FUI 中找不到目标"
	return "已连接 · %s" % _resolved_object.get_script().get_global_name()


func refresh_target() -> void:
	_refresh_view_binding()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if _find_view() == null:
		warnings.append("FGUITarget 必须放在 FGUIView 的子层级中。")
	if _target_ref == null:
		warnings.append("请从 GUI 预览中选择对象并点击“暴露节点”。")
	elif is_inside_tree() and _view != null and _view.fairy != null \
			and (_resolved_object == null or _resolved_object.is_disposed):
		warnings.append("当前 FUI 组件中无法解析目标：%s" % _target_ref.get_display_path())
	return warnings


func _refresh_view_binding() -> void:
	_bind_view(_find_view())


func _find_view() -> FGUIView:
	var current := get_parent()
	while current != null:
		if current is FGUIView:
			return current as FGUIView
		current = current.get_parent()
	return null


func _bind_view(value: FGUIView) -> void:
	if _view == value:
		if _view != null and _view.fairy != null:
			_resolve_target()
		return
	_release_target()
	if _view != null:
		if _view.fairy_ready.is_connected(_on_fairy_ready):
			_view.fairy_ready.disconnect(_on_fairy_ready)
		if _view.fairy_cleared.is_connected(_on_fairy_cleared):
			_view.fairy_cleared.disconnect(_on_fairy_cleared)
	_view = value
	if _view != null:
		if not _view.fairy_ready.is_connected(_on_fairy_ready):
			_view.fairy_ready.connect(_on_fairy_ready)
		if not _view.fairy_cleared.is_connected(_on_fairy_cleared):
			_view.fairy_cleared.connect(_on_fairy_cleared)
	_resolve_target()
	update_configuration_warnings()


func _on_fairy_ready(_value: FGUIObject) -> void:
	_resolve_target()


func _on_fairy_cleared(_value: FGUIObject) -> void:
	_release_target()
	_sync_proxy()


func _resolve_target() -> void:
	_release_target()
	if _view == null or _view.fairy == null or _target_ref == null:
		_sync_proxy()
		update_configuration_warnings()
		return
	_resolved_object = _target_ref.resolve(_view.fairy)
	if _resolved_object != null and not _resolved_object.is_disposed:
		_apply_material()
		_sync_proxy()
		target_resolved.emit(_resolved_object)
	else:
		_sync_proxy()
	update_configuration_warnings()
	notify_property_list_changed()


func _release_target() -> void:
	_restore_scene_render_parent()
	_release_material()
	if _resolved_object != null:
		_resolved_object = null
		target_cleared.emit()


func _sync_proxy() -> void:
	if not _enabled:
		visible = false
		_sync_render_hierarchy()
		return
	if _resolved_object == null or _resolved_object.is_disposed or _resolved_object.node == null:
		visible = not _hide_when_missing
		_sync_render_hierarchy()
		return
	var native := _resolved_object.node
	if _sync_transform and native.is_inside_tree() and is_inside_tree():
		var parent_canvas := get_parent() as CanvasItem
		if parent_canvas != null and parent_canvas.is_inside_tree():
			var local_transform := parent_canvas.get_global_transform().affine_inverse() * native.get_global_transform()
			pivot_offset = Vector2.ZERO
			position = local_transform.origin
			rotation = local_transform.get_rotation()
			scale = local_transform.get_scale()
	if _sync_size:
		size = native.size
	if _sync_visibility:
		visible = native.is_visible_in_tree()
	else:
		visible = true
	_sync_render_hierarchy()


func _update_attachment_mode() -> void:
	var preserve_hierarchy := _attachment_mode == AttachmentMode.FUI_HIERARCHY
	z_index = 0 if preserve_hierarchy else 1
	z_as_relative = true
	show_behind_parent = _attachment_behind_target if preserve_hierarchy else false
	if preserve_hierarchy:
		_sync_render_hierarchy()
	else:
		_restore_scene_render_parent()


func _sync_render_hierarchy() -> void:
	if _attachment_mode != AttachmentMode.FUI_HIERARCHY or not is_inside_tree() \
			or _resolved_object == null or _resolved_object.is_disposed \
			or _resolved_object.node == null or not _resolved_object.node.is_inside_tree():
		_restore_scene_render_parent()
		return
	var native := _resolved_object.node as CanvasItem
	if native == null or native == self:
		_restore_scene_render_parent()
		return
	if not _render_parent_overridden or _render_parent_target != native:
		RenderingServer.canvas_item_set_parent(get_canvas_item(), native.get_canvas_item())
	var render_transform := Transform2D.IDENTITY
	if not _sync_transform:
		render_transform = native.get_global_transform().affine_inverse() * get_global_transform()
	RenderingServer.canvas_item_set_transform(get_canvas_item(), render_transform)
	_render_parent_overridden = true
	_render_parent_target = native


func _restore_scene_render_parent() -> void:
	if not _render_parent_overridden:
		return
	_render_parent_overridden = false
	_render_parent_target = null
	if not is_inside_tree():
		return
	var scene_parent := _find_scene_canvas_parent()
	var parent_rid := scene_parent.get_canvas_item() if scene_parent != null else get_canvas()
	RenderingServer.canvas_item_set_parent(get_canvas_item(), parent_rid)
	RenderingServer.canvas_item_set_transform(get_canvas_item(), get_transform())


func _find_scene_canvas_parent() -> CanvasItem:
	var current := get_parent()
	while current != null:
		if current is CanvasItem:
			return current as CanvasItem
		current = current.get_parent()
	return null


func _refresh_material_target() -> void:
	if not _enabled or _resolved_object == null or _resolved_object.is_disposed:
		_release_material()
		return
	var current := _resolved_object.get_material_target()
	if current != _material_target:
		_release_material()
		_apply_material()
	elif _material_override != null and is_instance_valid(_material_target) \
			and _material_target.material != _material_override:
		_material_target.material = _material_override
		_applied_material = _material_override


func _apply_material() -> void:
	if not _enabled or _material_override == null \
			or _resolved_object == null or _resolved_object.is_disposed:
		return
	var current := _resolved_object.get_material_target()
	if current == null or not is_instance_valid(current):
		return
	_material_target = current
	_previous_material = current.material
	current.material = _material_override
	_applied_material = _material_override


func _release_material() -> void:
	if _material_target != null and is_instance_valid(_material_target) \
			and _material_target.material == _applied_material:
		_material_target.material = _previous_material
	_material_target = null
	_previous_material = null
	_applied_material = null


func _connect_target_ref() -> void:
	if _target_ref != null and not _target_ref.changed.is_connected(_on_target_ref_changed):
		_target_ref.changed.connect(_on_target_ref_changed)


func _disconnect_target_ref() -> void:
	if _target_ref != null and _target_ref.changed.is_connected(_on_target_ref_changed):
		_target_ref.changed.disconnect(_on_target_ref_changed)


func _on_target_ref_changed() -> void:
	_resolve_target()
