extends Node3D
## Builds the city of Sunset Shores: an 8x8 grid of blocks split into districts
## (downtown towers, midtown shops, residential streets, beachfront hotels, parks,
## parking lots), a beach and ocean on the west side, and the street furniture.

const Util := preload("res://scripts/util.gd")

const N := 8                 # blocks per side; road lines are 0..N
const BLOCK := 64.0          # block size including its sidewalk
const ROAD := 16.0           # road width
const P := 80.0              # grid pitch (BLOCK + ROAD)
const HALF := 320.0          # N * P / 2
const CURB := 0.12           # sidewalk height
const SIDEWALK := 4.0
const LANE_OFF := 3.5        # traffic lane offset from the road centre (drive on the right)
const PARK_OFF := 6.5        # curbside parking offset
const SHORE_X := -420.0      # where the ocean begins
const CORNERS := [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)]

const NEON := [Color(1.0, 0.25, 0.6), Color(0.2, 0.9, 1.0), Color(1.0, 0.75, 0.2),
	Color(0.6, 0.35, 1.0), Color(0.3, 1.0, 0.5), Color(1.0, 0.4, 0.25)]
const SHOP_NAMES := ["CAFE MARE", "NEON NOODLE", "LUCKY 8", "PIZZA ORBIT", "TACO LUNA",
	"VIDEO STAR", "JUICE BAR", "PAWN & GOLD", "LAUNDRY 24", "DISCO DELI", "SURF CO.",
	"BAY BANK", "PALM VIEW", "IRON BEACH GYM", "NIGHT OWL", "DONUT DREAM", "RADIO HUT", "KARAOKE"]
const HOTEL_NAMES := ["HOTEL CORAL", "SUNSET MOTEL", "THE FLAMINGO", "SEA BREEZE", "PALM COURT",
	"HOTEL AZUL", "THE LAGOON", "DRIFTWOOD INN"]
const PASTELS := [Color(0.62, 0.9, 0.8), Color(0.98, 0.72, 0.76), Color(0.8, 0.72, 0.96),
	Color(1.0, 0.82, 0.62), Color(0.62, 0.82, 0.97), Color(0.98, 0.93, 0.62), Color(0.95, 0.95, 0.93)]
const WARM := [Color(0.82, 0.55, 0.42), Color(0.92, 0.85, 0.72), Color(0.95, 0.7, 0.6),
	Color(0.85, 0.78, 0.6), Color(0.7, 0.8, 0.85), Color(0.75, 0.62, 0.55), Color(0.9, 0.9, 0.86)]
const TOWERS := [Color(0.5, 0.6, 0.7), Color(0.75, 0.72, 0.66), Color(0.38, 0.46, 0.54),
	Color(0.85, 0.82, 0.76), Color(0.3, 0.36, 0.44), Color(0.55, 0.7, 0.72)]

var game
var rng := RandomNumberGenerator.new()
var footprints: Array[Rect2] = []
var kinds := {}
var parking_spots: Array = []     # [Transform3D, type ("" = random)]
var pickup_spots: Array = []      # [kind, Vector3]
var contact_points: Array = []    # Vector3 for each mission contact
var spawn_point := Vector3.ZERO
var spawn_yaw := 0.0
var hospital_pos := Vector3.ZERO
var station_pos := Vector3.ZERO
var respray_pos := Vector3.ZERO
var lamp_lights: Array[OmniLight3D] = []
var lamp_head_mat: StandardMaterial3D
var neon_mats: Array[StandardMaterial3D] = []
var signs: Array = []             # [Label3D, Color]
var bmat: ShaderMaterial
var unit_box: BoxMesh
var palm_xf: Array[Transform3D] = []
var tree_xf: Array[Transform3D] = []
var lamp_xf: Array[Transform3D] = []
var _lights_on := -1
var world_body: StaticBody3D


# --- grid helpers -----------------------------------------------------------

func line(i: int) -> float:
	return -HALF + i * P


func node_pos(i: int, j: int) -> Vector3:
	return Vector3(line(i), 0.0, line(j))


func nodev(n: Vector2i) -> Vector3:
	return Vector3(line(n.x), 0.0, line(n.y))


func block_center(bx: int, bz: int) -> Vector3:
	return Vector3(line(bx) + P * 0.5, 0.0, line(bz) + P * 0.5)


func in_grid(n: Vector2i) -> bool:
	return n.x >= 0 and n.y >= 0 and n.x <= N and n.y <= N


func neighbors(n: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var m: Vector2i = n + d
		if in_grid(m):
			out.append(m)
	return out


func nearest_node(pos: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi((pos.x + HALF) / P), 0, N), clampi(roundi((pos.z + HALF) / P), 0, N))


func block_of(pos: Vector3) -> Vector2i:
	return Vector2i(clampi(floori((pos.x + HALF) / P), 0, N - 1), clampi(floori((pos.z + HALF) / P), 0, N - 1))


