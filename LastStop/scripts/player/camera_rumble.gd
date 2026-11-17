class_name CameraRumble
extends Camera3D
## Subtle sway and vibration while riding the moving train.
## The game scene sets [member strength] (0–1) from the train's speed.
## Amplitudes are kept tiny to avoid motion sickness; a settings toggle comes
## with the settings menu (Milestone 11).

@export var max_offset: float = 0.012
@export var max_roll_degrees: float = 0.35
@export var frequency: float = 1.3

## 0 = still, 1 = full cruising rumble.
var strength: float = 0.0

var _time: float = 0.0
var _base_position: Vector3


func _ready() -> void:
	_base_position = position


func _process(delta: float) -> void:
	if strength <= 0.001:
		position = _base_position
		rotation.z = 0.0
		return
	_time += delta
	var t := _time * frequency
	# Low sway plus a faster rail-joint vibration.
	var offset := Vector3(sin(t * 2.1) * 0.6, sin(t * 7.3) * 0.5 + sin(t * 13.7) * 0.5, 0.0)
	position = _base_position + offset * max_offset * strength
	rotation.z = deg_to_rad(sin(t) * max_roll_degrees * strength)
