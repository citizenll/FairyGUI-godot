@tool
extends FGUIView

const UI_TYPE := preload("res://generated/fairygui/basics/ui_basics_main.gd")

var ui: UI_TYPE


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	ui = fairy as UI_TYPE
	if ui == null:
		push_error("FairyGUI binding mismatch: Basics/Main")


func _on_btn_button_clicked(event: FGUIEventContext) -> void:
	var sender := event.sender as FGUIObject
	print("FairyGUI event binding: ", sender.name if sender != null else "btn_Button")
