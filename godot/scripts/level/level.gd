# The Level scene: terrain, sea and beach, the stone Track, buildings and
# vegetation. Gameplay code asks it where heroes may be built.
extends Node3D

const Models = preload("res://scripts/models.gd")
const Defs = preload("res://scripts/defs.gd")
const TrackScene = preload("res://scenes/track/track.tscn")
const TrackScript = preload("res://scripts/track/track.gd")
const HouseScene = preload("res://scenes/props/house.tscn")
const WindmillScene = preload("res://scenes/props/windmill.tscn")
const TreeScene = preload("res://scenes/props/tree.tscn")
const PalmScene = preload("res://scenes/props/palm.tscn")
const BushScene = preload("res://scenes/props/bush.tscn")
const RockScene = preload("res://scenes/props/rock.tscn")
const DecoScene = preload("res://scenes/props/decoration.tscn")

## Shoreline: x of the grass edge at a given z. The sea lies to the left (smaller x),
## widening towards the top-left corner.
const SHORE := [
	Vector2(-4, -46), Vector2(-14, -34), Vector2(-22, -26), Vector2(-28, -19), Vector2(-32, -11),
	Vector2(-34.5, -2), Vector2(-36, 8), Vector2(-37, 18), Vector2(-38, 30), Vector2(-39, 46),
]
## Area where heroes may be placed.
const PLAY_MIN := Vector2(-37.0, -21.0)
const PLAY_MAX := Vector2(34.0, 21.0)

var track
var blockers: Array = []   # Vector3(x, z, radius) for every prop
var _vegetation: Node3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 2024
	_build_terrain()
	track = TrackScene.instantiate()
	track.name = "Track"
	add_child(track)
	_build_landmarks()
	_build_ground_details()
	_vegetation = Node3D.new()
	_vegetation.name = "Vegetation"
	add_child(_vegetation)
	_build_vegetation()
	_batch_meshes(_vegetation)
	_build_petals()

# ---------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------
func shore_x(z: float) -> float:
	var x: float = SHORE[0].x
	if z >= SHORE[SHORE.size() - 1].y:
		x = SHORE[SHORE.size() - 1].x
	else:
		for i in range(1, SHORE.size()):
			var a: Vector2 = SHORE[i - 1]
			var b: Vector2 = SHORE[i]
			if z <= b.y:
				x = lerpf(a.x, b.x, clampf((z - a.y) / (b.y - a.y), 0.0, 1.0))
				break
	return x + 0.6 * sin(z * 0.37)

