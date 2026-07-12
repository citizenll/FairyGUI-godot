class_name FGUIToolSet
extends RefCounted

const _FILTER_VALUES_META := &"_fgui_filter_values"
const _FILTER_GRAY_META := &"_fgui_filter_gray"
const _FILTER_MATERIAL_META := &"_fgui_filter_material"
const _FILTER_STACK_META := &"_fgui_filter_stack"
const _BLEND_MODE_META := &"_fgui_blend_mode"
const _BLEND_MATERIAL_META := &"_fgui_blend_material"
const _BLEND_PREVIOUS_MATERIAL_META := &"_fgui_blend_previous_material"
const _BLEND_PREVIOUS_PARENT_META := &"_fgui_blend_previous_parent_material"
const _COLOR_FILTER_SHADER_CODE := """
shader_type canvas_item;

uniform vec4 fgui_filter = vec4(0.0);
uniform bool fgui_grayed = false;
__SCREEN_UNIFORM__

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
	vec4 filtered = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), source.a);
	__BLEND_OUTPUT__
}
"""

static var _color_filter_shaders: Dictionary = {}
static var _blend_materials: Dictionary = {}


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


static func is_pointer_event(event: InputEvent) -> bool:
	return event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag


static func is_primary_pointer_press(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)


static func is_primary_pointer_release(event: InputEvent) -> bool:
	return (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) or (event is InputEventScreenTouch and not event.pressed)


static func is_pointer_motion(event: InputEvent) -> bool:
	return event is InputEventMouseMotion or event is InputEventScreenDrag


