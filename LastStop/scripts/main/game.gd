extends Node3D
## Composition root of the playable game scene.
##
## Wires independent systems together through their signals and public APIs:
## train, station manager, player, interaction ray, mouse capture and HUD.
## Systems don't know about each other; only this script does.

const HINT_CAPTURED := "WASD move  ·  Shift sprint  ·  Space jump  ·  E interact  ·  Esc release mouse"
const HINT_RELEASED := "Click to resume"
## Placeholder result of searching a container until loot exists (Milestone 6).
const SEARCH_EMPTY_MESSAGE := "Nothing useful here."

@onready var _player: PlayerController = $Player
@onready var _rumble: CameraRumble = $Player/Head/Camera3D
@onready var _train: TrainController = $Train
@onready var _ray: InteractionRay = $Player/Head/Camera3D/InteractionRay
@onready var _stations: StationManager = $StationManager
@onready var _capture: MouseCapture = $MouseCapture
@onready var _hud: HUD = $HUD


func _ready() -> void:
	_player.teleport(($Train/PlayerSpawn as Marker3D).global_transform)

	_capture.captured_changed.connect(_on_capture_changed)
	_stations.station_arrived.connect(_on_station_arrived)
	_stations.journey_started.connect(_on_journey_started)
	_train.departure_refused.connect(_hud.show_message)
	_ray.focus_changed.connect(_on_focus_changed)
	_ray.hold_progress_changed.connect(_hud.set_hold_progress)
	_ray.interacted.connect(_on_interacted)

	_capture.set_captured(true)


func _process(_delta: float) -> void:
	var riding := _train.speed > 0.0 and _train.is_player_aboard()
	_rumble.strength = clampf(_train.speed / _train.cruise_speed, 0.0, 1.0) if riding else 0.0
	if _train.state != TrainController.State.PARKED:
		_update_travel_status()


func _on_capture_changed(captured: bool) -> void:
	_player.input_enabled = captured
	_ray.enabled = captured
	_hud.set_hint(HINT_CAPTURED if captured else HINT_RELEASED)


func _on_station_arrived(station: StationData) -> void:
	_hud.set_status(station.display_name, "Parked  ·  doors open")
	_hud.show_title_card(station.display_name, station.description)
	_train.departure_control.action = "Depart for %s" % _stations.get_next_station().display_name


func _on_journey_started(_from: StationData, _to: StationData) -> void:
	_update_travel_status()


func _on_focus_changed(target: Interactable) -> void:
	if target == null:
		_hud.set_interaction("", "")
	else:
		_hud.set_interaction(target.display_name, target.action, target.get_status_text(), target.hold_time > 0.0)


func _on_interacted(target: Interactable) -> void:
	if target.get_parent().is_in_group("loot_container"):
		_hud.show_message(SEARCH_EMPTY_MESSAGE)


func _update_travel_status() -> void:
	var destination := _stations.destination
	if destination == null:
		return
	var km_h := roundi(_train.speed * 3.6)
	match _train.state:
		TrainController.State.DEPARTING:
			var verb := "Doors closing" if _train.speed == 0.0 else "Departing"
			_hud.set_status(destination.display_name, "%s  ·  %d km/h" % [verb, km_h])
		TrainController.State.TRAVELLING:
			_hud.set_status(destination.display_name, "En route  ·  %d km/h" % km_h)
		TrainController.State.ARRIVING:
			_hud.set_status(destination.display_name, "Arriving  ·  %d km/h  ·  %d m" % [km_h, ceili(_train.get_remaining_distance())])
