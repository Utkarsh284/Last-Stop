class_name Station
extends Node3D
## Base script for every station scene.
##
## Contract:
## - A Marker3D child named "TrainStop" marks where the train's origin sits
##   when parked. The track runs along local Z, platforms are on the +X side
##   (edge at x = 1.7, height 0.35). Keep anything taller than the platform
##   at least 4 m from the track centre so it never clips the train.
## - Optional "Bounds" node: invisible walls that keep the player in the
##   playable area. They only collide while the train is parked here, because
##   stations slide past the (stationary) train when arriving and leaving.
## Stations are moved as a whole, so keep everything as children of this node.

@onready var _train_stop: Marker3D = $TrainStop
@onready var _bounds: Node3D = get_node_or_null("Bounds")


func _ready() -> void:
	_set_bounds_enabled(false)


## Position of the train stop relative to this node's origin.
func get_train_stop_offset() -> Vector3:
	return _train_stop.position


## Called once the train has stopped here. Future: wake enemies, refresh loot.
func on_train_arrived() -> void:
	_set_bounds_enabled(true)


## Called when the train starts leaving. Future: put the station to sleep.
func on_train_departing() -> void:
	_set_bounds_enabled(false)


func _set_bounds_enabled(enabled: bool) -> void:
	if _bounds:
		_bounds.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
