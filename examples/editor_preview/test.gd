@tool
extends FGUIView

var ui: UI_BasicsMain


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	ui = fairy as UI_BasicsMain
	if ui == null:
		push_error("Basics/Main was not created with its generated binding.")
