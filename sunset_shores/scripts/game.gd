extends Node3D
## Sunset Shores: entry point. Builds the world and owns the shared game state
## (money, time of day, wanted/wasted/busted flow) that the other systems use.

const City := preload("res://scripts/city.gd")
const Player := preload("res://scripts/player.gd")
const CameraRig := preload("res://scripts/camera_rig.gd")
const Traffic := preload("res://scripts/traffic.gd")
const Peds := preload("res://scripts/peds.gd")
const Police := preload("res://scripts/police.gd")
const Missions := preload("res://scripts/missions.gd")
const Hud := preload("res://scripts/hud.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Pickups := preload("res://scripts/pickups.gd")
const Fx := preload("res://scripts/fx.gd")
const Car := preload("res://scripts/car.gd")

const DAY_MINUTES := 16.0
const RESPRAY_COST := 250
const RESPRAY_COLORS := [Color(0.7, 0.08, 0.08), Color(0.1, 0.22, 0.55), Color(0.08, 0.08, 0.09),
	Color(0.92, 0.92, 0.9), Color(0.1, 0.5, 0.3), Color(0.95, 0.55, 0.1), Color(0.55, 0.2, 0.6)]

var city
var player
var cam
var traffic
var peds
var police
var missions
var hud
var sfx
var pickups
var fx
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var rng := RandomNumberGenerator.new()
var money := 500
var hour := 16.0
var night := 0.0
var time_flow := 1.0
var state := "play"
var state_ms := 0
var hint := ""
var headless := false
var respray_cd := 0.0
var stats := {"kills": 0, "cars_stolen": 0, "cars_destroyed": 0, "missions": 0}


func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"
	rng.randomize()
	_setup_input()
	_setup_environment()
	sfx = Sfx.new()
	add_child(sfx)
	sfx.setup(self)
	fx = Fx.new()
	fx.game = self
	add_child(fx)
	city = City.new()
	city.name = "City"
	add_child(city)
	city.build(self)
	hud = Hud.new()
	add_child(hud)
	traffic = Traffic.new()
	add_child(traffic)
	traffic.setup(self)
	peds = Peds.new()
	add_child(peds)
	peds.setup(self)
	player = Player.new()
	add_child(player)
	player.setup(self)
	player.global_position = city.spawn_point
	player.model.rotation.y = city.spawn_yaw
	cam = CameraRig.new()
	add_child(cam)
	cam.setup(self)
	police = Police.new()
	add_child(police)
	police.setup(self)
	pickups = Pickups.new()
	add_child(pickups)
	pickups.setup(self)
	missions = Missions.new()
	add_child(missions)
	missions.setup(self)
	hud.setup(self)
	traffic.initial_spawn()
	peds.initial_spawn()
	_update_time(0.0)
	if headless:
		hud.intro.visible = false
	else:
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- input --------------------------------------------------------------------------

func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e


func _mouse(b: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = b
	return e


func _joy(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e


func _axis(a: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	return e


func _setup_input() -> void:
	var map := {
		"move_forward": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"move_back": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"jump": [_key(KEY_SPACE), _joy(JOY_BUTTON_A)],
		"handbrake": [_key(KEY_SPACE), _joy(JOY_BUTTON_A)],
		"sprint": [_key(KEY_SHIFT), _joy(JOY_BUTTON_LEFT_STICK)],
		"enter_exit": [_key(KEY_F), _key(KEY_ENTER), _joy(JOY_BUTTON_Y)],
		"fire": [_mouse(MOUSE_BUTTON_LEFT), _joy(JOY_BUTTON_RIGHT_SHOULDER)],
		"aim": [_mouse(MOUSE_BUTTON_RIGHT), _joy(JOY_BUTTON_LEFT_SHOULDER)],
		"next_weapon": [_key(KEY_Q), _mouse(MOUSE_BUTTON_WHEEL_UP), _mouse(MOUSE_BUTTON_WHEEL_DOWN), _joy(JOY_BUTTON_DPAD_RIGHT)],
		"reset_car": [_key(KEY_R), _joy(JOY_BUTTON_DPAD_UP)],
		"horn": [_key(KEY_H), _joy(JOY_BUTTON_RIGHT_STICK)],
		"map": [_key(KEY_M), _joy(JOY_BUTTON_BACK)],
		"radio": [_key(KEY_T), _joy(JOY_BUTTON_DPAD_LEFT)],
		"pause": [_key(KEY_ESCAPE), _key(KEY_P), _joy(JOY_BUTTON_START)],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		for e in map[action]:
			InputMap.action_add_event(action, e)


# --- world look ------------------------------------------------------------------------

func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.65
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_density = 0.0011
	env.fog_sun_scatter = 0.15
	env.fog_aerial_perspective = 0.35
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.05
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.shadow_blur = 1.5
	add_child(sun)


func _ss(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


func _update_time(delta: float) -> void:
	hour = fmod(hour + delta * 24.0 / (DAY_MINUTES * 60.0) * time_flow, 24.0)
	var day_t := (hour - 6.0) / 12.0
	var sun_h := sin(day_t * PI)
	night = 1.0 - _ss(-0.12, 0.1, sun_h)
	var night_top := Color(0.01, 0.015, 0.05)
	var night_hor := Color(0.05, 0.06, 0.13)
	var dusk_top := Color(0.2, 0.2, 0.45)
	var dusk_hor := Color(0.98, 0.56, 0.36)
	var day_top := Color(0.2, 0.44, 0.85)
	var day_hor := Color(0.68, 0.8, 0.93)
	var top: Color
	var hor: Color
	if sun_h < 0.0:
		var k := _ss(-0.25, 0.0, sun_h)
		top = night_top.lerp(dusk_top, k)
		hor = night_hor.lerp(dusk_hor, k)
	else:
		var k := _ss(0.04, 0.5, sun_h)
		top = dusk_top.lerp(day_top, k)
		hor = dusk_hor.lerp(day_hor, k)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", hor)
	sky_mat.set_shader_parameter("ground_color", hor.darkened(0.6))
	sky_mat.set_shader_parameter("star_amount", smoothstep(0.7, 1.0, night))
	sky_mat.set_shader_parameter("cloud_color", Color(1, 1, 1).lerp(hor.lightened(0.2), 0.6).lerp(Color(0.12, 0.12, 0.18), night))
	if sun_h > -0.06:
		var elev := maxf(sun_h, 0.02) * deg_to_rad(68.0)
		var az := lerpf(deg_to_rad(80.0), deg_to_rad(-80.0), clampf(day_t, 0.0, 1.0))
		sun.rotation = Vector3(-elev, az, 0)
		sun.light_energy = _ss(-0.06, 0.18, sun_h) * 1.35
		sun.light_color = Color(1.0, 0.62, 0.38).lerp(Color(1.0, 0.96, 0.9), _ss(0.05, 0.45, sun_h))
	else:
		sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(30.0), 0)
		sun.light_energy = _ss(-0.06, -0.3, sun_h) * 0.22
		sun.light_color = Color(0.6, 0.7, 1.0)
	env.ambient_light_energy = lerpf(1.0, 0.5, night)
	env.ambient_light_color = Color(0.55, 0.6, 0.7).lerp(Color(0.2, 0.25, 0.45), night)
	env.fog_light_color = hor.lerp(Color(0.62, 0.66, 0.72), 0.45).lerp(Color(0.05, 0.06, 0.12), night * 0.7)
	env.tonemap_exposure = lerpf(1.0, 1.25, night)
	RenderingServer.global_shader_parameter_set("night", night)
	city.set_night(night)
	Car.set_night(night)


# --- main loop ----------------------------------------------------------------------------

func _process(delta: float) -> void:
	_update_time(delta)
	if state != "play" and Time.get_ticks_msec() - state_ms > 4500:
		_respawn()


func _physics_process(delta: float) -> void:
	hint = ""
	respray_cd -= delta
	if state != "play" or player.in_car == null:
		return
	var c = player.in_car
	var d := Vector2(c.global_position.x - city.respray_pos.x, c.global_position.z - city.respray_pos.z).length()
	if d < 7.0:
		if police.wanted > 0 and respray_cd <= 0.0:
			if money >= RESPRAY_COST:
				money -= RESPRAY_COST
				police.clear()
				c.repaint(RESPRAY_COLORS[rng.randi() % RESPRAY_COLORS.size()])
				c.health = 100.0
				if c.fire:
					c.fire.emitting = false
				if c.smoke:
					c.smoke.emitting = false
				hud.big_message("RESPRAYED", "-$%d  New paint, no heat" % RESPRAY_COST, Color(1.0, 0.3, 0.85), 3.0)
				sfx.play("pass", null, -4.0)
				respray_cd = 6.0
			else:
				hint = "A respray costs $%d" % RESPRAY_COST
		elif police.wanted == 0:
			hint = "Respray shop: come back when the cops are after you ($%d)" % RESPRAY_COST


func player_pos() -> Vector3:
	if player == null:
		return Vector3.ZERO
	if player.in_car:
		return player.in_car.global_position
	return player.global_position


func all_cars() -> Array:
	var out: Array = traffic.cars.duplicate()
	out.append_array(police.cars)
	return out


func get_blips() -> Array:
	var out := []
	out.append([city.hospital_pos, Color(1, 0.3, 0.3), "hospital"])
	out.append([city.respray_pos, Color(1, 0.3, 0.85), "respray"])
	out.append_array(pickups.get_blips())
	out.append_array(police.get_blips())
	out.append_array(missions.get_blips())
	return out


func add_money(amount: int, popup := true) -> void:
	money += amount
	if popup:
		hud.notice("+$%d" % amount)


# --- events ------------------------------------------------------------------------------

func crime(amount: float, pos: Vector3, need_witness := true) -> void:
	if state != "play":
		return
	if need_witness and peds.count_near(pos, 45.0) == 0 and not police.unit_near(pos, 70.0):
		return
	police.add_heat(amount)


func gunshot(pos: Vector3, by_player: bool) -> void:
	peds.alert(pos, 38.0)
	if by_player:
		crime(4.0, pos)


func npc_shoot(shooter, target_pos: Vector3) -> void:
	var from: Vector3 = shooter.global_position + Vector3(0, 1.45, 0)
	var aim := target_pos + Vector3(0, 1.0, 0)
	var chance: float = 0.28 + 0.06 * police.wanted
	if shooter.role == "guard":
		chance = 0.35
	var hit := rng.randf() < chance
	var end := aim if hit else aim + Vector3(rng.randf_range(-2, 2), rng.randf_range(-0.5, 1.5), rng.randf_range(-2, 2))
	end = from + (end - from) * 1.15
	var q := PhysicsRayQueryParameters3D.create(from, end, 1 | 2 | 4)
	q.exclude = [shooter.get_rid()]
	var res := get_world_3d().direct_space_state.intersect_ray(q)
	var stop: Vector3 = res.position if not res.is_empty() else end
	fx.tracer(from + (end - from).normalized() * 0.6, stop, Color(1.0, 0.7, 0.4))
	sfx.play("pistol", from, -6.0, rng.randf_range(0.9, 1.1))
	if not res.is_empty():
		var c = res.collider
		var dmg: float = 7.0 + police.wanted * 1.5
		if c == player:
			player.take_hit(dmg, shooter, stop)
		elif c == player.in_car:
			player.take_hit(dmg, shooter, stop)
		elif c != null and c.has_method("take_hit") and c is Car:
			c.take_hit(dmg, shooter, stop)
		else:
			fx.impact(stop)
	peds.alert(from, 20.0)


func explode(pos: Vector3, radius: float, by_player: bool, source = null) -> void:
	fx.explosion(pos)
	sfx.play("explosion", pos, 6.0)
	var cd: float = cam.global_position.distance_to(pos)
	cam.add_shake(clampf(1.2 - cd / 50.0, 0.0, 1.0))
	if player.in_car == null and not player.dead:
		var d: float = player.global_position.distance_to(pos)
		if d < radius:
			player.velocity += (player.global_position - pos).normalized() * 8.0 + Vector3.UP * 5.0
			player.knock_t = 1.0
			player.take_damage(110.0 * (1.0 - d / radius))
	for p in peds.peds.duplicate():
		if not is_instance_valid(p) or not p.is_alive():
			continue
		var d: float = p.global_position.distance_to(pos)
		if d < radius:
			p.health -= 200.0 * (1.0 - d / radius)
			p.hit_by_player = p.hit_by_player or by_player
			p.state = p.FLY
			p.fly_vel = (p.global_position - pos).normalized() * 9.0 + Vector3.UP * 7.0
			p.spin = Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
	for c in all_cars():
		if not is_instance_valid(c) or c == source or c.dead:
			continue
		var d: float = c.global_position.distance_to(pos)
		if d < radius * 1.3:
			if c.mode == Car.TRAFFIC:
				traffic.release(c)
			c.sleeping = false
			c.apply_central_impulse(((c.global_position - pos).normalized() + Vector3.UP) * c.mass * 4.0 * (1.0 - d / (radius * 1.3)))
			c.damage(90.0 * (1.0 - d / (radius * 1.3)), by_player)
	peds.alert(pos, 60.0)
	if by_player:
		crime(50.0, pos, false)


func on_car_crash(car, dv: float) -> void:
	if car == player.in_car:
		traffic.on_player_crash(car)
		police.on_player_crash(car, dv)
		cam.add_shake(clampf(dv / 30.0, 0.0, 0.6))
		if dv > 22.0:
			player.take_damage((dv - 22.0) * 2.0)


func player_died() -> void:
	if state != "play":
		return
	state = "wasted"
	state_ms = Time.get_ticks_msec()
	Engine.time_scale = 0.35
	hud.big_message("WASTED", "", Color(0.85, 0.1, 0.1), 4.5)
	sfx.play("fail")
	missions.fail("You were wasted.")


func player_busted() -> void:
	if state != "play":
		return
	state = "busted"
	state_ms = Time.get_ticks_msec()
	Engine.time_scale = 0.5
	if player.in_car == null:
		player.model.set_hands_up()
	hud.big_message("BUSTED", "", Color(0.3, 0.55, 1.0), 4.5)
	sfx.play("fail")
	missions.fail("You were busted.")


func _respawn() -> void:
	Engine.time_scale = 1.0
	var busted := state == "busted"
	var fee := mini(money, 100 + money / 20)
	money -= fee
	police.reset()
	if busted:
		player.weapons[1].ammo = 0
		player.weapon = 0
	var pos: Vector3 = city.station_pos if busted else city.hospital_pos
	player.respawn_at(pos)
	cam.yaw = 0.0
	cam.snap()
	state = "play"
	hour = fmod(hour + 6.0, 24.0)
	hud.notice(("Lawyer fees" if busted else "Hospital bill") + ": -$%d" % fee + ("   (SMG confiscated)" if busted else ""))
