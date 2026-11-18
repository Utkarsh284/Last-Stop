# Last Stop

First-person post-apocalyptic train survival game. Godot 4.7 · GDScript · Compatibility renderer · Windows.

## Running

Engine: `../tools/godot/Godot_v4.7.2-stable_win64.exe` (portable, standard build, no .NET).

- **Editor:** run the engine exe → Project Manager → **Import** → select this folder's `project.godot`.
- **Play from editor:** F5 runs the game (`scenes/main/game.tscn`). F6 runs the open scene, e.g. `movement_sandbox.tscn` for tuning movement.
- **Play from terminal:** `Godot_v4.7.2-stable_win64_console.exe --path <this folder>`

## Input Map

| Action         | Key   |
|----------------|-------|
| move_forward   | W     |
| move_back      | S     |
| move_left      | A     |
| move_right     | D     |
| sprint         | Shift |
| jump           | Space |
| interact       | E     |
| inventory      | Tab   |
| pause          | Esc   |

Keys are bound by **physical** keycode, so the layout works on AZERTY and other keyboards. Mouse look is handled in code, not through the Input Map.

## Folder plan

Folders are created when a milestone first needs them, never left empty.

| Folder                 | Contents                                            | Milestone |
|------------------------|-----------------------------------------------------|-----------|
| `scenes/main/`         | `game.tscn` (main scene), `movement_sandbox.tscn` (dev) | 0 ✔ |
| `scripts/main/`        | Scene composition scripts (`game.gd` wires systems together) | 0 ✔ |
| `scenes/player/`, `scripts/player/` | Player controller and components       | 1 ✔       |
| `tests/`               | Headless automated tests (excluded from export)     | 1 ✔       |
| `scenes/train/`, `scenes/train/props/` | Train carriage and its furniture    | 2 ✔       |
| `scripts/train/`       | `TrainController` (journey, doors, departure lever) | 3 ✔       |
| `scenes/stations/`, `scripts/stations/` | Station scenes + `Station` base script | 3–4 ✔ |
| `scenes/environment/kit/` | Modular 2 m wall pieces (plaster, brick × 7 kinds) | 4 ✔ |
| `data/stations/`       | `StationData` per station + `main_route.tres`       | 3 ✔       |
| `scripts/environment/` | `TravelScenery`, `FlickerLight`                     | 3–4 ✔     |
| `scenes/environment/`  | Railway track + reusable props (crates, drums, lamps) | 2 ✔ (more in 4) |
| `assets/materials/`    | Shared procedural materials (`.tres`)               | 2 ✔       |
| `scripts/interaction/` | `Interactable` component, `InteractionRay`          | 5 ✔       |
| `scripts/items/`, `resources/items/` | `ItemData`, `ItemStack`; one `.tres` per item | 6 ✔ |
| `scripts/loot/`, `resources/loot_tables/` | `LootTable`, `LootEntry`, `LootContainer`; one `.tres` per container theme | 6 ✔ |
| `scripts/inventory/`   | `InventoryComponent` (backpack and train storage)   | 7 ✔       |
| `scripts/survival/`    | Health / hunger / thirst / stamina                  | 8         |
| `scenes/enemies/`, `scripts/enemies/` | Enemy creature and AI                | 9         |
| `scripts/systems/`     | `StationManager`, `StationData`, `RouteData`, `MouseCapture`; later GameManager, SaveManager | 3 ✔ (more in 10, 12) |
| `scenes/ui/`, `scripts/ui/` | HUD (basic in 3), `InventoryScreen` + `ItemSlot`, menus | 3 ✔, 7 ✔ (more in 11) |
| `ui/themes/`, `ui/icons/items/` | `game_theme.tres` (buttons, chips, panes); one SVG icon per item | 7 ✔ (more in 11) |
| `assets/audio/`        | Sound effects / ambience                            | 11        |

## Player

`scenes/player/player.tscn` — `CharacterBody3D` (capsule 1.8 m × 0.35 m, eyes at 1.62 m).

- `PlayerController` (`scripts/player/player_controller.gd`): walk 4 m/s, sprint 6.8 m/s (forward only), 1.1 m jump, coyote time + jump buffer. Tunables are exported in the Inspector.
  Hooks for later systems: `can_sprint`, `input_enabled`, `teleport()`, signals `sprint_state_changed`, `jumped`, `landed`.
- `MouseLook` (`scripts/player/mouse_look.gd`, on `Head`): sensitivity, invert Y, pitch clamp ±85°. Only active while the mouse is captured.

