@tool
class_name FGUIMaskContainer
extends Control

const REVERSED_MASK_SHADER := """shader_type canvas_item;

uniform sampler2D mask_texture : source_color;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform bool mask_uses_texture = false;
uniform vec2 container_size = vec2(1.0);
uniform vec2 mask_origin = vec2(0.0);
uniform vec2 mask_x_axis = vec2(1.0, 0.0);
uniform vec2 mask_y_axis = vec2(0.0, 1.0);
uniform vec2 mask_size = vec2(1.0);
uniform float mask_alpha = 1.0;

void fragment() {
	vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
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
	COLOR.rgb = source.rgb;
	COLOR.a *= 1.0 - coverage;
}
"""

var mask_object: FGUIObject
var reversed_mask: bool = false
var _reversed_mask_material: ShaderMaterial
var _white_texture: ImageTexture
var _graph_mask_texture: ImageTexture
var _graph_mask_source_id: int = 0
var _graph_mask_revision: int = -1
var _graph_mask_size := Vector2.ZERO
var _texture_mask_texture: ImageTexture
var _texture_mask_key: String = ""


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
	_graph_mask_texture = null
	_graph_mask_source_id = 0
	_graph_mask_revision = -1
	_graph_mask_size = Vector2.ZERO
	_texture_mask_texture = null
	_texture_mask_key = ""
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
	if mask_node.has_method("get_mask_alpha_at") and mask_node.has_method("get_draw_points"):
		_draw_graph_mask(mask_node)
	elif mask_node is NinePatchRect and mask_node.texture != null:
		var texture_rect := mask_node as NinePatchRect
		var style_box := StyleBoxTexture.new()
		if texture_rect.texture is AtlasTexture and (texture_rect.texture as AtlasTexture).atlas != null:
			style_box.texture = (texture_rect.texture as AtlasTexture).atlas
			style_box.region_rect = (texture_rect.texture as AtlasTexture).region
		else:
			style_box.texture = texture_rect.texture
		style_box.texture_margin_left = texture_rect.patch_margin_left
		style_box.texture_margin_top = texture_rect.patch_margin_top
		style_box.texture_margin_right = texture_rect.patch_margin_right
		style_box.texture_margin_bottom = texture_rect.patch_margin_bottom
		style_box.axis_stretch_horizontal = _style_axis_mode(texture_rect.axis_stretch_horizontal)
		style_box.axis_stretch_vertical = _style_axis_mode(texture_rect.axis_stretch_vertical)
		style_box.modulate_color = Color(1.0, 1.0, 1.0, texture_rect.modulate.a * texture_rect.self_modulate.a)
		draw_style_box(style_box, Rect2(Vector2.ZERO, texture_rect.size))
	elif mask_node is TextureRect and mask_node.texture != null:
		var texture_rect := mask_node as TextureRect
		draw_texture_rect(texture_rect.texture, Rect2(Vector2.ZERO, texture_rect.size), false, Color(1.0, 1.0, 1.0, texture_rect.modulate.a * texture_rect.self_modulate.a))
	elif mask_node is ColorRect:
		var color_rect := mask_node as ColorRect
		draw_rect(Rect2(Vector2.ZERO, color_rect.size), Color(1.0, 1.0, 1.0, color_rect.color.a * color_rect.modulate.a * color_rect.self_modulate.a))
	elif mask_node.has_method("get_mask_alpha"):
		draw_rect(Rect2(Vector2.ZERO, mask_node.size), Color(1.0, 1.0, 1.0, float(mask_node.call("get_mask_alpha")) * mask_node.modulate.a * mask_node.self_modulate.a))
	else:
		draw_rect(Rect2(Vector2.ZERO, mask_node.size), Color(1.0, 1.0, 1.0, mask_node.modulate.a * mask_node.self_modulate.a))
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
		mask_texture = _get_texture_mask(mask_node as NinePatchRect)
	elif mask_node is TextureRect:
		mask_texture = _get_texture_mask(mask_node as TextureRect)
	elif mask_node.has_method("get_mask_alpha_at"):
		mask_texture = _get_graph_mask_texture(mask_node)
	var alpha := mask_node.modulate.a * mask_node.self_modulate.a
	if mask_node is ColorRect:
		alpha *= (mask_node as ColorRect).color.a
	elif mask_node.has_method("get_mask_alpha") and not mask_node.has_method("get_mask_alpha_at"):
		alpha *= float(mask_node.call("get_mask_alpha"))
	_reversed_mask_material.set_shader_parameter("mask_texture", mask_texture if mask_texture != null else _get_white_texture())
	_reversed_mask_material.set_shader_parameter("mask_uses_texture", mask_texture != null)
	_reversed_mask_material.set_shader_parameter("container_size", Vector2(maxf(1.0, size.x), maxf(1.0, size.y)))
	_reversed_mask_material.set_shader_parameter("mask_origin", transform.origin)
	_reversed_mask_material.set_shader_parameter("mask_x_axis", transform.x)
	_reversed_mask_material.set_shader_parameter("mask_y_axis", transform.y)
	_reversed_mask_material.set_shader_parameter("mask_size", Vector2(maxf(1.0, mask_node.size.x), maxf(1.0, mask_node.size.y)))
	_reversed_mask_material.set_shader_parameter("mask_alpha", clampf(alpha, 0.0, 1.0))


