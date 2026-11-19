extends Node3D
## Short-lived effects: tracers, muzzle flashes, sparks, blood, explosions,
## plus the glowing mission marker beams.

const Util := preload("res://scripts/util.gd")

var game
var items: Array = []   # [node, age, life, kind, extra]
var tracer_mesh: BoxMesh
var tracer_mat: StandardMaterial3D
var flash_mat: StandardMaterial3D
var spark_mat: StandardMaterial3D
var blood_mat: StandardMaterial3D
var small_sphere: SphereMesh


func _ready() -> void:
	name = "Fx"
	tracer_mesh = Util.box(0.03, 0.03, 1.0)
	tracer_mat = Util.glow_mat(Color(1.0, 0.85, 0.45), 4.0, true)
	flash_mat = Util.glow_mat(Color(1.0, 0.8, 0.4), 6.0, true)
	spark_mat = Util.glow_mat(Color(1.0, 0.7, 0.3), 5.0, true)
	blood_mat = Util.mat(Color(0.55, 0.02, 0.03), 0.6)
	small_sphere = Util.sphere(0.08, 6)


func _add(node: Node3D, life: float, kind: String, extra = null) -> void:
	add_child(node)
	items.append([node, 0.0, life, kind, extra])


func tracer(a: Vector3, b: Vector3, color := Color(1.0, 0.85, 0.45)) -> void:
	var len := a.distance_to(b)
	if len < 0.2:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = tracer_mesh
	mi.material_override = tracer_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(mi, 0.06, "static")
	mi.global_transform = Transform3D(Util.look_basis(b - a) * Basis.from_scale(Vector3(1, 1, len)), (a + b) * 0.5)


func flash(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Util.sphere(0.14, 6)
	mi.material_override = flash_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(mi, 0.05, "static")
	mi.global_position = pos
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.5)
	l.light_energy = 2.5
	l.omni_range = 5.0
	_add(l, 0.05, "static")
	l.global_position = pos


func spark(pos: Vector3) -> void:
	for k in 3:
		var mi := MeshInstance3D.new()
		mi.mesh = small_sphere
		mi.material_override = spark_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(mi, 0.25, "particle", Vector3(randf_range(-3, 3), randf_range(1, 4), randf_range(-3, 3)))
		mi.global_position = pos


func impact(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = small_sphere
	mi.material_override = Util.mat(Color(0.7, 0.68, 0.62))
	_add(mi, 0.3, "particle", Vector3(randf_range(-1, 1), 2.0, randf_range(-1, 1)))
	mi.global_position = pos
	spark(pos)


func blood(pos: Vector3) -> void:
	for k in 4:
		var mi := MeshInstance3D.new()
		mi.mesh = small_sphere
		mi.material_override = blood_mat
		_add(mi, 0.45, "particle", Vector3(randf_range(-2, 2), randf_range(0.5, 3), randf_range(-2, 2)))
		mi.global_position = pos


func explosion(pos: Vector3) -> void:
	var ball := MeshInstance3D.new()
	ball.mesh = Util.sphere(1.0, 16)
	var m := Util.fade_mat(Color(1.0, 0.6, 0.15, 1.0))
	m.albedo_color = Color(3.0, 1.6, 0.4, 1.0)
	ball.material_override = m
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(ball, 0.7, "fireball", m)
	ball.global_position = pos
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 12.0
	l.omni_range = 26.0
	_add(l, 0.8, "light")
	l.global_position = pos + Vector3.UP
	for k in 8:
		var s := MeshInstance3D.new()
		s.mesh = Util.sphere(1.0, 8)
		var sm := Util.fade_mat(Color(0.2, 0.2, 0.2, 0.7))
		s.material_override = sm
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_add(s, randf_range(1.8, 3.0), "smoke", [sm, Vector3(randf_range(-2, 2), randf_range(2, 5), randf_range(-2, 2))])
		s.global_position = pos + Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1))
	for k in 10:
		var d := MeshInstance3D.new()
		d.mesh = Util.box(0.25, 0.25, 0.25)
		d.material_override = Util.mat(Color(0.1, 0.1, 0.1))
		_add(d, 1.6, "debris", Vector3(randf_range(-8, 8), randf_range(6, 14), randf_range(-8, 8)))
		d.global_position = pos


func make_marker(color: Color, radius := 1.5, height := 3.0) -> Node3D:
	var n := Node3D.new()
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.cap_top = false
	cm.cap_bottom = false
	cm.radial_segments = 24
	beam.mesh = cm
	beam.position.y = height * 0.5
	var m := Util.fade_mat(Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.3))
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(beam)
	var ring := MeshInstance3D.new()
	ring.mesh = Util.cyl(radius, radius, 0.04, 24)
	ring.material_override = Util.fade_mat(Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.55))
	ring.position.y = 0.06
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(ring)
	var arrow := MeshInstance3D.new()
	arrow.mesh = Util.cyl(0.5, 0.0, 0.9, 4)
	arrow.material_override = Util.glow_mat(color, 3.0, true)
	arrow.position.y = height + 1.2
	arrow.name = "Arrow"
	n.add_child(arrow)
	return n


func _process(delta: float) -> void:
	var k := 0
	while k < items.size():
		var it: Array = items[k]
		var node: Node3D = it[0]
		it[1] += delta
		var age: float = it[1]
		var life: float = it[2]
		if age >= life or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			items.remove_at(k)
			continue
		var t := age / life
		match it[3]:
			"particle", "debris":
				var v: Vector3 = it[4]
				v.y -= 15.0 * delta
				it[4] = v
				node.global_position += v * delta
				if it[3] == "debris":
					node.rotation += Vector3(7, 5, 3) * delta
			"fireball":
				node.scale = Vector3.ONE * lerpf(1.0, 6.5, sqrt(t))
				var m: StandardMaterial3D = it[4]
				m.albedo_color.a = 1.0 - t
			"light":
				(node as OmniLight3D).light_energy = 12.0 * (1.0 - t)
			"smoke":
				var dat: Array = it[4]
				var sm: StandardMaterial3D = dat[0]
				node.global_position += (dat[1] as Vector3) * delta
				node.scale = Vector3.ONE * lerpf(1.2, 4.0, t)
				sm.albedo_color.a = 0.7 * (1.0 - t)
		k += 1
