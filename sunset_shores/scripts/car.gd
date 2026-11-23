extends RigidBody3D
## An arcade car with raycast suspension and tyre grip. The same node is used as
## a kinematic "traffic" car on rails, a parked car, the player's car, and a
## police car driven by AI. Origin is at road level; forward is -Z.

const Util := preload("res://scripts/util.gd")

enum {PARKED, TRAFFIC, PLAYER, AI}

## w/l: width/length, bh/by: lower body height/centre, ch/cl/cz: cabin height/length/offset,
## wb: wheelbase, r: wheel radius, engine: drive force (N), vmax: top speed (m/s), mu: grip.
const SPECS := {
	"sedan": {"name": "Corsa", "w": 1.9, "l": 4.5, "bh": 0.55, "by": 0.62, "ch": 0.5, "cl": 2.3, "cz": 0.25, "wb": 2.75, "r": 0.36, "engine": 11000.0, "vmax": 44.0, "mu": 1.3, "mass": 1250.0},
	"compact": {"name": "Pip", "w": 1.72, "l": 3.7, "bh": 0.55, "by": 0.62, "ch": 0.56, "cl": 1.9, "cz": 0.2, "wb": 2.3, "r": 0.33, "engine": 9000.0, "vmax": 38.0, "mu": 1.3, "mass": 950.0},
	"sport": {"name": "Marlin GT", "w": 1.98, "l": 4.4, "bh": 0.45, "by": 0.55, "ch": 0.4, "cl": 1.9, "cz": 0.35, "wb": 2.7, "r": 0.35, "engine": 17000.0, "vmax": 62.0, "mu": 1.5, "mass": 1200.0},
	"suv": {"name": "Ranger", "w": 2.02, "l": 4.7, "bh": 0.75, "by": 0.85, "ch": 0.62, "cl": 2.8, "cz": 0.45, "wb": 2.85, "r": 0.42, "engine": 14000.0, "vmax": 42.0, "mu": 1.25, "mass": 1700.0, "armor": 0.7},
	"pickup": {"name": "Duna", "w": 2.0, "l": 5.2, "bh": 0.7, "by": 0.8, "ch": 0.62, "cl": 1.7, "cz": -0.55, "wb": 3.1, "r": 0.42, "engine": 14000.0, "vmax": 42.0, "mu": 1.25, "mass": 1650.0, "armor": 0.75},
	"van": {"name": "Mule", "w": 2.05, "l": 5.0, "bh": 1.5, "by": 1.2, "ch": 0.0, "cl": 0.0, "cz": 0.0, "wb": 3.0, "r": 0.4, "engine": 12000.0, "vmax": 36.0, "mu": 1.15, "mass": 2000.0, "armor": 0.6},
	"taxi": {"name": "Cab", "w": 1.9, "l": 4.5, "bh": 0.55, "by": 0.62, "ch": 0.5, "cl": 2.3, "cz": 0.25, "wb": 2.75, "r": 0.36, "engine": 11000.0, "vmax": 44.0, "mu": 1.3, "mass": 1250.0},
	"police": {"name": "Cruiser", "w": 1.92, "l": 4.6, "bh": 0.56, "by": 0.63, "ch": 0.5, "cl": 2.3, "cz": 0.25, "wb": 2.8, "r": 0.37, "engine": 15000.0, "vmax": 52.0, "mu": 1.45, "mass": 1400.0, "armor": 0.8},
}

static var _mesh_cache := {}
static var _wheel_cache := {}
static var _paint_cache := {}
static var head_mat: StandardMaterial3D
static var tail_mat: StandardMaterial3D
static var trim_mat: StandardMaterial3D
static var burnt_mat: StandardMaterial3D