func ground_height(pos: Vector3) -> float:
	if absf(pos.x) < HALF and absf(pos.z) < HALF:
		var lx := fposmod(pos.x + HALF, P)
		var lz := fposmod(pos.z + HALF, P)
		if lx > ROAD * 0.5 and lx < P - ROAD * 0.5 and lz > ROAD * 0.5 and lz < P - ROAD * 0.5:
			return CURB
	if pos.x < -HALF - ROAD * 0.5 and pos.x > -HALF - ROAD * 0.5 - 8.0 and absf(pos.z) < HALF + ROAD * 0.5:
		return CURB
	return 0.0


func ring_corner(b: Vector2i, idx: int) -> Vector3:
	var c := block_center(b.x, b.y)
	var s: Vector2i = CORNERS[idx]
	var r := BLOCK * 0.5 - 2.2
	return Vector3(c.x + s.x * r, CURB, c.z + s.y * r)


func nearest_corner(b: Vector2i, pos: Vector3) -> int:
	var best := 0
	var bd := INF
	for i in 4:
		var d := ring_corner(b, i).distance_squared_to(pos)
		if d < bd:
			bd = d
			best = i
	return best


## A point in a traffic lane between two random intersections.
func random_lane_point(r: RandomNumberGenerator) -> Dictionary:
	var a := Vector2i(r.randi_range(0, N), r.randi_range(0, N))
	var nb := neighbors(a)
	var b: Vector2i = nb[r.randi() % nb.size()]
	var A := nodev(a)
	var B := nodev(b)
	var d := (B - A).normalized()
	var rt := Vector3(-d.z, 0, d.x)
	return {"pos": A.lerp(B, r.randf_range(0.3, 0.7)) + rt * LANE_OFF, "dir": d}


## A curbside parking transform on a random street.
func random_curb_xf(r: RandomNumberGenerator) -> Transform3D:
	var lp := random_lane_point(r)
	var d: Vector3 = lp.dir
	var rt := Vector3(-d.z, 0, d.x)
	var pos: Vector3 = lp.pos + rt * (PARK_OFF - LANE_OFF)
	return Transform3D(Basis(Vector3.UP, Util.yaw_of(d)), pos)


## A sidewalk point on a random block.
func random_sidewalk_point(r: RandomNumberGenerator) -> Vector3:
	var b := Vector2i(r.randi_range(0, N - 1), r.randi_range(0, N - 1))
	var k := r.randi() % 4
	return ring_corner(b, k).lerp(ring_corner(b, (k + 1) % 4), r.randf_range(0.2, 0.8))


# --- build --------------------------------------------------------------------

func build(g) -> void:
	game = g
	rng.seed = 20261119
	unit_box = BoxMesh.new()
	bmat = ShaderMaterial.new()
	bmat.shader = load("res://shaders/building.gdshader")
	lamp_head_mat = Util.glow_mat(Color(1.0, 0.85, 0.6), 0.5)
	world_body = StaticBody3D.new()
	world_body.name = "WorldBody"
	add_child(world_body)
	_build_ground()
	_build_roads()
	for bx in N:
		for bz in N:
			_build_block(bx, bz)
	_build_lamps()
	_build_beach()
	_build_outskirts()
	_finish_props()
	# Start on the beach promenade beside a sports car.
	spawn_point = Vector3(-332.0, CURB + 0.05, 30.0)
	spawn_yaw = -PI * 0.5
	parking_spots.append([Transform3D(Basis(), Vector3(line(0) - PARK_OFF, 0.0, 24.0)), "sport"])
	for i in 12:
		pickup_spots.append(["cash", random_sidewalk_point(rng)])
	pickup_spots.append(["smg", ring_corner(Vector2i(2, 4), 2)])
	pickup_spots.append(["smg", Vector3(-340.0, 0.1, -200.0)])
	pickup_spots.append(["armor", ring_corner(Vector2i(6, 2), 0)])


func _build_ground() -> void:
	var grass := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1530, 2400)
	grass.mesh = pm
	grass.position = Vector3(-330.0 + 765.0, -0.03, 0)
	grass.material_override = Util.mat(Color(0.34, 0.47, 0.24), 0.95)
	add_child(grass)
	_shape(world_body, Vector3(1065, 2, 1240), Vector3((-445.0 + 620.0) * 0.5, -1.0, 0))
	# invisible walls at the edge of the world
	_shape(world_body, Vector3(2, 60, 1240), Vector3(-446, 30, 0))
	_shape(world_body, Vector3(2, 60, 1240), Vector3(621, 30, 0))
	_shape(world_body, Vector3(1070, 60, 2), Vector3(87, 30, -621))
	_shape(world_body, Vector3(1070, 60, 2), Vector3(87, 30, 621))


