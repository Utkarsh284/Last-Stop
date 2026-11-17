class_name RouteData
extends Resource
## An ordered list of stations the train visits. After the last station the
## route loops back to the first. Future: branching routes, random stations.

@export var stations: Array[StationData] = []
## Minimum seconds from departure until the train starts braking for the next
## station. Braking also waits until the train is cruising and the previous
## station is out of range (see [member StationManager.despawn_distance]).
@export var travel_seconds: float = 20.0


## Index of the station after [param index], wrapping around.
func next_index(index: int) -> int:
	return (index + 1) % stations.size()
