extends SceneTree
## Automated walkability test for the Milestone 2 train.
##
## Walks the real player through the real train with simulated input (the
## player is steered toward waypoints and holds "move_forward"), so it proves
## the collision layout is navigable, not just that nodes exist.
##   Godot_console.exe --headless --path . --script res://tests/test_train.gd

const SCENE_PATH := "res://scenes/main/game.tscn"
const FLOOR_Y := 1.2          # train floor height (train local space)
const WALL_LIMIT := 1.4 - 0.35 + 0.02  # interior half width − capsule radius + tolerance

var _player: PlayerController
var _train: Node3D
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load(SCENE_PATH).instantiate()
	root.add_child(scene)
	_player = scene.get_node("Player")
	_train = scene.get_node("Train")
	await _wait(0.6)

	await _test_spawn()
	await _test_walk_whole_train()
	# Game starts at Mile 214 Siding: right door → 0.35 m platform, left door → ground.
	await _test_side_door(1.0, "right", 0.35)
	await _test_side_door(-1.0, "left", 0.0)
	await _test_walls_block()
	await _test_window_not_an_exit()

	print("")
	if _failures == 0:
		print("ALL TRAIN TESTS PASSED")
	else:
		print("%d TRAIN TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# --- Tests -------------------------------------------------------------------

func _test_spawn() -> void:
	var p := _local()
	_check("spawns on the train floor", _player.is_on_floor() and absf(p.y - FLOOR_Y) < 0.03, "local=%s" % p)


func _test_walk_whole_train() -> void:
	await _place(Vector3(0, FLOOR_Y, 0.3))
	var route := [
		["living → storage doorway", Vector3(0, 0, 2.6)],
		["through storage doorway", Vector3(0, 0, 4.0)],
		["storage rear", Vector3(0, 0, 7.6)],
		["back through storage doorway", Vector3(0, 0, 2.6)],
		["living → entrance", Vector3(0, 0, -4.3)],
		["entrance → cabin doorway", Vector3(0.4, 0, -5.0)],
		["through cabin doorway", Vector3(0.4, 0, -6.2)],
		["stand at the controls", Vector3(0.4, 0, -7.9)],
	]
	for leg in route:
		var reached := await _walk_to(leg[1], 6.0)
		var p := _local()
		_check(leg[0], reached and absf(p.y - FLOOR_Y) < 0.05, "local=(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])


func _test_side_door(side: float, label: String, outside_height: float) -> void:
	await _place(Vector3(0, FLOOR_Y, -4.3))
	var out := await _walk_to(Vector3(side * 4.2, 0, -4.3), 5.0)
	await _wait(0.3)
	var p := _local()
	_check("exit %s door down the steps" % label, out and absf(p.y - outside_height) < 0.03 and _player.is_on_floor(),
			"local=(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])
	var back := await _walk_to(Vector3(0, 0, -4.3), 5.0)
	p = _local()
	_check("re-enter %s door up the steps" % label, back and absf(p.y - FLOOR_Y) < 0.05,
			"local=(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])


func _test_walls_block() -> void:
	for side in [1.0, -1.0]:
		await _place(Vector3(0, FLOOR_Y, -0.2))
		await _walk_to(Vector3(side * 3.0, 0, -0.2), 1.5)
		var p := _local()
		_check("%s wall blocks" % ("right" if side > 0 else "left"),
				absf(p.x) <= WALL_LIMIT and absf(p.y - FLOOR_Y) < 0.05, "local x=%.3f" % p.x)


func _test_window_not_an_exit() -> void:
	await _place(Vector3(-0.3, FLOOR_Y, 0.6))
	_face(Vector3(-3.0, 0, 0.6))
	Input.action_press("move_forward")
	for i in int(2.0 * Engine.physics_ticks_per_second):
		if i % 30 == 0:
			Input.action_press("jump")
		elif i % 30 == 1:
			Input.action_release("jump")
		await physics_frame
	await _release_all()
	await _wait(1.0)
	var p := _local()
	_check("can't jump out through a window", absf(p.x) <= WALL_LIMIT and absf(p.y - FLOOR_Y) < 0.05,
			"local=(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])


# --- Helpers -----------------------------------------------------------------

## Player position in train-local space.
func _local() -> Vector3:
	return _train.to_local(_player.global_position)


func _place(local_pos: Vector3) -> void:
	await _release_all()
	_player.teleport(Transform3D(Basis(), _train.to_global(local_pos)))
	await _wait(0.4)


func _face(local_target: Vector3) -> void:
	var to := _train.to_global(local_target) - _player.global_position
	_player.rotation.y = atan2(-to.x, -to.z)


## Steers toward a train-local XZ point while holding forward. Returns true if reached.
func _walk_to(local_target: Vector3, timeout: float) -> bool:
	Input.action_press("move_forward")
	var reached := false
	for i in int(timeout * Engine.physics_ticks_per_second):
		_player.input_enabled = true
		var p := _local()
		if Vector2(p.x - local_target.x, p.z - local_target.z).length() < 0.2:
			reached = true
			break
		_face(Vector3(local_target.x, p.y, local_target.z))
		await physics_frame
	await _release_all()
	await _wait(0.2)
	return reached


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump"]:
		Input.action_release(action)
	await physics_frame


func _wait(seconds: float) -> void:
	for i in int(seconds * Engine.physics_ticks_per_second):
		await physics_frame


func _check(test_name: String, passed: bool, detail: String) -> void:
	if passed:
		print("  PASS  %s   %s" % [test_name, detail])
	else:
		_failures += 1
		print("  FAIL  %s   %s" % [test_name, detail])
