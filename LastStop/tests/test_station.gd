extends SceneTree
## Automated test for Milestone 4: the Grey Hollow station.
##   Godot_console.exe --headless --path . --script res://tests/test_station.gd
##
## 1. Walks the real player (simulated input, real collisions) from the train
##    through every building and back aboard.
## 2. Bakes a navigation mesh from the station's colliders and proves every
##    loot container can be reached on foot from the train door.
## 3. Checks the canopy-roof climb, the invisible boundaries, and that the
##    boundaries are disabled while the station is moving.

const SCENE_PATH := "res://scenes/main/game.tscn"
const P := 0.35  # plinth / platform height
const FLOOR_Y := 1.2

var _player: PlayerController
var _train: TrainController
var _stations: StationManager
var _station: Station
var _failures: int = 0
var _walked: float = 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node = load(SCENE_PATH).instantiate()
	# Start the route at Grey Hollow instead of Mile 214.
	var stations: StationManager = scene.get_node("StationManager")
	var route: RouteData = stations.route.duplicate()
	route.stations = [stations.route.stations[1], stations.route.stations[0]]
	stations.route = route
	root.add_child(scene)
	_player = scene.get_node("Player")
	_train = scene.get_node("Train")
	_stations = stations
	await _wait(0.6)
	_station = _stations.get_current_scene()

	_check("parked at Grey Hollow", _stations.current_station.id == &"grey_hollow" and _station != null, "")
	await _test_exploration_tour()
	await _test_canopy_climb()
	await _test_bounds()
	await _test_loot_reachable()
	await _test_bounds_disabled_while_moving()

	print("")
	if _failures == 0:
		print("ALL STATION TESTS PASSED")
	else:
		print("%d STATION TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# --- Tests -------------------------------------------------------------------

func _test_exploration_tour() -> void:
	await _place(Vector3(0, FLOOR_Y, -4.3))
	_walked = 0.0
	var route := [
		["leave the train onto the platform", Vector3(3.6, 0, -4.3), P],
		["cross the platform", Vector3(6.0, 0, -7.0), P],
		["approach the waiting hall", Vector3(8.3, 0, -9.0), P],
		["enter the waiting hall", Vector3(10.0, 0, -9.0), P],
		["cross the hall", Vector3(13.0, 0, -9.0), P],
		["reach the counter door", Vector3(16.0, 0, -5.2), P],
		["enter the ticket office", Vector3(16.0, 0, -3.0), P],
		["search the office", Vector3(14.5, 0, -0.3), P],
		["back to the counter door", Vector3(16.0, 0, -3.0), P],
		["back into the hall", Vector3(16.0, 0, -5.2), P],
		["to the hall's rear door", Vector3(15.5, 0, -9.0), P],
		["out into the back yard", Vector3(18.2, 0, -9.0), P],
		["approach the warehouse gateway", Vector3(20.5, 0, -14.0), P],
		["enter the warehouse", Vector3(23.8, 0, -14.0), P],
		["to the storeroom door", Vector3(25.0, 0, -16.8), P],
		["enter the warehouse storeroom", Vector3(25.0, 0, -19.6), P],
		["back through the storeroom door", Vector3(25.0, 0, -16.8), P],
		["to the warehouse north door", Vector3(25.0, 0, -7.2), P],
		["out into the yard", Vector3(25.0, 0, -4.8), P],
		["cross the yard to the shop", Vector3(18.2, 0, 11.0), P],
		["enter the shop storeroom", Vector3(15.5, 0, 11.0), P],
		["into the shop", Vector3(12.5, 0, 11.0), P],
		["to the shop entrance", Vector3(10.3, 0, 9.0), P],
		["out onto the platform", Vector3(7.6, 0, 9.0), P],
		["to the alley", Vector3(8.3, 0, 5.2), P],
		["through the alley", Vector3(17.5, 0, 5.2), P],
		["along the yard", Vector3(17.8, 0, 15.5), P],
		["approach the signal box", Vector3(13.0, 0, 16.2), P],
		["enter the signal box ruin", Vector3(13.0, 0, 19.0), P],
		["leave the ruin", Vector3(13.0, 0, 16.2), P],
		["back along the yard", Vector3(17.8, 0, 15.5), P],
		["back through the alley", Vector3(17.5, 0, 5.2), P],
		["out of the alley", Vector3(8.3, 0, 5.2), P],
		["back across the platform", Vector3(6.0, 0, 5.2), P],
		["to the train door", Vector3(3.6, 0, -4.3), P],
		["climb back aboard", Vector3(0.0, 0, -4.3), FLOOR_Y],
	]
	var all_ok := true
	for leg in route:
		var reached := await _walk_to(leg[1], 12.0)
		var p := _local()
		var ok: bool = reached and absf(p.y - leg[2]) < 0.06
		all_ok = all_ok and ok
		_check(leg[0], ok, "at (%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])
		if not ok:
			# Put the player where they should be so one failure doesn't cascade.
			await _place(Vector3(leg[1].x, leg[2], leg[1].z))
	_check("back aboard after the tour", _train.is_player_aboard(), "")
	print("        tour length %.0f m  ≈ %.0f s of pure walking at 4 m/s" % [_walked, _walked / 4.0])


func _test_canopy_climb() -> void:
	await _place(Vector3(4.0, P, 16.5))
	await _walk_to(Vector3(4.2, 0, 14.6), 4.0)
	# The slab meets the flat canopy roof at z = 6; stop just past it.
	var up := await _walk_to(Vector3(4.2, 0, 5.4), 6.0)
	var p := _local()
	_check("climb the collapsed canopy", up and absf(p.y - (P + 3.45)) < 0.08, "at (%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])
	var along := await _walk_to(Vector3(5.0, 0, -8.6), 8.0)
	p = _local()
	_check("walk along the canopy roof to the hidden crate", along and absf(p.y - (P + 3.45)) < 0.08,
			"at (%.2f, %.2f, %.2f)" % [p.x, p.y, p.z])


func _test_bounds() -> void:
	var cases := [
		["east boundary holds", Vector3(46.0, 0.0, 0.0), Vector3(70.0, 0, 0.0), func(p: Vector3) -> bool: return p.x < 52.0],
		["west boundary holds", Vector3(-14.0, 0.0, 10.0), Vector3(-40.0, 0, 10.0), func(p: Vector3) -> bool: return p.x > -20.0],
		["boundary across the track holds", Vector3(0.0, 0.0, -48.0), Vector3(0.0, 0, -80.0), func(p: Vector3) -> bool: return p.z > -55.0],
	]
	for c in cases:
		await _place(c[1])
		await _walk_to(c[2], 3.0, true)
		var p := _local()
		_check(c[0], c[3].call(p), "stopped at (%.1f, %.1f)" % [p.x, p.z])


func _test_loot_reachable() -> void:
	var containers: Array = get_nodes_in_group("loot_container").filter(func(n: Node) -> bool: return _station.is_ancestor_of(n))
	_check("enough loot containers placed", containers.size() >= 18, "%d containers" % containers.size())

	# Bake a navmesh from the station's static colliders, matching the player's
	# capsule (radius 0.35, height 1.8) and its inability to step up ledges.
	var map := root.get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.1)
	NavigationServer3D.map_set_cell_height(map, 0.05)
	var nm := NavigationMesh.new()
	nm.cell_size = 0.1
	nm.cell_height = 0.05
	nm.agent_radius = 0.4  # player capsule is 0.35; rounded up to the 0.1 m cell grid
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.1
	nm.agent_max_slope = 40.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, source, _station)
	NavigationServer3D.bake_from_source_geometry_data(nm, source)
	var region := NavigationRegion3D.new()
	region.navigation_mesh = nm
	_station.add_child(region)
	await _wait(0.2)
	_check("navmesh baked", nm.get_polygon_count() > 0, "%d polygons" % nm.get_polygon_count())

	var start := NavigationServer3D.map_get_closest_point(map, _station.to_global(Vector3(3.4, P, -4.3)))
	var unreachable: PackedStringArray = []
	var total_path := 0.0
	for c in containers:
		var result := _path_to_container(map, start, c)
		if result < 0.0:
			unreachable.append(String(c.name))
		else:
			total_path += result
	_check("every loot container reachable on foot from the train", unreachable.is_empty(),
			"unreachable: %s" % ", ".join(unreachable) if not unreachable.is_empty() else "%d/%d reachable" % [containers.size(), containers.size()])
	print("        mean walking distance train → container %.0f m" % (total_path / maxf(containers.size(), 1)))
	region.queue_free()


func _test_bounds_disabled_while_moving() -> void:
	var bounds := _station.get_node("Bounds")
	_check("bounds active while parked", bounds.can_process(), "")
	await _place(Vector3(0.4, FLOOR_Y, -7.9))
	_train.request_departure()
	await _wait(0.2)
	_check("bounds disabled once departing", not bounds.can_process(), "")


# --- Helpers -----------------------------------------------------------------

## Returns the path length to a spot beside the container, or -1 if none.
func _path_to_container(map: RID, start: Vector3, container: Node3D) -> float:
	var aabb := _world_aabb(container)
	var reach := maxf(aabb.size.x, aabb.size.z) / 2.0 + 0.75
	# Items on counters or stacked on crates are reached from the floor below.
	var floor_y := _station.to_global(Vector3(0, P, 0)).y
	var stand_y := floor_y if container.global_position.y - floor_y < 1.2 else container.global_position.y
	var best := -1.0
	for i in 16:
		var a := TAU * i / 16.0
		var probe := Vector3(aabb.get_center().x + cos(a) * reach, stand_y, aabb.get_center().z + sin(a) * reach)
		var spot := NavigationServer3D.map_get_closest_point(map, probe)
		if Vector2(spot.x - probe.x, spot.z - probe.z).length() > 0.45 or absf(spot.y - probe.y) > 0.3:
			continue
		var path := NavigationServer3D.map_get_path(map, start, spot, true)
		if path.is_empty() or path[path.size() - 1].distance_to(spot) > 0.3:
			continue
		var length := 0.0
		for j in range(1, path.size()):
			length += path[j - 1].distance_to(path[j])
		if best < 0.0 or length < best:
			best = length
	return best


func _world_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _local() -> Vector3:
	return _station.to_local(_player.global_position)


func _place(local_pos: Vector3) -> void:
	await _release_all()
	_player.teleport(Transform3D(Basis(), _station.to_global(local_pos)))
	await _wait(0.4)


## Steers toward a station-local XZ point holding forward (optionally sprinting).
func _walk_to(local_target: Vector3, timeout: float, sprint: bool = false) -> bool:
	Input.action_press("move_forward")
	if sprint:
		Input.action_press("sprint")
	var reached := false
	var last := _player.global_position
	for i in int(timeout * Engine.physics_ticks_per_second):
		_player.input_enabled = true
		var p := _local()
		if Vector2(p.x - local_target.x, p.z - local_target.z).length() < 0.25:
			reached = true
			break
		var to := _station.to_global(Vector3(local_target.x, p.y, local_target.z)) - _player.global_position
		_player.rotation.y = atan2(-to.x, -to.z)
		await physics_frame
		_walked += Vector2(_player.global_position.x - last.x, _player.global_position.z - last.z).length()
		last = _player.global_position
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
