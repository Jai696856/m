# Builds every 3D model in the game out of primitive meshes.
# Toon shading comes from StandardMaterial3D's toon diffuse mode, and the
# anime ink outline is an inverted-hull "grow" pass chained via next_pass.
extends RefCounted

const Defs = preload("res://scripts/defs.gd")

const Parts = preload("res://scripts/chibi_parts.gd")
const FoliageShader = preload("res://shaders/foliage.gdshader")
const RoofShader = preload("res://shaders/roof.gdshader")
const PortalShader = preload("res://shaders/portal.gdshader")

const INK := Color(0.165, 0.094, 0.22)
const SKIN := 0xffe4d2
## The hero rig is sunk by this much, so y = 0.36 in rig space is the ground (see make_chibi).
const BASE_DROP := 0.36

static var _mats := {}
static var _meshes := {}

# ---------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------
## Ink outline: an inverted hull drawn in a dark tint of the surface colour, so
## outlines stay soft instead of solid black.
static func outline_mat(base: Color, alpha: float = 1.0, grow: float = 0.022) -> StandardMaterial3D:
	var oc := INK.lerp(Color(base.r, base.g, base.b), 0.3).darkened(0.15)
	var key := "outline_%s_%s_%s" % [oc.to_html(false), alpha, grow]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_FRONT
	m.albedo_color = Color(oc, alpha)
	m.grow = true
	m.grow_amount = grow
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

## Character material: cel shading, soft rim light, tinted outline. Characters cast
## shadows but do not receive them, which keeps faces and outfits clean.
static func toon(hex: int, alpha: float = 1.0, outline: bool = true) -> StandardMaterial3D:
	var key := "toon_%x_%s_%s" % [hex, alpha, outline]
	if _mats.has(key):
		return _mats[key]
	var m := make_toon(Defs.col(hex, alpha), outline)
	_mats[key] = m
	return m

## Character material from a Color. `two_sided` is for open shells such as hair.
static func toon_c(c: Color, outline: bool = true, two_sided: bool = false) -> StandardMaterial3D:
	var key := "toonc_%s_%s_%s" % [c.to_html(), outline, two_sided]
	if _mats.has(key):
		return _mats[key]
	var m := make_toon(c, outline)
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m

## Unshaded material that takes its colour from the mesh's vertex colours (wisp faces).
static func face_mat(alpha: float = 1.0) -> StandardMaterial3D:
	var key := "facemat_%s" % alpha
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1, 1, 1, lerpf(alpha, 1.0, 0.5))
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m

