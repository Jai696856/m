extends Node3D
## The island: a coastline all the way round, a sandy beach that slopes into the
## sea, rolling hills and a mountain on the north-east peninsula, the flat ground
## the city and swamp sit on, and the winding coastal highway with its side roads.
##
## Everything is computed on an 8 m grid: which points are on land, the distance to
## the coast and to the highway (with a quick distance transform), then a height for
## each point. The same grid gives the terrain mesh, the water mesh and the
## collision heightmap.

const Util := preload("res://scripts/util.gd")

const CELL := 8.0
const HALF_EXT := 900.0
const SEA := -0.4                # water level
const HWY_WIDTH := 15.0

## Coastline control points (clockwise from the north-west), smoothed into a curve.
const COAST := [Vector2(-462, -360), Vector2(-440, -470), Vector2(-350, -560), Vector2(-170, -610), Vector2(20, -640),
	Vector2(200, -690), Vector2(380, -760), Vector2(560, -830), Vector2(720, -760), Vector2(780, -600), Vector2(730, -470),
	Vector2(745, -300), Vector2(790, -110), Vector2(760, 90), Vector2(780, 280), Vector2(720, 470), Vector2(590, 560),
	Vector2(430, 600), Vector2(270, 570), Vector2(110, 640), Vector2(-70, 615), Vector2(-240, 575), Vector2(-370, 510),
	Vector2(-440, 420), Vector2(-468, 260), Vector2(-450, 120), Vector2(-472, -20), Vector2(-450, -160), Vector2(-476, -270)]
## The coastal highway: leaves the beach road at the north-west corner of the city,
## loops round the north, crosses the swamp on a causeway and comes back along the south.
const HWY := [Vector2(-320, -329), Vector2(-320, -372), Vector2(-296, -424), Vector2(-220, -462), Vector2(-100, -470),
	Vector2(30, -458), Vector2(160, -478), Vector2(300, -468), Vector2(400, -430), Vector2(452, -350), Vector2(448, -230),
	Vector2(432, -110), Vector2(446, 10), Vector2(436, 130), Vector2(450, 250), Vector2(430, 360), Vector2(380, 438),
	Vector2(270, 474), Vector2(130, 462), Vector2(0, 482), Vector2(-130, 470), Vector2(-240, 452), Vector2(-300, 410),
	Vector2(-320, 372), Vector2(-320, 329)]

var city
var n := 0                       # grid points per side
var heights := PackedFloat32Array()
var coast_d := PackedFloat32Array()
var hwy_d := PackedFloat32Array()
var coast := PackedVector2Array()        # smoothed coastline
var hwy := PackedVector3Array()          # smoothed highway centreline (y = 0)
var hwy_len := PackedFloat32Array()      # cumulative length along hwy
var connectors: Array = []               # PackedVector3Array side roads into the city
var water_mat: ShaderMaterial


static func catmull(pts: Array, closed: bool, per := 8) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cnt := pts.size()
	var last := cnt if closed else cnt - 1
	for i in last:
		var p0: Vector2 = pts[(i - 1 + cnt) % cnt] if (closed or i > 0) else pts[0]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[(i + 1) % cnt]
		var p3: Vector2 = pts[(i + 2) % cnt] if (closed or i + 2 < cnt) else pts[cnt - 1]
		for k in per:
			var t := float(k) / per
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	if not closed:
		out.append(pts[cnt - 1])
	return out


func build(c) -> void:
	city = c
	name = "Terrain"
	coast = catmull(COAST, true)
	var hw := catmull(HWY, false)
	var total := 0.0
	for i in hw.size():
		if i > 0:
			total += hw[i].distance_to(hw[i - 1])
		hwy.append(Vector3(hw[i].x, 0, hw[i].y))
		hwy_len.append(total)
	# side roads from the city's edge roads out to the highway
	for pair in [[Vector2(0, -328), Vector2(0, 1)], [Vector2(0, 328), Vector2(0, -1)], [Vector2(328, -160), Vector2(-1, 0)]]:
		var a: Vector2 = pair[0]
		var dir: Vector2 = -(pair[1] as Vector2)
		var end := _nearest_on_hwy(a + dir * 140.0)
		connectors.append(PackedVector3Array([Vector3(a.x, 0, a.y), Vector3(end.x, 0, end.z)]))
	_compute_grid()
	_build_meshes()
	_build_collision()
	_build_water()
	_build_highway()
	_build_walls()


func _nearest_on_hwy(p: Vector2) -> Vector3:
	var best := Vector3.ZERO
	var bd := INF
	for q in hwy:
		var d := Vector2(q.x, q.z).distance_to(p)
		if d < bd:
			bd = d
			best = q
	return best


# --- grid -------------------------------------------------------------------------

func _idx(i: int, j: int) -> int:
	return j * n + i


func gx(i: int) -> float:
	return -HALF_EXT + i * CELL


func _compute_grid() -> void:
	n = int(HALF_EXT * 2.0 / CELL) + 1
	var cnt := n * n
	var inside := PackedByteArray()
	inside.resize(cnt)
	# scanline fill of the coastline polygon
	for j in n:
		var z := gx(j)
		var xs: Array[float] = []
		for k in coast.size():
			var a := coast[k]
			var b := coast[(k + 1) % coast.size()]
			if (a.y > z) != (b.y > z):
				xs.append(a.x + (z - a.y) * (b.x - a.x) / (b.y - a.y))
		xs.sort()
		var k := 0
		while k + 1 < xs.size():
			var i0 := maxi(0, ceili((xs[k] + HALF_EXT) / CELL))
			var i1 := mini(n - 1, floori((xs[k + 1] + HALF_EXT) / CELL))
			for i in range(i0, i1 + 1):
				inside[_idx(i, j)] = 1
			k += 2
	# distance to the other side of the coastline, both ways -> signed distance
	var to_sea := _dt(inside, 0)
	var to_land := _dt(inside, 1)
	coast_d.resize(cnt)
	for k in cnt:
		coast_d[k] = to_sea[k] if inside[k] == 1 else -to_land[k]
	# distance to the highway and its side roads
	var road := PackedByteArray()
	road.resize(cnt)
	var lines: Array = [hwy]
	lines.append_array(connectors)
	for pl in lines:
		for k in range(1, pl.size()):
			var a: Vector3 = pl[k - 1]
			var b: Vector3 = pl[k]
			var steps := maxi(1, int(a.distance_to(b) / (CELL * 0.5)))
			for s in steps + 1:
				var p := a.lerp(b, float(s) / steps)
				var i := roundi((p.x + HALF_EXT) / CELL)
				var j := roundi((p.z + HALF_EXT) / CELL)
				if i >= 0 and j >= 0 and i < n and j < n:
					road[_idx(i, j)] = 1
	hwy_d = _dt(road, 1)
	heights.resize(cnt)
	for j in n:
		for i in n:
			var k := _idx(i, j)
			heights[k] = _height(gx(i), gx(j), coast_d[k], hwy_d[k])


## Chamfer distance transform: distance (m) from each point to the nearest point whose
## value equals `target`.
func _dt(mask: PackedByteArray, target: int) -> PackedFloat32Array:
	var big := 1e9
	var d := PackedFloat32Array()
	d.resize(n * n)
	for k in n * n:
		d[k] = 0.0 if mask[k] == target else big
	var s2 := CELL * 1.4142
	for j in n:
		for i in n:
			var k := _idx(i, j)
			var v := d[k]
			if v == 0.0:
				continue
			if i > 0:
				v = minf(v, d[k - 1] + CELL)
			if j > 0:
				v = minf(v, d[k - n] + CELL)
				if i > 0:
					v = minf(v, d[k - n - 1] + s2)
				if i < n - 1:
					v = minf(v, d[k - n + 1] + s2)
			d[k] = v
	for j in range(n - 1, -1, -1):
		for i in range(n - 1, -1, -1):
			var k := _idx(i, j)
			var v := d[k]
			if v == 0.0:
				continue
			if i < n - 1:
				v = minf(v, d[k + 1] + CELL)
			if j < n - 1:
				v = minf(v, d[k + n] + CELL)
				if i < n - 1:
					v = minf(v, d[k + n + 1] + s2)
				if i > 0:
					v = minf(v, d[k + n - 1] + s2)
			d[k] = v
	return d


func _rect_dist(x: float, z: float, x0: float, x1: float, z0: float, z1: float) -> float:
	var dx := maxf(maxf(x0 - x, 0.0), x - x1)
	var dz := maxf(maxf(z0 - z, 0.0), z - z1)
	return sqrt(dx * dx + dz * dz)


## Distance from the flat ground the town is built on: the city, the beach and the swamp.
func flat_dist(x: float, z: float) -> float:
	return minf(_rect_dist(x, z, -345.0, 345.0, -345.0, 345.0),
		minf(_rect_dist(x, z, -560.0, -330.0, -350.0, 350.0), _rect_dist(x, z, 335.0, 700.0, -445.0, 445.0)))


func _hills(x: float, z: float) -> float:
	var v := sin(x * 0.011 + 1.3) * sin(z * 0.013 + 0.7) * 0.5 + sin(x * 0.027 + z * 0.019) * 0.3 \
		+ sin(x * 0.06 - 0.4) * sin(z * 0.05 + 2.0) * 0.2
	var h := pow(maxf(0.0, v * 0.5 + 0.5), 1.5) * 42.0
	# Mount Sol on the north-east peninsula, a ridge in the north and hills to the south
	h += 115.0 * exp(-(pow(x - 590.0, 2.0) + pow(z + 690.0, 2.0)) / (2.0 * 115.0 * 115.0))
	h += 45.0 * exp(-(pow(x + 120.0, 2.0) + pow(z + 575.0, 2.0)) / (2.0 * 90.0 * 90.0))
	h += 35.0 * exp(-(pow(x - 250.0, 2.0) + pow(z - 560.0, 2.0)) / (2.0 * 80.0 * 80.0))
	return h


func _height(x: float, z: float, dc: float, dh: float) -> float:
	var mask := smoothstep(25.0, 140.0, flat_dist(x, z)) * smoothstep(16.0, 70.0, dh) * smoothstep(20.0, 120.0, dc)
	var h := _hills(x, z) * mask
	if dc < 26.0:
		var shore := -1.6 + 1.6 * clampf(dc / 26.0, 0.0, 1.0)
		if dc < 0.0:
			shore = maxf(-6.0, -1.6 + dc * 0.06)
		h = minf(h, shore)
	return h


