# The Level scene: terrain, sea and beach, the stone Track, buildings and
# vegetation, all driven by one entry of scripts/maps.gd (route, theme, shore
# side, seed). Gameplay code asks it where heroes may be built.
extends Node3D

const Models = preload("res://scripts/models.gd")
const Defs = preload("res://scripts/defs.gd")
const Maps = preload("res://scripts/maps.gd")
const TrackScene = preload("res://scenes/track/track.tscn")
const TrackScript = preload("res://scripts/track/track.gd")
const HouseScene = preload("res://scenes/props/house.tscn")
const WindmillScene = preload("res://scenes/props/windmill.tscn")
const TreeScene = preload("res://scenes/props/tree.tscn")
const PalmScene = preload("res://scenes/props/palm.tscn")
const BushScene = preload("res://scenes/props/bush.tscn")
const RockScene = preload("res://scenes/props/rock.tscn")
const DecoScene = preload("res://scenes/props/decoration.tscn")

## Left-side shoreline: x of the grass edge at a given z (the sea is at smaller x).
const SHORE_LEFT := [
	Vector2(-4, -46), Vector2(-14, -34), Vector2(-22, -26), Vector2(-28, -19), Vector2(-32, -11),
	Vector2(-34.5, -2), Vector2(-36, 8), Vector2(-37, 18), Vector2(-38, 30), Vector2(-39, 46),
]
## Area where heroes may be placed.
const PLAY_MIN := Vector2(-37.0, -21.0)
const PLAY_MAX := Vector2(34.0, 21.0)