## Scenery material: cel shading, no outline, receives shadows.
static func soft(hex: int, alpha: float = 1.0) -> StandardMaterial3D:
	var key := "soft_%x_%s" % [hex, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := make_toon(Defs.col(hex, alpha), false, true)
	_mats[key] = m
	return m

## Leaves: swaying toon material shared per colour (shaders/foliage.gdshader).
static func foliage(hex: int, sway: float = 0.06) -> ShaderMaterial:
	var key := "foliage_%x_%s" % [hex, sway]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = FoliageShader
	m.set_shader_parameter("albedo", Defs.col(hex))
	m.set_shader_parameter("sway", sway)
	_mats[key] = m
	return m

## Tiled roof material (shaders/roof.gdshader).
static func roof(hex: int, rows: float = 2.4) -> ShaderMaterial:
	var key := "roof_%x_%s" % [hex, rows]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = RoofShader
	m.set_shader_parameter("albedo", Defs.col(hex))
	m.set_shader_parameter("rows", rows)
	_mats[key] = m
	return m

static func make_toon(c: Color, outline: bool = true, receive_shadows: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	m.disable_receive_shadows = not receive_shadows
	if not receive_shadows:
		m.rim_enabled = true
		m.rim = 0.1
		m.rim_tint = 0.7
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if outline:
		m.next_pass = outline_mat(c, c.a)
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

## A tuft of three grass blades. Normals point up so blades are lit like the ground.
static func grass_tuft() -> ArrayMesh:
	var key := "grass_tuft"
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(3):
		var a := i * TAU / 3.0 + 0.4
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x) * 0.06
		var base := dir * 0.04
		var mid := dir * 0.12 + Vector3(0, 0.22, 0)
		var tip := dir * 0.25 + Vector3(0, 0.4 - i * 0.07, 0)
		for v in [base - side, base + side, mid + side * 0.7, base - side, mid + side * 0.7, mid - side * 0.7, mid - side * 0.7, mid + side * 0.7, tip]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh

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
	var mat := make_toon(Color.WHITE, outline, true)
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
#
# Options (only "outfit", "hair" and "eye" are required):
#   outfit, skirt, legs, shoes, sleeve, trim, accent: colours (0xRRGGBB)
#   hair: colour.  style: "ponytail" | "twintails" | "buns" | "topknot" | "spiky" | "long" | "short"
#   bangs: fringe shape, see Parts.hair_mesh ("zigzag", "straight", "swept", "parted", "spiky", "none")
#   length: "short" | "bob" | "long" (defaults from the style)
#   eyes, mouth, brow, male, blush: the drawn face, see Parts.face_texture
#   ahoge: a little antenna of hair on top
#
# Coordinates other code relies on: `body` has its feet at y = 0, belt near 0.62 and
# shoulders near 1.2; `head` is centred on the head (radius 0.6) with the face at +Z.
# ---------------------------------------------------------------------
const SKIRT_PROFILE := [Vector2(0.6, 0.3), Vector2(0.595, 0.36), Vector2(0.52, 0.5), Vector2(0.42, 0.66), Vector2(0.36, 0.78)]
const TOP_PROFILE := [Vector2(0.37, 0.66), Vector2(0.36, 0.8), Vector2(0.355, 0.98), Vector2(0.33, 1.12), Vector2(0.25, 1.22), Vector2(0.15, 1.28)]
const TUNIC_PROFILE := [Vector2(0.44, 0.44), Vector2(0.445, 0.5), Vector2(0.41, 0.64), Vector2(0.36, 0.8), Vector2(0.355, 0.98), Vector2(0.33, 1.12), Vector2(0.25, 1.22), Vector2(0.15, 1.28)]
const TAIL_PROFILE := [Vector2(0.0, 0.0), Vector2(0.15, 0.06), Vector2(0.21, 0.28), Vector2(0.18, 0.6), Vector2(0.1, 0.9), Vector2(0.0, 1.08)]

static func make_chibi(o: Dictionary) -> Dictionary:
	# `root` is what the game positions on the ground. Everything is built inside `rig`,
	# where y = 0.36 is ground level (an older version stood on a pedestal that tall).
	var root := Node3D.new()
	var rig := Node3D.new()
	rig.position.y = -BASE_DROP
	root.add_child(rig)
	var outfit_parts: Array = []
	# A thin ring on the ground shows the hero's upgrade tier; a faint plate lifts it off the grass
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color.WHITE
	var ring := add(rig, torus(0.84, 0.045), ring_mat, Vector3(0, 0.385, 0), Vector3.ZERO, Vector3(1, 0.3, 1))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plate := add(rig, cyl(0.82, 0.82, 0.01, 32), flat(0xffffff, 0.14), Vector3(0, 0.37, 0))
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var body := Node3D.new()
	body.position.y = 0.36
	rig.add_child(body)

	var outfit: int = o["outfit"]
	for s in [-1.0, 1.0]:
		add(body, capsule(0.115, 0.24), toon(o.get("legs", 0x2b2a3d)), Vector3(0.15 * s, 0.27, 0))
		add(body, sphere(0.15, 14), toon(o.get("shoes", 0x3a2b2b)), Vector3(0.15 * s, 0.07, 0.05), Vector3.ZERO, Vector3(1, 0.62, 1.38))
	if o.has("skirt"):
		outfit_parts.append(add(body, Parts.lathe("skirt", SKIRT_PROFILE, 28, true), toon(o["skirt"])))
		outfit_parts.append(add(body, Parts.lathe("top", TOP_PROFILE, 28), toon(outfit)))
	else:
		outfit_parts.append(add(body, Parts.lathe("tunic", TUNIC_PROFILE, 28, true), toon(outfit)))
	var skin: int = o.get("skin", SKIN)
	add(body, cyl(0.13, 0.15, 0.2, 12), toon(skin, 1.0, false), Vector3(0, 1.3, 0))
	if o.has("trim"):
		add(body, torus(0.365, 0.055), toon(o["trim"], 1.0, false), Vector3(0, 0.78, 0))
		add(body, torus(0.2, 0.06), toon(o["trim"], 1.0, false), Vector3(0, 1.27, 0))

	# Head: skin sphere with the drawn face on a patch just above it
	var head := Node3D.new()
	head.position.y = 1.78
	body.add_child(head)
	add(head, sphere(0.6, 32), toon(skin))
	var hair_col := Defs.col(o["hair"])
	var face_tex := Parts.face_texture({
		"skin": Defs.col(skin), "eye": Defs.col(o["eye"]), "hair": hair_col,
		"eyes": o.get("eyes", "round"), "mouth": o.get("mouth", "smile"), "brow": float(o.get("brow", 0.0)),
		"male": o.get("male", false), "blush": o.get("blush", true),
	})
	var fkey := "face_%d" % face_tex.get_instance_id()
	if not _mats.has(fkey):
		var fm := make_toon(Color.WHITE, false)
		fm.albedo_texture = face_tex
		_mats[fkey] = fm
	add(head, Parts.face_mesh(), _mats[fkey])

	# Hair: one shell with a shaped fringe, plus a band of shine across the crown
	var style: String = o.get("style", "")
	var bangs: String = o.get("bangs", "spiky" if style == "spiky" else ("parted" if style == "topknot" else "zigzag"))
	var length: String = o.get("length", "long" if style == "long" else "short")
	var hair := toon_c(hair_col, true, true)
	add(head, Parts.hair_mesh(bangs, length), hair)
	var shine := add(head, Parts.shine_mesh(), toon_c(hair_col.lerp(Color.WHITE, 0.28), false))
	shine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var accent: int = o.get("accent", 0xffffff)
	var tail := Parts.lathe("hairtail", TAIL_PROFILE, 16)
	match style:
		"ponytail":
			add(head, sphere(0.13, 12), toon(accent), Vector3(0, 0.3, -0.66))
			add(head, tail, hair, Vector3(0, 0.3, -0.68), Vector3(PI + 0.6, 0, 0), Vector3(1.0, 1.15, 1.0))
		"twintails":
			for s in [-1.0, 1.0]:
				add(head, sphere(0.14, 12), toon(accent), Vector3(0.64 * s, 0.3, -0.12))
				add(head, tail, hair, Vector3(0.66 * s, 0.3, -0.14), Vector3(PI + 0.12, 0, -0.26 * s), Vector3(0.8, 1.2, 0.8))
		"buns":
			for s in [-1.0, 1.0]:
				add(head, sphere(0.25, 18), hair, Vector3(0.47 * s, 0.52, -0.1))
		"topknot":
			add(head, cyl(0.1, 0.15, 0.36, 12), hair, Vector3(0, 0.72, -0.25), Vector3(-0.6, 0, 0))
			add(head, sphere(0.17, 12), hair, Vector3(0, 0.86, -0.38))
		"spiky":
			for i in range(5):
				var a := -1.0 + i * 0.5
				add(head, cone(0.2, 0.5, 10), hair, Vector3(sin(a) * 0.44, 0.56, -0.26 - cos(a) * 0.12), Vector3(-0.6, 0, -sin(a) * 0.8))
			for i in range(3):
				add(head, cone(0.18, 0.42, 10), hair, Vector3((i - 1) * 0.3, 0.22, -0.66), Vector3(-1.25, 0, (i - 1) * -0.3))
	if o.get("ahoge", false):
		add(head, tail, hair, Vector3(0.02, 0.62, 0.1), Vector3(0.5, 0, -0.35), Vector3(0.3, 0.42, 0.3))

	# Arms. The right arm (-X) holds the weapon.
	var arms := []
	for s in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(0.43 * s, 1.15, 0)
		arm.rotation.z = 0.25 * s
		body.add_child(arm)
		var sleeve: int = o.get("sleeve", outfit)
		outfit_parts.append(add(arm, capsule(0.1, 0.3), toon(skin if sleeve == SKIN else sleeve), Vector3(0, -0.24, 0)))
		add(arm, sphere(0.11, 12), toon(skin), Vector3(0, -0.47, 0))
		arms.append(arm)
	var rarm: Node3D = arms[0]
	rarm.rotation.x = -0.9
	var holder := Node3D.new()
	holder.position.y = -0.5
	holder.rotation = Vector3(0.9, 0, 0.32)   # upright, leaning away from the face
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
					add(head, torus(0.675, 0.05), toon(col), Vector3(0, 0.26, 0), Vector3(-0.15, 0, 0))
					add(head, box(0.08, 0.35, 0.05), toon(col), Vector3(0.15, 0.08, -0.69), Vector3(0.3, 0, 0.3))
				2:
					# A clear visor: tinted glass over the eyes with a bright top edge
					add(head, box(0.86, 0.2, 0.06), flat(0x7ff6ff, 0.3), Vector3(0, -0.06, 0.6))
					add(head, box(0.9, 0.035, 0.07), flat(0xd9fbff), Vector3(0, 0.05, 0.6))
				3:
					# A cape draped from the shoulders
					add(body, cyl(0.3, 0.6, 1.05, 18), toon(col), Vector3(0, 0.76, -0.33), Vector3(0.2, 0, 0), Vector3(1, 1, 0.24))
					add(body, torus(0.26, 0.07), toon(0xffd34d, 1.0, false), Vector3(0, 1.26, -0.04))
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
			var c := make_chibi({"outfit": 0x3d2f66, "legs": 0x231b38, "sleeve": 0x2d2350, "hair": 0x2a2545, "style": "ponytail", "bangs": "swept", "eye": 0xd81b60, "eyes": "sharp", "brow": 8.0, "mouth": "smile", "trim": 0x7e57c2, "accent": 0xff3d6e})
			# Scarf with a trailing end, and a forehead protector
			add(c.body, torus(0.27, 0.12), toon(0xff3d6e), Vector3(0, 1.27, 0))
			add(c.body, box(0.18, 0.06, 0.75), toon(0xff3d6e), Vector3(0.15, 1.2, -0.48), Vector3(0.5, 0, 0))
			add(c.head, torus(0.672, 0.045), toon(0x4a3f7a, 1.0, false), Vector3(0, 0.3, 0), Vector3(-0.2, 0, 0))
			add(c.head, box(0.32, 0.14, 0.05), toon(0xc8cbd6), Vector3(0, 0.36, 0.585), Vector3(-0.5, 0, 0))
			add(c.holder, sphere(0.22, 4), toon(0xc8cbd6), Vector3(0, 0, 0.1), Vector3.ZERO, Vector3(1, 0.25, 1))
			return c
		"miko":
			var c := make_chibi({"outfit": 0xfdfdfd, "skirt": 0xd62f3a, "legs": 0xfdfdfd, "hair": 0x241d3a, "style": "long", "bangs": "straight", "eye": 0x8e4bdb, "eyes": "gentle", "mouth": "smile", "trim": 0xd62f3a})
			# Big red ribbon at the back of the head
			add(c.head, sphere(0.14, 10), toon(0xd62f3a), Vector3(0, 0.3, -0.7))
			for s in [-1.0, 1.0]:
				add(c.head, cone(0.16, 0.36, 4), toon(0xd62f3a), Vector3(0.2 * s, 0.3, -0.72), Vector3(0, 0, -1.57 * s))
			# Bow: a ring stood up and squashed into a tall ellipse
			add(c.holder, torus(0.62, 0.045), toon(0x8b5a2b), Vector3(0, 0.1, 0.05), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.35))
			return c
		"mage":
			var c := make_chibi({"outfit": 0xc62828, "skirt": 0x2b1b2e, "legs": 0x2b1b2e, "hair": 0x7a4424, "style": "short", "length": "bob", "eye": 0xff7043, "eyes": "round", "mouth": "open", "trim": 0xffb300})
			add(c.head, cyl(1.0, 1.02, 0.08, 28), toon(0x2b1b2e), Vector3(0, 0.44, 0), Vector3(-0.12, 0, 0))
			add(c.head, cone(0.64, 1.4, 24), toon(0x2b1b2e), Vector3(0, 1.1, -0.12), Vector3(-0.28, 0, 0))
			add(c.head, cyl(0.62, 0.645, 0.14, 24), toon(0xc62828, 1.0, false), Vector3(0, 0.52, -0.02), Vector3(-0.15, 0, 0))
			add(c.head, sphere(0.09, 8), toon(0xffb300), Vector3(0, 0.56, 0.6))
			add(c.body, box(0.9, 0.9, 0.06), toon(0x8e0000), Vector3(0, 0.82, -0.42), Vector3(0.18, 0, 0))
			add(c.holder, cyl(0.05, 0.06, 1.8, 8), toon(0x6d4c41), Vector3(0, 0.3, 0))
			add(c.holder, sphere(0.2, 12), flat(0xff5a1f), Vector3(0, 1.32, 0))
			add(c.holder, sphere(0.3, 12), fx_mat(Defs.col(0xff7b22, 0.35), true), Vector3(0, 1.32, 0))
			add(c.holder, torus(0.25, 0.04), toon(0xffb300), Vector3(0, 1.32, 0), Vector3(PI / 2, 0, 0))
			return c
		"ice":
			var c := make_chibi({"outfit": 0x7fd3ff, "skirt": 0xd4f1ff, "legs": 0xffffff, "hair": 0xeaf3ff, "style": "long", "bangs": "parted", "eye": 0x2f8cff, "eyes": "gentle", "mouth": "flat", "brow": -3.0, "trim": 0xffffff, "sleeve": 0xd4f1ff})
			for i in range(-2, 3):
				add(c.head, cone(0.06, 0.24 - absf(i) * 0.04, 4), toon(0xffd34d, 1.0, false), Vector3(i * 0.13, 0.69 - absf(i) * 0.035, 0.26), Vector3(-0.4, 0, 0))
			add(c.holder, cyl(0.04, 0.04, 1.0, 6), toon(0xffffff), Vector3(0, 0.2, 0))
			for i in range(3):
				add(c.holder, box(0.4, 0.06, 0.06), flat(0x9ff3ff), Vector3(0, 0.74, 0), Vector3(0, 0, i * PI / 3))
			return c
		"samurai":
			var c := make_chibi({"outfit": 0x2a5bb8, "skirt": 0x1f2433, "legs": 0x1f2433, "hair": 0x1d1a26, "style": "topknot", "eye": 0x8b5a2b, "eyes": "sharp", "brow": 12.0, "mouth": "flat", "male": true, "blush": false, "trim": 0xffffff, "sleeve": 0x2a5bb8})
			add(c.holder, box(0.06, 1.5, 0.14), toon(0xe6ecf5), Vector3(0, 0.95, 0))
			add(c.holder, cyl(0.16, 0.16, 0.05, 10), toon(0xffc107, 1.0, false), Vector3(0, 0.2, 0))
			add(c.holder, cyl(0.05, 0.05, 0.4, 6), toon(0x1b1b1b), Vector3(0, 0, 0))
			add(c.body, box(0.08, 0.12, 1.2), toon(0x1b1b1b), Vector3(0.42, 0.62, -0.1), Vector3(0.4, 0, 0.3))
			return c
		"mecha":
			var c := make_chibi({"outfit": 0xff8f1f, "legs": 0x3a3a48, "hair": 0xff6fae, "style": "buns", "eye": 0x00c8ff, "eyes": "round", "mouth": "grin", "trim": 0x3a3a48, "sleeve": 0x3a3a48})
			# Goggles pushed up into her hair, an arm cannon and a power pack
			for s in [-1.0, 1.0]:
				add(c.head, torus(0.13, 0.05), toon(0x3a3a48), Vector3(0.19 * s, 0.45, 0.5), Vector3(PI / 2 - 0.7, 0, 0))
				add(c.head, cyl(0.1, 0.1, 0.02, 14), flat(0x7ff6ff), Vector3(0.19 * s, 0.45, 0.52), Vector3(PI / 2 - 0.7, 0, 0))
			add(c.holder, cyl(0.2, 0.26, 1.0, 14), toon(0x6b7385), Vector3(0, 0, 0.35), Vector3(PI / 2, 0, 0))
			add(c.holder, torus(0.2, 0.05), flat(0x00e5ff), Vector3(0, 0, 0.86), Vector3(PI / 2, 0, 0))
			add(c.body, box(0.62, 0.62, 0.3), toon(0x6b7385), Vector3(0, 1.0, -0.42))
			return c
		"kaito":
			var c := make_chibi({"outfit": 0xc62828, "legs": 0x2b3a6b, "hair": 0x2b2a3d, "style": "spiky", "eye": 0x2b3a6b, "eyes": "sharp", "brow": 6.0, "mouth": "grin", "male": true, "trim": 0xffd34d, "sleeve": 0xf5f0e6, "skin": 0xe9bd92})
			# Captain's tricorn hat
			add(c.head, cyl(0.84, 0.9, 0.12, 3), toon(0x1f1f2b), Vector3(0, 0.58, 0), Vector3(-0.1, PI, 0))
			add(c.head, cyl(0.52, 0.62, 0.45, 14), toon(0x1f1f2b), Vector3(0, 0.8, -0.05))
			add(c.head, sphere(0.1, 8), toon(0xffd34d), Vector3(0, 0.84, 0.57))
			add(c.body, box(0.12, 0.85, 0.1), toon(0xffd34d), Vector3(-0.18, 0.94, 0.33), Vector3(0, 0, 0.6))
			add(c.holder, box(0.07, 1.2, 0.18), toon(0xe6ecf5), Vector3(0, 0.75, 0), Vector3(0, 0, 0.15))
			add(c.holder, torus(0.16, 0.04), toon(0xffd34d), Vector3(0, 0.12, 0))
			add(c.body, cyl(0.06, 0.06, 0.5, 8), toon(0x6b4a2a), Vector3(0.46, 0.72, 0.16), Vector3(PI / 2, 0, 0))
			return c
		"rei":
			var c := make_chibi({"outfit": 0xff9a26, "legs": 0x2f4f9e, "hair": 0x23232f, "style": "spiky", "eye": 0x3a3a55, "eyes": "sharp", "brow": 14.0, "mouth": "grin", "male": true, "blush": false, "trim": 0x2f4f9e, "sleeve": SKIN, "skin": 0xf6cfa8})
			for i in range(4):
				add(c.head, cone(0.17, 0.6, 8), toon(0x23232f), Vector3(-0.3 + i * 0.2, 0.68, -0.08), Vector3(-0.3, 0, (i - 1.5) * 0.35))
			add(c.holder, sphere(0.26, 12), flat(0xffe27a), Vector3(0, 0.05, 0.2))
			add(c.holder, sphere(0.42, 12), fx_mat(Defs.col(0xff9a26, 0.4), true), Vector3(0, 0.05, 0.2))
			return c
		"ichika":
			var c := make_chibi({"outfit": 0x1f1f2b, "skirt": 0x1f1f2b, "legs": 0x1f1f2b, "hair": 0xe9e4f0, "style": "ponytail", "bangs": "straight", "eye": 0xd81b60, "eyes": "sharp", "mouth": "flat", "trim": 0xd81b60, "accent": 0xd81b60})
			add(c.body, box(0.9, 0.1, 0.46), toon(0x2b2a3d), Vector3(0, 1.22, 0))
			for i in range(3):
				add(c.body, box(0.16, 0.3, 0.02), flat(0xfff3c4), Vector3(-0.28 + i * 0.28, 0.98, 0.37), Vector3(-0.08, 0, (i - 1) * 0.25))
			add(c.holder, box(0.22, 0.36, 0.02), flat(0xfff3c4), Vector3(0, 0.15, 0.08))
			add(c.holder, box(0.12, 0.04, 0.03), flat(0xd81b60), Vector3(0, 0.2, 0.1))
			add(c.rig, torus(1.1, 0.035), flat(0xd81b60, 0.8), Vector3(0, 0.39, 0))
			return c
		"gen":
			var c := make_chibi({"outfit": 0x2e7d6b, "legs": 0x2b2a3d, "hair": 0x3f9a45, "style": "short", "bangs": "swept", "eye": 0xffd34d, "eyes": "round", "mouth": "grin", "male": true, "trim": 0xffd34d, "sleeve": 0x2e7d6b, "ahoge": true})
			for s in [-1.0, 1.0]:
				add(c.head, torus(0.13, 0.05), toon(0x4a4a55), Vector3(0.19 * s, 0.45, 0.5), Vector3(PI / 2 - 0.7, 0, 0))
				add(c.head, cyl(0.1, 0.1, 0.02, 14), flat(0xffd34d, 0.8), Vector3(0.19 * s, 0.45, 0.52), Vector3(PI / 2 - 0.7, 0, 0))
			add(c.body, box(0.66, 0.66, 0.34), toon(0x4a4a55), Vector3(0, 1.0, -0.43))
			add(c.body, cyl(0.03, 0.03, 0.7, 6), toon(0x9aa7b4), Vector3(0.22, 1.55, -0.43))
			add(c.body, sphere(0.07, 8), flat(0xff5a3c), Vector3(0.22, 1.92, -0.43))
			add(c.holder, sphere(0.16, 10), toon(0x3a8a3a), Vector3(0, 0.05, 0.05))
			add(c.holder, cyl(0.05, 0.05, 0.12, 6), toon(0x9aa7b4), Vector3(0, 0.22, 0.05))
			return c
		"lumi":
			var c := make_chibi({"outfit": 0xffffff, "skirt": 0x7fb6ff, "legs": 0xffffff, "hair": 0xffd34d, "style": "twintails", "eye": 0x2f8cff, "eyes": "round", "mouth": "open", "trim": 0xff6fae, "accent": 0xff6fae, "sleeve": 0xffffff, "ahoge": true})
			add(c.body, sphere(0.15, 10), toon(0xff6fae), Vector3(0, 1.1, 0.36), Vector3.ZERO, Vector3(1.6, 0.8, 0.6))
			add(c.head, sphere(0.12, 4), toon(0xfff3a0), Vector3(0, 0.66, 0.3), Vector3.ZERO, Vector3(1.4, 1.4, 0.5))
			add(c.holder, cyl(0.04, 0.04, 0.9, 6), toon(0xff6fae), Vector3(0, 0.25, 0))
			add(c.holder, sphere(0.2, 4), flat(0xffd34d), Vector3(0, 0.8, 0), Vector3.ZERO, Vector3(1.2, 1.2, 0.5))
			add(c.holder, torus(0.25, 0.03), flat(0xff6fae), Vector3(0, 0.8, 0), Vector3(PI / 2, 0, 0))
			return c
		"ren":
			var c := make_chibi({"outfit": 0xf5f5f5, "legs": 0x2b2a3d, "hair": 0xd9452b, "style": "spiky", "eye": 0xffb02e, "eyes": "sharp", "brow": 12.0, "mouth": "grin", "male": true, "trim": 0x2b2a3d, "sleeve": SKIN, "accent": 0xffffff, "skin": 0xf6cfa8})
			# Headband with trailing ends, and red boxing gloves
			add(c.head, torus(0.675, 0.05), toon(0xf5f5f5, 1.0, false), Vector3(0, 0.3, 0), Vector3(-0.18, 0, 0))
			for s in [-1.0, 1.0]:
				add(c.head, box(0.07, 0.4, 0.03), toon(0xf5f5f5, 1.0, false), Vector3(0.08 * s, 0.1, -0.72), Vector3(0.35, 0, 0.25 * s))
			add(c.holder, sphere(0.19, 12), toon(0xd9452b), Vector3(0, 0.0, 0.05))
			add(c.larm, sphere(0.19, 12), toon(0xd9452b), Vector3(0, -0.5, 0.02))
			return c
		"kenta":
			var c := make_chibi({"outfit": 0x6b8f3a, "legs": 0x4a3a2a, "hair": 0x4a3320, "style": "short", "bangs": "swept", "eye": 0x4a8a3a, "eyes": "round", "mouth": "smile", "male": true, "trim": 0x8a6a3a, "sleeve": 0x6b8f3a})
			add(c.holder, cyl(0.04, 0.04, 2.0, 6), toon(0x8b5a2b), Vector3(0, 0.5, 0))
			add(c.holder, cone(0.1, 0.35, 6), toon(0xd0d4e0), Vector3(0, 1.65, 0))
			add(c.body, box(0.46, 0.56, 0.16), toon(0x8a6a3a), Vector3(0, 0.98, -0.4))
			for i in range(3):
				add(c.body, cyl(0.025, 0.025, 1.0, 5), toon(0x8b5a2b), Vector3(-0.12 + i * 0.12, 1.36, -0.43), Vector3(0.2, 0, 0))
				add(c.body, cone(0.05, 0.14, 5), toon(0xd0d4e0), Vector3(-0.12 + i * 0.12, 1.9, -0.54), Vector3(0.2, 0, 0))
			return c
		"saya":
			var c := make_chibi({"outfit": 0x3a4a6b, "skirt": 0x2b2a3d, "legs": 0x2b2a3d, "hair": 0xf2c14e, "style": "ponytail", "bangs": "swept", "eye": 0x2f8cff, "eyes": "sharp", "mouth": "grin", "brow": 6.0, "trim": 0xffb02e, "accent": 0xffb02e})
			# Officer's cap
			add(c.head, cyl(0.6, 0.66, 0.3, 20), toon(0x2b2a3d), Vector3(0, 0.66, -0.04), Vector3(-0.12, 0, 0))
			add(c.head, cyl(0.7, 0.7, 0.06, 20), toon(0x2b2a3d), Vector3(0, 0.82, -0.06), Vector3(-0.12, 0, 0))
			add(c.head, box(0.6, 0.05, 0.3), toon(0x1b1a26), Vector3(0, 0.5, 0.62), Vector3(-0.3, 0, 0))
			add(c.head, sphere(0.08, 8), toon(0xffb02e), Vector3(0, 0.68, 0.6))
			var cannon := Node3D.new()
			cannon.position = Vector3(0.7, 0.55, 0.3)
			c.body.add_child(cannon)
			add(cannon, cyl(0.22, 0.28, 1.1, 16), toon(0x4a4a55), Vector3(0, 0.25, 0.2), Vector3(PI / 2 - 0.5, 0, 0))
			add(cannon, torus(0.24, 0.05), toon(0x2b2a3d), Vector3(0, 0.5, 0.66), Vector3(PI - 0.5, 0, 0))
			add(cannon, cyl(0.3, 0.3, 0.12, 14), toon(0x8b5a2b), Vector3(0.0, -0.1, 0), Vector3(0, 0, PI / 2))
			return c
		"sora":
			var c := make_chibi({"outfit": 0x2f4f9e, "skirt": 0xfdfdfd, "legs": 0xfdfdfd, "hair": 0x7fb6ff, "style": "long", "eye": 0xfff36b, "eyes": "gentle", "mouth": "smile", "trim": 0xfff36b, "sleeve": 0xfdfdfd})
			for i in range(3):
				add(c.head, cone(0.06, 0.3, 4), flat(0xfff36b), Vector3(-0.2 + i * 0.2, 0.76, 0.2), Vector3(-0.3, 0, (i - 1) * 0.4))
			add(c.holder, cyl(0.04, 0.04, 1.2, 6), toon(0xfdfdfd), Vector3(0, 0.3, 0))
			for i in range(3):
				add(c.holder, box(0.08, 0.25, 0.05), flat(0xfff36b), Vector3((i - 1) * 0.12, 0.98 + i * 0.05, 0), Vector3(0, 0, (i - 1) * 0.6))
			# A little storm cloud that follows her
			for i in range(3):
				add(c.body, sphere(0.34, 12), toon(0xe6edff, 1.0, false), Vector3(-0.45 + i * 0.3, 2.95 + (0.12 if i == 1 else 0.0), -0.2), Vector3.ZERO, Vector3(1.0, 0.8, 0.9))
			return c
		"riku":
			var c := make_chibi({"outfit": 0x2e7d6b, "legs": 0x2b2a3d, "hair": 0x2f2d42, "style": "short", "bangs": "swept", "eye": 0x4fd8e6, "eyes": "round", "mouth": "smile", "male": true, "trim": 0xffb02e, "sleeve": 0x2b2a3d, "skin": 0xc8946a})
			# Headset with a cyan visor pushed up on the forehead
			add(c.head, box(0.74, 0.13, 0.08), flat(0x7ff6ff, 0.85), Vector3(0, 0.36, 0.58), Vector3(-0.45, 0, 0))
			add(c.head, torus(0.675, 0.04), toon(0x4a4a55, 1.0, false), Vector3(0, 0.3, 0), Vector3(-0.2, 0, 0))
			for s in [-1.0, 1.0]:
				add(c.head, cyl(0.14, 0.14, 0.1, 12), toon(0x4a4a55), Vector3(0.68 * s, -0.02, 0), Vector3(0, 0, PI / 2))
			add(c.holder, box(0.35, 0.22, 0.12), toon(0x4a4a55), Vector3(0, 0.0, 0.05))
			var drone := Node3D.new()
			drone.position = Vector3(0, 3.1, 0)
			c.rig.add_child(drone)
			add(drone, sphere(0.24, 12), toon(0x4a4a55), Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.6, 1.1))
			for dx in [-1.0, 1.0]:
				for dz in [-1.0, 1.0]:
					add(drone, box(0.34, 0.04, 0.06), toon(0x4a4a55, 1.0, false), Vector3(dx * 0.26, 0.02, dz * 0.26), Vector3(0, dx * dz * 0.78, 0))
					add(drone, cyl(0.2, 0.2, 0.02, 12), flat(0xd0d4e0, 0.6), Vector3(dx * 0.4, 0.08, dz * 0.4))
			add(drone, sphere(0.07, 6), flat(0xff5a3c), Vector3(0, -0.06, 0.24))
			c["spinners"].append(drone)
			return c
		"hina":
			var c := make_chibi({"outfit": 0xffb02e, "legs": 0x4a4a55, "hair": 0x9a6540, "style": "twintails", "eye": 0x2e9d7b, "eyes": "round", "mouth": "cat", "trim": 0x4a4a55, "accent": 0x4a4a55, "sleeve": 0x4a4a55, "skin": 0xd9a57c})
			add(c.head, torus(0.2, 0.05), toon(0x4a4a55), Vector3(0.3, 0.5, 0.42), Vector3(PI / 2 - 0.55, 0.3, 0))
			add(c.holder, box(0.08, 0.5, 0.08), toon(0x9aa7b4), Vector3(0, 0.2, 0.05), Vector3(0, 0, 0.6))
			add(c.holder, torus(0.1, 0.035), toon(0x9aa7b4), Vector3(-0.15, 0.42, 0.05), Vector3(PI / 2, 0, 0))
			var turret := Node3D.new()
			turret.position = Vector3(0.95, 0.36, 0.25)
			c.rig.add_child(turret)
			add(turret, cyl(0.25, 0.32, 0.5, 12), toon(0x4a4a55), Vector3(0, 0.25, 0))
			add(turret, chamfer_box(0.12), toon(0xffb02e), Vector3(0, 0.62, 0), Vector3.ZERO, Vector3(0.38, 0.3, 0.46))
			add(turret, cyl(0.06, 0.06, 0.6, 8), toon(0x2b2a3d), Vector3(0, 0.64, 0.45), Vector3(PI / 2, 0, 0))
			add(turret, sphere(0.05, 6), flat(0x7ff6ff), Vector3(0.12, 0.72, 0.24))
			return c
		"hiro":
			var c := make_chibi({"outfit": 0x7a3b8f, "skirt": 0x4a2a55, "legs": 0x4a2a55, "hair": 0x2b2a3d, "style": "short", "bangs": "parted", "eye": 0xffd34d, "eyes": "closed", "mouth": "grin", "male": true, "trim": 0xffd34d, "sleeve": 0x7a3b8f})
			add(c.head, cyl(0.74, 0.8, 0.08, 20), toon(0xd9b36a), Vector3(0, 0.6, 0))
			add(c.head, cone(0.56, 0.5, 20), toon(0xd9b36a), Vector3(0, 0.86, 0))
			add(c.holder, sphere(0.22, 12), toon(0x9b6a3a), Vector3(0, 0.05, 0.05), Vector3.ZERO, Vector3(1, 1.2, 1))
			add(c.holder, torus(0.1, 0.03), toon(0xffd34d, 1.0, false), Vector3(0, 0.26, 0.05))
			for i in range(3):
				add(c.rig, cyl(0.16, 0.16, 0.06, 14), toon(0xffd34d), Vector3(0.8, 0.4 + i * 0.07, 0.4))
			add(c.rig, chamfer_box(0.06), toon(0x9b6a3a), Vector3(-0.85, 0.6, 0.3), Vector3.ZERO, Vector3(0.7, 0.5, 0.5))
			return c
		"nao":
			var c := make_chibi({"outfit": 0xfdfdfd, "skirt": 0x7fd3a0, "legs": 0xfdfdfd, "hair": 0x4a9a7b, "style": "long", "bangs": "straight", "eye": 0x3a8a6b, "eyes": "closed", "mouth": "smile", "trim": 0x7fd3a0, "sleeve": 0xfdfdfd})
			add(c.head, torus(0.2, 0.045), flat(0xfff3a0), Vector3(0, 0.62, -0.42), Vector3(PI / 2 - 0.5, 0, 0))
			add(c.holder, cyl(0.035, 0.035, 0.9, 6), toon(0x8b5a2b), Vector3(0, 0.2, 0))
			add(c.holder, cone(0.18, 0.3, 10), toon(0xffd34d), Vector3(0, 0.75, 0), Vector3(PI, 0, 0))
			add(c.holder, sphere(0.06, 6), toon(0xffd34d), Vector3(0, 0.55, 0))
			return c
		"komugi":
			var c := make_chibi({"outfit": 0x6fae4f, "skirt": 0x3c6e9f, "legs": 0xfdf6e3, "hair": 0x8a5630, "style": "twintails", "eye": 0x7a4a24, "eyes": "round", "mouth": "open", "trim": 0xf2d16b, "sleeve": 0xfdf6e3, "accent": 0xc0392b, "skin": 0xf8d6b4})
			# Straw hat
			add(c.head, cyl(0.98, 1.02, 0.07, 24), toon(0xe9c46a), Vector3(0, 0.5, 0))
			add(c.head, cone(0.56, 0.42, 20), toon(0xe9c46a), Vector3(0, 0.72, 0))
			add(c.head, torus(0.54, 0.05), toon(0xc0392b, 1.0, false), Vector3(0, 0.55, 0))
			# Hoe
			add(c.holder, cyl(0.04, 0.04, 1.1, 6), toon(0x8b5a2b), Vector3(0, 0.25, 0))
			add(c.holder, box(0.42, 0.06, 0.12), toon(0xb8c2cc), Vector3(0.15, 0.8, 0))
			# Rice paddy around her feet, with sprouts
			add(c.rig, cyl(0.86, 0.86, 0.03, 24), toon(0x5aa7c8, 1.0, false), Vector3(0, 0.375, 0))
			for i in range(10):
				var a := i / 10.0 * TAU
				var sp := add(c.rig, cone(0.06, 0.36, 5), toon(0x7ccf52, 1.0, false), Vector3(cos(a) * 0.72, 0.54, sin(a) * 0.72))
				sp.rotation.z = sin(a * 3.0) * 0.25
			# Sack of rice
			add(c.rig, sphere(0.26, 12), toon(0xf3e4c0), Vector3(-0.72, 0.6, 0.45), Vector3.ZERO, Vector3(1, 1.15, 1))
			return c
		_:
			var c := make_chibi({"outfit": 0xff7ac8, "skirt": 0xffffff, "legs": 0xffffff, "hair": 0x9b6bff, "style": "twintails", "eye": 0xff3d8b, "eyes": "wink", "mouth": "open", "trim": 0xffd34d, "accent": 0xffd34d})
			add(c.head, sphere(0.16, 4), toon(0xffd34d), Vector3(0.4, 0.5, 0.4))
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
		var is_mask: bool = d.get("mask", false)
		if is_mask or d.get("lantern", false):
			add(g, sphere(s, 24), body_mat, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.95, 1))
		else:
			# A drop of spirit: round body, pointed tip curling back
			add(g, Parts.teardrop(), body_mat, Vector3.ZERO, Vector3.ZERO, Vector3(s, s * 0.95, s))
		if is_mask:
			for x in [-1.0, 1.0]:
				add(g, cone(0.13, 0.44, 10), toon(0xfff4d6, alpha), Vector3(0.4 * x, s * 0.84, 0), Vector3(0, 0, -0.35 * x))
			add(g, sphere(0.11, 8), flat(0xff3d6e), Vector3(0, 0.46, s * 0.9), Vector3.ZERO, Vector3(1, 1, 0.5))
		if d.get("fox", false):
			for x in [-1.0, 1.0]:
				add(g, cone(s * 0.28, s * 0.7, 10), body_mat, Vector3(s * 0.52 * x, s * 0.8, 0), Vector3(0, 0, -0.35 * x))
				add(g, cone(s * 0.14, s * 0.4, 8), toon(0xffffff, alpha, false), Vector3(s * 0.54 * x, s * 0.82, s * 0.08), Vector3(0, 0, -0.35 * x))
			for i in range(3):
				add(g, capsule(s * 0.22, s * 0.9), body_mat, Vector3((i - 1) * s * 0.4, s * 0.1, -s * 1.0), Vector3(-0.9, (i - 1) * 0.5, 0))
				add(g, sphere(s * 0.2, 10), toon(0xffffff, alpha, false), Vector3((i - 1) * s * 0.55, s * 0.6, -s * 1.45))
		if d.get("crane", false):
			for x in [-1.0, 1.0]:
				add(g, box(s * 1.6, 0.05, s * 0.8), toon(0xf4f1ea, alpha), Vector3(s * 1.1 * x, s * 0.3, 0), Vector3(0, 0, 0.35 * x))
				add(g, box(s * 0.6, 0.06, s * 0.82), toon(0xe63946, alpha, false), Vector3(s * 1.72 * x, s * 0.52, 0), Vector3(0, 0, 0.35 * x))
			add(g, cone(s * 0.18, s * 0.7, 4), toon(0xffc93c, alpha), Vector3(0, -s * 0.05, s * 1.1), Vector3(PI / 2, 0, 0))
		if d.get("lantern", false):
			add(g, cyl(s * 0.5, s * 0.5, 0.12, 16), toon(0x3b2a1a), Vector3(0, s * 0.96, 0))
			add(g, cyl(s * 0.5, s * 0.5, 0.12, 16), toon(0x3b2a1a), Vector3(0, -s * 0.9, 0))
			add(g, torus(s * 0.22, 0.03), toon(0x3b2a1a, 1.0, false), Vector3(0, s * 1.14, 0), Vector3(PI / 2, 0, 0))
			for i in range(3):
				add(g, torus(s * (0.985 if i == 1 else 0.9), 0.028), toon(0xc0392b, alpha, false), Vector3(0, (i - 1) * s * 0.42, 0))
			var glow := add(g, sphere(s * 1.25, 12), fx_mat(Color(1.0, 0.7, 0.3, 0.18), true))
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var face := add(g, Parts.wisp_face("mask" if is_mask else ("shadow" if k == "shadow" else "wisp")), face_mat(alpha), Vector3.ZERO, Vector3.ZERO, Vector3(s, s * 0.95, s))
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if camo:
		for i in range(3):
			add(g, sphere(s * 0.22, 6), flat(0x3b7d3b, 0.7), Vector3(cos(i * 2.1) * s * 0.75, s * 0.4, sin(i * 2.1) * s * 0.75), Vector3.ZERO, Vector3(1, 0.3, 0.6))
	return g

