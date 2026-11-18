extends SceneTree
## Automated test for Milestone 6: loot containers.
##   Godot_console.exe --headless --path . --script res://tests/test_loot.gd
##
## 1. Item definitions (resources/items/) are complete and consistent.
## 2. Loot tables (resources/loot_tables/) only reference valid items with
##    sane quantities, and together can drop every item.
## 3. Rolling: empty chance, pick counts, quantities and weights behave as
##    configured over thousands of seeded rolls; same seed = same loot.
## 4. Every Grey Hollow container has a LootContainer with the right table.
## 5. In the real game scene: searching shows what was found (HUD panel) or
##    "Nothing useful here.", the prompt changes to "Searched" / "Empty",
##    restock() rolls again. (Moving loot into the backpack is covered by
##    test_inventory.gd.)

const ITEMS_DIR := "res://resources/items/"
const TABLES_DIR := "res://resources/loot_tables/"
const SCENE_PATH := "res://scenes/main/game.tscn"
const ROLLS := 4000
## Which table each container prop uses (prop scene file → table file).
const EXPECTED_TABLES := {
	"crate": "crate", "crate_small": "crate", "suitcase": "luggage",
	"luggage_cart": "luggage", "vending_machine": "vending",
	"filing_cabinet": "office", "safe": "safe", "storage_locker": "locker",
	"drinks_fridge": "drinks_fridge", "cash_register": "office",
	"workbench": "workshop", "car_wreck": "workshop",
}
## The brief's starting items, by category.
const REQUIRED_CATEGORIES := [
	ItemData.Category.FOOD, ItemData.Category.WATER, ItemData.Category.MEDICAL,
	ItemData.Category.MATERIAL, ItemData.Category.AMMO, ItemData.Category.WEAPON,
]