## Visual themes: ground and water colours, stone tint, vegetation and lighting.
const THEMES := {
	"meadow": {
		"grass": 0x86d040, "lip": 0x9ccf55, "patches": [0x74c234, 0x97da4f, 0x7cc83a, 0xa3e05a],
		"sand": 0xf5df9e, "sea": 0x1f9ad6, "shallow": 0x5fd0ef, "foam": 0xeafcff, "stone": [1.0, 1.0, 1.0],
		"flowers": [0xffffff, 0xfff3a0, 0xffb3d1, 0xffffff, 0xc9a6ff], "tufts": [0x4fa82a, 0x5fbb33, 0x3f9a24],
		"trees": ["round", "round", "round", "round", "sakura", "bush"], "inner": ["bush", "rock", "lantern", "crates"],
		"palms": true, "particles": [0xffc1dc, 50],
		"sun": 0xfff1dc, "sun_energy": 0.8, "ambient": 0xfffaeb, "ambient_energy": 0.3, "sky_top": 0x3d9df2, "sky_horizon": 0xbfe8ff,
	},
	"autumn": {
		"grass": 0xa9c24a, "lip": 0xb8c95c, "patches": [0xc4b24a, 0x9fb840, 0xd1a845, 0xb5c25a],
		"sand": 0xf0d9a0, "sea": 0x2a8fc9, "shallow": 0x6cc8e6, "foam": 0xf2fbff, "stone": [1.04, 0.98, 0.92],
		"flowers": [0xffd34d, 0xff9a3d, 0xffffff, 0xe8603c], "tufts": [0x8f9a3a, 0xa38f3a, 0x7d8f33],
		"trees": ["autumn", "autumn", "autumn", "autumn", "round", "bush"], "inner": ["hay", "rock", "crates", "bush"],
		"palms": false, "particles": [0xe8792f, 80],
		"sun": 0xffe2b8, "sun_energy": 0.8, "ambient": 0xfff0dc, "ambient_energy": 0.3, "sky_top": 0x4f9fe0, "sky_horizon": 0xffe0b0,
	},
	"snow": {
		"grass": 0xeef3fa, "lip": 0xdde7f2, "patches": [0xe3ebf5, 0xf8fbff, 0xd8e3ef, 0xe9f0f8],
		"sand": 0xcfd9e4, "sea": 0x3a7fc1, "shallow": 0x8fcbe8, "foam": 0xffffff, "stone": [0.9, 0.95, 1.06],
		"flowers": [0xffffff, 0xbfe6ff, 0xe0f2ff], "tufts": [0xc9d6e4, 0xb6c7d9, 0xdde6f0],
		"trees": ["snowpine", "snowpine", "snowpine", "pine", "rock"], "inner": ["rock", "lantern", "crates"],
		"palms": false, "particles": [0xffffff, 170],
		"sun": 0xeaf4ff, "sun_energy": 0.72, "ambient": 0xe6f0ff, "ambient_energy": 0.32, "sky_top": 0x7fb6e8, "sky_horizon": 0xe8f2ff,
	},
	"desert": {
		"grass": 0xe6c27f, "lip": 0xdcb56f, "patches": [0xd9b06a, 0xefcf8f, 0xe2bb77, 0xd4a862],
		"sand": 0xf3dfae, "sea": 0x23a9c6, "shallow": 0x6fd8e0, "foam": 0xf2ffff, "stone": [1.12, 0.98, 0.8],
		"flowers": [0xff7eb6, 0xffd34d, 0xffffff], "tufts": [0xa8a456, 0x8f9a45, 0xb5a55a],
		"trees": ["cactus", "cactus", "palm", "rock", "cactus"], "inner": ["rock", "cactus", "crates"],
		"palms": true, "particles": [0xf3dfae, 0],
		"sun": 0xfff0d0, "sun_energy": 0.85, "ambient": 0xfff2dc, "ambient_energy": 0.32, "sky_top": 0x48a8f0, "sky_horizon": 0xfff0c8,
	},
	"sakura": {
		"grass": 0x8fd36a, "lip": 0xa3dc7c, "patches": [0x9fdc7a, 0x82c85c, 0xb3e38c, 0x8fd36a],
		"sand": 0xf7e4b5, "sea": 0x2ea3dc, "shallow": 0x74d6f0, "foam": 0xffffff, "stone": [1.02, 0.98, 1.0],
		"flowers": [0xffb3d1, 0xff8fbf, 0xffffff, 0xffd1e6], "tufts": [0x5fbb33, 0x6fc848, 0x4fa82a],
		"trees": ["sakura", "sakura", "sakura", "round", "bush"], "inner": ["lantern", "bush", "rock"],
		"palms": false, "particles": [0xffc1dc, 140],
		"sun": 0xfff3f0, "sun_energy": 0.8, "ambient": 0xfff0f6, "ambient_energy": 0.32, "sky_top": 0x5aa8f0, "sky_horizon": 0xffd9ec,
	},
	"dusk": {
		"grass": 0x5f9e48, "lip": 0x6fae55, "patches": [0x548f3f, 0x6aa852, 0x4f8a3c, 0x73b05a],
		"sand": 0xd9c08e, "sea": 0x1d4f8e, "shallow": 0x3e7fb8, "foam": 0xc8dcff, "stone": [0.86, 0.84, 0.98],
		"flowers": [0xc9a6ff, 0xfff59d, 0xffffff], "tufts": [0x3f7d2a, 0x4a8a33, 0x356b24],
		"trees": ["round", "round", "pine", "sakura", "bush"], "inner": ["lantern", "lantern", "rock", "bush"],
		"palms": true, "particles": [0xfff59d, 90],
		"sun": 0xffa97a, "sun_energy": 0.6, "ambient": 0x9d8cff, "ambient_energy": 0.42, "sky_top": 0x2e2363, "sky_horizon": 0xff9f6b,
	},
}

## Set before adding to the tree; defaults to the first map.
var map: Dictionary = Maps.MAPS[0]
var theme: Dictionary
var track
var blockers: Array = []   # Vector3(x, z, radius) for every prop
var _vegetation: Node3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	theme = THEMES.get(map.get("theme", "meadow"), THEMES["meadow"])
	_rng.seed = int(map.get("seed", 2024))
	_build_terrain()
	track = TrackScene.instantiate()
	track.name = "Track"
	track.route = map["route"]
	var tint: Array = theme["stone"]
	track.stone_tint = Color(tint[0], tint[1], tint[2])
	add_child(track)
	_build_landmarks()
	_build_ground_details()
	_vegetation = Node3D.new()
	_vegetation.name = "Vegetation"
	add_child(_vegetation)
	_build_vegetation()
	_batch_meshes(_vegetation)
	_build_particles()

# ---------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------
func shore_side() -> String:
	return map.get("shore", "none")