# ---------------------------------------------------------------------
# Scenery. Nothing here has ink outlines; leaves use the swaying foliage material.
# ---------------------------------------------------------------------
static func torii() -> Node3D:
	var g := Node3D.new()
	var red := soft(0xe5463f)
	var black := soft(0x2b2730)
	for x in [-2.5, 2.5]:
		add(g, cyl(0.24, 0.3, 4.5, 16), red, Vector3(x, 2.25, 0))
		add(g, cyl(0.4, 0.44, 0.45, 16), black, Vector3(x, 0.22, 0))
		add(g, cyl(0.3, 0.3, 0.14, 16), black, Vector3(x, 4.42, 0))
	# Top beam with upturned ends, a red beam under it, a tie beam and a centre tablet
	add(g, box(6.4, 0.34, 0.62), black, Vector3(0, 4.92, 0))
	for x in [-1.0, 1.0]:
		add(g, box(1.1, 0.34, 0.62), black, Vector3(3.6 * x, 5.02, 0), Vector3(0, 0, 0.2 * x))
	add(g, box(6.6, 0.3, 0.5), red, Vector3(0, 4.62, 0))
	add(g, box(6.0, 0.28, 0.36), red, Vector3(0, 3.6, 0))
	add(g, box(0.55, 0.72, 0.16), black, Vector3(0, 4.1, 0))
	add(g, box(0.4, 0.56, 0.18), soft(0xffd34d), Vector3(0, 4.1, 0))
	return g

