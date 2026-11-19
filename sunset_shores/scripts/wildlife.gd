extends Node3D
## Swamp wildlife: alligators that guard their pools and charge anyone on foot
## who gets too close, and flamingos that take off when startled.

const Util := preload("res://scripts/util.gd")


class Gator extends CharacterBody3D:
	enum {IDLE, CHASE, DEAD}
	var game
	var home := Vector3.ZERO
	var state := IDLE
	var health := 90.0
	var target := Vector3.ZERO
	var wait := 0.0
	var bite_cd := 0.0
	var tail: Node3D
	var body_node: Node3D
	var t := 0.0
	var dead_t := 0.0

	func setup(g, h: Vector3) -> void:
		game = g
		home = h
		collision_layer = 8
		collision_mask = 1
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(0.8, 0.5, 3.4)
		cs.shape = b
		cs.position = Vector3(0, 0.35, 0.2)
		add_child(cs)
		var skin := Color(0.2, 0.26, 0.14)
		var belly := Color(0.55, 0.55, 0.38)
		body_node = Node3D.new()
		add_child(body_node)
		var parts := [
			[Util.box(0.75, 0.32, 1.9), Util.xf(Vector3(0, 0.26, 0)), skin],
			[Util.box(0.7, 0.08, 1.8), Util.xf(Vector3(0, 0.1, 0)), belly],
			[Util.box(0.52, 0.26, 0.6), Util.xf(Vector3(0, 0.25, -1.2)), skin],
			[Util.box(0.36, 0.14, 0.75), Util.xf(Vector3(0, 0.2, -1.85)), skin],
			[Util.box(0.34, 0.04, 0.7), Util.xf(Vector3(0, 0.12, -1.85)), Color(0.9, 0.88, 0.75)],
			[Util.sphere(0.07, 6), Util.xf(Vector3(-0.17, 0.4, -1.3)), Color(0.85, 0.75, 0.2)],
			[Util.sphere(0.07, 6), Util.xf(Vector3(0.17, 0.4, -1.3)), Color(0.85, 0.75, 0.2)],
		]
		for k in 6:
			parts.append([Util.box(0.12, 0.1, 0.18), Util.xf(Vector3(-0.18 if k % 2 == 0 else 0.18, 0.46, -0.7 + k * 0.28)), skin.darkened(0.2)])
		for sx in [-1.0, 1.0]:
			for sz in [-0.65, 0.6]:
				parts.append([Util.box(0.4, 0.12, 0.18), Util.xf(Vector3(sx * 0.5, 0.1, sz), Vector3(0, sx * 0.4, 0)), skin])
		var mi := MeshInstance3D.new()
		mi.mesh = Util.merge(parts)
		mi.material_override = Util.vc_mat(0.75)
		mi.visibility_range_end = 160.0
		body_node.add_child(mi)
		tail = Node3D.new()
		tail.position = Vector3(0, 0.25, 0.95)
		body_node.add_child(tail)
		var tm := MeshInstance3D.new()
		tm.mesh = Util.merge([
			[Util.box(0.5, 0.26, 0.9), Util.xf(Vector3(0, 0, 0.45)), skin],
			[Util.box(0.32, 0.18, 0.9), Util.xf(Vector3(0, -0.03, 1.3)), skin],
			[Util.box(0.16, 0.12, 0.7), Util.xf(Vector3(0, -0.05, 2.0)), skin],
			[Util.box(0.06, 0.12, 1.6), Util.xf(Vector3(0, 0.15, 1.0)), skin.darkened(0.2)],
		])
		tm.material_override = Util.vc_mat(0.75)
		tm.visibility_range_end = 160.0
		tail.add_child(tm)
		target = home

	func is_alive() -> bool:
		return state != DEAD

	func _physics_process(delta: float) -> void:
		t += delta
		if state == DEAD:
			dead_t += delta
			return
		var p = game.player
		var pp: Vector3 = p.global_position
		if global_position.distance_to(pp) > 160.0:
			return
		bite_cd -= delta
		var v := Vector3.ZERO
		var on_foot: bool = p.in_car == null and not p.dead and game.state == "play"
		if state == IDLE:
			if on_foot and global_position.distance_to(pp) < 10.0 and pp.distance_to(home) < 40.0:
				state = CHASE
				game.sfx.play("thud", global_position, -4.0, 0.6)
				game.post("gator")
			else:
				wait -= delta
				if wait <= 0.0:
					wait = randf_range(4.0, 10.0)
					target = home + Vector3(randf_range(-12, 12), 0, randf_range(-12, 12))
				var to := target - global_position
				to.y = 0.0
				if to.length() > 1.0:
					v = to.normalized() * 0.7
		elif state == CHASE:
			var to := pp - global_position
			to.y = 0.0
			if not on_foot or pp.distance_to(home) > 55.0:
				state = IDLE
				target = home
			elif to.length() > 1.9:
				v = to.normalized() * 5.2
			else:
				if bite_cd <= 0.0:
					bite_cd = 1.1
					p.take_damage(16.0)
					game.sfx.play("thud", global_position, 2.0, 1.4)
					game.cam.add_shake(0.25)
				body_node.rotation.y = lerp_angle(body_node.rotation.y, Util.yaw_of(to), minf(1.0, delta * 8.0))
		velocity = v
		move_and_slide()
		global_position.y = 0.0
		if v.length() > 0.1:
			body_node.rotation.y = lerp_angle(body_node.rotation.y, Util.yaw_of(v), minf(1.0, delta * 5.0))
		tail.rotation.y = sin(t * (2.0 + v.length() * 2.0)) * (0.15 + v.length() * 0.06)

	func take_hit(dmg: float, from, _pos: Vector3) -> void:
		if state == DEAD:
			return
		health -= dmg
		game.fx.blood(global_position + Vector3.UP * 0.4)
		if health <= 0.0:
			die()
		elif from == game.player:
			state = CHASE

	func hit_by_car(_car, speed: float) -> void:
		take_hit(speed * 6.0, null, global_position)

	func die() -> void:
		state = DEAD
		collision_layer = 0
		body_node.rotation.z = PI
		body_node.position.y = 0.55
		tail.rotation = Vector3.ZERO