**Stairs:** CharacterBody3D can't step up ledges, so stairs are visual steps plus an invisible sloped `StaticBody3D` (see `Level/Stairs` in the sandbox). Use the same pattern for all stairs.

## Train (Milestone 2)

`scenes/train/train.tscn`: one 18 m carriage, interior 2.8 m wide, floor 1.2 m above the rails.

| Zone (front → rear) | Train-local Z | Contents |
|---|---|---|
| Control cabin | −9 … −5.6 | Console (`Instruments/DepartureLever`), driver seat, windshield |
| Entrance | −5.6 … −3 | Side doors both sides with steps, fire extinguisher |
| Living / sleeping | −3 … 3.3 | Bunk bed, barrel stove, table, crates |
| Storage | 3.3 … 9 | Shelving, workbench, fuel drums, `StorageLocker`, sealed rear door |

- Root script: `TrainController` (see Journey below). Exterior sliding `Doors`, an `AboardArea`, and the departure lever (an `Interactable`, see Interaction below).
- `Shell` is one `CSGCombiner3D` (walls, floor, ceiling, partitions, cut-outs) with collision.
- `PlayerSpawn` (Marker3D) is where the player starts.
- Props are separate scenes, so the console, locker and workbench can get interaction components later without touching the train.
- Small props stop drawing beyond 15 m, and tiny ones cast no shadows (performance).

## Journey (Milestone 3)

The train **never moves**. The world scrolls past it ("treadmill"), so the player walks around inside at full speed with no moving-platform physics.

1. Look at the red departure lever on the console and press **E** → `TrainController.request_departure()`. Refused (with a HUD message) unless the player is aboard. Milestone 10 adds fuel checks in `get_departure_block_reason()`.
2. Doors close → the train accelerates to 16 m/s (58 km/h). Each physics frame it emits `travelled(distance)`.
3. `StationManager` moves the departing station away and frees it at 300 m. `TravelScenery` scrolls the ground/track (wrapping every 60 m) and streams poles, dead trees and rocks out of the fog.
4. After `RouteData.travel_seconds` (and once cruising, with the old station gone), the next station spawns exactly one braking distance ahead and the train brakes along `v = √(2·a·d)`, stopping exactly on its `TrainStop`.
5. Doors open; HUD shows the station title card.

**Adding a station:** build a scene whose root uses `scripts/stations/station.gd`, with a `TrainStop` Marker3D at the train's parked origin, track along Z and platforms on +X (edge at x = 1.7, height 0.35). Create a `StationData` `.tres` in `data/stations/` and add it to `main_route.tres`.

Current route: **Mile 214 Siding** (start) ⇄ **Grey Hollow**.

## Grey Hollow (Milestone 4)

Abandoned station on a 0.35 m concrete plinth (x 1.7…31, z −32…32, station-local; track along Z, platform on +X):

| Area | Where | Notes |
|---|---|---|
| Platform | x 1.7…9 | Canopy with a collapsed end you can **walk up onto the roof** (hidden crate up there), benches, signs, luggage cart |
| Ticket office | x 9–17, z −14…2 | Waiting hall with a caved-in roof corner (sunbeam + dust), departure board; ticket counter; back office (desk, filing cabinets, safe, locker) |
| Shop | x 9–17, z 6…14 | Smashed front window, shelves, drinks fridge, counter + till, failing fluorescent light; storeroom behind |
| Signal box | x 10–16, z 18…24 | Roofless ruin, rubble, old signal levers, sapling |
| Goods warehouse | x 22–30, z −22…−6 | Brick; 4 m gateway, forklift wreck, pallets, workbench; storeroom lit by a red emergency light |
| Yard / fields | rest | Car wreck, broken fence, fallen pole, grass, bushes, ivy, dead trees; invisible bounds at x −20…52, z ±55 |

- **22 loot containers** are tagged with the `loot_container` group and can be searched (Milestone 5); Milestone 6 puts loot in them. All are reachable on foot (verified by navmesh in `test_station.gd`).
- The scripted tour of every building is 165 m (≈ 41 s of walking); with searching, a visit takes roughly 3–5 minutes.
- `Bounds` (invisible walls) only collide while the train is parked there (`Station.on_train_arrived/departing`).
- **Kit:** `scenes/environment/kit/wall_<plaster|brick>_<wall|door|window|opening|ticket|broken|low>.tscn`. 2 m × 3 m × 0.2 m, origin at the bottom centre, wall along local X. Door openings 1.2 × 2.3 m; window sills 1.0 m (not climbable).

