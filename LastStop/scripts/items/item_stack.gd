class_name ItemStack
extends RefCounted
## A quantity of one item: the unit that loot, inventory and storage pass around.

var item: ItemData
var quantity: int


func _init(p_item: ItemData = null, p_quantity: int = 1) -> void:
	item = p_item
	quantity = p_quantity


## "3 × Canned beans", or just the name for a single item.
func get_label() -> String:
	return item.display_name if quantity == 1 else "%d × %s" % [quantity, item.display_name]


func _to_string() -> String:
	return "%s×%d" % [item.id, quantity]
