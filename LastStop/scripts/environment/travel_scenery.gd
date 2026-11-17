class_name TravelScenery
extends Node3D
## Makes the world rush past the stationary train.
##
## - [member scroll] (ground + track) shifts with the train and wraps every
##   [member wrap_length] metres, so it looks endless. Wrap length must be a
##   multiple of every texture/sleeper repeat inside it (60 m works).
## - Roadside props stream in out of the fog ahead and are freed behind.
## Assumes the track runs along this node's Z axis, train facing -Z.

@export var train: TrainController
@export var scroll: Node3D
@export var wrap_length: float = 60.0

@export_group("Props")
@export var pole_scene: PackedScene
@export var tree_scene: PackedScene
@export var rock_scene: PackedScene
## Telegraph poles run along the left (-X) side, away from platforms.
@export var pole_spacing: float = 45.0
@export var pole_offset_x: float = -6.0
## Random gap between trees/rocks, in metres.
@export var tree_gap_min: float = 5.0
@export var tree_gap_max: float = 16.0
## Trees/rocks stay this far from the track on either side.
@export var side_min: float = 10.0
@export var side_max: float = 70.0
## Props appear this far ahead (inside the fog) and are freed this far behind.
@export var spawn_distance: float = 220.0
@export var despawn_distance: float = 140.0
## On arrival, props that would end up within this distance of the train are
## removed while still deep in the fog, keeping the station area clear.
@export var station_clear_radius: float = 60.0
@export var random_seed: int = 214

var _rng := RandomNumberGenerator.new()
var _props: Array[Node3D] = []
var _until_pole: float = 0.0
var _until_tree: float = 0.0


func _ready() -> void:
	_rng.seed = random_seed
	train.travelled.connect(_on_travelled)
	train.state_changed.connect(_on_train_state_changed)


func _on_travelled(distance: float) -> void:
	scroll.position.z = fposmod(scroll.position.z + distance, wrap_length)
	for i in range(_props.size() - 1, -1, -1):
		var prop := _props[i]
		prop.position.z += distance
		if prop.position.z > despawn_distance:
			prop.queue_free()
			_props.remove_at(i)
	if train.state != TrainController.State.ARRIVING:
		_spawn_props(distance)


func _spawn_props(distance: float) -> void:
	_until_pole -= distance
	while _until_pole <= 0.0:
		_add_prop(pole_scene, Vector3(pole_offset_x, 0, -spawn_distance + _until_pole), Vector3(0, 0, _rng.randf_range(-0.04, 0.04)), 1.0)
		_until_pole += pole_spacing
	_until_tree -= distance
	while _until_tree <= 0.0:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x := side * _rng.randf_range(side_min, side_max)
		var is_tree := _rng.randf() < 0.65
		var scene := tree_scene if is_tree else rock_scene
		var scale_factor := _rng.randf_range(0.7, 1.3) if is_tree else _rng.randf_range(0.5, 1.6)
		_add_prop(scene, Vector3(x, 0, -spawn_distance + _until_tree), Vector3(0, _rng.randf() * TAU, 0), scale_factor)
		_until_tree += _rng.randf_range(tree_gap_min, tree_gap_max)


func _add_prop(scene: PackedScene, pos: Vector3, rot: Vector3, scale_factor: float) -> void:
	var prop: Node3D = scene.instantiate()
	prop.position = pos
	prop.rotation = rot
	prop.scale = Vector3.ONE * scale_factor
	add_child(prop)
	_props.append(prop)


func _on_train_state_changed(state: TrainController.State) -> void:
	if state != TrainController.State.ARRIVING:
		return
	var travel_left := train.get_remaining_distance()
	for i in range(_props.size() - 1, -1, -1):
		if absf(_props[i].position.z + travel_left) < station_clear_radius:
			_props[i].queue_free()
			_props.remove_at(i)
