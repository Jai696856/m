extends Node3D
## Third-person camera: orbit with the mouse, right stick or a thumb drag, a chase
## view that swings in behind the car when driving, and collision that never pops.
##
## The camera is kept out of walls with a sphere cast from the pivot (the player's
## head) back to where the camera wants to be. It pulls in at once when something
## is in the way but eases back out, so turning past palms, lamp posts and curbs no
## longer makes the view jump back and forth.

const Util := preload("res://scripts/util.gd")

const PITCH_MIN := -1.15
const PITCH_MAX := 0.3
const MAX_MOUSE_STEP := 90.0   # ignore pointer-lock spikes larger than this (pixels per event)

var game
var yaw := 0.0
var pitch := -0.22
var cam: Camera3D
var mouse_idle := 10.0
var shake := 0.0
var look_sens := 0.0032
var _len := 4.5
var _dist := 4.5
var _shoulder := 0.45
var _probe: SphereShape3D
var _query: PhysicsShapeQueryParameters3D


func setup(g) -> void:
	game = g
	name = "CameraRig"
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.1
	cam.far = 2200.0
	add_child(cam)
	cam.current = true
	_probe = SphereShape3D.new()
	_probe.radius = 0.3
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = _probe
	_query.collision_mask = 1
	yaw = game.city.spawn_yaw
	snap()


func snap() -> void:
	global_position = _follow_point()
	_dist = _len
	_place_camera(0.0, true)


func look(dx: float, dy: float) -> void:
	yaw -= dx
	pitch = clampf(pitch - dy, PITCH_MIN, PITCH_MAX)
	mouse_idle = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_look(event.screen_relative)


func mouse_look(rel: Vector2) -> void:
	if rel.length() > MAX_MOUSE_STEP:
		return  # browsers sometimes report a huge jump after pointer lock; drop it
	look(rel.x * look_sens, rel.y * look_sens)


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
		look(rs.x * delta * 2.6, rs.y * delta * 1.8)
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
	# looking up brings the camera in close instead of driving it into the ground
	if pitch > 0.0:
		target_len *= lerpf(1.0, 0.55, pitch / PITCH_MAX)
	_len = lerpf(_len, target_len, 1.0 - exp(-6.0 * delta))
	_shoulder = lerpf(_shoulder, shoulder, 1.0 - exp(-8.0 * delta))
	cam.fov = lerpf(cam.fov, fov, 1.0 - exp(-5.0 * delta))
	rotation = Vector3(pitch, yaw, 0)
	_place_camera(delta, false)
	shake = maxf(0.0, shake - delta * 1.8)
	var s := shake * shake
	cam.h_offset = _shoulder + randf_range(-1, 1) * s * 0.35
	cam.v_offset = randf_range(-1, 1) * s * 0.35


## Puts the camera _len metres behind the pivot, or closer if something solid is
## in between. Pulls in immediately, eases back out.
func _place_camera(delta: float, instant: bool) -> void:
	var back := global_transform.basis.z
	var want := _len
	if is_inside_tree():
		var space := get_world_3d().direct_space_state
		_query.transform = Transform3D(Basis(), global_position)
		_query.motion = back * _len
		var ex: Array[RID] = []
		if game.player.in_car:
			ex.append(game.player.in_car.get_rid())
		_query.exclude = ex
		var res := space.cast_motion(_query)
		if res.size() == 2 and res[0] < 1.0:
			want = maxf(0.35, _len * res[0])
	if instant or want < _dist:
		_dist = want
	else:
		_dist = move_toward(_dist, want, delta * 6.0)
	cam.position = Vector3(0, 0, _dist)


func _physics_process(delta: float) -> void:
	var target := _follow_point()
	if game.player.in_car:
		global_position = global_position.lerp(target, 1.0 - exp(-30.0 * delta))
	else:
		global_position = global_position.lerp(target, 1.0 - exp(-16.0 * delta))
