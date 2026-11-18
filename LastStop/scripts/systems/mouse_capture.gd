class_name MouseCapture
extends Node
## Owns cursor capture: Esc releases, left click recaptures, Alt-Tab releases.
## TEMPORARY until the pause menu (Milestone 11) takes over Esc.
## The owning scene calls [method set_captured] once it has connected signals.

signal captured_changed(captured: bool)

var captured: bool = false
## True while a full-screen UI (inventory) owns the cursor: Esc, clicks and
## focus changes are left to that UI instead of (re)capturing the mouse.
var ui_open: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if ui_open:
		return
	if event.is_action_pressed("pause"):
		set_captured(false)
	elif not captured and _is_left_click(event):
		set_captured(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and not ui_open:
		set_captured(false)


func set_captured(value: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE
	captured = value
	captured_changed.emit(value)


func _is_left_click(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	return button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT
