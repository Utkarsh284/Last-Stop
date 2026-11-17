class_name DepartureTrigger
extends Area3D
## TEMPORARY (Milestone 3): pressing Interact while standing at the controls
## requests departure. Milestone 5 replaces this with an Interactable on the
## console's departure lever, using the real interaction raycast.

signal player_in_range_changed(in_range: bool)
signal activated

var player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_changed.bind(true))
	body_exited.connect(_on_body_changed.bind(false))


func _physics_process(_delta: float) -> void:
	if player_in_range and Input.is_action_just_pressed("interact"):
		activated.emit()


func _on_body_changed(body: Node3D, entered: bool) -> void:
	if body.is_in_group("player") and player_in_range != entered:
		player_in_range = entered
		player_in_range_changed.emit(entered)
