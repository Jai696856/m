extends Node3D
## Civilian cars. Traffic drives kinematically along lane "rails" between
## intersections and turns on smooth curves. A traffic car becomes a real physics
## car when the player steals it or crashes into it. Also owns every parked or
## abandoned civilian car.

const Car := preload("res://scripts/car.gd")
const Util := preload("res://scripts/util.gd")


class Agent:
	var car
	var a := Vector2i.ZERO
	var b := Vector2i.ZERO
	var c := Vector2i.ZERO
	var turning := false
	var p0 := Vector3.ZERO
	var p1 := Vector3.ZERO
	var p2 := Vector3.ZERO
	var t := 0.0
	var length := 1.0
	var speed := 0.0
	var max_speed := 12.0
	var stuck := 0.0
	var ignore := 0.0
	var honk_cd := 0.0
	var by_player := 0.0
	var vel := Vector3.ZERO


const TARGET := 26
const TYPES := ["sedan", "sedan", "sedan", "compact", "compact", "suv", "suv", "taxi", "pickup", "van", "sport"]
const COLORS := [Color(0.92, 0.92, 0.9), Color(0.08, 0.08, 0.09), Color(0.6, 0.62, 0.65), Color(0.35, 0.36, 0.38),
	Color(0.7, 0.08, 0.08), Color(0.1, 0.22, 0.55), Color(0.1, 0.32, 0.2), Color(0.75, 0.68, 0.52),
	Color(0.4, 0.06, 0.1), Color(0.0, 0.45, 0.5), Color(0.95, 0.55, 0.1), Color(0.55, 0.75, 0.9)]

var game
var city
var cars: Array = []
var agents := {}
var rng := RandomNumberGenerator.new()
var spawn_cd := 0.0
var cleanup_cd := 0.0
var _obs_cars := PackedVector3Array()
var _obs_people := PackedVector3Array()


func setup(g) -> void:
	game = g
	city = g.city
	name = "Traffic"
	rng.randomize()


func color_for(t: String) -> Color:
	if t == "taxi":
		return Color(1.0, 0.78, 0.1)
	if t == "police":
		return Color(0.95, 0.95, 0.97)
	if t == "sport" and rng.randf() < 0.5:
		return [Color(1.0, 0.85, 0.1), Color(0.95, 0.2, 0.5), Color(0.2, 0.85, 0.9), Color(0.95, 0.3, 0.1)][rng.randi() % 4]
	return COLORS[rng.randi() % COLORS.size()]


func spawn_car(t: String, color: Color, xf: Transform3D):
	var c := Car.new()
	c.setup(game, t, color)
	add_child(c)
	c.global_transform = xf
	cars.append(c)
	return c


func initial_spawn() -> void:
	for s in city.parking_spots:
		var t: String = s[1]
		if t == "":
			t = TYPES[rng.randi() % TYPES.size()]
		var c = spawn_car(t, color_for(t), s[0])
		c.home_spot = true
	for i in TARGET:
		_spawn_traffic(20.0, 280.0)


# --- lanes ----------------------------------------------------------------------

func _lane_pt(a: Vector2i, b: Vector2i, at_start: bool) -> Vector3:
	var A: Vector3 = city.nodev(a)
	var B: Vector3 = city.nodev(b)
	var d := (B - A).normalized()
	var r := Vector3(-d.z, 0, d.x)
	var inset: float = city.ROAD * 0.5 + 1.0
	return (A + d * inset if at_start else B - d * inset) + r * city.LANE_OFF


func _pick_next(a: Vector2i, b: Vector2i) -> Vector2i:
	var opts: Array[Vector2i] = []
	var straight := b + (b - a)
	for n in city.neighbors(b):
		if n == a:
			continue
		opts.append(n)
		if n == straight:
			opts.append(n)
	if opts.is_empty():
		return a
	return opts[rng.randi() % opts.size()]


func _set_straight(ag: Agent) -> void:
	ag.turning = false
	ag.p0 = _lane_pt(ag.a, ag.b, true)
	ag.p2 = _lane_pt(ag.a, ag.b, false)
	ag.p1 = (ag.p0 + ag.p2) * 0.5
	ag.length = ag.p0.distance_to(ag.p2)


