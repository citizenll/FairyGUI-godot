extends SceneTree

const PACKAGE_DIR := "res://examples/assets/ui"
const OUTPUT_DIR := "res://generated/fairygui"
const REGISTRY_PATH := OUTPUT_DIR + "/registry.gd"


func _initialize() -> void:
	_generate.call_deferred()


func _generate() -> void:
	var package_paths := PackedStringArray()
	var directory := DirAccess.open(PACKAGE_DIR)
	if directory == null:
		push_error("Could not open demo FairyGUI package directory: %s" % PACKAGE_DIR)
		quit(1)
		return
	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "fui":
			package_paths.append("%s/%s" % [PACKAGE_DIR, file_name])
	package_paths.sort()

	var result := FGUIBindingCodeGenerator.new().generate(
		package_paths,
		OUTPUT_DIR,
		"UI_",
		true,
		REGISTRY_PATH,
		true
	)
	var warnings: PackedStringArray = result.get("warnings", PackedStringArray())
	if not warnings.is_empty():
		print("[FairyGUI demo codegen] %d warning(s):" % warnings.size())
		for warning: String in warnings:
			print("  - %s" % warning)
	if not bool(result.get("ok", false)):
		for error: String in result.get("errors", PackedStringArray()):
			push_error("[FairyGUI demo codegen] %s" % error)
		quit(1)
		return
	print("[FairyGUI demo codegen] %d generated, %d unchanged, %d removed." % [
		result.get("generated_files", PackedStringArray()).size(),
		result.get("unchanged_files", PackedStringArray()).size(),
		result.get("removed_files", PackedStringArray()).size(),
	])
	quit(0)
