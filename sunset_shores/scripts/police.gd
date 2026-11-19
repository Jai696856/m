extends Node3D
## Wanted level (0-5 stars), police cars that chase along the road grid, officers
## on foot, busting the player, and losing the heat when out of sight.

const Car := preload("res://scripts/car.gd")
const Ped := preload("res://scripts/ped.gd")

const STAR_HEAT := [0.0, 0.01, 120.0, 300.0, 600.0, 1000.0]
const CARS_FOR := [0, 1, 2, 3, 4, 6]

var game
var city
var heat := 0.0
var wanted := 0
var unseen_t := 0.0
var cars: Array = []
var cops: Array = []
var data := {}
var spawn_cd := 0.0
var los_cd := 0.0
var seen := false
var bust_t := 0.0
var ram_cd := 0.0
var shot_cd := 0.0
var rng := RandomNumberGenerator.new()


func setup(g) -> void:
	game = g
	city = g.city
	name = "Police"
	rng.randomize()


func add_heat(amount: float) -> void:
	if game.state != "play":
		return
	heat += amount
	unseen_t = 0.0
	var old := wanted
	wanted = _stars_for(heat)
	if wanted > old:
		game.hud.flash_stars()
		spawn_cd = minf(spawn_cd, 1.5)


func set_min_stars(stars: int) -> void:
	if wanted < stars:
		add_heat(STAR_HEAT[stars] - heat + 1.0)


func _stars_for(h: float) -> int:
	var s := 0
	for i in range(1, 6):
		if h >= STAR_HEAT[i]:
			s = i
	return s


func searching() -> bool:
	return wanted > 0 and unseen_t > 1.5


func clear() -> void:
	heat = 0.0
	wanted = 0
	unseen_t = 0.0
	bust_t = 0.0
	for c in cars:
		if data.has(c):
			data[c].leave = true
			c.siren_on = false


func reset() -> void:
	clear()
	for c in cars:
		if is_instance_valid(c):
			c.queue_free()
	cars.clear()
	data.clear()
	for p in cops:
		game.peds.remove(p)
	cops.clear()


func unit_near(pos: Vector3, r: float) -> bool:
	for c in cars:
		if is_instance_valid(c) and not c.dead and c.global_position.distance_to(pos) < r:
			return true
	for p in cops:
		if is_instance_valid(p) and p.is_alive() and p.global_position.distance_to(pos) < r:
			return true
	return false


func on_player_crash(pcar, _dv: float) -> void:
	if ram_cd > 0.0:
		return
	for c in cars:
		if is_instance_valid(c) and c.global_position.distance_to(pcar.global_position) < 7.5:
			ram_cd = 2.0
			game.crime(25.0, pcar.global_position, false)
			return


func on_cop_car_shot() -> void:
	if shot_cd <= 0.0:
		shot_cd = 0.5
		game.crime(10.0, game.player_pos(), false)


