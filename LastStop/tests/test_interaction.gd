extends SceneTree
## Automated test for Milestone 5: the interaction system.
##   Godot_console.exe --headless --path . --script res://tests/test_interaction.gd
##
## Uses the real game scene (starting at Grey Hollow), the real player camera,
## the real InteractionRay and simulated key presses.
## 1. Every loot container has a hold-to-search Interactable and can be
##    targeted from at least one spot where the player can actually stand.
## 2. Walls block the ray; targets beyond reach are ignored.
## 3. Prompt, crosshair and hold progress in the HUD follow the focus.
## 4. Hold-to-search: early release cancels, looking away cancels, a full hold
##    searches once, a searched container can't be searched again.
## 5. Releasing the mouse disables interaction.
## 6. The departure lever departs, then shows "Train in motion" and animates.

const SCENE_PATH := "res://scenes/main/game.tscn"
const P := 0.35  # Grey Hollow plinth height
const FLOOR_Y := 1.2
const EYE := 1.62
const EXPECTED_CONTAINERS := 22

var _scene: Node
var _player: PlayerController
var _head: Node3D
var _train: TrainController
var _stations: StationManager
var _station: Station
var _ray: InteractionRay
var _hud: HUD
var _capture: MouseCapture
var _failures: int = 0
var _interactions: Array[Interactable] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_scene = load(SCENE_PATH).instantiate()
	_stations = _scene.get_node("StationManager")
	var route: RouteData = _stations.route.duplicate()
	route.stations = [_stations.route.stations[1], _stations.route.stations[0]]
	_stations.route = route
	root.add_child(_scene)
	_player = _scene.get_node("Player")
	_head = _player.get_node("Head")
	_train = _scene.get_node("Train")
	_ray = _scene.get_node("Player/Head/Camera3D/InteractionRay")
	_hud = _scene.get_node("HUD")
	_capture = _scene.get_node("MouseCapture")
	_ray.interacted.connect(func(t: Interactable) -> void: _interactions.append(t))
	await _wait(0.6)
	_station = _stations.get_current_scene()
	_check("parked at Grey Hollow", _stations.current_station.id == &"grey_hollow", "")

	var containers := _containers()
	var standpoints := await _test_containers_targetable(containers)
	await _test_walls_and_reach()
	await _test_hold_search(containers, standpoints)
	await _test_mouse_release(containers, standpoints)
	await _test_departure_lever()

	print("")
	if _failures == 0:
		print("ALL INTERACTION TESTS PASSED")
	else:
		print("%d INTERACTION TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# --- Tests -------------------------------------------------------------------

## Returns { container: standpoint floor position } for every targetable container.
func _test_containers_targetable(containers: Array[Node3D]) -> Dictionary:
	_check("%d loot containers" % EXPECTED_CONTAINERS, containers.size() == EXPECTED_CONTAINERS,
			"found=%d" % containers.size())
	var bad_setup: Array[String] = []
	for c in containers:
		var it := Interactable.find_on(c)
		if it == null or not it.one_shot or it.hold_time <= 0.0 or it.action != "Search" or it.display_name.is_empty():
			bad_setup.append(String(c.name))
	_check("every container has a one-shot hold-to-search Interactable", bad_setup.is_empty(), "bad=%s" % [bad_setup])

	var found := {}
	var unreachable: Array[String] = []
	for c in containers:
		var spot: Variant = _find_standpoint(c)
		if spot == null:
			unreachable.append(String(c.get_parent().name) + "/" + String(c.name))
		else:
			found[c] = spot
	_check("every container can be targeted from a standing spot", unreachable.is_empty(),
			"%d/%d ok, failed=%s" % [found.size(), containers.size(), unreachable])
	return found


func _test_walls_and_reach() -> void:
	# The back-office safe stands against the ticket office's outer wall (x = 17).
	var safe := _station.get_node("TicketOffice/Safe") as Node3D
	var aim := _aim_point(safe)
	var outside := _station.to_global(Vector3(18.0, P + EYE, 1.5))
	_check("wall blocks the ray (safe from outside)", outside.distance_to(aim) < _ray.reach \
			and _ray.probe(outside, outside + (aim - outside).normalized() * _ray.reach) == null,
			"distance=%.2f m" % outside.distance_to(aim))

	# Platform suitcase from 3 m away in open air: out of reach.
	var suitcase := _station.get_node("Platform/Suitcase") as Node3D
	var s_aim := _aim_point(suitcase)
	var far := s_aim + Vector3(0, 0.6, 3.0)
	var hit_far := _ray.probe(far, far + (s_aim - far).normalized() * _ray.reach)
	var near := s_aim + Vector3(0, 0.6, 1.5)
	var hit_near := _ray.probe(near, near + (s_aim - near).normalized() * _ray.reach)
	_check("targets beyond reach are ignored", hit_far == null and hit_near == Interactable.find_on(suitcase),
			"far=%s near=%s" % [hit_far, hit_near])


func _test_hold_search(containers: Array[Node3D], standpoints: Dictionary) -> void:
	var crate := _pick(containers, standpoints, "Platform/Suitcase")
	if crate == null:
		_check("hold-search setup", false, "no standpoint for Platform/Suitcase")
		return
	var it := Interactable.find_on(crate)
	await _stand_and_look(standpoints[crate], _aim_point(crate))
	_check("looking at a container focuses it", _ray.target == it, "target=%s" % [_ray.target])
	_check("HUD prompt shows name, key and action", _hud.is_prompt_visible()
			and _label("TargetLabel").text == "SUITCASE" and _label("PromptLabel").text == "Search"
			and (_hud.get_node("%KeyChip") as Control).visible and (_hud.get_node("%HoldTrack") as Control).visible,
			"'%s' / '%s'" % [_label("TargetLabel").text, _label("PromptLabel").text])
	await _wait(0.2)
	var cross := _hud.get_node("%Crosshair") as Control
	_check("crosshair grows when focused", cross.scale.x > 1.5, "scale=%.2f" % cross.scale.x)

	# Early release cancels.
	Input.action_press("interact")
	await _wait(it.hold_time * 0.5)
	var mid := _ray.hold_progress
	var fill := (_hud.get_node("%HoldFill") as Control).anchor_right
	Input.action_release("interact")
	await _wait(0.05)
	_check("holding fills progress (ray + HUD)", mid > 0.3 and mid < 0.7 and absf(fill - mid) < 0.05,
			"ray=%.2f hud=%.2f" % [mid, fill])
	_check("early release cancels the search", not it.used and _ray.hold_progress == 0.0 and _interactions.is_empty(),
			"used=%s progress=%.2f" % [it.used, _ray.hold_progress])

	# Looking away mid-hold cancels.
	Input.action_press("interact")
	await _wait(it.hold_time * 0.5)
	_head.rotation.x = deg_to_rad(80)  # look at the sky
	await _wait(0.1)
	_check("looking away cancels the hold", _ray.target == null and _ray.hold_progress == 0.0 and not it.used, "")
	await _stand_and_look(standpoints[crate], _aim_point(crate))  # still holding E
	await _wait(it.hold_time + 0.2)
	_check("key held from before focusing doesn't auto-search", not it.used, "")
	Input.action_release("interact")
	await _wait(0.05)

	# Full hold searches exactly once.
	Input.action_press("interact")
	await _wait(it.hold_time + 0.15)
	_check("full hold searches the container", it.used and _interactions.size() == 1 and _interactions[0] == it,
			"interactions=%d" % _interactions.size())
	_check("HUD shows 'Searched' without a key", _label("PromptLabel").text == "Searched"
			and not (_hud.get_node("%KeyChip") as Control).visible, "'%s'" % _label("PromptLabel").text)
	_check("search feedback message shown", _label("MessageLabel").text == "Nothing useful here."
			and _label("MessageLabel").modulate.a > 0.5, "'%s'" % _label("MessageLabel").text)
	await _wait(it.hold_time + 0.2)
	Input.action_release("interact")
	await _wait(0.05)
	Input.action_press("interact")
	await _wait(it.hold_time + 0.2)
	Input.action_release("interact")
	_check("a searched container can't be searched again", _interactions.size() == 1 and _ray.target == it,
			"interactions=%d" % _interactions.size())

	_head.rotation.x = deg_to_rad(80)
	await _wait(0.25)
	_check("prompt hides when looking away", not _hud.is_prompt_visible() and cross.scale.x < 1.1,
			"scale=%.2f" % cross.scale.x)


func _test_mouse_release(containers: Array[Node3D], standpoints: Dictionary) -> void:
	var crate := _pick(containers, standpoints, "GoodsWarehouse/Crate2")
	if crate == null:
		_check("mouse-release setup", false, "no standpoint for GoodsWarehouse/Crate2")
		return
	var it := Interactable.find_on(crate)
	await _stand_and_look(standpoints[crate], _aim_point(crate))
	_check("[mouse] container focused while captured", _ray.target == it, "")
	_capture.set_captured(false)
	await physics_frame
	Input.action_press("interact")
	await _wait(it.hold_time + 0.2)
	Input.action_release("interact")
	_check("releasing the mouse disables interaction", _ray.target == null and not _hud.is_prompt_visible()
			and not it.used, "used=%s" % it.used)
	_capture.set_captured(true)
	await _wait(0.1)
	_check("recapturing restores focus", _ray.target == it, "")


func _test_departure_lever() -> void:
	var lever := _train.departure_control
	_check("lever action names the next station", lever.action == "Depart for Mile 214 Siding", "'%s'" % lever.action)
	# Lever from the cabin entrance (4 m away) is out of reach.
	await _place_in_train(Vector3(0.4, FLOOR_Y, -4.5))
	await _look_at((lever.get_parent() as Node3D).global_position)
	_check("lever out of reach from the vestibule", _ray.target == null, "")

	await _place_in_train(Vector3(0.4, FLOOR_Y, -7.9))
	await _look_at((lever.get_parent() as Node3D).global_position)
	_check("lever focused at the controls", _ray.target == lever and _label("TargetLabel").text == "DEPARTURE LEVER"
			and _label("PromptLabel").text == "Depart for Mile 214 Siding", "'%s'" % _label("PromptLabel").text)
	var rest_angle := (_train.get_node("Interior/ControlCabin/ControlConsole/Instruments/DepartureLever") as Node3D).rotation.x

	Input.action_press("interact")
	await _wait(0.1)
	Input.action_release("interact")
	_check("pressing E on the lever departs", _train.state == TrainController.State.DEPARTING, "state=%d" % _train.state)
	await _wait(0.4)
	var pulled := (_train.get_node("Interior/ControlCabin/ControlConsole/Instruments/DepartureLever") as Node3D).rotation.x
	_check("lever swings forward", pulled - rest_angle > 0.6, "rest=%.2f pulled=%.2f" % [rest_angle, pulled])
	_check("lever shows 'Train in motion' while moving", _ray.target == lever and not lever.can_interact()
			and _label("PromptLabel").text == "Train in motion"
			and not (_hud.get_node("%KeyChip") as Control).visible, "'%s'" % _label("PromptLabel").text)
	var count := _interactions.size()
	Input.action_press("interact")
	await _wait(0.1)
	Input.action_release("interact")
	_check("lever can't be used while moving", _interactions.size() == count, "")


# --- Helpers -----------------------------------------------------------------

func _containers() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in get_nodes_in_group("loot_container"):
		if _station.is_ancestor_of(n):
			out.append(n)
	return out


func _pick(containers: Array[Node3D], standpoints: Dictionary, path: String) -> Node3D:
	var c := _station.get_node_or_null(path) as Node3D
	return c if c in containers and standpoints.has(c) else null


## Centre of the container's first collision shape.
func _aim_point(c: Node3D) -> Vector3:
	for child in c.get_children():
		if child is CollisionShape3D:
			return (child as Node3D).global_position
	return c.global_position + Vector3.UP * 0.4


## Searches a ring of spots around [param c] for one where the player capsule
## fits on a floor and the ray from eye height reaches the container.
func _find_standpoint(c: Node3D) -> Variant:
	var space := _player.get_world_3d().direct_space_state
	var aim := _aim_point(c)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var shape_q := PhysicsShapeQueryParameters3D.new()
	shape_q.shape = capsule
	shape_q.exclude = [_player.get_rid()]
	for radius in [0.8, 1.1, 1.4]:
		for i in 16:
			var ang := TAU * i / 16.0
			var xz: Vector3 = aim + Vector3(cos(ang), 0, sin(ang)) * radius
			var down := PhysicsRayQueryParameters3D.create(Vector3(xz.x, aim.y + 1.0, xz.z),
					Vector3(xz.x, aim.y - 2.5, xz.z), 1, [_player.get_rid()])
			var floor_hit := space.intersect_ray(down)
			if floor_hit.is_empty() or (floor_hit.normal as Vector3).y < 0.7:
				continue
			var floor_pos: Vector3 = floor_hit.position
			shape_q.transform = Transform3D(Basis(), floor_pos + Vector3.UP * 0.92)
			if not space.intersect_shape(shape_q, 1).is_empty():
				continue
			var eye := floor_pos + Vector3.UP * EYE
			if eye.distance_to(aim) > _ray.reach * 0.95:
				continue
			if _ray.probe(eye, eye + (aim - eye).normalized() * _ray.reach) == Interactable.find_on(c):
				return floor_pos
	return null


func _stand_and_look(floor_pos: Vector3, point: Vector3) -> void:
	_player.teleport(Transform3D(Basis(), floor_pos))
	await _wait(0.15)
	await _look_at(point)


func _place_in_train(local_pos: Vector3) -> void:
	_player.teleport(Transform3D(Basis(), _train.to_global(local_pos)))
	await _wait(0.3)


func _look_at(point: Vector3) -> void:
	var to := point - _head.global_position
	_player.rotation.y = atan2(-to.x, -to.z)
	_head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await physics_frame
	await physics_frame
	await process_frame


func _label(unique_name: String) -> Label:
	return _hud.get_node("%" + unique_name) as Label


func _wait(seconds: float) -> void:
	for i in maxi(1, int(seconds * Engine.physics_ticks_per_second)):
		await physics_frame


func _check(test_name: String, passed: bool, detail: String) -> void:
	if passed:
		print("  PASS  %s   %s" % [test_name, detail])
	else:
		_failures += 1
		print("  FAIL  %s   %s" % [test_name, detail])