func _shore_left_x(z: float) -> float:
	var x: float = SHORE_LEFT[0].x
	if z >= SHORE_LEFT[SHORE_LEFT.size() - 1].y:
		x = SHORE_LEFT[SHORE_LEFT.size() - 1].x
	else:
		for i in range(1, SHORE_LEFT.size()):
			var a: Vector2 = SHORE_LEFT[i - 1]
			var b: Vector2 = SHORE_LEFT[i]
			if z <= b.y:
				x = lerpf(a.x, b.x, clampf((z - a.y) / (b.y - a.y), 0.0, 1.0))
				break
	return x + 0.6 * sin(z * 0.37)

func _shore_top_z(x: float) -> float:
	return -20.8 + 1.1 * sin(x * 0.11 + 0.5) + 0.6 * sin(x * 0.29) - 2.5 * clampf((x + 10.0) / -25.0, 0.0, 1.0)

func _shore_bottom_z(x: float) -> float:
	return 20.8 + 1.1 * sin(x * 0.13 + 1.7) + 0.6 * sin(x * 0.31) + 2.0 * clampf((x - 10.0) / 25.0, 0.0, 1.0)

## How far (x, z) is inland from the shoreline (negative = in the sea).
func land_value(x: float, z: float) -> float:
	match shore_side():
		"left":
			return x - _shore_left_x(z)
		"top":
			return z - _shore_top_z(x)
		"bottom":
			return _shore_bottom_z(x) - z
	return 999.0

func is_land(x: float, z: float, margin: float = 0.0) -> bool:
	return land_value(x, z) > margin

## Distance from (x, z) to the nearest track cell square (0 if on the track).
func track_distance(x: float, z: float) -> float:
	var best := INF
	var half: float = TrackScript.CELL / 2.0
	for c in track.cells:
		var p: Vector3 = TrackScript.cell_to_world(c)
		var dx := maxf(absf(x - p.x) - half, 0.0)
		var dz := maxf(absf(z - p.z) - half, 0.0)
		best = minf(best, sqrt(dx * dx + dz * dz))
	return best

func blocked(x: float, z: float, r: float) -> bool:
	for b in blockers:
		if Vector2(b.x, b.y).distance_to(Vector2(x, z)) < b.z + r:
			return true
	return false

func is_buildable(x: float, z: float) -> bool:
	if x < PLAY_MIN.x or x > PLAY_MAX.x or z < PLAY_MIN.y or z > PLAY_MAX.y:
		return false
	return is_land(x, z, 2.0) and not blocked(x, z, 0.8)

# ---------------------------------------------------------------------
# Terrain: stacked flat layers seen from above
# ---------------------------------------------------------------------
## Land polygon with the shoreline pushed `offset` units inland (negative = out to sea).
func _land_poly(offset: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shore_side():
		"left":
			var z := -120.0
			while z <= 120.0:
				pts.append(Vector2(_shore_left_x(z) + offset, z))
				z += 1.5
			pts.append(Vector2(200.0, 120.0))
			pts.append(Vector2(200.0, -120.0))
		"top":
			var x := -200.0
			while x <= 200.0:
				pts.append(Vector2(x, _shore_top_z(x) + offset))
				x += 1.5
			pts.append(Vector2(200.0, 150.0))
			pts.append(Vector2(-200.0, 150.0))
		"bottom":
			var x2 := -200.0
			while x2 <= 200.0:
				pts.append(Vector2(x2, _shore_bottom_z(x2) - offset))
				x2 += 1.5
			pts.append(Vector2(200.0, -150.0))
			pts.append(Vector2(-200.0, -150.0))
	return pts

func _poly_mesh(poly: PackedVector2Array, y: float, hex: int) -> MeshInstance3D:
	var idx := Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in idx:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(poly[i].x, y, poly[i].y))
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = _flat(hex)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _flat(hex: int) -> StandardMaterial3D:
	var mat := Models.make_toon(Defs.col(hex), false)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

