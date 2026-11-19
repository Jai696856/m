extends Node3D
## Keeps the sidewalks busy around the player, and knocks people down when a
## moving car hits them (the player included).

const Ped := preload("res://scripts/ped.gd")

var target := 42

var game
var city
var peds: Array = []
var rng := RandomNumberGenerator.new()
var spawn_cd := 0.0


func setup(g) -> void:
	game = g
	city = g.city
	name = "Peds"
	rng.randomize()


func spawn_ped(pos: Vector3, role := "ped"):
	var p := Ped.new()
	add_child(p)
	p.setup(game, role)
	p.global_position = pos
	p.model.rotation.y = rng.randf() * TAU
	peds.append(p)
	if role == "ped":
		p.start_walking()
	return p


func remove(p) -> void:
	peds.erase(p)
	if is_instance_valid(p):
		p.queue_free()


func initial_spawn() -> void:
	for i in target:
		_spawn_walker(8.0, 160.0)


func _walker_count() -> int:
	var n := 0
	for p in peds:
		if p.role == "ped" and not p.mission:
			n += 1
	return n


func _spawn_walker(min_d: float, max_d: float) -> void:
	var pp: Vector3 = game.player_pos()
	var pb: Vector2i = city.block_of(pp)
	for attempt in 8:
		var b := Vector2i(clampi(pb.x + rng.randi_range(-2, 2), 0, city.N - 1), clampi(pb.y + rng.randi_range(-2, 2), 0, city.N - 1))
		var k := rng.randi() % 4
		var pos: Vector3 = city.ring_corner(b, k).lerp(city.ring_corner(b, (k + 1) % 4), rng.randf())
		var d := pos.distance_to(pp)
		if d < min_d or d > max_d:
			continue
		var p = spawn_ped(pos)
		p.block = b
		if rng.randf() < 0.5:
			p.dir = 1
			p.corner = (k + 1) % 4
		else:
			p.dir = -1
			p.corner = k
		p.target = city.ring_corner(b, p.corner)
		return


func _physics_process(delta: float) -> void:
	var pp: Vector3 = game.player_pos()
	for p in peds.duplicate():
		if not is_instance_valid(p):
			peds.erase(p)
			continue
		if p.mission or p.role == "cop":
			continue
		var d: float = p.global_position.distance_to(pp)
		if d > 175.0 or (p.state == Ped.DEAD and p.timer > 30.0):
			remove(p)
	spawn_cd -= delta
	if spawn_cd <= 0.0 and _walker_count() < target:
		spawn_cd = 0.15
		_spawn_walker(70.0, 150.0)
	_car_hits()


func _car_hits() -> void:
	var movers := []
	for c in game.all_cars():
		if not is_instance_valid(c) or c.mode == c.TRAFFIC:
			continue
		var spd: float = c.linear_velocity.length()
		if spd > 3.0:
			movers.append([c, spd])
	if movers.is_empty():
		return
	var player = game.player
	for m in movers:
		var car = m[0]
		var spd: float = m[1]
		var inv: Transform3D = car.global_transform.affine_inverse()
		var half_l: float = float(car.spec.l) * 0.5 + 0.35
		var half_w: float = float(car.spec.w) * 0.5 + 0.35
		var cp: Vector3 = car.global_position
		for p in peds:
			if not is_instance_valid(p) or not p.is_alive():
				continue
			if p.global_position.distance_squared_to(cp) > 25.0:
				continue
			var l: Vector3 = inv * p.global_position
			if absf(l.x) < half_w and absf(l.z) < half_l and l.y > -1.5 and l.y < 2.0:
				p.hit_by_car(car, spd)
		if player.in_car == null and not player.dead and car != player.in_car:
			if player.global_position.distance_squared_to(cp) < 25.0:
				var l: Vector3 = inv * player.global_position
				if absf(l.x) < half_w and absf(l.z) < half_l and l.y > -1.5 and l.y < 2.0:
					player.hit_by_car(car, spd)


func alert(pos: Vector3, radius: float) -> void:
	for p in peds:
		if not is_instance_valid(p) or p.mission:
			continue
		if (p.state == Ped.WALK or p.state == Ped.IDLE) and p.global_position.distance_to(pos) < radius:
			if p.role == "ped":
				p.flee(pos)


func count_near(pos: Vector3, r: float) -> int:
	var n := 0
	for p in peds:
		if is_instance_valid(p) and p.role == "ped" and p.is_alive() and p.global_position.distance_squared_to(pos) < r * r:
			n += 1
	return n
