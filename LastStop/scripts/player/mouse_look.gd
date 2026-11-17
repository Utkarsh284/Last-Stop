class_name MouseLook
extends Node3D
## First-person mouse look. Attach to the player's Head node.
##
## Horizontal motion yaws [member body] (so movement follows the view);
## vertical motion pitches this node (so the body stays upright).
## Only reacts while the mouse is captured, so menus can free the cursor
## without the view spinning.

## Degrees of rotation per pixel of mouse movement.
@export_range(0.01, 1.0, 0.01) var sensitivity: float = 0.12
## Flip vertical look.
@export var invert_y: bool = false
## Maximum look angle up or down, in degrees.
@export_range(10.0, 89.0) var max_pitch_degrees: float = 85.0
## Node that turns left/right. Defaults to the parent (the player body).
@export var body: Node3D

## When false, mouse motion is ignored even if the cursor is captured.
var enabled: bool = true


func _ready() -> void:
	if body == null:
		body = get_parent() as Node3D
	assert(body != null, "MouseLook needs a Node3D body to yaw.")


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := event as InputEventMouseMotion
	if motion:
		# screen_relative ignores the viewport stretch, so sensitivity is resolution-independent.
		apply_look(motion.screen_relative)


## Rotates the view by a mouse delta in pixels. Public so tests and
## gamepad/other look sources can drive the camera too.
func apply_look(pixel_delta: Vector2) -> void:
	var y_sign := -1.0 if invert_y else 1.0
	body.rotate_y(deg_to_rad(-pixel_delta.x * sensitivity))
	var max_pitch := deg_to_rad(max_pitch_degrees)
	rotation.x = clampf(rotation.x - deg_to_rad(pixel_delta.y * sensitivity * y_sign), -max_pitch, max_pitch)


## Current pitch in degrees (positive = looking up).
func get_pitch_degrees() -> float:
	return rad_to_deg(rotation.x)
