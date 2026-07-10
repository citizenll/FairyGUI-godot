@tool
class_name FGUIMaskContainer
extends Control

var mask_object: FGUIObject
var reversed_mask: bool = false


func set_mask(value: FGUIObject, reversed: bool = false) -> void:
	if mask_object == value and reversed_mask == reversed:
		return
	if mask_object != null and mask_object.node != null:
		mask_object.node.remove_meta("fgui_mask_hidden")
		mask_object._handle_visible_changed()
	mask_object = value
	reversed_mask = reversed
	if mask_object != null and mask_object.node != null:
		mask_object.node.set_meta("fgui_mask_hidden", true)
		mask_object.node.visible = false
		clip_children = CanvasItem.CLIP_CHILDREN_DISABLED if reversed_mask else CanvasItem.CLIP_CHILDREN_ONLY
	else:
		clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
	queue_redraw()


func refresh_mask() -> void:
	queue_redraw()


func _draw() -> void:
	if reversed_mask or mask_object == null or mask_object.node == null:
		return
	var mask_node := mask_object.node
	var transform := _get_mask_transform(mask_node)
	draw_set_transform_matrix(transform)
	if mask_node is NinePatchRect and mask_node.texture != null:
		var texture_rect := mask_node as NinePatchRect
		draw_texture_rect(texture_rect.texture, Rect2(Vector2.ZERO, texture_rect.size), false, Color(1, 1, 1, texture_rect.modulate.a))
	elif mask_node is TextureRect and mask_node.texture != null:
		var texture_rect := mask_node as TextureRect
		draw_texture_rect(texture_rect.texture, Rect2(Vector2.ZERO, texture_rect.size), false, Color(1, 1, 1, texture_rect.modulate.a))
	elif mask_node is ColorRect:
		var color_rect := mask_node as ColorRect
		draw_rect(Rect2(Vector2.ZERO, color_rect.size), Color(1, 1, 1, color_rect.color.a * color_rect.modulate.a))
	else:
		draw_rect(Rect2(Vector2.ZERO, mask_node.size), Color.WHITE)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _get_mask_transform(mask_node: Control) -> Transform2D:
	if is_inside_tree() and mask_node.is_inside_tree():
		return get_global_transform().affine_inverse() * mask_node.get_global_transform()
	return mask_node.get_transform()
