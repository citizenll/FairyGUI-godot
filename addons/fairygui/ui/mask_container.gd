@tool
class_name FGUIMaskContainer
extends Control

const REVERSED_MASK_SHADER := """shader_type canvas_item;

uniform sampler2D mask_texture : source_color;
uniform bool mask_uses_texture = false;
uniform vec2 container_size = vec2(1.0);
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_x_axis = vec2(1.0, 0.0);
uniform vec2 mask_y_axis = vec2(0.0, 1.0);
uniform vec2 mask_size = vec2(1.0);
uniform float mask_alpha = 1.0;

void fragment() {
	vec2 point = UV * container_size;
	vec2 relative = point - mask_origin;
	float determinant = mask_x_axis.x * mask_y_axis.y - mask_x_axis.y * mask_y_axis.x;
	float coverage = 0.0;
	if (abs(determinant) > 0.00001) {
		vec2 local_point = vec2(
			(relative.x * mask_y_axis.y - relative.y * mask_y_axis.x) / determinant,
			(mask_x_axis.x * relative.y - mask_x_axis.y * relative.x) / determinant
		);
		vec2 mask_uv = local_point / max(mask_size, vec2(0.00001));
		if (all(greaterThanEqual(mask_uv, vec2(0.0))) && all(lessThanEqual(mask_uv, vec2(1.0)))) {
			coverage = mask_alpha;
			if (mask_uses_texture) {
				coverage *= texture(mask_texture, mask_uv).a;
			}
		}
	}
	COLOR = vec4(1.0, 1.0, 1.0, 1.0 - coverage);
}
"""

var mask_object: FGUIObject
var reversed_mask: bool = false
var _reversed_mask_material: ShaderMaterial
var _white_texture: ImageTexture


func _has_point(point: Vector2) -> bool:
	if not has_meta("fgui_owner"):
		return Rect2(Vector2.ZERO, size).has_point(point)
	var owner := get_meta("fgui_owner")
	if owner != null and owner.has_method("_accepts_native_input_at"):
		return bool(owner.call("_accepts_native_input_at", point))
	return Rect2(Vector2.ZERO, size).has_point(point)


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
		clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		_update_reversed_mask_material()
	else:
		clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
		material = null
	queue_redraw()


func refresh_mask() -> void:
	if reversed_mask:
		_update_reversed_mask_material()
	queue_redraw()


func _draw() -> void:
	if mask_object == null or mask_object.node == null:
		return
	if reversed_mask:
		draw_texture_rect(_get_white_texture(), Rect2(Vector2.ZERO, size), false, Color.WHITE)
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
	elif mask_node.has_method("get_mask_alpha"):
		draw_rect(Rect2(Vector2.ZERO, mask_node.size), Color(1, 1, 1, float(mask_node.call("get_mask_alpha")) * mask_node.modulate.a))
	else:
		draw_rect(Rect2(Vector2.ZERO, mask_node.size), Color.WHITE)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and reversed_mask:
		_update_reversed_mask_material()
		queue_redraw()


func _update_reversed_mask_material() -> void:
	if not reversed_mask or mask_object == null or not (mask_object.node is Control):
		material = null
		return
	if _reversed_mask_material == null:
		var shader := Shader.new()
		shader.code = REVERSED_MASK_SHADER
		_reversed_mask_material = ShaderMaterial.new()
		_reversed_mask_material.shader = shader
	material = _reversed_mask_material
	var mask_node := mask_object.node as Control
	var transform := _get_mask_transform(mask_node)
	var mask_texture: Texture2D = null
	if mask_node is NinePatchRect:
		mask_texture = (mask_node as NinePatchRect).texture
	elif mask_node is TextureRect:
		mask_texture = (mask_node as TextureRect).texture
	var alpha := mask_node.modulate.a * mask_node.self_modulate.a
	if mask_node is ColorRect:
		alpha *= (mask_node as ColorRect).color.a
	elif mask_node.has_method("get_mask_alpha"):
		alpha *= float(mask_node.call("get_mask_alpha"))
	_reversed_mask_material.set_shader_parameter("mask_texture", mask_texture if mask_texture != null else _get_white_texture())
	_reversed_mask_material.set_shader_parameter("mask_uses_texture", mask_texture != null)
	_reversed_mask_material.set_shader_parameter("container_size", Vector2(maxf(1.0, size.x), maxf(1.0, size.y)))
	_reversed_mask_material.set_shader_parameter("mask_origin", transform.origin)
	_reversed_mask_material.set_shader_parameter("mask_x_axis", transform.x)
	_reversed_mask_material.set_shader_parameter("mask_y_axis", transform.y)
	_reversed_mask_material.set_shader_parameter("mask_size", Vector2(maxf(1.0, mask_node.size.x), maxf(1.0, mask_node.size.y)))
	_reversed_mask_material.set_shader_parameter("mask_alpha", clampf(alpha, 0.0, 1.0))


func _get_white_texture() -> ImageTexture:
	if _white_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white_texture = ImageTexture.create_from_image(image)
	return _white_texture


func _get_mask_transform(mask_node: Control) -> Transform2D:
	if is_inside_tree() and mask_node.is_inside_tree():
		return get_global_transform().affine_inverse() * mask_node.get_global_transform()
	return mask_node.get_transform()
