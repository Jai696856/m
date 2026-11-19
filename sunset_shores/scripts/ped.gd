extends CharacterBody3D
## A pedestrian, police officer, bodyguard or mission target.
## Walkers loop around the sidewalks of a block and sometimes cross the street.

const Humanoid := preload("res://scripts/humanoid.gd")
const Util := preload("res://scripts/util.gd")

enum {WALK, FLEE, FLY, DOWN, DEAD, CHASE, IDLE}

const SHIRTS := [Color(0.9, 0.3, 0.3), Color(0.2, 0.5, 0.85), Color(0.95, 0.85, 0.3), Color(0.3, 0.7, 0.4),
	Color(0.95, 0.95, 0.95), Color(0.15, 0.15, 0.18), Color(0.95, 0.5, 0.7), Color(0.5, 0.35, 0.75), Color(1.0, 0.6, 0.25)]
const PANTS := [Color(0.2, 0.25, 0.4), Color(0.15, 0.15, 0.17), Color(0.75, 0.68, 0.5), Color(0.4, 0.3, 0.25), Color(0.9, 0.9, 0.88)]
const SKINS := [Color(0.98, 0.8, 0.66), Color(0.86, 0.64, 0.48), Color(0.65, 0.45, 0.3), Color(0.45, 0.3, 0.2), Color(0.95, 0.75, 0.6)]
const HAIR := [Color(0.1, 0.07, 0.05), Color(0.35, 0.22, 0.1), Color(0.85, 0.7, 0.4), Color(0.6, 0.6, 0.6), Color(0.55, 0.15, 0.1)]

var game
var model
var state := WALK
var role := "ped"
var health := 40.0
var walk_speed := 1.4
var target := Vector3.ZERO
var block := Vector2i.ZERO
var corner := 0
var dir := 1
var flee_from := Vector3.ZERO
var timer := 0.0
var fly_vel := Vector3.ZERO
var spin := Vector3.ZERO
var shoot_cd := 1.5
var armed := false
var alerted := false
var mission := false
var hit_by_player := false
var los := false
var los_cd := 0.0
var speed_now := 0.0


func setup(g, role_ := "ped") -> void:
	game = g
	role = role_
	collision_layer = 8
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 1.0
	add_child(cs)
	model = Humanoid.new()
	add_child(model)
	var r: RandomNumberGenerator = game.rng
	match role:
		"cop":
			model.build(Color(0.15, 0.22, 0.42), Color(0.1, 0.11, 0.16), SKINS[r.randi() % SKINS.size()], HAIR[0], {"cap": Color(0.1, 0.13, 0.25)})
			health = 70.0
			walk_speed = 1.6
			armed = true
		"guard":
			model.build(Color(0.12, 0.12, 0.14), Color(0.12, 0.12, 0.14), SKINS[r.randi() % SKINS.size()], HAIR[0], {})
			health = 90.0
			armed = true
		"target":
			model.build(Color(0.95, 0.95, 0.92), Color(0.95, 0.95, 0.92), SKINS[r.randi() % SKINS.size()], HAIR[3], {"shoes": Color(0.5, 0.3, 0.15)})
			health = 60.0
		_:
			model.build(SHIRTS[r.randi() % SHIRTS.size()], PANTS[r.randi() % PANTS.size()], SKINS[r.randi() % SKINS.size()],
				HAIR[r.randi() % HAIR.size()], {"hair_style": r.randi() % 2})
			walk_speed = r.randf_range(1.2, 1.7)
	model.show_gun(armed)


func is_alive() -> bool:
	return state != DEAD and state != FLY and state != DOWN


func _physics_process(delta: float) -> void:
	match state:
		WALK:
			_walk(delta)
		FLEE:
			_flee(delta)
		FLY:
			_fly(delta)
		DOWN:
			timer -= delta
			if timer <= 0.0:
				model.reset_pose()
				flee(game.player_pos())
		DEAD:
			timer += delta
		CHASE:
			_chase(delta)
		IDLE:
			model.animate(delta, 0.0, alerted and armed)
			_idle_check()


func _move(v: Vector3, delta: float, aiming := false) -> void:
	velocity = v
	move_and_slide()
	var p := global_position
	p.y = game.city.ground_height(p)
	global_position = p
	speed_now = v.length()
	if speed_now > 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, Util.yaw_of(v), minf(1.0, delta * 10.0))
	model.animate(delta, speed_now, aiming)