func _draw_graph_mask(graph_node: Control) -> void:
	var graph_type := int(graph_node.get("graph_type"))
	var fill_color: Color = graph_node.get("fill_color")
	var line_color: Color = graph_node.get("line_color")
	var line_size := float(graph_node.get("line_size"))
	var modulation := graph_node.modulate.a * graph_node.self_modulate.a
	fill_color = Color(1.0, 1.0, 1.0, fill_color.a * modulation)
	line_color = Color(1.0, 1.0, 1.0, line_color.a * modulation)
	if graph_type == 0:
		var compatibility: ColorRect = graph_node.get("compatibility_color_rect")
		var alpha := compatibility.color.a * modulation if compatibility != null else 0.0
		draw_rect(Rect2(Vector2.ZERO, graph_node.size), Color(1.0, 1.0, 1.0, alpha))
	elif graph_type == 1:
		var style_box := StyleBoxFlat.new()
		style_box.bg_color = fill_color
		var radii: Array = graph_node.get("corner_radii")
		if not radii.is_empty():
			style_box.corner_radius_top_left = roundi(float(radii[0])) if radii.size() > 0 else 0
			style_box.corner_radius_top_right = roundi(float(radii[1])) if radii.size() > 1 else 0
			style_box.corner_radius_bottom_left = roundi(float(radii[2])) if radii.size() > 2 else 0
			style_box.corner_radius_bottom_right = roundi(float(radii[3])) if radii.size() > 3 else 0
		if line_size > 0.0 and line_color.a > 0.0:
			var border_size := maxi(1, roundi(line_size))
			style_box.border_width_left = border_size
			style_box.border_width_top = border_size
			style_box.border_width_right = border_size
			style_box.border_width_bottom = border_size
			style_box.border_color = line_color
		draw_style_box(style_box, Rect2(Vector2.ZERO, graph_node.size))
	else:
		var points: PackedVector2Array = graph_node.call("get_draw_points")
		if points.size() >= 3 and fill_color.a > 0.0:
			draw_colored_polygon(points, fill_color)
		if points.size() >= 2 and line_size > 0.0 and line_color.a > 0.0:
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, line_color, line_size, true)


func _get_graph_mask_texture(graph_node: Control) -> ImageTexture:
	var revision := int(graph_node.get("mask_revision"))
	if _graph_mask_texture != null and _graph_mask_source_id == graph_node.get_instance_id() \
		and _graph_mask_revision == revision and _graph_mask_size.is_equal_approx(graph_node.size):
		return _graph_mask_texture
	_graph_mask_source_id = graph_node.get_instance_id()
	_graph_mask_revision = revision
	_graph_mask_size = graph_node.size
	_graph_mask_texture = _build_graph_mask_texture(graph_node)
	return _graph_mask_texture


