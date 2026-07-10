extends SceneTree

var state_change_count: int = 0


func _initialize() -> void:
	var parent := FGUIComponent.new()
	root.add_child(parent.node)
	var controller := FGUIController.new()
	controller.parent = parent
	controller.add_page("first")
	controller.add_page("third")
	controller.add_page_at("second", 1)
	if controller.page_count != 3 or controller.get_page_name(1) != "second" or controller.get_page_name_by_id(controller.get_page_id(2)) != "third":
		_fail("Controller dynamic page insertion did not preserve page IDs and names.")
		return
	controller.on(FGUIEvents.STATE_CHANGED, Callable(self, "_on_state_changed"))
	controller.selected_index = 1
	if controller.selected_page != "second" or state_change_count != 1:
		_fail("Controller selected_index did not emit state change events.")
		return
	controller.set_selected_index(2)
	if controller.selected_page != "third" or state_change_count != 1:
		_fail("Controller set_selected_index should update state without emitting an event.")
		return
	controller.selected_page = "missing"
	if controller.selected_index != 0 or state_change_count != 2:
		_fail("Controller selected_page did not fall back to the first page.")
		return
	controller.opposite_page_id = controller.get_page_id(0)
	if controller.selected_index != 1:
		_fail("Controller opposite_page_id did not select a different page.")
		return
	controller.remove_page("second")
	if controller.page_count != 2 or controller.selected_page != "third":
		_fail("Controller page removal did not preserve the current logical page.")
		return
	controller.clear_pages()
	if controller.page_count != 0 or controller.selected_index != -1:
		_fail("Controller clear_pages did not reset selection.")
		return

	var radio_parent := FGUIComponent.new()
	root.add_child(radio_parent.node)
	var radio_controller := FGUIController.new()
	radio_controller.name = "radio"
	radio_controller.auto_radio_group_depth = true
	radio_controller.add_page("first")
	radio_controller.add_page("second")
	radio_parent.add_controller(radio_controller)
	var first_radio := FGUIButton.new()
	first_radio.mode = FGUIEnums.BUTTON_RADIO
	first_radio.related_controller = radio_controller
	first_radio.related_page_id = radio_controller.get_page_id(0)
	var spacer := FGUIObject.new()
	var second_radio := FGUIButton.new()
	second_radio.mode = FGUIEnums.BUTTON_RADIO
	second_radio.related_controller = radio_controller
	second_radio.related_page_id = radio_controller.get_page_id(1)
	radio_parent.add_child(first_radio)
	radio_parent.add_child(spacer)
	radio_parent.add_child(second_radio)
	first_radio.selected = true
	if radio_parent.get_child_at(2) != first_radio:
		_fail("Auto radio group depth did not move the selected button in front of its group.")
		return
	second_radio.selected = true
	if radio_parent.get_child_at(2) != second_radio:
		_fail("Auto radio group depth did not update when the selected page changed.")
		return
	radio_parent.dispose()
	parent.controllers.append(controller)
	parent.dispose()
	if controller.parent != null or controller.has_event_listener(FGUIEvents.STATE_CHANGED):
		_fail("Component disposal did not release controller listeners.")
		return
	await process_frame
	quit(0)


func _on_state_changed(_controller: FGUIController) -> void:
	state_change_count += 1


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