func _build_roads() -> void:
	var asphalt := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(N * P + ROAD, N * P + ROAD)
	asphalt.mesh = pm
	asphalt.position = Vector3(0, 0.004, 0)
	asphalt.material_override = Util.mat(Color(0.17, 0.17, 0.19), 0.92)
	add_child(asphalt)
	var dashes: Array[Transform3D] = []
	var stripes: Array[Transform3D] = []
	for i in N + 1:
		var z := -HALF
		while z <= HALF:
			var off := fposmod(z + HALF, P)
			if off > ROAD * 0.5 + 1.5 and off < P - ROAD * 0.5 - 1.5:
				dashes.append(Transform3D(Basis(), Vector3(line(i), 0.012, z)))
				dashes.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(z, 0.012, line(i))))
			z += 6.0
	for i in N + 1:
		for j in N + 1:
			var c := node_pos(i, j)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not in_grid(Vector2i(i, j) + d):
					continue
				var along := Vector3(d.x, 0, d.y)
				var across := Vector3(-d.y, 0, d.x)
				var at := c + along * (ROAD * 0.5 + 1.6)
				for k in 6:
					var o := -6.25 + k * 2.5
					var b := Basis(Vector3.UP, Util.yaw_of(along))
					stripes.append(Transform3D(b, at + across * o + Vector3(0, 0.012, 0)))
	_multimesh(Util.box(0.22, 0.02, 3.0), dashes, Util.mat(Color(0.95, 0.78, 0.2), 0.7), false)
	_multimesh(Util.box(1.1, 0.02, 2.8), stripes, Util.mat(Color(0.9, 0.9, 0.88), 0.7), false)


func _kind(bx: int, bz: int) -> String:
	var k := Vector2i(bx, bz)
	if k == Vector2i(1, 1):
		return "hospital"
	if k == Vector2i(5, 6):
		return "police"
	if k == Vector2i(2, 3):
		return "respray"
	if k == Vector2i(4, 1) or k == Vector2i(1, 5):
		return "park"
	if k == Vector2i(5, 2) or k == Vector2i(2, 6):
		return "parking"
	if bx == 0:
		return "beach"
	var d := maxf(absf(bx - 3.5), absf(bz - 3.5))
	if d < 1.0:
		return "downtown"
	if d < 2.0:
		return "midtown"
	return "residential"


func _build_block(bx: int, bz: int) -> void:
	var kind := _kind(bx, bz)
	kinds[Vector2i(bx, bz)] = kind
	var c3 := block_center(bx, bz)
	var c := Vector2(c3.x, c3.z)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var slab := MeshInstance3D.new()
	slab.mesh = Util.box(BLOCK, CURB, BLOCK)
	slab.position = Vector3(c.x, CURB * 0.5, c.y)
	slab.material_override = Util.mat(Color(0.6, 0.59, 0.56), 0.9)
	add_child(slab)
	_shape(body, Vector3(BLOCK, CURB, BLOCK), slab.position)
	_edge_props(c, kind, body)
	match kind:
		"downtown": _downtown(c, body)
		"midtown": _midtown(c, body, false)
		"residential": _residential(c, body)
		"beach": _beachfront(c, body)
		"park": _park(c, body)
		"parking": _parking(c, body)
		"hospital": _hospital(c, body)
		"police": _police(c, body)
		"respray": _respray(c, body)


func _lot(c: Vector2, color: Color, size := BLOCK - SIDEWALK * 2.0) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	mi.position = Vector3(c.x, CURB + 0.006, c.y)
	mi.material_override = Util.mat(color, 0.95)
	add_child(mi)


func _edge_props(c: Vector2, kind: String, body: StaticBody3D) -> void:
	var e := BLOCK * 0.5 - 1.0
	for side in 4:
		var n: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][side]
		var t := Vector2(-n.y, n.x)
		# a lamp in the middle of each side, arm out over the road
		var lp := c + n * e
		var ln := Vector3(n.x, 0, n.y)
		lamp_xf.append(Transform3D(Basis(Vector3.UP, Util.yaw_of(ln)), Vector3(lp.x, CURB, lp.y)))
		_cyl_shape(body, 0.15, 7.0, Vector3(lp.x, CURB + 3.5, lp.y))
		if kind in ["parking", "downtown", "police", "hospital"]:
			continue
		for o in [-22.0, -11.0, 11.0, 22.0]:
			if kind == "midtown" and absf(o) < 15.0:
				continue
			var pp: Vector2 = c + n * (e - 0.2) + t * o
			var p3 := Vector3(pp.x, CURB, pp.y)
			if kind in ["residential", "park"] and rng.randf() < 0.35:
				tree_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.1)), p3))
			else:
				palm_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.15)), p3))
			_cyl_shape(body, 0.25, 5.0, p3 + Vector3(0, 2.5, 0))


func _building(c: Vector2, size: Vector3, color: Color, style: int, body: StaticBody3D, y0 := CURB) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = unit_box
	mi.material_override = bmat
	mi.scale = size
	mi.position = Vector3(c.x, y0 + size.y * 0.5, c.y)
	add_child(mi)
	mi.set_instance_shader_parameter("wall_color", color)
	mi.set_instance_shader_parameter("style", float(style))
	mi.set_instance_shader_parameter("seed", rng.randf())
	_shape(body, size, mi.position)
	if y0 <= CURB + 0.01:
		footprints.append(Rect2(c.x - size.x * 0.5, c.y - size.z * 0.5, size.x, size.z))
	return mi