class Flamingo extends Node3D:
	enum {STAND, FLY, GONE}
	var game
	var home := Vector3.ZERO
	var state := STAND
	var t := 0.0
	var vel := Vector3.ZERO
	var gone_t := 0.0
	var wing_l: Node3D
	var wing_r: Node3D
	var neck: Node3D

	func setup(g, h: Vector3) -> void:
		game = g
		home = h
		t = randf() * 10.0
		var pink := Color(1.0, 0.5, 0.62)
		var leg := Color(0.95, 0.45, 0.5)
		var mi := MeshInstance3D.new()
		mi.mesh = Util.merge([
			[Util.sphere(0.3, 10), Util.xf(Vector3(0, 1.0, 0), Vector3.ZERO, Vector3(0.75, 0.7, 1.35)), pink],
			[Util.box(0.12, 0.08, 0.3), Util.xf(Vector3(0, 1.08, 0.42), Vector3(-0.3, 0, 0)), pink.darkened(0.15)],
			[Util.cyl(0.015, 0.02, 0.95, 4), Util.xf(Vector3(0, 0.48, 0)), leg],
			[Util.cyl(0.015, 0.02, 0.5, 4), Util.xf(Vector3(0.08, 0.72, 0.12), Vector3(1.2, 0, 0)), leg],
		])
		mi.material_override = Util.vc_mat(0.7)
		mi.visibility_range_end = 120.0
		add_child(mi)
		neck = Node3D.new()
		neck.position = Vector3(0, 1.15, -0.3)
		add_child(neck)
		var nm := MeshInstance3D.new()
		nm.mesh = Util.merge([
			[Util.cyl(0.04, 0.05, 0.45, 5), Util.xf(Vector3(0, 0.2, -0.05), Vector3(-0.3, 0, 0)), pink],
			[Util.cyl(0.035, 0.04, 0.35, 5), Util.xf(Vector3(0, 0.52, -0.02), Vector3(0.35, 0, 0)), pink],
			[Util.sphere(0.07, 6), Util.xf(Vector3(0, 0.7, -0.06)), pink],
			[Util.box(0.04, 0.05, 0.16), Util.xf(Vector3(0, 0.66, -0.17), Vector3(0.6, 0, 0)), Color(0.12, 0.12, 0.12)],
		])
		nm.material_override = Util.vc_mat(0.7)
		nm.visibility_range_end = 120.0
		neck.add_child(nm)
		wing_l = _wing(-1.0, pink)
		wing_r = _wing(1.0, pink)
		rotation.y = randf() * TAU

	func _wing(side: float, pink: Color) -> Node3D:
		var n := Node3D.new()
		n.position = Vector3(side * 0.18, 1.08, 0)
		add_child(n)
		var mi := MeshInstance3D.new()
		mi.mesh = Util.merge([
			[Util.box(0.7, 0.03, 0.4), Util.xf(Vector3(side * 0.35, 0, 0)), pink],
			[Util.box(0.22, 0.032, 0.4), Util.xf(Vector3(side * 0.6, 0, 0.02)), Color(0.1, 0.1, 0.1)],
		])
		mi.material_override = Util.vc_mat(0.7)
		n.add_child(mi)
		n.rotation.z = -side * 1.4
		return n

	func startle(from: Vector3) -> void:
		if state != STAND:
			return
		state = FLY
		var away := global_position - from
		away.y = 0.0
		if away.length() < 0.1:
			away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		vel = away.normalized() * 7.0 + Vector3.UP * 3.0
		rotation.y = Util.yaw_of(away)
		game.post("flamingo")

	func _process(delta: float) -> void:
		t += delta
		match state:
			STAND:
				neck.rotation.x = maxf(0.0, sin(t * 0.4)) * 1.2
				var p = game.player
				var d: float = global_position.distance_to(game.player_pos())
				var fast: bool = p.in_car != null and absf(p.in_car.forward_speed()) > 6.0
				if d < 6.0 or (fast and d < 18.0):
					startle(game.player_pos())
			FLY:
				vel.y = minf(vel.y + delta * 2.0, 5.0)
				global_position += vel * delta
				var flap := sin(t * 14.0) * 0.9
				wing_l.rotation.z = flap
				wing_r.rotation.z = -flap
				neck.rotation.x = -0.9
				if global_position.y > 60.0:
					state = GONE
					visible = false
					gone_t = 0.0
			GONE:
				gone_t += delta
				if gone_t > 45.0 and home.distance_to(game.player_pos()) > 80.0:
					state = STAND
					visible = true
					global_position = home
					wing_l.rotation.z = 1.4
					wing_r.rotation.z = -1.4