static func shrine() -> Node3D:
	var g := Node3D.new()
	var stone := soft(0xb9b2a6)
	var red := soft(0xd9453d)
	var roof_mat := roof(0x3f6f8f, 3.2)
	var gold := soft(0xffcf4a)
	# Two stone steps and a platform
	add(g, chamfer_box(0.06), stone, Vector3(0, 0.15, 0), Vector3.ZERO, Vector3(5.8, 0.3, 5.0))
	add(g, chamfer_box(0.08), soft(0xc7c0b3), Vector3(0, 0.45, 0), Vector3.ZERO, Vector3(5.0, 0.36, 4.2))
	add(g, box(1.6, 0.2, 0.7), stone, Vector3(0, 0.1, 2.75))
	# Hall: paper walls, red corner pillars, lattice doors
	add(g, box(3.5, 2.1, 2.8), soft(0xfff3df), Vector3(0, 1.68, 0))
	for p in [Vector2(-1.85, -1.5), Vector2(1.85, -1.5), Vector2(-1.85, 1.5), Vector2(1.85, 1.5)]:
		add(g, cyl(0.17, 0.2, 2.3, 12), red, Vector3(p.x, 1.78, p.y))
	add(g, box(3.9, 0.22, 3.2), red, Vector3(0, 2.84, 0))
	add(g, box(1.5, 1.5, 0.08), soft(0x7a4a2c), Vector3(0, 1.4, 1.42))
	for x in [-0.5, 0.0, 0.5]:
		add(g, box(0.06, 1.5, 0.1), soft(0x4f2f1c), Vector3(x, 1.4, 1.44))
	for y in [1.0, 1.5, 2.0]:
		add(g, box(1.5, 0.06, 0.1), soft(0x4f2f1c), Vector3(0, y, 1.44))
	# Offering box and rope bell
	add(g, box(1.0, 0.45, 0.5), soft(0x8a5a36), Vector3(0, 0.86, 2.0))
	add(g, sphere(0.16, 10), gold, Vector3(0, 2.45, 1.75))
	# Two-tier roof with a gold finial
	add(g, cone(4.5, 1.25, 4), roof_mat, Vector3(0, 3.55, 0), Vector3(0, PI / 4, 0), Vector3(1, 1, 0.86))
	add(g, cone(4.75, 0.2, 4), soft(0x2f5670), Vector3(0, 3.02, 0), Vector3(0, PI / 4, 0), Vector3(1, 1, 0.86))
	add(g, box(2.0, 0.5, 1.6), soft(0xfff3df), Vector3(0, 4.1, 0))
	add(g, cone(2.5, 1.15, 4), roof_mat, Vector3(0, 4.85, 0), Vector3(0, PI / 4, 0), Vector3(1, 1, 0.86))
	add(g, cyl(0.1, 0.14, 0.5, 8), gold, Vector3(0, 5.55, 0))
	add(g, sphere(0.26, 14), gold, Vector3(0, 5.9, 0))
	return g

