extends Node3D
## A simple blocky person: torso, head and four limbs on pivots, animated in code.
## Faces -Z. Used for the player, pedestrians and police.

const Util := preload("res://scripts/util.gd")

var body: Node3D
var head: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var gun: MeshInstance3D
var phase := 0.0
var aim_amount := 0.0
var lying := false


func build(shirt: Color, pants: Color, skin: Color, hair: Color, opts := {}) -> void:
	var shoe: Color = opts.get("shoes", Color(0.12, 0.1, 0.1))
	var cap = opts.get("cap", null)
	var hair_style: int = opts.get("hair_style", 0)
	body = _part(Vector3.ZERO, [
		[Util.box(0.44, 0.56, 0.25), Util.xf(Vector3(0, 1.22, 0)), shirt],
		[Util.box(0.4, 0.16, 0.23), Util.xf(Vector3(0, 0.94, 0)), pants],
		[Util.cyl(0.06, 0.07, 0.1, 6), Util.xf(Vector3(0, 1.53, 0)), skin],
	])
	var head_parts := [
		[Util.sphere(0.135, 12), Util.xf(Vector3(0, 0.13, 0), Vector3.ZERO, Vector3(0.95, 1.1, 1.0)), skin],
		[Util.box(0.035, 0.035, 0.02), Util.xf(Vector3(-0.045, 0.16, -0.128)), Color(0.08, 0.06, 0.06)],
		[Util.box(0.035, 0.035, 0.02), Util.xf(Vector3(0.045, 0.16, -0.128)), Color(0.08, 0.06, 0.06)],
	]
	if cap != null:
		head_parts.append([Util.cyl(0.14, 0.145, 0.09, 12), Util.xf(Vector3(0, 0.27, 0)), cap])
		head_parts.append([Util.box(0.24, 0.025, 0.14), Util.xf(Vector3(0, 0.235, -0.15)), cap])
	elif hair_style == 1:
		head_parts.append([Util.sphere(0.15, 10), Util.xf(Vector3(0, 0.17, 0.03), Vector3.ZERO, Vector3(1.0, 0.9, 1.05)), hair])
		head_parts.append([Util.box(0.26, 0.3, 0.08), Util.xf(Vector3(0, 0.02, 0.1)), hair])
	else:
		head_parts.append([Util.sphere(0.145, 10), Util.xf(Vector3(0, 0.19, 0.02), Vector3.ZERO, Vector3(1.0, 0.7, 1.0)), hair])
	head = _part(Vector3(0, 1.56, 0), head_parts)
	leg_l = _part(Vector3(-0.1, 0.9, 0), [
		[Util.box(0.16, 0.84, 0.18), Util.xf(Vector3(0, -0.42, 0)), pants],
		[Util.box(0.17, 0.09, 0.28), Util.xf(Vector3(0, -0.86, -0.04)), shoe],
	])
	leg_r = _part(Vector3(0.1, 0.9, 0), [
		[Util.box(0.16, 0.84, 0.18), Util.xf(Vector3(0, -0.42, 0)), pants],
		[Util.box(0.17, 0.09, 0.28), Util.xf(Vector3(0, -0.86, -0.04)), shoe],
	])
	arm_l = _part(Vector3(-0.3, 1.46, 0), [
		[Util.box(0.13, 0.32, 0.14), Util.xf(Vector3(0, -0.15, 0)), shirt],
		[Util.box(0.1, 0.3, 0.11), Util.xf(Vector3(0, -0.45, 0)), skin],
		[Util.sphere(0.06, 6), Util.xf(Vector3(0, -0.63, 0)), skin],
	])
	arm_r = _part(Vector3(0.3, 1.46, 0), [
		[Util.box(0.13, 0.32, 0.14), Util.xf(Vector3(0, -0.15, 0)), shirt],
		[Util.box(0.1, 0.3, 0.11), Util.xf(Vector3(0, -0.45, 0)), skin],
		[Util.sphere(0.06, 6), Util.xf(Vector3(0, -0.63, 0)), skin],
	])
	gun = MeshInstance3D.new()
	gun.mesh = Util.merge([
		[Util.box(0.05, 0.26, 0.07), Util.xf(Vector3(0, -0.74, -0.02)), Color(0.1, 0.1, 0.11)],
		[Util.box(0.045, 0.06, 0.13), Util.xf(Vector3(0, -0.66, 0.05)), Color(0.15, 0.13, 0.12)],
	])
	gun.material_override = Util.vc_mat(0.4, 0.5)
	gun.visible = false
	arm_r.add_child(gun)


func _part(pivot: Vector3, parts: Array) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	add_child(n)
	var mi := MeshInstance3D.new()
	mi.mesh = Util.merge(parts)
	mi.material_override = Util.vc_mat()
	mi.visibility_range_end = 140.0
	n.add_child(mi)
	return n


func show_gun(on: bool) -> void:
	if gun:
		gun.visible = on


func animate(delta: float, speed: float, aiming := false) -> void:
	if lying:
		return
	var k := clampf(speed / 3.0, 0.0, 1.5)
	if speed > 0.1:
		phase += delta * (3.5 + speed * 1.7)
	else:
		phase = lerpf(phase, roundf(phase / PI) * PI, minf(1.0, delta * 8.0))
	var s := sin(phase) * 0.65 * minf(k, 1.25)
	leg_l.rotation.x = s
	leg_r.rotation.x = -s
	arm_l.rotation.x = -s * 0.8
	aim_amount = move_toward(aim_amount, 1.0 if aiming else 0.0, delta * 8.0)
	arm_r.rotation.x = lerpf(s * 0.8, PI * 0.5, aim_amount)
	arm_l.rotation.z = 0.0
	var bob := absf(sin(phase)) * 0.045 * minf(k, 1.0)
	body.position.y = bob
	head.position.y = 1.56 + bob
	body.rotation.x = -0.12 * clampf((speed - 4.0) / 3.0, 0.0, 1.0)


func muzzle_position() -> Vector3:
	return arm_r.global_transform * Vector3(0, -0.88, -0.02)


func set_dead() -> void:
	lying = true
	rotation.x = -PI * 0.5
	position.y = 0.16
	arm_l.rotation = Vector3(0, 0, 1.2)
	arm_r.rotation = Vector3(0, 0, -1.0)
	leg_l.rotation = Vector3(0.1, 0, 0.15)
	leg_r.rotation = Vector3(-0.1, 0, -0.1)
	show_gun(false)


func set_hands_up() -> void:
	lying = true
	arm_l.rotation = Vector3(PI * 0.95, 0, 0.2)
	arm_r.rotation = Vector3(PI * 0.95, 0, -0.2)
	show_gun(false)


func reset_pose() -> void:
	lying = false
	rotation = Vector3(0, rotation.y, 0)
	position.y = 0.0
	for n in [arm_l, arm_r, leg_l, leg_r]:
		n.rotation = Vector3.ZERO
