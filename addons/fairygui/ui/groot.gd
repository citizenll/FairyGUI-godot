class_name FGUIRoot
extends FGUIComponent

static var inst: FGUIRoot

var content_scale_factor: float = 1.0


func _init() -> void:
	super._init()
	inst = self
	name = "GRoot"
	if node != null:
		node.name = "GRoot"
		node.mouse_filter = Control.MOUSE_FILTER_PASS


static func get_inst() -> FGUIRoot:
	if inst == null:
		inst = FGUIRoot.new()
	return inst


func attach_to(parent_node: Node) -> void:
	if parent_node == null or node == null:
		return
	if node.get_parent() != parent_node:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		parent_node.add_child(node)
	_update_size_from_viewport()


func show_window(window: FGUIWindow) -> void:
	if window == null:
		return
	if window.parent != self:
		add_child(window)
	else:
		set_child_index(window, children.size() - 1)
	window._show_from_root()


func hide_window(window: FGUIWindow) -> void:
	if window == null:
		return
	window._hide_from_root()
	if window.parent == self:
		remove_child(window)


func bring_to_front(window: FGUIWindow) -> void:
	if window != null and window.parent == self:
		set_child_index(window, children.size() - 1)


func show_popup(popup: FGUIObject, target: FGUIObject = null, _dir: int = FGUIEnums.POPUP_AUTO) -> void:
	if popup == null:
		return
	add_child(popup)
	if target != null:
		popup.set_xy(target.x, target.y + target.height)


func hide_popup(popup: FGUIObject = null) -> void:
	if popup != null:
		popup.remove_from_parent()


func play_one_shot_sound(sound: Variant, volume_scale: float = 1.0) -> AudioStreamPlayer:
	var stream: AudioStream
	if sound is AudioStream:
		stream = sound
	elif sound is String:
		var path := String(sound)
		if path.begins_with("ui://"):
			var item := FGUIPackage.get_item_by_url(path)
			if item != null:
				stream = item.owner.get_item_asset(item)
		else:
			var resource := load(path)
			if resource is AudioStream:
				stream = resource
	if stream == null or node == null:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(0.0001, volume_scale))
	node.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


func _update_size_from_viewport() -> void:
	if node == null:
		return
	var viewport := node.get_viewport()
	if viewport != null:
		set_size(viewport.get_visible_rect().size.x, viewport.get_visible_rect().size.y)
