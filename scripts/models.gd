# Builds every 3D model in the game out of primitive meshes.
# Toon shading comes from StandardMaterial3D's toon diffuse mode, and the
# anime ink outline is an inverted-hull "grow" pass chained via next_pass.
extends RefCounted

const Defs = preload("res://scripts/defs.gd")

const INK := Color(0.165, 0.094, 0.22)
const SKIN := 0xffe4d2
## How far the hero rig is sunk so its token base is slim (see make_chibi).
const BASE_DROP := 0.24

static var _mats := {}
static var _meshes := {}

# ---------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------
static func outline_mat(alpha: float = 1.0, grow: float = 0.022) -> StandardMaterial3D:
	var key := "outline_%s_%s" % [alpha, grow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.albedo_color = Color(INK, alpha)
	m.grow = true
	m.grow_amount = grow
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

static func toon(hex: int, alpha: float = 1.0, outline: bool = true) -> StandardMaterial3D:
	var key := "toon_%x_%s_%s" % [hex, alpha, outline]
	if _mats.has(key):
		return _mats[key]
	var m := make_toon(Defs.col(hex, alpha), outline)
	_mats[key] = m
	return m

static func make_toon(c: Color, outline: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if outline:
		m.next_pass = outline_mat(c.a)
	return m

static func flat(hex: int, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "flat_%x_%s" % [hex, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Defs.col(hex, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

# A fresh (uncached) unshaded transparent material, for effects that fade out.
static func fx_mat(c: Color, additive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	m.no_depth_test = false
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

# ---------------------------------------------------------------------
# Meshes (cached so instances share GPU resources)
# ---------------------------------------------------------------------
static func sphere(r: float, seg: int = 20, hemi: bool = false) -> SphereMesh:
	var key := "s_%s_%s_%s" % [r, seg, hemi]
	if _meshes.has(key):
		return _meshes[key]
	var s := SphereMesh.new()
	s.radius = r
	s.height = r if hemi else r * 2.0
	s.radial_segments = seg
	s.rings = maxi(4, seg / 2)
	s.is_hemisphere = hemi
	_meshes[key] = s
	return s

static func cyl(rt: float, rb: float, h: float, seg: int = 16) -> CylinderMesh:
	var key := "c_%s_%s_%s_%s" % [rt, rb, h, seg]
	if _meshes.has(key):
		return _meshes[key]
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	_meshes[key] = c
	return c

static func cone(r: float, h: float, seg: int = 12) -> CylinderMesh:
	return cyl(0.0, r, h, seg)

static func box(x: float, y: float, z: float) -> BoxMesh:
	var key := "b_%s_%s_%s" % [x, y, z]
	if _meshes.has(key):
		return _meshes[key]
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	_meshes[key] = b
	return b

static func capsule(r: float, mid: float) -> CapsuleMesh:
	var key := "cap_%s_%s" % [r, mid]
	if _meshes.has(key):
		return _meshes[key]
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = mid + r * 2.0
	c.radial_segments = 12
	c.rings = 4
	_meshes[key] = c
	return c

# Torus lying in the XZ plane (around the Y axis).
static func torus(r: float, tube: float) -> TorusMesh:
	var key := "t_%s_%s" % [r, tube]
	if _meshes.has(key):
		return _meshes[key]
	var t := TorusMesh.new()
	t.inner_radius = r - tube
	t.outer_radius = r + tube
	t.rings = 32
	t.ring_segments = 8
	_meshes[key] = t
	return t

# Chunky stone block: a unit cube with bevelled edges and flat facets.
# Scale it per instance to get bricks, slabs and barrier stones.
static func chamfer_box(c: float = 0.14) -> ArrayMesh:
	var key := "chamfer_%s" % c
	if _meshes.has(key):
		return _meshes[key]
	var h := 0.5
	var signs := [-1.0, 1.0]
	var polys: Array = []
	# Main faces
	for ax in range(3):
		var a1 := (ax + 1) % 3
		var a2 := (ax + 2) % 3
		for sa in signs:
			var face: Array = []
			for k in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				var sv := Vector3.ZERO
				sv[ax] = sa
				sv[a1] = k[0]
				sv[a2] = k[1]
				face.append(_cv(sv, ax, h, c))
			polys.append(face)
	# Bevelled edges
	for ax in range(3):
		var bx := (ax + 1) % 3
		var cx := (ax + 2) % 3
		for sa in signs:
			for sb in signs:
				var s1 := Vector3.ZERO
				s1[ax] = sa
				s1[bx] = sb
				s1[cx] = -1.0
				var s2 := s1
				s2[cx] = 1.0
				polys.append([_cv(s1, ax, h, c), _cv(s2, ax, h, c), _cv(s2, bx, h, c), _cv(s1, bx, h, c)])
	# Corner facets
	for sx in signs:
		for sy in signs:
			for sz in signs:
				var sc := Vector3(sx, sy, sz)
				polys.append([_cv(sc, 0, h, c), _cv(sc, 1, h, c), _cv(sc, 2, h, c)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for poly in polys:
		var p0: Vector3 = poly[0]
		var p1: Vector3 = poly[1]
		var p2: Vector3 = poly[2]
		var n: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
		var centroid := Vector3.ZERO
		for q in poly:
			centroid += q
		centroid /= float(poly.size())
		if n.dot(centroid) < 0.0:
			poly.reverse()
			n = -n
		# Godot treats clockwise triangles as front-facing.
		for i in range(1, poly.size() - 1):
			for v in [poly[0], poly[i + 1], poly[i]]:
				st.set_normal(n)
				st.add_vertex(v)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh

# Vertex of a chamfered cube: corner signs `sv`, lying on the face of axis `ax`.
static func _cv(sv: Vector3, ax: int, h: float, c: float) -> Vector3:
	var v := sv * (h - c)
	v[ax] = sv[ax] * h
	return v

# Many instances of one mesh in a single draw call. items: [[Transform3D, Color], ...]
static func batch(mesh: Mesh, items: Array, outline: bool = false, shadows: bool = true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = items.size()
	mm.mesh = mesh
	for i in range(items.size()):
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := make_toon(Color.WHITE, outline)
	mat.vertex_color_use_as_albedo = true
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst

# Collision helpers for props.
static func collide_box(parent: Node3D, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	body.add_child(cs)
	parent.add_child(body)
	return body

static func collide_cyl(parent: Node3D, radius: float, height: float, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Collision"
	var cs := CollisionShape3D.new()
	var c := CylinderShape3D.new()
	c.radius = radius
	c.height = height
	cs.shape = c
	cs.position = pos
	body.add_child(cs)
	parent.add_child(body)
	return body

static func mi(mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation = rot
	m.scale = scl
	return m

static func add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var m := mi(mesh, mat, pos, rot, scl)
	parent.add_child(m)
	return m

# ---------------------------------------------------------------------
# Chibi hero builder. Faces +Z. Returns a dictionary of useful parts.
# ---------------------------------------------------------------------
static func make_chibi(o: Dictionary) -> Dictionary:
	# `root` is what the game positions on the ground. Everything is built inside `rig`,
	# which keeps the old coordinates (feet at y = 0.36) above a slim token base.
	var root := Node3D.new()
	var rig := Node3D.new()
	rig.position.y = -BASE_DROP
	root.add_child(rig)
	var outfit_parts: Array = []
	add(rig, cyl(0.84, 0.9, 0.36 - BASE_DROP, 32), toon(o.get("base", 0xefe9dc)), Vector3(0, (0.36 + BASE_DROP) / 2.0, 0))
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color.WHITE
	var ring := add(rig, torus(0.91, 0.05), ring_mat, Vector3(0, 0.33, 0))

	var body := Node3D.new()
	body.position.y = 0.36
	rig.add_child(body)

	var outfit: int = o["outfit"]
	for s in [-1.0, 1.0]:
		add(body, capsule(0.12, 0.2), toon(o.get("legs", 0x2b2a3d)), Vector3(0.16 * s, 0.24, 0))
		add(body, sphere(0.15, 12), toon(o.get("shoes", 0x3a2b2b)), Vector3(0.16 * s, 0.06, 0.05), Vector3.ZERO, Vector3(1, 0.62, 1.35))
	if o.has("skirt"):
		outfit_parts.append(add(body, cyl(0.34, 0.62, 0.5, 28), toon(o["skirt"]), Vector3(0, 0.52, 0)))
	outfit_parts.append(add(body, cyl(0.3, 0.46, 0.78, 28), toon(outfit), Vector3(0, 0.86, 0)))
	if o.has("trim"):
		add(body, cyl(0.455, 0.455, 0.1, 28), toon(o["trim"], 1.0, false), Vector3(0, 0.62, 0))
		add(body, torus(0.27, 0.06), toon(o["trim"], 1.0, false), Vector3(0, 1.24, 0))

	var head := Node3D.new()
	head.position.y = 1.78
	body.add_child(head)
	add(head, sphere(0.6, 32), toon(SKIN))

	# Hair: a cap tilted back off the forehead, a fuller back, three soft bangs and two side locks.
	var hair := toon(o["hair"])
	var hair_plain := toon(o["hair"], 1.0, false)
	add(head, sphere(0.66, 32, true), hair, Vector3(0, 0.05, 0), Vector3(-0.32, 0, 0))
	add(head, sphere(0.635, 28), hair, Vector3(0, -0.02, -0.16), Vector3.ZERO, Vector3(1.03, 1.0, 0.86))
	for i in range(-1, 2):
		add(head, sphere(0.2, 14), hair_plain, Vector3(i * 0.27, 0.3 - absf(i) * 0.05, 0.47 - absf(i) * 0.07), Vector3(0.5, i * 0.5, 0), Vector3(1.0, 0.72, 0.5))
	for s in [-1.0, 1.0]:
		add(head, capsule(0.1, 0.3), hair, Vector3(0.56 * s, -0.12, 0.12), Vector3(0.08, 0, -0.08 * s), Vector3(0.8, 1, 1))
	var accent: int = o.get("accent", 0xffffff)
	match o.get("style", ""):
		"ponytail":
			add(head, sphere(0.12, 12), toon(accent), Vector3(0, 0.25, -0.63))
			add(head, capsule(0.17, 0.72), hair, Vector3(0, -0.2, -0.85), Vector3(0.55, 0, 0))
		"long":
			add(head, capsule(0.42, 1.0), hair, Vector3(0, -0.72, -0.26), Vector3.ZERO, Vector3(1.16, 1, 0.52))
		"twintails":
			for s in [-1.0, 1.0]:
				add(head, sphere(0.13, 12), toon(accent), Vector3(0.62 * s, 0.28, -0.12))
				add(head, capsule(0.19, 0.92), hair, Vector3(0.82 * s, -0.42, -0.18), Vector3(0, 0, 0.28 * s))
		"buns":
			for s in [-1.0, 1.0]:
				add(head, sphere(0.25, 16), hair, Vector3(0.45 * s, 0.5, -0.1))
		"topknot":
			add(head, cyl(0.1, 0.15, 0.36, 12), hair, Vector3(0, 0.68, -0.25), Vector3(-0.6, 0, 0))
			add(head, sphere(0.16, 12), hair, Vector3(0, 0.82, -0.38))
		"spiky":
			for i in range(5):
				var a := -1.0 + i * 0.5
				add(head, cone(0.2, 0.5, 10), hair, Vector3(sin(a) * 0.42, 0.5, -0.28 - cos(a) * 0.12), Vector3(-0.6, 0, -sin(a) * 0.8))

	# Eyes: a dark oval, the eye colour in its lower half, and one highlight.
	for s in [-1.0, 1.0]:
		add(head, sphere(0.115, 16), flat(0x2a2038), Vector3(0.21 * s, -0.04, 0.545), Vector3(0, 0.36 * s, 0), Vector3(0.82, 1.28, 0.36))
		add(head, sphere(0.085, 14), flat(o["eye"]), Vector3(0.212 * s, -0.09, 0.563), Vector3(0, 0.36 * s, 0), Vector3(0.84, 0.86, 0.36))
		add(head, sphere(0.042, 10), flat(0xffffff), Vector3(0.21 * s + 0.035, 0.03, 0.592), Vector3.ZERO, Vector3(1, 1, 0.5))
		add(head, sphere(0.085, 10), flat(0xff8fb0, 0.5), Vector3(0.37 * s, -0.21, 0.455), Vector3(0, 0.62 * s, 0), Vector3(1.15, 0.5, 0.25))
	add(head, sphere(0.036, 8), flat(0xb8405c), Vector3(0, -0.27, 0.568), Vector3.ZERO, Vector3(1.4, 0.55, 0.4))

	# Arms. The right arm (-X) holds the weapon.
	var arms := []
	for s in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.45 * s, 1.15, 0)
		arm.rotation.z = 0.25 * s
		body.add_child(arm)
		outfit_parts.append(add(arm, capsule(0.095, 0.3), toon(o.get("sleeve", outfit)), Vector3(0, -0.24, 0)))
		add(arm, sphere(0.105, 12), toon(SKIN), Vector3(0, -0.47, 0))
		arms.append(arm)
	var rarm: Node3D = arms[0]
	rarm.rotation.x = -0.9
	var holder := Node3D.new()
	holder.position.y = -0.5
	holder.rotation.x = 0.9
	rarm.add_child(holder)
	return {"root": root, "rig": rig, "body": body, "head": head, "rarm": rarm, "larm": arms[1], "holder": holder, "ring": ring, "ring_mat": ring_mat, "outfit_parts": outfit_parts, "spinners": []}

# ---------------------------------------------------------------------
# Upgrade looks: every tier on every path visibly changes the hero.
#   Path 1 (power):   sash -> spiked pauldrons -> glowing weapon -> horned crown
#   Path 2 (speed):   headband -> visor -> flowing cape -> wings
#   Path 3 (mystic):  charm -> orbiting spirit orb -> rune circle -> halo
# At tier 3 the outfit also shifts toward the path's colour.
# ---------------------------------------------------------------------
const PATH_COLORS := [0xff5a3c, 0x3cc8ff, 0xb36bff]

static func apply_upgrade_look(m: Dictionary, path: int, tier: int) -> void:
	var body: Node3D = m["body"]
	var head: Node3D = m["head"]
	var col: int = PATH_COLORS[path]
	var glow := fx_mat(Defs.col(col, 0.35), true)
	match path:
		0:
			match tier:
				1:
					add(body, box(0.16, 0.95, 0.12), toon(col), Vector3(0, 0.9, 0.36), Vector3(0, 0, 0.75))
				2:
					for s in [-1.0, 1.0]:
						add(body, sphere(0.26, 12, true), toon(0x9aa7b4), Vector3(0.47 * s, 1.2, 0), Vector3(0, 0, -0.35 * s))
						for i in range(2):
							add(body, cone(0.07, 0.3, 6), toon(0xe8edf2), Vector3((0.5 + i * 0.1) * s, 1.38, -0.05 + i * 0.12), Vector3(0, 0, -0.5 * s))
				3:
					var holder: Node3D = m["holder"]
					holder.scale = Vector3.ONE * 1.35
					add(holder, sphere(0.5, 14), glow, Vector3(0, 0.4, 0.1))
					_tint_outfit(m, col)
				4:
					add(head, torus(0.5, 0.06), toon(0xffd34d), Vector3(0, 0.45, -0.05), Vector3(-0.15, 0, 0))
					for s in [-1.0, 1.0]:
						add(head, cone(0.1, 0.55, 8), toon(0x2a1838), Vector3(0.35 * s, 0.75, -0.05), Vector3(0, 0, -0.45 * s))
					for i in range(5):
						var a := (i - 2) * 0.32
						add(head, cone(0.09, 0.35, 6), flat(0xff8a3c), Vector3(sin(a) * 0.48, 0.62, cos(a) * 0.15 - 0.05), Vector3(0, 0, -a))
		1:
			match tier:
				1:
					add(head, torus(0.63, 0.05), toon(col), Vector3(0, 0.22, 0), Vector3(-0.15, 0, 0))
					add(head, box(0.08, 0.35, 0.05), toon(col), Vector3(0.15, 0.05, -0.62), Vector3(0.3, 0, 0.3))
				2:
					add(head, box(0.78, 0.16, 0.1), flat(0x7ff6ff, 0.75), Vector3(0, 0.0, 0.56))
				3:
					add(body, box(0.95, 1.1, 0.06), toon(col), Vector3(0, 0.8, -0.45), Vector3(0.22, 0, 0))
					_tint_outfit(m, col)
				4:
					for s in [-1.0, 1.0]:
						var wing := Node3D.new()
						wing.position = Vector3(0.18 * s, 1.15, -0.35)
						wing.rotation = Vector3(0.2, 0.5 * s, 0.35 * s)
						body.add_child(wing)
						for i in range(3):
							add(wing, capsule(0.12, 0.9 - i * 0.2), toon(0xf4fbff if i % 2 == 0 else col), Vector3(0.45 * s, 0.25 - i * 0.18, 0), Vector3(0, 0, (1.1 + i * 0.25) * s), Vector3(1, 1, 0.35))
		2:
			match tier:
				1:
					add(body, sphere(0.1, 4), flat(col), Vector3(0, 1.05, 0.45))
					add(body, torus(0.22, 0.02), toon(0xffd34d), Vector3(0, 1.2, 0.3), Vector3(PI / 2 - 0.4, 0, 0))
				2, 3:
					var pivot := Node3D.new()
					pivot.position = Vector3(0, 1.4, 0)
					pivot.rotation.y = tier * 1.7
					body.add_child(pivot)
					add(pivot, sphere(0.16, 12), flat(col), Vector3(0.95, 0.2 if tier == 2 else -0.1, 0))
					add(pivot, sphere(0.28, 12), glow, Vector3(0.95, 0.2 if tier == 2 else -0.1, 0))
					(m["spinners"] as Array).append(pivot)
					if tier == 3:
						var root: Node3D = m["rig"]
						add(root, torus(1.22, 0.035), flat(col, 0.85), Vector3(0, 0.27, 0))
						for i in range(6):
							var a2 := i * TAU / 6.0
							add(root, sphere(0.07, 8), flat(0xffffff, 0.95), Vector3(cos(a2) * 1.22, 0.27, sin(a2) * 1.22))
						_tint_outfit(m, col)
				4:
					var halo := Node3D.new()
					halo.position = Vector3(0, 2.45, -0.55)
					head.add_child(halo)
					add(halo, torus(0.7, 0.06), flat(0xffe9a8), Vector3.ZERO, Vector3(PI / 2, 0, 0))
					for i in range(8):
						var a3 := i * TAU / 8.0
						add(halo, sphere(0.07, 6), flat(col), Vector3(cos(a3) * 0.7, sin(a3) * 0.7, 0))
					add(head, sphere(0.22, 4), flat(col), Vector3(0, 1.25, 0), Vector3.ZERO, Vector3(0.7, 1.3, 0.7))
					(m["spinners"] as Array).append(halo)

# Blend the hero's clothes 40% toward the path colour.
static func _tint_outfit(m: Dictionary, hex: int) -> void:
	for part in m["outfit_parts"]:
		var mi := part as MeshInstance3D
		var base := (mi.material_override as StandardMaterial3D).albedo_color
		mi.material_override = make_toon(base.lerp(Defs.col(hex), 0.4))

## A hero skin: recolours the outfit strongly toward the skin's colour.
static func apply_skin(m: Dictionary, hex: int) -> void:
	for part in m["outfit_parts"]:
		var mi := part as MeshInstance3D
		var base := (mi.material_override as StandardMaterial3D).albedo_color
		mi.material_override = make_toon(base.lerp(Defs.col(hex), 0.8))

## Heroes added by packs (scripts/packs.gd): key -> pack object with build_hero(key).
static var pack_builders := {}

static func build_hero(key: String) -> Dictionary:
	if pack_builders.has(key):
		return pack_builders[key].build_hero(key)
	match key:
		"ninja":
			var c := make_chibi({"outfit": 0x3d2f66, "legs": 0x231b38, "sleeve": 0x2d2350, "hair": 0x22203a, "style": "ponytail", "eye": 0xd81b60, "trim": 0x7e57c2, "accent": 0xff3d6e})
			add(c.body, torus(0.33, 0.12), toon(0xff3d6e), Vector3(0, 1.3, 0))
			add(c.body, box(0.18, 0.06, 0.8), toon(0xff3d6e), Vector3(0.15, 1.2, -0.5), Vector3(0.5, 0, 0))
			add(c.head, cyl(0.645, 0.645, 0.12, 22), toon(0x22203a, 1.0, false), Vector3(0, 0.27, 0), Vector3(-0.18, 0, 0))
			add(c.head, box(0.34, 0.15, 0.06), toon(0xc8cbd6), Vector3(0, 0.32, 0.6), Vector3(-0.25, 0, 0))
			add(c.holder, sphere(0.22, 4), toon(0xc8cbd6), Vector3(0, 0, 0.1), Vector3.ZERO, Vector3(1, 0.25, 1))
			return c
		"miko":
			var c := make_chibi({"outfit": 0xfdfdfd, "skirt": 0xd62f3a, "legs": 0xd62f3a, "hair": 0x1d1830, "style": "long", "eye": 0x8e4bdb, "trim": 0xd62f3a})
			add(c.head, sphere(0.15, 10), toon(0xd62f3a), Vector3(0, 0.2, -0.65))
			for s in [-1.0, 1.0]:
				add(c.head, cone(0.14, 0.32, 4), toon(0xd62f3a), Vector3(0.18 * s, 0.2, -0.68), Vector3(0, 0, -1.57 * s))
			# Bow: a ring stood up and squashed into a tall ellipse
			add(c.holder, torus(0.62, 0.045), toon(0x8b5a2b), Vector3(0, 0.1, 0.05), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.35))
			return c
		"mage":
			var c := make_chibi({"outfit": 0xc62828, "skirt": 0x2b1b2e, "legs": 0x2b1b2e, "hair": 0x6b3b1f, "style": "spiky", "eye": 0xff7043, "trim": 0xffb300})
			add(c.head, cyl(1.0, 1.0, 0.08, 24), toon(0x2b1b2e), Vector3(0, 0.42, 0), Vector3(-0.12, 0, 0))
			add(c.head, cone(0.62, 1.4, 20), toon(0x2b1b2e), Vector3(0, 1.08, -0.12), Vector3(-0.28, 0, 0))
			add(c.head, cyl(0.6, 0.62, 0.14, 20), toon(0xc62828, 1.0, false), Vector3(0, 0.5, -0.02), Vector3(-0.15, 0, 0))
			add(c.body, box(1.0, 1.0, 0.08), toon(0x8e0000), Vector3(0, 0.85, -0.45), Vector3(0.18, 0, 0))
			add(c.holder, cyl(0.05, 0.06, 1.8, 8), toon(0x6d4c41), Vector3(0, 0.3, 0))
			add(c.holder, sphere(0.22, 4), flat(0xff3d00), Vector3(0, 1.32, 0))
			add(c.holder, torus(0.25, 0.04), toon(0xffb300), Vector3(0, 1.32, 0), Vector3(PI / 2, 0, 0))
			return c
		"ice":
			var c := make_chibi({"outfit": 0x7fd3ff, "skirt": 0xd4f1ff, "legs": 0xffffff, "hair": 0xeef6ff, "style": "long", "eye": 0x2f8cff, "trim": 0xffffff, "sleeve": 0xd4f1ff})
			for i in range(-2, 3):
				add(c.head, cone(0.06, 0.22 - absf(i) * 0.04, 4), toon(0xffd34d, 1.0, false), Vector3(i * 0.13, 0.62 - absf(i) * 0.03, 0.3), Vector3(-0.4, 0, 0))
			add(c.holder, cyl(0.04, 0.04, 1.0, 6), toon(0xffffff), Vector3(0, 0.2, 0))
			for i in range(3):
				add(c.holder, box(0.5, 0.07, 0.07), flat(0x9ff3ff), Vector3(0, 0.78, 0), Vector3(0, 0, i * PI / 3))
			return c
		"samurai":
			var c := make_chibi({"outfit": 0x2a5bb8, "skirt": 0x1f2433, "legs": 0x1f2433, "hair": 0x15121c, "style": "topknot", "eye": 0x8b5a2b, "trim": 0xffffff, "sleeve": 0x2a5bb8})
			add(c.holder, box(0.06, 1.5, 0.14), toon(0xe6ecf5), Vector3(0, 0.95, 0))
			add(c.holder, cyl(0.16, 0.16, 0.05, 10), toon(0xffc107, 1.0, false), Vector3(0, 0.2, 0))
			add(c.holder, cyl(0.05, 0.05, 0.4, 6), toon(0x1b1b1b), Vector3(0, 0, 0))
			add(c.body, box(0.08, 0.12, 1.2), toon(0x1b1b1b), Vector3(0.45, 0.6, -0.1), Vector3(0.4, 0, 0.3))
			return c
		"mecha":
			var c := make_chibi({"outfit": 0xff8f1f, "legs": 0x3a3a48, "hair": 0xff6fae, "style": "buns", "eye": 0x00c8ff, "trim": 0x3a3a48, "sleeve": 0x3a3a48})
			for s in [-1.0, 1.0]:
				add(c.head, torus(0.13, 0.05), toon(0x3a3a48), Vector3(0.18 * s, 0.4, 0.45), Vector3(PI / 2 - 0.6, 0, 0))
				add(c.head, cyl(0.1, 0.1, 0.02, 14), flat(0x7ff6ff), Vector3(0.18 * s, 0.4, 0.47), Vector3(PI / 2 - 0.6, 0, 0))
			add(c.holder, cyl(0.2, 0.26, 1.0, 14), toon(0x6b7385), Vector3(0, 0, 0.35), Vector3(PI / 2, 0, 0))
			add(c.holder, torus(0.2, 0.05), flat(0x00e5ff), Vector3(0, 0, 0.86), Vector3(PI / 2, 0, 0))
			add(c.body, box(0.7, 0.7, 0.35), toon(0x6b7385), Vector3(0, 1.0, -0.45))
			return c
		"kaito":
			var c := make_chibi({"outfit": 0xc62828, "legs": 0x2b3a6b, "hair": 0x2b2a3d, "style": "spiky", "eye": 0x2b3a6b, "trim": 0xffd34d, "sleeve": 0xf5f0e6})
			# Captain's tricorn hat
			add(c.head, cyl(0.8, 0.85, 0.12, 3), toon(0x1f1f2b), Vector3(0, 0.55, 0), Vector3(-0.1, PI, 0))
			add(c.head, cyl(0.5, 0.6, 0.45, 12), toon(0x1f1f2b), Vector3(0, 0.78, -0.05))
			add(c.head, sphere(0.1, 8), toon(0xffd34d), Vector3(0, 0.82, 0.55))
			add(c.body, box(0.12, 0.9, 0.12), toon(0xffd34d), Vector3(-0.2, 0.9, 0.38), Vector3(0, 0, 0.6))
			add(c.holder, box(0.07, 1.2, 0.18), toon(0xe6ecf5), Vector3(0, 0.75, 0), Vector3(0, 0, 0.15))
			add(c.holder, torus(0.16, 0.04), toon(0xffd34d), Vector3(0, 0.12, 0))
			add(c.body, cyl(0.06, 0.06, 0.55, 8), toon(0x6b4a2a), Vector3(0.55, 0.72, 0.2), Vector3(PI / 2, 0, 0))
			return c
		"rei":
			var c := make_chibi({"outfit": 0xff9a26, "legs": 0x2f4f9e, "hair": 0x1f1f2b, "style": "spiky", "eye": 0x2b2a3d, "trim": 0x2f4f9e, "sleeve": SKIN})
			for i in range(4):
				add(c.head, cone(0.16, 0.55, 5), toon(0x1f1f2b), Vector3(-0.3 + i * 0.2, 0.62, -0.1), Vector3(-0.3, 0, (i - 1.5) * 0.35))
			add(c.body, cyl(0.5, 0.5, 0.12, 16), toon(0x2f4f9e), Vector3(0, 0.62, 0))
			add(c.holder, sphere(0.28, 12), flat(0xffd34d, 0.85), Vector3(0, 0.05, 0.2))
			add(c.holder, sphere(0.42, 12), fx_mat(Defs.col(0xff9a26, 0.35), true), Vector3(0, 0.05, 0.2))
			return c
		"ichika":
			var c := make_chibi({"outfit": 0x1f1f2b, "skirt": 0x1f1f2b, "legs": 0x1f1f2b, "hair": 0xe9e4f0, "style": "ponytail", "eye": 0xd81b60, "trim": 0xd81b60, "accent": 0xd81b60})
			add(c.body, box(0.95, 0.12, 0.5), toon(0x2b2a3d), Vector3(0, 1.25, 0))
			for i in range(3):
				add(c.body, box(0.18, 0.32, 0.02), flat(0xfff3c4), Vector3(-0.35 + i * 0.35, 0.95, 0.47), Vector3(0, 0, (i - 1) * 0.25))
			add(c.holder, box(0.22, 0.36, 0.02), flat(0xfff3c4), Vector3(0, 0.15, 0.08))
			add(c.holder, box(0.12, 0.04, 0.03), flat(0xd81b60), Vector3(0, 0.2, 0.1))
			add(c.rig, torus(1.15, 0.04), flat(0xd81b60, 0.8), Vector3(0, 0.4, 0))
			return c
		"gen":
			var c := make_chibi({"outfit": 0x2e7d6b, "legs": 0x2b2a3d, "hair": 0x3a8a3a, "style": "short", "eye": 0xffd34d, "trim": 0xffd34d, "sleeve": 0x2e7d6b})
			for s in [-1.0, 1.0]:
				add(c.head, torus(0.13, 0.05), toon(0x4a4a55), Vector3(0.18 * s, 0.4, 0.45), Vector3(PI / 2 - 0.6, 0, 0))
				add(c.head, cyl(0.1, 0.1, 0.02, 14), flat(0xffd34d, 0.8), Vector3(0.18 * s, 0.4, 0.47), Vector3(PI / 2 - 0.6, 0, 0))
			add(c.body, box(0.75, 0.75, 0.4), toon(0x4a4a55), Vector3(0, 1.0, -0.45))
			add(c.body, cyl(0.06, 0.06, 0.7, 6), toon(0x9aa7b4), Vector3(0.25, 1.55, -0.45))
			add(c.holder, sphere(0.16, 10), toon(0x3a8a3a), Vector3(0, 0.05, 0.05))
			add(c.holder, cyl(0.05, 0.05, 0.12, 6), toon(0x9aa7b4), Vector3(0, 0.22, 0.05))
			return c
		"lumi":
			var c := make_chibi({"outfit": 0xffffff, "skirt": 0x7fb6ff, "legs": 0xffffff, "hair": 0xffd34d, "style": "twintails", "eye": 0x2f8cff, "trim": 0xff6fae, "accent": 0xff6fae, "sleeve": 0xffffff})
			add(c.body, sphere(0.16, 10), toon(0xff6fae), Vector3(0, 1.12, 0.42), Vector3.ZERO, Vector3(1.6, 0.8, 0.6))
			add(c.head, sphere(0.12, 4), toon(0xffd34d), Vector3(0, 0.6, 0.3), Vector3.ZERO, Vector3(1.4, 1.4, 0.5))
			add(c.holder, cyl(0.04, 0.04, 0.9, 6), toon(0xff6fae), Vector3(0, 0.25, 0))
			add(c.holder, sphere(0.2, 4), flat(0xffd34d), Vector3(0, 0.8, 0), Vector3.ZERO, Vector3(1.2, 1.2, 0.5))
			add(c.holder, torus(0.25, 0.03), flat(0xff6fae), Vector3(0, 0.8, 0), Vector3(PI / 2, 0, 0))
			return c
		"ren":
			var c := make_chibi({"outfit": 0xf5f5f5, "legs": 0x2b2a3d, "hair": 0xd9452b, "style": "spiky", "eye": 0xffb02e, "trim": 0x2b2a3d, "sleeve": SKIN, "accent": 0xffffff})
			add(c.head, cyl(0.645, 0.645, 0.1, 22), toon(0xd9452b, 1.0, false), Vector3(0, 0.27, 0), Vector3(-0.18, 0, 0))
			add(c.body, cyl(0.49, 0.49, 0.1, 16), toon(0x2b2a3d), Vector3(0, 0.64, 0))
			add(c.holder, sphere(0.17, 10), toon(0xd9452b), Vector3(0, 0.0, 0.05))
			add(c.body, sphere(0.17, 10), toon(0xd9452b), Vector3(0.56, 0.72, 0.1))
			return c
		"kenta":
			var c := make_chibi({"outfit": 0x6b8f3a, "legs": 0x4a3a2a, "hair": 0x3a2a1a, "style": "short", "eye": 0x4a8a3a, "trim": 0x8a6a3a, "sleeve": 0x6b8f3a})
			add(c.holder, cyl(0.04, 0.04, 2.0, 6), toon(0x8b5a2b), Vector3(0, 0.5, 0))
			add(c.holder, cone(0.1, 0.35, 6), toon(0xd0d4e0), Vector3(0, 1.65, 0))
			add(c.body, box(0.5, 0.6, 0.18), toon(0x8a6a3a), Vector3(0, 0.95, -0.45))
			for i in range(3):
				add(c.body, cyl(0.025, 0.025, 1.0, 5), toon(0x8b5a2b), Vector3(-0.12 + i * 0.12, 1.35, -0.48), Vector3(0.2, 0, 0))
			return c
		"saya":
			var c := make_chibi({"outfit": 0x3a4a6b, "skirt": 0x2b2a3d, "legs": 0x2b2a3d, "hair": 0xf2c14e, "style": "ponytail", "eye": 0x2f8cff, "trim": 0xffb02e, "accent": 0xffb02e})
			add(c.head, box(1.1, 0.12, 0.8), toon(0x2b2a3d), Vector3(0, 0.62, 0), Vector3(-0.1, 0, 0))
			add(c.head, cyl(0.45, 0.5, 0.35, 12), toon(0x2b2a3d), Vector3(0, 0.78, 0))
			var cannon := Node3D.new()
			cannon.position = Vector3(0.75, 0.55, 0.3)
			c.body.add_child(cannon)
			add(cannon, cyl(0.22, 0.28, 1.1, 14), toon(0x4a4a55), Vector3(0, 0.25, 0.2), Vector3(PI / 2 - 0.5, 0, 0))
			add(cannon, cyl(0.3, 0.3, 0.12, 12), toon(0x8b5a2b), Vector3(0.0, -0.1, 0), Vector3(0, 0, PI / 2))
			return c
		"sora":
			var c := make_chibi({"outfit": 0x2f4f9e, "skirt": 0xfdfdfd, "legs": 0xfdfdfd, "hair": 0x7fb6ff, "style": "long", "eye": 0xfff36b, "trim": 0xfff36b, "sleeve": 0xfdfdfd})
			for i in range(3):
				add(c.head, cone(0.06, 0.3, 4), flat(0xfff36b), Vector3(-0.2 + i * 0.2, 0.7, 0.2), Vector3(-0.3, 0, (i - 1) * 0.4))
			add(c.holder, cyl(0.04, 0.04, 1.2, 6), toon(0xfdfdfd), Vector3(0, 0.3, 0))
			for i in range(3):
				add(c.holder, box(0.08, 0.25, 0.05), flat(0xfff36b), Vector3((i - 1) * 0.12, 0.98 + i * 0.05, 0), Vector3(0, 0, (i - 1) * 0.6))
			add(c.body, sphere(0.5, 10), toon(0xdfe8ff, 0.85), Vector3(-0.2, 2.9, -0.2), Vector3.ZERO, Vector3(1.4, 0.6, 1.0))
			return c
		"riku":
			var c := make_chibi({"outfit": 0x2e7d6b, "legs": 0x2b2a3d, "hair": 0x2b2a3d, "style": "short", "eye": 0x7ff6ff, "trim": 0xffb02e, "sleeve": 0x2b2a3d})
			add(c.head, box(0.8, 0.14, 0.12), flat(0x7ff6ff, 0.8), Vector3(0, 0.05, 0.56))
			add(c.holder, box(0.35, 0.22, 0.12), toon(0x4a4a55), Vector3(0, 0.0, 0.05))
			var drone := Node3D.new()
			drone.position = Vector3(0, 3.0, 0)
			c.rig.add_child(drone)
			add(drone, box(0.5, 0.15, 0.5), toon(0x4a4a55), Vector3.ZERO)
			for dx in [-1.0, 1.0]:
				for dz in [-1.0, 1.0]:
					add(drone, cyl(0.2, 0.2, 0.03, 10), flat(0xd0d4e0, 0.7), Vector3(dx * 0.35, 0.08, dz * 0.35))
			add(drone, sphere(0.07, 6), flat(0xff5a3c), Vector3(0, -0.08, 0.25))
			c["spinners"].append(drone)
			return c
		"hina":
			var c := make_chibi({"outfit": 0xffb02e, "legs": 0x4a4a55, "hair": 0x8a5a3a, "style": "twintails", "eye": 0x2e7d6b, "trim": 0x4a4a55, "accent": 0x4a4a55, "sleeve": 0x4a4a55})
			add(c.head, torus(0.2, 0.05), toon(0x4a4a55), Vector3(0.3, 0.45, 0.4), Vector3(PI / 2 - 0.4, 0, 0))
			add(c.holder, box(0.08, 0.5, 0.08), toon(0x9aa7b4), Vector3(0, 0.2, 0.05), Vector3(0, 0, 0.6))
			var turret := Node3D.new()
			turret.position = Vector3(0.95, 0.36, 0.25)
			c.rig.add_child(turret)
			add(turret, cyl(0.25, 0.32, 0.5, 10), toon(0x4a4a55), Vector3(0, 0.25, 0))
			add(turret, box(0.35, 0.28, 0.45), toon(0xffb02e), Vector3(0, 0.6, 0))
			add(turret, cyl(0.06, 0.06, 0.6, 8), toon(0x2b2a3d), Vector3(0, 0.62, 0.45), Vector3(PI / 2, 0, 0))
			return c
		"hiro":
			var c := make_chibi({"outfit": 0x7a3b8f, "skirt": 0x4a2a55, "legs": 0x4a2a55, "hair": 0x2b2a3d, "style": "short", "eye": 0xffd34d, "trim": 0xffd34d, "sleeve": 0x7a3b8f})
			add(c.head, cyl(0.7, 0.75, 0.08, 18), toon(0xd9b36a), Vector3(0, 0.55, 0))
			add(c.head, cone(0.55, 0.5, 18), toon(0xd9b36a), Vector3(0, 0.82, 0))
			add(c.holder, sphere(0.22, 10), toon(0x9b6a3a), Vector3(0, 0.05, 0.05), Vector3.ZERO, Vector3(1, 1.2, 1))
			for i in range(3):
				add(c.rig, cyl(0.16, 0.16, 0.06, 12), toon(0xffd34d), Vector3(0.8, 0.4 + i * 0.07, 0.4))
			add(c.rig, box(0.7, 0.5, 0.5), toon(0x9b6a3a), Vector3(-0.85, 0.6, 0.3))
			return c
		"nao":
			var c := make_chibi({"outfit": 0xfdfdfd, "skirt": 0x7fd3a0, "legs": 0x7fd3a0, "hair": 0x3a8a6b, "style": "long", "eye": 0x3a8a6b, "trim": 0x7fd3a0, "sleeve": 0xfdfdfd})
			add(c.head, torus(0.18, 0.05), flat(0xfff3a0), Vector3(0, 0.55, -0.4), Vector3(PI / 2 - 0.5, 0, 0))
			add(c.holder, cyl(0.035, 0.035, 0.9, 6), toon(0x8b5a2b), Vector3(0, 0.2, 0))
			add(c.holder, cone(0.18, 0.3, 10), toon(0xffd34d), Vector3(0, 0.75, 0), Vector3(PI, 0, 0))
			add(c.holder, sphere(0.06, 6), toon(0xffd34d), Vector3(0, 0.55, 0))
			return c
		"komugi":
			var c := make_chibi({"outfit": 0x6fae4f, "skirt": 0x3c6e9f, "legs": 0x3c6e9f, "hair": 0x7a4a24, "style": "short", "eye": 0x6b3f1d, "trim": 0xf2d16b, "sleeve": 0xfdf6e3, "base": 0x8fc75c})
			# Straw hat
			add(c.head, cyl(0.95, 1.0, 0.07, 20), toon(0xe9c46a), Vector3(0, 0.45, 0))
			add(c.head, cone(0.55, 0.42, 18), toon(0xe9c46a), Vector3(0, 0.68, 0))
			add(c.head, torus(0.53, 0.05), toon(0xc0392b, 1.0, false), Vector3(0, 0.5, 0))
			# Sickle-hoe
			add(c.holder, cyl(0.04, 0.04, 1.1, 6), toon(0x8b5a2b), Vector3(0, 0.25, 0))
			add(c.holder, box(0.42, 0.06, 0.12), toon(0xb8c2cc), Vector3(0.15, 0.8, 0))
			# Rice paddy on the base, with sprouts
			add(c.rig, cyl(0.86, 0.86, 0.04, 20), toon(0x5aa7c8, 1.0, false), Vector3(0, 0.37, 0))
			for i in range(10):
				var a := i / 10.0 * TAU
				var sp := add(c.rig, cone(0.06, 0.36, 5), toon(0x7ccf52, 1.0, false), Vector3(cos(a) * 0.72, 0.52, sin(a) * 0.72))
				sp.rotation.z = sin(a * 3.0) * 0.25
			# Sack of rice
			add(c.rig, sphere(0.26, 10), toon(0xf3e4c0), Vector3(-0.72, 0.58, 0.45), Vector3.ZERO, Vector3(1, 1.15, 1))
			return c
		_:
			var c := make_chibi({"outfit": 0xff7ac8, "skirt": 0xffffff, "legs": 0xffffff, "hair": 0x9b6bff, "style": "twintails", "eye": 0xff3d8b, "trim": 0xffd34d, "accent": 0xffd34d, "base": 0xffc6e4})
			add(c.head, sphere(0.17, 4), toon(0xffd34d), Vector3(0.4, 0.42, 0.35))
			add(c.holder, cyl(0.05, 0.035, 0.4, 8), toon(0x333344), Vector3(0, 0.15, 0.05))
			add(c.holder, sphere(0.1, 10), toon(0xdddddd), Vector3(0, 0.38, 0.05))
			return c
	return {}

# ---------------------------------------------------------------------
# Spirits
# ---------------------------------------------------------------------
static func build_enemy(k: String, camo: bool, rainbow: StandardMaterial3D, rainbow_camo: StandardMaterial3D) -> Node3D:
	var d: Dictionary = Defs.ENEMIES[k]
	var g := Node3D.new()
	var alpha := 0.4 if camo else 1.0
	var color: int = d["color"]
	var body_mat: StandardMaterial3D
	if d.get("rainbow", false):
		body_mat = rainbow_camo if camo else rainbow
	else:
		body_mat = toon(color, alpha)
	var s: float = d["size"]
	if k == "oni":
		add(g, sphere(s, 28), body_mat, Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.95, 1))
		for x in [-1.0, 1.0]:
			add(g, cone(0.32, 1.2, 10), toon(0xfff4d6), Vector3(0.8 * x, s * 0.85, 0.1), Vector3(0, 0, -0.4 * x))
			add(g, sphere(0.34, 12), flat(0xffeb3b), Vector3(0.55 * x, 0.35, s * 0.92), Vector3(0, 0.4 * x, 0.3 * x), Vector3(1.2, 0.7, 0.4))
			add(g, sphere(0.13, 8), flat(0x1b0f24), Vector3(0.5 * x, 0.33, s * 1.0))
			add(g, box(0.7, 0.14, 0.14), flat(0x1b0f24), Vector3(0.55 * x, 0.68, s * 0.88), Vector3(0, 0, 0.45 * x))
			add(g, cone(0.13, 0.5, 8), toon(0xffffff), Vector3(0.4 * x, -0.65, s * 0.85))
		add(g, box(1.2, 0.22, 0.2), flat(0x3b0b16), Vector3(0, -0.45, s * 0.93))
		add(g, torus(s * 0.95, 0.16), toon(0xf5e0a0), Vector3(0, -0.35, 0))
	elif k == "shogun":
		add(g, sphere(s, 26), body_mat, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 1.0, 1))
		# Kabuto helmet with a golden crest
		add(g, sphere(s * 1.04, 24, true), toon(0x1c1530), Vector3(0, s * 0.15, 0))
		add(g, cyl(s * 1.3, s * 1.35, 0.14, 24), toon(0x1c1530), Vector3(0, s * 0.18, 0), Vector3(-0.15, 0, 0))
		for x in [-1.0, 1.0]:
			add(g, cone(0.12, 1.5, 6), toon(0xffc93c), Vector3(0.45 * x, s * 1.15, s * 0.35), Vector3(-0.3, 0, -0.55 * x))
			add(g, sphere(0.2, 10), flat(0xff3d6e), Vector3(0.5 * x, 0.15, s * 0.95), Vector3.ZERO, Vector3(1.4, 0.6, 0.4))
			add(g, box(0.9, 0.5, 0.9), toon(0x5a1f2e), Vector3(1.6 * x, -0.2, 0), Vector3(0, 0, 0.3 * x))
		add(g, sphere(0.3, 10), toon(0xffc93c), Vector3(0, s * 0.85, s * 0.6))
		add(g, box(1.3, 0.5, 0.2), toon(0x9e9e9e), Vector3(0, -0.45, s * 0.92))
		add(g, torus(s * 0.98, 0.14), toon(0xffc93c), Vector3(0, -0.3, 0))
	elif k == "dragon":
		add(g, sphere(s, 24), body_mat, Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 0.85, 1.25))
		add(g, box(1.5, 0.9, 1.4), toon(color), Vector3(0, -0.3, s * 1.1))
		for x in [-1.0, 1.0]:
			add(g, cone(0.22, 1.8, 8), toon(0xffd34d), Vector3(0.6 * x, s * 0.8, -0.6), Vector3(-0.9, 0, -0.3 * x))
			add(g, sphere(0.3, 12), flat(0xff5252), Vector3(0.75 * x, 0.45, s * 0.95), Vector3(0, 0.6 * x, 0), Vector3(1, 0.6, 0.4))
			add(g, cyl(0.02, 0.04, 2.2, 5), flat(0xffd34d), Vector3(0.95 * x, -0.4, s * 1.4), Vector3(0, 0, 1.2 * x))
		add(g, cone(0.9, 1.2, 8), toon(0xffffff), Vector3(0, s * 0.5, -s * 0.9), Vector3(-2.0, 0, 0))
	else:
		add(g, sphere(s, 22), body_mat, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.95, 1))
		if not d.get("mask", false):
			add(g, cone(s * 0.6, s * 1.1, 14), body_mat, Vector3(0, s * 0.95, -s * 0.25), Vector3(-0.5, 0, 0))
		else:
			for x in [-1.0, 1.0]:
				add(g, cone(0.13, 0.42, 8), toon(0xfff4d6, alpha), Vector3(0.38 * x, s * 0.82, 0), Vector3(0, 0, -0.35 * x))
			add(g, box(0.05, 0.5, 0.05), flat(0x6d4c41), Vector3(0.2, 0.15, s * 0.98), Vector3(0, 0, 0.5))
			add(g, sphere(0.12, 4), flat(0xff3d6e), Vector3(0, 0.42, s * 0.92))
		if d.get("fox", false):
			for x in [-1.0, 1.0]:
				add(g, cone(s * 0.28, s * 0.7, 8), body_mat, Vector3(s * 0.5 * x, s * 0.8, 0), Vector3(0, 0, -0.35 * x))
				add(g, cone(s * 0.14, s * 0.4, 8), toon(0xffffff, alpha), Vector3(s * 0.52 * x, s * 0.82, s * 0.08), Vector3(0, 0, -0.35 * x))
			for i in range(3):
				var tail := add(g, capsule(s * 0.22, s * 0.9), body_mat, Vector3((i - 1) * s * 0.4, s * 0.1, -s * 1.0), Vector3(-0.9, (i - 1) * 0.5, 0))
				tail.scale = Vector3.ONE
				add(g, sphere(s * 0.2, 8), toon(0xffffff, alpha), Vector3((i - 1) * s * 0.55, s * 0.6, -s * 1.45))
		if d.get("crane", false):
			for x in [-1.0, 1.0]:
				add(g, box(s * 1.6, 0.05, s * 0.8), toon(0xf4f1ea, alpha), Vector3(s * 1.1 * x, s * 0.3, 0), Vector3(0, 0, 0.35 * x))
			add(g, cone(s * 0.2, s * 0.9, 4), toon(0xe63946, alpha), Vector3(0, s * 0.4, s * 0.95), Vector3(PI / 2, 0, 0))
		if d.get("lantern", false):
			add(g, cyl(s * 0.5, s * 0.5, 0.12, 14), toon(0x3b2a1a), Vector3(0, s * 0.98, 0))
			add(g, cyl(s * 0.5, s * 0.5, 0.12, 14), toon(0x3b2a1a), Vector3(0, -s * 0.9, 0))
			for i in range(3):
				add(g, torus(s * 0.98, 0.03), toon(0xc0392b, alpha), Vector3(0, (i - 1) * s * 0.42, 0))
			var glow := add(g, sphere(s * 1.25, 12), fx_mat(Color(1.0, 0.7, 0.3, 0.18), true))
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var eye_col := 0xff4d6d if k == "shadow" else 0x1b0f24
		for x in [-1.0, 1.0]:
			add(g, sphere(s * 0.17, 10), flat(eye_col, 0.6 if camo else 1.0), Vector3(s * 0.34 * x, s * 0.08, s * 0.92), Vector3(0, 0.35 * x, 0), Vector3(0.8, 1.3, 0.5))
			add(g, sphere(s * 0.06, 6), flat(0xffffff), Vector3(s * 0.37 * x + s * 0.03, s * 0.18, s * 0.99))
	if camo:
		for i in range(3):
			add(g, sphere(s * 0.22, 6), flat(0x3b7d3b, 0.7), Vector3(cos(i * 2.1) * s * 0.75, s * 0.4, sin(i * 2.1) * s * 0.75), Vector3.ZERO, Vector3(1, 0.3, 0.6))
	return g

# ---------------------------------------------------------------------
# Scenery
# ---------------------------------------------------------------------
static func torii() -> Node3D:
	var g := Node3D.new()
	var red := toon(0xe23b3b)
	for x in [-2.5, 2.5]:
		add(g, cyl(0.26, 0.3, 4.6, 12), red, Vector3(x, 2.3, 0))
		add(g, cyl(0.38, 0.38, 0.4, 12), toon(0x2a2a2a), Vector3(x, 0.2, 0))
	add(g, box(7, 0.45, 0.6), toon(0x2a2a2a), Vector3(0, 4.85, 0))
	add(g, box(6.4, 0.35, 0.5), red, Vector3(0, 4.45, 0))
	add(g, box(5.8, 0.3, 0.4), red, Vector3(0, 3.6, 0))
	return g

static func shrine() -> Node3D:
	var g := Node3D.new()
	add(g, box(5, 0.6, 4.2), toon(0x8d6748), Vector3(0, 0.3, 0))
	for p in [Vector2(-2, -1.6), Vector2(2, -1.6), Vector2(-2, 1.6), Vector2(2, 1.6)]:
		add(g, cyl(0.18, 0.18, 2.4, 10), toon(0xe23b3b), Vector3(p.x, 1.8, p.y))
	add(g, box(3.6, 2.2, 2.8), toon(0xfff5e6), Vector3(0, 1.7, 0))
	add(g, cone(4.3, 1.9, 4), toon(0xb5482f), Vector3(0, 3.9, 0), Vector3(0, PI / 4, 0), Vector3(1, 1, 0.85))
	add(g, sphere(0.35, 14), toon(0xffd34d), Vector3(0, 5.0, 0))
	return g

static func sakura(s: float, rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	add(g, cyl(0.63, 1.0, 1.0, 12), toon(0x7a4b36), Vector3(0, 1.1 * s, 0), Vector3.ZERO, Vector3(0.35 * s, 2.2 * s, 0.35 * s))
	var cols := [0xffb7d5, 0xffc9e0, 0xff9fc7]
	for i in range(4):
		var r := (1.1 + rng.randf() * 0.4) * s
		add(g, sphere(1.0, 16), toon(cols[i % 3]), Vector3(cos(i * 2.1) * 0.8 * s, (2.5 + rng.randf() * 0.6) * s, sin(i * 2.1) * 0.8 * s), Vector3.ZERO, Vector3.ONE * r)
	g.set_meta("r", 1.6 * s)
	return g

# Big round leafy tree: a cluster of overlapping canopy balls.
static func round_tree(s: float, rng: RandomNumberGenerator, greens: Array = [0x2f9a36, 0x3fae3a, 0x52c043], top: int = 0x6fd456) -> Node3D:
	var g := Node3D.new()
	add(g, cyl(0.66, 1.0, 1.0, 12), toon(0x7a4f2e), Vector3(0, 0.8 * s, 0), Vector3.ZERO, Vector3(0.38 * s, 1.6 * s, 0.38 * s))
	for i in range(6):
		var a := i * 1.05 + rng.randf() * 0.4
		var r := (0.95 + rng.randf() * 0.35) * s
		var rad := 0.0 if i == 0 else 0.95 * s
		add(g, sphere(1.0, 16), toon(greens[mini(i, 2)] if i < 3 else greens[2]), Vector3(cos(a) * rad, (2.2 + (0.6 if i == 0 else rng.randf() * 0.4)) * s, sin(a) * rad), Vector3.ZERO, Vector3.ONE * r)
	add(g, sphere(1.0, 16), toon(top), Vector3(0.2 * s, 3.0 * s, 0.25 * s), Vector3.ZERO, Vector3.ONE * 0.75 * s)
	g.set_meta("r", 1.9 * s)
	return g

# Low bush made of a few soft green blobs.
static func bush(s: float, rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	var greens := [0x3aa83a, 0x4cbb40, 0x5ccb48]
	for i in range(4):
		var a := i * 1.6 + rng.randf()
		var r := (0.55 + rng.randf() * 0.3) * s
		add(g, sphere(1.0, 16), toon(greens[i % 3]), Vector3(cos(a) * 0.55 * s, r * 0.75, sin(a) * 0.55 * s), Vector3.ZERO, Vector3.ONE * r)
	g.set_meta("r", 1.2 * s)
	return g

# Curved palm tree with drooping fronds.
static func palm(s: float, rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	var lean := 0.12 + rng.randf() * 0.1
	var p := Vector3.ZERO
	for i in range(6):
		var seg_h := 0.75 * s
		var c := add(g, cyl(0.77, 1.0, 1.0, 12), toon(0xa8773f if i % 2 == 0 else 0x93652f), p + Vector3(0, seg_h / 2.0, 0), Vector3(0, 0, -lean * i * 0.5), Vector3(0.26 * s, seg_h, 0.26 * s))
		c.position.x += i * lean * 0.45 * s
		p.y += seg_h * 0.95
	var top := Vector3(6 * lean * 0.45 * s, p.y, 0)
	for i in range(7):
		var a := i * TAU / 7.0 + rng.randf() * 0.2
		var frond := Node3D.new()
		frond.position = top
		frond.rotation = Vector3(0, a, 0)
		g.add_child(frond)
		add(frond, capsule(0.22, 1.5), toon(0x3fae3a if i % 2 == 0 else 0x2f9a36), Vector3(0, -0.25 * s, 0.85 * s), Vector3(PI / 2 + 0.45, 0, 0), Vector3(s, s, 0.3 * s))
	for i in range(3):
		add(g, sphere(0.16, 8), toon(0x6b4a2a), top + Vector3(cos(i * 2.1) * 0.22 * s, -0.25 * s, sin(i * 2.1) * 0.22 * s), Vector3.ZERO, Vector3.ONE * s)
	g.set_meta("r", 1.0 * s)
	return g

static func crate() -> Node3D:
	var g := Node3D.new()
	add(g, box(1.1, 1.1, 1.1), toon(0xb9773d), Vector3(0, 0.55, 0))
	for y in [0.12, 0.98]:
		add(g, box(1.16, 0.14, 1.16), toon(0x8a5427, 1.0, false), Vector3(0, y, 0))
	add(g, box(1.12, 0.14, 1.12), toon(0x8a5427, 1.0, false), Vector3(0, 0.55, 0), Vector3(0, 0, PI / 4), Vector3(1.25, 1, 1))
	g.set_meta("r", 1.0)
	return g

# Pine with snow on every layer.
static func snowy_pine(s: float) -> Node3D:
	var g := Node3D.new()
	add(g, cyl(0.66, 1.0, 1.0, 8), toon(0x6b4430), Vector3(0, 0.5 * s, 0), Vector3.ZERO, Vector3(0.3 * s, 1.0 * s, 0.3 * s))
	for i in range(3):
		var r := (1.5 - i * 0.35) * s
		add(g, cone(1.0, 1.0, 14), toon(0x2f7d55), Vector3(0, (1.3 + i * 0.9) * s, 0), Vector3.ZERO, Vector3(r, 1.6 * s, r))
		add(g, cone(1.0, 1.0, 14), toon(0xf4f8ff), Vector3(0, (1.62 + i * 0.9) * s, 0), Vector3.ZERO, Vector3(r * 0.62, 0.95 * s, r * 0.62))
	g.set_meta("r", 1.4 * s)
	return g

# Saguaro-style cactus with one or two arms.
static func cactus(s: float, rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	var green := toon(0x4f9d3a)
	add(g, capsule(0.32, 1.0), green, Vector3(0, 1.0 * s, 0), Vector3.ZERO, Vector3(s, 1.6 * s, s))
	for side in ([-1.0, 1.0] if rng.randf() < 0.6 else [1.0]):
		var h := rng.randf_range(0.9, 1.5) * s
		add(g, capsule(0.2, 0.4), green, Vector3(side * 0.42 * s, h, 0), Vector3(0, 0, side * PI / 2.0), Vector3.ONE * s)
		add(g, capsule(0.2, 0.5), green, Vector3(side * 0.68 * s, h + 0.42 * s, 0), Vector3.ZERO, Vector3.ONE * s)
	add(g, sphere(0.08, 6), toon(0xff7eb6), Vector3(0, 2.15 * s, 0), Vector3.ZERO, Vector3.ONE * s)
	g.set_meta("r", 0.8 * s)
	return g

static func pine(s: float) -> Node3D:
	var g := Node3D.new()
	add(g, cyl(0.2 * s, 0.3 * s, 1.0 * s, 8), toon(0x6b4430), Vector3(0, 0.5 * s, 0))
	for i in range(3):
		add(g, cone((1.5 - i * 0.35) * s, 1.6 * s, 14), toon(0x3f9a5a), Vector3(0, (1.3 + i * 0.9) * s, 0))
	g.set_meta("r", 1.4 * s)
	return g

static func rock(s: float) -> Node3D:
	var g := Node3D.new()
	add(g, sphere(1.0, 10), toon(0xa9a3b5), Vector3(0, s * 0.5, 0), Vector3.ZERO, Vector3(s, 0.7 * s, s))
	add(g, sphere(1.0, 8), toon(0xbdb7c8), Vector3(s * 0.8, s * 0.3, s * 0.3), Vector3.ZERO, Vector3.ONE * 0.55 * s)
	g.set_meta("r", s * 1.3)
	return g

static func lantern() -> Node3D:
	var g := Node3D.new()
	var stone := toon(0xc2bcc9)
	add(g, cyl(0.45, 0.55, 0.3, 6), stone, Vector3(0, 0.15, 0))
	add(g, cyl(0.18, 0.2, 1.1, 6), stone, Vector3(0, 0.85, 0))
	add(g, box(0.75, 0.6, 0.75), stone, Vector3(0, 1.7, 0))
	add(g, box(0.5, 0.35, 0.8), flat(0xffd27a), Vector3(0, 1.7, 0))
	add(g, cone(0.75, 0.5, 6), stone, Vector3(0, 2.25, 0))
	g.set_meta("r", 0.9)
	return g

## A coin bundle (rice sack tied with gold string) that a farm grows.
static func crop_bundle() -> Node3D:
	var g := Node3D.new()
	add(g, sphere(0.32, 12), toon(0xf3e4c0), Vector3(0, 0.3, 0), Vector3.ZERO, Vector3(1, 1.1, 1))
	add(g, torus(0.16, 0.05), toon(0xffc93c, 1.0, false), Vector3(0, 0.6, 0))
	add(g, cone(0.12, 0.2, 8), toon(0xf3e4c0), Vector3(0, 0.72, 0))
	add(g, cyl(0.16, 0.16, 0.05, 12), toon(0xffd34d), Vector3(0.18, 0.35, 0.26), Vector3(PI / 2, 0, 0))
	# Gold glow ring so bundles stand out on the grass
	var ring := add(g, torus(0.5, 0.06), fx_mat(Color(1.0, 0.85, 0.3, 0.8), true), Vector3(0, 0.05, 0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.scale = Vector3.ONE * 1.7
	return g

# ---------------------------------------------------------------------
# Ability effects. Each is built pointing up (+Y); the game aims and animates it.
# ---------------------------------------------------------------------
## A burning rock with a glowing shell and a long flame trail behind it (+Y).
static func meteor(scale: float = 1.0) -> Node3D:
	var g := Node3D.new()
	add(g, sphere(0.62, 10), toon(0x5a2a1c), Vector3.ZERO, Vector3(0.4, 0.7, 0.2), Vector3(1, 0.86, 1))
	for i in range(4):
		add(g, sphere(0.2, 6), flat(0xffc34a), Vector3(cos(i * 1.7) * 0.42, sin(i * 2.3) * 0.3, sin(i * 1.7) * 0.42))
	add(g, sphere(0.95, 14), fx_mat(Color(1.0, 0.5, 0.12, 0.5), true))
	add(g, cone(0.75, 4.6, 12), fx_mat(Color(1.0, 0.45, 0.1, 0.55), true), Vector3(0, 2.5, 0))
	add(g, cone(0.4, 6.4, 10), fx_mat(Color(1.0, 0.85, 0.4, 0.6), true), Vector3(0, 3.3, 0))
	g.scale = Vector3.ONE * scale
	for c in g.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return g

## A spear that falls point-first (the tip is at -Y).
static func spear() -> Node3D:
	var g := Node3D.new()
	add(g, cyl(0.05, 0.05, 2.2, 6), toon(0x8b5a2b, 1.0, false), Vector3(0, 1.1, 0))
	add(g, cone(0.16, 0.6, 8), flat(0xe8f4ff), Vector3(0, -0.2, 0), Vector3(PI, 0, 0))
	add(g, cone(0.3, 2.6, 8), fx_mat(Color(0.7, 0.9, 1.0, 0.35), true), Vector3(0, 1.6, 0))
	return g

## A heavy cannon shell with a smoke-orange tail.
static func shell() -> Node3D:
	var g := Node3D.new()
	add(g, capsule(0.3, 0.5), toon(0x39404d), Vector3.ZERO)
	add(g, cyl(0.31, 0.31, 0.12, 12), flat(0xffc93c), Vector3(0, 0.1, 0))
	add(g, cone(0.4, 3.0, 10), fx_mat(Color(1.0, 0.6, 0.2, 0.45), true), Vector3(0, 1.8, 0))
	return g

## A jagged lightning bolt from `height` down to the origin.
static func lightning(height: float, rng_seed: int, hex: int = 0xfff36b) -> Node3D:
	var g := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var core := fx_mat(Color(1, 1, 1, 0.95), true)
	var glow := fx_mat(Defs.col(hex, 0.55), true)
	var p := Vector3.ZERO
	var steps := 7
	for i in range(steps):
		var q := Vector3(rng.randf_range(-1.1, 1.1), height * (i + 1) / steps, rng.randf_range(-1.1, 1.1))
		if i == steps - 1:
			q.x *= 2.0
		var mid := (p + q) / 2.0
		var d := q - p
		var basis := Basis(Quaternion(Vector3.UP, d.normalized()))
		for pass_i in range(2):
			var w := 0.12 if pass_i == 0 else 0.42
			var seg := mi(cyl(1.0, 1.0, 1.0, 6), core if pass_i == 0 else glow)
			seg.transform = Transform3D(basis * Basis.from_scale(Vector3(w, d.length() * 1.04, w)), mid)
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			g.add_child(seg)
		p = q
	return g

## A glowing magic circle lying on the ground: two rings, spokes and rune dots.
static func rune_circle(radius: float, hex: int) -> Node3D:
	var g := Node3D.new()
	var m := fx_mat(Defs.col(hex, 0.85), true)
	add(g, torus(radius, 0.07), m)
	add(g, torus(radius * 0.62, 0.05), m)
	for i in range(6):
		var a := i * TAU / 6.0
		add(g, box(0.07, 0.03, radius * 1.24), m, Vector3.ZERO, Vector3(0, a, 0))
		add(g, sphere(0.16, 8), fx_mat(Color(1, 1, 1, 0.9), true), Vector3(cos(a) * radius * 0.81, 0.05, sin(a) * radius * 0.81))
	g.set_meta("mat", m)
	return g

static func projectile(kind: String) -> Node3D:
	var g := Node3D.new()
	var spin: Node3D = null
	match kind:
		"shuriken":
			spin = add(g, sphere(0.3, 4), toon(0xd0d4e0), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.22, 1))
		"arrow":
			add(g, box(0.12, 0.06, 0.8), flat(0xfff3c4))
			add(g, box(0.3, 0.02, 0.22), flat(0xe53935), Vector3(0, 0, -0.25))
		"fireball":
			add(g, sphere(0.34, 12), flat(0xff7b22))
			add(g, sphere(0.18, 8), flat(0xfff176), Vector3(0, 0, 0.12))
		"frag":
			add(g, sphere(0.16, 8), flat(0xffa726))
		"flash":
			spin = add(g, box(0.35, 0.05, 0.5), flat(0xfff59d))
		"wave":
			add(g, torus(0.9, 0.12), flat(0x9ff3ff, 0.85), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.45))
		"missile":
			add(g, cone(0.13, 0.5, 8), flat(0xff5252), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	if kind.begins_with("orb_"):
		# A glowing energy ball in any colour: "orb_" + hex, e.g. "orb_3fa9f5"
		var hex := kind.substr(4).hex_to_int()
		add(g, sphere(0.26, 12), flat(0xffffff))
		add(g, sphere(0.36, 12), fx_mat(Defs.col(hex, 0.85), true))
		spin = add(g, torus(0.42, 0.05), fx_mat(Defs.col(hex, 0.7), true), Vector3.ZERO, Vector3(0.5, 0, 0.3))
	if spin:
		g.set_meta("spin", spin)
	return g
