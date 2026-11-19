extends Node3D
## Third-person camera: orbit with the mouse or right stick, a spring arm that
## stops at walls, and a chase view that swings in behind the car when driving.

const Util := preload("res://scripts/util.gd")

var game
var yaw := 0.0
var pitch := -0.22
var arm: SpringArm3D
var cam: Camera3D
var mouse_idle := 10.0
var shake := 0.0
var look_sens := 0.0032
var _len := 4.5


func setup(g) -> void:
	game = g
	name = "CameraRig"
	arm = SpringArm3D.new()
	arm.collision_mask = 1
	arm.margin = 0.3
	var sh := SphereShape3D.new()
	sh.radius = 0.25
	arm.shape = sh
	arm.spring_length = 4.5
	add_child(arm)
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.1
	cam.far = 2200.0
	arm.add_child(cam)
	cam.current = true
	yaw = game.city.spawn_yaw
	snap()


func snap() -> void:
	global_position = _follow_point()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * look_sens
		pitch = clampf(pitch - event.relative.y * look_sens, -1.2, 0.6)
		mouse_idle = 0.0


func add_shake(amount: float) -> void:
	shake = minf(1.0, shake + amount)


func _follow_point() -> Vector3:
	var p = game.player
	if p.in_car:
		return p.in_car.global_position + Vector3(0, 1.7, 0)
	return p.global_position + Vector3(0, 1.55, 0)


func _process(delta: float) -> void:
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if rs.length() > 0.15:
		yaw -= rs.x * delta * 2.6
		pitch = clampf(pitch - rs.y * delta * 1.8, -1.2, 0.6)
		mouse_idle = 0.0
	mouse_idle += delta
	var p = game.player
	var target_len := 4.2
	var shoulder := 0.45
	var fov := 70.0
	if p.in_car:
		var car = p.in_car
		var spd: float = absf(car.forward_speed())
		var f: Vector3 = -car.global_transform.basis.z
		var car_yaw := Util.yaw_of(f)
		if car.forward_speed() < -3.0:
			car_yaw = Util.yaw_of(-f)
		if mouse_idle > 1.3 and spd > 2.0:
			yaw = lerp_angle(yaw, car_yaw, 1.0 - exp(-2.5 * delta))
			pitch = lerpf(pitch, -0.2, 1.0 - exp(-2.0 * delta))
		target_len = 7.5 + spd * 0.05 + (2.5 if car.type_id in ["van", "pickup", "suv"] else 0.0)
		shoulder = 0.0
		fov = 70.0 + clampf(spd - 10.0, 0.0, 40.0) * 0.5
	elif p.aiming:
		target_len = 2.4
		shoulder = 0.75
		fov = 60.0
	_len = lerpf(_len, target_len, 1.0 - exp(-6.0 * delta))
	arm.spring_length = _len
	arm.position = Vector3(shoulder, 0, 0)
	cam.fov = lerpf(cam.fov, fov, 1.0 - exp(-5.0 * delta))
	rotation = Vector3(pitch, yaw, 0)
	shake = maxf(0.0, shake - delta * 1.8)
	var s := shake * shake
	cam.h_offset = randf_range(-1, 1) * s * 0.35
	cam.v_offset = randf_range(-1, 1) * s * 0.35


func _physics_process(delta: float) -> void:
	var target := _follow_point()
	if game.player.in_car:
		global_position = global_position.lerp(target, 1.0 - exp(-30.0 * delta))
	else:
		global_position = global_position.lerp(target, 1.0 - exp(-16.0 * delta))