var game
var type_id := "sedan"
var spec: Dictionary
var paint := Color.WHITE
var mode := PARKED
var driver = null
var accel := 0.0
var steer_in := 0.0
var handbrake := false
var steer := 0.0
var health := 100.0
var dead := false
var is_police := false
var siren_on := false
var mission := false
var home_spot := false
var wheels: Array = []
var anchor_y := 0.76
var rest_len := 0.84
var k_spring := 35000.0
var k_damp := 3000.0
var com_y := 0.45
var grounded := 0
var rail_speed := 0.0
var upside_down_t := 0.0
var last_hit_player := false
var burn_t := 0.0
var dead_t := 0.0
var _prev_vel := Vector3.ZERO
var _crash_cd := 0.0
var _still_t := 0.0
var _q: PhysicsRayQueryParameters3D
var body_mi: MeshInstance3D
var trim_mi: MeshInstance3D
var head_mi: MeshInstance3D
var tail_mi: MeshInstance3D
var bar_red: StandardMaterial3D
var bar_blue: StandardMaterial3D
var smoke: CPUParticles3D
var fire: CPUParticles3D
var siren_player: AudioStreamPlayer3D
var headlight: SpotLight3D
var flash_t := 0.0


static func _init_mats() -> void:
	if head_mat != null:
		return
	head_mat = Util.glow_mat(Color(1.0, 0.95, 0.8), 0.6)
	tail_mat = Util.glow_mat(Color(0.9, 0.05, 0.05), 1.0)
	trim_mat = Util.vc_mat(0.35, 0.25)
	burnt_mat = Util.mat(Color(0.08, 0.07, 0.07), 1.0)


static func set_night(n: float) -> void:
	_init_mats()
	head_mat.emission_energy_multiplier = lerpf(0.4, 5.0, n)
	tail_mat.emission_energy_multiplier = lerpf(0.8, 3.0, n)


func setup(g, t: String, color: Color) -> void:
	game = g
	type_id = t
	spec = SPECS[t]
	paint = color
	_init_mats()
	mass = spec.mass
	var r: float = spec.r
	anchor_y = r + 0.4
	k_spring = mass * 28.0
	var sag := mass * 9.8 * 0.25 / k_spring
	rest_len = anchor_y + sag
	k_damp = 2.0 * sqrt(k_spring * mass * 0.25) * 0.55
	com_y = float(spec.by) - float(spec.bh) * 0.5 + 0.12
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, com_y, 0)
	collision_layer = 2
	collision_mask = 1 | 2
	linear_damp = 0.02
	angular_damp = 0.6
	can_sleep = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.35
	pm.bounce = 0.05
	physics_material_override = pm
	is_police = t == "police"
	_add_box_shape(Vector3(spec.w, spec.bh, spec.l), Vector3(0, spec.by, 0))
	if float(spec.ch) > 0.0:
		_add_box_shape(Vector3(float(spec.w) * 0.9, spec.ch, spec.cl), Vector3(0, float(spec.by) + float(spec.bh) * 0.5 + float(spec.ch) * 0.5, spec.cz))
	var m: Dictionary = _meshes(t)
	body_mi = _mi(m.paint, _paint_mat(color), 500.0)
	trim_mi = _mi(m.trim, trim_mat, 200.0)
	head_mi = _mi(m.head, head_mat, 300.0)
	tail_mi = _mi(m.tail, tail_mat, 300.0)
	var wx: float = float(spec.w) * 0.5 - 0.2
	var wz: float = float(spec.wb) * 0.5
	for p in [Vector3(-wx, anchor_y, -wz), Vector3(wx, anchor_y, -wz), Vector3(-wx, anchor_y, wz), Vector3(wx, anchor_y, wz)]:
		var node := MeshInstance3D.new()
		node.mesh = _wheel_mesh(r)
		node.material_override = Util.vc_mat(0.7)
		node.visibility_range_end = 120.0
		add_child(node)
		node.position = Vector3(p.x, r, p.z)
		wheels.append({"anchor": p, "front": p.z < 0.0, "node": node, "dist": anchor_y, "spin": 0.0, "grounded": false})
	if is_police:
		_add_lightbar()
	_q = PhysicsRayQueryParameters3D.new()
	_q.collision_mask = 1
	_q.exclude = [get_rid()]