## The spirit portal: a stone ring around a glowing vortex. `g.get_meta("disc")` spins.
static func portal() -> Node3D:
	var g := Node3D.new()
	add(g, torus(2.5, 0.36), soft(0x6a4f9a), Vector3(0, 2.6, 0), Vector3(PI / 2, 0, 0))
	add(g, torus(2.5, 0.2), soft(0x8f76c4), Vector3(0, 2.6, 0.12), Vector3(PI / 2, 0, 0))
	for i in range(8):
		var a := i * TAU / 8.0 + 0.2
		add(g, sphere(0.14, 8), flat(0xe6d4ff), Vector3(cos(a) * 2.5, 2.6 + sin(a) * 2.5, 0.32))
	for x in [-1.0, 1.0]:
		add(g, chamfer_box(0.1), soft(0x5a4486), Vector3(2.3 * x, 0.35, 0), Vector3.ZERO, Vector3(1.3, 0.7, 1.2))
	var quad := QuadMesh.new()
	quad.size = Vector2(4.7, 4.7)
	var pm := ShaderMaterial.new()
	pm.shader = PortalShader
	var disc := add(g, quad, pm, Vector3(0, 2.6, 0))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.set_meta("disc", disc)
	return g

## Leafy canopy made of a few big overlapping balls: darker lobes low, lighter on top.
static func _canopy(g: Node3D, s: float, rng: RandomNumberGenerator, cols: Array, y: float) -> void:
	add(g, sphere(1.0, 18), foliage(cols[1]), Vector3(0, y * s, 0), Vector3.ZERO, Vector3(1.32, 1.14, 1.32) * s)
	var a0 := rng.randf() * TAU
	for i in range(3):
		var a := a0 + i * TAU / 3.0 + rng.randf_range(-0.25, 0.25)
		var r := rng.randf_range(0.82, 1.0) * s
		add(g, sphere(1.0, 16), foliage(cols[0]), Vector3(cos(a) * 0.95 * s, (y - 0.42 + rng.randf() * 0.2) * s, sin(a) * 0.95 * s), Vector3.ZERO, Vector3(r, r * 0.88, r))
	var ta := a0 + 0.9
	add(g, sphere(1.0, 16), foliage(cols[2]), Vector3(cos(ta) * 0.34 * s, (y + 0.78) * s, sin(ta) * 0.34 * s), Vector3.ZERO, Vector3.ONE * 0.84 * s)

