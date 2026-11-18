extends Node3D
## Composition root of the playable game scene.
##
## Wires independent systems together through their signals and public APIs:
## train, station manager, player, inventory, interaction ray, mouse capture,
## HUD and inventory screen.
## Systems don't know about each other; only this script does.

const HINT_CAPTURED := "WASD move  ·  Shift sprint  ·  Space jump  ·  E interact  ·  Tab inventory  ·  Esc release mouse"
const HINT_RELEASED := "Click to resume"
## Shown when a searched container turns out to be empty.
const SEARCH_EMPTY_MESSAGE := "Nothing useful here."
## Shown when some found items didn't fit in the backpack.
const BACKPACK_FULL_MESSAGE := "Backpack full. The rest is still in the %s."

@onready var _player: PlayerController = $Player
@onready var _rumble: CameraRumble = $Player/Head/Camera3D
@onready var _train: TrainController = $Train
@onready var _ray: InteractionRay = $Player/Head/Camera3D/InteractionRay
@onready var _stations: StationManager = $StationManager
@onready var _capture: MouseCapture = $MouseCapture
@onready var _hud: HUD = $HUD
@onready var _inventory: InventoryComponent = $Player/Inventory
@onready var _inventory_screen: InventoryScreen = $InventoryScreen


func _ready() -> void:
	_player.teleport(($Train/PlayerSpawn as Marker3D).global_transform)

	_capture.captured_changed.connect(_on_capture_changed)
	_stations.station_arrived.connect(_on_station_arrived)
	_stations.journey_started.connect(_on_journey_started)
	_train.departure_refused.connect(_hud.show_message)
	_ray.focus_changed.connect(_on_focus_changed)
	_ray.hold_progress_changed.connect(_hud.set_hold_progress)
	_ray.interacted.connect(_on_interacted)
	_inventory_screen.closed.connect(_on_inventory_closed)

	_capture.set_captured(true)


func _process(_delta: float) -> void:
	var riding := _train.speed > 0.0 and _train.is_player_aboard()
	_rumble.strength = clampf(_train.speed / _train.cruise_speed, 0.0, 1.0) if riding else 0.0
	if _train.state != TrainController.State.PARKED:
		_update_travel_status()


func _unhandled_input(event: InputEvent) -> void:
	# Opening only; the screen closes itself (Tab/Esc) before input gets here.
	if event.is_action_pressed("inventory") and not _inventory_screen.is_open():
		get_viewport().set_input_as_handled()
		open_inventory()


## Shows the inventory screen; with [param storage], beside the player's
## backpack for moving items in and out. Player control pauses meanwhile.
func open_inventory(storage: InventoryComponent = null) -> void:
	if _inventory_screen.is_open():
		return
	_capture.ui_open = true
	_capture.set_captured(false)
	_hud.visible = false  # nothing from the HUD should show through the backdrop
	_inventory_screen.open(_inventory, storage)


func _on_inventory_closed() -> void:
	_hud.visible = true
	_capture.ui_open = false
	_capture.set_captured(true)


func _on_capture_changed(captured: bool) -> void:
	_player.input_enabled = captured
	_ray.enabled = captured
	if not _capture.ui_open:
		_hud.set_hint(HINT_CAPTURED if captured else HINT_RELEASED)


func _on_station_arrived(station: StationData) -> void:
	_hud.set_status(station.display_name, "Parked  ·  doors open")
	_hud.show_title_card(station.display_name, station.description)
	_train.departure_control.action = "Depart for %s" % _stations.get_next_station().display_name


func _on_journey_started(_from: StationData, _to: StationData) -> void:
	_update_travel_status()


func _on_focus_changed(target: Interactable) -> void:
	if target == null:
		_hud.set_interaction("", "")
	else:
		_hud.set_interaction(target.display_name, target.action, target.get_status_text(), target.hold_time > 0.0)


func _on_interacted(target: Interactable) -> void:
	if target == _train.storage_control:
		open_inventory(_train.storage)
		return
	var container := LootContainer.find_on(target)
	if container:
		_search(target, container)


## Opens a container and moves what's inside into the backpack. Whatever
## doesn't fit goes back in the container, which can then be used again
## ("Take items") once the player has made room.
func _search(target: Interactable, container: LootContainer) -> void:
	container.search()
	var found := container.take_all()
	if found.is_empty():
		_hud.show_message(SEARCH_EMPTY_MESSAGE)
		return
	var left := _inventory.add_stacks(found)
	container.put_back(left)
	_hud.show_loot(target.display_name, _subtract(found, left), left)
	if not left.is_empty():
		_hud.show_message(BACKPACK_FULL_MESSAGE % target.display_name.to_lower())


## [param all] minus [param part], per item (what was actually taken).
static func _subtract(all: Array[ItemStack], part: Array[ItemStack]) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for s in all:
		var n := s.quantity
		for p in part:
			if p.item == s.item:
				n -= p.quantity
		if n > 0:
			out.append(ItemStack.new(s.item, n))
	return out


func _update_travel_status() -> void:
	var destination := _stations.destination
	if destination == null:
		return
	var km_h := roundi(_train.speed * 3.6)
	match _train.state:
		TrainController.State.DEPARTING:
			var verb := "Doors closing" if _train.speed == 0.0 else "Departing"
			_hud.set_status(destination.display_name, "%s  ·  %d km/h" % [verb, km_h])
		TrainController.State.TRAVELLING:
			_hud.set_status(destination.display_name, "En route  ·  %d km/h" % km_h)
		TrainController.State.ARRIVING:
			_hud.set_status(destination.display_name, "Arriving  ·  %d km/h  ·  %d m" % [km_h, ceili(_train.get_remaining_distance())])