func _prop(mesh: Mesh, pos: Vector3, m: Material, rot := Vector3.ZERO, vis := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = m
	if vis > 0.0:
		mi.visibility_range_end = vis
	add_child(mi)
	return mi


func _roof_details(c: Vector2, size: Vector3, y0: float) -> void:
	var top := y0 + size.y
	var m := Util.mat(Color(0.45, 0.45, 0.47), 0.8)
	if size.y > 18.0:
		_prop(Util.box(size.x * 0.35, 2.4, size.z * 0.3), Vector3(c.x + size.x * 0.15, top + 1.2, c.y - size.z * 0.1), m, Vector3.ZERO, 400.0)
	for k in rng.randi_range(1, 3):
		var p := Vector3(c.x + rng.randf_range(-0.35, 0.35) * size.x, top + 0.5, c.y + rng.randf_range(-0.35, 0.35) * size.z)
		_prop(Util.box(1.6, 1.0, 1.2), p, m, Vector3.ZERO, 250.0)


func _sign(text: String, pos: Vector3, normal: Vector3, color: Color, px := 0.02) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = px
	l.outline_size = 18
	l.shaded = false
	l.double_sided = false
	l.modulate = color * 1.6
	l.outline_modulate = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 1.0)
	l.position = pos + normal * 0.12
	l.rotation.y = atan2(normal.x, normal.z)
	l.visibility_range_end = 450.0
	add_child(l)
	signs.append([l, color])


func _awning(c: Vector2, size: Vector3, n: Vector2, color: Color) -> void:
	var along := absf(n.x) < 0.5
	var w := (size.x if along else size.z) * 0.8
	var off := (size.z if along else size.x) * 0.5 + 0.8
	var p := Vector3(c.x + n.x * off, CURB + 3.2, c.y + n.y * off)
	var bx := Util.box(w, 0.18, 1.6) if along else Util.box(1.6, 0.18, w)
	_prop(bx, p, Util.mat(color, 0.7), Vector3.ZERO, 200.0)


func _downtown(c: Vector2, body: StaticBody3D) -> void:
	_lot(c, Color(0.56, 0.55, 0.53))
	var r := rng.randi() % 3
	match r:
		0:
			var h := rng.randf_range(95.0, 150.0)
			var col: Color = TOWERS[rng.randi() % TOWERS.size()]
			_building(c, Vector3(46, 14, 46), Color(0.78, 0.75, 0.7), 0, body)
			_building(c, Vector3(34, h, 34), col, 1, body)
			_building(c, Vector3(22, 14, 22), col.darkened(0.15), 1, body, CURB + h)
			_prop(Util.box(0.5, 22, 0.5), Vector3(c.x, CURB + h + 25, c.y), Util.mat(Color(0.3, 0.3, 0.32)), Vector3.ZERO, 900.0)
			var beacon := Util.glow_mat(Color(1, 0.15, 0.1), 4.0, true)
			neon_mats.append(beacon)
			_prop(Util.sphere(0.6, 8), Vector3(c.x, CURB + h + 36.3, c.y), beacon, Vector3.ZERO, 1200.0)
		1:
			for sx in [-1.0, 1.0]:
				var h := rng.randf_range(45.0, 120.0)
				var p := c + Vector2(sx * 13.0, 0)
				var s := Vector3(22, h, 46)
				_building(p, s, TOWERS[rng.randi() % TOWERS.size()], rng.randi() % 2, body)
				_roof_details(p, s, CURB)
		_:
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					var h := rng.randf_range(28.0, 100.0)
					var p := c + Vector2(sx * 13.0, sz * 13.0)
					var s := Vector3(22, h, 22)
					_building(p, s, TOWERS[rng.randi() % TOWERS.size()], rng.randi() % 2, body)
					_roof_details(p, s, CURB)


func _midtown(c: Vector2, body: StaticBody3D, north_only: bool) -> void:
	_lot(c, Color(0.5, 0.49, 0.47))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			if north_only and sz > 0:
				continue
			var p := c + Vector2(sx * 13.0, sz * 13.0)
			if rng.randf() < 0.12 and not north_only:
				tree_xf.append(Transform3D(Basis(), Vector3(p.x, CURB, p.y)))
				continue
			var s := Vector3(rng.randf_range(18.0, 24.0), rng.randf_range(8.0, 30.0), rng.randf_range(18.0, 24.0))
			var col: Color = WARM[rng.randi() % WARM.size()]
			_building(p, s, col, 0, body)
			_roof_details(p, s, CURB)
			var n := Vector2(sx, 0) if rng.randf() < 0.5 else Vector2(0, sz)
			_awning(p, s, n, NEON[rng.randi() % NEON.size()].darkened(0.25))
			if rng.randf() < 0.75:
				var off := (s.x if absf(n.x) > 0.5 else s.z) * 0.5
				var pos := Vector3(p.x + n.x * off, CURB + minf(s.y - 1.5, rng.randf_range(5.5, 8.0)), p.y + n.y * off)
				_sign(SHOP_NAMES[rng.randi() % SHOP_NAMES.size()], pos, Vector3(n.x, 0, n.y), NEON[rng.randi() % NEON.size()])


