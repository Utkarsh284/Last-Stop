class_name InteractionRay
extends Node3D
## Finds the [Interactable] the player is looking at and handles the Interact key.
##
## Attach to the camera. Each physics frame it casts a ray along the camera's
## forward axis. World geometry blocks the ray, so nothing can be used through
## walls. Two kinds of target are recognised:
## - collision bodies with an Interactable child (crates, lockers, safes);
## - Area3D hotspots on the "interaction" layer (small parts such as a lever,
##   which would be too fiddly to hit using the whole prop's collider).
##
## Press-type interactions fire on the key press; hold-type ones fill
## [member hold_progress] while the key is held and fire when it is full.
## After any interaction, and when focus moves to a new target while the key
## is held, the key must be released before the next interaction starts, so
## one press never triggers two things.

## Emitted when the focused target changes, or something in its prompt changes.
signal focus_changed(target: Interactable)
## Emitted while holding; 0…1. Emits 0 when the hold is cancelled or completes.
signal hold_progress_changed(progress: float)
## Emitted after the focused target was successfully used.
signal interacted(target: Interactable)

## Maximum distance from the camera, in metres.
@export var reach: float = 2.2
## Layers of solid geometry that block the ray (and of interactable bodies).
@export_flags_3d_physics var world_mask: int = 1
## Layers of interaction hotspot areas.
@export_flags_3d_physics var hotspot_mask: int = 2

## When false nothing is focused (menus, released mouse, cutscenes).
var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			_set_target(null)

## The Interactable currently looked at, or null.
var target: Interactable
## Hold progress for the current target, 0…1.
var hold_progress: float = 0.0

var _exclude: Array[RID] = []
var _needs_release: bool = false


func _ready() -> void:
	# Never hit the player's own capsule.
	var node := get_parent()
	while node != null:
		if node is CollisionObject3D:
			_exclude.append((node as CollisionObject3D).get_rid())
			break
		node = node.get_parent()


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	var origin := global_position
	_set_target(probe(origin, origin - global_basis.z * reach))
	_handle_input(delta)


## The focusable Interactable hit by a ray from [param from] to [param to], or
## null if the ray hits nothing, plain geometry, or a non-focusable target.
## Public so tests and other systems (e.g. an AI checking line of sight to a
## door) can use exactly the same rules.
func probe(from: Vector3, to: Vector3) -> Interactable:
	var space := get_world_3d().direct_space_state

	var body_query := PhysicsRayQueryParameters3D.create(from, to, world_mask, _exclude)
	var body_hit := space.intersect_ray(body_query)

	var area_query := PhysicsRayQueryParameters3D.create(from, to, hotspot_mask, _exclude)
	area_query.collide_with_bodies = false
	area_query.collide_with_areas = true
	var area_hit := space.intersect_ray(area_query)

	var hit := body_hit
	if not area_hit.is_empty() and (body_hit.is_empty()
			or from.distance_squared_to(area_hit.position) <= from.distance_squared_to(body_hit.position)):
		hit = area_hit
	if hit.is_empty():
		return null
	var found := Interactable.find_on(hit.collider)
	return found if found != null and found.is_focusable() else null


func _handle_input(delta: float) -> void:
	var pressed := Input.is_action_pressed("interact")
	if not pressed:
		_needs_release = false
	if target == null or not target.can_interact() or _needs_release or not pressed:
		_set_hold(0.0)
		return

	if target.hold_time <= 0.0:
		_use_target()  # first frame of a fresh press (see _needs_release)
		return

	_set_hold(hold_progress + delta / target.hold_time)
	if hold_progress >= 1.0:
		_use_target()


func _use_target() -> void:
	_needs_release = true
	_set_hold(0.0)
	var used := target
	if used.interact(get_parent()):
		interacted.emit(used)


func _set_target(new_target: Interactable) -> void:
	if new_target == target:
		return
	if target != null and is_instance_valid(target):
		target.changed.disconnect(_on_target_changed)
		target.tree_exiting.disconnect(_on_target_exiting)
	target = new_target
	_needs_release = Input.is_action_pressed("interact")
	if target != null:
		target.changed.connect(_on_target_changed)
		target.tree_exiting.connect(_on_target_exiting)
	_set_hold(0.0)
	focus_changed.emit(target)


func _set_hold(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if value != hold_progress:
		hold_progress = value
		hold_progress_changed.emit(value)


func _on_target_changed() -> void:
	if target != null and not target.is_focusable():
		_set_target(null)
	else:
		focus_changed.emit(target)


func _on_target_exiting() -> void:
	_set_target(null)