func is_land(x: float, z: float, margin: float = 0.0) -> bool:
	return x > shore_x(z) + margin

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
func _shore_poly(offset: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var z := -90.0
	while z <= 90.0:
		pts.append(Vector2(shore_x(z) + offset, z))
		z += 1.5
	pts.append(Vector2(160.0, 90.0))
	pts.append(Vector2(160.0, -90.0))
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
	var mat := Models.make_toon(Defs.col(hex), false)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m

func _build_terrain() -> void:
	var sea := PlaneMesh.new()
	sea.size = Vector2(900, 900)
	var sea_mat := Models.make_toon(Defs.col(0x1f9ad6), false)
	add_child(Models.mi(sea, sea_mat, Vector3(0, -0.45, 0)))
	add_child(_poly_mesh(_shore_poly(-9.0), -0.38, 0x5fd0ef))   # shallows
	var foam := _poly_mesh(_shore_poly(-5.0), -0.33, 0xeafcff)
	add_child(foam)
	add_child(_poly_mesh(_shore_poly(-4.0), -0.22, 0xf5df9e))   # sand beach
	add_child(_poly_mesh(_shore_poly(-0.6), -0.1, 0x9ccf55))    # grass lip
	add_child(_poly_mesh(_shore_poly(0.0), 0.0, 0x86d040))      # grass

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
	var entry_tile: Vector3 = TrackScript.cell_to_world(cells[1])

	var shrine := Models.shrine()
	shrine.position = exit_p + Vector3(0, 0, 2.6)
	shrine.rotation.y = PI
	add_child(shrine)
	Models.collide_box(shrine, Vector3(5, 5, 4.2), Vector3(0, 2.5, 0))
	blockers.append(Vector3(shrine.position.x, shrine.position.z, 3.6))

	# Torii gate straddles the track where it leaves the last tile.
	var gate := (last_tile + exit_p) / 2.0
	var torii := Models.torii()
	torii.position = gate
	torii.rotation.y = atan2(exit_p.x - last_tile.x, exit_p.z - last_tile.z)
	add_child(torii)
	blockers.append(Vector3(gate.x - 2.5, gate.z, 0.8))
	blockers.append(Vector3(gate.x + 2.5, gate.z, 0.8))

	var portal := Node3D.new()
	portal.name = "SpiritPortal"
	Models.add(portal, Models.torus(2.5, 0.35), Models.toon(0x5a2d82), Vector3(0, 2.5, 0), Vector3(PI / 2, 0, 0))
	var swirl := Models.fx_mat(Defs.col(0x9d5cff, 0.55))
	Models.add(portal, Models.cyl(2.4, 2.4, 0.05, 36), swirl, Vector3(0, 2.5, 0), Vector3(PI / 2, 0, 0))
	portal.position = entry_tile + Vector3(0, 0, -1.6)
	add_child(portal)
	var tw := create_tween().set_loops()
	tw.tween_property(swirl, "albedo_color:a", 0.25, 1.2)
	tw.tween_property(swirl, "albedo_color:a", 0.6, 1.2)

	_place(WindmillScene, Vector3(-29.5, 0, -2.0), 0.15)
	_place(HouseScene, Vector3(-14.5, 0, -4.5), 0.1, {"variant": 0})
	_place(HouseScene, Vector3(22.0, 0, -12.0), -0.2, {"variant": 1})
	_place(HouseScene, Vector3(8.0, 0, 13.2), 0.05, {"variant": 2})
	_place(HouseScene, Vector3(-28.8, 0, 13.6), 0.25, {"variant": 3})
	_place(DecoScene, Vector3(-25.5, 0, -0.5), 0.3, {"kind": "hay"})
	_place(DecoScene, Vector3(-11.0, 0, -2.0), 0.0, {"kind": "crates"})
	_place(DecoScene, Vector3(25.5, 0, -9.5), 0.6, {"kind": "crates"})
	_place(DecoScene, Vector3(11.0, 0, 12.0), 1.57, {"kind": "fence"})

# ---------------------------------------------------------------------
# Grass patches, flowers and tufts (instanced)
# ---------------------------------------------------------------------
func _build_ground_details() -> void:
	var patch_items: Array = []
	var fl: Array = []
	var tf: Array = []
	var greens := [Defs.col(0x74c234), Defs.col(0x97da4f), Defs.col(0x7cc83a), Defs.col(0xa3e05a)]
	var flower_cols := [Defs.col(0xffffff), Defs.col(0xfff3a0), Defs.col(0xffb3d1), Defs.col(0xffffff), Defs.col(0xc9a6ff)]
	var tuft_cols := [Defs.col(0x4fa82a), Defs.col(0x5fbb33), Defs.col(0x3f9a24)]
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
# only a few bushes and rocks inside so heroes have room.
# ---------------------------------------------------------------------
func _zone_weight(x: float, z: float) -> float:
	if x > 18.0 and z < -14.0:
		return 1.0     # top-right corner
	if x > 18.0 and z > 15.0:
		return 1.0     # bottom-right corner
	if x < -22.0 and z > 17.0:
		return 1.0     # bottom-left corner
	if x < -8.0 and z < -18.0:
		return 0.9     # top-left, by the beach
	if absf(z) > 21.0 or x > 33.0:
		return 0.7     # around the edges, framing the map
	return 0.04        # interior

func _build_vegetation() -> void:
	# Palms along the curved beach
	var z := -34.0
	while z < 34.0:
		if _rng.randf() < 0.55:
			var x := shore_x(z) - _rng.randf_range(0.8, 2.4)
			if track_distance(x, z) > 2.0 and not blocked(x, z, 0.6):
				_place(PalmScene, Vector3(x, 0, z), _rng.randf() * TAU, {"size": _rng.randf_range(0.85, 1.2), "tree_seed": _rng.randi()}, _vegetation)
		z += _rng.randf_range(3.0, 5.5)
	# Trees and bushes
	var trees := 0
	var interior := 0
	for i in range(4000):
		if trees >= 85:
			break
		var x := _rng.randf_range(-44, 52)
		var zz := _rng.randf_range(-34, 34)
		if not is_land(x, zz, 1.5):
			continue
		var w := _zone_weight(x, zz)
		if _rng.randf() > w:
			continue
		var inside := w < 0.1
		if inside and interior >= 14:
			continue
		if track_distance(x, zz) < (1.2 if inside else 1.6):
			continue
		var size := _rng.randf_range(0.9, 1.4)
		if blocked(x, zz, (0.9 if inside else 0.55) * size):
			continue
		var pick := _rng.randf()
		var pos := Vector3(x, 0, zz)
		var rot := _rng.randf() * TAU
		if inside:
			interior += 1
			if pick < 0.45:
				_place(BushScene, pos, rot, {"size": size * 0.8, "bush_seed": _rng.randi()}, _vegetation)
			elif pick < 0.7:
				_place(RockScene, pos, rot, {"size": size * 0.6}, _vegetation)
			elif pick < 0.85:
				_place(DecoScene, pos, rot, {"kind": "lantern"}, _vegetation)
			else:
				_place(TreeScene, pos, rot, {"kind": "sakura", "size": 0.9, "tree_seed": _rng.randi()}, _vegetation)
		else:
			trees += 1
			if pick < 0.62:
				_place(TreeScene, pos, rot, {"kind": "round", "size": size, "tree_seed": _rng.randi()}, _vegetation)
			elif pick < 0.72:
				_place(TreeScene, pos, rot, {"kind": "sakura", "size": size, "tree_seed": _rng.randi()}, _vegetation)
			elif pick < 0.92:
				_place(BushScene, pos, rot, {"size": size * 1.2, "bush_seed": _rng.randi()}, _vegetation)
			else:
				_place(RockScene, pos, rot, {"size": size * 0.8}, _vegetation)

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

func _build_petals() -> void:
	var petals := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.22)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Defs.col(0xffc1dc)
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = pmat
	petals.mesh = quad
	petals.amount = 60
	petals.lifetime = 14.0
	petals.preprocess = 14.0
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	petals.emission_box_extents = Vector3(48, 1, 28)
	petals.position = Vector3(-6, 22, 0)
	petals.direction = Vector3(1, -0.4, 0.2)
	petals.spread = 25.0
	petals.gravity = Vector3(0, -0.6, 0)
	petals.initial_velocity_min = 0.8
	petals.initial_velocity_max = 1.8
	add_child(petals)