func _residential(c: Vector2, body: StaticBody3D) -> void:
	_lot(c, Color(0.38, 0.55, 0.27))
	var roof_cols := [Color(0.62, 0.3, 0.22), Color(0.35, 0.35, 0.38), Color(0.7, 0.45, 0.3), Color(0.3, 0.4, 0.5)]
	for ix in [-1, 0, 1]:
		for iz in [-1, 0, 1]:
			var p := c + Vector2(ix * 18.0, iz * 18.0) + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
			if ix == 0 and iz == 0 and rng.randf() < 0.5:
				_prop(Util.box(5, 0.15, 8), Vector3(p.x, CURB + 0.05, p.y), Util.mat(Color(0.2, 0.65, 0.9), 0.1), Vector3.ZERO, 200.0)
				palm_xf.append(Transform3D(Basis(), Vector3(p.x + 4.5, CURB, p.y + 3)))
				continue
			var s := Vector3(rng.randf_range(9.0, 12.0), rng.randf_range(3.6, 6.8), rng.randf_range(9.0, 12.0))
			_building(p, s, PASTELS[rng.randi() % PASTELS.size()], 2, body)
			var roof := PrismMesh.new()
			var rot := 0.0 if rng.randf() < 0.5 else PI * 0.5
			roof.size = Vector3((s.x if rot == 0.0 else s.z) + 0.8, 1.9, (s.z if rot == 0.0 else s.x) + 0.8)
			_prop(roof, Vector3(p.x, CURB + s.y + 0.95, p.y), Util.mat(roof_cols[rng.randi() % roof_cols.size()], 0.8), Vector3(0, rot, 0), 350.0)
			if rng.randf() < 0.5:
				palm_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x + s.x * 0.5 + 1.5, CURB, p.y + s.z * 0.5 + 1.0)))


func _beachfront(c: Vector2, body: StaticBody3D) -> void:
	_lot(c, Color(0.85, 0.8, 0.68))
	for sz in [-1.0, 1.0]:
		var p := c + Vector2(4.0, sz * 13.0)
		var s := Vector3(24, rng.randf_range(14.0, 34.0), 22)
		var col: Color = PASTELS[rng.randi() % PASTELS.size()]
		_building(p, s, col, 0, body)
		_roof_details(p, s, CURB)
		var face := Vector3(p.x - s.x * 0.5, CURB + s.y - 3.0, p.y)
		_sign(HOTEL_NAMES[rng.randi() % HOTEL_NAMES.size()], face, Vector3(-1, 0, 0), NEON[rng.randi() % NEON.size()], 0.03)
		_awning(p, s, Vector2(-1, 0), Color(0.95, 0.4, 0.5))
	for k in 4:
		palm_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(c.x - 24.0, CURB, c.y - 24.0 + k * 16.0)))


func _park(c: Vector2, body: StaticBody3D) -> void:
	_lot(c, Color(0.36, 0.58, 0.28))
	var path := Util.mat(Color(0.78, 0.72, 0.6), 0.95)
	_prop(Util.box(56, 0.02, 4), Vector3(c.x, CURB + 0.02, c.y), path)
	_prop(Util.box(4, 0.02, 56), Vector3(c.x, CURB + 0.02, c.y), path)
	var stone := Util.mat(Color(0.75, 0.74, 0.7), 0.8)
	_prop(Util.cyl(4.2, 4.4, 0.7, 24), Vector3(c.x, CURB + 0.35, c.y), stone)
	_cyl_shape(body, 4.3, 0.7, Vector3(c.x, CURB + 0.35, c.y))
	var water := Util.mat(Color(0.25, 0.6, 0.85), 0.05)
	_prop(Util.cyl(3.9, 3.9, 0.1, 24), Vector3(c.x, CURB + 0.62, c.y), water)
	_prop(Util.cyl(0.35, 0.5, 2.4, 10), Vector3(c.x, CURB + 1.5, c.y), stone)
	_prop(Util.cyl(1.4, 0.4, 0.4, 16), Vector3(c.x, CURB + 2.8, c.y), stone)
	for k in 14:
		var p := c + Vector2(rng.randf_range(-25, 25), rng.randf_range(-25, 25))
		if absf(p.x - c.x) < 4.0 or absf(p.y - c.y) < 4.0 or p.distance_to(c) < 7.0:
			continue
		tree_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.3)), Vector3(p.x, CURB, p.y)))
		_cyl_shape(body, 0.3, 4.0, Vector3(p.x, CURB + 2.0, p.y))
	var wood := Util.mat(Color(0.5, 0.33, 0.2), 0.8)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var bp: Vector2 = c + d * 9.0 + Vector2(d.y, d.x) * 3.0
		_prop(Util.box(2.0 if d.x == 0 else 0.6, 0.5, 0.6 if d.x == 0 else 2.0), Vector3(bp.x, CURB + 0.45, bp.y), wood, Vector3.ZERO, 120.0)
	pickup_spots.append(["health", Vector3(c.x + 6.0, CURB, c.y + 6.0)])


