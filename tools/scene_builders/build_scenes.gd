extends SceneTree
## Generates Last Stop's greybox scenes: the train and its props, the railway
## track, roadside scenery, station scenes and the shared procedural materials.
##
## Usage (from the repository root):
##   tools/godot/Godot_v4.7.2-stable_win64_console.exe --path LastStop --script tools/scene_builders/build_scenes.gd
##
## Do NOT pass --headless: the headless (dummy) renderer discards MultiMesh
## instance data, so grass, ivy and track sleepers would be saved empty.
## A window flashes briefly while it runs.
##
## WARNING: overwrites every file it generates. Once those scenes are edited by
## hand in the Godot editor, edit them there instead of re-running this script.
##
## Conventions:
## - 1 unit = 1 metre. Prop origins sit on the floor at the centre of their footprint.
## - Prop "front" faces +Z; the back goes against a wall.
## - Train local space: floor at y = FLOOR_Y, front (control cabin) toward -Z.

const FLOOR_Y := 1.2
const CEIL_Y := 3.6
const HALF_W := 1.4   # interior half width
const HALF_L := 9.0   # interior half length
const LAMP_DROP := 0.4  # bulb distance below the ceiling (keeps lamps above head height when jumping)

const SUB := CSGShape3D.OPERATION_SUBTRACTION
const UNION := CSGShape3D.OPERATION_UNION

const ENV_PROPS := "res://scenes/environment/props/"
const TRAIN_PROPS := "res://scenes/train/props/"

# Materials -------------------------------------------------------------------
var m_exterior: StandardMaterial3D
var m_interior: StandardMaterial3D
var m_floor: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_dark_2s: StandardMaterial3D
var m_rust: StandardMaterial3D
var m_wood: StandardMaterial3D
var m_wood_dark: StandardMaterial3D
var m_mattress: StandardMaterial3D
var m_blanket: StandardMaterial3D
var m_seat: StandardMaterial3D
var m_cardboard: StandardMaterial3D
var m_locker: StandardMaterial3D
var m_red: StandardMaterial3D
var m_paper: StandardMaterial3D
var m_gravel: StandardMaterial3D
var m_glass: StandardMaterial3D
var m_bulb: StandardMaterial3D
var m_ember: StandardMaterial3D
var m_gauge: StandardMaterial3D
var m_lamp_red: StandardMaterial3D
var m_lamp_green: StandardMaterial3D
var m_headlamp: StandardMaterial3D
var m_concrete: StandardMaterial3D
var m_ground: StandardMaterial3D
var m_paint_yellow: StandardMaterial3D
var m_rock: StandardMaterial3D