## Terrain height at a world position (bilinear).
func height_at(x: float, z: float) -> float:
	var fx := clampf((x + HALF_EXT) / CELL, 0.0, n - 1.001)
	var fz := clampf((z + HALF_EXT) / CELL, 0.0, n - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := lerpf(heights[_idx(i, j)], heights[_idx(i + 1, j)], tx)
	var b := lerpf(heights[_idx(i, j + 1)], heights[_idx(i + 1, j + 1)], tx)
	return lerpf(a, b, tz)


func _sample(arr: PackedFloat32Array, x: float, z: float) -> float:
	var i := clampi(roundi((x + HALF_EXT) / CELL), 0, n - 1)
	var j := clampi(roundi((z + HALF_EXT) / CELL), 0, n - 1)
	return arr[_idx(i, j)]


func coast_dist_at(x: float, z: float) -> float:
	return _sample(coast_d, x, z)


func hwy_dist_at(x: float, z: float) -> float:
	return _sample(hwy_d, x, z)


func on_land(x: float, z: float, margin := 0.0) -> bool:
	return coast_dist_at(x, z) > margin


# --- meshes -------------------------------------------------------------------------

func _color(x: float, z: float, h: float, dc: float, slope: float) -> Color:
	var grass := Color(0.34, 0.47, 0.24)
	var v := sin(x * 0.05) * sin(z * 0.043)
	grass = grass.lerp(Color(0.42, 0.52, 0.27), v * 0.5 + 0.5).lerp(Color(0.25, 0.38, 0.2), clampf(h / 30.0, 0.0, 1.0))
	if dc < 30.0 or (x < -334.0 and absf(z) < 352.0):
		var sand := Color(0.93, 0.84, 0.64)
		if h < SEA:
			sand = sand.darkened(clampf(-h * 0.15, 0.0, 0.5))
		return sand
	if x > 335.0 and x < 700.0 and absf(z) < 445.0:
		return Color(0.3, 0.36, 0.2)
	var rock := Color(0.5, 0.47, 0.42)
	var c := grass.lerp(rock, clampf((slope - 0.45) * 2.5, 0.0, 1.0))
	c = c.lerp(rock.lightened(0.15), clampf((h - 75.0) / 30.0, 0.0, 1.0))
	return c


func _build_meshes() -> void:
	var chunks := 6
	var per := int(ceil(float(n - 1) / chunks))
	var m := Util.vc_mat(0.95)
	for cj in chunks:
		for ci in chunks:
			var i0 := ci * per
			var j0 := cj * per
			var i1 := mini(n - 1, i0 + per)
			var j1 := mini(n - 1, j0 + per)
			if i0 >= i1 or j0 >= j1:
				continue
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			var idx := PackedInt32Array()
			var w := i1 - i0 + 1
			var any_land := false
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var x := gx(i)
					var z := gx(j)
					var k := _idx(i, j)
					var h := heights[k]
					var hl := heights[_idx(maxi(i - 1, 0), j)]
					var hr := heights[_idx(mini(i + 1, n - 1), j)]
					var hd := heights[_idx(i, maxi(j - 1, 0))]
					var hu := heights[_idx(i, mini(j + 1, n - 1))]
					var nrm := Vector3(hl - hr, CELL * 2.0, hd - hu).normalized()
					var y := h
					if absf(x) < 330.0 and absf(z) < 330.0:
						y -= 0.06  # tuck under the city's roads and sidewalks
					verts.append(Vector3(x, y, z))
					norms.append(nrm)
					cols.append(_color(x, z, h, coast_d[k], 1.0 - nrm.y))
					if coast_d[k] > -20.0:
						any_land = true
			if not any_land:
				continue
			for j in range(j1 - j0):
				for i in range(i1 - i0):
					var a := j * w + i
					idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = m
			add_child(mi)


func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	var data := PackedFloat32Array()
	data.resize(n * n)
	for k in n * n:
		data[k] = heights[k] / CELL
	hm.map_data = data
	var cs := CollisionShape3D.new()
	cs.shape = hm
	cs.scale = Vector3(CELL, CELL, CELL)
	body.add_child(cs)


func _build_water() -> void:
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var map := {}
	# water over every cell near or past the shoreline
	for j in n - 1:
		for i in n - 1:
			var wet := false
			for dk in [_idx(i, j), _idx(i + 1, j), _idx(i, j + 1), _idx(i + 1, j + 1)]:
				if heights[dk] < SEA + 0.3:
					wet = true
			if not wet:
				continue
			var corners := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1), Vector2i(i + 1, j + 1)]
			var ids := []
			for c in corners:
				if not map.has(c):
					map[c] = verts.size()
					var dc := coast_d[_idx(c.x, c.y)]
					verts.append(Vector3(gx(c.x), SEA, gx(c.y)))
					cols.append(Color(clampf(-dc / 140.0, 0.0, 1.0), clampf(1.0 - absf(dc + 4.0) / 8.0, 0.0, 1.0), 0, 1))
				ids.append(map[c])
			idx.append_array([ids[0], ids[1], ids[2], ids[1], ids[3], ids[2]])
	# open sea beyond the grid
	var e := HALF_EXT
	var far := 5000.0
	for q in [[Vector2(-far, -far), Vector2(far, -e)], [Vector2(-far, e), Vector2(far, far)], [Vector2(-far, -e), Vector2(-e, e)], [Vector2(e, -e), Vector2(far, e)]]:
		var a: Vector2 = q[0]
		var b: Vector2 = q[1]
		var base := verts.size()
		for p in [Vector2(a.x, a.y), Vector2(b.x, a.y), Vector2(a.x, b.y), Vector2(b.x, b.y)]:
			verts.append(Vector3(p.x, SEA, p.y))
			cols.append(Color(1, 0, 0, 1))
		idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	norms.fill(Vector3.UP)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = water_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## A ribbon of road along a polyline, with edge lines and a dashed centre line.