func _set_turn(ag: Agent) -> void:
	ag.turning = true
	ag.p0 = _lane_pt(ag.a, ag.b, false)
	ag.p2 = _lane_pt(ag.b, ag.c, true)
	var d1 := ag.b - ag.a
	if ag.c - ag.b == d1:
		ag.p1 = (ag.p0 + ag.p2) * 0.5
		ag.length = ag.p0.distance_to(ag.p2)
	else:
		if d1.x != 0:
			ag.p1 = Vector3(ag.p2.x, 0, ag.p0.z)
		else:
			ag.p1 = Vector3(ag.p0.x, 0, ag.p2.z)
		ag.length = (ag.p0.distance_to(ag.p1) + ag.p1.distance_to(ag.p2)) * 0.88


func _eval(ag: Agent) -> Vector3:
	var t := ag.t
	if not ag.turning:
		return ag.p0.lerp(ag.p2, t)
	var u := 1.0 - t
	return ag.p0 * u * u + ag.p1 * 2.0 * u * t + ag.p2 * t * t


func _tangent(ag: Agent) -> Vector3:
	var d: Vector3
	if not ag.turning:
		d = ag.p2 - ag.p0
	else:
		d = (ag.p1 - ag.p0) * 2.0 * (1.0 - ag.t) + (ag.p2 - ag.p1) * 2.0 * ag.t
	if d.length_squared() < 0.0001:
		d = ag.p2 - ag.p0
	return d.normalized()


func _is_turn_next(ag: Agent) -> bool:
	return ag.c - ag.b != ag.b - ag.a


# --- spawning -------------------------------------------------------------------

func _too_close(pos: Vector3, r: float) -> bool:
	for c in cars:
		if is_instance_valid(c) and c.global_position.distance_squared_to(pos) < r * r:
			return true
	return false


func _spawn_traffic(min_d: float, max_d: float) -> bool:
	var pp: Vector3 = game.player_pos()
	for attempt in 10:
		var a := Vector2i(rng.randi_range(0, city.N), rng.randi_range(0, city.N))
		var nb: Array[Vector2i] = city.neighbors(a)
		var ag := Agent.new()
		ag.a = a
		ag.b = nb[rng.randi() % nb.size()]
		ag.c = _pick_next(ag.a, ag.b)
		_set_straight(ag)
		ag.t = rng.randf_range(0.05, 0.85)
		var pos := _eval(ag)
		var d := pos.distance_to(pp)
		if d < min_d or d > max_d or _too_close(pos, 14.0):
			continue
		var t: String = TYPES[rng.randi() % TYPES.size()]
		var car = spawn_car(t, color_for(t), Transform3D(Util.look_basis(_tangent(ag)), pos))
		car.make_traffic()
		ag.car = car
		ag.max_speed = rng.randf_range(10.0, 15.0)
		ag.speed = ag.max_speed * 0.7
		agents[car] = ag
		return true
	return false


func _physics_process(delta: float) -> void:
	var pp: Vector3 = game.player_pos()
	_build_obstacles()
	var gone := []
	for car in agents.keys():
		if not is_instance_valid(car):
			gone.append(car)
			continue
		_drive(agents[car], delta)
		if car.global_position.distance_to(pp) > 320.0:
			gone.append(car)
	for car in gone:
		_despawn(car)
	spawn_cd -= delta
	if agents.size() < TARGET and spawn_cd <= 0.0:
		spawn_cd = 0.25
		_spawn_traffic(120.0, 260.0)
	cleanup_cd -= delta
	if cleanup_cd <= 0.0:
		cleanup_cd = 2.0
		_cleanup(pp)


func _cleanup(pp: Vector3) -> void:
	for c in cars.duplicate():
		if not is_instance_valid(c):
			cars.erase(c)
			continue
		if agents.has(c) or c.mission or c == game.player.in_car:
			continue
		var d: float = c.global_position.distance_to(pp)
		if (not c.home_spot and d > 350.0) or (c.dead and (c.dead_t > 90.0 or d > 200.0)):
			_despawn(c)


func _despawn(car) -> void:
	agents.erase(car)
	cars.erase(car)
	if is_instance_valid(car):
		car.queue_free()


func _build_obstacles() -> void:
	_obs_cars.clear()
	_obs_people.clear()
	for c in game.all_cars():
		if is_instance_valid(c):
			_obs_cars.append(c.global_position)
	var p = game.player
	if p.in_car == null and not p.dead:
		_obs_people.append(p.global_position)
	for ped in game.peds.peds:
		if is_instance_valid(ped) and ped.is_alive():
			_obs_people.append(ped.global_position)


