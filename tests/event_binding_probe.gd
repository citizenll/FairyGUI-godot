extends SceneTree

const PACKAGE_PATH := "res://examples/assets/ui/Basics.fui"
const ROUNDTRIP_PATH := "res://tests/_event_binding_roundtrip.tscn"
const EventBinding := preload("res://addons/fairygui/ui/event_binding.gd")


class EventView extends FGUIView:
	var call_count: int = 0
	var last_context: FGUIEventContext

	func _on_button_clicked(context: FGUIEventContext) -> void:
		call_count += 1
		last_context = context


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var resource := ResourceLoader.load(PACKAGE_PATH) as FGUIPackageResource
	if resource == null:
		_fail("Could not load Basics.fui for event binding coverage.")
		return
	var binding := EventBinding.new()
	binding.target_path = PackedStringArray(["btn_Button"])
	binding.event_name = FGUIEvents.CLICK
	binding.handler = &"_on_button_clicked"
	var bindings: Array[EventBinding] = [binding]
	if not _verify_scene_roundtrip(resource, bindings):
		return

	var view := EventView.new()
	view.package = resource
	view.component_name = "Main"
	view.event_bindings = bindings
	root.add_child(view)
	for _frame in 4:
		await process_frame
	if view.fairy == null:
		_fail("FGUIView did not create the event binding test component.")
		return
	var target := binding.resolve_target(view.fairy)
	if target == null:
		_fail("Serialized FairyGUI target path did not resolve.")
		return
	target.emit_event(FGUIEvents.CLICK, "first")
	if view.call_count != 1 or view.last_context == null:
		_fail("FairyGUI event binding did not invoke the typed context handler.")
		return
	if view.last_context.type != "" or view.last_context.data != null:
		_fail("Pooled event context escaped its callback lifetime.")
		return

	view.refresh_preview()
	var refreshed_target := binding.resolve_target(view.fairy)
	if refreshed_target == null or refreshed_target == target:
		_fail("Event binding preview refresh did not replace the target object.")
		return
	refreshed_target.emit_event(FGUIEvents.CLICK, "second")
	if view.call_count != 2:
		_fail("Event binding was missing or duplicated after preview refresh.")
		return

	binding.enabled = false
	refreshed_target.emit_event(FGUIEvents.CLICK, "disabled")
	if view.call_count != 2:
		_fail("Disabling an event binding did not disconnect it.")
		return
	view.queue_free()
	await process_frame
	quit(0)


func _verify_scene_roundtrip(resource: FGUIPackageResource, bindings: Array[EventBinding]) -> bool:
	_remove_roundtrip_file()
	var scene_root := Control.new()
	scene_root.name = "EventBindingRoundtrip"
	var persisted_view := FGUIView.new()
	persisted_view.name = "View"
	persisted_view.package = resource
	persisted_view.component_name = "Main"
	persisted_view.event_bindings = bindings
	scene_root.add_child(persisted_view)
	persisted_view.owner = scene_root
	var packed := PackedScene.new()
	if packed.pack(scene_root) != OK or ResourceSaver.save(packed, ROUNDTRIP_PATH) != OK:
		scene_root.free()
		_remove_roundtrip_file()
		_fail("Could not serialize FGUIView event bindings into a scene.")
		return false
	scene_root.free()
	var reloaded := ResourceLoader.load(ROUNDTRIP_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	var instance := reloaded.instantiate() if reloaded != null else null
	var second_instance := reloaded.instantiate() if reloaded != null else null
	var restored := instance.get_node_or_null("View") as FGUIView if instance != null else null
	var second_restored := second_instance.get_node_or_null("View") as FGUIView if second_instance != null else null
	var valid := restored != null \
		and second_restored != null \
		and restored.event_bindings.size() == 1 \
		and second_restored.event_bindings.size() == 1 \
		and restored.event_bindings[0] != second_restored.event_bindings[0] \
		and restored.event_bindings[0].target_path == PackedStringArray(["btn_Button"]) \
		and restored.event_bindings[0].event_name == FGUIEvents.CLICK \
		and restored.event_bindings[0].handler == &"_on_button_clicked"
	if instance != null:
		instance.free()
	if second_instance != null:
		second_instance.free()
	_remove_roundtrip_file()
	if not valid:
		_fail("FGUIView event bindings did not survive scene serialization.")
		return false
	return true


func _remove_roundtrip_file() -> void:
	for path in [ROUNDTRIP_PATH, ROUNDTRIP_PATH + ".uid"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
