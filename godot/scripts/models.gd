# Builds every 3D model in the game out of primitive meshes.
# Toon shading comes from StandardMaterial3D's toon diffuse mode, and the
# anime ink outline is an inverted-hull "grow" pass chained via next_pass.
extends RefCounted

const Defs = preload("res://scripts/defs.gd")

const INK := Color(0.165, 0.094, 0.22)
const SKIN := 0xffe1cf

static var _mats := {}
static var _meshes := {}

# ---------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------
static func outline_mat(alpha: float = 1.0, grow: float = 0.035) -> StandardMaterial3D:
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
	var root := Node3D.new()
	add(root, cyl(0.95, 1.08, 0.36, 24), toon(o.get("base", 0xe8dcc8)), Vector3(0, 0.18, 0))
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color.WHITE
	var ring := add(root, torus(1.0, 0.08), ring_mat, Vector3(0, 0.36, 0))

	var body := Node3D.new()
	body.position.y = 0.36
	root.add_child(body)

	var outfit: int = o["outfit"]
	for s in [-1.0, 1.0]:
		add(body, cyl(0.13, 0.12, 0.45, 10), toon(o.get("legs", 0x2b2a3d)), Vector3(0.17 * s, 0.22, 0))
		add(body, sphere(0.15, 10), toon(o.get("shoes", 0x3a2b2b)), Vector3(0.17 * s, 0.04, 0.05), Vector3.ZERO, Vector3(1, 0.7, 1.4))
	if o.has("skirt"):
		add(body, cyl(0.36, 0.66, 0.52, 18), toon(o["skirt"]), Vector3(0, 0.52, 0))
	add(body, cyl(0.34, 0.48, 0.78, 16), toon(outfit), Vector3(0, 0.86, 0))
	if o.has("trim"):
		add(body, cyl(0.47, 0.47, 0.12, 16), toon(o["trim"], 1.0, false), Vector3(0, 0.62, 0))
		add(body, torus(0.3, 0.07), toon(o["trim"], 1.0, false), Vector3(0, 1.24, 0))

	var head := Node3D.new()
	head.position.y = 1.78
	body.add_child(head)
	add(head, sphere(0.6, 26), toon(SKIN))

	# Hair
	var hair := toon(o["hair"])
	add(head, sphere(0.67, 24, true), hair, Vector3(0, 0.05, 0), Vector3(-0.32, 0, 0))
	add(head, sphere(0.64, 20), hair, Vector3(0, -0.03, -0.17), Vector3.ZERO, Vector3(1.03, 1.0, 0.86))
	for i in range(-2, 3):
		var ai := absf(i)
		add(head, cone(0.17, 0.44, 6), hair, Vector3(i * 0.2, 0.32 - ai * 0.05, 0.5 - ai * 0.09), Vector3(PI - 0.4, 0, i * 0.22))
	for s in [-1.0, 1.0]:
		add(head, cone(0.15, 0.7, 6), hair, Vector3(0.55 * s, -0.18, 0.18), Vector3(PI - 0.1, 0, -0.12 * s))
	var accent: int = o.get("accent", 0xffffff)
	match o.get("style", ""):
		"ponytail":
			add(head, sphere(0.13, 10), toon(accent), Vector3(0, 0.25, -0.63))
			add(head, capsule(0.18, 0.75), hair, Vector3(0, -0.2, -0.85), Vector3(0.55, 0, 0))
		"long":
			add(head, capsule(0.42, 1.0), hair, Vector3(0, -0.72, -0.26), Vector3.ZERO, Vector3(1.18, 1, 0.55))
		"twintails":
			for s in [-1.0, 1.0]:
				add(head, sphere(0.14, 10), toon(accent), Vector3(0.62 * s, 0.28, -0.12))
				add(head, capsule(0.2, 0.95), hair, Vector3(0.82 * s, -0.42, -0.18), Vector3(0, 0, 0.28 * s))
		"buns":
			for s in [-1.0, 1.0]:
				add(head, sphere(0.26, 14), hair, Vector3(0.45 * s, 0.5, -0.1))
		"topknot":
			add(head, cyl(0.1, 0.16, 0.4, 10), hair, Vector3(0, 0.68, -0.25), Vector3(-0.6, 0, 0))
			add(head, sphere(0.16, 10), hair, Vector3(0, 0.82, -0.38))
		"spiky":
			for i in range(6):
				var a := -1.2 + i * 0.48
				add(head, cone(0.2, 0.6, 6), hair, Vector3(sin(a) * 0.45, 0.45, -0.3 - cos(a) * 0.15), Vector3(-0.7, 0, -sin(a) * 0.8))

	# Big anime eyes
	for s in [-1.0, 1.0]:
		add(head, sphere(0.13, 14), flat(o["eye"]), Vector3(0.22 * s, -0.05, 0.535), Vector3(0, 0.38 * s, 0), Vector3(0.85, 1.3, 0.4))
		add(head, sphere(0.075, 10), flat(0x1b0f24), Vector3(0.225 * s, -0.08, 0.565), Vector3(0, 0.38 * s, 0), Vector3(0.9, 1.3, 0.4))
		add(head, sphere(0.045, 8), flat(0xffffff), Vector3(0.25 * s + 0.02, 0.03, 0.585))
		add(head, box(0.26, 0.05, 0.05), flat(0x1b0f24), Vector3(0.23 * s, 0.13, 0.545), Vector3(0, 0.38 * s, -0.18 * s))
		add(head, sphere(0.09, 10), flat(0xff9ebd, 0.7), Vector3(0.36 * s, -0.22, 0.47), Vector3(0, 0.6 * s, 0), Vector3(1.2, 0.5, 0.3))
	add(head, sphere(0.05, 8), flat(0x9b2c48), Vector3(0, -0.29, 0.56), Vector3.ZERO, Vector3(1.2, 0.6, 0.4))

	# Arms. The right arm (-X) holds the weapon.
	var arms := []
	for s in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.47 * s, 1.15, 0)
		arm.rotation.z = 0.25 * s
		body.add_child(arm)
		add(arm, capsule(0.1, 0.32), toon(o.get("sleeve", outfit)), Vector3(0, -0.24, 0))
		add(arm, sphere(0.11, 10), toon(SKIN), Vector3(0, -0.48, 0))
		arms.append(arm)
	var rarm: Node3D = arms[0]
	rarm.rotation.x = -0.9
	var holder := Node3D.new()
	holder.position.y = -0.5
	holder.rotation.x = 0.9
	rarm.add_child(holder)
	return {"root": root, "body": body, "head": head, "rarm": rarm, "holder": holder, "ring": ring, "ring_mat": ring_mat}