func _build_graph_mask_texture(graph_node: Control) -> ImageTexture:
	var scale := minf(1.0, 512.0 / maxf(1.0, maxf(graph_node.size.x, graph_node.size.y)))
	var image_width := maxi(1, ceili(graph_node.size.x * scale))
	var image_height := maxi(1, ceili(graph_node.size.y * scale))
	var image := Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)
	for y in image_height:
		for x in image_width:
			var source_point := Vector2((x + 0.5) * graph_node.size.x / image_width, (y + 0.5) * graph_node.size.y / image_height)
			var alpha := clampf(float(graph_node.call("get_mask_alpha_at", source_point)), 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _get_texture_mask(texture_node: Control) -> Texture2D:
	var source_texture: Texture2D = (texture_node as NinePatchRect).texture if texture_node is NinePatchRect else (texture_node as TextureRect).texture
	if source_texture == null:
		return null
	var needs_raster := source_texture is AtlasTexture
	if texture_node is NinePatchRect:
		var nine_patch := texture_node as NinePatchRect
		needs_raster = needs_raster or nine_patch.patch_margin_left > 0 or nine_patch.patch_margin_top > 0 \
			or nine_patch.patch_margin_right > 0 or nine_patch.patch_margin_bottom > 0
	if not needs_raster:
		return source_texture
	var key := _texture_mask_cache_key(texture_node)
	if _texture_mask_texture != null and _texture_mask_key == key:
		return _texture_mask_texture
	_texture_mask_key = key
	_texture_mask_texture = _build_texture_mask_texture(texture_node)
	return _texture_mask_texture if _texture_mask_texture != null else source_texture


func _texture_mask_cache_key(texture_node: Control) -> String:
	var texture: Texture2D = (texture_node as NinePatchRect).texture if texture_node is NinePatchRect else (texture_node as TextureRect).texture
	var texture_id := texture.get_instance_id() if texture != null else 0
	var values := [texture_id, texture_node.size.x, texture_node.size.y]
	if texture_node is NinePatchRect:
		var nine_patch := texture_node as NinePatchRect
		values.append_array([
			nine_patch.patch_margin_left,
			nine_patch.patch_margin_top,
			nine_patch.patch_margin_right,
			nine_patch.patch_margin_bottom,
			int(nine_patch.axis_stretch_horizontal),
			int(nine_patch.axis_stretch_vertical),
		])
	return var_to_str(values)


func _build_texture_mask_texture(texture_node: Control) -> ImageTexture:
	var texture: Texture2D = (texture_node as NinePatchRect).texture if texture_node is NinePatchRect else (texture_node as TextureRect).texture
	var source_image: Image
	var source_region: Rect2i
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		if atlas_texture.atlas == null:
			return null
		source_image = atlas_texture.atlas.get_image()
		source_region = Rect2i(Vector2i(atlas_texture.region.position), Vector2i(atlas_texture.region.size))
	else:
		source_image = texture.get_image()
		if source_image != null:
			source_region = Rect2i(Vector2i.ZERO, source_image.get_size())
	if source_image == null or source_image.is_empty() or source_region.size.x <= 0 or source_region.size.y <= 0:
		return null
	var scale := minf(1.0, 512.0 / maxf(1.0, maxf(texture_node.size.x, texture_node.size.y)))
	var output_width := maxi(1, ceili(texture_node.size.x * scale))
	var output_height := maxi(1, ceili(texture_node.size.y * scale))
	var output := Image.create(output_width, output_height, false, Image.FORMAT_RGBA8)
	var nine_patch := texture_node as NinePatchRect
	for y in output_height:
		var destination_y := (y + 0.5) * texture_node.size.y / output_height
		var source_y := destination_y / maxf(0.001, texture_node.size.y) * source_region.size.y
		if nine_patch != null:
			source_y = _map_nine_patch_coordinate(destination_y, texture_node.size.y, source_region.size.y, nine_patch.patch_margin_top, nine_patch.patch_margin_bottom, int(nine_patch.axis_stretch_vertical))
		for x in output_width:
			var destination_x := (x + 0.5) * texture_node.size.x / output_width
			var source_x := destination_x / maxf(0.001, texture_node.size.x) * source_region.size.x
			if nine_patch != null:
				source_x = _map_nine_patch_coordinate(destination_x, texture_node.size.x, source_region.size.x, nine_patch.patch_margin_left, nine_patch.patch_margin_right, int(nine_patch.axis_stretch_horizontal))
			var sample_x := clampi(source_region.position.x + floori(source_x), source_region.position.x, source_region.end.x - 1)
			var sample_y := clampi(source_region.position.y + floori(source_y), source_region.position.y, source_region.end.y - 1)
			var alpha := source_image.get_pixel(sample_x, sample_y).a
			output.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(output)


func _map_nine_patch_coordinate(value: float, destination_size: float, source_size: float, start_margin: float, end_margin: float, stretch_mode: int) -> float:
	var margin_scale := minf(1.0, destination_size / maxf(0.001, start_margin + end_margin))
	var destination_start := start_margin * margin_scale
	var destination_end := end_margin * margin_scale
	if value < destination_start:
		return value / maxf(0.001, destination_start) * start_margin
	if value >= destination_size - destination_end:
		return source_size - end_margin + (value - (destination_size - destination_end)) / maxf(0.001, destination_end) * end_margin
	var source_center := maxf(0.001, source_size - start_margin - end_margin)
	var destination_center := maxf(0.001, destination_size - destination_start - destination_end)
	var center_value := value - destination_start
	match stretch_mode:
		NinePatchRect.AXIS_STRETCH_MODE_TILE:
			return start_margin + fmod(center_value, source_center)
		NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT:
			var tile_count := maxf(1.0, roundf(destination_center / source_center))
			return start_margin + fmod(center_value * tile_count / destination_center, 1.0) * source_center
	return start_margin + center_value / destination_center * source_center


func _get_white_texture() -> ImageTexture:
	if _white_texture == null:
		var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_white_texture = ImageTexture.create_from_image(image)
	return _white_texture


func _style_axis_mode(value: int) -> StyleBoxTexture.AxisStretchMode:
	match value:
		NinePatchRect.AXIS_STRETCH_MODE_TILE:
			return StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT:
			return StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH


func _get_mask_transform(mask_node: Control) -> Transform2D:
	if is_inside_tree() and mask_node.is_inside_tree():
		return get_global_transform().affine_inverse() * mask_node.get_global_transform()
	return mask_node.get_transform()