func _add_box_shape(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	add_child(cs)


func _mi(mesh: Mesh, m: Material, vis: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.visibility_range_end = vis
	add_child(mi)
	return mi


static func _paint_mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _paint_cache.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = color
		m.metallic = 0.45
		m.roughness = 0.3
		m.clearcoat_enabled = true
		m.clearcoat = 0.6
		_paint_cache[key] = m
	return _paint_cache[key]


static func _wheel_mesh(r: float) -> ArrayMesh:
	var key := "%.2f" % r
	if not _wheel_cache.has(key):
		var z := Vector3(0, 0, PI * 0.5)
		_wheel_cache[key] = Util.merge([
			[Util.cyl(r, r, 0.27, 14), Util.xf(Vector3.ZERO, z), Color(0.08, 0.08, 0.09)],
			[Util.cyl(r * 0.62, r * 0.62, 0.285, 12), Util.xf(Vector3.ZERO, z), Color(0.75, 0.76, 0.78)],
			[Util.box(0.29, r * 1.1, 0.07), Util.xf(Vector3.ZERO), Color(0.3, 0.3, 0.32)],
			[Util.box(0.29, 0.07, r * 1.1), Util.xf(Vector3.ZERO), Color(0.3, 0.3, 0.32)],
		])
	return _wheel_cache[key]


static func _meshes(t: String) -> Dictionary:
	if _mesh_cache.has(t):
		return _mesh_cache[t]
	var s: Dictionary = SPECS[t]
	var W: float = s.w
	var L: float = s.l
	var bh: float = s.bh
	var by: float = s.by
	var ch: float = s.ch
	var cl: float = s.cl
	var cz: float = s.cz
	var top := by + bh * 0.5
	var bot := by - bh * 0.5
	var glass := Color(0.07, 0.09, 0.12)
	var dark := Color(0.11, 0.11, 0.12)
	var paint := []
	var trim := []
	var head := []
	var tail := []
	paint.append([Util.box(W, bh, L), Util.xf(Vector3(0, by, 0))])
	# a slight hood/trunk bevel
	paint.append([Util.box(W * 0.96, 0.06, L * 0.98), Util.xf(Vector3(0, top + 0.02, 0))])
	if ch > 0.0:
		trim.append([Util.box(W * 0.86, ch, cl), Util.xf(Vector3(0, top + ch * 0.5, cz)), glass])
		paint.append([Util.box(W * 0.88, 0.07, cl * 0.82), Util.xf(Vector3(0, top + ch + 0.03, cz))])
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				paint.append([Util.box(0.07, ch, 0.12), Util.xf(Vector3(sx * W * 0.43, top + ch * 0.5, cz + sz * cl * 0.44))])
		trim.append([Util.box(0.08, 0.1, 0.16), Util.xf(Vector3(-W * 0.5 - 0.05, top + 0.12, cz - cl * 0.5 + 0.15)), dark])
		trim.append([Util.box(0.08, 0.1, 0.16), Util.xf(Vector3(W * 0.5 + 0.05, top + 0.12, cz - cl * 0.5 + 0.15)), dark])
	else:
		# van: windscreen and side windows painted onto the tall body
		trim.append([Util.box(W * 0.9, 0.6, 0.04), Util.xf(Vector3(0, top - 0.4, -L * 0.5 - 0.01)), glass])
		for sx in [-1.0, 1.0]:
			trim.append([Util.box(0.04, 0.5, 1.0), Util.xf(Vector3(sx * (W * 0.5 + 0.01), top - 0.4, -L * 0.5 + 0.7)), glass])
	trim.append([Util.box(W + 0.04, 0.2, 0.26), Util.xf(Vector3(0, bot + 0.12, -L * 0.5 + 0.08)), dark])
	trim.append([Util.box(W + 0.04, 0.2, 0.26), Util.xf(Vector3(0, bot + 0.12, L * 0.5 - 0.08)), dark])
	trim.append([Util.box(W * 0.45, 0.14, 0.05), Util.xf(Vector3(0, by + 0.03, -L * 0.5 - 0.01)), dark])
	trim.append([Util.box(W + 0.02, 0.06, L * 0.7), Util.xf(Vector3(0, bot + 0.05, 0)), dark])
	for sx in [-1.0, 1.0]:
		head.append([Util.box(W * 0.22, 0.12, 0.06), Util.xf(Vector3(sx * W * 0.33, by + 0.1, -L * 0.5 - 0.015))])
		tail.append([Util.box(W * 0.2, 0.12, 0.06), Util.xf(Vector3(sx * W * 0.34, by + 0.12, L * 0.5 + 0.015))])
	match t:
		"sport":
			paint.append([Util.box(W * 0.92, 0.06, 0.38), Util.xf(Vector3(0, top + 0.34, L * 0.5 - 0.25))])
			for sx in [-0.6, 0.6]:
				trim.append([Util.box(0.06, 0.3, 0.1), Util.xf(Vector3(sx, top + 0.17, L * 0.5 - 0.25)), dark])
			trim.append([Util.box(0.3, 0.02, 1.2), Util.xf(Vector3(0, top + 0.035, -L * 0.25)), dark])
		"pickup":
			var bed_len := 2.1
			for sx in [-1.0, 1.0]:
				paint.append([Util.box(0.08, 0.45, bed_len), Util.xf(Vector3(sx * (W * 0.5 - 0.04), top + 0.22, L * 0.5 - bed_len * 0.5 - 0.05))])
			paint.append([Util.box(W, 0.45, 0.08), Util.xf(Vector3(0, top + 0.22, L * 0.5 - 0.06))])
			trim.append([Util.box(W - 0.16, 0.04, bed_len), Util.xf(Vector3(0, top + 0.03, L * 0.5 - bed_len * 0.5 - 0.05)), dark])
		"taxi":
			trim.append([Util.box(0.7, 0.22, 0.3), Util.xf(Vector3(0, top + ch + 0.18, cz)), Color(1.0, 0.95, 0.75)])
			trim.append([Util.box(W + 0.01, 0.08, L * 0.5), Util.xf(Vector3(0, by + 0.05, 0)), Color(0.1, 0.1, 0.1)])
		"police":
			trim.append([Util.box(W + 0.015, 0.14, L * 0.62), Util.xf(Vector3(0, by + 0.06, 0)), Color(0.08, 0.12, 0.3)])
			paint.append([Util.box(W * 0.7, 0.03, 0.12), Util.xf(Vector3(0, top + ch + 0.08, cz))])
		"van":
			trim.append([Util.box(W + 0.015, 0.3, L * 0.55), Util.xf(Vector3(0, by + 0.2, L * 0.15)), Color(0.85, 0.85, 0.82)])
	var out := {
		"paint": Util.merge(paint),
		"trim": Util.merge(trim),
		"head": Util.merge(head),
		"tail": Util.merge(tail),
	}
	_mesh_cache[t] = out
	return out


func _add_lightbar() -> void:
	var y: float = float(spec.by) + float(spec.bh) * 0.5 + float(spec.ch) + 0.16
	bar_red = Util.glow_mat(Color(1.0, 0.1, 0.1), 0.3)
	bar_blue = Util.glow_mat(Color(0.1, 0.3, 1.0), 0.3)
	var r := MeshInstance3D.new()
	r.mesh = Util.box(0.55, 0.13, 0.26)
	r.material_override = bar_red
	r.position = Vector3(-0.32, y, spec.cz)
	add_child(r)
	var b := MeshInstance3D.new()
	b.mesh = Util.box(0.55, 0.13, 0.26)
	b.material_override = bar_blue
	b.position = Vector3(0.32, y, spec.cz)
	add_child(b)


# --- control -----------------------------------------------------------------

func set_controls(a: float, s: float, hb: bool) -> void:
	accel = clampf(a, -1.0, 1.0)
	steer_in = clampf(s, -1.0, 1.0)
	handbrake = hb


func set_driver(d) -> void:
	driver = d
	if d == null:
		mode = PARKED
		set_controls(0, 0, false)
		continuous_cd = false
		if headlight:
			headlight.queue_free()
			headlight = null
	else:
		if freeze:
			freeze = false
		mode = PLAYER if d == game.player else AI
		sleeping = false
		if mode == PLAYER:
			continuous_cd = true
			_make_headlight()


func make_traffic() -> void:
	mode = TRAFFIC
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true


func make_dynamic(vel: Vector3) -> void:
	freeze = false
	mode = PARKED
	sleeping = false
	linear_velocity = vel
	_prev_vel = vel


func rail_move(xf: Transform3D, spd: float) -> void:
	global_transform = xf
	rail_speed = spd


func forward_speed() -> float:
	if mode == TRAFFIC:
		return rail_speed
	return -linear_velocity.dot(global_transform.basis.z)


func flip_upright() -> void:
	var f := -global_transform.basis.z
	global_transform = Transform3D(Basis(Vector3.UP, Util.yaw_of(Vector3(f.x, 0, f.z))), global_position + Vector3.UP * 1.2)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_prev_vel = Vector3.ZERO
	upside_down_t = 0.0


func honk() -> void:
	game.sfx.play("horn", global_position, -2.0)


func repaint(color: Color) -> void:
	paint = color
	if not dead:
		body_mi.material_override = _paint_mat(color)


# --- physics -----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_crash_cd -= delta
	if mode == TRAFFIC:
		_update_wheels(rail_speed, delta, true)
		return
	if dead:
		dead_t += delta
		if burn_t > 0.0:
			burn_t -= delta
			if burn_t <= 0.0 and fire:
				fire.emitting = false
		return
	if driver == null and mode != AI and sleeping:
		return
	_drive(delta)
	_check_crash()
	_damage_tick(delta)


func _drive(delta: float) -> void:
	var xf := global_transform
	var b := xf.basis
	var up := b.y
	var com := xf * center_of_mass
	var lv := linear_velocity
	var av := angular_velocity
	var fwd_speed := -lv.dot(b.z)
	var a := accel
	var s_in := steer_in
	var hb := handbrake
	var has_driver: bool = driver != null or mode == AI
	if not has_driver:
		a = 0.0
		s_in = 0.0
		hb = false
	var throttle := 0.0
	var brake := 0.0
	if a > 0.05:
		if fwd_speed < -1.0:
			brake = a
		else:
			throttle = a
	elif a < -0.05:
		if fwd_speed > 1.0:
			brake = -a
		else:
			throttle = a
	elif absf(fwd_speed) < 2.0:
		brake = 0.3
	if not has_driver:
		brake = 1.0
	var vmax: float = spec.vmax
	var curve := 1.0
	if throttle > 0.0:
		curve = clampf(1.0 - pow(maxf(fwd_speed, 0.0) / vmax, 2.0), 0.0, 1.0)
	elif throttle < 0.0:
		curve = clampf(1.0 - pow(maxf(-fwd_speed, 0.0) / 13.0, 2.0), 0.0, 1.0)
	var max_steer := lerpf(0.6, 0.13, clampf(absf(fwd_speed) / 45.0, 0.0, 1.0))
	steer = move_toward(steer, s_in * max_steer, delta * 3.0)
	var quarter := mass * 0.25
	var drive_total: float = float(spec.engine) * throttle * curve
	var slip := 1.0
	if mode == PLAYER and game.player.perk() == "driver":
		drive_total *= 1.15
		if game.player.ability_on:
			slip = 1.6
	var space := get_world_3d().direct_space_state
	grounded = 0
	for w in wheels:
		var anchor: Vector3 = w.anchor
		var origin: Vector3 = xf * anchor
		_q.from = origin
		_q.to = origin - up * rest_len
		var hit := space.intersect_ray(_q)
		if hit.is_empty():
			w.dist = rest_len
			w.grounded = false
			continue
		grounded += 1
		w.grounded = true
		var pt: Vector3 = hit.position
		var n: Vector3 = hit.normal
		var dist := origin.distance_to(pt)
		w.dist = dist
		var vp := lv + av.cross(pt - com)
		var spring := k_spring * (rest_len - dist) - k_damp * vp.dot(up)
		spring = clampf(spring, 0.0, mass * 9.8 * 2.5)
		apply_force(up * spring, pt - xf.origin)
		var fdir := -b.z
		var rdir := b.x
		if w.front:
			fdir = fdir.rotated(up, steer)
			rdir = rdir.rotated(up, steer)
		fdir = (fdir - n * fdir.dot(n)).normalized()
		rdir = (rdir - n * rdir.dot(n)).normalized()
		var vs := vp.dot(rdir)
		var vf := vp.dot(fdir)
		var mu: float = float(spec.mu) * slip
		var rear_hb: bool = hb and not w.front
		if rear_hb:
			mu *= 0.45
		var max_f := mu * spring
		var f_lat := -vs * quarter / delta * 0.35
		var f_long := clampf(drive_total * 0.25, -max_f * 0.8, max_f * 0.8)
		var stop_f := absf(vf) * quarter / delta * 0.5
		if brake > 0.0:
			f_long -= signf(vf) * minf(brake * 4500.0, stop_f)
		if rear_hb:
			f_long -= signf(vf) * minf(max_f * 0.8, stop_f)
		f_long -= vf * 20.0
		var f := Vector2(f_lat, f_long)
		if f.length() > max_f:
			f = f.normalized() * max_f
		var app := b * Vector3(anchor.x, com_y + 0.15, anchor.z)
		apply_force(rdir * f.x + fdir * f.y, app)
	var spd := lv.length()
	apply_central_force(-lv * spd * 0.45)
	# driving into the sea: heavy drag, then the engine floods
	if xf.origin.y < -0.9:
		apply_central_force(-lv * mass * 1.5)
		if has_driver:
			damage(8.0 * delta, driver == game.player)
			if driver == game.player:
				game.hint = "The engine is flooding. Get back to dry land!"
	if grounded > 0:
		apply_central_force(-up * spd * spd * 1.2)
	else:
		apply_torque(up.cross(Vector3.UP) * mass * 3.0 - av * mass * 0.3)
	if up.y < 0.3 and spd < 3.0:
		upside_down_t += delta
	else:
		upside_down_t = 0.0
	if mode == AI and upside_down_t > 3.0:
		flip_upright()
	if not has_driver and spd < 0.25 and av.length() < 0.25 and grounded == 4:
		_still_t += delta
		if _still_t > 1.0:
			_still_t = 0.0
			sleeping = true
	else:
		_still_t = 0.0
	_update_wheels(fwd_speed, delta, false)


func _update_wheels(fwd_speed: float, delta: float, rest: bool) -> void:
	var r: float = spec.r
	for w in wheels:
		var node: Node3D = w.node
		var a: Vector3 = w.anchor
		var d: float = anchor_y if rest else clampf(w.dist, 0.25, rest_len)
		node.position = Vector3(a.x, a.y - d + r, a.z)
		w.spin = fmod(w.spin - fwd_speed * delta / r, TAU)
		var yaw: float = steer if w.front and not rest else 0.0
		node.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, w.spin)


func _check_crash() -> void:
	var dv := (linear_velocity - _prev_vel).length()
	_prev_vel = linear_velocity
	if dv > 7.0 and _crash_cd <= 0.0:
		_crash_cd = 0.3
		var by_player: bool = driver == game.player
		# a hard crash at ~40 m/s takes about 70%; it takes a few to set a car alight
		damage((dv - 7.0) * 2.2 * float(spec.get("armor", 1.0)), by_player)
		game.sfx.play("crash", global_position, clampf(-16.0 + dv, -10.0, 6.0), randf_range(0.85, 1.1))
		game.on_car_crash(self, dv)


func _damage_tick(delta: float) -> void:
	if health < 50.0:
		if smoke == null:
			smoke = _particles(Color(0.25, 0.25, 0.25), false)
		smoke.emitting = true
	if health < 22.0:
		if fire == null:
			fire = _particles(Color(1.0, 0.45, 0.1), true)
		fire.emitting = true
		damage(4.0 * delta, last_hit_player)


func damage(amount: float, by_player := false) -> void:
	if dead:
		return
	if by_player:
		last_hit_player = true
	health -= amount
	if health <= 0.0:
		explode()


func take_hit(dmg: float, from, pos: Vector3) -> void:
	var by_player: bool = from == game.player
	damage(dmg * 0.3, by_player)
	game.fx.spark(pos)
	if is_police and by_player:
		game.police.on_cop_car_shot()


func explode() -> void:
	if dead:
		return
	dead = true
	health = 0.0
	var by_player := last_hit_player
	body_mi.material_override = burnt_mat
	trim_mi.material_override = burnt_mat
	head_mi.visible = false
	tail_mi.visible = false
	siren_on = false
	if bar_red:
		bar_red.emission_energy_multiplier = 0.0
		bar_blue.emission_energy_multiplier = 0.0
	if siren_player:
		siren_player.stop()
	if mode == TRAFFIC:
		game.traffic.release(self)
	freeze = false
	sleeping = false
	apply_central_impulse(Vector3.UP * mass * 5.0 + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * mass * 1.5)
	apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * mass * 1.5)
	if fire == null:
		fire = _particles(Color(1.0, 0.45, 0.1), true)
	fire.emitting = true
	if smoke:
		smoke.emitting = true
	burn_t = 12.0
	if driver == game.player:
		game.player.die_in_car()
	elif driver != null:
		driver = null
	mode = PARKED
	game.stats.cars_destroyed += 1
	game.explode(global_position + Vector3.UP, 8.0, by_player, self)