func _parking(c: Vector2, body: StaticBody3D) -> void:
	_lot(c, Color(0.22, 0.22, 0.24))
	var white := Util.mat(Color(0.9, 0.9, 0.88), 0.8)
	for row in [-1.0, 1.0]:
		var z: float = c.y + row * 9.0
		for k in 16:
			var x := c.x - 22.5 + k * 3.0
			if k < 15:
				_prop(Util.box(0.12, 0.02, 5.2), Vector3(x + 1.5, CURB + 0.012, z), white, Vector3.ZERO, 150.0)
			var yaw := 0.0 if row < 0 else PI
			if rng.randf() < 0.45:
				parking_spots.append([Transform3D(Basis(Vector3.UP, yaw), Vector3(x, CURB, z)), ""])
	_building(c + Vector2(24.0, 0), Vector3(3, 3, 4), Color(0.9, 0.85, 0.3), 2, body)


func _hospital(c: Vector2, body: StaticBody3D) -> void:
	_lot(c, Color(0.6, 0.6, 0.58))
	var s := Vector3(40, 16, 28)
	var p := c + Vector2(0, -4)
	_building(p, s, Color(0.94, 0.95, 0.96), 0, body)
	_roof_details(p, s, CURB)
	var red := Util.glow_mat(Color(1.0, 0.1, 0.12), 1.5)
	neon_mats.append(red)
	var face := Vector3(p.x, CURB + 12.0, p.y + s.z * 0.5 + 0.1)
	_prop(Util.box(4.0, 1.2, 0.2), face, red)
	_prop(Util.box(1.2, 4.0, 0.2), face, red)
	_sign("HOSPITAL", Vector3(p.x, CURB + 7.0, p.y + s.z * 0.5), Vector3(0, 0, 1), Color(1, 1, 1), 0.025)
	hospital_pos = Vector3(c.x, CURB + 0.05, c.y + 24.0)
	pickup_spots.append(["health", Vector3(c.x + 8.0, CURB, c.y + 20.0)])


func _police(c: Vector2, body: StaticBody3D) -> void:
	_lot(c, Color(0.5, 0.5, 0.52))
	var s := Vector3(40, 13, 24)
	var p := c + Vector2(0, -8)
	_building(p, s, Color(0.42, 0.48, 0.6), 0, body)
	_roof_details(p, s, CURB)
	_sign("POLICE", Vector3(p.x, CURB + 9.0, p.y + s.z * 0.5), Vector3(0, 0, 1), Color(0.35, 0.6, 1.0), 0.028)
	station_pos = Vector3(c.x, CURB + 0.05, c.y + 26.0)
	for k in 3:
		parking_spots.append([Transform3D(Basis(Vector3.UP, PI), Vector3(c.x - 10.0 + k * 10.0, CURB, c.y + 16.0)), "police"])


func _respray(c: Vector2, body: StaticBody3D) -> void:
	_midtown(c, body, true)
	var s := Vector3(18, 7, 14)
	var p := c + Vector2(0, 16)
	_building(p, s, Color(0.55, 0.55, 0.58), 0, body)
	_prop(Util.box(9, 5, 0.1), Vector3(p.x, CURB + 2.5, p.y + s.z * 0.5 + 0.06), Util.mat(Color(0.05, 0.05, 0.06)))
	var stripe := Util.glow_mat(Color(1.0, 0.3, 0.85), 2.0)
	neon_mats.append(stripe)
	_prop(Util.box(10, 0.25, 0.15), Vector3(p.x, CURB + 5.3, p.y + s.z * 0.5 + 0.1), stripe)
	_sign("RESPRAY", Vector3(p.x, CURB + 6.2, p.y + s.z * 0.5), Vector3(0, 0, 1), Color(1.0, 0.3, 0.85), 0.022)
	respray_pos = Vector3(p.x, CURB, c.y + 28.0)


func _build_lamps() -> void:
	for i in N + 1:
		for j in N + 1:
			var sx := 1.0 if i < N else -1.0
			var sz := 1.0 if j < N else -1.0
			var p := node_pos(i, j) + Vector3(sx * (ROAD * 0.5 + 1.0), CURB, sz * (ROAD * 0.5 + 1.0))
			var dir := Vector3(-sx, 0, -sz).normalized()
			lamp_xf.append(Transform3D(Basis(Vector3.UP, Util.yaw_of(dir)), p))
			_cyl_shape(world_body, 0.15, 7.0, p + Vector3(0, 3.5, 0))
			var l := OmniLight3D.new()
			l.position = p + dir * 2.6 + Vector3(0, 6.5, 0)
			l.omni_range = 26.0
			l.light_energy = 2.4
			l.light_color = Color(1.0, 0.8, 0.55)
			l.shadow_enabled = false
			l.visible = false
			add_child(l)
			lamp_lights.append(l)