func _blocked(pos: Vector3, fwd: Vector3, include_cars: bool) -> Vector2:
	# returns (distance to nearest obstacle ahead or -1, 1 if it is a person)
	var best := -1.0
	var person := 0.0
	if include_cars:
		for o in _obs_cars:
			var to := o - pos
			to.y = 0.0
			var d2 := to.length_squared()
			if d2 < 0.25 or d2 > 256.0:
				continue
			var d := sqrt(d2)
			if fwd.dot(to) / d > 0.55 and absf(fwd.cross(to).y) < 2.4:
				if best < 0.0 or d < best:
					best = d
	for o in _obs_people:
		var to := o - pos
		to.y = 0.0
		var d2 := to.length_squared()
		if d2 > 196.0:
			continue
		var d := sqrt(d2)
		if d > 0.1 and fwd.dot(to) / d > 0.4 and absf(fwd.cross(to).y) < 2.2:
			if best < 0.0 or d < best:
				best = d
				person = 1.0
	return Vector2(best, person)


func _drive(ag: Agent, delta: float) -> void:
	var car = ag.car
	var pos: Vector3 = car.global_position
	var fwd := _tangent(ag)
	var desired := ag.max_speed
	if ag.turning and _is_turn_corner(ag):
		desired = minf(desired, 6.5)
	elif not ag.turning and (1.0 - ag.t) * ag.length < 16.0 and _is_turn_next(ag):
		desired = minf(desired, 8.0)
	ag.ignore -= delta
	ag.honk_cd -= delta
	var blk := _blocked(pos, fwd, ag.ignore <= 0.0)
	if blk.x >= 0.0:
		desired = minf(desired, maxf(0.0, (blk.x - 6.0) * 1.4))
		if blk.y > 0.5 and blk.x < 9.0:
			ag.by_player += delta
			if ag.by_player > 1.5 and ag.honk_cd <= 0.0:
				ag.honk_cd = rng.randf_range(2.5, 5.0)
				car.honk()
	else:
		ag.by_player = 0.0
	var acc := 10.0 if desired < ag.speed else 3.5
	ag.speed = move_toward(ag.speed, desired, acc * delta)
	if ag.speed < 0.3 and desired < 0.3 and blk.y < 0.5:
		ag.stuck += delta
	else:
		ag.stuck = 0.0
	if ag.stuck > 4.0:
		ag.ignore = 2.5
		ag.stuck = 0.0
	ag.t += ag.speed * delta / maxf(ag.length, 0.1)
	var guard := 0
	while ag.t >= 1.0 and guard < 3:
		guard += 1
		var over := (ag.t - 1.0) * ag.length
		if ag.turning:
			ag.a = ag.b
			ag.b = ag.c
			ag.c = _pick_next(ag.a, ag.b)
			_set_straight(ag)
		else:
			_set_turn(ag)
		ag.t = over / maxf(ag.length, 0.1)
	var tg := _tangent(ag)
	ag.vel = tg * ag.speed
	car.rail_move(Transform3D(Util.look_basis(tg), _eval(ag)), ag.speed)


func _is_turn_corner(ag: Agent) -> bool:
	return ag.c - ag.b != ag.b - ag.a


# --- events ----------------------------------------------------------------------

func release(car) -> void:
	if not agents.has(car):
		return
	var ag: Agent = agents[car]
	agents.erase(car)
	car.make_dynamic(ag.vel)


func carjack(car) -> void:
	var v := Vector3.ZERO
	if agents.has(car):
		v = (agents[car] as Agent).vel
		agents.erase(car)
	car.make_dynamic(v * 0.2)
	var side: Vector3 = car.global_transform.basis.x
	var p = game.peds.spawn_ped(car.global_position - side * 1.9 + Vector3(0, 0.05, 0), "ped")
	p.flee(game.player.global_position)
	game.sfx.play("door", car.global_position)
	if game.police.unit_near(car.global_position, 50.0):
		game.crime(60.0, car.global_position, false)


func on_player_crash(pcar) -> void:
	for car in agents.keys():
		if is_instance_valid(car) and car.global_position.distance_to(pcar.global_position) < 7.5:
			release(car)
			if rng.randf() < 0.5:
				var side: Vector3 = car.global_transform.basis.x
				var p = game.peds.spawn_ped(car.global_position - side * 1.9, "ped")
				p.flee(pcar.global_position)
