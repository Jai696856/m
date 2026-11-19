extends RefCounted
## Shared helpers: cached materials, primitive shapes, and merging several
## primitives into one vertex-coloured mesh (one draw call per model part).

static var _mats := {}


static func xf(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scl), pos)


static func box(x: float, y: float, z: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(x, y, z)
	return m


static func cyl(top: float, bottom: float, h: float, segs := 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	return m


static func sphere(r: float, segs := 10) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = segs
	m.rings = maxi(4, segs / 2)
	return m


static func mat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var key := "m%s_%.2f_%.2f" % [color.to_html(), rough, metal]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		_mats[key] = m
	return _mats[key]


static func glow_mat(color: Color, energy := 2.0, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func vc_mat(rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var key := "vc_%.2f_%.2f" % [rough, metal]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = rough
		m.metallic = metal
		_mats[key] = m
	return _mats[key]


static func fade_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	return m


## parts: Array of [PrimitiveMesh, Transform3D, Color]
static func merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for p in parts:
		var arr: Array = (p[0] as PrimitiveMesh).get_mesh_arrays()
		var t: Transform3D = p[1]
		var c: Color = p[2] if p.size() > 2 else Color.WHITE
		var nb := t.basis.inverse().transposed()
		var base := verts.size()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for k in v.size():
			verts.append(t * v[k])
			norms.append((nb * n[k]).normalized())
			cols.append(c)
		var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for k in ii:
			idx.append(base + k)
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = verts
	a[Mesh.ARRAY_NORMAL] = norms
	a[Mesh.ARRAY_COLOR] = cols
	a[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return mesh


static func look_basis(dir: Vector3) -> Basis:
	if dir.length_squared() < 0.0001:
		return Basis()
	dir = dir.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
	return Basis.looking_at(dir, up)


## Yaw that makes a node's -Z axis face along dir (on the ground plane).
static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)