var _root: Node
var _mesh_cache: Dictionary = {}


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("[builder] Refusing to run headless: MultiMesh data would be lost. Run without --headless.")
		quit(1)
		return
	for dir in ["res://assets/materials", "res://scenes/environment/props", "res://scenes/environment/kit",
			"res://scenes/train/props", "res://scenes/stations"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_make_materials()
	_make_station_materials()
	_build_env_props()
	_build_train_props()
	_build_world_props()
	_build_kit()
	_build_station_props()
	_build_track()
	_build_train()
	_build_stations()
	print("[builder] done")
	quit()


# =============================================================================
# Materials
# =============================================================================

func _make_materials() -> void:
	m_exterior = _mat("train_exterior_paint", Color(0.42, 0.17, 0.1), 0.8, 0.3, 0.5, 0.35, 11)
	m_interior = _mat("train_interior_paint", Color(0.36, 0.42, 0.37), 0.85, 0.1, 0.45, 0.6, 12)
	m_floor = _mat("train_floor", Color(0.2, 0.16, 0.12), 0.9, 0.0, 0.4, 1.2, 13)
	m_dark = _mat("dark_metal", Color(0.13, 0.13, 0.13), 0.6, 0.7, 0.35, 1.0, 14)
	m_dark_2s = _mat("dark_metal_double_sided", Color(0.13, 0.13, 0.13), 0.6, 0.7, 0.35, 1.0, 14, func(m: StandardMaterial3D) -> void:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED)
	m_rust = _mat("rust_metal", Color(0.38, 0.2, 0.11), 0.8, 0.5, 0.5, 0.8, 15)
	m_wood = _mat("wood_worn", Color(0.36, 0.26, 0.16), 0.9, 0.0, 0.4, 1.5, 16)
	m_wood_dark = _mat("wood_dark", Color(0.2, 0.15, 0.1), 0.9, 0.0, 0.4, 1.5, 17)
	m_mattress = _mat("fabric_mattress", Color(0.42, 0.38, 0.3), 1.0, 0.0, 0.35, 2.0, 18)
	m_blanket = _mat("fabric_blanket", Color(0.32, 0.22, 0.17), 1.0, 0.0, 0.35, 2.0, 19)
	m_seat = _mat("fabric_seat", Color(0.2, 0.18, 0.16), 1.0, 0.0, 0.3, 2.0, 20)
	m_cardboard = _mat("cardboard", Color(0.45, 0.35, 0.22), 0.95, 0.0, 0.3, 2.0, 21)
	m_locker = _mat("locker_paint", Color(0.24, 0.3, 0.28), 0.7, 0.4, 0.4, 1.0, 22)
	m_red = _mat("red_paint", Color(0.5, 0.1, 0.08), 0.6, 0.3, 0.3, 1.0, 23)
	m_paper = _mat("paper", Color(0.7, 0.66, 0.55), 1.0, 0.0, 0.2, 3.0, 24)
	m_gravel = _mat("gravel", Color(0.27, 0.25, 0.22), 1.0, 0.0, 0.6, 3.0, 25)
	m_glass = _mat("glass_dirty", Color(0.55, 0.6, 0.55, 0.22), 0.25, 0.0, 0.0, 1.0, 0, func(m: StandardMaterial3D) -> void:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED)
	m_bulb = _emissive("bulb_warm", Color(1.0, 0.8, 0.55), 3.0)
	m_ember = _emissive("stove_ember", Color(1.0, 0.35, 0.08), 2.5)
	m_gauge = _emissive("gauge_face", Color(0.85, 0.7, 0.4), 0.6)
	m_lamp_red = _emissive("indicator_red", Color(1.0, 0.15, 0.1), 1.5)
	m_lamp_green = _emissive("indicator_green", Color(0.3, 1.0, 0.4), 1.2)
	m_headlamp = _emissive("headlamp_glass", Color(0.9, 0.85, 0.6), 0.3)
	m_concrete = _mat("concrete", Color(0.34, 0.33, 0.31), 0.95, 0.0, 0.5, 0.5, 26)
	# Ground repeats every 10 m (uv 0.1): TravelScenery's 60 m wrap must stay a multiple of it.
	m_ground = _mat("ground_dirt", Color(0.21, 0.19, 0.15), 1.0, 0.0, 0.45, 0.1, 27)
	m_paint_yellow = _mat("paint_yellow_faded", Color(0.55, 0.45, 0.15), 0.8, 0.0, 0.5, 1.0, 28)
	m_rock = _mat("rock", Color(0.3, 0.29, 0.27), 0.95, 0.0, 0.55, 0.7, 29)


## Creates a StandardMaterial3D with a procedural grime texture (tinted noise,
## local triplanar so it never stretches on boxes and stays put when the train moves).
func _mat(file: String, color: Color, roughness: float, metallic: float, grime: float,
		uv_scale: float, noise_seed: int, extra: Callable = Callable()) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if grime > 0.0:
		var noise := FastNoiseLite.new()
		noise.seed = noise_seed
		noise.frequency = 0.012
		noise.fractal_octaves = 5
		var ramp := Gradient.new()
		ramp.set_color(0, Color.WHITE.darkened(grime))
		ramp.set_color(1, Color.WHITE)
		var tex := NoiseTexture2D.new()
		tex.width = 256
		tex.height = 256
		tex.seamless = true
		tex.noise = noise
		tex.color_ramp = ramp
		m.albedo_texture = tex
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * uv_scale
	if extra.is_valid():
		extra.call(m)
	return _save_resource(m, file)


func _emissive(file: String, color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return _save_resource(m, file)


## Saves the material and returns the copy loaded back from disk, so scenes
## reference the shared .tres file instead of embedding a duplicate.
func _save_resource(res: StandardMaterial3D, file: String) -> StandardMaterial3D:
	var path := "res://assets/materials/%s.tres" % file
	var err := ResourceSaver.save(res, path)
	assert(err == OK, "Failed to save %s" % path)
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as StandardMaterial3D


# =============================================================================
# Node helpers
# =============================================================================

func _begin(root: Node, root_name: String) -> Node:
	root.name = root_name
	_root = root
	return root


func _save(path: String) -> void:
	_merge_static_meshes(_root)
	var packed := PackedScene.new()
	var err := packed.pack(_root)
	assert(err == OK, "pack failed for %s" % path)
	err = ResourceSaver.save(packed, path)
	print("[builder] %s -> %s" % [path, error_string(err)])
	_root.free()
	_root = null


func _own(node: Node, parent: Node) -> Node:
	parent.add_child(node, true)
	node.owner = _root
	return node


func _box_mesh(size: Vector3, mat: Material) -> BoxMesh:
	var key := "box|%s|%s" % [size, mat.resource_path]
	if not _mesh_cache.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh.material = mat
		_mesh_cache[key] = mesh
	return _mesh_cache[key]


func _cyl_mesh(radius: float, height: float, mat: Material, top_radius: float = -1.0, cap_bottom: bool = true) -> CylinderMesh:
	var key := "cyl|%s|%s|%s|%s|%s" % [radius, height, top_radius, cap_bottom, mat.resource_path]
	if not _mesh_cache.has(key):
		var mesh := CylinderMesh.new()
		mesh.bottom_radius = radius
		mesh.top_radius = radius if top_radius < 0.0 else top_radius
		mesh.height = height
		mesh.radial_segments = 16
		mesh.rings = 1
		mesh.cap_bottom = cap_bottom
		mesh.material = mat
		_mesh_cache[key] = mesh
	return _mesh_cache[key]


func box(parent: Node, node_name: String, size: Vector3, pos: Vector3, mat: Material,
		rot: Vector3 = Vector3.ZERO, casts_shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = _box_mesh(size, mat)
	mi.position = pos
	mi.rotation = rot
	_apply_detail_culling(mi, maxf(size.x, maxf(size.y, size.z)), casts_shadow)
	return _own(mi, parent)


func cyl(parent: Node, node_name: String, radius: float, height: float, pos: Vector3, mat: Material,
		rot: Vector3 = Vector3.ZERO, casts_shadow: bool = true, top_radius: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = _cyl_mesh(radius, height, mat, top_radius)
	mi.position = pos
	mi.rotation = rot
	_apply_detail_culling(mi, maxf(radius * 2.0, height), casts_shadow)
	return _own(mi, parent)


func sphere(parent: Node, node_name: String, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	_apply_detail_culling(mi, radius * 2.0, false)
	return _own(mi, parent)


## Performance: small clutter stops drawing beyond DETAIL_RANGE and the tiniest
## pieces never cast shadows. Keeps draw calls down on modest GPUs.
const DETAIL_SIZE := 0.35
const TINY_SIZE := 0.15
const DETAIL_RANGE := 15.0

func _apply_detail_culling(mi: MeshInstance3D, largest_dimension: float, casts_shadow: bool) -> void:
	if not casts_shadow or largest_dimension < TINY_SIZE:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if largest_dimension < DETAIL_SIZE:
		mi.visibility_range_end = DETAIL_RANGE
		mi.visibility_range_end_margin = 1.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED


func node3d(parent: Node, node_name: String, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.position = pos
	n.rotation = rot
	return _own(n, parent)


func collider_box(body: Node, size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	cs.position = pos
	cs.rotation = rot
	return _own(cs, body)


func collider_cyl(body: Node, radius: float, height: float, pos: Vector3) -> CollisionShape3D:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	var cs := CollisionShape3D.new()
	cs.name = "Collision"
	cs.shape = shape
	cs.position = pos
	return _own(cs, body)


func csg_box(parent: Node, node_name: String, size: Vector3, pos: Vector3, mat: Material,
		op: int = UNION) -> CSGBox3D:
	var c := CSGBox3D.new()
	c.name = node_name
	c.size = size
	c.position = pos
	c.material = mat
	c.operation = op
	return _own(c, parent)


func instance(parent: Node, path: String, node_name: String, pos: Vector3, rot_y_deg: float = 0.0) -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.name = node_name
	n.position = pos
	n.rotation.y = deg_to_rad(rot_y_deg)
	return _own(n, parent)


# =============================================================================
# Environment props (reusable at stations too)
# =============================================================================

func _build_env_props() -> void:
	_build_crate(ENV_PROPS + "crate.tscn", 0.7)
	_build_crate(ENV_PROPS + "crate_small.tscn", 0.45)

	# Oil drum
	var drum := _begin(StaticBody3D.new(), "OilDrum")
	cyl(drum, "Body", 0.29, 0.88, Vector3(0, 0.44, 0), m_rust)
	for y in [0.29, 0.59]:
		cyl(drum, "Rib", 0.3, 0.025, Vector3(0, y, 0), m_dark)
	cyl(drum, "Lid", 0.27, 0.012, Vector3(0, 0.886, 0), m_dark)
	collider_cyl(drum, 0.3, 0.88, Vector3(0, 0.44, 0))
	_save(ENV_PROPS + "oil_drum.tscn")

	# Hanging lamp: the root IS the light so instances can override energy/shadows.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.78, 0.52)
	lamp.light_energy = 1.2
	lamp.light_specular = 0.3
	lamp.omni_range = 5.5
	lamp.shadow_enabled = false
	_begin(lamp, "HangingLamp")
	cyl(lamp, "Cord", 0.006, 0.45, Vector3(0, 0.35, 0), m_dark, Vector3.ZERO, false)
	var shade := MeshInstance3D.new()
	shade.name = "Shade"
	shade.mesh = _cyl_mesh(0.17, 0.14, m_dark_2s, 0.04, false)
	shade.position = Vector3(0, 0.1, 0)
	_own(shade, lamp)
	sphere(lamp, "Bulb", 0.05, Vector3.ZERO, m_bulb)
	_save(ENV_PROPS + "hanging_lamp.tscn")


func _build_crate(path: String, s: float) -> void:
	var r := _begin(StaticBody3D.new(), "Crate")
	box(r, "Body", Vector3.ONE * s, Vector3(0, s / 2.0, 0), m_wood)
	for y in [s * 0.2, s * 0.8]:
		box(r, "Band", Vector3(s + 0.02, 0.05, s + 0.02), Vector3(0, y, 0), m_dark)
	collider_box(r, Vector3.ONE * s, Vector3(0, s / 2.0, 0))
	_save(path)


# =============================================================================
# Train props
# =============================================================================

func _build_train_props() -> void:
	_build_bunk_bed()
	_build_table()
	_build_stove()
	_build_shelf_unit()
	_build_storage_locker()
	_build_workbench()
	_build_control_console()
	_build_driver_seat()


## Two-tier bunk. 2.0 m long (X) × 0.9 m deep (Z). Head end at -X.
func _build_bunk_bed() -> void:
	var r := _begin(StaticBody3D.new(), "BunkBed")
	for sx in [-0.975, 0.975]:
		for sz in [-0.425, 0.425]:
			box(r, "Post", Vector3(0.05, 1.95, 0.05), Vector3(sx, 0.975, sz), m_dark)
	for y in [0.35, 1.4]:
		box(r, "Frame", Vector3(2.0, 0.06, 0.9), Vector3(0, y, 0), m_dark)
		box(r, "Mattress", Vector3(1.9, 0.14, 0.82), Vector3(0, y + 0.1, 0), m_mattress)
	box(r, "Pillow", Vector3(0.35, 0.1, 0.55), Vector3(-0.72, 0.6, 0), m_paper)
	box(r, "Blanket", Vector3(1.15, 0.05, 0.86), Vector3(0.3, 0.545, 0.01), m_blanket, Vector3(0, 0.04, 0))
	cyl(r, "SleepingBagRoll", 0.13, 0.8, Vector3(0.55, 1.66, 0), m_blanket, Vector3(PI / 2, 0, 0))
	box(r, "SafetyRail", Vector3(1.3, 0.04, 0.03), Vector3(0.2, 1.72, 0.43), m_dark)
	collider_box(r, Vector3(2.0, 0.52, 0.9), Vector3(0, 0.26, 0))
	collider_box(r, Vector3(2.0, 0.2, 0.9), Vector3(0, 1.47, 0))
	_save(TRAIN_PROPS + "bunk_bed.tscn")


## 1.1 m × 0.7 m table with a few items.
func _build_table() -> void:
	var r := _begin(StaticBody3D.new(), "Table")
	box(r, "Top", Vector3(1.1, 0.05, 0.7), Vector3(0, 0.755, 0), m_wood)
	for sx in [-0.5, 0.5]:
		for sz in [-0.3, 0.3]:
			box(r, "Leg", Vector3(0.05, 0.73, 0.05), Vector3(sx, 0.365, sz), m_dark)
	cyl(r, "Can", 0.04, 0.11, Vector3(0.3, 0.835, 0.12), m_rust)
	cyl(r, "Can", 0.04, 0.11, Vector3(0.38, 0.835, -0.05), m_rust)
	box(r, "Map", Vector3(0.42, 0.004, 0.3), Vector3(-0.15, 0.782, 0), m_paper, Vector3(0, 0.25, 0), false)
	cyl(r, "Mug", 0.045, 0.09, Vector3(-0.4, 0.825, 0.18), m_locker)
	collider_box(r, Vector3(1.1, 0.78, 0.7), Vector3(0, 0.39, 0))
	_save(TRAIN_PROPS + "table.tscn")


## Barrel stove with ember glow and a flue to the ceiling (2.4 m).
func _build_stove() -> void:
	var r := _begin(StaticBody3D.new(), "Stove")
	for a in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		box(r, "Leg", Vector3(0.04, 0.14, 0.04), Vector3(sin(a) * 0.2, 0.07, cos(a) * 0.2), m_dark)
	cyl(r, "Body", 0.28, 0.75, Vector3(0, 0.515, 0), m_dark)
	cyl(r, "TopPlate", 0.3, 0.03, Vector3(0, 0.905, 0), m_dark)
	box(r, "EmberDoor", Vector3(0.22, 0.2, 0.03), Vector3(0, 0.45, 0.285), m_ember, Vector3.ZERO, false)
	cyl(r, "Flue", 0.065, 1.5, Vector3(0, 1.65, 0), m_dark)
	var glow := OmniLight3D.new()
	glow.name = "EmberGlow"
	glow.position = Vector3(0, 0.45, 0.5)
	glow.light_color = Color(1.0, 0.45, 0.15)
	glow.light_energy = 1.0
	glow.omni_range = 3.5
	_own(glow, r)
	collider_cyl(r, 0.3, 0.92, Vector3(0, 0.46, 0))
	_save(TRAIN_PROPS + "stove.tscn")


## 1.6 m wide × 0.45 m deep × 2.0 m tall metal shelving with supplies.
func _build_shelf_unit() -> void:
	var r := _begin(StaticBody3D.new(), "ShelfUnit")
	for sx in [-0.78, 0.78]:
		for sz in [-0.2, 0.2]:
			box(r, "Post", Vector3(0.04, 2.0, 0.04), Vector3(sx, 1.0, sz), m_dark)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for y in [0.12, 0.7, 1.28, 1.86]:
		box(r, "Shelf", Vector3(1.6, 0.03, 0.45), Vector3(0, y, 0), m_dark)
		var x := -0.72
		while true:
			var kind := rng.randi_range(0, 3)
			var w := 0.0
			match kind:
				0:  # cardboard box
					w = rng.randf_range(0.22, 0.38)
					var h := rng.randf_range(0.18, 0.34)
					var d := rng.randf_range(0.26, 0.38)
					if x + w > 0.74:
						break
					box(r, "Box", Vector3(w, h, d), Vector3(x + w / 2.0, y + 0.015 + h / 2.0, rng.randf_range(-0.02, 0.02)),
							m_cardboard, Vector3(0, rng.randf_range(-0.08, 0.08), 0))
				1:  # cluster of cans
					w = 0.26
					if x + w > 0.74:
						break
					for i in 3:
						cyl(r, "Can", 0.04, 0.11, Vector3(x + 0.05 + i * 0.085, y + 0.07, rng.randf_range(-0.1, 0.1)), m_rust)
				2:  # bottles
					w = 0.2
					if x + w > 0.74:
						break
					for i in 2:
						cyl(r, "Bottle", 0.045, 0.25, Vector3(x + 0.05 + i * 0.1, y + 0.14, rng.randf_range(-0.08, 0.08)), m_glass, Vector3.ZERO, false)
				_:  # gap
					w = 0.12
			x += w + 0.04
			if x > 0.7:
				break
	collider_box(r, Vector3(1.6, 2.0, 0.45), Vector3(0, 1.0, 0))
	_save(TRAIN_PROPS + "shelf_unit.tscn")


## 0.9 m × 0.5 m × 1.9 m two-door metal locker. Becomes train storage in Milestone 7.
func _build_storage_locker() -> void:
	var r := _begin(StaticBody3D.new(), "StorageLocker")
	box(r, "Body", Vector3(0.9, 1.84, 0.5), Vector3(0, 0.98, 0), m_locker)
	box(r, "Base", Vector3(0.88, 0.06, 0.48), Vector3(0, 0.03, 0), m_dark)
	box(r, "Seam", Vector3(0.01, 1.8, 0.012), Vector3(0, 0.98, 0.25), m_dark)
	for sx in [-0.06, 0.06]:
		box(r, "Handle", Vector3(0.02, 0.14, 0.03), Vector3(sx, 1.0, 0.26), m_dark)
	for door_x in [-0.22, 0.22]:
		for i in 3:
			box(r, "Vent", Vector3(0.24, 0.015, 0.006), Vector3(door_x, 1.65 + i * 0.04, 0.251), m_dark)
	collider_box(r, Vector3(0.9, 1.9, 0.5), Vector3(0, 0.95, 0))
	_save(TRAIN_PROPS + "storage_locker.tscn")


## 1.6 m × 0.65 m workbench with vise, toolbox, scrap and a pegboard. Repair station later.
func _build_workbench() -> void:
	var r := _begin(StaticBody3D.new(), "Workbench")
	box(r, "Top", Vector3(1.6, 0.06, 0.65), Vector3(0, 0.87, 0), m_wood)
	for sx in [-0.75, 0.75]:
		for sz in [-0.28, 0.28]:
			box(r, "Leg", Vector3(0.06, 0.84, 0.06), Vector3(sx, 0.42, sz), m_dark)
	box(r, "LowerShelf", Vector3(1.5, 0.03, 0.55), Vector3(0, 0.25, 0), m_wood_dark)
	box(r, "ViseBody", Vector3(0.15, 0.12, 0.2), Vector3(0.6, 0.96, 0.2), m_dark)
	box(r, "ViseJaw", Vector3(0.15, 0.08, 0.04), Vector3(0.6, 0.98, 0.32), m_dark)
	box(r, "Toolbox", Vector3(0.45, 0.18, 0.2), Vector3(-0.45, 0.99, -0.05), m_red)
	box(r, "Scrap", Vector3(0.2, 0.02, 0.12), Vector3(0.05, 0.91, 0.1), m_rust, Vector3(0, 0.5, 0))
	box(r, "Scrap", Vector3(0.12, 0.06, 0.08), Vector3(0.22, 0.93, -0.12), m_rust, Vector3(0, 0.8, 0))
	cyl(r, "PipeOffcut", 0.025, 0.3, Vector3(-0.1, 0.925, 0.2), m_rust, Vector3(0, 0.3, PI / 2))
	box(r, "Pegboard", Vector3(1.6, 0.7, 0.02), Vector3(0, 1.45, -0.315), m_wood_dark)
	box(r, "Wrench", Vector3(0.04, 0.25, 0.01), Vector3(-0.5, 1.5, -0.3), m_dark)
	box(r, "HammerHandle", Vector3(0.03, 0.28, 0.02), Vector3(-0.3, 1.45, -0.3), m_wood)
	box(r, "HammerHead", Vector3(0.12, 0.04, 0.04), Vector3(-0.3, 1.59, -0.3), m_dark)
	box(r, "Saw", Vector3(0.35, 0.12, 0.005), Vector3(0.2, 1.55, -0.3), m_dark)
	cyl(r, "WireCoil", 0.1, 0.04, Vector3(0.55, 1.5, -0.29), m_rust, Vector3(PI / 2, 0, 0))
	collider_box(r, Vector3(1.6, 0.9, 0.65), Vector3(0, 0.45, 0))
	_save(TRAIN_PROPS + "workbench.tscn")


## 2.4 m driver console. Instruments sit on a sloped panel facing the driver (+Z).
## "Instruments/DepartureLever" becomes the departure interaction in a later milestone.
func _build_control_console() -> void:
	var r := _begin(StaticBody3D.new(), "ControlConsole")
	box(r, "Base", Vector3(2.4, 0.9, 0.6), Vector3(0, 0.45, 0), m_dark)
	var slope := Vector3(0.45, 0, 0)
	var top_pos := Vector3(0, 0.95, -0.03)
	box(r, "SlopedPanel", Vector3(2.4, 0.25, 0.5), top_pos, m_dark, slope)
	var inst := node3d(r, "Instruments", top_pos, slope)
	var surface := 0.125
	for i in 3:
		var gx := -0.95 + i * 0.23
		cyl(inst, "Gauge", 0.075, 0.02, Vector3(gx, surface + 0.01, -0.08), m_gauge, Vector3.ZERO, false)
		box(inst, "Needle", Vector3(0.006, 0.004, 0.06), Vector3(gx, surface + 0.023, -0.08), m_dark,
				Vector3(0, 0.6 - i * 0.7, 0), false)
	box(inst, "LampRed", Vector3(0.04, 0.02, 0.04), Vector3(-0.25, surface + 0.01, -0.15), m_lamp_red, Vector3.ZERO, false)
	box(inst, "LampGreen", Vector3(0.04, 0.02, 0.04), Vector3(-0.18, surface + 0.01, -0.15), m_lamp_green, Vector3.ZERO, false)
	box(inst, "LampOff", Vector3(0.04, 0.02, 0.04), Vector3(-0.11, surface + 0.01, -0.15), m_dark, Vector3.ZERO, false)
	for i in 4:
		cyl(inst, "Button", 0.02, 0.02, Vector3(0.0 + i * 0.06, surface + 0.01, 0.05), m_red if i == 0 else m_dark, Vector3.ZERO, false)
	_build_lever(inst, "BrakeLever", Vector3(0.38, surface, 0.06), m_dark, 0.015, 0.035)
	_build_lever(inst, "ThrottleLever", Vector3(0.52, surface, 0.06), m_dark, 0.015, 0.035)
	box(inst, "DepartureLeverPlate", Vector3(0.12, 0.02, 0.2), Vector3(0.85, surface + 0.01, 0.0), m_rust, Vector3.ZERO, false)
	_build_lever(inst, "DepartureLever", Vector3(0.85, surface, 0.0), m_dark, 0.02, 0.05, m_red)
	var glow := OmniLight3D.new()
	glow.name = "InstrumentGlow"
	glow.position = Vector3(0, 1.25, 0.25)
	glow.light_color = Color(0.65, 0.85, 0.7)
	glow.light_energy = 0.4
	glow.omni_range = 2.2
	_own(glow, r)
	collider_box(r, Vector3(2.4, 1.05, 0.6), Vector3(0, 0.525, 0))
	_save(TRAIN_PROPS + "control_console.tscn")


func _build_lever(parent: Node, lever_name: String, pos: Vector3, mat: Material, rod_r: float, knob_r: float,
		knob_mat: Material = null) -> void:
	var pivot := node3d(parent, lever_name, pos, Vector3(-0.4, 0, 0))
	pivot.set_meta(KEEP_SEPARATE, true)  # levers animate later; never merge
	cyl(pivot, "Rod", rod_r, 0.3, Vector3(0, 0.15, 0), mat, Vector3.ZERO, false)
	sphere(pivot, "Knob", knob_r, Vector3(0, 0.3, 0), knob_mat if knob_mat else mat)


func _build_driver_seat() -> void:
	var r := _begin(StaticBody3D.new(), "DriverSeat")
	cyl(r, "BasePlate", 0.22, 0.02, Vector3(0, 0.01, 0), m_dark)
	cyl(r, "Pedestal", 0.06, 0.42, Vector3(0, 0.21, 0), m_dark)
	box(r, "Cushion", Vector3(0.5, 0.1, 0.48), Vector3(0, 0.47, 0), m_seat)
	box(r, "Backrest", Vector3(0.5, 0.62, 0.08), Vector3(0, 0.84, -0.22), m_seat, Vector3(-0.12, 0, 0))
	collider_box(r, Vector3(0.5, 1.15, 0.5), Vector3(0, 0.575, 0))
	_save(TRAIN_PROPS + "driver_seat.tscn")


# =============================================================================
# Railway track (reusable at every station)
# =============================================================================

## 60 m straight track. Origin on the ground at the centre. Ballast is sunk so
## its top is 5 cm above ground; rails/sleepers have no collision (walk-through).
func _build_track() -> void:
	const LENGTH := 60.0
	const SPACING := 0.6
	const GAUGE_HALF := 0.7175
	var r := _begin(Node3D.new(), "RailwayTrack")
	box(r, "Ballast", Vector3(3.4, 0.15, LENGTH), Vector3(0, -0.025, 0), m_gravel)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _box_mesh(Vector3(2.5, 0.12, 0.24), m_wood_dark)
	mm.instance_count = int(LENGTH / SPACING)
	for i in mm.instance_count:
		var basis := Basis(Vector3.UP, rng.randf_range(-0.03, 0.03))
		mm.set_instance_transform(i, Transform3D(basis, Vector3(rng.randf_range(-0.03, 0.03), 0.11,
				-LENGTH / 2.0 + SPACING / 2.0 + i * SPACING)))
	var sleepers := MultiMeshInstance3D.new()
	sleepers.name = "Sleepers"
	sleepers.multimesh = mm
	_own(sleepers, r)
	for side in [-1.0, 1.0]:
		box(r, "Rail", Vector3(0.07, 0.12, LENGTH), Vector3(side * GAUGE_HALF, 0.23, 0), m_rust)
	_save("res://scenes/environment/railway_track.tscn")


# =============================================================================
# Train
# =============================================================================

func _build_train() -> void:
	var train := Node3D.new()
	train.set_script(load("res://scripts/train/train_controller.gd"))
	var r := _begin(train, "Train")
	_build_shell(r)
	_build_windows(r)
	_build_exterior(r)
	_build_entrance_steps(r)
	_build_doors(r)
	_build_interior(r)

	# Player-aboard detection, required for departure.
	var aboard := Area3D.new()
	aboard.name = "AboardArea"
	aboard.position = Vector3(0, FLOOR_Y + 1.15, 0)
	aboard.monitorable = false
	_own(aboard, r)
	collider_box(aboard, Vector3(2.7, 2.3, 17.8), Vector3.ZERO)

	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, FLOOR_Y, 0.3)
	_own(spawn, r)
	_save("res://scenes/train/train.tscn")


## Window definitions: [side (-1 left / +1 right), z centre, width, state].
const WINDOWS := [
	[-1, -7.3, 1.0, "glass"], [1, -7.3, 1.0, "glass"],       # control cabin
	[-1, -1.6, 1.0, "boarded"], [-1, 0.6, 1.0, "glass"], [-1, 2.4, 1.0, "broken"],  # living, left
	[1, -0.9, 1.0, "glass"], [1, 1.0, 1.0, "glass"], [1, 2.6, 1.0, "broken"],       # living, right
	[-1, 7.7, 0.8, "boarded"], [1, 6.4, 0.8, "glass"],      # storage
]
const WINDOW_Y := FLOOR_Y + 0.95 + 0.375   # centre; sill at floor + 0.95 m
const WINDOW_H := 0.75
const DOOR_Z := -4.3
const DOOR_W := 1.1
const DOOR_H := 2.06


## One CSG combiner forms the walls, floor, ceiling and partitions, with
## openings subtracted. Subtracted faces take the cutter's material, so the
## inside gets interior paint and openings get dark metal reveals.
func _build_shell(r: Node) -> void:
	var shell := CSGCombiner3D.new()
	shell.name = "Shell"
	shell.use_collision = true
	_own(shell, r)
	# Overlaps of a few mm avoid coplanar faces, which CSG handles badly.
	csg_box(shell, "Outer", Vector3(3.0, 2.7, 18.2), Vector3(0, 2.35, 0), m_exterior)
	csg_box(shell, "Inner", Vector3(HALF_W * 2, 2.44, HALF_L * 2), Vector3(0, 2.38, 0), m_interior, SUB)
	csg_box(shell, "FloorSlab", Vector3(2.84, 0.05, 18.04), Vector3(0, 1.175, 0), m_floor)
	csg_box(shell, "CabPartition", Vector3(2.84, 2.48, 0.1), Vector3(0, 2.38, -5.6), m_interior)
	csg_box(shell, "StoragePartition", Vector3(2.84, 2.48, 0.1), Vector3(0, 2.38, 3.3), m_interior)

	var door_y := FLOOR_Y - 0.01 + DOOR_H / 2.0
	csg_box(shell, "CabDoorway", Vector3(1.0, DOOR_H, 0.3), Vector3(0.4, door_y, -5.6), m_dark, SUB)
	csg_box(shell, "StorageDoorway", Vector3(1.0, DOOR_H, 0.3), Vector3(0, door_y, 3.3), m_dark, SUB)
	for side in [-1.0, 1.0]:
		csg_box(shell, "SideDoor", Vector3(0.4, DOOR_H, DOOR_W), Vector3(side * 1.45, door_y, DOOR_Z), m_dark, SUB)
	for w in WINDOWS:
		csg_box(shell, "Window", Vector3(0.4, WINDOW_H, w[2]), Vector3(w[0] * 1.45, WINDOW_Y, w[1]), m_dark, SUB)
	csg_box(shell, "Windshield", Vector3(2.2, 0.85, 0.4), Vector3(0, FLOOR_Y + 1.05 + 0.425, -9.05), m_dark, SUB)


func _build_windows(r: Node) -> void:
	var group := node3d(r, "Windows", Vector3.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for w in WINDOWS:
		var side: float = w[0]
		var z: float = w[1]
		var width: float = w[2]
		match w[3]:
			"glass":
				box(group, "Glass", Vector3(0.012, WINDOW_H, width), Vector3(side * 1.45, WINDOW_Y, z), m_glass, Vector3.ZERO, false)
			"boarded":
				for i in 3:
					box(group, "Plank", Vector3(0.025, 0.13, width + 0.25),
							Vector3(side * 1.37, WINDOW_Y - 0.24 + i * 0.24, z), m_wood,
							Vector3(rng.randf_range(-0.12, 0.12), 0, 0))
			"broken":
				for i in 4:
					box(group, "GlassShard", Vector3(0.06, 0.004, 0.1),
							Vector3(side * rng.randf_range(0.9, 1.25), FLOOR_Y + 0.003, z + rng.randf_range(-0.4, 0.4)),
							m_glass, Vector3(0, rng.randf_range(0, PI), 0), false)
	# Windshield with a centre mullion.
	var ws_y := FLOOR_Y + 1.05 + 0.425
	box(group, "WindshieldGlass", Vector3(2.2, 0.85, 0.012), Vector3(0, ws_y, -9.05), m_glass, Vector3.ZERO, false)
	box(group, "WindshieldMullion", Vector3(0.06, 0.85, 0.06), Vector3(0, ws_y, -9.05), m_dark)


func _build_exterior(r: Node) -> void:
	var ext := node3d(r, "Exterior", Vector3.ZERO)
	box(ext, "Roof", Vector3(3.12, 0.1, 18.36), Vector3(0, 3.75, 0), m_rust)
	box(ext, "RoofVent", Vector3(0.6, 0.15, 0.6), Vector3(0, 3.87, -0.5), m_dark)
	box(ext, "RoofVent", Vector3(0.6, 0.15, 0.6), Vector3(0, 3.87, 5.5), m_dark)
	cyl(ext, "ChimneyStack", 0.07, 0.7, Vector3(1.0, 4.05, -2.4), m_dark)
	cyl(ext, "ChimneyCap", 0.12, 0.03, Vector3(1.0, 4.42, -2.4), m_dark)
	box(ext, "Underframe", Vector3(2.6, 0.28, 16.5), Vector3(0, 0.86, 0), m_dark)

	for bz in [-6.2, 6.2]:
		box(ext, "BogieFrame", Vector3(1.9, 0.16, 2.6), Vector3(0, 0.64, bz), m_dark)
		for az in [-0.85, 0.85]:
			cyl(ext, "Axle", 0.045, 1.5, Vector3(0, 0.63, bz + az), m_dark, Vector3(0, 0, PI / 2))
			for wx in [-0.7175, 0.7175]:
				cyl(ext, "Wheel", 0.34, 0.1, Vector3(wx, 0.63, bz + az), m_rust, Vector3(0, 0, PI / 2))

	for end in [-1.0, 1.0]:
		box(ext, "Coupler", Vector3(0.3, 0.22, 0.35), Vector3(0, 1.0, end * 9.27), m_dark)
		for bx in [-0.85, 0.85]:
			cyl(ext, "Buffer", 0.12, 0.25, Vector3(bx, 1.05, end * 9.22), m_dark, Vector3(PI / 2, 0, 0))
	for hx in [-0.95, 0.95]:
		cyl(ext, "Headlamp", 0.13, 0.08, Vector3(hx, 1.65, -9.13), m_headlamp, Vector3(PI / 2, 0, 0))

	# Sealed rear door: future connection to extra carriages.
	box(ext, "RearDoorInside", Vector3(0.9, 2.0, 0.04), Vector3(0, FLOOR_Y + 1.0, 8.98), m_dark)
	box(ext, "RearDoorOutside", Vector3(0.9, 2.0, 0.04), Vector3(0, FLOOR_Y + 1.0, 9.12), m_dark)
	box(ext, "RearDoorHandle", Vector3(0.04, 0.18, 0.04), Vector3(0.3, FLOOR_Y + 1.0, 8.94), m_rust)

	# Keeps the player from walking under the carriage.
	var guard := StaticBody3D.new()
	guard.name = "UnderframeCollider"
	_own(guard, ext)
	collider_box(guard, Vector3(2.9, 1.0, 18.2), Vector3(0, 0.5, 0))


## Steps down from each side door. Visual treads plus an invisible ramp
## collider (CharacterBody3D cannot climb steps), same pattern as the sandbox stairs.
func _build_entrance_steps(r: Node) -> void:
	const RUN := 1.75             # horizontal distance from door sill to ground
	const ANGLE := 0.6011         # atan(1.2 / 1.75)
	var length := sqrt(RUN * RUN + FLOOR_Y * FLOOR_Y)
	var steps := node3d(r, "EntranceSteps", Vector3.ZERO)
	for side in [-1.0, 1.0]:
		for i in range(1, 5):
			box(steps, "Tread", Vector3(0.35, 0.04, 1.0),
					Vector3(side * (1.5 + 0.35 * i), FLOOR_Y - 0.24 * i - 0.02, DOOR_Z), m_dark)
		for sz in [-0.52, 0.52]:
			box(steps, "Stringer", Vector3(length, 0.1, 0.04),
					Vector3(side * (1.5 + RUN / 2.0), FLOOR_Y / 2.0, DOOR_Z + sz), m_dark, Vector3(0, 0, -side * ANGLE))
		for hz in [-0.62, 0.62]:
			# Outboard of the sliding door's path.
			cyl(steps, "Handrail", 0.025, 1.1, Vector3(side * 1.62, FLOOR_Y + 0.65, DOOR_Z + hz), m_dark)
		var body := StaticBody3D.new()
		body.name = "StepRamp"
		body.position = Vector3(side * 2.347, 0.559, DOOR_Z)
		body.rotation = Vector3(0, 0, -side * ANGLE)
		_own(body, steps)
		collider_box(body, Vector3(length, 0.1, DOOR_W), Vector3.ZERO)


func _build_interior(r: Node) -> void:
	var interior := node3d(r, "Interior", Vector3.ZERO)
	var f := FLOOR_Y

	# Ceiling ribs.
	for z in range(-8, 9, 2):
		box(interior, "CeilingRib", Vector3(2.8, 0.05, 0.08), Vector3(0, CEIL_Y - 0.025, z), m_dark)

	# Control cabin (z -9 … -5.6).
	var cabin := node3d(interior, "ControlCabin", Vector3.ZERO)
	instance(cabin, TRAIN_PROPS + "control_console.tscn", "ControlConsole", Vector3(0, f, -8.7))
	instance(cabin, TRAIN_PROPS + "driver_seat.tscn", "DriverSeat", Vector3(-0.45, f, -7.7), 180)
	# TEMPORARY departure control until the interaction system (Milestone 5).
	var trigger := Area3D.new()
	trigger.set_script(load("res://scripts/train/departure_trigger.gd"))
	trigger.name = "DepartureTrigger"
	trigger.position = Vector3(0.3, f + 1.0, -7.6)
	trigger.monitorable = false
	_own(trigger, cabin)
	collider_box(trigger, Vector3(1.6, 2.0, 1.6), Vector3.ZERO)
	var cab_lamp: OmniLight3D = instance(cabin, ENV_PROPS + "hanging_lamp.tscn", "CabinLamp", Vector3(0.3, CEIL_Y - LAMP_DROP, -6.8))
	cab_lamp.light_energy = 0.5

	# Entrance vestibule (z -5.6 … -3).
	var vest := node3d(interior, "Entrance", Vector3.ZERO)
	var entrance_lamp: OmniLight3D = instance(vest, ENV_PROPS + "hanging_lamp.tscn", "EntranceLamp", Vector3(0, CEIL_Y - LAMP_DROP, DOOR_Z))
	entrance_lamp.light_energy = 0.9
	cyl(vest, "FireExtinguisher", 0.08, 0.5, Vector3(-1.0, f + 0.65, -5.45), m_red)
	cyl(vest, "ExtinguisherValve", 0.03, 0.06, Vector3(-1.0, f + 0.93, -5.45), m_dark)
	box(vest, "LoosePaper", Vector3(0.2, 0.002, 0.28), Vector3(0.3, f + 0.002, -3.8), m_paper, Vector3(0, 0.7, 0), false)
	box(vest, "LoosePaper", Vector3(0.2, 0.002, 0.28), Vector3(-0.6, f + 0.002, -4.9), m_paper, Vector3(0, 0.2, 0), false)

	# Living / sleeping area (z -3 … 3.3).
	var living := node3d(interior, "LivingArea", Vector3.ZERO)
	instance(living, TRAIN_PROPS + "bunk_bed.tscn", "BunkBed", Vector3(-HALF_W + 0.45, f, -1.65), 90)
	instance(living, TRAIN_PROPS + "stove.tscn", "Stove", Vector3(1.0, f, -2.4), -90)
	instance(living, TRAIN_PROPS + "table.tscn", "Table", Vector3(HALF_W - 0.35, f, 1.0), -90)
	instance(living, ENV_PROPS + "crate_small.tscn", "Stool", Vector3(0.45, f, 1.0), 10)
	instance(living, ENV_PROPS + "crate.tscn", "Crate", Vector3(-1.0, f, 2.55), 12)
	instance(living, ENV_PROPS + "crate_small.tscn", "CrateSmall", Vector3(-1.0, f + 0.7, 2.5), -20)
	var living_lamp: OmniLight3D = instance(living, ENV_PROPS + "hanging_lamp.tscn", "LivingLamp", Vector3(0, CEIL_Y - LAMP_DROP, 0.0))
	living_lamp.light_energy = 1.5
	living_lamp.shadow_enabled = true

	# Storage (z 3.3 … 9).
	var storage := node3d(interior, "StorageArea", Vector3.ZERO)
	instance(storage, TRAIN_PROPS + "shelf_unit.tscn", "ShelfUnit", Vector3(-HALF_W + 0.225, f, 4.3), 90)
	instance(storage, TRAIN_PROPS + "shelf_unit.tscn", "ShelfUnit2", Vector3(-HALF_W + 0.225, f, 6.0), 90)
	instance(storage, TRAIN_PROPS + "workbench.tscn", "Workbench", Vector3(HALF_W - 0.325, f, 4.4), -90)
	instance(storage, ENV_PROPS + "oil_drum.tscn", "FuelDrum", Vector3(1.05, f, 6.1))
	instance(storage, ENV_PROPS + "oil_drum.tscn", "FuelDrum2", Vector3(1.05, f, 6.75), 40)
	instance(storage, TRAIN_PROPS + "storage_locker.tscn", "StorageLocker", Vector3(HALF_W - 0.25, f, 8.0), -90)
	instance(storage, ENV_PROPS + "crate.tscn", "Crate", Vector3(-1.0, f, 8.5), -8)
	var storage_lamp: OmniLight3D = instance(storage, ENV_PROPS + "hanging_lamp.tscn", "StorageLamp", Vector3(0, CEIL_Y - LAMP_DROP, 6.2))
	storage_lamp.light_energy = 1.0


## Exterior sliding doors. Closed, they block the doorway; TrainController
## slides them toward the cabin to open (its door_slide must match DOOR_SLIDE).
## AnimatableBody3D so the moving collision behaves correctly.
const DOOR_SLIDE := 1.3

func _build_doors(r: Node) -> void:
	var doors := node3d(r, "Doors", Vector3.ZERO)
	for side in [-1.0, 1.0]:
		var door := AnimatableBody3D.new()
		door.name = "DoorLeft" if side < 0.0 else "DoorRight"
		door.position = Vector3(side * 1.53, FLOOR_Y - 0.01 + DOOR_H / 2.0, DOOR_Z)
		_own(door, doors)
		box(door, "Panel", Vector3(0.05, DOOR_H + 0.06, DOOR_W + 0.08), Vector3.ZERO, m_exterior)
		box(door, "Inset", Vector3(0.056, 0.42, 0.5), Vector3(0, 0.45, 0), m_dark)
		box(door, "Handle", Vector3(0.04, 0.3, 0.04), Vector3(side * 0.04, 0, DOOR_W / 2.0 - 0.1), m_dark)
		collider_box(door, Vector3(0.12, DOOR_H, DOOR_W + 0.04), Vector3(-side * 0.03, 0, 0))
		box(doors, "DoorRail", Vector3(0.06, 0.06, 2.6), Vector3(side * 1.53, FLOOR_Y + DOOR_H + 0.07, DOOR_Z - 0.65), m_dark)


# =============================================================================
# Roadside scenery (streamed past the train, reusable at stations)
# =============================================================================

func _build_world_props() -> void:
	# Telegraph pole, 7 m.
	var pole := _begin(StaticBody3D.new(), "TelegraphPole")
	cyl(pole, "Pole", 0.11, 7.0, Vector3(0, 3.5, 0), m_wood_dark, Vector3.ZERO, true, 0.09)
	box(pole, "Crossbar", Vector3(1.6, 0.1, 0.1), Vector3(0, 6.4, 0), m_wood_dark)
	for x in [-0.65, -0.25, 0.25, 0.65]:
		cyl(pole, "Insulator", 0.035, 0.1, Vector3(x, 6.5, 0), m_glass)
	collider_cyl(pole, 0.12, 7.0, Vector3(0, 3.5, 0))
	_save(ENV_PROPS + "telegraph_pole.tscn")

	# Dead tree, ~5 m, with bare branches: [height, yaw, tilt, length].
	var tree := _begin(StaticBody3D.new(), "DeadTree")
	cyl(tree, "Trunk", 0.22, 5.0, Vector3(0, 2.5, 0), m_wood_dark, Vector3.ZERO, true, 0.08)
	var branches := [[2.4, 0.0, 0.9, 1.9], [3.1, 2.1, 0.7, 2.3], [3.8, 4.0, 0.8, 1.7], [4.4, 1.0, 0.5, 1.4], [2.9, 5.2, 1.0, 1.5]]
	for b in branches:
		var pivot := node3d(tree, "Branch", Vector3(0, b[0], 0), Vector3(0, b[1], b[2]))
		cyl(pivot, "Limb", 0.07, b[3], Vector3(0, b[3] / 2.0, 0), m_wood_dark, Vector3.ZERO, true, 0.02)
	collider_cyl(tree, 0.25, 5.0, Vector3(0, 2.5, 0))
	_save(ENV_PROPS + "dead_tree.tscn")

	# Rock.
	var rock := _begin(StaticBody3D.new(), "Rock")
	var rock_rot := Vector3(0.2, 0.5, 0.12)
	box(rock, "Body", Vector3(1.2, 0.7, 0.9), Vector3(0, 0.22, 0), m_rock, rock_rot)
	box(rock, "Chunk", Vector3(0.6, 0.4, 0.5), Vector3(0.55, 0.12, 0.35), m_rock, Vector3(0.4, 1.1, 0.2))
	collider_box(rock, Vector3(1.2, 0.7, 0.9), Vector3(0, 0.22, 0), rock_rot)
	_save(ENV_PROPS + "rock.tscn")


# =============================================================================
# Stations
# =============================================================================
# Contract (see scripts/stations/station.gd): root uses Station, a "TrainStop"
# Marker3D at the train's parked origin, track along Z, platforms on +X.

const PLATFORM_H := 0.35
const PLATFORM_EDGE_X := 1.7

## A static mesh with a matching box collider.
func solid(parent: Node, node_name: String, size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation = rot
	_own(body, parent)
	box(body, "Mesh", size, Vector3.ZERO, mat)
	collider_box(body, size, Vector3.ZERO)
	return body


func _begin_station(root_name: String) -> Node3D:
	var root := Node3D.new()
	root.set_script(load("res://scripts/stations/station.gd"))
	_begin(root, root_name)
	var stop := Marker3D.new()
	stop.name = "TrainStop"
	_own(stop, root)
	return root


## Low platform beside the track with a painted edge and ramps at both ends.
func _platform(parent: Node, width: float, length: float) -> void:
	const RAMP_RUN := 3.5
	var group := node3d(parent, "Platform", Vector3.ZERO)
	var cx := PLATFORM_EDGE_X + width / 2.0
	solid(group, "Deck", Vector3(width, PLATFORM_H, length), Vector3(cx, PLATFORM_H / 2.0, 0), m_concrete)
	box(group, "EdgeLine", Vector3(0.3, 0.01, length), Vector3(PLATFORM_EDGE_X + 0.2, PLATFORM_H + 0.005, 0), m_paint_yellow, Vector3.ZERO, false)
	var ramp_len := sqrt(RAMP_RUN * RAMP_RUN + PLATFORM_H * PLATFORM_H)
	var angle := atan(PLATFORM_H / RAMP_RUN)
	for end in [-1.0, 1.0]:
		var z: float = end * (length / 2.0 + RAMP_RUN / 2.0)
		# Positive X rotation raises the -Z end: the +Z ramp needs +angle, the -Z ramp -angle.
		solid(group, "Ramp", Vector3(width, 0.1, ramp_len), Vector3(cx, PLATFORM_H / 2.0 - 0.05, z), m_concrete,
				Vector3(end * angle, 0, 0))


## Two-post name board readable from the track side and the platform side.
func _station_sign(parent: Node, text: String, pos: Vector3) -> void:
	var sign_node := node3d(parent, "StationSign", pos)
	for z in [-1.1, 1.1]:
		cyl(sign_node, "Post", 0.05, 2.7, Vector3(0, 1.35, z), m_dark)
	box(sign_node, "Board", Vector3(0.06, 0.55, 2.5), Vector3(0, 2.45, 0), m_dark)
	for facing in [-1.0, 1.0]:
		var label := Label3D.new()
		label.name = "Name"
		label.text = text
		label.font_size = 96
		label.pixel_size = 0.0035
		label.modulate = Color(0.88, 0.85, 0.78)
		label.outline_size = 0
		label.double_sided = false
		label.position = Vector3(facing * 0.035, 2.45, 0)
		label.rotation.y = facing * PI / 2.0
		_own(label, sign_node)


## Unlit lamp post (no power left). Arm reaches toward the track (-X).
func _lamp_post(parent: Node, pos: Vector3) -> void:
	var post := StaticBody3D.new()
	post.name = "LampPost"
	post.position = pos
	_own(post, parent)
	cyl(post, "Pole", 0.06, 3.4, Vector3(0, 1.7, 0), m_dark)
	box(post, "Arm", Vector3(0.7, 0.06, 0.06), Vector3(-0.32, 3.35, 0), m_dark)
	box(post, "Head", Vector3(0.32, 0.12, 0.22), Vector3(-0.62, 3.28, 0), m_dark)
	collider_cyl(post, 0.08, 3.4, Vector3(0, 1.7, 0))


func _build_stations() -> void:
	_build_mile_214()
	_build_grey_hollow()


## Mile 214 Siding: a lonely halt where the game starts.
func _build_mile_214() -> void:
	var r := _begin_station("Mile214Siding")
	var p := PLATFORM_H
	_platform(r, 4.3, 30.0)
	_station_sign(r, "MILE 214", Vector3(4.2, p, -5.0))
	var shelter := node3d(r, "Shelter", Vector3(4.8, p, 4.0))
	solid(shelter, "BackWall", Vector3(0.12, 2.4, 4.0), Vector3(1.05, 1.2, 0), m_wood_dark)
	solid(shelter, "SideWall", Vector3(2.2, 2.4, 0.12), Vector3(0, 1.2, -1.94), m_wood_dark)
	solid(shelter, "SideWall2", Vector3(2.2, 2.4, 0.12), Vector3(0, 1.2, 1.94), m_wood_dark)
	box(shelter, "Roof", Vector3(2.8, 0.08, 4.6), Vector3(-0.05, 2.48, 0), m_rust, Vector3(0, 0, 0.08))
	solid(shelter, "Bench", Vector3(0.45, 0.45, 2.6), Vector3(0.7, 0.225, 0), m_wood)
	_lamp_post(r, Vector3(5.4, p, -11.0))
	_lamp_post(r, Vector3(5.4, p, 11.0))
	instance(r, ENV_PROPS + "crate.tscn", "Crate", Vector3(4.4, p, -1.6), 15)
	instance(r, ENV_PROPS + "crate_small.tscn", "CrateSmall", Vector3(4.9, p, -0.7), -25)
	instance(r, ENV_PROPS + "oil_drum.tscn", "OilDrum", Vector3(5.4, p, 9.0))
	instance(r, ENV_PROPS + "dead_tree.tscn", "DeadTree", Vector3(9.0, 0, 7.0), 40)
	instance(r, ENV_PROPS + "rock.tscn", "Rock", Vector3(9.5, 0, -9.0), 70)
	instance(r, ENV_PROPS + "telegraph_pole.tscn", "TelegraphPole", Vector3(-6.0, 0, 3.0))
	_save("res://scenes/stations/mile_214_siding.tscn")



# =============================================================================
# Milestone 4: station materials
# =============================================================================

var m_plaster: StandardMaterial3D
var m_brick: StandardMaterial3D
var m_roof: StandardMaterial3D
var m_tile: StandardMaterial3D
var m_car_paint: StandardMaterial3D
var m_sack: StandardMaterial3D
var m_grass: StandardMaterial3D
var m_leaf: StandardMaterial3D
var m_dust: StandardMaterial3D
var m_chainlink: StandardMaterial3D
var m_tube_on: StandardMaterial3D
var m_tube_off: StandardMaterial3D
var m_bulb_red: StandardMaterial3D


func _make_station_materials() -> void:
	# Kit wall materials use the baked planar UVs from _merged_boxes, not triplanar.
	var baked_uv := func(m: StandardMaterial3D) -> void:
		m.uv1_triplanar = false
	m_plaster = _mat("plaster_dirty", Color(0.56, 0.53, 0.47), 0.95, 0.0, 0.55, 0.4, 31, baked_uv)
	m_brick = _mat("brick", Color(0.42, 0.24, 0.18), 0.95, 0.0, 0.45, 1.2, 32, baked_uv)
	m_roof = _mat("roof_tar", Color(0.15, 0.14, 0.13), 0.9, 0.0, 0.4, 0.5, 33)
	m_tile = _mat("floor_tile", Color(0.38, 0.36, 0.32), 0.85, 0.0, 0.5, 0.8, 34)
	m_car_paint = _mat("car_paint_faded", Color(0.22, 0.3, 0.34), 0.7, 0.4, 0.55, 0.8, 35)
	m_sack = _mat("burlap", Color(0.45, 0.38, 0.26), 1.0, 0.0, 0.35, 2.0, 36)
	var foliage := func(m: StandardMaterial3D) -> void:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true  # per-instance colour variation
	m_grass = _mat("grass", Color(0.42, 0.44, 0.24), 1.0, 0.0, 0.0, 1.0, 0, foliage)
	m_leaf = _mat("leaves", Color(0.3, 0.36, 0.18), 0.9, 0.0, 0.0, 1.0, 0, foliage)
	m_dust = _mat("dust_mote", Color(1.0, 0.95, 0.85, 0.22), 1.0, 0.0, 0.0, 1.0, 0, func(m: StandardMaterial3D) -> void:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED)
	m_chainlink = _mat("chainlink", Color(0.32, 0.33, 0.31, 0.45), 0.7, 0.5, 0.0, 1.0, 0, func(m: StandardMaterial3D) -> void:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED)
	m_tube_on = _emissive("tube_lit", Color(0.85, 0.95, 1.0), 2.5)
	m_tube_off = _mat("tube_unlit", Color(0.35, 0.36, 0.36), 0.5, 0.0, 0.0, 1.0, 0)
	m_bulb_red = _emissive("emergency_red", Color(1.0, 0.12, 0.08), 2.0)


## One ArrayMesh from several boxes, so a multi-part piece costs one draw call.
## parts: [[size: Vector3, centre: Vector3, (optional) rotation: Vector3], ...]
##
## UVs are baked as a planar projection in metres along each face's dominant
## axis, so non-triplanar materials (plaster, brick) tile at a consistent
## world scale. Triplanar caused banding on instanced kit walls in the
## Compatibility renderer, so kit materials use these baked UVs instead.
func _merged_boxes(parts: Array, mat: Material) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in parts:
		var bm := BoxMesh.new()
		bm.size = part[0]
		var rot: Vector3 = part[2] if part.size() > 2 else Vector3.ZERO
		var xf := Transform3D(Basis.from_euler(rot), part[1])
		var arrays := bm.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for idx in indices:
			var p := xf * verts[idx]
			var n := (xf.basis * normals[idx]).normalized()
			var a := n.abs()
			var uv := Vector2(p.z, -p.y) if a.x >= a.y and a.x >= a.z else (Vector2(p.x, p.z) if a.y >= a.z else Vector2(p.x, -p.y))
			st.set_normal(n)
			st.set_uv(uv)
			st.add_vertex(p)
	st.index()
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## Instances a prop and tags it as a future loot container (Milestones 5–6).
func loot(parent: Node, path: String, node_name: String, pos: Vector3, rot_y_deg: float = 0.0) -> Node3D:
	var n := instance(parent, path, node_name, pos, rot_y_deg)
	n.add_to_group("loot_container", true)
	return n


# =============================================================================
# Modular building kit: 2 m wall pieces, 3 m tall, 0.2 m thick.
# Origin at the bottom centre, wall runs along local X. Each piece is one
# merged mesh + box colliders. Styles: plaster, brick.
# =============================================================================

const KIT := "res://scenes/environment/kit/"
const WALL_H := 3.0
const WALL_T := 0.2
const KIT_KINDS := ["wall", "door", "window", "opening", "ticket", "broken", "low"]


func _build_kit() -> void:
	for style in ["plaster", "brick"]:
		var mat := m_plaster if style == "plaster" else m_brick
		for kind in KIT_KINDS:
			var parts := _wall_parts(kind)
			var r := _begin(StaticBody3D.new(), "Wall%s%s" % [String(style).capitalize(), String(kind).capitalize()])
			var mi := MeshInstance3D.new()
			mi.name = "Mesh"
			mi.mesh = _merged_boxes(parts, mat)
			_own(mi, r)
			for part in parts:
				collider_box(r, part[0], part[1])
			_save(KIT + "wall_%s_%s.tscn" % [style, kind])


## Box layout per piece. Openings: door 1.2 × 2.3 m, window 1.2 × 1.1 m
## (sill 1.0 m, too small to climb through), ticket window 0.8 × 0.7 m.
func _wall_parts(kind: String) -> Array:
	var t := WALL_T
	var post_l := [Vector3(0.4, WALL_H, t), Vector3(-0.8, WALL_H / 2.0, 0)]
	var post_r := [Vector3(0.4, WALL_H, t), Vector3(0.8, WALL_H / 2.0, 0)]
	match kind:
		"wall":
			return [[Vector3(2.0, WALL_H, t), Vector3(0, WALL_H / 2.0, 0)]]
		"door":
			return [post_l, post_r, [Vector3(1.2, 0.7, t), Vector3(0, 2.65, 0)]]
		"window":
			return [post_l, post_r, [Vector3(1.2, 1.0, t), Vector3(0, 0.5, 0)], [Vector3(1.2, 0.9, t), Vector3(0, 2.55, 0)]]
		"opening":  # lintel only; place two side by side for a 4 m gateway
			return [[Vector3(2.0, 0.4, t), Vector3(0, 2.8, 0)]]
		"ticket":
			return [
				[Vector3(0.6, WALL_H, t), Vector3(-0.7, WALL_H / 2.0, 0)],
				[Vector3(0.6, WALL_H, t), Vector3(0.7, WALL_H / 2.0, 0)],
				[Vector3(0.8, 1.1, t), Vector3(0, 0.55, 0)],
				[Vector3(0.8, 1.2, t), Vector3(0, 2.4, 0)],
				[Vector3(0.9, 0.05, 0.5), Vector3(0, 1.125, 0)],
			]
		"broken", "low":
			# Jagged top from a random walk of 0.25 m columns.
			var broken := kind == "broken"
			var rng := RandomNumberGenerator.new()
			rng.seed = 41 if broken else 42
			var parts := []
			var h := rng.randf_range(1.6, 2.4) if broken else 0.7
			for i in 8:
				h = clampf(h + rng.randf_range(-0.45, 0.45), 1.0 if broken else 0.25, 2.8 if broken else 1.0)
				parts.append([Vector3(0.25, h, t), Vector3(-0.875 + i * 0.25, h / 2.0, 0)])
			return parts
	push_error("Unknown wall kind %s" % kind)
	return []


## Places kit pieces end to end. axis "x" runs along +X from start, "z" along +Z.
## "" leaves a gap. Odd broken pieces are flipped so ruins don't repeat.
func _wall_run(parent: Node, style: String, start: Vector3, axis: String, kinds: Array, prefix: String) -> void:
	var dir := Vector3.RIGHT if axis == "x" else Vector3.BACK
	var base_rot := 0.0 if axis == "x" else -90.0
	for i in kinds.size():
		var kind: String = kinds[i]
		if kind.is_empty():
			continue
		var flip := 180.0 if (kind == "broken" or kind == "low") and i % 2 == 1 else 0.0
		instance(parent, KIT + "wall_%s_%s.tscn" % [style, kind], "%s%d" % [prefix, i],
				start + dir * (i * 2.0 + 1.0), base_rot + flip)


## Flat roof slab sitting on 3 m walls.
func _roof_slab(parent: Node, node_name: String, x0: float, x1: float, z0: float, z1: float) -> void:
	solid(parent, node_name, Vector3(x1 - x0, 0.2, z1 - z0),
			Vector3((x0 + x1) / 2.0, PLATFORM_H + WALL_H + 0.1, (z0 + z1) / 2.0), m_roof)


## Visual-only floor finish 5 mm above the plinth (the plinth provides collision).
func _floor_finish(parent: Node, x0: float, x1: float, z0: float, z1: float) -> void:
	box(parent, "FloorTiles", Vector3(x1 - x0, 0.01, z1 - z0),
			Vector3((x0 + x1) / 2.0, PLATFORM_H + 0.005, (z0 + z1) / 2.0), m_tile, Vector3.ZERO, false)


## Debris pile: one merged mesh; chunks big enough to trip over get colliders.
func _rubble(parent: Node, center: Vector3, radius: float, count: int, rng_seed: int, mat: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var group := StaticBody3D.new()
	group.name = "Rubble"
	group.position = center
	_own(group, parent)
	var parts := []
	for i in count:
		var s := Vector3(rng.randf_range(0.15, 0.6), rng.randf_range(0.08, 0.3), rng.randf_range(0.15, 0.5))
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * radius
		var pos := Vector3(cos(a) * d, s.y * 0.3, sin(a) * d)
		var rot := Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))
		parts.append([s, pos, rot])
		if s.y >= 0.2 and minf(s.x, s.z) >= 0.3:
			collider_box(group, s, pos, rot)
	var mi := MeshInstance3D.new()
	mi.name = "Chunks"
	mi.mesh = _merged_boxes(parts, mat)
	_own(mi, group)


## Chain-link fence along +Z from start, 2.5 m segments. skip = gaps,
## down = panels lying flat (no collision).
func _fence_run(parent: Node, start: Vector3, segments: int, skip: Array, down: Array) -> void:
	var group := node3d(parent, "Fence", start)
	var body := StaticBody3D.new()
	body.name = "FenceCollision"
	_own(body, group)
	var frame := []
	var panels := []
	for i in segments + 1:
		if (i in skip or i == segments) and ((i - 1) in skip or i == 0):
			continue
		frame.append([Vector3(0.08, 1.9, 0.08), Vector3(0, 0.95, i * 2.5)])
	for i in segments:
		if i in skip:
			continue
		var zc := i * 2.5 + 1.25
		if i in down:
			panels.append([Vector3(0.02, 1.6, 2.4), Vector3(-0.85, 0.03, zc), Vector3(0, 0, PI / 2.0 - 0.06)])
		else:
			panels.append([Vector3(0.02, 1.6, 2.4), Vector3(0, 1.0, zc)])
			frame.append([Vector3(0.05, 0.05, 2.5), Vector3(0, 1.85, zc)])
			collider_box(body, Vector3(0.1, 1.9, 2.5), Vector3(0, 0.95, zc))
	var frame_mi := MeshInstance3D.new()
	frame_mi.name = "Frame"
	frame_mi.mesh = _merged_boxes(frame, m_dark)
	_own(frame_mi, group)
	var panel_mi := MeshInstance3D.new()
	panel_mi.name = "Mesh"
	panel_mi.mesh = _merged_boxes(panels, m_chainlink)
	panel_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(panel_mi, group)


# =============================================================================
# Vegetation (MultiMesh: one draw call per patch, no collision)
# =============================================================================

var _tuft: ArrayMesh
var _bush: SphereMesh
var _leaf_quad: QuadMesh


## A grass tuft: 9 tapered blades, darker at the base.
func _tuft_mesh() -> ArrayMesh:
	if _tuft:
		return _tuft
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 9:
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0, sin(a))
		var base := out * rng.randf_range(0.0, 0.08)
		var b := rng.randf() * TAU
		var half := Vector3(cos(b), 0, sin(b)) * 0.02
		var tip := base + out * rng.randf_range(0.03, 0.14) + Vector3(0, rng.randf_range(0.2, 0.45), 0)
		for v in [[base - half, 0.55], [base + half, 0.55], [tip, 1.0]]:
			st.set_normal(Vector3.UP)
			st.set_color(Color(v[1], v[1], v[1]))
			st.add_vertex(v[0])
	_tuft = st.commit()
	_tuft.surface_set_material(0, m_grass)
	return _tuft


func _bush_mesh() -> SphereMesh:
	if _bush == null:
		_bush = SphereMesh.new()
		_bush.radius = 0.6
		_bush.height = 1.0
		_bush.radial_segments = 8
		_bush.rings = 4
		_bush.material = m_leaf
	return _bush


func _excluded(pt: Vector2, exclude: Array) -> bool:
	for rect in exclude:
		if (rect as Rect2).has_point(pt):
			return true
	return false


## Picks a random point in one of rects (area-weighted), skipping exclusions.
func _random_point(rng: RandomNumberGenerator, rects: Array, exclude: Array) -> Variant:
	var total := 0.0
	for rect in rects:
		total += (rect as Rect2).get_area()
	for attempt in 30:
		var pick := rng.randf() * total
		var chosen: Rect2 = rects[0]
		for rect in rects:
			pick -= (rect as Rect2).get_area()
			if pick <= 0.0:
				chosen = rect
				break
		var pt := chosen.position + Vector2(rng.randf() * chosen.size.x, rng.randf() * chosen.size.y)
		if not _excluded(pt, exclude):
			return pt
	return null


func _multimesh(parent: Node, node_name: String, mesh: Mesh, xforms: Array, rng: RandomNumberGenerator,
		color_a: Color, color_b: Color) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, color_a.lerp(color_b, rng.randf()))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_own(mmi, parent)


## Scatters a mesh over rectangles (XZ) at height y.
func _scatter(parent: Node, node_name: String, mesh: Mesh, count: int, rects: Array, y: float, rng_seed: int,
		exclude: Array, scale_range: Vector2, squash_range: Vector2, color_a: Color, color_b: Color, sink: float = 0.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var xforms := []
	for i in count:
		var pt = _random_point(rng, rects, exclude)
		if pt == null:
			continue
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(squash_range.x, squash_range.y), s))
		xforms.append(Transform3D(basis, Vector3(pt.x, y - sink * s, pt.y)))
	_multimesh(parent, node_name, mesh, xforms, rng, color_a, color_b)


## Grass growing along a crack or wall base.
func _grass_line(parent: Node, node_name: String, from: Vector3, to: Vector3, count: int, jitter: float, rng_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var side := (to - from).cross(Vector3.UP).normalized()
	var xforms := []
	for i in count:
		var s := rng.randf_range(0.5, 1.2)
		var pos := from.lerp(to, rng.randf()) + side * rng.randf_range(-jitter, jitter)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos))
	_multimesh(parent, node_name, _tuft_mesh(), xforms, rng, Color(0.75, 0.7, 0.5), Color(1.0, 1.0, 0.9))


## Ivy creeping up a wall face. origin = bottom-left on the wall's centre
## plane, along = unit direction across the wall, normal = outward face.
func _ivy(parent: Node, node_name: String, origin: Vector3, along: Vector3, normal: Vector3,
		width: float, height: float, count: int, rng_seed: int) -> void:
	if _leaf_quad == null:
		_leaf_quad = QuadMesh.new()
		_leaf_quad.size = Vector2(0.16, 0.16)
		_leaf_quad.material = m_leaf
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var face := Basis.looking_at(-normal, Vector3.UP)
	var xforms := []
	for i in count:
		var v := pow(rng.randf(), 1.7)  # denser near the ground
		var u := 0.5 + (rng.randf() - 0.5) * (1.0 - v * 0.6)  # narrower as it climbs
		var pos := origin + along * (u * width) + Vector3.UP * (v * height) + normal * rng.randf_range(0.11, 0.14)
		var b := face * Basis(Vector3(0, 0, 1), rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * rng.randf_range(0.7, 1.4))
		xforms.append(Transform3D(b, pos))
	_multimesh(parent, node_name, _leaf_quad, xforms, rng, Color(0.55, 0.7, 0.45), Color(1.0, 1.0, 0.85))


# =============================================================================
# Station props
# =============================================================================

func _build_station_props() -> void:
	var p := ENV_PROPS

	# Platform bench, 2 m.
	var bench := _begin(StaticBody3D.new(), "Bench")
	for x in [-0.85, 0.85]:
		box(bench, "Leg", Vector3(0.06, 0.45, 0.42), Vector3(x, 0.225, 0), m_dark)
		box(bench, "BackSupport", Vector3(0.06, 0.5, 0.05), Vector3(x, 0.7, -0.2), m_dark, Vector3(-0.15, 0, 0))
	for i in 3:
		box(bench, "Slat", Vector3(2.0, 0.04, 0.12), Vector3(0, 0.47, -0.14 + i * 0.14), m_wood)
	for i in 2:
		box(bench, "BackSlat", Vector3(2.0, 0.1, 0.03), Vector3(0, 0.68 + i * 0.18, -0.23), m_wood, Vector3(-0.15, 0, 0))
	collider_box(bench, Vector3(2.0, 0.95, 0.5), Vector3(0, 0.475, -0.02))
	_save(p + "bench.tscn")

	# Vending machine (loot).
	var vend := _begin(StaticBody3D.new(), "VendingMachine")
	box(vend, "Body", Vector3(0.9, 1.9, 0.8), Vector3(0, 0.95, 0), m_red)
	box(vend, "Inside", Vector3(0.6, 1.1, 0.02), Vector3(-0.08, 1.2, 0.395), m_dark)
	box(vend, "Glass", Vector3(0.62, 1.15, 0.02), Vector3(-0.08, 1.2, 0.41), m_glass, Vector3.ZERO, false)
	box(vend, "Keypad", Vector3(0.16, 0.5, 0.03), Vector3(0.33, 1.25, 0.41), m_dark)
	box(vend, "Slot", Vector3(0.6, 0.18, 0.04), Vector3(-0.08, 0.35, 0.41), m_dark)
	collider_box(vend, Vector3(0.9, 1.9, 0.8), Vector3(0, 0.95, 0))
	_save(p + "vending_machine.tscn")

	# Filing cabinet (loot), top drawer pulled out.
	var cab := _begin(StaticBody3D.new(), "FilingCabinet")
	box(cab, "Body", Vector3(0.5, 1.3, 0.6), Vector3(0, 0.65, 0), m_locker)
	for i in 3:
		box(cab, "Gap", Vector3(0.46, 0.01, 0.012), Vector3(0, 0.46 + i * 0.42, 0.306), m_dark)
		box(cab, "Handle", Vector3(0.12, 0.025, 0.03), Vector3(0, 0.3 + i * 0.42, 0.32), m_dark)
	box(cab, "OpenDrawer", Vector3(0.44, 0.34, 0.35), Vector3(0, 1.1, 0.45), m_locker)
	collider_box(cab, Vector3(0.5, 1.3, 0.6), Vector3(0, 0.65, 0))
	_save(p + "filing_cabinet.tscn")

	# Safe (loot).
	var safe := _begin(StaticBody3D.new(), "Safe")
	box(safe, "Body", Vector3(0.6, 0.7, 0.6), Vector3(0, 0.35, 0), m_dark)
	box(safe, "Door", Vector3(0.5, 0.6, 0.02), Vector3(0, 0.35, 0.305), m_rust)
	cyl(safe, "Dial", 0.05, 0.03, Vector3(0.1, 0.42, 0.32), m_paper, Vector3(PI / 2, 0, 0))
	box(safe, "Handle", Vector3(0.04, 0.14, 0.04), Vector3(-0.12, 0.35, 0.33), m_paper)
	collider_box(safe, Vector3(0.6, 0.7, 0.6), Vector3(0, 0.35, 0))
	_save(p + "safe.tscn")

	# Cash register (loot), sits on a counter.
	var reg := _begin(StaticBody3D.new(), "CashRegister")
	box(reg, "Base", Vector3(0.4, 0.12, 0.36), Vector3(0, 0.06, 0), m_dark)
	box(reg, "Drawer", Vector3(0.36, 0.06, 0.05), Vector3(0, 0.04, 0.2), m_dark)
	box(reg, "Keys", Vector3(0.34, 0.04, 0.18), Vector3(0, 0.14, 0.06), m_locker, Vector3(-0.3, 0, 0))
	box(reg, "Display", Vector3(0.18, 0.1, 0.03), Vector3(0, 0.24, -0.12), m_gauge)
	collider_box(reg, Vector3(0.4, 0.25, 0.36), Vector3(0, 0.125, 0))
	_save(p + "cash_register.tscn")

	# Drinks fridge (loot).
	var fridge := _begin(StaticBody3D.new(), "DrinksFridge")
	box(fridge, "Body", Vector3(0.8, 1.9, 0.7), Vector3(0, 0.95, 0), m_plaster)
	box(fridge, "Inside", Vector3(0.66, 1.55, 0.02), Vector3(0, 1.0, 0.345), m_dark)
	for i in 3:
		box(fridge, "Shelf", Vector3(0.64, 0.02, 0.02), Vector3(0, 0.55 + i * 0.4, 0.35), m_dark)
	box(fridge, "Glass", Vector3(0.7, 1.62, 0.02), Vector3(0, 1.0, 0.36), m_glass, Vector3.ZERO, false)
	box(fridge, "Sign", Vector3(0.8, 0.22, 0.04), Vector3(0, 1.8, 0.37), m_red)
	collider_box(fridge, Vector3(0.8, 1.9, 0.7), Vector3(0, 0.95, 0))
	_save(p + "drinks_fridge.tscn")

	# Office desk with a typewriter.
	var desk := _begin(StaticBody3D.new(), "Desk")
	box(desk, "Top", Vector3(1.4, 0.05, 0.7), Vector3(0, 0.755, 0), m_wood)
	for x in [-0.67, 0.67]:
		box(desk, "Side", Vector3(0.05, 0.73, 0.68), Vector3(x, 0.365, 0), m_wood_dark)
	box(desk, "Drawers", Vector3(0.4, 0.6, 0.65), Vector3(0.43, 0.4, 0), m_wood_dark)
	box(desk, "Typewriter", Vector3(0.4, 0.12, 0.3), Vector3(-0.2, 0.84, 0.05), m_dark)
	box(desk, "Papers", Vector3(0.22, 0.004, 0.3), Vector3(0.3, 0.78, 0.1), m_paper, Vector3(0, 0.3, 0), false)
	collider_box(desk, Vector3(1.4, 0.78, 0.7), Vector3(0, 0.39, 0))
	_save(p + "desk.tscn")

	# Office chair.
	var chair := _begin(StaticBody3D.new(), "OfficeChair")
	cyl(chair, "Base", 0.25, 0.03, Vector3(0, 0.02, 0), m_dark)
	cyl(chair, "Pedestal", 0.04, 0.42, Vector3(0, 0.24, 0), m_dark)
	box(chair, "Seat", Vector3(0.45, 0.08, 0.45), Vector3(0, 0.48, 0), m_seat)
	box(chair, "Back", Vector3(0.45, 0.5, 0.06), Vector3(0, 0.8, -0.2), m_seat, Vector3(-0.1, 0, 0))
	collider_box(chair, Vector3(0.5, 1.05, 0.5), Vector3(0, 0.525, 0))
	_save(p + "office_chair.tscn")

	# Suitcase (loot).
	var case := _begin(StaticBody3D.new(), "Suitcase")
	box(case, "Body", Vector3(0.6, 0.42, 0.2), Vector3(0, 0.21, 0), m_blanket)
	box(case, "Handle", Vector3(0.18, 0.04, 0.03), Vector3(0, 0.44, 0), m_dark)
	box(case, "Strap", Vector3(0.04, 0.43, 0.21), Vector3(0.18, 0.21, 0), m_dark)
	collider_box(case, Vector3(0.6, 0.45, 0.2), Vector3(0, 0.225, 0))
	_save(p + "suitcase.tscn")

	# Luggage cart (loot).
	var cart := _begin(StaticBody3D.new(), "LuggageCart")
	box(cart, "Frame", Vector3(1.62, 0.06, 0.82), Vector3(0, 0.37, 0), m_dark)
	box(cart, "Deck", Vector3(1.6, 0.05, 0.8), Vector3(0, 0.42, 0), m_wood)
	for x in [-0.6, 0.6]:
		for z in [-0.35, 0.35]:
			cyl(cart, "Wheel", 0.16, 0.06, Vector3(x, 0.16, z), m_dark, Vector3(PI / 2, 0, 0))
	for z in [-0.35, 0.35]:
		box(cart, "HandlePost", Vector3(0.05, 0.9, 0.05), Vector3(-0.8, 0.85, z), m_dark)
	box(cart, "HandleBar", Vector3(0.05, 0.05, 0.75), Vector3(-0.8, 1.3, 0), m_dark)
	box(cart, "Bag", Vector3(0.6, 0.35, 0.45), Vector3(0.3, 0.62, 0.05), m_blanket, Vector3(0, 0.2, 0))
	box(cart, "Box", Vector3(0.45, 0.25, 0.35), Vector3(-0.3, 0.57, -0.1), m_cardboard)
	collider_box(cart, Vector3(1.6, 0.8, 0.8), Vector3(0, 0.4, 0))
	_save(p + "luggage_cart.tscn")

	# Car wreck (loot: open boot at +Z). Missing front-left wheel, so it lists.
	var car := _begin(StaticBody3D.new(), "CarWreck")
	var body := node3d(car, "Body", Vector3.ZERO, Vector3(0.03, 0, 0.05))
	box(body, "Lower", Vector3(1.8, 0.65, 4.2), Vector3(0, 0.6, 0), m_car_paint)
	box(body, "Cabin", Vector3(1.6, 0.55, 2.0), Vector3(0, 1.2, 0.2), m_car_paint)
	box(body, "SideWindows", Vector3(1.62, 0.38, 1.7), Vector3(0, 1.22, 0.2), m_dark)
	box(body, "Windscreens", Vector3(1.4, 0.38, 2.02), Vector3(0, 1.22, 0.2), m_dark)
	for z in [-2.12, 2.12]:
		box(body, "Bumper", Vector3(1.9, 0.15, 0.12), Vector3(0, 0.42, z), m_dark)
	box(body, "OpenBoot", Vector3(1.6, 0.04, 0.9), Vector3(0, 1.02, 1.75), m_car_paint, Vector3(-0.35, 0, 0))
	for w in [Vector3(0.85, 0.3, 1.3), Vector3(-0.85, 0.3, 1.3), Vector3(0.85, 0.3, -1.3)]:
		cyl(body, "Wheel", 0.32, 0.22, w, m_dark, Vector3(0, 0, PI / 2))
	collider_box(car, Vector3(1.8, 1.0, 4.2), Vector3(0, 0.5, 0))
	collider_box(car, Vector3(1.6, 0.6, 2.0), Vector3(0, 1.2, 0.2))
	_save(p + "car_wreck.tscn")

	# Forklift wreck.
	var fork := _begin(StaticBody3D.new(), "ForkliftWreck")
	box(fork, "Body", Vector3(1.1, 0.9, 1.8), Vector3(0, 0.65, 0.2), m_paint_yellow)
	box(fork, "Counterweight", Vector3(1.1, 0.6, 0.4), Vector3(0, 0.6, 1.05), m_dark)
	box(fork, "Seat", Vector3(0.5, 0.1, 0.45), Vector3(0, 1.15, 0.4), m_seat)
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.8]:
			box(fork, "GuardPost", Vector3(0.06, 1.1, 0.06), Vector3(x, 1.65, z), m_dark)
		box(fork, "Mast", Vector3(0.08, 2.4, 0.1), Vector3(x * 0.7, 1.2, -0.8), m_dark)
		box(fork, "Fork", Vector3(0.1, 0.05, 1.1), Vector3(x * 0.5, 0.12, -1.4), m_dark)
		cyl(fork, "FrontWheel", 0.28, 0.2, Vector3(x * 1.2, 0.28, -0.4), m_dark, Vector3(0, 0, PI / 2))
		cyl(fork, "RearWheel", 0.22, 0.2, Vector3(x * 1.2, 0.22, 0.9), m_dark, Vector3(0, 0, PI / 2))
	box(fork, "Guard", Vector3(1.1, 0.06, 1.4), Vector3(0, 2.2, 0.15), m_dark)
	collider_box(fork, Vector3(1.3, 2.25, 2.3), Vector3(0, 1.125, 0.05))
	_save(p + "forklift_wreck.tscn")

	# Pallet of sacks.
	var pallet := _begin(StaticBody3D.new(), "PalletSacks")
	box(pallet, "Pallet", Vector3(1.2, 0.14, 1.0), Vector3(0, 0.07, 0), m_wood)
	var sack_rng := RandomNumberGenerator.new()
	sack_rng.seed = 77
	for x in [-0.3, 0.3]:
		for z in [-0.24, 0.24]:
			box(pallet, "Sack", Vector3(0.55, 0.22, 0.45), Vector3(x, 0.25, z), m_sack, Vector3(0, sack_rng.randf_range(-0.15, 0.15), 0))
	box(pallet, "Sack", Vector3(0.55, 0.22, 0.45), Vector3(0, 0.47, 0.1), m_sack, Vector3(0, 0.4, 0))
	collider_box(pallet, Vector3(1.2, 0.6, 1.0), Vector3(0, 0.3, 0))
	_save(p + "pallet_sacks.tscn")

	# Sapling: young tree pushing through the ruins.
	var sap := _begin(StaticBody3D.new(), "Sapling")
	cyl(sap, "Trunk", 0.05, 2.4, Vector3(0, 1.2, 0), m_wood_dark, Vector3.ZERO, true, 0.025)
	sphere(sap, "Canopy", 0.55, Vector3(0, 2.3, 0), m_leaf)
	sphere(sap, "Canopy2", 0.4, Vector3(0.3, 2.0, 0.2), m_leaf)
	sphere(sap, "Canopy3", 0.42, Vector3(-0.25, 2.05, -0.15), m_leaf)
	collider_cyl(sap, 0.07, 2.4, Vector3(0, 1.2, 0))
	_save(p + "sapling.tscn")

	# Departure board (wall mounted, no collision).
	var board := _begin(Node3D.new(), "DepartureBoard")
	box(board, "Frame", Vector3(2.4, 1.0, 0.1), Vector3.ZERO, m_dark)
	var text := Label3D.new()
	text.name = "Text"
	text.text = "DEPARTURES\n\n06:40   KESSEL YARD          CANCELLED\n07:15   NORTH TERMINUS       CANCELLED\n08:05   ASH CREEK            CANCELLED\n--:--   ALL SERVICES         SUSPENDED"
	text.font_size = 28
	text.pixel_size = 0.0026
	text.modulate = Color(0.95, 0.62, 0.25, 0.85)
	text.position = Vector3(0, 0, 0.055)
	_own(text, board)
	_save(p + "departure_board.tscn")

	# Failing fluorescent light. The root is the light (FlickerLight).
	var tube_light := OmniLight3D.new()
	tube_light.set_script(load("res://scripts/environment/flicker_light.gd"))
	tube_light.light_color = Color(0.8, 0.9, 1.0)
	tube_light.light_energy = 1.1
	tube_light.omni_range = 7.0
	_begin(tube_light, "FluorescentLight")
	box(tube_light, "Housing", Vector3(1.3, 0.06, 0.18), Vector3(0, 0.06, 0), m_dark)
	var tube := cyl(tube_light, "Tube", 0.025, 1.2, Vector3(0, 0.0, 0), m_tube_off, Vector3(0, 0, PI / 2), false)
	tube.set_meta(KEEP_SEPARATE, true)  # FlickerLight swaps its material
	for x in [-0.55, 0.55]:
		cyl(tube_light, "Chain", 0.005, 0.6, Vector3(x, 0.39, 0), m_dark, Vector3.ZERO, false)
	tube_light.set("base_energy", 1.1)
	tube_light.set("fixture", tube)
	tube_light.set("lit_material", m_tube_on)
	tube_light.set("unlit_material", m_tube_off)
	_save(p + "fluorescent_light.tscn")

	# Battery emergency light, dim red.
	var emergency := OmniLight3D.new()
	emergency.light_color = Color(1.0, 0.15, 0.1)
	emergency.light_energy = 0.8
	emergency.omni_range = 6.0
	_begin(emergency, "EmergencyLight")
	box(emergency, "Housing", Vector3(0.3, 0.12, 0.1), Vector3(0, 0, -0.03), m_dark)
	box(emergency, "Lens", Vector3(0.24, 0.07, 0.03), Vector3(0, 0, 0.03), m_bulb_red, Vector3.ZERO, false)
	_save(p + "emergency_light.tscn")

	# Dust motes drifting in light shafts.
	var dust := CPUParticles3D.new()
	_begin(dust, "DustMotes")
	dust.amount = 60
	dust.lifetime = 12.0
	dust.preprocess = 12.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(2.0, 1.3, 2.0)
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.initial_velocity_min = 0.01
	dust.initial_velocity_max = 0.06
	dust.gravity = Vector3(0, -0.004, 0)
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	var mote := QuadMesh.new()
	mote.size = Vector2(0.011, 0.011)
	mote.material = m_dust
	dust.mesh = mote
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_save(p + "dust_motes.tscn")


# =============================================================================
# Grey Hollow: abandoned station (Milestone 4)
# =============================================================================
# Everything playable sits on a concrete plinth at platform height (0.35 m)
# spanning x 1.7…31, z −32…32, with ramps at both ends and one to the east
# field. Buildings: ticket office (x 9–17, z −14…2), shop (z 6…14), ruined
# signal box (x 10–16, z 18…24), brick goods warehouse (x 22–30, z −22…−6).

const GH_X1 := 31.0
const GH_Z := 32.0
const GH_ENV := ENV_PROPS


func _build_grey_hollow() -> void:
	var r := _begin_station("GreyHollow")
	_gh_grounds(r)
	_gh_platform(r)
	_gh_ticket_office(r)
	_gh_shop(r)
	_gh_signal_box(r)
	_gh_warehouse(r)
	_gh_yard(r)
	_gh_fields(r)
	_gh_bounds(r)
	_save("res://scenes/stations/grey_hollow.tscn")


func _gh_grounds(r: Node) -> void:
	const RUN := 3.5
	var p := PLATFORM_H
	var g := node3d(r, "Grounds", Vector3.ZERO)
	var cx := (PLATFORM_EDGE_X + GH_X1) / 2.0
	var width := GH_X1 - PLATFORM_EDGE_X
	solid(g, "Plinth", Vector3(width, p, GH_Z * 2.0), Vector3(cx, p / 2.0, 0), m_concrete)
	box(g, "EdgeLine", Vector3(0.3, 0.01, GH_Z * 2.0), Vector3(PLATFORM_EDGE_X + 0.2, p + 0.005, 0), m_paint_yellow, Vector3.ZERO, false)
	box(g, "Kerb", Vector3(0.12, 0.012, GH_Z * 2.0), Vector3(9.0, p + 0.006, 0), m_dark, Vector3.ZERO, false)
	var ramp_len := sqrt(RUN * RUN + p * p)
	var angle := atan(p / RUN)
	for end in [-1.0, 1.0]:
		solid(g, "EndRamp", Vector3(width, 0.1, ramp_len), Vector3(cx, p / 2.0 - 0.05, end * (GH_Z + RUN / 2.0)),
				m_concrete, Vector3(end * angle, 0, 0))
	solid(g, "FieldRamp", Vector3(ramp_len, 0.1, 4.0), Vector3(GH_X1 + RUN / 2.0, p / 2.0 - 0.05, 12.0),
			m_concrete, Vector3(0, 0, -angle))


func _gh_platform(r: Node) -> void:
	var p := PLATFORM_H
	var pf := node3d(r, "Platform", Vector3.ZERO)
	# Canopy: columns + roof over z −14…6.
	for z in [-12.0, -8.0, -4.0, 0.0, 4.0]:
		solid(pf, "CanopyColumn", Vector3(0.3, 3.3, 0.3), Vector3(7.8, p + 1.65, z), m_dark)
	solid(pf, "CanopyRoof", Vector3(5.6, 0.15, 20.0), Vector3(5.8, p + 3.375, -4.0), m_rust)
	box(pf, "CanopyFascia", Vector3(0.1, 0.35, 20.0), Vector3(3.0, p + 3.2, -4.0), m_dark)
	# Collapsed section z 6…14: slab rests from the canopy edge down onto the
	# platform at 23° — a walkable ramp up onto the canopy roof.
	solid(pf, "CollapsedCanopy", Vector3(5.6, 0.15, 8.8), Vector3(5.8, p + 1.656, 10.018), m_rust, Vector3(0.403, 0, 0))
	var fallen := node3d(pf, "FallenColumnPivot", Vector3(7.0, p + 0.15, 16.5), Vector3(PI / 2, 0.6, 0))
	solid(fallen, "FallenColumn", Vector3(0.3, 3.3, 0.3), Vector3.ZERO, m_dark)
	_rubble(pf, Vector3(6.0, p, 15.0), 1.6, 18, 3, m_concrete)
	# Furniture.
	instance(pf, GH_ENV + "bench.tscn", "Bench", Vector3(7.2, p, -10.0), -90)
	instance(pf, GH_ENV + "bench.tscn", "Bench2", Vector3(7.2, p, -2.0), -90)
	instance(pf, GH_ENV + "bench.tscn", "Bench3", Vector3(7.1, p, 2.6), -97)
	for z in [-26.0, -18.0, 18.0, 26.0]:
		_lamp_post(pf, Vector3(8.4, p, z))
	_station_sign(pf, "GREY HOLLOW", Vector3(6.0, p, -17.0))
	_station_sign(pf, "GREY HOLLOW", Vector3(6.0, p, 21.0))
	loot(pf, GH_ENV + "luggage_cart.tscn", "LuggageCart", Vector3(5.6, p, -21.0), 80)
	loot(pf, GH_ENV + "suitcase.tscn", "Suitcase", Vector3(6.9, p, -1.0), -80)
	# Reward for climbing the collapsed canopy.
	loot(pf, GH_ENV + "crate.tscn", "RoofCrate", Vector3(5.8, p + 3.45, -10.0), 20)
	box(pf, "Litter", Vector3(0.3, 0.003, 0.22), Vector3(5.2, p + 0.003, -7.0), m_paper, Vector3(0, 0.6, 0), false)
	box(pf, "Litter", Vector3(0.25, 0.003, 0.3), Vector3(4.4, p + 0.003, 5.0), m_paper, Vector3(0, 1.9, 0), false)
	# Weeds in the cracks along the platform edge and building line.
	_grass_line(pf, "EdgeWeeds", Vector3(2.2, p, -31.0), Vector3(2.2, p, 31.0), 160, 0.15, 101)
	_grass_line(pf, "KerbWeeds", Vector3(8.8, p, -31.0), Vector3(8.8, p, 31.0), 140, 0.2, 102)


func _gh_ticket_office(r: Node) -> void:
	var p := PLATFORM_H
	var b := node3d(r, "TicketOffice", Vector3.ZERO)
	var y := p
	_wall_run(b, "plaster", Vector3(9, y, -14), "z", ["wall", "window", "door", "window", "wall", "wall", "window", "wall"], "WallWest")
	_wall_run(b, "plaster", Vector3(17, y, -14), "z", ["wall", "window", "door", "wall", "window", "wall", "window", "wall"], "WallEast")
	_wall_run(b, "plaster", Vector3(9, y, -14), "x", ["wall", "window", "window", "wall"], "WallSouth")
	_wall_run(b, "plaster", Vector3(9, y, 2), "x", ["wall", "window", "wall", "wall"], "WallNorth")
	_wall_run(b, "plaster", Vector3(9, y, -4), "x", ["ticket", "ticket", "ticket", "door"], "Counter")
	# Roof with a collapsed corner over the waiting hall (light + dust).
	_roof_slab(b, "Roof", 8.8, 17.2, -10.0, 2.2)
	_roof_slab(b, "Roof2", 13.0, 17.2, -14.2, -10.0)
	solid(b, "FallenRoof", Vector3(3.0, 0.2, 2.4), Vector3(10.9, p + 0.7, -12.1), m_roof, Vector3(0.35, 0.4, 0.5))
	_rubble(b, Vector3(11.0, p, -12.0), 1.8, 26, 11, m_plaster)
	_floor_finish(b, 9.1, 16.9, -13.9, 1.9)
	instance(b, GH_ENV + "dust_motes.tscn", "DustMotes", Vector3(11.0, p + 1.6, -12.0))

	# Waiting hall (z −14…−4). Doors at z −9 on both long walls.
	instance(b, GH_ENV + "bench.tscn", "HallBench", Vector3(14.0, p, -11.8), 0)
	instance(b, GH_ENV + "bench.tscn", "HallBench2", Vector3(14.0, p, -6.2), 0)
	loot(b, GH_ENV + "vending_machine.tscn", "VendingMachine", Vector3(16.5, p, -12.9), -90)
	loot(b, GH_ENV + "suitcase.tscn", "Suitcase", Vector3(12.4, p, -11.0), 30)
	var board := instance(b, GH_ENV + "departure_board.tscn", "DepartureBoard", Vector3(12.0, p + 2.45, -4.16), 180)
	board.name = "DepartureBoard"
	box(b, "Poster", Vector3(0.6, 0.85, 0.01), Vector3(9.105, p + 1.7, -12.8), m_paper, Vector3(0, PI / 2, 0), false)
	box(b, "Poster2", Vector3(0.6, 0.85, 0.01), Vector3(16.895, p + 1.6, -7.0), m_red, Vector3(0, PI / 2, 0), false)

	# Ticket office (z −4…2), entered through the counter door at x 16.
	instance(b, GH_ENV + "desk.tscn", "Desk", Vector3(12.5, p, -1.5), 180)
	instance(b, GH_ENV + "office_chair.tscn", "Chair", Vector3(12.7, p, -2.4), 200)
	loot(b, GH_ENV + "filing_cabinet.tscn", "FilingCabinet", Vector3(16.6, p, -1.2), -90)
	loot(b, GH_ENV + "filing_cabinet.tscn", "FilingCabinet2", Vector3(16.6, p, -0.6), -90)
	loot(b, GH_ENV + "safe.tscn", "Safe", Vector3(16.55, p, 1.5), -90)
	loot(b, TRAIN_PROPS + "storage_locker.tscn", "StaffLocker", Vector3(9.35, p, 1.1), 90)
	instance(b, TRAIN_PROPS + "shelf_unit.tscn", "RecordsShelf", Vector3(9.325, p, -2.9), 90)
	box(b, "LoosePapers", Vector3(0.3, 0.003, 0.4), Vector3(14.0, p + 0.01, -0.5), m_paper, Vector3(0, 0.4, 0), false)
	box(b, "LoosePapers2", Vector3(0.3, 0.003, 0.4), Vector3(11.2, p + 0.01, 0.6), m_paper, Vector3(0, 2.2, 0), false)


func _gh_shop(r: Node) -> void:
	var p := PLATFORM_H
	var b := node3d(r, "Shop", Vector3.ZERO)
	var y := p
	_wall_run(b, "plaster", Vector3(9, y, 6), "z", ["window", "door", "window", "wall"], "WallWest")
	_wall_run(b, "plaster", Vector3(17, y, 6), "z", ["wall", "wall", "door", "wall"], "WallEast")
	_wall_run(b, "plaster", Vector3(9, y, 6), "x", ["wall", "wall", "wall", "window"], "WallSouth")
	_wall_run(b, "plaster", Vector3(9, y, 14), "x", ["wall", "wall", "wall", "wall"], "WallNorth")
	_wall_run(b, "plaster", Vector3(14, y, 6), "z", ["wall", "wall", "door", "wall"], "Partition")
	_roof_slab(b, "Roof", 8.8, 17.2, 5.8, 14.2)
	_floor_finish(b, 9.1, 16.9, 6.1, 13.9)

	# Shop floor (x 9…14). Entrance at z 9, storeroom door at z 11.
	instance(b, TRAIN_PROPS + "shelf_unit.tscn", "ShopShelf", Vector3(10.9, p, 6.325), 0)
	instance(b, TRAIN_PROPS + "shelf_unit.tscn", "ShopShelf2", Vector3(12.6, p, 6.325), 0)
	loot(b, GH_ENV + "drinks_fridge.tscn", "DrinksFridge", Vector3(13.55, p, 9.3), -90)
	solid(b, "Counter", Vector3(2.0, 1.0, 0.6), Vector3(11.0, p + 0.5, 12.6), m_wood_dark)
	box(b, "CounterTop", Vector3(2.1, 0.04, 0.66), Vector3(11.0, p + 1.02, 12.6), m_wood)
	loot(b, GH_ENV + "cash_register.tscn", "CashRegister", Vector3(11.5, p + 1.04, 12.6), 180)
	instance(b, GH_ENV + "fluorescent_light.tscn", "FluorescentLight", Vector3(11.5, p + 2.75, 9.8))
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	for i in 6:
		cyl(b, "SpilledCan", 0.04, 0.11, Vector3(rng.randf_range(10.2, 13.0), p + 0.04, rng.randf_range(6.9, 7.6)),
				m_rust, Vector3(PI / 2, rng.randf() * TAU, 0))
	for i in 8:
		var z0 := 6.4 if i < 4 else 10.4
		box(b, "GlassShard", Vector3(0.06, 0.004, 0.1), Vector3(rng.randf_range(9.2, 9.8), p + 0.004, z0 + rng.randf_range(0, 1.2)),
				m_glass, Vector3(0, rng.randf() * TAU, 0), false)

	# Storeroom (x 14…17).
	loot(b, GH_ENV + "crate.tscn", "StoreCrate", Vector3(16.3, p, 7.0), 10)
	loot(b, GH_ENV + "crate_small.tscn", "StoreCrateSmall", Vector3(16.3, p + 0.7, 7.0), -15)
	instance(b, GH_ENV + "pallet_sacks.tscn", "Pallet", Vector3(15.0, p, 7.0), 90)
	instance(b, TRAIN_PROPS + "shelf_unit.tscn", "StoreShelf", Vector3(16.675, p, 13.0), -90)
	loot(b, TRAIN_PROPS + "storage_locker.tscn", "StoreLocker", Vector3(15.0, p, 13.65), 180)
	instance(b, GH_ENV + "oil_drum.tscn", "Drum", Vector3(14.6, p, 9.2))
	_ivy(b, "Ivy", Vector3(17.0, p, 6.2), Vector3.BACK, Vector3.RIGHT, 3.4, 2.8, 260, 71)


func _gh_signal_box(r: Node) -> void:
	var p := PLATFORM_H
	var b := node3d(r, "SignalBoxRuin", Vector3.ZERO)
	var y := p
	_wall_run(b, "plaster", Vector3(10, y, 18), "z", ["broken", "low", "broken"], "WallWest")
	_wall_run(b, "plaster", Vector3(16, y, 18), "z", ["wall", "broken", "low"], "WallEast")
	_wall_run(b, "plaster", Vector3(10, y, 18), "x", ["broken", "door", "low"], "WallSouth")
	_wall_run(b, "plaster", Vector3(10, y, 24), "x", ["low", "broken", "wall"], "WallNorth")
	# Debris kept to the west half so the crate in the NE corner is reachable on foot.
	_rubble(b, Vector3(11.4, p, 22.0), 1.3, 26, 21, m_plaster)
	solid(b, "FallenBeam", Vector3(5.2, 0.22, 0.22), Vector3(11.1, p + 0.5, 21.0), m_wood_dark, Vector3(0, 1.35, 0.15))
	for i in 6:
		cyl(b, "SignalLever", 0.025, 0.9, Vector3(11.4 + i * 0.32, p + 0.4, 19.0), m_rust, Vector3(0.25 - i * 0.12, 0, 0))
	loot(b, GH_ENV + "crate.tscn", "BuriedCrate", Vector3(14.6, p, 22.6), 32)
	instance(b, GH_ENV + "sapling.tscn", "Sapling", Vector3(12.2, p, 23.0), 0)
	_ivy(b, "Ivy", Vector3(16.0, p, 18.1), Vector3.BACK, Vector3.RIGHT, 2.0, 2.6, 180, 72)


func _gh_warehouse(r: Node) -> void:
	var p := PLATFORM_H
	var b := node3d(r, "GoodsWarehouse", Vector3.ZERO)
	var y := p
	_wall_run(b, "brick", Vector3(22, y, -22), "z", ["wall", "window", "wall", "opening", "opening", "wall", "window", "wall"], "WallWest")
	_wall_run(b, "brick", Vector3(30, y, -22), "z", ["wall", "wall", "wall", "window", "wall", "wall", "window", "wall"], "WallEast")
	_wall_run(b, "brick", Vector3(22, y, -22), "x", ["wall", "window", "wall", "wall"], "WallSouth")
	_wall_run(b, "brick", Vector3(22, y, -6), "x", ["wall", "door", "wall", "window"], "WallNorth")
	_wall_run(b, "brick", Vector3(22, y, -18), "x", ["wall", "door", "wall", "wall"], "Partition")
	_roof_slab(b, "Roof", 21.8, 30.2, -22.2, -5.8)

	# Main hall (z −18…−6): 4 m gateway on the west, door at x 25 on the north.
	instance(b, GH_ENV + "forklift_wreck.tscn", "Forklift", Vector3(27.6, p, -10.5), 20)
	instance(b, GH_ENV + "pallet_sacks.tscn", "Pallet", Vector3(28.9, p, -16.6), 90)
	instance(b, GH_ENV + "pallet_sacks.tscn", "Pallet2", Vector3(28.9, p, -14.9), 85)
	instance(b, TRAIN_PROPS + "shelf_unit.tscn", "Shelf", Vector3(29.675, p, -12.6), -90)
	instance(b, TRAIN_PROPS + "shelf_unit.tscn", "Shelf2", Vector3(29.675, p, -7.0), -90)
	loot(b, GH_ENV + "crate.tscn", "Crate", Vector3(23.0, p, -7.0), 5)
	loot(b, GH_ENV + "crate_small.tscn", "CrateSmall", Vector3(23.0, p + 0.7, -7.0), -12)
	loot(b, GH_ENV + "crate.tscn", "Crate2", Vector3(23.0, p, -7.85), -4)
	instance(b, GH_ENV + "oil_drum.tscn", "Drum", Vector3(22.6, p, -11.0))
	instance(b, GH_ENV + "oil_drum.tscn", "Drum2", Vector3(23.25, p, -10.7), 50)
	loot(b, TRAIN_PROPS + "workbench.tscn", "Workbench", Vector3(27.2, p, -17.575), 0)
	instance(b, GH_ENV + "dust_motes.tscn", "DustMotes", Vector3(26.0, p + 1.6, -12.0))

	# Storeroom (z −22…−18), lit only by a battery emergency light.
	instance(b, TRAIN_PROPS + "shelf_unit.tscn", "StoreShelf", Vector3(23.2, p, -21.675), 0)
	instance(b, TRAIN_PROPS + "shelf_unit.tscn", "StoreShelf2", Vector3(27.8, p, -21.675), 0)
	loot(b, TRAIN_PROPS + "storage_locker.tscn", "StoreLocker", Vector3(29.65, p, -20.0), -90)
	loot(b, GH_ENV + "crate.tscn", "StoreCrate", Vector3(26.5, p, -20.3), 18)
	instance(b, GH_ENV + "emergency_light.tscn", "EmergencyLight", Vector3(25.0, p + 2.6, -21.85))
	_ivy(b, "Ivy", Vector3(22.0, p, -22.0), Vector3.BACK, Vector3.LEFT, 5.5, 2.9, 320, 73)


func _gh_yard(r: Node) -> void:
	var p := PLATFORM_H
	var yd := node3d(r, "Yard", Vector3.ZERO)
	loot(yd, GH_ENV + "car_wreck.tscn", "CarWreck", Vector3(21.0, p, 17.0), 75)
	var pole := node3d(yd, "FallenPolePivot", Vector3(24.5, p + 0.12, 26.0), Vector3(0, 0.35, PI / 2))
	instance(pole, GH_ENV + "telegraph_pole.tscn", "FallenPole", Vector3.ZERO)
	# Stack of old sleepers behind the ticket office.
	var stack := StaticBody3D.new()
	stack.name = "SleeperStack"
	stack.position = Vector3(19.5, p, -3.0)
	_own(stack, yd)
	var sleepers := []
	for layer in 3:
		for i in 4:
			sleepers.append([Vector3(2.4, 0.15, 0.25), Vector3(0, 0.075 + layer * 0.15, -0.5 + i * 0.33 + (0.08 if layer % 2 == 1 else 0.0)),
					Vector3(0, (layer - 1) * 0.05, 0)])
	var stack_mesh := MeshInstance3D.new()
	stack_mesh.name = "Mesh"
	stack_mesh.mesh = _merged_boxes(sleepers, m_wood_dark)
	_own(stack_mesh, stack)
	collider_box(stack, Vector3(2.5, 0.45, 1.4), Vector3(0, 0.225, 0))
	# Alley between the ticket office and the shop.
	var bin := node3d(yd, "ToppledDrumPivot", Vector3(12.0, p + 0.3, 4.2), Vector3(0, 0.4, PI / 2))
	# Offset along the pivot's own Y (now horizontal) so the drum is centred on the pivot.
	instance(bin, GH_ENV + "oil_drum.tscn", "ToppledDrum", Vector3(0, -0.44, 0))
	instance(yd, GH_ENV + "crate.tscn", "AlleyCrate", Vector3(15.6, p, 3.2), 25)
	# Broken chain-link fence on the east edge, gap at the field ramp (z 10…15).
	_fence_run(yd, Vector3(30.8, p, -5.0), 14, [6, 7], [3, 11])
	for pos in [Vector3(28.5, p, 24.0), Vector3(19.0, p, 30.0), Vector3(26.0, p, 3.0)]:
		instance(yd, GH_ENV + "sapling.tscn", "Sapling", pos, pos.x * 40.0)
	# Overgrowth on the plinth.
	var tuft := _tuft_mesh()
	var green := Color(0.8, 0.85, 0.6)
	var dry := Color(1.0, 0.95, 0.75)
	_scatter(yd, "YardGrass", tuft, 750, [Rect2(17.2, -5.8, 13.4, 37.6)], p, 201, [Rect2(19.0, 14.6, 4.2, 4.8)],
			Vector2(0.7, 1.4), Vector2(0.8, 1.3), green, dry)
	_scatter(yd, "BackGrass", tuft, 220, [Rect2(17.2, -21.8, 4.6, 15.8)], p, 202, [], Vector2(0.7, 1.3), Vector2(0.8, 1.2), green, dry)
	_scatter(yd, "AlleyGrass", tuft, 140, [Rect2(9.2, 2.2, 7.6, 3.6)], p, 203, [], Vector2(0.6, 1.2), Vector2(0.8, 1.2), green, dry)
	_scatter(yd, "RuinGrass", tuft, 380, [Rect2(9.2, 14.4, 7.6, 17.4)], p, 204, [], Vector2(0.7, 1.5), Vector2(0.9, 1.4), green, dry)
	_scatter(yd, "YardBushes", _bush_mesh(), 16, [Rect2(18.0, 20.0, 12.0, 11.5), Rect2(18.0, -5.5, 3.5, 6.0)], p, 205,
			[], Vector2(0.6, 1.1), Vector2(0.6, 0.9), Color(0.65, 0.75, 0.55), Color(0.95, 1.0, 0.8), 0.15)
	_ivy(yd, "IvyOfficeEnd", Vector3(9.4, p, -14.0), Vector3.RIGHT, Vector3.FORWARD, 5.0, 2.9, 300, 74)


## Fields around the plinth (ground level y = 0). Track band |x| < 4 stays
## clear because the station slides past the train on that line.
func _gh_fields(r: Node) -> void:
	var f := node3d(r, "Fields", Vector3.ZERO)
	var exclude := [Rect2(1.5, -36.0, GH_X1 - 1.5 + 0.2, 72.0), Rect2(GH_X1, 9.8, 3.8, 4.4), Rect2(-4.0, -60.0, 8.0, 120.0)]
	var east := Rect2(GH_X1 + 0.2, -54.0, 20.5, 108.0)
	var west := Rect2(-20.0, -54.0, 16.0, 108.0)
	var north := Rect2(4.0, 35.6, 27.0, 18.4)
	var south := Rect2(4.0, -54.0, 27.0, 18.4)
	var fields := [east, west, north, south]
	_scatter(f, "FieldGrass", _tuft_mesh(), 4200, fields, 0.0, 301, exclude, Vector2(0.8, 1.7), Vector2(0.9, 1.6),
			Color(0.75, 0.8, 0.55), Color(1.0, 0.95, 0.7))
	_scatter(f, "FieldBushes", _bush_mesh(), 110, fields, 0.0, 302, exclude, Vector2(0.6, 1.5), Vector2(0.6, 0.9),
			Color(0.55, 0.65, 0.45), Color(0.9, 0.95, 0.75), 0.15)
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	var props := [["dead_tree.tscn", 10], ["sapling.tscn", 10], ["rock.tscn", 10]]
	for entry in props:
		for i in entry[1]:
			var pt = _random_point(rng, fields, exclude)
			if pt != null:
				instance(f, GH_ENV + entry[0], String(entry[0]).get_basename().to_pascal_case(), Vector3(pt.x, 0, pt.y), rng.randf() * 360.0)
	for z in [-45.0, 0.0, 45.0]:
		instance(f, GH_ENV + "telegraph_pole.tscn", "TelegraphPole", Vector3(-6.0, 0, z), 0)


## Invisible walls keeping the player near the station (only active while parked).
func _gh_bounds(r: Node) -> void:
	var bounds := node3d(r, "Bounds", Vector3.ZERO)
	var walls := [
		[Vector3(1.0, 6.0, 112.0), Vector3(-20.5, 3.0, 0.0)],
		[Vector3(1.0, 6.0, 112.0), Vector3(52.5, 3.0, 0.0)],
		[Vector3(74.0, 6.0, 1.0), Vector3(16.0, 3.0, -55.5)],
		[Vector3(74.0, 6.0, 1.0), Vector3(16.0, 3.0, 55.5)],
	]
	for w in walls:
		var body := StaticBody3D.new()
		body.name = "Boundary"
		_own(body, bounds)
		collider_box(body, w[0], w[1])


# =============================================================================
# Draw-call optimisation: merge static meshes on save
# =============================================================================
# Every scene is saved through _save(), which first merges the scene's own
# (owned) static MeshInstance3D nodes that share a material and render
# settings into one mesh. Instanced sub-scenes are left alone (they are merged
# when they themselves are generated). Never merged:
# - anything under a node with the KEEP_SEPARATE meta (animated levers, the
#   flickering tube whose material is swapped at runtime),
# - anything under an AnimatableBody3D (moving doors),
# - meshes with a material_override or several surfaces.
# Distance-culled detail meshes are merged per DETAIL_CELL cell so their
# visibility range stays local to where they are.

const KEEP_SEPARATE := &"keep_separate"
const DETAIL_CELL := 4.0


func _merge_static_meshes(root: Node) -> void:
	var groups := {}
	for node in root.find_children("*", "MeshInstance3D", true, true):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.material_override != null or mi.mesh.get_surface_count() != 1:
			continue
		if _is_merge_protected(mi, root):
			continue
		var mat := mi.mesh.surface_get_material(0)
		if mat == null:
			continue
		var xf := _relative_transform(mi, root)
		var cell := Vector3i.ZERO
		if mi.visibility_range_end > 0.0:
			cell = Vector3i((xf.origin / DETAIL_CELL).floor())
		var key := "%s|%d|%s|%s" % [mat.resource_path, mi.cast_shadow, mi.visibility_range_end, cell]
		if not groups.has(key):
			groups[key] = []
		groups[key].append([mi, xf])

	for key in groups:
		var members: Array = groups[key]
		if members.size() < 2:
			continue
		var first: MeshInstance3D = members[0][0]
		var centre := Vector3.ZERO
		for m in members:
			centre += (m[1] as Transform3D).origin
		centre /= members.size()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for m in members:
			st.append_from((m[0] as MeshInstance3D).mesh, 0, Transform3D(Basis.IDENTITY, -centre) * (m[1] as Transform3D))
		var mesh := st.commit()
		mesh.surface_set_material(0, first.mesh.surface_get_material(0))
		var merged := MeshInstance3D.new()
		merged.name = "Merged"
		merged.mesh = mesh
		merged.position = centre
		merged.cast_shadow = first.cast_shadow
		merged.visibility_range_end = first.visibility_range_end
		merged.visibility_range_end_margin = first.visibility_range_end_margin
		merged.visibility_range_fade_mode = first.visibility_range_fade_mode
		root.add_child(merged, true)
		merged.owner = root
		for m in members:
			var old: MeshInstance3D = m[0]
			old.get_parent().remove_child(old)
			old.free()


func _relative_transform(node: Node3D, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node = node
	while n != root and n != null:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf


func _is_merge_protected(node: Node, root: Node) -> bool:
	var n := node
	while n != null:
		if n.has_meta(KEEP_SEPARATE) or n is AnimatableBody3D:
			return true
		if n == root:
			break
		n = n.get_parent()
	return false
