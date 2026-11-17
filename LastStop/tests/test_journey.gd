extends SceneTree
## Automated journey test for Milestone 3: departure rules, doors, travel and
## arrival between stations, using the real game scene and simulated input.
## Since Milestone 5 departure goes through the real interaction ray: the
## player looks at the departure lever and presses E.
##   Godot_console.exe --headless --path . --script res://tests/test_journey.gd
## Speeds and distances are raised/shortened so a round trip takes seconds.

const SCENE_PATH := "res://scenes/main/game.tscn"
const FLOOR_Y := 1.2
const Mode := TrainController.State

var _scene: Node
var _player: PlayerController
var _train: TrainController
var _stations: StationManager
var _ray: InteractionRay
var _scenery: TravelScenery
var _failures: int = 0
var _states_seen: Array[int] = []
var _refusals: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_scene = load(SCENE_PATH).instantiate()
	root.add_child(_scene)
	_player = _scene.get_node("Player")
	_train = _scene.get_node("Train")
	_stations = _scene.get_node("StationManager")
	_ray = _scene.get_node("Player/Head/Camera3D/InteractionRay")
	_scenery = _scene.get_node("TravelScenery")

	# Fast-forward settings for testing.
	_train.acceleration = 6.0
	_train.braking = 6.0
	_stations.route.travel_seconds = 1.0
	_stations.despawn_distance = 60.0

	_train.state_changed.connect(func(s: TrainController.State) -> void: _states_seen.append(s))
	_train.departure_refused.connect(func(r: String) -> void: _refusals.append(r))
	await _wait(0.5)

	await _test_starts_parked()
	await _test_refuses_when_not_aboard()
	await _test_journey(&"grey_hollow")
	await _test_exit_at_new_station()
	await _test_journey(&"mile_214_siding")

	print("")
	if _failures == 0:
		print("ALL JOURNEY TESTS PASSED")
	else:
		print("%d JOURNEY TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# --- Tests -------------------------------------------------------------------

func _test_starts_parked() -> void:
	_check("starts parked at Mile 214 Siding",
			_train.state == Mode.PARKED and _stations.current_station.id == &"mile_214_siding", "")
	_check("doors start open", _train.doors_open, "")
	_check("train stop aligned with train", _stop_error() < 0.01, "error=%.4f m" % _stop_error())


func _test_refuses_when_not_aboard() -> void:
	await _place(Vector3(4.2, 0.4, 0.0))  # on the platform
	_refusals.clear()
	var ok := _train.request_departure()
	_check("refuses departure when player is outside", not ok and _train.state == Mode.PARKED \
			and _refusals.size() == 1 and "aboard" in _refusals[0], "refusals=%s" % [_refusals])


func _test_journey(expected_id: StringName) -> void:
	var label := String(expected_id)
	await _place(Vector3(0.4, FLOOR_Y, -7.9))  # at the controls
	await _aim_at_lever()
	_check("[%s] looking at the departure lever focuses it" % label, _ray.target == _train.departure_control,
			"target=%s" % [_ray.target])
	_states_seen.clear()

	# Press E for one physics frame, exactly like a player would.
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	_check("[%s] E at the controls departs" % label, _train.state == Mode.DEPARTING, "state=%d" % _train.state)

	await _wait(_train.door_duration + 0.2)
	_check("[%s] doors closed before moving" % label, not _train.doors_open, "")

	# Doors must block the exit while travelling.
	await _place(Vector3(0, FLOOR_Y, -4.3))
	await _walk_toward(Vector3(4.2, 0, -4.3), 1.5)
	var p := _local()
	_check("[%s] closed door blocks the exit" % label, p.x < 1.3 and absf(p.y - FLOOR_Y) < 0.05, "local x=%.2f" % p.x)
	await _place(Vector3(0, FLOOR_Y, 0.3))

	# Ride to the next station, watching the player's footing the whole way.
	var min_y := INF
	var max_y := -INF
	var max_speed := 0.0
	var max_props := 0
	var arrived := false
	for i in int(60.0 * Engine.physics_ticks_per_second):
		await physics_frame
		var y := _local().y
		min_y = minf(min_y, y)
		max_y = maxf(max_y, y)
		max_speed = maxf(max_speed, _train.speed)
		max_props = maxi(max_props, _scenery.get_child_count() - 1)
		if _train.state == Mode.PARKED:
			arrived = true
			break
	_check("[%s] arrives" % label, arrived, "")
	_check("[%s] state sequence" % label,
			_states_seen == [Mode.DEPARTING, Mode.TRAVELLING, Mode.ARRIVING, Mode.PARKED], "seen=%s" % [_states_seen])
	_check("[%s] reaches cruise speed" % label, is_equal_approx(max_speed, _train.cruise_speed), "max=%.2f m/s" % max_speed)
	_check("[%s] player stays on the floor while riding" % label,
			absf(min_y - FLOOR_Y) < 0.02 and absf(max_y - FLOOR_Y) < 0.02, "y range=%.3f…%.3f" % [min_y, max_y])
	_check("[%s] scenery streams past" % label, max_props > 0, "max props=%d" % max_props)
	_check("[%s] arrived at the right station" % label, _stations.current_station.id == expected_id,
			"current=%s" % _stations.current_station.id)
	_check("[%s] stops exactly on the train stop" % label, _stop_error() < 0.01, "error=%.4f m" % _stop_error())
	await _wait(0.1)
	_check("[%s] previous station unloaded" % label, _scene.get_node("StationRoot").get_child_count() == 1,
			"stations loaded=%d" % _scene.get_node("StationRoot").get_child_count())
	await _wait(_train.door_duration + 0.2)
	_check("[%s] doors open on arrival" % label, _train.doors_open, "")


func _test_exit_at_new_station() -> void:
	await _place(Vector3(0, FLOOR_Y, -4.3))
	var out := await _walk_toward(Vector3(4.2, 0, -4.3), 5.0)
	await _wait(0.3)
	var p := _local()
	_check("step off onto Grey Hollow's platform", out and absf(p.y - 0.35) < 0.03 and _player.is_on_floor(),
			"local=(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])


# --- Helpers -----------------------------------------------------------------

func _aim_at_lever() -> void:
	var hotspot := _train.departure_control.get_parent() as Node3D
	var head := _player.get_node("Head") as Node3D
	var to := hotspot.global_position - head.global_position
	_player.rotation.y = atan2(-to.x, -to.z)
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await physics_frame
	await physics_frame


func _stop_error() -> float:
	var station := _stations.get_current_scene()
	if station == null:
		return INF
	return (station.get_node("TrainStop") as Node3D).global_position.distance_to(_train.global_position)


func _local() -> Vector3:
	return _train.to_local(_player.global_position)


func _place(local_pos: Vector3) -> void:
	await _release_all()
	_player.teleport(Transform3D(Basis(), _train.to_global(local_pos)))
	await _wait(0.4)


## Steers toward a train-local XZ point while holding forward. True if reached.
func _walk_toward(local_target: Vector3, timeout: float) -> bool:
	Input.action_press("move_forward")
	var reached := false
	for i in int(timeout * Engine.physics_ticks_per_second):
		_player.input_enabled = true
		var p := _local()
		if Vector2(p.x - local_target.x, p.z - local_target.z).length() < 0.2:
			reached = true
			break
		var to := _train.to_global(Vector3(local_target.x, p.y, local_target.z)) - _player.global_position
		_player.rotation.y = atan2(-to.x, -to.z)
		await physics_frame
	await _release_all()
	return reached


func _release_all() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right", "sprint", "jump", "interact"]:
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
