extends SceneTree


class ProbeWindow extends FGUIWindow:
	var init_count: int = 0
	var shown_count: int = 0
	var hidden_count: int = 0


	func on_init() -> void:
		init_count += 1


	func on_shown() -> void:
		shown_count += 1


	func on_hide() -> void:
		hidden_count += 1


func _initialize() -> void:
	var host := Control.new()
	root.add_child(host)
	var gui_root := FGUIRoot.new()
	gui_root.set_size(400, 300)
	host.add_child(gui_root.node)

	var window := ProbeWindow.new()
	var content := FGUIComponent.new()
	content.set_size(120, 80)
	window.set_content_pane(content)
	window.show()
	if window.parent != gui_root or not window.shown or window.init_count != 1 or window.shown_count != 1:
		_fail("Window show did not attach through GRoot and initialize once.")
		return
	if gui_root.focus != window:
		_fail("GRoot show_window did not focus the opened window.")
		return
	if window.width != 120 or window.height != 80:
		_fail("Window content pane did not define window size.")
		return
	window.show()
	if window.init_count != 1 or window.shown_count != 1:
		_fail("Showing an already visible window repeated its lifecycle callbacks.")
		return

	var second_window := ProbeWindow.new()
	second_window.show_on(gui_root)
	window.bring_to_front()
	if not window.is_top:
		_fail("Window bring_to_front did not reorder the root display list.")
		return
	window.modal = true
	if gui_root._modal_layer == null or gui_root._modal_layer.parent != gui_root or not window.is_top:
		_fail("Modal windows did not create and prioritize a root modal layer.")
		return
	if gui_root.get_child_index(gui_root._modal_layer) != gui_root.get_child_index(window) - 1 or gui_root._modal_layer.node.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("Root modal layer was not placed directly below the modal window.")
		return
	window.center_on(gui_root)
	if absf(window.x - 140.0) > 0.1 or absf(window.y - 110.0) > 0.1:
		_fail("Window center_on did not use root dimensions.")
		return

	var wait_pane := FGUIComponent.new()
	window._modal_wait_pane = wait_pane
	window.show_modal_wait(7)
	if not window.modal_waiting or window.close_modal_wait(8):
		_fail("Window modal wait request filtering is incorrect.")
		return
	if not window.close_modal_wait(7) or window.modal_waiting:
		_fail("Window modal wait pane did not close for its owning request.")
		return

	var close_button := FGUIObject.new()
	window.close_button = close_button
	close_button.emit_event("click")
	if window.parent != null or window.shown or window.hidden_count != 1 or gui_root._modal_layer.parent != null:
		_fail("Window close button did not hide and detach the window.")
		return
	window.show()
	if window.init_count != 1 or window.shown_count != 2:
		_fail("Window reopen did not preserve initialization state.")
		return

	var global_wait := FGUIComponent.new()
	gui_root._modal_wait_pane = global_wait
	gui_root.show_modal_wait("Loading")
	if not gui_root.modal_waiting or global_wait.parent != gui_root or gui_root.get_child_at(gui_root.num_children - 1) != global_wait:
		_fail("GRoot global modal wait did not attach above modal windows.")
		return
	gui_root.show_window(second_window)
	if gui_root.get_child_at(gui_root.num_children - 1) != global_wait:
		_fail("GRoot global modal wait did not remain above subsequently shown windows.")
		return
	gui_root.close_modal_wait()
	if gui_root.modal_waiting or global_wait.parent != null:
		_fail("GRoot close_modal_wait did not detach the wait pane.")
		return
	gui_root.close_all_except_modals()
	if second_window.parent != null or window.parent != gui_root or gui_root.get_top_window() != window:
		_fail("GRoot close_all_except_modals did not retain only modal windows.")
		return
	gui_root.close_all_windows()
	if window.parent != null or gui_root.get_top_window() != null or gui_root.has_modal_window:
		_fail("GRoot close_all_windows did not clear root windows and modal state.")
		return

	var clamped_window := ProbeWindow.new()
	clamped_window.set_size(60.0, 40.0)
	clamped_window.set_xy(500.0, 500.0)
	clamped_window.show_on(gui_root)
	if absf(clamped_window.x - 340.0) > 0.1 or absf(clamped_window.y - 260.0) > 0.1:
		_fail("GRoot show_window did not constrain an off-screen window.")
		return
	clamped_window.hide_immediately()
	if clamped_window.parent != null:
		_fail("Window hide_immediately did not detach from GRoot.")
		return

	window.dispose()
	second_window.dispose()
	clamped_window.dispose()
	global_wait.dispose()
	close_button.dispose()
	gui_root.dispose()
	host.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
