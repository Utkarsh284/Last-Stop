class_name StationData
extends Resource
## Static description of one railway station. One .tres per station in data/stations/.

## Stable identifier used by saves and quests. Never change it once shipped.
@export var id: StringName
## Name shown on the HUD and arrival title card.
@export var display_name: String
## One-line flavour text shown under the name on arrival.
@export_multiline var description: String
## Scene whose root uses the [Station] script.
@export var scene: PackedScene
