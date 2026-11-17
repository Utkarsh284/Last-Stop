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
| `scripts/train/`       | `TrainController`, temporary `DepartureTrigger`     | 3 ✔       |
| `scenes/stations/`, `scripts/stations/` | Station scenes + `Station` base script | 3–4 ✔ |
| `scenes/environment/kit/` | Modular 2 m wall pieces (plaster, brick × 7 kinds) | 4 ✔ |
| `data/stations/`       | `StationData` per station + `main_route.tres`       | 3 ✔       |
| `scripts/environment/` | `TravelScenery`, `FlickerLight`                     | 3–4 ✔     |
| `scenes/environment/`  | Railway track + reusable props (crates, drums, lamps) | 2 ✔ (more in 4) |
| `assets/materials/`    | Shared procedural materials (`.tres`)               | 2 ✔       |
| `scripts/interaction/` | Interactable component, interaction raycast         | 5         |
| `scenes/items/`, `resources/items/`, `resources/loot_tables/` | Item definitions and loot | 6–7 |
| `scripts/inventory/`   | Inventory component                                 | 7         |
| `scripts/survival/`    | Health / hunger / thirst / stamina                  | 8         |
| `scenes/enemies/`, `scripts/enemies/` | Enemy creature and AI                | 9         |
| `scripts/systems/`     | `StationManager`, `StationData`, `RouteData`, `MouseCapture`; later GameManager, SaveManager | 3 ✔ (more in 10, 12) |
| `scenes/ui/`, `scripts/ui/` | HUD (basic in 3), inventory, menus             | 3 ✔ (more in 7, 11) |
| `ui/themes/`, `ui/icons/` | Shared theme, item icons                         | 7, 11     |
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

- Root script: `TrainController` (see Journey below). Exterior sliding `Doors`, an `AboardArea`, and a temporary `DepartureTrigger` at the controls.
- `Shell` is one `CSGCombiner3D` (walls, floor, ceiling, partitions, cut-outs) with collision.
- `PlayerSpawn` (Marker3D) is where the player starts.
- Props are separate scenes, so the console, locker and workbench can get interaction components later without touching the train.
- Small props stop drawing beyond 15 m, and tiny ones cast no shadows (performance).

## Journey (Milestone 3)

The train **never moves**. The world scrolls past it ("treadmill"), so the player walks around inside at full speed with no moving-platform physics.

1. At the controls, **E** → `TrainController.request_departure()`. Refused (with a HUD message) unless the player is aboard. Milestone 10 adds fuel checks in `get_departure_block_reason()`.
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

- **22 loot containers** are tagged with the `loot_container` group (interactive from Milestones 5–6). All are reachable on foot (verified by navmesh in `test_station.gd`).
- The scripted tour of every building is 165 m (≈ 41 s of walking); with searching, a visit takes roughly 3–5 minutes.
- `Bounds` (invisible walls) only collide while the train is parked there (`Station.on_train_arrived/departing`).
- **Kit:** `scenes/environment/kit/wall_<plaster|brick>_<wall|door|window|opening|ticket|broken|low>.tscn`. 2 m × 3 m × 0.2 m, origin at the bottom centre, wall along local X. Door openings 1.2 × 2.3 m; window sills 1.0 m (not climbable).

### Scene builder

The train, props, kit, track, roadside scenery, station scenes and materials are generated by `../tools/scene_builders/build_scenes.gd`:
```
Godot_v4.7.2-stable_win64_console.exe --path . --script ../tools/scene_builders/build_scenes.gd
```
Run it **without `--headless`** (a window flashes briefly): the headless renderer discards MultiMesh data, so grass and sleepers would be saved empty. The builder refuses to run headless.

On save, static meshes that share a material are merged into one mesh per material (fewer draw calls). Moving parts (doors), levers and the flickering tube are kept separate.
**It overwrites the generated scenes and materials.** Once you edit a generated scene by hand in the editor, keep editing there and don't re-run the builder.

## Tests

```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_player_movement.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_train.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_journey.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_station.gd
```
Exit code 0 = all passed.

## Dev flags

`-- --capture=<file.png>` (on `movement_sandbox.tscn`): saves a screenshot after 30 frames and quits. Used to verify rendering from the command line.
