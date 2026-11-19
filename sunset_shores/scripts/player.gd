extends CharacterBody3D
## The player: third-person movement, weapons, getting in and out of cars.

const Humanoid := preload("res://scripts/humanoid.gd")
const Car := preload("res://scripts/car.gd")
const Util := preload("res://scripts/util.gd")

const WALK := 3.4
const RUN := 7.4
const JUMP := 5.4
const GRAVITY := 18.0

var game
var model
var health := 100.0
var armor := 0.0
var in_car = null
var dead := false
var knock_t := 0.0
var fire_cd := 0.0
var aiming := false
var weapon := 0
var weapons := [
	{"name": "Pistol", "dmg": 34.0, "rate": 0.26, "ammo": -1, "auto": false, "spread": 0.01, "sound": "pistol"},
	{"name": "SMG", "dmg": 16.0, "rate": 0.085, "ammo": 0, "auto": true, "spread": 0.028, "sound": "smg"},
]
var hurt_flash := 0.0
var shape: CollisionShape3D
var near_car = null


func setup(g) -> void:
	game = g
	name = "Player"
	collision_layer = 4
	collision_mask = 1 | 2
	floor_max_angle = deg_to_rad(62.0)
	floor_snap_length = 0.4
	shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)
	model = Humanoid.new()
	add_child(model)
	model.build(Color(0.1, 0.62, 0.62), Color(0.16, 0.18, 0.26), Color(0.82, 0.6, 0.45), Color(0.12, 0.08, 0.05),
		{"shoes": Color(0.95, 0.95, 0.95)})
	model.show_gun(true)


func _physics_process(delta: float) -> void:
	fire_cd -= delta
	hurt_flash = maxf(0.0, hurt_flash - delta)
	near_car = null
	if dead:
		if in_car == null:
			velocity.x = move_toward(velocity.x, 0, 10 * delta)
			velocity.z = move_toward(velocity.z, 0, 10 * delta)
			velocity.y -= GRAVITY * delta
			move_and_slide()
		return
	if game.state != "play":
		return
	if in_car != null:
		_drive(delta)
		return
	_walk(delta)


func _walk(delta: float) -> void:
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := Basis(Vector3.UP, game.cam.yaw)
	var dir := cam_basis * Vector3(inp.x, 0, inp.y)
	aiming = Input.is_action_pressed("aim") or Input.is_action_pressed("fire")
	var spd := RUN if Input.is_action_pressed("sprint") and not aiming else WALK
	if knock_t > 0.0:
		knock_t -= delta
		dir = Vector3.ZERO
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
	else:
		var a := 32.0 if is_on_floor() else 6.0
		velocity.x = move_toward(velocity.x, dir.x * spd, a * delta)
		velocity.z = move_toward(velocity.z, dir.z * spd, a * delta)
	if is_on_floor():
		if Input.is_action_just_pressed("jump") and knock_t <= 0.0:
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	_step_up(delta)
	move_and_slide()
	var hs := Vector2(velocity.x, velocity.z).length()
	if knock_t > 0.0:
		model.rotation.x = lerpf(model.rotation.x, -1.2, minf(1.0, delta * 8.0))
	else:
		model.rotation.x = lerpf(model.rotation.x, 0.0, minf(1.0, delta * 8.0))
		if aiming:
			model.rotation.y = lerp_angle(model.rotation.y, game.cam.yaw, minf(1.0, 18.0 * delta))
		elif hs > 0.3:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-velocity.x, -velocity.z), minf(1.0, 12.0 * delta))
	model.animate(delta, hs, aiming)
	_weapons()
	_find_near_car()
	if Input.is_action_just_pressed("enter_exit") and knock_t <= 0.0:
		try_enter_vehicle()
	if global_position.y < -15.0:
		global_position = game.city.spawn_point
		velocity = Vector3.ZERO


## Climb curbs and other low ledges: if a short test move forward is blocked
## but the same move from a little higher is free, lift the player onto it.
func _step_up(delta: float) -> void:
	if not is_on_floor() or velocity.y > 0.1:
		return
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() < 0.3:
		return
	var motion := hv * delta + hv.normalized() * 0.08
	if not test_move(global_transform, motion):
		return
	var lift := Vector3(0, 0.32, 0)
	if test_move(global_transform, lift):
		return
	var raised := global_transform.translated(lift)
	if test_move(raised, motion):
		return
	global_position += lift
	global_position += hv.normalized() * 0.05
	apply_floor_snap()


func _drive(delta: float) -> void:
	var c = in_car
	var a := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var s := Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
	c.set_controls(a, s, Input.is_action_pressed("handbrake"))
	global_position = c.global_position
	if Input.is_action_just_pressed("enter_exit"):
		exit_car()
		return
	if Input.is_action_just_pressed("reset_car"):
		c.flip_upright()
	if Input.is_action_just_pressed("horn"):
		c.honk()
	if c.upside_down_t > 1.5:
		game.hint = "Press R to flip the car back over"
	_weapons()


func _weapons() -> void:
	if Input.is_action_just_pressed("next_weapon"):
		for k in weapons.size():
			weapon = (weapon + 1) % weapons.size()
			if weapons[weapon].ammo != 0:
				break
		game.sfx.play("click", null, -8.0)
	var w: Dictionary = weapons[weapon]
	if w.ammo == 0:
		weapon = 0
		w = weapons[0]
	var want: bool = Input.is_action_pressed("fire") if w.auto else Input.is_action_just_pressed("fire")
	if want and fire_cd <= 0.0:
		fire()


