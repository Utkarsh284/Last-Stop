class_name LootContainer
extends Node
## Gives its parent (a searchable prop) contents rolled from a [LootTable].
##
## Add as a child of the same collision object that carries the container's
## [Interactable]. The contents are rolled the first time the container is
## searched (or when [method get_contents] is first called), so every visit
## to a station can produce different loot. Whoever handles the interaction
## calls [method search]; this node doesn't listen to input itself.

## Emitted after a search with whatever was inside (may be empty).
signal searched(contents: Array[ItemStack])

## Parent metadata key used by [method find_on].
const META := &"loot_container"
## Prompt action once leftovers have been put back.
const TAKE_ACTION := "Take items"

@export var loot_table: LootTable
## Fixed seed for reproducible contents. 0 = random each time it's rolled.
@export var rng_seed: int = 0

var _contents: Array[ItemStack] = []
var _rolled: bool = false
var _searched: bool = false
## Whether the first search found anything ("Searched" vs "Empty" label).
var _found_any: bool = false
## The Interactable's original action and hold time, restored by restock().
var _default_action: String = ""
var _default_hold_time: float = 0.0


func _enter_tree() -> void:
	get_parent().set_meta(META, self)


func _exit_tree() -> void:
	var parent := get_parent()
	if parent.has_meta(META) and parent.get_meta(META) == self:
		parent.remove_meta(META)


## The LootContainer on the same object as [param interactable], or null.
static func find_on(interactable: Interactable) -> LootContainer:
	if interactable == null:
		return null
	var parent := interactable.get_parent()
	if not parent.has_meta(META):
		return null
	return parent.get_meta(META) as LootContainer


## True once the container has been searched.
func is_searched() -> bool:
	return _searched


## What is inside right now (rolls the contents if that hasn't happened yet).
func get_contents() -> Array[ItemStack]:
	_ensure_rolled()
	return _contents


## Opens the container: rolls its contents if needed, marks it searched,
## updates the Interactable's "used" label and returns the contents.
## The items stay inside until something takes them (see [method take_all]).
## Searching again (after [method put_back]) returns what is left.
func search() -> Array[ItemStack]:
	_ensure_rolled()
	if not _searched:
		_searched = true
		_found_any = not _contents.is_empty()
	_update_label()
	searched.emit(_contents)
	return _contents


## Removes and returns everything inside.
func take_all() -> Array[ItemStack]:
	_ensure_rolled()
	var taken := _contents
	_contents = []
	_update_label()
	return taken


## Puts back items that were taken but couldn't be carried (inventory full).
## The container becomes usable again, as a quick "Take items" press, so the
## player can come back for them after making room.
func put_back(stacks: Array[ItemStack]) -> void:
	if stacks.is_empty():
		return
	_ensure_rolled()
	_contents.append_array(stacks)
	var it := _interactable()
	if it and _searched:
		_remember_interactable_defaults(it)
		it.action = TAKE_ACTION
		it.hold_time = 0.0
		it.reset()


## Empties the container and forgets the roll, so the next search rolls anew.
func restock() -> void:
	_contents = []
	_rolled = false
	_searched = false
	_found_any = false
	var it := _interactable()
	if it:
		if not _default_action.is_empty():
			it.action = _default_action
			it.hold_time = _default_hold_time
		it.used_label = "Searched"
		it.reset()


func _ensure_rolled() -> void:
	if _rolled:
		return
	_rolled = true
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	_contents = loot_table.roll(rng) if loot_table else []


func _update_label() -> void:
	var it := _interactable()
	if it and _searched:
		it.used_label = "Searched" if _found_any else "Empty"


func _remember_interactable_defaults(it: Interactable) -> void:
	if _default_action.is_empty() and it.action != TAKE_ACTION:
		_default_action = it.action
		_default_hold_time = it.hold_time


func _interactable() -> Interactable:
	var parent := get_parent()
	return parent.get_meta(Interactable.META) as Interactable if parent.has_meta(Interactable.META) else null