func _los(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _physics_process(delta: float) -> void:
	ram_cd -= delta
	shot_cd -= delta
	if game.state != "play":
		return
	var pp: Vector3 = game.player_pos()
	los_cd -= delta
	if los_cd <= 0.0:
		los_cd = 0.35
		seen = false
		if wanted > 0:
			for u in cars + cops:
				if not is_instance_valid(u):
					continue
				if u is Car and (u.dead or (data.has(u) and data[u].leave)):
					continue
				if u is Ped and not u.is_alive():
					continue
				if u.global_position.distance_to(pp) < 75.0 and _los(u.global_position + Vector3.UP * 1.4, pp + Vector3.UP):
					seen = true
					break
	if wanted > 0:
		if seen:
			unseen_t = 0.0
		else:
			unseen_t += delta
		if unseen_t > 9.0 + wanted * 3.0:
			clear()
			game.hud.notice("You lost the cops.")
			game.sfx.play("pickup", null, -6.0)
		spawn_cd -= delta
		if _active_cars() < CARS_FOR[wanted] and spawn_cd <= 0.0:
			spawn_cd = 3.5
			_spawn_car(pp)
		_bust_check(delta, pp)
	for c in cars.duplicate():
		_ai(c, delta, pp)
	_cleanup(pp)


func _active_cars() -> int:
	var n := 0
	for c in cars:
		if is_instance_valid(c) and not c.dead and data.has(c) and not data[c].leave:
			n += 1
	return n


func _spawn_car(pp: Vector3) -> void:
	for attempt in 20:
		var n := Vector2i(rng.randi_range(0, city.N), rng.randi_range(0, city.N))
		var np: Vector3 = city.nodev(n)
		var d := np.distance_to(pp)
		if d < 110.0 or d > 210.0:
			continue
		var best := n
		var bd := INF
		for m in city.neighbors(n):
			var md: float = city.nodev(m).distance_to(pp)
			if md < bd:
				bd = md
				best = m
		var dir: Vector3 = (city.nodev(best) - np).normalized()
		var right := Vector3(-dir.z, 0, dir.x)
		var pos: Vector3 = np + dir * 14.0 + right * city.LANE_OFF
		var c := Car.new()
		c.setup(game, "police", Color(0.95, 0.95, 0.97))
		add_child(c)
		c.global_transform = Transform3D(Basis(Vector3.UP, atan2(-dir.x, -dir.z)), pos + Vector3.UP * 0.1)
		c.set_driver(self)
		c.siren_on = true
		cars.append(c)
		data[c] = {"wp": best, "prev": n, "stuck": 0.0, "rev": 0.0, "deployed": false, "leave": false,
			"life": 0.0, "los": false, "los_cd": 0.0}
		return


func _drop(c) -> void:
	data.erase(c)
	cars.erase(c)
	if is_instance_valid(c):
		c.siren_on = false
		if not c.dead and c.driver != self:
			game.traffic.cars.append(c)
			c.reparent(game.traffic)
		elif c.dead:
			game.traffic.cars.append(c)
			c.reparent(game.traffic)


func _road_wp(c, d: Dictionary, goal: Vector3) -> Vector3:
	var cp: Vector3 = c.global_position
	var wp: Vector2i = d.wp
	var wpos: Vector3 = city.nodev(wp)
	if cp.distance_to(wpos) < 10.0:
		var best := wp
		var bd := INF
		for n in city.neighbors(wp):
			if n == d.prev:
				continue
			var dd: float = city.nodev(n).distance_to(goal)
			if dd < bd:
				bd = dd
				best = n
		d.prev = wp
		d.wp = best
		wpos = city.nodev(best)
	return wpos


func _ai(c, delta: float, pp: Vector3) -> void:
	if not is_instance_valid(c):
		cars.erase(c)
		data.erase(c)
		return
	if c.dead or c.driver != self or not data.has(c):
		_drop(c)
		return
	var d: Dictionary = data[c]
	d.life += delta
	var cp: Vector3 = c.global_position
	var to_player := cp.distance_to(pp)
	var player_in_car: bool = game.player.in_car != null
	d.los_cd -= delta
	if d.los_cd <= 0.0:
		d.los_cd = 0.3
		d.los = _los(cp + Vector3.UP * 1.2, pp + Vector3.UP)
	var goal: Vector3
	if d.leave or wanted == 0:
		d.leave = true
		c.siren_on = false
		goal = _road_wp(c, d, cp + (cp - pp).normalized() * 400.0)
	elif to_player < 55.0 and d.los:
		goal = pp
		if player_in_car:
			goal += game.player.in_car.linear_velocity * clampf(to_player / 30.0, 0.0, 1.0)
	else:
		goal = _road_wp(c, d, pp)
	var local: Vector3 = c.global_transform.affine_inverse() * goal
	var ang := atan2(-local.x, -local.z)
	var steer := clampf(ang * 2.2, -1.0, 1.0)
	var accel := 1.0
	var spd: float = c.forward_speed()
	if d.leave:
		accel = 0.6
	if absf(ang) > 0.6 and spd > 13.0:
		accel = -0.5
	if not player_in_car and not d.leave and to_player < 20.0 and d.los:
		accel = -1.0 if spd > 1.0 else 0.0
		if absf(spd) < 3.0 and not d.deployed:
			_deploy(c)
			d.deployed = true
	if d.rev > 0.0:
		d.rev -= delta
		accel = -1.0
		steer = -steer
	elif accel > 0.3 and absf(spd) < 1.2:
		d.stuck += delta
		if d.stuck > 1.5:
			d.rev = 1.3
			d.stuck = 0.0
	else:
		d.stuck = maxf(0.0, d.stuck - delta)
	c.set_controls(accel, steer, false)


func _deploy(c) -> void:
	var side: Vector3 = c.global_transform.basis.x
	for s in [-1.0, 1.0]:
		var p = game.peds.spawn_ped(c.global_position + side * s * 2.0 + Vector3.UP * 0.05, "cop")
		p.alerted = true
		p.state = Ped.CHASE
		cops.append(p)


func _bust_check(delta: float, pp: Vector3) -> void:
	var p = game.player
	var close := false
	if p.in_car == null:
		var hs := Vector2(p.velocity.x, p.velocity.z).length()
		if hs < 3.6:
			for cop in cops:
				if is_instance_valid(cop) and cop.is_alive() and cop.global_position.distance_to(pp) < 2.3:
					close = true
	elif absf(p.in_car.forward_speed()) < 1.5:
		for c in cars:
			if is_instance_valid(c) and not c.dead and c.global_position.distance_to(pp) < 7.0:
				close = true
		for cop in cops:
			if is_instance_valid(cop) and cop.is_alive() and cop.global_position.distance_to(pp) < 3.5:
				close = true
	if close:
		bust_t += delta
		game.hint = "Move! You're about to get busted"
	else:
		bust_t = maxf(0.0, bust_t - delta * 0.5)
	if bust_t > (1.6 if p.in_car == null else 3.0):
		bust_t = 0.0
		game.player_busted()


func _cleanup(pp: Vector3) -> void:
	for c in cars.duplicate():
		if not is_instance_valid(c) or not data.has(c):
			continue
		var d: Dictionary = data[c]
		var dist: float = c.global_position.distance_to(pp)
		if dist > 330.0 or (d.leave and (dist > 140.0 or d.life > 60.0) and c != game.player.in_car):
			cars.erase(c)
			data.erase(c)
			c.queue_free()
	for p in cops.duplicate():
		if not is_instance_valid(p):
			cops.erase(p)
			continue
		var dist: float = p.global_position.distance_to(pp)
		if dist > 220.0 or (wanted == 0 and dist > 70.0) or (p.state == Ped.DEAD and p.timer > 30.0):
			cops.erase(p)
			game.peds.remove(p)


func get_blips() -> Array:
	var out := []
	var flash := fmod(Time.get_ticks_msec() * 0.004, 2.0) < 1.0
	for c in cars:
		if is_instance_valid(c) and not c.dead and data.has(c) and not data[c].leave:
			out.append([c.global_position, Color(1, 0.2, 0.2) if flash else Color(0.25, 0.45, 1.0), "police"])
	for p in cops:
		if is_instance_valid(p) and p.is_alive():
			out.append([p.global_position, Color(0.35, 0.55, 1.0), "cop"])
	return out
