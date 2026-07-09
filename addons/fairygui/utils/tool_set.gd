class_name FGUIToolSet
extends RefCounted


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
		control.self_modulate = Color(0.65, 0.65, 0.65, control.self_modulate.a) if color else Color.WHITE
	elif color is Color:
		control.self_modulate = color
	elif color is String:
		control.self_modulate = color_from_html(color)
	else:
		control.self_modulate = Color.WHITE