## Interaction (Milestone 5)

Look at something within **2.2 m** and the HUD shows what it is and what **E** does.

- **`Interactable`** (`scripts/interaction/interactable.gd`) — a plain `Node` added as a child of any collision object. Exports: `display_name`, `action`, `hold_time` (0 = press, otherwise hold E), `one_shot` + `used_label`, `enabled` + `disabled_reason`. Signals `interacted(interactor)` and `changed`. It registers itself as metadata on its parent, so the parent needs no script.
- **`InteractionRay`** (`scripts/interaction/interaction_ray.gd`, on `Player/Head/Camera3D`) — ray from the camera each physics frame. Solid geometry (layer 1 `world`) blocks it, so nothing works through walls. Small parts use an invisible `Area3D` hotspot on layer 2 `interaction` (only the ray sees it). Signals `focus_changed`, `hold_progress_changed`, `interacted`. `probe(from, to)` runs the same check from any point (used by the tests).
- After an interaction, or when you look at something new while already holding E, you have to release E before the next one. One press never does two things.
- Releasing the mouse (Esc) turns the ray off.
- HUD: object name, key, action, hold bar (if it's a hold), and an amber crosshair when the object can be used. Objects you can't use right now show a grey status instead of the key ("Searched", "Train in motion").

| Object | Action | Notes |
|---|---|---|
| Departure lever (train console) | Press: "Depart for <next station>" | Owned by `TrainController.departure_control`. Swings forward while under way; disabled with "Train in motion". |
| 22 Grey Hollow loot containers | Hold: "Search" (0.8 s small crate … 2.5 s safe) | One-shot → "Searched" or "Empty". See Loot below. Becomes a press, "Take items", if the backpack was full. |
| Storage locker (train, storage area) | Press: "Open storage" | Owned by `TrainController.storage_control`; opens the inventory with train storage. |

**Making something interactable:** add an `Interactable` child to its `StaticBody3D`. For a part too small to aim at, add an `Area3D` with `collision_layer = 2`, `collision_mask = 0`, `monitoring = false` and a slightly oversized shape, then put the `Interactable` under it. Connect `interacted` wherever the behaviour lives. In the scene builder, use `interactable()` and `interaction_hotspot()`. Containers made with `loot()` get one automatically (names and search times are in `LOOT_INFO`).

## Loot (Milestone 6)

Searching a container shows what was inside in a panel on the right ("FOUND IN SAFE" · "8 × Pistol rounds   Ammunition"), or "Nothing useful here." if it was empty. The prompt then reads **Searched** or **Empty**.

- **`ItemData`** (`scripts/items/item_data.gd`) — Resource: `id` (= file name, used by saves), `display_name`, `description`, `category` (Food, Water, Medical, Materials, Ammunition, Weapons), `max_stack`, `icon` (SVG in `ui/icons/items/`). **`ItemStack`** = item + quantity.
- **`LootTable`** (`scripts/loot/loot_table.gd`) — Resource: `entries` (`LootEntry`: item, weight, min/max quantity), `empty_chance`, `min_picks`/`max_picks`. A roll draws different entries by weight (never the same item twice) and caps quantities at the stack size.
- **`LootContainer`** (`scripts/loot/loot_container.gd`) — a `Node` next to the container's `Interactable`. Rolls its table the first time it's searched (`rng_seed` ≠ 0 makes it reproducible). API: `search()`, `get_contents()`, `take_all()`, `put_back()`, `restock()`, signal `searched`. `LootContainer.find_on(interactable)` finds it. `game.gd` calls `search()` when the ray reports a completed interaction.
- Since Milestone 7 the found items go straight into the backpack (see Inventory below).

| Item (`resources/items/`) | Category | Stack |
|---|---|---|
| Canned beans, Bottled water | Food, Water | 10 |
| Bandages / First aid kit | Medical | 10 / 3 |
| Scrap metal / Battery | Materials | 50 / 10 |
| Pistol rounds | Ammunition | 60 |
| Crowbar, Old revolver | Weapons | 1 |

| Table (`resources/loot_tables/`) | Used by | Empty | Mostly |
|---|---|---|---|
| `vending` | Vending machine | 25 % | food, water |
| `drinks_fridge` | Drinks fridge | 20 % | water |
| `luggage` | Suitcases, luggage cart | 30 % | food, water, bandages |
| `office` | Filing cabinets, till | 45 % | a battery or bandages |
| `safe` | Safe | never | ammo, batteries, first aid kit, sometimes the revolver |
| `locker` | Lockers | 20 % | medical, ammo, sometimes a crowbar |
| `crate` | Crates | 25 % | scrap, food, water |
| `workshop` | Workbench, car wreck | 10 % | scrap, batteries |

A Grey Hollow visit averages about 5 empty containers out of 22. **Adding an item:** create an `ItemData` `.tres` in `resources/items/` and add a `LootEntry` for it to one or more tables (in the Inspector). **New container type:** add it to `LOOT_INFO` in the scene builder with a table name.

## Inventory (Milestone 7)

**Tab** opens the backpack anywhere; the **storage locker** at the back of the train opens the backpack *and* the train's storage side by side. Tab or Esc closes it. While it's open the player can't move, the interaction ray is off, the HUD is hidden and the mouse is free; the world keeps running.

- **`InventoryComponent`** (`scripts/inventory/inventory_component.gd`) — a `Node` with `slot_count` slots. Identical items stack up to `ItemData.max_stack`, extra goes to the next empty slot. API: `add_item()` / `add_stacks()` (return what didn't fit), `remove_item()`, `remove_from_slot()`, `transfer_slot()` / `transfer_all()` (to another inventory, only what fits), `count_item()`, `has_item()`, `get_capacity_for()`, `get_slot()`, `get_stacks()`, `clear()`; signal `changed`. Knows nothing about specific items.
- **Backpack:** `Player/Inventory`, 20 slots. **Train storage:** `Train/Storage`, 40 slots (`TrainController.storage`).
- **Picking up:** searching a container moves everything into the backpack. If it doesn't all fit, the rest goes back in the container (`LootContainer.put_back()`), the found panel lists it dimmed as "No room", the HUD says "Backpack full…", and the container's prompt becomes **E Take items** (a press, no re-search) until it's emptied.
- **`InventoryScreen`** (`scenes/ui/inventory_screen.tscn`) — shows inventories, never stores items. Category filter chips (All, Food, Water, Medical, Materials, Ammo, Weapons) dim non-matching items. The details pane shows icon, name, category, description and stack (`7 / 10 · 7 in backpack`).
  - Click selects · **double-click / Enter** moves the stack to the other side (storage mode) · arrows browse · **Delete** (twice) or *Discard* (twice, within 3 s) destroys the stack.
  - Storage mode adds *Deposit in storage →* / *← Take to backpack* and *Deposit everything*. If the other side is full only what fits moves, with a message.
- **`ItemSlot`** (`scripts/ui/item_slot.gd`) — one self-drawn `Button` per slot: icon, quantity (amber when the stack is full), category strip, hover / focus / selected states, press animation.
- **Theme:** `ui/themes/game_theme.tres` — `Button`, `ChipButton`, `Pane`, `Well` styles, meant to be reused by the menus in Milestone 11.
- `game.gd` owns opening: `open_inventory(storage = null)`. `MouseCapture.ui_open` stops Esc/click/Alt-Tab from fighting the screen over the cursor.

**Adding an item:** also draw a 128 × 128 SVG in `ui/icons/items/<id>.svg` (stroke `#EBE3D1`, ~5 px, round caps) and set it as the item's `icon`.

### Scene builder

The train, props, kit, track, roadside scenery, station scenes and materials are generated by `../tools/scene_builders/build_scenes.gd`:
```
Godot_v4.7.2-stable_win64_console.exe --path . --script ../tools/scene_builders/build_scenes.gd
```
Run it **without `--headless`** (a window flashes briefly): the headless renderer discards MultiMesh data, so grass and sleepers would be saved empty. The builder refuses to run headless.

Regenerating changes every node's random `unique_id`, even in scenes whose content didn't change. Discard files where that is the only change before committing.

On save, static meshes that share a material are merged into one mesh per material (fewer draw calls). Moving parts (doors), levers and the flickering tube are kept separate.
**It overwrites the generated scenes and materials.** Once you edit a generated scene by hand in the editor, keep editing there and don't re-run the builder.

## Tests

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_player_movement.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_train.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_journey.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_station.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_interaction.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_loot.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_inventory.gd
```
Exit code 0 = all passed.

## Dev flags

`-- --capture=<file.png>` (on `movement_sandbox.tscn`): saves a screenshot after 30 frames and quits. Used to verify rendering from the command line.