func _walk(delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.6:
		_next_target()
		to = target - global_position
		to.y = 0.0
	_move(to.normalized() * walk_speed, delta)


func _next_target() -> void:
	var city = game.city
	var s: Vector2i = city.CORNERS[corner]
	if game.rng.randf() < 0.3:
		var opts := []
		var nx := Vector2i(block.x + s.x, block.y)
		if nx.x >= 0 and nx.x < city.N:
			opts.append([nx, Vector2i(-s.x, s.y)])
		var nz := Vector2i(block.x, block.y + s.y)
		if nz.y >= 0 and nz.y < city.N:
			opts.append([nz, Vector2i(s.x, -s.y)])
		if not opts.is_empty():
			var o: Array = opts[game.rng.randi() % opts.size()]
			block = o[0]
			corner = city.CORNERS.find(o[1])
			target = city.ring_corner(block, corner)
			return
	corner = (corner + dir + 4) % 4
	target = city.ring_corner(block, corner)


func start_walking() -> void:
	var city = game.city
	block = city.block_of(global_position)
	corner = city.nearest_corner(block, global_position)
	dir = 1 if game.rng.randf() < 0.5 else -1
	target = city.ring_corner(block, corner)
	state = WALK


func flee(from: Vector3) -> void:
	if state == DEAD or state == FLY or state == DOWN:
		return
	if role == "cop" or role == "guard":
		alerted = true
		state = CHASE
		return
	flee_from = from
	timer = game.rng.randf_range(5.0, 8.0) if role != "target" else 60.0
	state = FLEE


func _flee(delta: float) -> void:
	timer -= delta
	var away := global_position - flee_from
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(game.rng.randf_range(-1, 1), 0, game.rng.randf_range(-1, 1))
	var d := away.normalized()
	d = d.rotated(Vector3.UP, sin(Time.get_ticks_msec() * 0.001 + get_instance_id()) * 0.4)
	_move(d * (4.6 if role != "target" else 4.0), delta)
	if timer <= 0.0:
		start_walking()


func _fly(delta: float) -> void:
	fly_vel.y -= 20.0 * delta
	global_position += fly_vel * delta
	model.rotation += spin * delta
	var gh: float = game.city.ground_height(global_position)
	if global_position.y <= gh and fly_vel.y < 0.0:
		global_position.y = gh
		model.rotation = Vector3(0, model.rotation.y, 0)
		if health <= 0.0:
			die()
		else:
			state = DOWN
			timer = 2.5
			model.set_dead()


func _los_to(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), p + Vector3(0, 1.0, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _chase(delta: float) -> void:
	if role == "cop" and game.police.wanted == 0:
		alerted = false
		start_walking()
		return
	if game.state != "play":
		_move(Vector3.ZERO, delta)
		return
	var pp: Vector3 = game.player_pos()
	var to := pp - global_position
	to.y = 0.0
	var d := to.length()
	los_cd -= delta
	if los_cd <= 0.0:
		los_cd = 0.3
		los = _los_to(pp)
	var v := Vector3.ZERO
	if d > 14.0 or not los:
		v = to.normalized() * 4.3
	elif d > 1.6 and role == "cop" and game.player.in_car == null:
		v = to.normalized() * (3.0 if game.police.wanted <= 1 else 1.5)
	_move(v, delta, los and d < 35.0)
	if d > 0.1 and v.length() < 0.1:
		model.rotation.y = lerp_angle(model.rotation.y, Util.yaw_of(to), minf(1.0, delta * 10.0))
	shoot_cd -= delta
	var may_shoot: bool = role == "guard" or game.police.wanted >= 2 or game.player.in_car != null
	if armed and may_shoot and los and d < 34.0 and shoot_cd <= 0.0:
		shoot_cd = game.rng.randf_range(0.8, 1.5)
		game.npc_shoot(self, pp)


func _idle_check() -> void:
	if alerted:
		return
	var d: float = global_position.distance_to(game.player_pos())
	if d < 22.0:
		alert_group()


func alert_group() -> void:
	for p in game.peds.peds:
		if is_instance_valid(p) and p.mission and p.state == IDLE:
			p.alerted = true
			if p.role == "guard":
				p.state = CHASE
			else:
				p.flee(game.player_pos())


func take_hit(dmg: float, from, pos: Vector3) -> void:
	if state == DEAD:
		return
	health -= dmg
	game.fx.blood(pos)
	var by_player: bool = from == game.player
	if by_player:
		hit_by_player = true
	if mission:
		alert_group()
	if health <= 0.0:
		die()
	else:
		if by_player:
			game.crime(25.0 if role != "cop" else 60.0, global_position, role != "cop")
		flee(from.global_position if from is Node3D else pos)


func hit_by_car(car, speed: float) -> void:
	if state == FLY or state == DEAD:
		return
	state = FLY
	fly_vel = car.linear_velocity * 0.8 + Vector3.UP * (2.5 + speed * 0.15)
	spin = Vector3(game.rng.randf_range(-6, 6), game.rng.randf_range(-3, 3), game.rng.randf_range(-6, 6))
	health -= speed * 5.0
	game.sfx.play("thud", global_position, 0.0)
	if car.driver == game.player:
		hit_by_player = true
		game.crime(20.0 if role != "cop" else 60.0, global_position, role != "cop")
	if mission:
		alert_group()


func die() -> void:
	if state == DEAD:
		return
	state = DEAD
	timer = 0.0
	health = 0.0
	collision_layer = 0
	model.set_dead()
	if hit_by_player:
		game.stats.kills += 1
		game.crime(150.0 if role == "cop" else 60.0, global_position, role != "cop")
	if role == "ped" and game.rng.randf() < 0.35:
		game.pickups.spawn("cash", global_position + Vector3(0.6, 0, 0), game.rng.randi_range(10, 60))
	if role in ["cop", "guard"] and game.rng.randf() < 0.5:
		game.pickups.spawn("smg", global_position + Vector3(-0.5, 0, 0.3), 30)
	game.peds.alert(global_position, 25.0)