func _ribbon(pl: PackedVector3Array, width: float, y: float, m: Material) -> void:
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for k in pl.size():
		var a: Vector3 = pl[maxi(k - 1, 0)]
		var b: Vector3 = pl[mini(k + 1, pl.size() - 1)]
		var t := (b - a).normalized()
		var r := Vector3(-t.z, 0, t.x)
		verts.append(pl[k] + r * width * 0.5 + Vector3(0, y, 0))
		verts.append(pl[k] - r * width * 0.5 + Vector3(0, y, 0))
		if k > 0:
			var base := (k - 1) * 2
			idx.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	norms.fill(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _offset_line(pl: PackedVector3Array, off: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in pl.size():
		var a: Vector3 = pl[maxi(k - 1, 0)]
		var b: Vector3 = pl[mini(k + 1, pl.size() - 1)]
		var t := (b - a).normalized()
		out.append(pl[k] + Vector3(-t.z, 0, t.x) * off)
	return out


func _build_highway() -> void:
	var asphalt := Util.mat(Color(0.17, 0.17, 0.19), 0.92)
	var white := Util.mat(Color(0.9, 0.9, 0.88), 0.7)
	var yellow := Util.mat(Color(0.95, 0.78, 0.2), 0.7)
	var lines: Array = [hwy]
	lines.append_array(connectors)
	for pl in lines:
		var dense := _densify(pl, 6.0)
		_ribbon(dense, HWY_WIDTH, 0.03, asphalt)
		_ribbon(_offset_line(dense, HWY_WIDTH * 0.5 - 0.5), 0.2, 0.045, white)
		_ribbon(_offset_line(dense, -HWY_WIDTH * 0.5 + 0.5), 0.2, 0.045, white)
		# dashed yellow centre line
		var d := 0.0
		for k in range(1, dense.size()):
			var a: Vector3 = dense[k - 1]
			var b: Vector3 = dense[k]
			d += a.distance_to(b)
			if int(d / 6.0) % 2 == 0:
				_dash(a, b, yellow)
		# street lamps every 70 m
		var acc := 0.0
		var side := 1.0
		for k in range(1, dense.size()):
			acc += dense[k].distance_to(dense[k - 1])
			if acc > 70.0:
				acc = 0.0
				var t: Vector3 = (dense[k] - dense[k - 1]).normalized()
				var r := Vector3(-t.z, 0, t.x) * side
				var p: Vector3 = dense[k] + r * (HWY_WIDTH * 0.5 + 1.2)
				if absf(p.x) > 345.0 or absf(p.z) > 345.0:
					city.lamp_xf.append(Transform3D(Basis(Vector3.UP, Util.yaw_of(-r)), Vector3(p.x, 0.0, p.z)))
				side = -side
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Util.box(0.22, 0.02, 1.0)
	mm.instance_count = _dashes.size()
	for k in _dashes.size():
		mm.set_instance_transform(k, _dashes[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = yellow
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


var _dashes: Array[Transform3D] = []


func _dash(a: Vector3, b: Vector3, _m: Material) -> void:
	var len := a.distance_to(b)
	_dashes.append(Transform3D(Util.look_basis(b - a) * Basis.from_scale(Vector3(1, 1, len)), (a + b) * 0.5 + Vector3(0, 0.045, 0)))


func _densify(pl: PackedVector3Array, step: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in range(1, pl.size()):
		var a: Vector3 = pl[k - 1]
		var b: Vector3 = pl[k]
		var cnt := maxi(1, int(a.distance_to(b) / step))
		for s in cnt:
			out.append(a.lerp(b, float(s) / cnt))
	out.append(pl[pl.size() - 1])
	return out


## Invisible walls a little way out to sea, following the coast.
func _build_walls() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	add_child(body)
	var off := PackedVector2Array()
	var cnt := coast.size()
	for k in cnt:
		var t := (coast[(k + 1) % cnt] - coast[(k - 1 + cnt) % cnt]).normalized()
		off.append(coast[k] + Vector2(-t.y, t.x) * 32.0)
	# make sure the offset went outward (away from the island's middle)
	if off[0].length() < coast[0].length():
		for k in cnt:
			var t := (coast[(k + 1) % cnt] - coast[(k - 1 + cnt) % cnt]).normalized()
			off[k] = coast[k] - Vector2(-t.y, t.x) * 32.0
	for k in cnt:
		var a := off[k]
		var b := off[(k + 1) % cnt]
		var mid := (a + b) * 0.5
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(2.0, 60.0, a.distance_to(b) + 2.0)
		cs.shape = sh
		body.add_child(cs)
		cs.transform = Transform3D(Basis(Vector3.UP, atan2(b.x - a.x, b.y - a.y)), Vector3(mid.x, 20.0, mid.y))


# --- highway path queries (used by traffic) -------------------------------------------

func hwy_length() -> float:
	return hwy_len[hwy_len.size() - 1]


## Position and direction at distance s along the highway centreline.
func hwy_at(s: float) -> Array:
	s = clampf(s, 0.0, hwy_length())
	var lo := 0
	var hi := hwy_len.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if hwy_len[mid] <= s:
			lo = mid
		else:
			hi = mid
	var seg := hwy_len[hi] - hwy_len[lo]
	var t := 0.0 if seg < 0.001 else (s - hwy_len[lo]) / seg
	var p := hwy[lo].lerp(hwy[hi], t)
	var dir := (hwy[hi] - hwy[lo]).normalized()
	return [p, dir]
