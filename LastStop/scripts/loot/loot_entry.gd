class_name LootEntry
extends Resource
## One possible drop in a [LootTable]: an item, how likely it is and how many.

@export var item: ItemData
## Relative chance of being picked. 2 is twice as likely as 1.
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export_range(1, 999) var min_quantity: int = 1
@export_range(1, 999) var max_quantity: int = 1
