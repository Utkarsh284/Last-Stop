class_name ItemData
extends Resource
## Static definition of one kind of item. One .tres per item in resources/items/.
##
## Systems never special-case items by name: inventory, loot and (later)
## survival read everything they need from these fields.

## Inventory grouping, shown as a filter/label in the inventory (Milestone 7).
enum Category { FOOD, WATER, MEDICAL, MATERIAL, AMMO, WEAPON }

## Human-readable name of each [enum Category], for UI.
const CATEGORY_NAMES := {
	Category.FOOD: "Food",
	Category.WATER: "Water",
	Category.MEDICAL: "Medical",
	Category.MATERIAL: "Materials",
	Category.AMMO: "Ammunition",
	Category.WEAPON: "Weapons",
}

## Stable identifier used by saves and loot tables. Matches the file name.
## Never change it once shipped.
@export var id: StringName
## Name shown in the HUD and inventory ("Canned beans").
@export var display_name: String
## One or two sentences shown in the inventory.
@export_multiline var description: String
@export var category: Category = Category.MATERIAL
## Largest quantity that fits in one inventory slot. 1 = never stacks.
@export_range(1, 999) var max_stack: int = 1
## Inventory icon. Icons arrive with the inventory UI (Milestone 7).
@export var icon: Texture2D


## The category's display name ("Medical").
func get_category_name() -> String:
	return CATEGORY_NAMES[category]