var game
var gators: Array = []
var flamingos: Array = []


func setup(g) -> void:
	game = g
	name = "Wildlife"
	var homes: Array = g.city.gator_homes
	for k in mini(homes.size(), 14):
		var gt := Gator.new()
		add_child(gt)
		gt.setup(g, homes[k])
		gt.global_position = homes[k] + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		gt.body_node.rotation.y = randf() * TAU
		gators.append(gt)
	for spot in g.city.flamingo_spots:
		var f := Flamingo.new()
		add_child(f)
		f.setup(g, spot)
		f.global_position = spot
		flamingos.append(f)


func alert(pos: Vector3, radius: float) -> void:
	for f in flamingos:
		if f.state == Flamingo.STAND and f.global_position.distance_to(pos) < radius:
			f.startle(pos)


func _physics_process(_delta: float) -> void:
	# cars run gators over
	for c in game.all_cars():
		if not is_instance_valid(c) or c.mode == c.TRAFFIC:
			continue
		var spd: float = c.linear_velocity.length()
		if spd < 4.0 or c.global_position.x < game.city.WET_X - 20.0:
			continue
		var inv: Transform3D = c.global_transform.affine_inverse()
		for gt in gators:
			if gt.state == Gator.DEAD or gt.global_position.distance_squared_to(c.global_position) > 30.0:
				continue
			var l: Vector3 = inv * gt.global_position
			if absf(l.x) < float(c.spec.w) * 0.5 + 0.5 and absf(l.z) < float(c.spec.l) * 0.5 + 1.0:
				gt.hit_by_car(c, spd)
	# bring dead gators back once the player has left the area
	for gt in gators:
		if gt.state == Gator.DEAD and gt.dead_t > 60.0 and gt.global_position.distance_to(game.player_pos()) > 150.0:
			gt.state = Gator.IDLE
			gt.health = 90.0
			gt.dead_t = 0.0
			gt.collision_layer = 8
			gt.body_node.rotation.z = 0.0
			gt.body_node.position.y = 0.0
			gt.global_position = gt.home


func get_blips() -> Array:
	var out := []
	var pp: Vector3 = game.player_pos()
	for gt in gators:
		if gt.state == Gator.CHASE and gt.global_position.distance_to(pp) < 60.0:
			out.append([gt.global_position, Color(0.4, 0.8, 0.3), "gator"])
	return out
