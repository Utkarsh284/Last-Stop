class_name TrainController
extends Node3D
## Journey state, speed profile and doors of the train.
##
## The train never actually moves. The world scrolls past it instead
## ("treadmill"), so the player can walk around inside at full speed without
## moving-platform physics. Each physics frame the controller emits
## [signal travelled] with the distance covered; [StationManager] and
## [TravelScenery] move the world by that amount along the train's +Z.
##
## The departure lever on the console is an [Interactable]: using it calls
## [method request_departure]. It is disabled (with a reason) while moving
## and is animated forward while the train is under way.

enum State { PARKED, DEPARTING, TRAVELLING, ARRIVING }

signal state_changed(state: State)
## Distance (m) the train covered this physics frame.
signal travelled(distance: float)
signal departure_refused(reason: String)
signal doors_changed(is_open: bool)

@export_group("Speed")
## Top speed in m/s (16 m/s ≈ 58 km/h).
@export var cruise_speed: float = 16.0
## m/s² when pulling away.
@export var acceleration: float = 1.2
## m/s² when braking into a station.
@export var braking: float = 1.2
## Minimum crawl speed during the final approach so arrival never stalls.
@export var min_approach_speed: float = 0.5

@export_group("Doors")
## How far the doors slide (m) toward the cabin when opening.
@export var door_slide: float = 1.3
## Seconds to open or close.
@export var door_duration: float = 1.1

@export_group("Departure lever")
## Lever angle (radians, around its X axis) at rest and when pulled.
@export var lever_rest_angle: float = -0.4
@export var lever_pulled_angle: float = 0.45
## Seconds for the lever to swing.
@export var lever_duration: float = 0.25

var state: State = State.PARKED
## Current speed in m/s.
var speed: float = 0.0
var doors_open: bool = false

var _remaining: float = 0.0
var _door_tween: Tween
var _doors_closed_z: Array[float] = []
var _lever_tween: Tween

## The departure lever's Interactable. The game scene sets its action text
## (e.g. "Depart for Grey Hollow"); the train handles enabling and use.
@onready var departure_control: Interactable = 		$Interior/ControlCabin/ControlConsole/Instruments/DepartureHotspot/Interactable
@onready var _lever: Node3D = $Interior/ControlCabin/ControlConsole/Instruments/DepartureLever
@onready var _doors: Array[AnimatableBody3D] = [$Doors/DoorLeft, $Doors/DoorRight]
@onready var _aboard_area: Area3D = $AboardArea


func _ready() -> void:
	for door in _doors:
		_doors_closed_z.append(door.position.z)
	_set_doors_instant(true)
	departure_control.disabled_reason = "Train in motion"
	departure_control.interacted.connect(func(_by: Node) -> void: request_departure())
	_lever.rotation.x = lever_rest_angle
	_update_departure_control()


func _physics_process(delta: float) -> void:
	match state:
		State.DEPARTING, State.TRAVELLING:
			if _is_door_moving():
				return
			speed = move_toward(speed, cruise_speed, acceleration * delta)
			if state == State.DEPARTING and speed >= cruise_speed:
				_set_state(State.TRAVELLING)
			travelled.emit(speed * delta)
		State.ARRIVING:
			# Follow the braking curve v = √(2·a·d) so the train stops exactly on the mark.
			var target := sqrt(2.0 * braking * _remaining)
			speed = maxf(minf(target, speed + acceleration * delta), min_approach_speed)
			var step := minf(speed * delta, _remaining)
			_remaining -= step
			travelled.emit(step)
			if _remaining <= 0.0:
				_arrive()


## True when the player is inside the carriage (not on the steps or outside).
func is_player_aboard() -> bool:
	for body in _aboard_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false


## Why the train can't leave right now, or "" if it can.
## Milestone 10 adds fuel and condition checks here.
func get_departure_block_reason() -> String:
	if state != State.PARKED:
		return "The train is already moving."
	if not is_player_aboard():
		return "You need to be aboard to depart."
	return ""


## Closes the doors and pulls away. Returns false (and emits
## [signal departure_refused]) if departure isn't possible.
func request_departure() -> bool:
	var reason := get_departure_block_reason()
	if not reason.is_empty():
		departure_refused.emit(reason)
		return false
	_set_state(State.DEPARTING)
	_animate_doors(false)
	return true


## Starts braking so the train stops exactly [param distance] metres ahead.
func begin_arrival(distance: float) -> void:
	_remaining = maxf(distance, 0.0)
	_set_state(State.ARRIVING)


## Distance needed to stop from the current speed.
func get_braking_distance() -> float:
	return speed * speed / (2.0 * braking)


## Metres left until the train stops (only meaningful while arriving).
func get_remaining_distance() -> float:
	return _remaining


func _arrive() -> void:
	speed = 0.0
	_remaining = 0.0
	_set_state(State.PARKED)
	_animate_doors(true)


func _set_state(new_state: State) -> void:
	state = new_state
	_update_departure_control()
	state_changed.emit(state)


func _update_departure_control() -> void:
	var parked := state == State.PARKED
	departure_control.enabled = parked
	var angle := lever_rest_angle if parked else lever_pulled_angle
	if is_equal_approx(_lever.rotation.x, angle):
		return
	if _lever_tween:
		_lever_tween.kill()
	_lever_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lever_tween.tween_property(_lever, "rotation:x", angle, lever_duration)


func _is_door_moving() -> bool:
	return _door_tween != null and _door_tween.is_running()


func _animate_doors(open: bool) -> void:
	if _door_tween:
		_door_tween.kill()
	_door_tween = create_tween().set_parallel().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_door_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in _doors.size():
		_door_tween.tween_property(_doors[i], "position:z", _door_target_z(i, open), door_duration)
	doors_open = open
	doors_changed.emit(open)


func _set_doors_instant(open: bool) -> void:
	for i in _doors.size():
		_doors[i].position.z = _door_target_z(i, open)
	doors_open = open
	doors_changed.emit(open)


func _door_target_z(index: int, open: bool) -> float:
	return _doors_closed_z[index] - (door_slide if open else 0.0)
