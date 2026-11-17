class_name StationManager
extends Node
## Loads stations along a [RouteData] and moves them past the parked train.
##
## On departure the current station becomes the "leaving" station and scrolls
## away. After [member RouteData.travel_seconds] the next station is spawned
## exactly one braking distance ahead and the train is told to brake, so it
## stops precisely on that station's TrainStop marker.

signal station_arrived(station: StationData)
signal journey_started(from: StationData, to: StationData)

@export var route: RouteData
@export var train: TrainController
## Parent node for spawned station scenes.
@export var station_root: Node3D
## Leaving stations are freed once this far behind the train.
@export var despawn_distance: float = 300.0

## Station the train is parked at (or last left).
var current_station: StationData
## Destination while travelling, otherwise null.
var destination: StationData

var _index: int = 0
var _current_scene: Station
var _leaving_scene: Station
var _arriving_scene: Station
var _travel_time: float = 0.0


func _ready() -> void:
	assert(route != null and not route.stations.is_empty(), "StationManager needs a route with stations.")
	train.travelled.connect(_on_travelled)
	train.state_changed.connect(_on_train_state_changed)
	current_station = route.stations[_index]
	_current_scene = _spawn_station(current_station, 0.0)
	_current_scene.on_train_arrived()
	station_arrived.emit.call_deferred(current_station)


func _physics_process(delta: float) -> void:
	var moving := train.state == TrainController.State.DEPARTING or train.state == TrainController.State.TRAVELLING
	if not moving or _arriving_scene != null or train.speed <= 0.0:
		return
	_travel_time += delta
	# Only start the approach once at cruising speed (so the next station appears
	# a full braking distance away, inside the fog) and once the previous station
	# has been freed (so two stations never overlap).
	var ready_to_arrive := _travel_time >= route.travel_seconds \
			and train.state == TrainController.State.TRAVELLING \
			and _leaving_scene == null
	if ready_to_arrive:
		_schedule_arrival()


## The station the train will go to next from where it is parked.
func get_next_station() -> StationData:
	return route.stations[route.next_index(_index)]


## The spawned scene of the station the train is parked at (null while travelling).
func get_current_scene() -> Station:
	return _current_scene


func _on_train_state_changed(state: TrainController.State) -> void:
	match state:
		TrainController.State.DEPARTING:
			destination = get_next_station()
			_leaving_scene = _current_scene
			_current_scene = null
			_travel_time = 0.0
			if _leaving_scene:
				_leaving_scene.on_train_departing()
			journey_started.emit(current_station, destination)
		TrainController.State.PARKED:
			if _arriving_scene == null:
				return
			_index = route.next_index(_index)
			current_station = destination
			destination = null
			_current_scene = _arriving_scene
			_arriving_scene = null
			_current_scene.on_train_arrived()
			station_arrived.emit(current_station)


func _schedule_arrival() -> void:
	var distance := train.get_braking_distance()
	_arriving_scene = _spawn_station(destination, distance)
	train.begin_arrival(distance)


## Instances a station so its TrainStop sits [param distance_ahead] metres in
## front of the train.
func _spawn_station(data: StationData, distance_ahead: float) -> Station:
	var station: Station = data.scene.instantiate()
	station_root.add_child(station)
	var forward := -train.global_basis.z
	var stop := train.global_position + forward * distance_ahead
	station.global_position = stop - station.global_basis * station.get_train_stop_offset()
	return station


func _on_travelled(distance: float) -> void:
	var offset := train.global_basis.z * distance
	if is_instance_valid(_arriving_scene):
		_arriving_scene.global_position += offset
	if is_instance_valid(_leaving_scene):
		_leaving_scene.global_position += offset
		if _leaving_scene.global_position.distance_to(train.global_position) > despawn_distance:
			_leaving_scene.queue_free()
			_leaving_scene = null
