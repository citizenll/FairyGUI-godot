@tool
extends EditorDebuggerPlugin

const DebuggerPanel := preload("res://addons/fairygui/editor/fairygui_debugger_panel.gd")

var _panels: Dictionary = {}


func _setup_session(session_id: int) -> void:
	var session := get_session(session_id)
	if session == null:
		return
	var panel := DebuggerPanel.new()
	panel.refresh_requested.connect(_request_snapshot.bind(session_id))
	panel.object_selected.connect(_select_runtime_object.bind(session_id))
	session.add_session_tab(panel)
	session.started.connect(_on_session_started.bind(session_id))
	session.stopped.connect(_on_session_stopped.bind(session_id))
	_panels[session_id] = panel


func _has_capture(capture: String) -> bool:
	return capture == "fairygui"


func _capture(message: String, data: Array, session_id: int) -> bool:
	if message != "fairygui:tree" or not _panels.has(session_id):
		return false
	var snapshot: Dictionary = data[0] if not data.is_empty() and data[0] is Dictionary else {}
	(_panels[session_id] as Control).call("set_snapshot", snapshot)
	return true


func _on_session_started(session_id: int) -> void:
	if _panels.has(session_id):
		(_panels[session_id] as Control).call("set_running", true)
	call_deferred("_request_snapshot", session_id)


func _on_session_stopped(session_id: int) -> void:
	if _panels.has(session_id):
		(_panels[session_id] as Control).call("set_running", false)


func _request_snapshot(session_id: int) -> void:
	var session := get_session(session_id)
	if session != null and session.is_active():
		session.send_message("fairygui:request_tree", [])


func _select_runtime_object(object_id: int, session_id: int) -> void:
	var session := get_session(session_id)
	if session != null and session.is_active():
		session.send_message("fairygui:select", [object_id])