static func build_hero(key: String) -> Dictionary:
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
	add(g, cone(4.3, 1.9, 4), toon(0x3a3d5c), Vector3(0, 3.9, 0), Vector3(0, PI / 4, 0), Vector3(1, 1, 0.85))
	add(g, sphere(0.35, 14), toon(0xffd34d), Vector3(0, 5.0, 0))
	return g

static func sakura(s: float, rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	add(g, cyl(0.22 * s, 0.35 * s, 2.2 * s, 8), toon(0x7a4b36), Vector3(0, 1.1 * s, 0))
	var cols := [0xffb7d5, 0xffc9e0, 0xff9fc7]
	for i in range(4):
		var r := (1.1 + rng.randf() * 0.4) * s
		add(g, sphere(r, 8), toon(cols[i % 3]), Vector3(cos(i * 2.1) * 0.8 * s, (2.5 + rng.randf() * 0.6) * s, sin(i * 2.1) * 0.8 * s))
	g.set_meta("r", 1.6 * s)
	return g

static func pine(s: float) -> Node3D:
	var g := Node3D.new()
	add(g, cyl(0.2 * s, 0.3 * s, 1.0 * s, 8), toon(0x6b4430), Vector3(0, 0.5 * s, 0))
	for i in range(3):
		add(g, cone((1.5 - i * 0.35) * s, 1.6 * s, 8), toon(0x3f9a5a), Vector3(0, (1.3 + i * 0.9) * s, 0))
	g.set_meta("r", 1.4 * s)
	return g

static func rock(s: float) -> Node3D:
	var g := Node3D.new()
	add(g, sphere(s, 6), toon(0xa9a3b5), Vector3(0, s * 0.5, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
	add(g, sphere(s * 0.55, 5), toon(0xbdb7c8), Vector3(s * 0.8, s * 0.3, s * 0.3))
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
	if spin:
		g.set_meta("spin", spin)
	return g
