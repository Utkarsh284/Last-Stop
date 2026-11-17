extends SceneTree
## Automated movement test for Milestone 1.
##
## Loads the real sandbox scene, drives the player with simulated input
## actions and checks positions/velocities. Run from the project folder:
##   Godot_console.exe --headless --path . --script res://tests/test_player_movement.gd
## Exit code 0 = all passed, 1 = failures.

const SCENE_PATH := "res://scenes/main/movement_sandbox.tscn"

var _player: PlayerController
var _look: MouseLook
var _failures: int = 0
var _landed_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load(SCENE_PATH).instantiate()
	root.add_child(scene)
	_player = scene.get_node("Player")
	_look = _player.get_node("Head")
	_player.landed.connect(func(_speed: float) -> void: _landed_count += 1)

	await _test_settles_on_floor()
	await _test_walk_speed()
	await _test_sprint_speed()
	await _test_stops_when_released()
	await _test_jump_height_and_landing()
	await _test_sprint_gate()
	await _test_input_disabled()
	await _test_mouse_look_turns_movement()
	await _test_pitch_clamp()
	await _test_wall_blocks()
	await _test_ramp_climb()
	await _test_stairs_climb()
	await _test_jump_onto_crate()

	print("")
	if _failures == 0:
		print("ALL MOVEMENT TESTS PASSED")
	else:
		print("%d MOVEMENT TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# --- Tests -------------------------------------------------------------------

func _test_settles_on_floor() -> void:
	await _spawn(Vector3(0, 0.5, 8), 0.0)
	_check("settles on floor", _player.is_on_floor() and absf(_player.global_position.y) < 0.05,
			"y=%.3f on_floor=%s" % [_player.global_position.y, _player.is_on_floor()])


func _test_walk_speed() -> void:
	await _spawn(Vector3(0, 0, 8), 0.0)
	var start := _player.global_position
	await _hold(["move_forward"], 0.6)
	var speed := _player.get_horizontal_speed()
	_check("walk reaches walk_speed", is_equal_approx(snappedf(speed, 0.01), _player.walk_speed),
			"speed=%.2f" % speed)
	_check("forward moves toward -Z", _player.global_position.z < start.z - 1.5,
			"dz=%.2f" % (_player.global_position.z - start.z))
	await _release_all()


func _test_sprint_speed() -> void:
	await _spawn(Vector3(0, 0, 8), 0.0)
	await _hold(["move_forward", "sprint"], 0.6)
	var speed := _player.get_horizontal_speed()
	_check("sprint reaches sprint_speed", is_equal_approx(snappedf(speed, 0.01), _player.sprint_speed),
			"speed=%.2f sprinting=%s" % [speed, _player.is_sprinting])
	await _release_all()


func _test_stops_when_released() -> void:
	await _spawn(Vector3(0, 0, 8), 0.0)
	await _hold(["move_forward", "sprint"], 0.5)
	await _release_all()
	await _wait(0.25)
	_check("stops within 0.25 s of release", _player.get_horizontal_speed() < 0.01,
			"speed=%.2f" % _player.get_horizontal_speed())
	_check("sprint flag clears", not _player.is_sprinting, "")


func _test_jump_height_and_landing() -> void:
	await _spawn(Vector3(0, 0, 8), 0.0)
	_landed_count = 0
	var base_y := _player.global_position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var peak := base_y
	for i in 120:
		await physics_frame
		peak = maxf(peak, _player.global_position.y)
	var height := peak - base_y
	_check("jump apex ≈ jump_height", absf(height - _player.jump_height) < 0.08, "apex=%.3f" % height)
	_check("lands after jump", _player.is_on_floor() and _landed_count >= 1, "landed=%d" % _landed_count)


func _test_sprint_gate() -> void:
	await _spawn(Vector3(0, 0, 8), 0.0)
	_player.can_sprint = false
	await _hold(["move_forward", "sprint"], 0.6)
	_check("can_sprint=false blocks sprint", not _player.is_sprinting \
			and _player.get_horizontal_speed() <= _player.walk_speed + 0.01,
			"speed=%.2f" % _player.get_horizontal_speed())
	_player.can_sprint = true
	await _release_all()


func _test_input_disabled() -> void:
	await _spawn(Vector3(0, 0, 8), 0.0)
	var start := _player.global_position
	_player.input_enabled = false
	await _hold(["move_forward", "jump"], 0.4, false)
	_check("input_enabled=false ignores input",
			_player.global_position.distance_to(start) < 0.01, "moved=%.3f" % _player.global_position.distance_to(start))
	_player.input_enabled = true
	await _release_all()


func _test_mouse_look_turns_movement() -> void:
	await _spawn(Vector3(0, 0, 8), 0.0)
	# 750 px × 0.12 °/px = 90° turn to the right.
	_look.apply_look(Vector2(750 * 0.12 / _look.sensitivity, 0))
	var yaw := rad_to_deg(_player.rotation.y)
	_check("mouse right yaws body −90°", absf(yaw + 90.0) < 0.1, "yaw=%.2f" % yaw)
	var start := _player.global_position
	await _hold(["move_forward"], 0.5)
	var moved := _player.global_position - start
	_check("forward follows view (+X)", moved.x > 1.0 and absf(moved.z) < 0.05,
			"moved=(%.2f, %.2f)" % [moved.x, moved.z])
	await _release_all()


func _test_pitch_clamp() -> void:
	await _spawn(Vector3(0, 0, 8), 0.0)
	_look.apply_look(Vector2(0, -100000))
	_check("pitch clamps looking up", is_equal_approx(snappedf(_look.get_pitch_degrees(), 0.01), _look.max_pitch_degrees),
			"pitch=%.2f" % _look.get_pitch_degrees())
	_look.apply_look(Vector2(0, 100000))
	_check("pitch clamps looking down", is_equal_approx(snappedf(_look.get_pitch_degrees(), 0.01), -_look.max_pitch_degrees),
			"pitch=%.2f" % _look.get_pitch_degrees())
	_check("pitch never tilts body", absf(_player.rotation.x) < 0.0001, "")


func _test_wall_blocks() -> void:
	await _spawn(Vector3(0, 0, -10), 0.0)
	await _hold(["move_forward", "sprint"], 2.0)
	# Wall front face is at z = -13.8; capsule radius 0.35.
	var z := _player.global_position.z
	_check("wall stops the player", z > -13.8 + 0.3 and z < -13.0, "z=%.3f" % z)
	await _release_all()


func _test_ramp_climb() -> void:
	# ~2.3 s at walk speed ends mid-platform (platform spans z −4.5 … −7.5).
	await _spawn(Vector3(6, 0, 2), 0.0)
	var peak := 0.0
	Input.action_press("move_forward")
	for i in int(2.3 * Engine.physics_ticks_per_second):
		await physics_frame
		peak = maxf(peak, _player.global_position.y)
	_check("no bump at ramp/platform seam", peak < 1.8 + 0.02, "peak=%.3f" % peak)
	var y := _player.global_position.y
	_check("walks up 20° ramp onto 1.8 m platform", absf(y - 1.8) < 0.05 and _player.is_on_floor(),
			"y=%.3f" % y)
	await _release_all()


func _test_stairs_climb() -> void:
	# ~1.7 s at walk speed ends mid-platform.
	await _spawn(Vector3(-6, 0, 0), 0.0)
	await _hold(["move_forward"], 1.7)
	var y := _player.global_position.y
	_check("walks up stairs onto 1.25 m platform", absf(y - 1.25) < 0.05 and _player.is_on_floor(),
			"y=%.3f" % y)
	await _release_all()


func _test_jump_onto_crate() -> void:
	await _spawn(Vector3(-2.6, 0, 3.6), 0.0)
	Input.action_press("move_forward")
	await _wait(0.3)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await _wait(0.35)
	Input.action_release("move_forward")
	await _wait(1.0)
	var y := _player.global_position.y
	_check("can jump onto 1 m crate", absf(y - 1.0) < 0.05 and _player.is_on_floor(), "y=%.3f" % y)
	await _release_all()


# --- Helpers -----------------------------------------------------------------

func _spawn(position: Vector3, yaw_degrees: float) -> void:
	await _release_all()
	_look.rotation = Vector3.ZERO
	_player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), position))
	await _wait(0.5)  # Long enough to fall 0.5 m (0.32 s) and settle.


func _hold(actions: Array, seconds: float, keep_input_enabled: bool = true) -> void:
	for action in actions:
		Input.action_press(action)
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		if keep_input_enabled:
			_player.input_enabled = true  # Sandbox may toggle this on focus changes.
		await physics_frame


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump"]:
		Input.action_release(action)
	await physics_frame


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _check(name: String, passed: bool, detail: String) -> void:
	if passed:
		print("  PASS  %s   %s" % [name, detail])
	else:
		_failures += 1
		print("  FAIL  %s   %s" % [name, detail])
