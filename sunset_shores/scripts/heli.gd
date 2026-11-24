extends Node3D
## The police helicopter: joins the chase at 3 stars, circles overhead, lights you
## up with a searchlight after dark and fires down at you. Can be shot down.

const Util := preload("res://scripts/util.gd")

var game
var health := 260.0
var dead := false
var leaving := false
var vel := Vector3.ZERO
var rotor: Node3D
var tail_rotor: Node3D
var light: SpotLight3D
var hitbox: AnimatableBody3D
var angle := 0.0
var shoot_cd := 2.0
var fall_spin := 0.0
var audio: AudioStreamPlayer3D


class HitBox extends AnimatableBody3D:
	var heli
	func take_hit(dmg: float, from, pos: Vector3) -> void:
		heli.take_hit(dmg, from, pos)


func setup(g) -> void:
	game = g
	name = "PoliceHeli"
	var navy := Color(0.12, 0.16, 0.3)
	var white := Color(0.92, 0.92, 0.95)
	var glass := Color(0.1, 0.14, 0.2)
	var mi := MeshInstance3D.new()
	mi.mesh = Util.merge([
		[Util.sphere(1.3, 12), Util.xf(Vector3(0, 0, 0), Vector3.ZERO, Vector3(1.0, 0.95, 1.6)), navy],
		[Util.sphere(1.0, 10), Util.xf(Vector3(0, 0.2, -1.1), Vector3.ZERO, Vector3(0.95, 0.8, 1.0)), glass],
		[Util.box(2.0, 0.25, 1.6), Util.xf(Vector3(0, -0.55, 0.3)), white],
		[Util.cyl(0.25, 0.4, 4.2, 8), Util.xf(Vector3(0, 0.35, 3.2), Vector3(PI * 0.5, 0, 0)), navy],
		[Util.box(0.1, 1.2, 0.8), Util.xf(Vector3(0, 0.9, 5.1)), white],
		[Util.box(0.1, 0.1, 2.6), Util.xf(Vector3(-0.8, -1.35, 0)), Color(0.2, 0.2, 0.2)],
		[Util.box(0.1, 0.1, 2.6), Util.xf(Vector3(0.8, -1.35, 0)), Color(0.2, 0.2, 0.2)],
		[Util.box(0.08, 0.5, 0.08), Util.xf(Vector3(-0.8, -1.1, -0.6)), Color(0.2, 0.2, 0.2)],
		[Util.box(0.08, 0.5, 0.08), Util.xf(Vector3(0.8, -1.1, -0.6)), Color(0.2, 0.2, 0.2)],
		[Util.box(0.08, 0.5, 0.08), Util.xf(Vector3(-0.8, -1.1, 0.6)), Color(0.2, 0.2, 0.2)],
		[Util.box(0.08, 0.5, 0.08), Util.xf(Vector3(0.8, -1.1, 0.6)), Color(0.2, 0.2, 0.2)],
	])
	mi.material_override = Util.vc_mat(0.4, 0.3)
	add_child(mi)
	rotor = Node3D.new()
	rotor.position = Vector3(0, 1.45, 0)
	add_child(rotor)
	var rm := MeshInstance3D.new()
	rm.mesh = Util.merge([
		[Util.box(10.0, 0.06, 0.35), Util.xf(Vector3.ZERO), Color(0.15, 0.15, 0.15)],
		[Util.box(0.35, 0.06, 10.0), Util.xf(Vector3.ZERO), Color(0.15, 0.15, 0.15)],
		[Util.cyl(0.25, 0.25, 0.4, 8), Util.xf(Vector3(0, -0.2, 0)), Color(0.3, 0.3, 0.3)],
	])
	rm.material_override = Util.vc_mat(0.5)
	rotor.add_child(rm)
	tail_rotor = Node3D.new()
	tail_rotor.position = Vector3(0.15, 0.9, 5.2)
	add_child(tail_rotor)
	var tm := MeshInstance3D.new()
	tm.mesh = Util.box(0.05, 1.6, 0.15)
	tm.material_override = Util.mat(Color(0.15, 0.15, 0.15))
	tail_rotor.add_child(tm)
	light = SpotLight3D.new()
	light.position = Vector3(0, -1.0, -1.0)
	light.spot_range = 90.0
	light.spot_angle = 12.0
	light.light_energy = 14.0
	light.light_color = Color(1.0, 0.97, 0.9)
	light.shadow_enabled = false
	add_child(light)
	hitbox = HitBox.new()
	hitbox.heli = self
	hitbox.collision_layer = 2
	hitbox.collision_mask = 0
	hitbox.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.6, 2.6, 5.0)
	cs.shape = sh
	cs.position = Vector3(0, 0, 1.0)
	hitbox.add_child(cs)
	add_child(hitbox)
	audio = AudioStreamPlayer3D.new()
	audio.stream = game.sfx.streams.get("rotor")
	audio.unit_size = 25.0
	audio.max_distance = 260.0
	audio.volume_db = -4.0
	add_child(audio)
	audio.play()


func take_hit(dmg: float, from, pos: Vector3) -> void:
	if dead:
		return
	health -= dmg
	game.fx.spark(pos)
	if from == game.player:
		game.police.on_cop_car_shot()
	if health <= 0.0:
		dead = true
		fall_spin = 3.0
		vel = Vector3(vel.x, -2.0, vel.z)
		game.hud.notice("Police chopper going down!")
		game.post("heli")
		if from == game.player:
			game.crime(120.0, global_position, false)


func _physics_process(delta: float) -> void:
	rotor.rotation.y += delta * 28.0
	tail_rotor.rotation.x += delta * 40.0
	if dead:
		vel.y -= 12.0 * delta
		global_position += vel * delta
		rotation.y += fall_spin * delta
		rotation.z = lerpf(rotation.z, 0.6, delta)
		if global_position.y < 1.5:
			game.explode(global_position, 10.0, true)
			game.stats.cars_destroyed += 1
			queue_free()
		return
	var pp: Vector3 = game.player_pos()
	var target: Vector3
	if leaving:
		target = global_position + Vector3(0, 30, 0) + (global_position - pp).normalized() * 60.0
		if global_position.distance_to(pp) > 300.0:
			queue_free()
			return
	else:
		angle += delta * 0.35
		target = pp + Vector3(cos(angle) * 30.0, 48.0, sin(angle) * 30.0)
	var to := target - global_position
	var want := to.limit_length(26.0)
	vel = vel.lerp(want, minf(1.0, delta * 1.2))
	global_position += vel * delta
	var flat := Vector3(vel.x, 0, vel.z)
	if flat.length() > 1.0:
		rotation.y = lerp_angle(rotation.y, Util.yaw_of(flat), delta * 2.0)
	rotation.x = clampf(-flat.length() * 0.012, -0.3, 0.0)
	# searchlight and gunner
	var aim := pp - light.global_position
	if aim.length() > 0.1:
		light.global_transform = Transform3D(Util.look_basis(aim), light.global_position)
	light.visible = game.night > 0.3 and not leaving
	shoot_cd -= delta
	if not leaving and shoot_cd <= 0.0 and game.state == "play":
		shoot_cd = game.rng.randf_range(1.4, 2.4)
		if global_position.distance_to(pp) < 90.0:
			game.heli_shoot(self, pp)


func sees(pos: Vector3) -> bool:
	return not dead and not leaving and Vector2(pos.x - global_position.x, pos.z - global_position.z).length() < 95.0
