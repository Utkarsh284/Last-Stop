extends Node3D
## Developer movement sandbox (not part of the game flow).
##
## Flat test geometry for tuning the player: a crate to jump on, a ramp,
## stairs and a wall. Used by tests/test_player_movement.gd.
## Run it from the editor with F6 while this scene is open.

## Dev-only: `-- --capture=<path>` saves a screenshot after a few frames and quits.
const CAPTURE_ARG_PREFIX := "--capture="
const CAPTURE_DELAY_FRAMES := 30

@onready var _player: PlayerController = $Player
@onready var _capture: MouseCapture = $MouseCapture
@onready var _debug_label: Label = %DebugLabel
@onready var _hint_label: Label = %HintLabel


func _ready() -> void:
	_capture.captured_changed.connect(_on_capture_changed)
	_capture.set_captured(true)
	_read_dev_args()


func _process(_delta: float) -> void:
	_debug_label.text = "%.1f m/s   ·   %s" % [_player.get_horizontal_speed(), _describe_state()]


func _on_capture_changed(captured: bool) -> void:
	_player.input_enabled = captured
	_hint_label.text = "WASD move  ·  Shift sprint  ·  Space jump  ·  Esc release mouse" if captured \
			else "Click to resume"


func _describe_state() -> String:
	if not _player.is_on_floor():
		return "Airborne"
	if _player.is_sprinting:
		return "Sprinting"
	if _player.get_horizontal_speed() > 0.1:
		return "Walking"
	return "Idle"


func _read_dev_args() -> void:
	var capture_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(CAPTURE_ARG_PREFIX):
			capture_path = arg.trim_prefix(CAPTURE_ARG_PREFIX)
	if capture_path.is_empty():
		return
	for i in CAPTURE_DELAY_FRAMES:
		await get_tree().process_frame
	var err := get_viewport().get_texture().get_image().save_png(capture_path)
	print("[LastStop] Capture saved to %s (error %d)" % [capture_path, err])
	get_tree().quit()