func fire() -> void:
	var w: Dictionary = weapons[weapon]
	if w.ammo == 0:
		return
	fire_cd = w.rate
	if w.ammo > 0:
		w.ammo -= 1
	var cam: Camera3D = game.cam.cam
	var dir := -cam.global_transform.basis.z
	var sp: float = w.spread
	dir = (dir + Vector3(randf_range(-sp, sp), randf_range(-sp, sp), randf_range(-sp, sp))).normalized()
	var origin := cam.global_position
	var me: Vector3 = (in_car.global_position if in_car else global_position) + Vector3.UP * 1.3
	origin += dir * maxf(0.0, (me - origin).dot(dir))
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 220.0, 1 | 2 | 8)
	var ex: Array[RID] = [get_rid()]
	if in_car:
		ex.append(in_car.get_rid())
	q.exclude = ex
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = hit.position if not hit.is_empty() else origin + dir * 220.0
	var muzzle: Vector3
	if in_car:
		muzzle = in_car.global_position + Vector3.UP * 1.6 + dir * 1.2
	else:
		muzzle = model.muzzle_position()
	game.fx.tracer(muzzle, end)
	game.fx.flash(muzzle)
	game.sfx.play(w.sound, muzzle, -3.0, randf_range(0.93, 1.07))
	if not hit.is_empty():
		var c = hit.collider
		if c != null and c.has_method("take_hit"):
			c.take_hit(w.dmg, self, hit.position)
		else:
			game.fx.impact(hit.position)
	game.gunshot(muzzle, true)
	game.cam.add_shake(0.05)


func _find_near_car() -> void:
	var bd := 4.2
	for c in game.all_cars():
		if not is_instance_valid(c) or c.dead or c.mode == Car.AI:
			continue
		var d: float = c.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			near_car = c
	if near_car:
		var verb := "steal" if near_car.mode == Car.TRAFFIC or near_car.is_police else "get in"
		game.hint = "Press F to %s the %s" % [verb, near_car.spec.name]


func try_enter_vehicle() -> bool:
	_find_near_car()
	if near_car == null:
		return false
	enter_car(near_car)
	return true


func enter_car(c) -> void:
	if c.mode == Car.TRAFFIC:
		game.traffic.carjack(c)
	elif c.is_police:
		game.crime(40.0, global_position, false)
	in_car = c
	c.set_driver(self)
	collision_layer = 0
	collision_mask = 0
	model.visible = false
	velocity = Vector3.ZERO
	knock_t = 0.0
	game.hud.show_vehicle(c.spec.name)
	game.sfx.play("door", c.global_position)
	game.stats.cars_stolen += 1


func exit_car() -> void:
	var c = in_car
	if c == null:
		return
	var spd: float = c.linear_velocity.length()
	var b: Basis = c.global_transform.basis
	var side := Vector3(b.x.x, 0, b.x.z).normalized()
	var base: Vector3 = c.global_position
	var spots := [base - side * 2.1, base + side * 2.1, base + Vector3(-b.z.x, 0, -b.z.z).normalized() * 3.6, base + Vector3.UP * 2.6]
	var pos: Vector3 = spots[spots.size() - 1]
	for s in spots:
		if _space_free(s, c):
			pos = s
			break
	c.set_driver(null)
	in_car = null
	collision_layer = 4
	collision_mask = 1 | 2
	model.visible = true
	global_position = pos + Vector3(0, 0.15, 0)
	model.rotation.y = Util.yaw_of(-b.z)
	if spd > 9.0:
		velocity = c.linear_velocity * 0.55
		knock_t = 1.0
		take_damage(4.0 + spd * 0.4)
	else:
		velocity = Vector3.ZERO
	game.sfx.play("door", pos)


func _space_free(pos: Vector3, car) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape.shape
	q.transform = Transform3D(Basis(), pos + Vector3(0, 1.0, 0))
	q.collision_mask = 1 | 2
	q.exclude = [car.get_rid(), get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func take_hit(dmg: float, from, _pos: Vector3) -> void:
	if dead:
		return
	if in_car:
		in_car.take_hit(dmg * 0.8, from, in_car.global_position + Vector3.UP)
		dmg *= 0.3
	take_damage(dmg)


func take_damage(dmg: float) -> void:
	if dead or game.state != "play":
		return
	if armor > 0.0:
		var absorbed := minf(armor, dmg * 0.75)
		armor -= absorbed
		dmg -= absorbed
	health -= dmg
	hurt_flash = 0.45
	if health <= 0.0:
		die()


func heal(amount: float) -> void:
	health = minf(100.0, health + amount)


func hit_by_car(car, speed: float) -> void:
	if in_car or dead or knock_t > 0.3:
		return
	knock_t = 1.3
	velocity = car.linear_velocity * 0.7 + Vector3.UP * (3.0 + speed * 0.1)
	game.sfx.play("thud", global_position)
	game.cam.add_shake(0.4)
	take_damage(speed * 3.2)


func die() -> void:
	if dead:
		return
	dead = true
	health = 0.0
	model.visible = true
	model.set_dead()
	game.player_died()


func die_in_car() -> void:
	var c = in_car
	if c:
		var side: Vector3 = c.global_transform.basis.x
		c.set_driver(null)
		in_car = null
		collision_layer = 4
		collision_mask = 1
		global_position = c.global_position - side * 2.4 + Vector3.UP * 0.3
	die()


func respawn_at(pos: Vector3) -> void:
	if in_car:
		in_car.set_driver(null)
		in_car = null
	collision_layer = 4
	collision_mask = 1 | 2
	dead = false
	health = 100.0
	knock_t = 0.0
	velocity = Vector3.ZERO
	model.visible = true
	model.reset_pose()
	model.rotation = Vector3(0, PI, 0)
	model.show_gun(true)
	global_position = pos + Vector3(0, 0.1, 0)