static func _trunk(g: Node3D, s: float, h: float, hex: int) -> void:
	add(g, cyl(0.2 * s, 0.34 * s, h * s, 12), soft(hex), Vector3(0, h * s / 2.0, 0))
	add(g, cyl(0.38 * s, 0.5 * s, 0.22 * s, 12), soft(hex), Vector3(0, 0.1 * s, 0))

static func sakura(s: float, rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	_trunk(g, s, 2.3, 0x7a4b3a)
	_canopy(g, s, rng, [0xff9fc6, 0xffb5d3, 0xffcfe2], 3.15)
	g.set_meta("r", 1.6 * s)
	return g

# Big round leafy tree.
static func round_tree(s: float, rng: RandomNumberGenerator, greens: Array = [0x3f9e44, 0x52b54d, 0x74cc5c], top: int = 0x74cc5c) -> Node3D:
	var g := Node3D.new()
	_trunk(g, s, 2.1, 0x8a5a36)
	_canopy(g, s, rng, [greens[0], greens[1], top], 3.0)
	g.set_meta("r", 1.9 * s)
	return g

# Low bush made of a few soft green blobs.
static func bush(s: float, rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	var greens := [0x45a548, 0x58b950, 0x6fc95c]
	for i in range(3):
		var a := i * TAU / 3.0 + rng.randf()
		var r := (0.62 + rng.randf() * 0.25) * s
		add(g, sphere(1.0, 14), foliage(greens[i], 0.02), Vector3(cos(a) * 0.5 * s, r * 0.7, sin(a) * 0.5 * s), Vector3.ZERO, Vector3(r, r * 0.85, r))
	g.set_meta("r", 1.2 * s)
	return g

# Curved palm tree with drooping fronds.
static func palm(s: float, rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	var lean := 0.12 + rng.randf() * 0.1
	var p := Vector3.ZERO
	for i in range(6):
		var seg_h := 0.75 * s
		var c := add(g, cyl(0.8, 1.0, 1.0, 12), soft(0xb5895a if i % 2 == 0 else 0xa87c4e), p + Vector3(0, seg_h / 2.0, 0), Vector3(0, 0, -lean * i * 0.5), Vector3(0.25 * s, seg_h, 0.25 * s))
		c.position.x += i * lean * 0.45 * s
		p.y += seg_h * 0.95
	var top := Vector3(6 * lean * 0.45 * s, p.y, 0)
	for i in range(7):
		var a := i * TAU / 7.0 + rng.randf() * 0.2
		var frond := Node3D.new()
		frond.position = top
		frond.rotation = Vector3(0, a, 0)
		g.add_child(frond)
		add(frond, capsule(0.22, 1.5), foliage(0x4fb850 if i % 2 == 0 else 0x3fa247, 0.12), Vector3(0, -0.25 * s, 0.85 * s), Vector3(PI / 2 + 0.45, 0, 0), Vector3(s, s, 0.28 * s))
	for i in range(3):
		add(g, sphere(0.16, 10), soft(0x7a5632), top + Vector3(cos(i * 2.1) * 0.22 * s, -0.25 * s, sin(i * 2.1) * 0.22 * s), Vector3.ZERO, Vector3.ONE * s)
	g.set_meta("r", 1.0 * s)
	return g

static func crate() -> Node3D:
	var g := Node3D.new()
	add(g, chamfer_box(0.05), soft(0xc48a4f), Vector3(0, 0.55, 0), Vector3.ZERO, Vector3.ONE * 1.1)
	for y in [0.12, 0.98]:
		add(g, box(1.16, 0.14, 1.16), soft(0x96623a), Vector3(0, y, 0))
	for x in [-0.5, 0.5]:
		for z in [-0.5, 0.5]:
			add(g, box(0.14, 1.0, 0.14), soft(0x96623a), Vector3(x, 0.55, z))
	g.set_meta("r", 1.0)
	return g

# Pine with snow on every layer.
static func snowy_pine(s: float) -> Node3D:
	var g := Node3D.new()
	add(g, cyl(0.2 * s, 0.3 * s, 1.0 * s, 10), soft(0x6f4a36), Vector3(0, 0.5 * s, 0))
	for i in range(3):
		var r := (1.5 - i * 0.35) * s
		add(g, cone(1.0, 1.0, 16), foliage(0x3a8a66, 0.03), Vector3(0, (1.3 + i * 0.9) * s, 0), Vector3.ZERO, Vector3(r, 1.6 * s, r))
		add(g, cone(1.0, 1.0, 16), foliage(0xf4f9ff, 0.03), Vector3(0, (1.64 + i * 0.9) * s, 0), Vector3.ZERO, Vector3(r * 0.6, 0.95 * s, r * 0.6))
	g.set_meta("r", 1.4 * s)
	return g

# Saguaro-style cactus with one or two arms.
static func cactus(s: float, rng: RandomNumberGenerator) -> Node3D:
	var g := Node3D.new()
	var green := soft(0x5aab4a)
	add(g, capsule(0.32, 1.0), green, Vector3(0, 1.0 * s, 0), Vector3.ZERO, Vector3(s, 1.6 * s, s))
	for side in ([-1.0, 1.0] if rng.randf() < 0.6 else [1.0]):
		var h := rng.randf_range(0.9, 1.5) * s
		add(g, capsule(0.2, 0.4), green, Vector3(side * 0.42 * s, h, 0), Vector3(0, 0, side * PI / 2.0), Vector3.ONE * s)
		add(g, capsule(0.2, 0.5), green, Vector3(side * 0.68 * s, h + 0.42 * s, 0), Vector3.ZERO, Vector3.ONE * s)
	add(g, sphere(0.1, 8), soft(0xff8fc0), Vector3(0, 2.18 * s, 0), Vector3.ZERO, Vector3.ONE * s)
	g.set_meta("r", 0.8 * s)
	return g

static func pine(s: float) -> Node3D:
	var g := Node3D.new()
	add(g, cyl(0.2 * s, 0.3 * s, 1.0 * s, 10), soft(0x6f4a36), Vector3(0, 0.5 * s, 0))
	var cols := [0x378a55, 0x45a060, 0x58b56c]
	for i in range(3):
		add(g, cone((1.5 - i * 0.35) * s, 1.6 * s, 16), foliage(cols[i], 0.03), Vector3(0, (1.3 + i * 0.9) * s, 0))
	g.set_meta("r", 1.4 * s)
	return g

static func rock(s: float) -> Node3D:
	var g := Node3D.new()
	add(g, sphere(1.0, 10), soft(0xb4adb9), Vector3(0, s * 0.42, 0), Vector3(0.2, 0.5, 0.1), Vector3(s, 0.66 * s, 0.88 * s))
	add(g, sphere(1.0, 8), soft(0xc7c1cc), Vector3(s * 0.78, s * 0.26, s * 0.3), Vector3(0.1, 1.1, 0.2), Vector3(0.56, 0.44, 0.5) * s)
	g.set_meta("r", s * 1.3)
	return g

static func lantern() -> Node3D:
	var g := Node3D.new()
	var stone := soft(0xc9c3cf)
	add(g, cyl(0.42, 0.55, 0.3, 6), stone, Vector3(0, 0.15, 0))
	add(g, cyl(0.17, 0.2, 1.05, 8), stone, Vector3(0, 0.82, 0))
	add(g, cyl(0.46, 0.34, 0.16, 6), stone, Vector3(0, 1.42, 0))
	add(g, box(0.62, 0.52, 0.62), stone, Vector3(0, 1.76, 0))
	add(g, box(0.4, 0.34, 0.66), flat(0xffdc8a), Vector3(0, 1.76, 0))
	add(g, box(0.66, 0.34, 0.4), flat(0xffdc8a), Vector3(0, 1.76, 0))
	add(g, cone(0.72, 0.46, 6), stone, Vector3(0, 2.26, 0))
	add(g, sphere(0.1, 8), stone, Vector3(0, 2.54, 0))
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

## Small white sprites for drifting particles; tint them with the material colour.
##   "petal" | "leaf" | "dot" (soft glow) | "flake"
static var _sprites := {}

static func sprite(kind: String) -> Texture2D:
	if _sprites.has(kind):
		return _sprites[kind]
	var body := ""
	match kind:
		"petal":
			body = '<path d="M32 4 C50 14 56 38 34 60 L32 52 L30 60 C8 38 14 14 32 4 Z" fill="#ffffff"/><path d="M32 12 C36 26 36 40 32 52" fill="none" stroke="#000000" stroke-opacity="0.12" stroke-width="2"/>'
		"leaf":
			body = '<path d="M32 2 C54 16 56 42 32 62 C8 42 10 16 32 2 Z" fill="#ffffff"/><path d="M32 6 L32 58" stroke="#000000" stroke-opacity="0.16" stroke-width="2.5"/>'
		"flake":
			body = '<circle cx="32" cy="32" r="16" fill="#ffffff"/><circle cx="32" cy="32" r="26" fill="#ffffff" fill-opacity="0.35"/>'
		_:
			body = '<defs><radialGradient id="g" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#ffffff" stop-opacity="1"/><stop offset="0.35" stop-color="#ffffff" stop-opacity="0.75"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></radialGradient></defs><circle cx="32" cy="32" r="31" fill="url(#g)"/>'
	var img := Image.new()
	if img.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">%s</svg>' % body, 1.0) != OK:
		img = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_sprites[kind] = t
	return t

## Drifting particles (petals, leaves, snow, fireflies) for a scene.
static func drift_particles(kind: String, col: Color, amount: int, extents: Vector3, height: float) -> CPUParticles3D:
	var parts := CPUParticles3D.new()
	var quad := QuadMesh.new()
	var fly := kind == "dot"
	quad.size = Vector2(0.34, 0.34) if kind != "flake" else Vector2(0.24, 0.24)
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = col
	pmat.albedo_texture = sprite(kind)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	if fly:
		pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = pmat
	parts.mesh = quad
	parts.amount = amount
	parts.lifetime = 14.0
	parts.preprocess = 14.0
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	parts.emission_box_extents = extents
	parts.position = Vector3(-6, height, 0)
	parts.direction = Vector3(1, -0.4, 0.2) if not fly else Vector3(0, 1, 0)
	parts.spread = 25.0 if not fly else 180.0
	parts.gravity = Vector3(0, -0.6, 0) if not fly else Vector3(0, 0.05, 0)
	parts.initial_velocity_min = 0.8 if not fly else 0.2
	parts.initial_velocity_max = 1.8 if not fly else 0.7
	parts.angle_min = 0.0
	parts.angle_max = 360.0
	parts.angular_velocity_min = -90.0 if not fly else 0.0
	parts.angular_velocity_max = 90.0 if not fly else 0.0
	parts.scale_amount_min = 0.7
	parts.scale_amount_max = 1.3 if not fly else 1.8
	parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return parts

## A four-pointed throwing star, lying flat.
static func star_mesh() -> ArrayMesh:
	if _meshes.has("star4"):
		return _meshes["star4"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for i in range(8):
		var a := i * TAU / 8.0
		var r := 0.36 if i % 2 == 0 else 0.12
		pts.append(Vector3(sin(a) * r, 0, cos(a) * r))
	for side in [1.0, -1.0]:
		var top := Vector3(0, 0.07 * side, 0)
		for i in range(8):
			var a1: Vector3 = pts[i]
			var b1: Vector3 = pts[(i + 1) % 8]
			var tri: Array = [top, a1, b1] if side > 0.0 else [top, b1, a1]
			var n: Vector3 = ((tri[2] as Vector3) - (tri[0] as Vector3)).cross((tri[1] as Vector3) - (tri[0] as Vector3)).normalized()
			for v in tri:
				st.set_normal(n)
				st.add_vertex(v)
	var mesh := st.commit()
	_meshes["star4"] = mesh
	return mesh

## Soft additive glow material shared per colour.
static func glow(hex: int, alpha: float = 0.45) -> StandardMaterial3D:
	var key := "glow_%x_%s" % [hex, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := fx_mat(Defs.col(hex, alpha), true)
	_mats[key] = m
	return m

static func projectile(kind: String) -> Node3D:
	var g := Node3D.new()
	var spin: Node3D = null
	match kind:
		"shuriken":
			spin = add(g, star_mesh(), flat(0xe6eaf2))
			add(g, sphere(0.09, 6), flat(0x4a4f63), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1))
		"arrow":
			add(g, box(0.07, 0.07, 0.86), flat(0xfff3c4))
			add(g, cone(0.11, 0.26, 6), flat(0xe8f4ff), Vector3(0, 0, 0.52), Vector3(PI / 2, 0, 0))
			add(g, box(0.26, 0.02, 0.2), flat(0xe53935), Vector3(0, 0, -0.34))
			add(g, box(0.02, 0.26, 0.2), flat(0xe53935), Vector3(0, 0, -0.34))
			add(g, box(0.05, 0.05, 1.3), glow(0xfff3c4, 0.3), Vector3(0, 0, -0.75))
		"fireball":
			add(g, sphere(0.3, 12), flat(0xffd76a))
			add(g, sphere(0.42, 12), glow(0xff7b22, 0.75))
			add(g, cone(0.34, 1.0, 10), glow(0xff5a1f, 0.5), Vector3(0, 0, -0.6), Vector3(-PI / 2, 0, 0))
		"frag":
			add(g, sphere(0.14, 8), flat(0xffe08a))
			add(g, sphere(0.22, 8), glow(0xffa726, 0.6))
		"flash":
			spin = add(g, box(0.35, 0.05, 0.5), flat(0xfff59d))
			add(g, sphere(0.3, 8), glow(0xfff59d, 0.4))
		"wave":
			add(g, torus(0.9, 0.12), flat(0xd9fbff, 0.9), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.45))
			add(g, torus(0.9, 0.3), glow(0x7fdcff, 0.35), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.6, 0.45))
		"missile":
			add(g, capsule(0.1, 0.34), flat(0xf2f4f8), Vector3.ZERO, Vector3(PI / 2, 0, 0))
			add(g, cone(0.1, 0.2, 8), flat(0xff5252), Vector3(0, 0, 0.36), Vector3(PI / 2, 0, 0))
			add(g, cone(0.12, 0.6, 8), glow(0xffa726, 0.6), Vector3(0, 0, -0.5), Vector3(-PI / 2, 0, 0))
	if kind.begins_with("orb_"):
		# A glowing energy ball in any colour: "orb_" + hex, e.g. "orb_3fa9f5"
		var hex := kind.substr(4).hex_to_int()
		add(g, sphere(0.26, 12), flat(0xffffff))
		add(g, sphere(0.36, 12), glow(hex, 0.85))
		spin = add(g, torus(0.42, 0.05), glow(hex, 0.7), Vector3.ZERO, Vector3(0.5, 0, 0.3))
	for c in g.get_children():
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if spin:
		g.set_meta("spin", spin)
	return g
