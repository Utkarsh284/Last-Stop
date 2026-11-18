class_name LootTable
extends Resource
## Weighted list of what a kind of container can hold. One .tres per
## container theme in resources/loot_tables/ (vending machine, safe, ...).
##
## A roll: with [member empty_chance] the container is empty; otherwise
## between [member min_picks] and [member max_picks] different entries are
## drawn by weight (never the same entry twice) and each gets a random
## quantity in its range, capped at the item's stack size.

@export var entries: Array[LootEntry] = []
## Chance (0…1) that the container holds nothing at all.
@export_range(0.0, 1.0, 0.01) var empty_chance: float = 0.2
## Number of different items found when the container isn't empty.
@export_range(1, 10) var min_picks: int = 1
@export_range(1, 10) var max_picks: int = 2


## Rolls the contents of one container. [param rng] makes it reproducible.
func roll(rng: RandomNumberGenerator) -> Array[ItemStack]:
	var result: Array[ItemStack] = []
	if rng.randf() < empty_chance:
		return result
	var pool: Array[LootEntry] = entries.filter(func(e: LootEntry) -> bool: return e.item != null and e.weight > 0.0)
	var picks := mini(rng.randi_range(min_picks, max_picks), pool.size())
	for i in picks:
		var entry := _pick_weighted(pool, rng)
		pool.erase(entry)
		var amount := mini(rng.randi_range(entry.min_quantity, entry.max_quantity), entry.item.max_stack)
		result.append(ItemStack.new(entry.item, amount))
	return result


func _pick_weighted(pool: Array[LootEntry], rng: RandomNumberGenerator) -> LootEntry:
	var total := 0.0
	for e in pool:
		total += e.weight
	var r := rng.randf() * total
	for e in pool:
		r -= e.weight
		if r < 0.0:
			return e
	return pool.back()
