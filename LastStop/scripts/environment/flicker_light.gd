class_name FlickerLight
extends OmniLight3D
## A failing light: steady most of the time, with occasional stuttering bursts
## and brief blackouts. Optionally swaps a mesh between lit and unlit
## materials so the fixture itself goes dark with the light.
## Flicker is gentle (no rapid full-screen strobing); a settings toggle to
## disable it arrives with the settings menu (Milestone 11).

@export var base_energy: float = 1.0
## Average seconds between stutter bursts.
@export var mean_interval: float = 4.0
## Length range of a stutter burst in seconds.
@export var burst_min: float = 0.25
@export var burst_max: float = 0.9
## Mesh whose material follows the light (e.g. a fluorescent tube).
@export var fixture: GeometryInstance3D
@export var lit_material: Material
@export var unlit_material: Material
@export var random_seed: int = 0

var _rng := RandomNumberGenerator.new()
var _until_burst: float = 0.0
var _burst_left: float = 0.0
var _until_toggle: float = 0.0
var _on: bool = true


func _ready() -> void:
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()
	_until_burst = _next_interval()
	_set_on(true)


func _process(delta: float) -> void:
	if _burst_left > 0.0:
		_burst_left -= delta
		_until_toggle -= delta
		if _until_toggle <= 0.0:
			_set_on(not _on)
			_until_toggle = _rng.randf_range(0.04, 0.16)
		if _burst_left <= 0.0:
			_set_on(true)
			_until_burst = _next_interval()
		return
	_until_burst -= delta
	if _until_burst <= 0.0:
		_burst_left = _rng.randf_range(burst_min, burst_max)


func _next_interval() -> float:
	return _rng.randf_range(mean_interval * 0.4, mean_interval * 1.6)


func _set_on(on: bool) -> void:
	_on = on
	light_energy = base_energy if on else base_energy * 0.08
	if fixture and lit_material and unlit_material:
		fixture.material_override = lit_material if on else unlit_material