func _build_beach() -> void:
	var sand := MeshInstance3D.new()
	sand.mesh = Util.box(134, 0.04, 1400)
	sand.position = Vector3(-403, 0.0, 0)
	sand.material_override = Util.mat(Color(0.93, 0.84, 0.64), 1.0)
	add_child(sand)
	var prom := MeshInstance3D.new()
	prom.mesh = Util.box(8, CURB, N * P + ROAD)
	prom.position = Vector3(-332, CURB * 0.5, 0)
	prom.material_override = Util.mat(Color(0.78, 0.72, 0.66), 0.9)
	add_child(prom)
	_shape(world_body, Vector3(8, CURB, N * P + ROAD), prom.position)
	var ocean := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2600, 2600)
	pm.subdivide_width = 160
	pm.subdivide_depth = 160
	ocean.mesh = pm
	ocean.position = Vector3(SHORE_X - 1300.0, 0.22, 0)
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	wm.set_shader_parameter("shore_x", SHORE_X)
	ocean.material_override = wm
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean)
	var z := -HALF
	while z <= HALF:
		palm_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.25)), Vector3(-348.0 + rng.randf_range(-3, 3), 0.02, z)))
		_cyl_shape(world_body, 0.25, 5.0, Vector3(-348.0, 2.5, z))
		z += 22.0
	var umb := [Color(1, 0.3, 0.35), Color(0.2, 0.6, 1.0), Color(1.0, 0.85, 0.2), Color(0.3, 0.85, 0.5), Color(1, 0.55, 0.2)]
	for k in 34:
		var p := Vector3(rng.randf_range(-405, -362), 0.02, rng.randf_range(-HALF, HALF))
		_prop(Util.cyl(0.04, 0.04, 2.4, 6), p + Vector3(0, 1.2, 0), Util.mat(Color(0.9, 0.9, 0.9)), Vector3.ZERO, 200.0)
		_prop(Util.cyl(0.05, 1.5, 0.6, 12), p + Vector3(0, 2.45, 0), Util.mat(umb[k % umb.size()], 0.8), Vector3.ZERO, 250.0)
		_prop(Util.box(0.9, 0.03, 1.9), p + Vector3(1.2, 0.02, 0.4), Util.mat(umb[(k + 2) % umb.size()], 0.9), Vector3(0, rng.randf(), 0), 150.0)
	for k in 5:
		var p := Vector3(-388, 0.0, -260 + k * 130)
		var col: Color = [Color(1, 0.45, 0.4), Color(0.4, 0.7, 1.0), Color(1, 0.8, 0.3)][k % 3]
		for lx in [-1.0, 1.0]:
			for lz in [-1.0, 1.0]:
				_prop(Util.box(0.15, 2.6, 0.15), p + Vector3(lx, 1.3, lz), Util.mat(Color(0.95, 0.95, 0.95)), Vector3.ZERO, 300.0)
		_prop(Util.box(2.8, 2.0, 2.8), p + Vector3(0, 3.6, 0), Util.mat(col, 0.7), Vector3.ZERO, 400.0)
		_prop(Util.box(3.4, 0.2, 3.4), p + Vector3(0, 4.7, 0), Util.mat(Color(0.95, 0.95, 0.95)), Vector3.ZERO, 400.0)
		_shape(world_body, Vector3(2.8, 4.7, 2.8), p + Vector3(0, 2.35, 0))
	# stunt ramps on the sand
	for rz in [-110.0, 150.0]:
		_ramp(Vector3(-392, 0, rz), PI)
	_ramp(Vector3(-375, 0, -300), 0.0)
	contact_points.append(Vector3(-332.0, CURB, 64.0))


func _ramp(pos: Vector3, yaw: float) -> void:
	var angle := deg_to_rad(16.0)
	var length := 14.0
	var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, angle)
	var center := pos + Basis(Vector3.UP, yaw) * Vector3(0, length * 0.5 * sin(angle) - 0.25, -length * 0.5 * cos(angle))
	var mi := _prop(Util.box(7, 0.5, length), Vector3.ZERO, Util.mat(Color(0.85, 0.55, 0.2), 0.7))
	mi.global_transform = Transform3D(b, center)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(7, 0.5, length)
	cs.shape = sh
	world_body.add_child(cs)
	cs.global_transform = Transform3D(b, center)
	var stripe := _prop(Util.box(7.05, 0.52, 0.6), Vector3.ZERO, Util.mat(Color(0.95, 0.95, 0.95)))
	stripe.global_transform = Transform3D(b, center + b * Vector3(0, 0.01, -length * 0.5 + 0.4))


