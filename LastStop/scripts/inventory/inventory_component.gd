class_name InventoryComponent
extends Node
## A fixed number of item slots. Identical items stack up to their
## [member ItemData.max_stack]; anything beyond that takes another slot.
##
## Used for the player's backpack and the train's storage alike. The logic
## never looks at specific items: everything comes from [ItemData].
## UI listens to [signal changed] and redraws; it never edits slots directly.

## Emitted after any change to the contents.
signal changed

## Number of slots. Changing it at runtime keeps existing stacks that still fit.
@export_range(1, 200) var slot_count: int = 20:
	set(value):
		slot_count = value
		_slots.resize(value)
		changed.emit()

## One entry per slot; null = empty.
var _slots: Array[ItemStack] = []


func _init() -> void:
	_slots.resize(slot_count)


## The stack in slot [param index], or null if it's empty.
func get_slot(index: int) -> ItemStack:
	return _slots[index] if index >= 0 and index < _slots.size() else null


## Every non-empty stack, in slot order.
func get_stacks() -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for s in _slots:
		if s != null:
			out.append(s)
	return out


## Number of slots holding something.
func get_used_slot_count() -> int:
	return _slots.size() - _slots.count(null)


func is_empty() -> bool:
	return get_used_slot_count() == 0


## Total quantity of [param item] across all slots.
func count_item(item: ItemData) -> int:
	var total := 0
	for s in _slots:
		if s != null and s.item == item:
			total += s.quantity
	return total


func has_item(item: ItemData, quantity: int = 1) -> bool:
	return count_item(item) >= quantity


## How many more of [param item] would fit (topping up stacks + empty slots).
func get_capacity_for(item: ItemData) -> int:
	var room := 0
	for s in _slots:
		if s == null:
			room += item.max_stack
		elif s.item == item:
			room += item.max_stack - s.quantity
	return room


## Adds [param quantity] of [param item]: tops up existing stacks first, then
## fills empty slots. Returns how many did NOT fit (0 = all added).
func add_item(item: ItemData, quantity: int) -> int:
	if item == null or quantity <= 0:
		return maxi(quantity, 0)
	var left := quantity
	for s in _slots:
		if left == 0:
			break
		if s != null and s.item == item and s.quantity < item.max_stack:
			var n := mini(left, item.max_stack - s.quantity)
			s.quantity += n
			left -= n
	for i in _slots.size():
		if left == 0:
			break
		if _slots[i] == null:
			var n := mini(left, item.max_stack)
			_slots[i] = ItemStack.new(item, n)
			left -= n
	if left != quantity:
		changed.emit()
	return left


## Adds several stacks. Returns what didn't fit, as new stacks (empty = all added).
func add_stacks(stacks: Array[ItemStack]) -> Array[ItemStack]:
	var leftovers: Array[ItemStack] = []
	for s in stacks:
		var left := add_item(s.item, s.quantity)
		if left > 0:
			leftovers.append(ItemStack.new(s.item, left))
	return leftovers


## Removes up to [param quantity] of [param item], taking from the last slots
## first so the earliest stacks stay put. Returns how many were removed.
func remove_item(item: ItemData, quantity: int) -> int:
	var left := quantity
	for i in range(_slots.size() - 1, -1, -1):
		if left <= 0:
			break
		var s := _slots[i]
		if s != null and s.item == item:
			var n := mini(left, s.quantity)
			s.quantity -= n
			left -= n
			if s.quantity == 0:
				_slots[i] = null
	var removed := quantity - maxi(left, 0)
	if removed > 0:
		changed.emit()
	return removed


## Removes [param quantity] from one slot (-1 = the whole stack) and returns
## what was removed as a new stack, or null if the slot was empty.
func remove_from_slot(index: int, quantity: int = -1) -> ItemStack:
	var s := get_slot(index)
	if s == null:
		return null
	var n := s.quantity if quantity < 0 else mini(quantity, s.quantity)
	s.quantity -= n
	if s.quantity == 0:
		_slots[index] = null
	changed.emit()
	return ItemStack.new(s.item, n)


## Moves as much of slot [param index] as fits into [param target].
## Returns the quantity moved (0 if nothing fitted or the slot was empty).
func transfer_slot(index: int, target: InventoryComponent) -> int:
	var s := get_slot(index)
	if s == null or target == null or target == self:
		return 0
	var n := mini(s.quantity, target.get_capacity_for(s.item))
	if n == 0:
		return 0
	remove_from_slot(index, n)
	target.add_item(s.item, n)
	return n


## Moves every stack that fits into [param target]. Returns the quantity moved.
func transfer_all(target: InventoryComponent) -> int:
	var moved := 0
	for i in _slots.size():
		moved += transfer_slot(i, target)
	return moved


## Empties every slot.
func clear() -> void:
	_slots.fill(null)
	changed.emit()
