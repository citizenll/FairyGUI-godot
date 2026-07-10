class_name FGUIToolSet
extends RefCounted

const _FILTER_VALUES_META := &"_fgui_filter_values"
const _FILTER_GRAY_META := &"_fgui_filter_gray"
const _FILTER_MATERIAL_META := &"_fgui_filter_material"
const _FILTER_STACK_META := &"_fgui_filter_stack"
const _COLOR_FILTER_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 fgui_filter = vec4(0.0);
uniform bool fgui_grayed = false;

const vec3 FGUI_LUMA = vec3(0.299, 0.587, 0.114);

vec3 apply_hue(vec3 rgb, float amount) {
	float angle = clamp(amount, -1.0, 1.0) * PI;
	float c = cos(angle);
	float s = sin(angle);
	return vec3(
		(FGUI_LUMA.r + c * (1.0 - FGUI_LUMA.r) - s * FGUI_LUMA.r) * rgb.r
			+ (FGUI_LUMA.g - c * FGUI_LUMA.g - s * FGUI_LUMA.g) * rgb.g
			+ (FGUI_LUMA.b - c * FGUI_LUMA.b + s * (1.0 - FGUI_LUMA.b)) * rgb.b,
		(FGUI_LUMA.r - c * FGUI_LUMA.r + s * 0.143) * rgb.r
			+ (FGUI_LUMA.g + c * (1.0 - FGUI_LUMA.g) + s * 0.14) * rgb.g
			+ (FGUI_LUMA.b - c * FGUI_LUMA.b - s * 0.283) * rgb.b,
		(FGUI_LUMA.r - c * FGUI_LUMA.r - s * (1.0 - FGUI_LUMA.r)) * rgb.r
			+ (FGUI_LUMA.g - c * FGUI_LUMA.g + s * FGUI_LUMA.g) * rgb.g
			+ (FGUI_LUMA.b + c * (1.0 - FGUI_LUMA.b) + s * FGUI_LUMA.b) * rgb.b
	);
}

