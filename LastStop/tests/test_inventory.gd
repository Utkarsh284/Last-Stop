extends SceneTree
## Automated test for Milestone 7: inventory.
##   Godot_console.exe --headless --path . --script res://tests/test_inventory.gd
##
## 1. InventoryComponent: stacking, stack limits, full inventory, removing,
##    transfers between inventories, change signals.
## 2. Every item has an icon.
## 3. Game wiring: player backpack (20 slots), train storage (40) behind an
##    interactable locker that can be reached from inside the train.
## 4. Searching moves loot into the backpack; with a full backpack the rest
##    stays in the container ("Take items") and can be collected later.
## 5. Inventory screen via real key events: Tab opens/closes, player control
##    and the interaction ray pause, slots show icons and quantities, the
##    details pane, category filter, discard (press twice), Esc closes.
## 6. Storage mode: deposit a stack, take it back, deposit everything,
##    storage full feedback.

const SCENE_PATH := "res://scenes/main/game.tscn"
const ITEMS_DIR := "res://resources/items/"

var _failures: int = 0
var _beans: ItemData
var _water: ItemData
var _rounds: ItemData
var _crowbar: ItemData
var _scrap: ItemData


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_beans = load(ITEMS_DIR + "canned_food.tres")
	_water = load(ITEMS_DIR + "bottled_water.tres")
	_rounds = load(ITEMS_DIR + "pistol_rounds.tres")
	_crowbar = load(ITEMS_DIR + "crowbar.tres")
	_scrap = load(ITEMS_DIR + "scrap_metal.tres")
	_test_component()
	_test_icons()
	await _test_game()

	print("")
	if _failures == 0:
		print("ALL INVENTORY TESTS PASSED")
	else:
		print("%d INVENTORY TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# --- 1. Component --------------------------------------------------------------

func _test_component() -> void:
	var inv := InventoryComponent.new()
	inv.slot_count = 4
	var changes := [0]
	inv.changed.connect(func() -> void: changes[0] += 1)

	_check("starts empty", inv.is_empty() and inv.get_used_slot_count() == 0, "")
	var left := inv.add_item(_beans, 3)
	left += inv.add_item(_beans, 4)
	_check("identical items stack in one slot", left == 0 and inv.get_used_slot_count() == 1
			and inv.get_slot(0).quantity == 7, "slot0=%s" % inv.get_slot(0))
	left = inv.add_item(_beans, 5)
	_check("overflow beyond max_stack (10) starts a new stack", left == 0 and inv.get_slot(0).quantity == 10
			and inv.get_slot(1).quantity == 2 and inv.count_item(_beans) == 12, "%s %s" % [inv.get_slot(0), inv.get_slot(1)])
	inv.add_item(_crowbar, 1)
	left = inv.add_item(_crowbar, 1)
	_check("non-stacking items take one slot each", left == 0 and inv.get_used_slot_count() == 4
			and inv.count_item(_crowbar) == 2 and inv.get_slot(2).quantity == 1,
			"left=%d crowbars=%d" % [left, inv.count_item(_crowbar)])
	# Now: beans 10, beans 2, crowbar, crowbar → full.
	_check("capacity: only partial stacks have room when every slot is used",
			inv.get_capacity_for(_beans) == 8 and inv.get_capacity_for(_water) == 0, "beans=%d water=%d"
			% [inv.get_capacity_for(_beans), inv.get_capacity_for(_water)])
	left = inv.add_item(_beans, 20)
	_check("adding to a full inventory tops up and returns the rest", left == 12 and inv.count_item(_beans) == 20, "left=%d" % left)
	left = inv.add_item(_water, 3)
	_check("a new item doesn't fit in a full inventory", left == 3 and not inv.has_item(_water), "")

	var leftovers := inv.add_stacks([ItemStack.new(_water, 2), ItemStack.new(_beans, 1)] as Array[ItemStack])
	_check("add_stacks returns what didn't fit", leftovers.size() == 2 and leftovers[0].item == _water
			and leftovers[0].quantity == 2, "%s" % [leftovers])

	var removed := inv.remove_item(_beans, 13)
	_check("remove_item takes from the last stacks first", removed == 13 and inv.count_item(_beans) == 7
			and inv.get_slot(0).quantity == 7 and inv.get_slot(1) == null, "%s %s" % [inv.get_slot(0), inv.get_slot(1)])
	_check("remove_item can't remove more than there is", inv.remove_item(_water, 5) == 0, "")
	var part := inv.remove_from_slot(0, 3)
	_check("remove_from_slot (partial)", part.item == _beans and part.quantity == 3 and inv.get_slot(0).quantity == 4, "")
	var whole := inv.remove_from_slot(0)
	_check("remove_from_slot (whole stack) empties the slot", whole.quantity == 4 and inv.get_slot(0) == null, "")
	_check("remove_from_slot on an empty slot returns null", inv.remove_from_slot(0) == null, "")

	var other := InventoryComponent.new()
	other.slot_count = 2
	inv.clear()
	inv.add_item(_rounds, 100)  # 60 + 40
	other.add_item(_rounds, 50)
	other.add_item(_scrap, 1)
	var moved := inv.transfer_slot(0, other)
	_check("transfer_slot moves only what fits", moved == 10 and other.count_item(_rounds) == 60
			and inv.count_item(_rounds) == 90, "moved=%d" % moved)
	moved = inv.transfer_all(other)
	_check("transfer_all with a full target moves nothing", moved == 0 and inv.count_item(_rounds) == 90, "")
	other.slot_count = 4
	moved = inv.transfer_all(other)
	_check("transfer_all moves everything that fits", moved == 90 and inv.is_empty()
			and other.count_item(_rounds) == 150, "moved=%d" % moved)
	_check("changes emit 'changed'", changes[0] >= 10, "count=%d" % changes[0])
	var before: int = changes[0]
	inv.add_item(_water, 0)
	inv.remove_item(_water, 1)
	_check("no-op calls don't emit 'changed'", changes[0] == before, "")
	inv.free()
	other.free()


# --- 2. Icons ------------------------------------------------------------------

func _test_icons() -> void:
	var missing: Array[String] = []
	for f in DirAccess.get_files_at(ITEMS_DIR):
		if not f.ends_with(".tres"):
			continue
		var item := load(ITEMS_DIR + f) as ItemData
		if item.icon == null or item.icon.get_width() < 64:
			missing.append(f)
	_check("every item has an icon (≥ 64 px)", missing.is_empty(), "missing=%s" % [missing])


# --- 3–6. Game -----------------------------------------------------------------

func _test_game() -> void:
	var scene: Node = load(SCENE_PATH).instantiate()
	var stations: StationManager = scene.get_node("StationManager")
	var route: RouteData = stations.route.duplicate()
	route.stations = [stations.route.stations[1], stations.route.stations[0]]
	stations.route = route
	root.add_child(scene)
	await _wait(0.6)
	var station := stations.get_current_scene()
	var player: PlayerController = scene.get_node("Player")
	var backpack: InventoryComponent = scene.get_node("Player/Inventory")
	var train: TrainController = scene.get_node("Train")
	var ray: InteractionRay = scene.get_node("Player/Head/Camera3D/InteractionRay")
	var capture: MouseCapture = scene.get_node("MouseCapture")
	var hud: HUD = scene.get_node("HUD")
	var screen: InventoryScreen = scene.get_node("InventoryScreen")

	# 3. Wiring.
	_check("player has a 20-slot backpack, empty at start", backpack.slot_count == 20 and backpack.is_empty(), "")
	_check("train has 40-slot storage", train.storage != null and train.storage.slot_count == 40, "")
	var locker_it := train.storage_control
	_check("storage locker is interactable ('Open storage', press)", locker_it != null
			and locker_it.action == "Open storage" and locker_it.hold_time == 0.0 and not locker_it.one_shot, "")
	var locker := locker_it.get_parent() as Node3D
	# Eye height, 1 m in front of the doors (the locker's front is its local +Z).
	var eye := locker.global_position + Vector3(0, 1.62, 0)
	var from := eye + locker.global_basis.z * 1.0
	var hit := ray.probe(from, eye)
	_check("storage locker can be targeted from the aisle", hit == locker_it, "hit=%s from=%s" % [hit, from])

	# 4. Searching moves loot into the backpack.
	var safe := station.get_node("TicketOffice/Safe") as Node3D
	var safe_it := Interactable.find_on(safe)
	var safe_lc := LootContainer.find_on(safe_it)
	safe_lc.rng_seed = 5
	var expected := _copy(safe_lc.get_contents())
	_use(ray, safe_it, player)
	await _wait(0.2)
	var all_in := expected.all(func(s: ItemStack) -> bool: return backpack.count_item(s.item) == s.quantity)
	_check("searching moves the loot into the backpack", all_in and safe_lc.get_contents().is_empty()
			and safe_it.get_status_text() == "Searched", "%s → %s" % [expected, backpack.get_stacks()])
	_check("found panel lists what was taken", hud.is_loot_visible() and _loot_rows(hud).size() == expected.size()
			and _loot_rows(hud).all(func(r: Control) -> bool: return not r.get_meta(&"no_room")), "")

	# Full backpack: the rest stays in the container.
	backpack.clear()
	for i in backpack.slot_count - 1:
		backpack.add_item(_crowbar, 1)
	var fridge := station.get_node("Shop/DrinksFridge") as Node3D
	var fridge_it := Interactable.find_on(fridge)
	var fridge_lc := LootContainer.find_on(fridge_it)
	fridge_lc.rng_seed = _seed_where(fridge_lc.loot_table, func(c: Array[ItemStack]) -> bool: return c.size() >= 2)
	var fridge_loot := _copy(fridge_lc.get_contents())
	_use(ray, fridge_it, player)
	await _wait(0.2)
	var msg := hud.get_node("%MessageLabel") as Label
	var rows := _loot_rows(hud)
	var no_room_rows := rows.filter(func(r: Control) -> bool: return r.get_meta(&"no_room"))
	_check("full backpack: first stack fits, the rest stays in the fridge",
			backpack.count_item(fridge_loot[0].item) == fridge_loot[0].quantity and fridge_lc.get_contents().size() == fridge_loot.size() - 1,
			"loot=%s left=%s" % [fridge_loot, fridge_lc.get_contents()])
	_check("full backpack: HUD marks 'No room' rows and says why", no_room_rows.size() == fridge_loot.size() - 1
			and msg.text.begins_with("Backpack full") and msg.modulate.a > 0.5, "msg='%s' rows=%d" % [msg.text, rows.size()])
	_check("leftovers make the container usable again ('Take items', press)",
			fridge_it.can_interact() and fridge_it.action == LootContainer.TAKE_ACTION and fridge_it.hold_time == 0.0,
			"action='%s' can=%s" % [fridge_it.action, fridge_it.can_interact()])
	backpack.remove_item(_crowbar, 5)
	_use(ray, fridge_it, player)
	await _wait(0.2)
	var all_taken := fridge_loot.all(func(s: ItemStack) -> bool: return backpack.count_item(s.item) == s.quantity)
	_check("after making room, the rest can be taken", all_taken and fridge_lc.get_contents().is_empty()
			and fridge_it.get_status_text() == "Searched", "status='%s'" % fridge_it.get_status_text())
	fridge_lc.restock()
	_check("restock restores 'Search' and its hold time", fridge_it.action == "Search" and fridge_it.hold_time > 0.0, "")

	# 5. Inventory screen (real key events).
	backpack.clear()
	backpack.add_item(_beans, 3)
	backpack.add_item(_water, 2)
	backpack.add_item(_rounds, 24)
	backpack.add_item(_crowbar, 1)
	_check("screen starts closed", not screen.is_open() and not screen.visible, "")
	_key(KEY_TAB)
	await _wait(0.4)
	_check("Tab opens the inventory", screen.is_open() and screen.visible, "")
	_check("while open: player input, interaction ray and mouse capture are off, HUD hidden",
			not player.input_enabled and not ray.enabled and capture.ui_open and not capture.captured
			and not hud.visible, "")
	var grid := screen.get_node("%PlayerGrid") as GridContainer
	var slots: Array = grid.get_children()
	var s0 := slots[0] as ItemSlot
	_check("grid shows 20 slots, filled in order", slots.size() == 20 and s0.stack.item == _beans
			and (slots[2] as ItemSlot).stack.quantity == 24 and (slots[4] as ItemSlot).is_empty(), "")
	_check("capacity label", (screen.get_node("%PlayerCapacity") as Label).text == "4 / 20", "")
	_check("storage pane hidden when opened with Tab", not (screen.get_node("%StoragePane") as Control).visible, "")
	_check("first item is focused and selected", s0.has_focus() and s0.selected and screen.get_selection()[1] == 0, "")
	_check("details show name, category, description, stack and icon",
			_text(screen, "DetailName") == "Canned beans" and _text(screen, "DetailCategory") == "FOOD"
			and _text(screen, "DetailDescription") == _beans.description
			and _text(screen, "DetailStack").begins_with("Stack 3 / 10")
			and (screen.get_node("%DetailIcon") as TextureRect).texture == _beans.icon, _text(screen, "DetailStack"))
	_check("transfer button hidden without storage", not (screen.get_node("%TransferButton") as Control).visible, "")
	var vp := Rect2(Vector2.ZERO, grid.get_viewport_rect().size)
	var layout := screen.get_node("%Layout") as Control
	_check("inventory layout fits on screen", vp.encloses(layout.get_global_rect()), "%s in %s" % [layout.get_global_rect(), vp.size])

	_key(KEY_RIGHT)
	await _wait(0.1)
	_check("arrow keys move the selection", screen.get_selection()[1] == 1 and _text(screen, "DetailName") == "Bottled water",
			"sel=%s" % [screen.get_selection()])

	# Filter: Water only.
	var chips := screen.get_node("%Filters").get_children()
	(chips.filter(func(c: Button) -> bool: return c.text == "Water")[0] as Button).emit_signal("pressed")
	await _wait(0.05)
	_check("category filter dims other items", s0.filtered_out and not (slots[1] as ItemSlot).filtered_out
			and s0.disabled, "")
	(chips[0] as Button).emit_signal("pressed")
	await _wait(0.05)
	_check("'All' clears the filter", not s0.filtered_out, "")

	# Discard (Delete twice).
	screen.select_slot(backpack, 3)
	_key(KEY_DELETE)
	await _wait(0.05)
	var discard := screen.get_node("%DiscardButton") as Button
	_check("first Delete only arms the discard", backpack.has_item(_crowbar) and discard.text.begins_with("Press again"),
			"'%s'" % discard.text)
	_key(KEY_DELETE)
	await _wait(0.05)
	_check("second Delete discards the stack", not backpack.has_item(_crowbar)
			and _text(screen, "Feedback").begins_with("Discarded"), _text(screen, "Feedback"))
	screen.select_slot(backpack, 0)
	discard.emit_signal("pressed")
	await _wait(3.2)
	_check("an armed discard times out", backpack.count_item(_beans) == 3 and discard.text.begins_with("Discard"),
			"'%s'" % discard.text)

	_key(KEY_TAB)
	await _wait(0.3)
	_check("Tab closes the inventory and gives control back", not screen.is_open() and not screen.visible
			and player.input_enabled and ray.enabled and capture.captured and not capture.ui_open and hud.visible, "")
	_key(KEY_TAB)
	await _wait(0.3)
	_key(KEY_ESCAPE)
	await _wait(0.3)
	_check("Esc closes the inventory (and keeps the mouse captured)", not screen.is_open() and capture.captured, "")

	# 6. Storage.
	train.storage.clear()
	_use(ray, locker_it, player)
	await _wait(0.4)
	_check("storage locker opens the screen with the storage grid", screen.is_open()
			and (screen.get_node("%StoragePane") as Control).visible
			and screen.get_node("%StorageGrid").get_child_count() == 40, "")
	screen.select_slot(backpack, 2)  # 24 rounds
	var transfer := screen.get_node("%TransferButton") as Button
	_check("transfer button offers depositing", transfer.visible and transfer.text.begins_with("Deposit"), transfer.text)
	transfer.emit_signal("pressed")
	await _wait(0.05)
	_check("deposit moves the stack into storage", train.storage.count_item(_rounds) == 24 and not backpack.has_item(_rounds), "")
	var storage_slot := screen.get_node("%StorageGrid").get_child(0) as ItemSlot
	_check("storage grid shows the deposited stack", storage_slot.stack != null and storage_slot.stack.item == _rounds, "")
	screen.select_slot(train.storage, 0)
	_check("selecting a storage item offers taking it", transfer.text.ends_with("Take to backpack"), transfer.text)
	storage_slot.activated.emit(storage_slot)  # double-click / Enter
	await _wait(0.05)
	_check("double-click on a storage item takes it back", backpack.count_item(_rounds) == 24 and train.storage.is_empty(), "")
	(screen.get_node("%DepositAllButton") as Button).emit_signal("pressed")
	await _wait(0.05)
	_check("'Deposit everything' empties the backpack into storage", backpack.is_empty()
			and train.storage.count_item(_beans) == 3 and train.storage.count_item(_water) == 2
			and train.storage.count_item(_rounds) == 24, "%s" % [train.storage.get_stacks()])
	_check("storage capacity label", (screen.get_node("%StorageCapacity") as Label).text == "3 / 40", "")

	# Full storage.
	for i in 37:
		train.storage.add_item(_crowbar, 1)
	backpack.add_item(_scrap, 5)
	(screen.get_node("%DepositAllButton") as Button).emit_signal("pressed")
	await _wait(0.05)
	_check("full storage: nothing lost, feedback shown", backpack.count_item(_scrap) == 5
			and _text(screen, "Feedback") == "Storage is full.", _text(screen, "Feedback"))
	_key(KEY_ESCAPE)
	await _wait(0.3)
	_check("storage screen closes with Esc", not screen.is_open() and capture.captured, "")

	scene.queue_free()
	await process_frame


# --- Helpers -------------------------------------------------------------------

func _copy(stacks: Array[ItemStack]) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	for s in stacks:
		out.append(ItemStack.new(s.item, s.quantity))
	return out


func _loot_rows(hud: HUD) -> Array:
	return hud.get_node("%LootRows").get_children().filter(func(r: Node) -> bool: return not r.is_queued_for_deletion())


func _text(screen: InventoryScreen, node: String) -> String:
	return (screen.get_node("%" + node) as Label).text


## A real key press + release through the input pipeline (_input, GUI, _unhandled_input).
func _key(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()


## Does what InteractionRay does when an interaction completes.
func _use(ray: InteractionRay, it: Interactable, player: Node) -> void:
	if it.interact(player):
		ray.interacted.emit(it)


func _seed_where(table: LootTable, pred: Callable) -> int:
	for s in range(1, 10000):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		if pred.call(table.roll(rng)):
			return s
	return 1


func _wait(seconds: float) -> void:
	for i in maxi(1, int(seconds * Engine.physics_ticks_per_second)):
		await physics_frame


func _check(test_name: String, passed: bool, detail: String) -> void:
	if passed:
		print("  PASS  %s   %s" % [test_name, detail])
	else:
		_failures += 1
		print("  FAIL  %s   %s" % [test_name, detail])
