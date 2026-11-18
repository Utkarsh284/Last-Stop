class_name Interactable
extends Node
## Makes its parent [CollisionObject3D] usable with the Interact key.
##
## Add as a child of a StaticBody3D (a crate, a locker) or of a small Area3D
## on the "interaction" physics layer (a hotspot around a lever or button).
## [InteractionRay] finds it through the parent's metadata, so the parent can
## be any collision object and needs no script of its own.
##
## Systems react through [signal interacted]; this node never knows what the
## interaction means (departing, searching, opening storage...).

## Emitted when the player completes the interaction (after the hold, if any).
signal interacted(interactor: Node)
## Emitted whenever anything shown in the prompt changes.
signal changed

## Parent metadata key used by [InteractionRay] to find this component.
const META := &"interactable"

## What the object is called, shown above the action ("Filing cabinet").
@export var display_name: String = "Object":
	set(value):
		display_name = value
		changed.emit()
## Verb shown next to the key ("Search", "Depart for Grey Hollow").
@export var action: String = "Use":
	set(value):
		action = value
		changed.emit()
## Seconds the key must be held. 0 = a single press.
@export_range(0.0, 10.0, 0.05, "suffix:s") var hold_time: float = 0.0
## When true, the object can be used only once (e.g. searching a container).
@export var one_shot: bool = false
## Shown instead of the action once a one-shot object has been used.
@export var used_label: String = "Used":
	set(value):
		if used_label != value:
			used_label = value
			changed.emit()
## When false, the object can't be used. If [member disabled_reason] is set it
## is still focused and the reason is shown; otherwise it is ignored entirely.
@export var enabled: bool = true:
	set(value):
		if enabled != value:
			enabled = value
			changed.emit()
## Shown instead of the action while disabled ("Train in motion").
@export var disabled_reason: String = "":
	set(value):
		disabled_reason = value
		changed.emit()

## True once a one-shot interaction has happened.
var used: bool = false


func _enter_tree() -> void:
	get_parent().set_meta(META, self)


func _exit_tree() -> void:
	var parent := get_parent()
	if parent.has_meta(META) and parent.get_meta(META) == self:
		parent.remove_meta(META)


## The Interactable attached to [param collider], or null.
static func find_on(collider: Object) -> Interactable:
	if collider == null or not collider.has_meta(META):
		return null
	return collider.get_meta(META) as Interactable


## True if pressing Interact would do something right now.
func can_interact() -> bool:
	return enabled and not (one_shot and used)


## True if the ray should stop on this object and show a prompt.
func is_focusable() -> bool:
	return can_interact() or (one_shot and used) or not disabled_reason.is_empty()


## Why the object can't be used ("Searched", "Train in motion"), or "" if it can.
func get_status_text() -> String:
	if one_shot and used:
		return used_label
	if not enabled:
		return disabled_reason
	return ""


## Performs the interaction. Returns false if it isn't currently possible.
func interact(interactor: Node) -> bool:
	if not can_interact():
		return false
	if one_shot:
		used = true
	interacted.emit(interactor)
	changed.emit()
	return true


## Makes a used one-shot object usable again (e.g. a station's loot respawning).
func reset() -> void:
	used = false
	changed.emit()
