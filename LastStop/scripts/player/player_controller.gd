class_name PlayerController
extends CharacterBody3D
## First-person body movement: walk, sprint, jump and gravity.
##
## Camera rotation lives in [MouseLook] on the Head node; this script only
## moves the body. Other systems talk to it through [member can_sprint],
## [member input_enabled] and the signals below, never by reaching inside.
##
## Feel helpers: acceleration/deceleration instead of instant velocity,
## coyote time (jump shortly after walking off a ledge) and jump buffering
## (a jump pressed just before landing still fires).

## Emitted when the player starts or stops sprinting. A stamina system hooks in here.
signal sprint_state_changed(is_sprinting: bool)
## Emitted on the physics frame a jump starts.
signal jumped
## Emitted when touching the floor after being airborne. [param fall_speed] is positive, in m/s.
signal landed(fall_speed: float)

@export_group("Speed")
## Walking speed in m/s.
@export var walk_speed: float = 4.0
## Sprinting speed in m/s.
@export var sprint_speed: float = 6.8
## How fast the player reaches target speed on the ground (m/s²).
@export var ground_acceleration: float = 40.0
## How fast the player stops on the ground with no input (m/s²).
@export var ground_deceleration: float = 45.0
## Steering strength while airborne (m/s²). Low values commit the player to their jump.
@export var air_acceleration: float = 8.0

@export_group("Jump")
## Apex height of a jump in metres.
@export var jump_height: float = 1.1
## Seconds after leaving a ledge during which a jump is still allowed.
@export var coyote_time: float = 0.12
## Seconds a jump press is remembered before landing.
@export var jump_buffer_time: float = 0.12
## Scales project gravity for this body only.
@export var gravity_multiplier: float = 1.0

## External gate for sprinting (e.g. the stamina system sets this to false when exhausted).
var can_sprint: bool = true
## When false, movement input is ignored but gravity still applies (menus, cutscenes).
var input_enabled: bool = true
## True while actively sprinting. Read-only from outside; changes emit [signal sprint_state_changed].
var is_sprinting: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0


func _physics_process(delta: float) -> void:
	var input_dir := _read_move_input()
	var was_on_floor := is_on_floor()

	_apply_gravity(delta)
	_update_sprint(input_dir)
	_update_jump(delta)
	_apply_horizontal_movement(input_dir, delta)

	var fall_speed := -velocity.y
	move_and_slide()

	if not was_on_floor and is_on_floor():
		landed.emit(maxf(fall_speed, 0.0))


## Current horizontal speed in m/s (ignores vertical velocity).
func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Instantly moves the player to [param target] and clears all velocity.
## Use for spawning, scene transitions and respawns.
func teleport(target: Transform3D) -> void:
	global_transform = target
	velocity = Vector3.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


func _read_move_input() -> Vector2:
	if not input_enabled:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta
		velocity.y -= _gravity * gravity_multiplier * delta


func _update_sprint(input_dir: Vector2) -> void:
	# Sprint only while moving forward; strafing or backpedalling at sprint speed feels wrong.
	var wants_sprint := input_enabled and can_sprint \
			and Input.is_action_pressed("sprint") and input_dir.y < -0.1
	if wants_sprint != is_sprinting:
		is_sprinting = wants_sprint
		sprint_state_changed.emit(is_sprinting)


func _update_jump(delta: float) -> void:
	if input_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = sqrt(2.0 * _gravity * gravity_multiplier * jump_height)
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		jumped.emit()


func _apply_horizontal_movement(input_dir: Vector2, delta: float) -> void:
	# Body only rotates around Y, so its basis maps input straight onto the ground plane.
	var wish_dir := transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	var speed := sprint_speed if is_sprinting else walk_speed
	var target := Vector2(wish_dir.x, wish_dir.z) * speed

	var rate: float
	if not is_on_floor():
		rate = air_acceleration
	elif input_dir.is_zero_approx():
		rate = ground_deceleration
	else:
		rate = ground_acceleration

	var horizontal := Vector2(velocity.x, velocity.z).move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.y