func _build_terrain() -> void:
	var sea := PlaneMesh.new()
	sea.size = Vector2(900, 900)
	if shore_side() == "none":
		add_child(Models.mi(sea, _flat(theme["grass"]), Vector3(0, 0, 0)))
		return
	add_child(Models.mi(sea, _flat(theme["sea"]), Vector3(0, -0.45, 0)))
	add_child(_poly_mesh(_land_poly(-9.0), -0.38, theme["shallow"]))
	add_child(_poly_mesh(_land_poly(-5.0), -0.33, theme["foam"]))
	add_child(_poly_mesh(_land_poly(-4.0), -0.22, theme["sand"]))
	add_child(_poly_mesh(_land_poly(-0.6), -0.1, theme["lip"]))
	add_child(_poly_mesh(_land_poly(0.0), 0.0, theme["grass"]))

# ---------------------------------------------------------------------
# Landmarks: shrine at the exit, torii, spirit portal, windmill, cottages
# ---------------------------------------------------------------------
func _place(scene: PackedScene, pos: Vector3, rot_y: float = 0.0, props: Dictionary = {}, parent: Node = null) -> Node3D:
	var n = scene.instantiate()
	for k in props:
		n.set(k, props[k])
	n.position = pos
	n.rotation.y = rot_y
	(parent if parent else self).add_child(n)
	blockers.append(Vector3(pos.x, pos.z, float(n.get_meta("r", 1.2))))
	return n

func _build_landmarks() -> void:
	var cells: Array = track.cells
	var exit_p: Vector3 = TrackScript.cell_to_world(cells[cells.size() - 1])
	var last_tile: Vector3 = TrackScript.cell_to_world(cells[cells.size() - 2])
	var entry_p: Vector3 = TrackScript.cell_to_world(cells[0])
	var entry_tile: Vector3 = TrackScript.cell_to_world(cells[1])

	# Shrine just past the exit, facing back up the track.
	var out_dir := (exit_p - last_tile).normalized()
	var shrine := Models.shrine()
	shrine.position = exit_p + out_dir * 2.6
	shrine.rotation.y = atan2(out_dir.x, out_dir.z) + PI
	add_child(shrine)
	Models.collide_box(shrine, Vector3(5, 5, 4.2), Vector3(0, 2.5, 0))
	blockers.append(Vector3(shrine.position.x, shrine.position.z, 3.6))

	# Torii gate straddles the track where it leaves the last tile.
	var gate := (last_tile + exit_p) / 2.0
	var torii := Models.torii()
	torii.position = gate
	torii.rotation.y = atan2(out_dir.x, out_dir.z)
	add_child(torii)
	var side := Vector3(out_dir.z, 0, -out_dir.x) * 2.5
	blockers.append(Vector3(gate.x + side.x, gate.z + side.z, 0.8))
	blockers.append(Vector3(gate.x - side.x, gate.z - side.z, 0.8))

	# Spirit portal at the entry.
	var in_dir := (entry_tile - entry_p).normalized()
	var portal := Node3D.new()
	portal.name = "SpiritPortal"
	Models.add(portal, Models.torus(2.5, 0.35), Models.toon(0x5a2d82), Vector3(0, 2.5, 0), Vector3(PI / 2, 0, 0))
	var swirl := Models.fx_mat(Defs.col(0x9d5cff, 0.55))
	Models.add(portal, Models.cyl(2.4, 2.4, 0.05, 36), swirl, Vector3(0, 2.5, 0), Vector3(PI / 2, 0, 0))
	portal.position = entry_tile - in_dir * 1.6
	portal.rotation.y = atan2(in_dir.x, in_dir.z)
	add_child(portal)
	var tw := create_tween().set_loops()
	tw.tween_property(swirl, "albedo_color:a", 0.25, 1.2)
	tw.tween_property(swirl, "albedo_color:a", 0.6, 1.2)

	_place_buildings()