vec3 apply_saturation(vec3 rgb, float amount) {
	float scale = clamp(amount, -1.0, 1.0) + 1.0;
	float inverse_scale = 1.0 - scale;
	vec3 inverse_luma = FGUI_LUMA * inverse_scale;
	return vec3(
		(inverse_luma.r + scale) * rgb.r + inverse_luma.g * rgb.g + inverse_luma.b * rgb.b,
		inverse_luma.r * rgb.r + (inverse_luma.g + scale) * rgb.g + inverse_luma.b * rgb.b,
		inverse_luma.r * rgb.r + inverse_luma.g * rgb.g + (inverse_luma.b + scale) * rgb.b
	);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	vec3 rgb = source.rgb;
	if (fgui_grayed) {
		rgb = vec3(dot(rgb, FGUI_LUMA));
	} else {
		rgb = apply_hue(rgb, fgui_filter.w);
		float contrast_scale = clamp(fgui_filter.y, -1.0, 1.0) + 1.0;
		rgb = rgb * contrast_scale + vec3(0.5019608 * (1.0 - contrast_scale));
		rgb += vec3(clamp(fgui_filter.x, -1.0, 1.0));
		rgb = apply_saturation(rgb, fgui_filter.z);
	}
	COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), source.a);
}
"""

static var _color_filter_shader: Shader


static func starts_with(source: String, value: String, ignore_case: bool = false) -> bool:
	if ignore_case:
		return source.to_lower().begins_with(value.to_lower())
	return source.begins_with(value)


static func ends_with(source: String, value: String, ignore_case: bool = false) -> bool:
	if ignore_case:
		return source.to_lower().ends_with(value.to_lower())
	return source.ends_with(value)


static func trim_right(source: String) -> String:
	var index := source.length() - 1
	while index >= 0:
		var ch := source[index]
		if ch != " " and ch != "\n" and ch != "\r" and ch != "\t":
			break
		index -= 1
	return source.substr(0, index + 1)


static func encode_html(source: String) -> String:
	return source.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("'", "&apos;").replace("\"", "&quot;")


static func clamp01(value: float) -> float:
	if is_nan(value):
		return 0.0
	return clampf(value, 0.0, 1.0)


static func lerp_number(start: float, end: float, percent: float) -> float:
	return start + percent * (end - start)


static func repeat(value: float, length: float) -> float:
	return value - floorf(value / length) * length


static func distance(x1: float, y1: float, x2: float, y2: float) -> float:
	return Vector2(x1, y1).distance_to(Vector2(x2, y2))


static func color_from_html(source: String, has_alpha: bool = false) -> Color:
	var text := source.strip_edges()
	if text == "":
		return Color.TRANSPARENT
	if not text.begins_with("#"):
		text = "#" + text
	if text.length() == 9:
		return Color.html(text)
	var color := Color.html(text)
	if has_alpha:
		color.a = 1.0
	return color


static func color_to_html(color: Color, has_alpha: bool = false) -> String:
	return color.to_html(has_alpha)


static func display_object_to_gobject(node: Node) -> FGUIObject:
	var current := node
	while current != null:
		if current.has_meta("fgui_owner"):
			return current.get_meta("fgui_owner")
		current = current.get_parent()
	return null


static func set_color_filter(control: CanvasItem, color: Variant = null) -> void:
	if control == null:
		return
	if color is bool:
		control.set_meta(_FILTER_GRAY_META, color)
	elif color is Color:
		control.self_modulate = color
		return
	elif color is String:
		control.self_modulate = color_from_html(color)
		return
	elif color is Vector4:
		control.set_meta(_FILTER_VALUES_META, color)
	elif color is Array and color.size() >= 4:
		control.set_meta(_FILTER_VALUES_META, Vector4(float(color[0]), float(color[1]), float(color[2]), float(color[3])))
	elif typeof(color) == TYPE_PACKED_FLOAT32_ARRAY and color.size() >= 4:
		control.set_meta(_FILTER_VALUES_META, Vector4(float(color[0]), float(color[1]), float(color[2]), float(color[3])))
	else:
		control.remove_meta(_FILTER_VALUES_META)
		control.self_modulate = Color.WHITE
	refresh_color_filter(control)


static func refresh_color_filter(control: CanvasItem, rebuild_tree: bool = false) -> void:
	if control == null:
		return
	var grayed := bool(control.get_meta(_FILTER_GRAY_META, false))
	var has_values := control.has_meta(_FILTER_VALUES_META)
	var owner_id := control.get_instance_id()
	if not grayed and not has_values:
		_remove_filter_from_tree(control, owner_id)
		control.remove_meta(_FILTER_MATERIAL_META)
		return
	var material: ShaderMaterial = control.get_meta(_FILTER_MATERIAL_META) if control.has_meta(_FILTER_MATERIAL_META) else null
	if material == null:
		material = ShaderMaterial.new()
		material.shader = _get_color_filter_shader()
		control.set_meta(_FILTER_MATERIAL_META, material)
		rebuild_tree = true
	var values: Vector4 = control.get_meta(_FILTER_VALUES_META, Vector4.ZERO)
	material.set_shader_parameter("fgui_filter", values)
	material.set_shader_parameter("fgui_grayed", grayed)
	if rebuild_tree:
		_apply_filter_to_tree(control, material, owner_id, control)


static func detach_color_filter(control: CanvasItem, filter_owner: CanvasItem) -> void:
	if control == null or filter_owner == null:
		return
	_remove_filter_from_tree(control, filter_owner.get_instance_id())


static func _get_color_filter_shader() -> Shader:
	if _color_filter_shader == null:
		_color_filter_shader = Shader.new()
		_color_filter_shader.code = _COLOR_FILTER_SHADER_CODE
	return _color_filter_shader


static func _apply_filter_to_tree(node: Node, material: ShaderMaterial, owner_id: int, owner_root: CanvasItem) -> void:
	if node is CanvasItem:
		_apply_filter_to_item(node as CanvasItem, material, owner_id, owner_root)
	for child in node.get_children():
		_apply_filter_to_tree(child, material, owner_id, owner_root)


static func _apply_filter_to_item(item: CanvasItem, material: ShaderMaterial, owner_id: int, owner_root: CanvasItem) -> void:
	var stack: Array = item.get_meta(_FILTER_STACK_META, []).duplicate(true)
	for i in stack.size():
		if int(stack[i]["owner_id"]) == owner_id:
			if i == stack.size() - 1:
				item.material = material
				item.use_parent_material = false
			return

	var insert_index := stack.size()
	for i in stack.size():
		var existing_owner := instance_from_id(int(stack[i]["owner_id"])) as CanvasItem
		if existing_owner != null and owner_root.is_ancestor_of(existing_owner):
			insert_index = i
			break

	var previous_material: Material = item.material
	var previous_use_parent := item.use_parent_material
	if insert_index < stack.size():
		previous_material = stack[insert_index]["material"]
		previous_use_parent = bool(stack[insert_index]["use_parent_material"])
	stack.insert(insert_index, {
		"owner_id": owner_id,
		"material": previous_material,
		"use_parent_material": previous_use_parent
	})
	if insert_index + 1 < stack.size():
		var next_entry: Dictionary = stack[insert_index + 1]
		next_entry["material"] = material
		next_entry["use_parent_material"] = false
		stack[insert_index + 1] = next_entry
	else:
		item.material = material
		item.use_parent_material = false
	item.set_meta(_FILTER_STACK_META, stack)


static func _remove_filter_from_tree(node: Node, owner_id: int) -> void:
	if node is CanvasItem:
		_remove_filter_from_item(node as CanvasItem, owner_id)
	for child in node.get_children():
		_remove_filter_from_tree(child, owner_id)


static func _remove_filter_from_item(item: CanvasItem, owner_id: int) -> void:
	var stack: Array = item.get_meta(_FILTER_STACK_META, []).duplicate(true)
	var index := -1
	for i in stack.size():
		if int(stack[i]["owner_id"]) == owner_id:
			index = i
			break
	if index == -1:
		return
	var entry: Dictionary = stack[index]
	if index == stack.size() - 1:
		item.material = entry["material"]
		item.use_parent_material = bool(entry["use_parent_material"])
	else:
		var next_entry: Dictionary = stack[index + 1]
		next_entry["material"] = entry["material"]
		next_entry["use_parent_material"] = bool(entry["use_parent_material"])
		stack[index + 1] = next_entry
	stack.remove_at(index)
	if stack.is_empty():
		item.remove_meta(_FILTER_STACK_META)
	else:
		item.set_meta(_FILTER_STACK_META, stack)