func _build_outskirts() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	for k in 260:
		var p := Vector3(rng.randf_range(-330, 600), 0.0, rng.randf_range(-600, 600))
		if absf(p.x) < HALF + 14.0 and absf(p.z) < HALF + 14.0:
			continue
		tree_xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.6)), p))
		_cyl_shape(body, 0.35, 4.0, p + Vector3(0, 2.0, 0))
	# a few low hills of rock
	for k in 10:
		var p := Vector3(rng.randf_range(380, 580), 0.0, rng.randf_range(-560, 560))
		var r := rng.randf_range(8, 18)
		_prop(Util.sphere(r, 12), p + Vector3(0, -r * 0.55, 0), Util.mat(Color(0.48, 0.45, 0.38), 0.95), Vector3.ZERO, 900.0).scale = Vector3(1.3, 1.0, 1.0)
	contact_points.push_front(Vector3(block_center(5, 2).x - 20.0, CURB, block_center(5, 2).z + 30.0))
	contact_points.append(Vector3(block_center(4, 1).x, CURB, block_center(4, 1).z + 20.0))


# --- shared prop meshes ---------------------------------------------------------

func _palm_mesh() -> ArrayMesh:
	var parts := []
	var trunk := Color(0.5, 0.38, 0.25)
	var x := 0.0
	for i in 7:
		var r := 0.24 - i * 0.012
		x = 0.03 * pow(i, 1.6)
		parts.append([Util.cyl(r - 0.012, r, 1.25, 7), Util.xf(Vector3(x, 0.62 + i * 1.18, 0), Vector3(0, 0, -0.04 * i)), trunk.darkened(0.08 * (i % 2))])
	var top := Vector3(x + 0.12, 8.6, 0)
	for k in 9:
		var yaw := k * TAU / 9.0 + 0.2
		var droop := -0.35 - 0.2 * float(k % 2)
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, droop)
		parts.append([Util.box(0.7, 0.05, 3.4), Transform3D(b, top + b * Vector3(0, 0, -1.6)), Color(0.22, 0.55, 0.18).lerp(Color(0.35, 0.6, 0.2), float(k % 3) / 3.0)])
	for k in 3:
		parts.append([Util.sphere(0.16, 6), Util.xf(top + Vector3(cos(k * 2.1) * 0.25, -0.3, sin(k * 2.1) * 0.25)), Color(0.4, 0.3, 0.12)])
	return Util.merge(parts)


func _tree_mesh() -> ArrayMesh:
	var green := Color(0.25, 0.5, 0.2)
	return Util.merge([
		[Util.cyl(0.2, 0.3, 3.0, 7), Util.xf(Vector3(0, 1.5, 0)), Color(0.42, 0.3, 0.2)],
		[Util.sphere(2.0, 10), Util.xf(Vector3(0, 4.0, 0)), green],
		[Util.sphere(1.5, 8), Util.xf(Vector3(1.0, 3.6, 0.6)), green.lightened(0.08)],
		[Util.sphere(1.4, 8), Util.xf(Vector3(-0.9, 3.8, -0.5)), green.darkened(0.08)],
	])


func _lamp_mesh() -> ArrayMesh:
	var grey := Color(0.28, 0.3, 0.32)
	return Util.merge([
		[Util.cyl(0.08, 0.12, 7.0, 8), Util.xf(Vector3(0, 3.5, 0)), grey],
		[Util.box(0.1, 0.1, 2.8), Util.xf(Vector3(0, 6.95, -1.35)), grey],
		[Util.box(0.55, 0.12, 0.85), Util.xf(Vector3(0, 6.95, -2.6)), grey],
	])


func _finish_props() -> void:
	_multimesh(_palm_mesh(), palm_xf, Util.vc_mat(0.9))
	_multimesh(_tree_mesh(), tree_xf, Util.vc_mat(0.9))
	_multimesh(_lamp_mesh(), lamp_xf, Util.vc_mat(0.6, 0.4))
	var heads: Array[Transform3D] = []
	for t in lamp_xf:
		heads.append(t * Transform3D(Basis(), Vector3(0, 6.86, -2.6)))
	_multimesh(Util.box(0.45, 0.06, 0.7), heads, lamp_head_mat, false)


func _multimesh(mesh: Mesh, xforms: Array[Transform3D], m: Material, shadows := true) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _shape(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)


func _cyl_shape(body: StaticBody3D, r: float, h: float, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)


# --- day / night ------------------------------------------------------------------

var _last_night := -1.0


func set_night(n: float) -> void:
	if absf(n - _last_night) < 0.01:
		return
	_last_night = n
	lamp_head_mat.emission_energy_multiplier = lerpf(0.3, 7.0, n)
	for m in neon_mats:
		m.emission_energy_multiplier = lerpf(1.2, 5.0, n)
	for s in signs:
		var l: Label3D = s[0]
		var col: Color = s[1]
		l.modulate = col * lerpf(1.3, 3.2, n)
		l.modulate.a = 1.0
	var on := 1 if n > 0.45 else 0
	if on != _lights_on:
		_lights_on = on
		for l in lamp_lights:
			l.visible = on == 1