# A small village: 2-4 cottages, usually a windmill, and a few props, placed in
# open grass near (but clear of) the track.
func _place_buildings() -> void:
	var wanted: Array = []
	if _rng.randf() < 0.7:
		wanted.append(["windmill", 3.4])
	var houses := 2 + _rng.randi() % 3
	for i in range(houses):
		wanted.append(["house", 3.4])
	var variant := _rng.randi() % 4
	for w in wanted:
		for attempt in range(500):
			var x := _rng.randf_range(-34.0, 27.0)
			var z := _rng.randf_range(-18.5, 18.5)
			var r: float = w[1]
			if not is_land(x, z, r + 1.5):
				continue
			var td := track_distance(x, z)
			if td < r - 0.6 or td > r + 5.0:
				continue
			if blocked(x, z, r + 1.0):
				continue
			if w[0] == "windmill":
				_place(WindmillScene, Vector3(x, 0, z), _rng.randf_range(-0.3, 0.3))
			else:
				_place(HouseScene, Vector3(x, 0, z), _rng.randf_range(-0.25, 0.25), {"variant": variant})
				variant = (variant + 1) % 4
				# A prop beside the cottage
				var px := x + _rng.randf_range(-3.2, 3.2)
				var pz := z + 3.2
				if is_land(px, pz, 1.5) and track_distance(px, pz) > 1.2 and not blocked(px, pz, 0.9):
					var kinds: Array = theme["inner"]
					var kind: String = kinds[_rng.randi() % kinds.size()]
					if kind in ["crates", "hay", "lantern"]:
						_place(DecoScene, Vector3(px, 0, pz), _rng.randf() * TAU, {"kind": kind})
			break

# ---------------------------------------------------------------------
# Grass patches, flowers and tufts (instanced)
# ---------------------------------------------------------------------
func _cols(key: String) -> Array:
	var out: Array = []
	for h in theme[key]:
		out.append(Defs.col(h))
	return out

func _build_ground_details() -> void:
	var patch_items: Array = []
	var fl: Array = []
	var tf: Array = []
	var greens := _cols("patches")
	var flower_cols := _cols("flowers")
	var tuft_cols := _cols("tufts")
	for i in range(70):
		var x := _rng.randf_range(-40, 46)
		var z := _rng.randf_range(-30, 30)
		if not is_land(x, z, 2.0) or track_distance(x, z) < 0.5:
			continue
		var r := _rng.randf_range(2.0, 5.5)
		var b := Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3(r, 1.0, r * _rng.randf_range(0.45, 0.9)))
		patch_items.append([Transform3D(b, Vector3(x, 0.01, z)), greens[i % greens.size()]])
	for i in range(2400):
		var x := _rng.randf_range(-42, 50)
		var z := _rng.randf_range(-32, 32)
		if not is_land(x, z, 0.8) or track_distance(x, z) < 0.35:
			continue
		if i % 3 == 0:
			var s := _rng.randf_range(0.7, 1.3)
			fl.append([Transform3D(Basis.from_scale(Vector3(s, 0.5 * s, s)), Vector3(x, 0.06, z)), flower_cols[i % flower_cols.size()]])
		else:
			var s2 := _rng.randf_range(0.8, 1.5)
			tf.append([Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * s2), Vector3(x, 0.15 * s2, z)), tuft_cols[i % tuft_cols.size()]])
	add_child(Models.batch(Models.cyl(1.0, 1.0, 0.02, 20), patch_items, false, false))
	add_child(Models.batch(Models.sphere(0.13, 6), fl, false, false))
	add_child(Models.batch(Models.cone(0.13, 0.32, 4), tf, false, false))

# ---------------------------------------------------------------------
# Vegetation: dense trees in the outer corners, palms on the beach,
# only a few small props inside so heroes have room.
# ---------------------------------------------------------------------
func _zone_weight(x: float, z: float) -> float:
	for corner in [Vector2(-38, -24), Vector2(32, -24), Vector2(-38, 24), Vector2(32, 24)]:
		if absf(x - corner.x) < 15.0 and absf(z - corner.y) < 8.5:
			return 1.0
	if absf(z) > 21.0 or x > 33.0 or x < -36.0:
		return 0.7
	return 0.04

func _spawn_tree(kind: String, pos: Vector3, size: float) -> void:
	var rot := _rng.randf() * TAU
	match kind:
		"bush":
			_place(BushScene, pos, rot, {"size": size * 1.1, "bush_seed": _rng.randi()}, _vegetation)
		"rock":
			_place(RockScene, pos, rot, {"size": size * 0.7}, _vegetation)
		"palm":
			_place(PalmScene, pos, rot, {"size": size * 0.9, "tree_seed": _rng.randi()}, _vegetation)
		"lantern", "crates", "hay":
			_place(DecoScene, pos, rot, {"kind": kind}, _vegetation)
		_:
			_place(TreeScene, pos, rot, {"kind": kind, "size": size, "tree_seed": _rng.randi()}, _vegetation)