func _particles(color: Color, glow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 20
	p.lifetime = 1.3 if glow else 2.0
	var m := SphereMesh.new()
	m.radius = 0.3
	m.height = 0.6
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0)
	m.material = mat
	p.mesh = m
	p.direction = Vector3.UP
	p.spread = 18.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, 1.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.85))
	g.set_color(1, Color(1, 1, 1, 0.0))
	p.color_ramp = g
	p.local_coords = false
	p.position = Vector3(0, float(spec.by) + 0.4, -float(spec.l) * 0.32)
	p.emitting = false
	add_child(p)
	return p


func _make_headlight() -> void:
	if headlight:
		return
	headlight = SpotLight3D.new()
	headlight.position = Vector3(0, float(spec.by) + 0.15, -float(spec.l) * 0.5 - 0.2)
	headlight.rotation.x = -0.1
	headlight.spot_range = 45.0
	headlight.spot_angle = 34.0
	headlight.light_energy = 5.0
	headlight.light_color = Color(1.0, 0.95, 0.85)
	headlight.shadow_enabled = false
	add_child(headlight)


func _process(delta: float) -> void:
	if headlight:
		headlight.visible = game.night > 0.35 and not dead
	if is_police and bar_red and not dead:
		if siren_on:
			flash_t += delta
			var on := fmod(flash_t, 0.5) < 0.25
			bar_red.emission_energy_multiplier = 6.0 if on else 0.3
			bar_blue.emission_energy_multiplier = 0.3 if on else 6.0
		else:
			bar_red.emission_energy_multiplier = 0.3
			bar_blue.emission_energy_multiplier = 0.3
	if is_police:
		var want: bool = siren_on and not dead
		if want and siren_player == null:
			siren_player = AudioStreamPlayer3D.new()
			siren_player.stream = game.sfx.streams.get("siren")
			siren_player.unit_size = 14.0
			siren_player.max_distance = 220.0
			siren_player.volume_db = -6.0
			add_child(siren_player)
		if siren_player:
			if want and not siren_player.playing:
				siren_player.play(randf() * 1.0)
			elif not want and siren_player.playing:
				siren_player.stop()
