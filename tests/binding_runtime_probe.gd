extends SceneTree

const PACKAGE_PATH := "res://examples/assets/ui/VirtualList.fui"

class BoundMain extends FGUIComponent:
	var hook_called: bool = false
	var mail_list: FGUIList

	func _on_construct() -> void:
		super._on_construct()
		hook_called = true
		mail_list = require_child("mailList", FGUIList) as FGUIList


class GeneratedMain extends BoundMain:
	pass


class ManualMain extends BoundMain:
	pass

var _ready_value: FGUIObject


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	FGUIObjectFactory.clear()
	var package := FGUIPackage.add_package(PACKAGE_PATH)
	if package == null:
		_fail("Could not load binding runtime package.")
		return

	var direct := package.create_object("Main", BoundMain) as BoundMain
	if direct == null or not direct.hook_called or direct.mail_list == null:
		_fail("Explicit component script did not run the construct hook and bind members.")
		return
	direct.dispose()

	var item := package.get_item_by_name("Main")
	var url := "ui://%s%s" % [package.id, item.id]
	FGUIObjectFactory.set_generated_extensions({url: GeneratedMain})
	var generated := package.create_object("Main")
	if not generated is GeneratedMain:
		_fail("Generated factory extension was not selected.")
		return
	generated.dispose()

	FGUIObjectFactory.set_extension(url, ManualMain)
	var manual := package.create_object("Main")
	if not manual is ManualMain:
		_fail("Manual factory extension did not override the generated extension.")
		return
	manual.dispose()

	var previous_registry: Variant = ProjectSettings.get_setting("fairygui/codegen/registry_path", null)
	ProjectSettings.set_setting("fairygui/codegen/registry_path", "res://tests/missing_generated_registry.gd")
	FGUIObjectFactory.clear()
	var fallback := package.create_object("Main")
	if fallback == null or not fallback is FGUIComponent or fallback is BoundMain:
		_fail("Missing generated registry did not fall back to the base FairyGUI component.")
		return
	fallback.dispose()
	if previous_registry == null:
		ProjectSettings.clear("fairygui/codegen/registry_path")
	else:
		ProjectSettings.set_setting("fairygui/codegen/registry_path", previous_registry)

	var package_resource := ResourceLoader.load(PACKAGE_PATH) as FGUIPackageResource
	var view := FGUIView.new()
	view.package = package_resource
	view.component_name = "Main"
	view.component_script = BoundMain
	view.fairy_ready.connect(func(value: FGUIObject) -> void: _ready_value = value)
	root.add_child(view)
	if view.fairy == null or not view.fairy is BoundMain or _ready_value != view.fairy:
		_fail("FGUIView did not create and expose its typed FairyGUI object synchronously.")
		return
	if not (view.fairy as BoundMain).hook_called or (view.fairy as BoundMain).mail_list == null:
		_fail("FGUIView typed object did not finish generated member binding.")
		return

	view.queue_free()
	await process_frame
	FGUIObjectFactory.clear()
	if FGUIPackage.get_by_name(package.name) == package:
		FGUIPackage.remove_package_instance(package)
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	FGUIObjectFactory.clear()
	quit(1)