func _build_vegetation() -> void:
	# Palms along the beach
	if theme["palms"] and shore_side() != "none":
		var t := -40.0
		while t < 40.0:
			if _rng.randf() < 0.55:
				var p := Vector3.ZERO
				var back := _rng.randf_range(0.8, 2.4)
				match shore_side():
					"left":
						p = Vector3(_shore_left_x(t) - back, 0, t)
					"top":
						p = Vector3(t, 0, _shore_top_z(t) - back)
					"bottom":
						p = Vector3(t, 0, _shore_bottom_z(t) + back)
				if track_distance(p.x, p.z) > 2.0 and not blocked(p.x, p.z, 0.6):
					_place(PalmScene, p, _rng.randf() * TAU, {"size": _rng.randf_range(0.85, 1.2), "tree_seed": _rng.randi()}, _vegetation)
			t += _rng.randf_range(3.0, 5.5)
	var tree_kinds: Array = theme["trees"]
	var inner_kinds: Array = theme["inner"]
	var trees := 0
	var interior := 0
	for i in range(4000):
		if trees >= 85:
			break
		var x := _rng.randf_range(-46, 52)
		var z := _rng.randf_range(-34, 34)
		if not is_land(x, z, 1.5):
			continue
		var w := _zone_weight(x, z)
		if _rng.randf() > w:
			continue
		var inside := w < 0.1
		if inside and interior >= 14:
			continue
		if track_distance(x, z) < (1.2 if inside else 1.6):
			continue
		var size := _rng.randf_range(0.9, 1.4)
		if blocked(x, z, (0.9 if inside else 0.55) * size):
			continue
		if inside:
			interior += 1
			_spawn_tree(inner_kinds[_rng.randi() % inner_kinds.size()], Vector3(x, 0, z), size * 0.8)
		else:
			trees += 1
			_spawn_tree(tree_kinds[_rng.randi() % tree_kinds.size()], Vector3(x, 0, z), size)

# Merge every repeated mesh+material under `root` into one MultiMesh each.
# Collision bodies stay; only the visual MeshInstance3D nodes are replaced.
func _batch_meshes(root: Node) -> void:
	var groups := {}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.material_override == null:
			continue
		var key := "%d_%d" % [mi.mesh.get_instance_id(), mi.material_override.get_instance_id()]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mi)
	var inv := global_transform.affine_inverse()
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var first: MeshInstance3D = list[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.instance_count = list.size()
		mm.mesh = first.mesh
		for i in range(list.size()):
			mm.set_instance_transform(i, inv * (list[i] as MeshInstance3D).global_transform)
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.material_override = first.material_override
		add_child(inst)
		for mi in list:
			(mi as MeshInstance3D).queue_free()

# Drifting petals, autumn leaves, snowflakes or fireflies depending on the theme.
func _build_particles() -> void:
	var cfg: Array = theme["particles"]
	if int(cfg[1]) <= 0:
		return
	var parts := CPUParticles3D.new()
	var quad := QuadMesh.new()
	var is_snow: bool = map.get("theme", "") == "snow"
	var is_fly: bool = map.get("theme", "") == "dusk"
	quad.size = Vector2(0.22, 0.22) if (is_snow or is_fly) else Vector2(0.35, 0.22)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Defs.col(cfg[0])
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = pmat
	parts.mesh = quad
	parts.amount = int(cfg[1])
	parts.lifetime = 14.0
	parts.preprocess = 14.0
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	parts.emission_box_extents = Vector3(48, 1 if not is_fly else 2, 28)
	parts.position = Vector3(-6, 22 if not is_fly else 2.5, 0)
	parts.direction = Vector3(1, -0.4, 0.2) if not is_fly else Vector3(0, 1, 0)
	parts.spread = 25.0 if not is_fly else 180.0
	parts.gravity = Vector3(0, -0.6, 0) if not is_fly else Vector3(0, 0.05, 0)
	parts.initial_velocity_min = 0.8 if not is_fly else 0.2
	parts.initial_velocity_max = 1.8 if not is_fly else 0.7
	add_child(parts)