var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var items := _test_items()
	var tables := _test_tables(items)
	_test_rolling(tables)
	await _test_game(tables)

	print("")
	if _failures == 0:
		print("ALL LOOT TESTS PASSED")
	else:
		print("%d LOOT TEST(S) FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


# --- 1. Items ------------------------------------------------------------------

func _test_items() -> Dictionary:
	var items := {}
	var problems: Array[String] = []
	for file in _resource_files(ITEMS_DIR):
		var item := load(ITEMS_DIR + file) as ItemData
		if item == null:
			problems.append("%s isn't an ItemData" % file)
			continue
		var stem := file.get_basename()
		if String(item.id) != stem:
			problems.append("%s: id '%s' doesn't match file name" % [file, item.id])
		if items.has(item.id):
			problems.append("duplicate id %s" % item.id)
		if item.display_name.strip_edges().is_empty() or item.description.strip_edges().length() < 10:
			problems.append("%s: missing name or description" % stem)
		if item.max_stack < 1:
			problems.append("%s: max_stack %d" % [stem, item.max_stack])
		if item.category == ItemData.Category.WEAPON and item.max_stack != 1:
			problems.append("%s: weapons shouldn't stack" % stem)
		items[item.id] = item
	_check("item definitions valid", problems.is_empty() and items.size() >= 7,
			"%d items %s" % [items.size(), problems])

	var categories := {}
	for item: ItemData in items.values():
		categories[item.category] = true
	var missing := REQUIRED_CATEGORIES.filter(func(c: int) -> bool: return not categories.has(c))
	_check("food, water, medical, materials, ammo and weapons all exist", missing.is_empty(),
			"missing=%s" % [missing.map(func(c: int) -> String: return ItemData.CATEGORY_NAMES[c])])
	var has_scrap := items.has(&"scrap_metal") and items.has(&"battery")
	_check("scrap metal and batteries exist (train repairs/power later)", has_scrap, "")
	return items


# --- 2. Tables -----------------------------------------------------------------

func _test_tables(items: Dictionary) -> Dictionary:
	var tables := {}
	var problems: Array[String] = []
	var droppable := {}
	for file in _resource_files(TABLES_DIR):
		var table := load(TABLES_DIR + file) as LootTable
		var stem := file.get_basename()
		if table == null:
			problems.append("%s isn't a LootTable" % file)
			continue
		tables[stem] = table
		if table.entries.is_empty() or table.min_picks > table.max_picks:
			problems.append("%s: no entries or picks %d>%d" % [stem, table.min_picks, table.max_picks])
		if table.empty_chance < 0.0 or table.empty_chance > 0.6:
			problems.append("%s: empty_chance %.2f" % [stem, table.empty_chance])
		var seen := {}
		for e in table.entries:
			if e == null or e.item == null or not items.has(e.item.id):
				problems.append("%s: entry with unknown item" % stem)
				continue
			if seen.has(e.item.id):
				problems.append("%s: %s listed twice" % [stem, e.item.id])
			seen[e.item.id] = true
			droppable[e.item.id] = true
			if e.weight <= 0.0 or e.min_quantity < 1 or e.min_quantity > e.max_quantity \
					or e.max_quantity > e.item.max_stack:
				problems.append("%s/%s: weight %.1f qty %d-%d stack %d" % [stem, e.item.id, e.weight,
						e.min_quantity, e.max_quantity, e.item.max_stack])
	_check("loot tables valid", problems.is_empty() and tables.size() >= 5,
			"%d tables %s" % [tables.size(), problems])
	var never := items.keys().filter(func(id: StringName) -> bool: return not droppable.has(id))
	_check("every item can be found somewhere", never.is_empty(), "never dropped=%s" % [never])
	return tables


# --- 3. Rolling ----------------------------------------------------------------

func _test_rolling(tables: Dictionary) -> void:
	for stem: String in tables:
		var table: LootTable = tables[stem]
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234
		var empty := 0
		var bad: Array[String] = []
		var hits := {}
		for i in ROLLS:
			var stacks := table.roll(rng)
			if stacks.is_empty():
				empty += 1
				continue
			if stacks.size() < mini(table.min_picks, table.entries.size()) or stacks.size() > table.max_picks:
				bad.append("picks=%d" % stacks.size())
			var ids := {}
			for s in stacks:
				if ids.has(s.item.id):
					bad.append("duplicate %s" % s.item.id)
				ids[s.item.id] = true
				hits[s.item.id] = hits.get(s.item.id, 0) + 1
				var e := _entry_for(table, s.item)
				if s.quantity < e.min_quantity or s.quantity > e.max_quantity:
					bad.append("%s qty %d" % [s.item.id, s.quantity])
		var rate := float(empty) / ROLLS
		var all_hit := table.entries.all(func(e: LootEntry) -> bool: return hits.has(e.item.id))
		_check("roll '%s': empty rate, picks, quantities, coverage" % stem,
				absf(rate - table.empty_chance) < 0.035 and bad.is_empty() and all_hit,
				"empty %.3f (want %.2f) bad=%s all_items=%s" % [rate, table.empty_chance, bad.slice(0, 3), all_hit])

	# Weighting: in the vending table food and water are 5:5; in the fridge water is 8 vs food 2.
	var fridge: LootTable = tables.get("drinks_fridge")
	if fridge:
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		var first_water := 0
		var first_total := 0
		var single := fridge.duplicate(true) as LootTable
		single.min_picks = 1
		single.max_picks = 1
		single.empty_chance = 0.0
		for i in ROLLS:
			var s := single.roll(rng)
			first_total += 1
			if s[0].item.id == &"bottled_water":
				first_water += 1
		var share := float(first_water) / first_total
		_check("weights respected (fridge water ≈ 80%)", absf(share - 0.8) < 0.03, "water=%.3f" % share)

	var a := RandomNumberGenerator.new()
	a.seed = 777
	var b := RandomNumberGenerator.new()
	b.seed = 777
	var t: LootTable = tables["safe"]  # never empty, so the comparison means something
	var ra := t.roll(a).map(func(s: ItemStack) -> String: return str(s))
	var rb := t.roll(b).map(func(s: ItemStack) -> String: return str(s))
	_check("same seed → same loot", ra == rb and not ra.is_empty(), "%s / %s" % [ra, rb])


# --- 4 + 5. Game ---------------------------------------------------------------

func _test_game(tables: Dictionary) -> void:
	var scene: Node = load(SCENE_PATH).instantiate()
	var stations: StationManager = scene.get_node("StationManager")
	var route: RouteData = stations.route.duplicate()
	route.stations = [stations.route.stations[1], stations.route.stations[0]]
	stations.route = route
	root.add_child(scene)
	var ray: InteractionRay = scene.get_node("Player/Head/Camera3D/InteractionRay")
	var hud: HUD = scene.get_node("HUD")
	await _wait(0.6)
	var station := stations.get_current_scene()
	_check("parked at Grey Hollow", stations.current_station.id == &"grey_hollow", "")

	# 4. Every container is wired to the right table.
	var wrong: Array[String] = []
	var containers: Array[Node3D] = []
	for n in get_nodes_in_group("loot_container"):
		if station.is_ancestor_of(n):
			containers.append(n)
	for c in containers:
		var it := Interactable.find_on(c)
		var lc := LootContainer.find_on(it)
		var prop := c.scene_file_path.get_file().get_basename()
		if lc == null or lc.loot_table == null \
				or lc.loot_table.resource_path.get_file().get_basename() != EXPECTED_TABLES.get(prop, "?"):
			wrong.append("%s/%s" % [c.get_parent().name, c.name])
	_check("all 22 containers have a LootContainer with the right table",
			containers.size() == 22 and wrong.is_empty(), "n=%d wrong=%s" % [containers.size(), wrong])

	# How much a typical visit yields (sanity, printed for tuning).
	var total_items := 0
	var total_empty := 0
	var visits := 300
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for v in visits:
		for c in containers:
			var stacks := LootContainer.find_on(Interactable.find_on(c)).loot_table.roll(rng)
			if stacks.is_empty():
				total_empty += 1
			for s in stacks:
				total_items += s.quantity
	var empty_per_visit := float(total_empty) / visits
	_check("a visit has a mix of full and empty containers", empty_per_visit > 2.0 and empty_per_visit < 9.0,
			"avg %.1f empty of 22, %.1f items per visit" % [empty_per_visit, float(total_items) / visits])

	# 5. Searching through the game's interaction hook.
	var safe := station.get_node("TicketOffice/Safe") as Node3D
	var safe_it := Interactable.find_on(safe)
	var safe_lc := LootContainer.find_on(safe_it)
	safe_lc.rng_seed = 5
	var expected := safe_lc.get_contents().duplicate()
	_check("contents can be inspected before searching, and don't mark it searched",
			not expected.is_empty() and not safe_lc.is_searched() and not safe_it.used, "%s" % [expected])
	var rolled_again := safe_lc.get_contents()
	_check("contents are rolled once (stable until restock)", rolled_again == expected, "")

	_use(ray, safe_it, scene)
	await _wait(0.6)
	var panel := hud.get_node("%LootPanel") as Control
	var rows := hud.get_node("%LootRows") as Container
	var header := (hud.get_node("%LootHeader") as Label).text
	var row_texts: Array[String] = []
	for r in rows.get_children():
		row_texts.append((r.get_child(1) as Label).text)
	var want: Array[String] = []
	for s: ItemStack in expected:
		want.append(s.get_label())
	_check("search shows the found items in the HUD", hud.is_loot_visible() and header == "FOUND IN SAFE"
			and row_texts == want, "header='%s' rows=%s want=%s" % [header, row_texts, want])
	var vp := Rect2(Vector2.ZERO, panel.get_viewport_rect().size)
	var rect := panel.get_global_rect()
	_check("found panel fits on screen, right of the crosshair", vp.encloses(rect) and rect.position.x > vp.size.x * 0.55,
			"rect=%s viewport=%s" % [rect, vp.size])
	_check("searched container reads 'Searched' and its items were taken",
			safe_it.get_status_text() == "Searched" and safe_lc.get_contents().is_empty(),
			"'%s'" % safe_it.get_status_text())
	await _wait(5.0)
	_check("found panel fades out after a few seconds", not hud.is_loot_visible() and not panel.visible, "")

	# An empty container.
	var fridge := station.get_node("Shop/DrinksFridge") as Node3D
	var fridge_it := Interactable.find_on(fridge)
	var fridge_lc := LootContainer.find_on(fridge_it)
	fridge_lc.rng_seed = _seed_where(fridge_lc.loot_table, true)
	_use(ray, fridge_it, scene)
	await _wait(0.2)
	var msg := hud.get_node("%MessageLabel") as Label
	_check("empty container: 'Nothing useful here.' and prompt says 'Empty'",
			msg.text == "Nothing useful here." and msg.modulate.a > 0.5 and fridge_it.get_status_text() == "Empty"
			and not hud.is_loot_visible(), "msg='%s' status='%s'" % [msg.text, fridge_it.get_status_text()])

	# take_all on a container that still holds something, then restock.
	var vending := station.get_node("TicketOffice/VendingMachine") as Node3D
	var vending_lc := LootContainer.find_on(Interactable.find_on(vending)) if vending else null
	if vending_lc:
		vending_lc.rng_seed = _seed_where(vending_lc.loot_table, false)
		var inside := vending_lc.get_contents().size()
		var taken := vending_lc.take_all()
		_check("take_all empties the container", inside > 0 and taken.size() == inside
				and vending_lc.get_contents().is_empty(), "taken=%d" % taken.size())
	else:
		_check("take_all empties the container", false, "no TicketOffice/VendingMachine")
	safe_lc.rng_seed = 0
	safe_lc.restock()
	_check("restock makes it searchable again with fresh loot", safe_it.can_interact() and not safe_lc.is_searched()
			and safe_it.get_status_text() == "", "")

	scene.queue_free()
	await process_frame


## Does what InteractionRay does when a hold completes (the ray itself is
## covered by test_interaction.gd).
func _use(ray: InteractionRay, it: Interactable, scene: Node) -> void:
	if it.interact(scene.get_node("Player")):
		ray.interacted.emit(it)


func _seed_where(table: LootTable, want_empty: bool) -> int:
	for s in range(1, 10000):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		if table.roll(rng).is_empty() == want_empty:
			return s
	return 1


func _entry_for(table: LootTable, item: ItemData) -> LootEntry:
	for e in table.entries:
		if e.item == item:
			return e
	return null


func _resource_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres"):
			out.append(f)
	return out


func _wait(seconds: float) -> void:
	for i in maxi(1, int(seconds * Engine.physics_ticks_per_second)):
		await physics_frame


func _check(test_name: String, passed: bool, detail: String) -> void:
	if passed:
		print("  PASS  %s   %s" % [test_name, detail])
	else:
		_failures += 1
		print("  FAIL  %s   %s" % [test_name, detail])