static func get_pointer_position(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return event.global_position
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return event.position
	return Vector2.ZERO


static func get_pointer_id(event: InputEvent) -> int:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return event.index
	return -1


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


static func get_blend_mode(control: CanvasItem) -> int:
	if control == null:
		return FGUIEnums.BLEND_NORMAL
	return int(control.get_meta(_BLEND_MODE_META, FGUIEnums.BLEND_NORMAL))


static func normalize_blend_mode(mode: int) -> int:
	return mode if mode >= FGUIEnums.BLEND_NORMAL and mode <= FGUIEnums.BLEND_CUSTOM_3 else FGUIEnums.BLEND_NORMAL


static func set_blend_mode(control: CanvasItem, mode: int) -> void:
	if control == null:
		return
	var normalized_mode := normalize_blend_mode(mode)
	control.set_meta(_BLEND_MODE_META, normalized_mode)
	if bool(control.get_meta(_FILTER_GRAY_META, false)) or control.has_meta(_FILTER_VALUES_META):
		control.remove_meta(_FILTER_MATERIAL_META)
		refresh_color_filter(control, true)
	else:
		_apply_direct_blend_mode(control)


static func refresh_color_filter(control: CanvasItem, rebuild_tree: bool = false) -> void:
	if control == null:
		return
	var grayed := bool(control.get_meta(_FILTER_GRAY_META, false))
	var has_values := control.has_meta(_FILTER_VALUES_META)
	var owner_id := control.get_instance_id()
	if not grayed and not has_values:
		_remove_filter_from_tree(control, owner_id)
		control.remove_meta(_FILTER_MATERIAL_META)
		_apply_direct_blend_mode(control)
		return
	var material: ShaderMaterial = control.get_meta(_FILTER_MATERIAL_META) if control.has_meta(_FILTER_MATERIAL_META) else null
	if material == null:
		material = ShaderMaterial.new()
		material.shader = _get_color_filter_shader(get_blend_mode(control))
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


static func _get_color_filter_shader(blend_mode: int) -> Shader:
	var normalized_mode := normalize_blend_mode(blend_mode)
	if not _color_filter_shaders.has(normalized_mode):
		var shader := Shader.new()
		shader.code = _build_blend_shader_code(normalized_mode)
		_color_filter_shaders[normalized_mode] = shader
	return _color_filter_shaders[normalized_mode]


static func _apply_direct_blend_mode(control: CanvasItem) -> void:
	var blend_mode := get_blend_mode(control)
	var current_material: Material = control.get_meta(_BLEND_MATERIAL_META) if control.has_meta(_BLEND_MATERIAL_META) else null
	var desired_material := _get_direct_blend_material(blend_mode)
	if current_material == desired_material:
		return
	if current_material != null and control.material == current_material:
		control.material = control.get_meta(_BLEND_PREVIOUS_MATERIAL_META, null)
		control.use_parent_material = bool(control.get_meta(_BLEND_PREVIOUS_PARENT_META, false))
	if desired_material != null:
		if current_material == null:
			control.set_meta(_BLEND_PREVIOUS_MATERIAL_META, control.material)
			control.set_meta(_BLEND_PREVIOUS_PARENT_META, control.use_parent_material)
		control.set_meta(_BLEND_MATERIAL_META, desired_material)
		control.material = desired_material
		control.use_parent_material = false
		return
	control.remove_meta(_BLEND_MATERIAL_META)
	control.remove_meta(_BLEND_PREVIOUS_MATERIAL_META)
	control.remove_meta(_BLEND_PREVIOUS_PARENT_META)


static func _get_direct_blend_material(blend_mode: int) -> Material:
	blend_mode = normalize_blend_mode(blend_mode)
	if blend_mode == FGUIEnums.BLEND_NORMAL or blend_mode >= FGUIEnums.BLEND_CUSTOM_1:
		return null
	if _blend_materials.has(blend_mode):
		return _blend_materials[blend_mode]
	var material: Material
	match blend_mode:
		FGUIEnums.BLEND_ADD:
			var canvas_material := CanvasItemMaterial.new()
			canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			material = canvas_material
		FGUIEnums.BLEND_MULTIPLY:
			material = _new_shader_material(blend_mode)
		FGUIEnums.BLEND_OFF:
			material = _new_shader_material(blend_mode)
		FGUIEnums.BLEND_ONE_ONE_MINUS_SRC_ALPHA:
			material = _new_shader_material(blend_mode)
		_:
			material = _new_shader_material(blend_mode)
	_blend_materials[blend_mode] = material
	return material


static func _new_shader_material(blend_mode: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_color_filter_shader(blend_mode)
	material.set_shader_parameter("fgui_filter", Vector4.ZERO)
	material.set_shader_parameter("fgui_grayed", false)
	return material


static func _build_blend_shader_code(blend_mode: int) -> String:
	var render_mode := ""
	var screen_uniform := ""
	var blend_output := "COLOR = filtered;"
	match blend_mode:
		FGUIEnums.BLEND_ADD:
			render_mode = "\nrender_mode blend_add;"
		FGUIEnums.BLEND_MULTIPLY:
			render_mode = "\nrender_mode blend_mul;"
			blend_output = "COLOR = vec4(mix(vec3(1.0), filtered.rgb, filtered.a), 1.0);"
		FGUIEnums.BLEND_OFF:
			render_mode = "\nrender_mode blend_disabled;"
			blend_output = "if (filtered.a <= 0.0001) { discard; } COLOR = filtered;"
		FGUIEnums.BLEND_ONE_ONE_MINUS_SRC_ALPHA:
			render_mode = "\nrender_mode blend_premul_alpha;"
			blend_output = "COLOR = vec4(filtered.rgb * filtered.a, filtered.a);"
		FGUIEnums.BLEND_NONE, FGUIEnums.BLEND_SCREEN, FGUIEnums.BLEND_ERASE, FGUIEnums.BLEND_MASK, FGUIEnums.BLEND_BELOW:
			render_mode = "\nrender_mode blend_disabled;"
			screen_uniform = "uniform sampler2D fgui_screen_texture : hint_screen_texture, repeat_disable, filter_nearest;"
			match blend_mode:
				FGUIEnums.BLEND_NONE:
					blend_output = "if (filtered.a <= 0.0001) { discard; } vec4 background = textureLod(fgui_screen_texture, SCREEN_UV, 0.0); COLOR = min(background + filtered, vec4(1.0));"
				FGUIEnums.BLEND_SCREEN:
					blend_output = "if (filtered.a <= 0.0001) { discard; } vec4 background = textureLod(fgui_screen_texture, SCREEN_UV, 0.0); vec3 source_rgb = filtered.rgb * filtered.a; COLOR = vec4(vec3(1.0) - (vec3(1.0) - background.rgb) * (vec3(1.0) - source_rgb), filtered.a + background.a * (1.0 - filtered.a));"
				FGUIEnums.BLEND_ERASE:
					blend_output = "if (filtered.a <= 0.0001) { discard; } vec4 background = textureLod(fgui_screen_texture, SCREEN_UV, 0.0); COLOR = background * (1.0 - filtered.a);"
				FGUIEnums.BLEND_MASK:
					blend_output = "if (filtered.a <= 0.0001) { discard; } vec4 background = textureLod(fgui_screen_texture, SCREEN_UV, 0.0); COLOR = background * filtered.a;"
				FGUIEnums.BLEND_BELOW:
					blend_output = "if (filtered.a <= 0.0001) { discard; } vec4 background = textureLod(fgui_screen_texture, SCREEN_UV, 0.0); COLOR = filtered * (1.0 - background.a) + background * background.a;"
	var code := _COLOR_FILTER_SHADER_CODE.replace("shader_type canvas_item;", "shader_type canvas_item;" + render_mode)
	code = code.replace("__SCREEN_UNIFORM__", screen_uniform)
	return code.replace("__BLEND_OUTPUT__", blend_output)


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
