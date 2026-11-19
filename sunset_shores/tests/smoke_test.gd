# Headless smoke test: plays Sunset Shores without a window.
#   godot --headless --path . -s tests/smoke_test.gd
# Exits with code 1 on any failure.
extends SceneTree

var failures: Array = []
var game


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures.append(msg)
		printerr("  FAIL ", msg)


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func _initialize() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await frames(5)
	print("world")
	check(game.city.kinds.size() == 64, "64 city blocks built")
	check(game.city.footprints.size() > 150, "buildings placed (%d)" % game.city.footprints.size())
	check(game.traffic.agents.size() >= 15, "traffic spawned (%d)" % game.traffic.agents.size())
	check(game.peds.peds.size() >= 20, "pedestrians spawned (%d)" % game.peds.peds.size())
	check(game.city.contact_points.size() == 3, "three mission contacts")
	await _test_walk()
	await _test_curb()
	await _test_drive()
	await _test_shooting()
	await _test_police_and_wasted()
	await _test_courier()
	await _test_race()
	await _test_explosion()
	await _test_long_run()
	await _test_crew_switch()
	await _test_wildlife()
	await _test_stunt_and_feed()
	_test_night()
	print("")
	if failures.is_empty():
		print("ALL PASSED")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % failures.size())
		quit(1)


func _test_walk() -> void:
	print("walking")
	var p = game.player
	var start: Vector3 = p.global_position
	Input.action_press("move_forward")
	await frames(60)
	Input.action_release("move_forward")
	check(p.global_position.distance_to(start) > 2.0, "player walks (%.1f m)" % p.global_position.distance_to(start))
	check(p.is_on_floor(), "player stays on the floor")


func _test_curb() -> void:
	print("curb")
	var p = game.player
	# stand on the road beside block (3,3) and walk east onto its sidewalk
	var c: Vector3 = game.city.block_center(3, 3)
	p.global_position = Vector3(c.x - 40.0 + 2.0, 0.05, c.z + 5.0)
	p.velocity = Vector3.ZERO
	game.cam.yaw = -PI * 0.5  # facing +X
	await frames(5)
	Input.action_press("move_forward")
	await frames(150)
	Input.action_release("move_forward")
	check(p.global_position.x > c.x - 32.0 + 1.0, "player steps up onto the sidewalk (x=%.1f)" % (p.global_position.x - (c.x - 32.0)))
	check(absf(p.global_position.y - game.city.CURB) < 0.08, "player stands at curb height (y=%.2f)" % p.global_position.y)


func _test_drive() -> void:
	print("driving")
	var p = game.player
	var car = null
	for c in game.traffic.cars:
		if c.type_id == "sport" and c.global_position.distance_to(Vector3(-326.5, 0, 24)) < 3.0:
			car = c
	check(car != null, "starter sports car parked on the beach road")
	if car == null:
		return
	p.global_position = car.global_position + Vector3(2.5, 0.1, 0)
	await frames(3)
	check(p.try_enter_vehicle(), "player can enter a nearby car")
	check(p.in_car == car, "player is in the sports car")
	await frames(10)
	Input.action_press("move_forward")
	await frames(240)
	var spd: float = car.forward_speed()
	check(spd > 18.0, "car accelerates (%.1f m/s after 4 s)" % spd)
	check(car.global_transform.basis.y.y > 0.9, "car stays upright under throttle")
	var yaw0: float = car.global_rotation.y
	Input.action_press("move_left")
	await frames(45)
	Input.action_release("move_left")
	check(absf(angle_difference(yaw0, car.global_rotation.y)) > 0.3, "car steers (%.2f rad)" % absf(angle_difference(yaw0, car.global_rotation.y)))
	check(car.global_transform.basis.y.y > 0.85, "car stays upright while turning")
	Input.action_release("move_forward")
	var before: float = absf(car.forward_speed())
	Input.action_press("move_back")
	await frames(90)
	Input.action_release("move_back")
	check(absf(car.forward_speed()) < before * 0.5, "car brakes (%.1f -> %.1f)" % [before, absf(car.forward_speed())])
	await frames(120)
	p.exit_car()
	check(p.in_car == null and p.model.visible, "player gets out")
	await frames(30)
	check(p.global_position.y > -1.0, "player is on the ground after exiting")
	# carjack a traffic car
	var tcar = game.traffic.agents.keys()[0]
	p.global_position = tcar.global_position + tcar.global_transform.basis.x * 2.6 + Vector3.UP * 0.2
	await frames(1)
	p.enter_car(tcar)
	check(p.in_car == tcar and tcar.mode == tcar.PLAYER, "carjacking a traffic car works")
	check(not game.traffic.agents.has(tcar), "stolen car leaves the traffic system")
	await frames(30)
	p.exit_car()
	await frames(10)


func _test_shooting() -> void:
	print("shooting")
	var p = game.player
	var bc: Vector3 = game.city.block_center(4, 4)
	p.global_position = Vector3(bc.x + 6.0, game.city.CURB + 0.1, bc.z - 27.0)
	game.cam.pitch = 0.0
	game.cam.yaw = 0.0
	await frames(20)
	var cam: Camera3D = game.cam.cam
	var fwd := -cam.global_transform.basis.z
	var aim_pt: Vector3 = cam.global_position + fwd * 9.0
	var target = game.peds.spawn_ped(aim_pt - Vector3(0, 1.0, 0), "ped")
	target.state = target.IDLE
	var witness = game.peds.spawn_ped(p.global_position + Vector3(4, 0, 4), "ped")
	witness.state = witness.IDLE
	await frames(2)
	var hp0: float = target.health
	for i in 3:
		# keep the target on the camera's current line of fire
		var f := -cam.global_transform.basis.z
		target.global_position = cam.global_position + f * 9.0 - Vector3(0, 1.0, 0)
		await frames(1)
		p.fire_cd = 0.0
		p.fire()
		await frames(2)
	check(target.health < hp0, "bullets hit a pedestrian (%.0f -> %.0f)" % [hp0, target.health])
	check(target.state == target.DEAD, "pedestrian goes down")
	check(game.police.wanted >= 1, "killing in front of a witness raises the wanted level (%d)" % game.police.wanted)


func _test_police_and_wasted() -> void:
	print("police")
	game.police.add_heat(200)
	check(game.police.wanted == 2, "200 heat is two stars")
	game.police.spawn_cd = 0.0
	await frames(240)
	check(game.police.cars.size() >= 1, "police cars spawn (%d)" % game.police.cars.size())
	var pc = game.police.cars[0] if game.police.cars.size() > 0 else null
	if pc:
		var d0: float = pc.global_position.distance_to(game.player_pos())
		await frames(300)
		if is_instance_valid(pc):
			var d1: float = pc.global_position.distance_to(game.player_pos())
			check(d1 < d0 or d1 < 25.0, "police car closes in (%.0f -> %.0f m)" % [d0, d1])
	print("wasted")
	game.player.take_damage(500)
	check(game.state == "wasted", "player is wasted at 0 health")
	var guard := 0
	while game.state != "play" and guard < 2000:
		await physics_frame
		guard += 1
	check(game.state == "play", "player respawns")
	check(game.player.health == 100.0 and not game.player.dead, "full health after respawn")
	check(game.police.wanted == 0 and game.police.cars.is_empty(), "wanted level cleared after respawn")
	check(game.player.global_position.distance_to(game.city.hospital_pos) < 3.0, "respawned at the hospital")
	check(Engine.time_scale == 1.0, "time scale restored")


func _test_courier() -> void:
	print("mission: courier")
	var m = game.missions
	var money0: int = game.money
	game.player.global_position = game.city.contact_points[0] + Vector3(0, 0.1, 0)
	m.start_cd = 0.0
	await frames(10)
	check(m.is_active() and m.active.def.type == "courier", "walking into Rosa's marker starts the courier job")
	if not m.is_active():
		return
	var car = m.active.car
	check(is_instance_valid(car) and car.type_id == "sport", "target car spawned")
	game.player.global_position = car.global_position + Vector3(0, 0.2, 0)
	game.player.enter_car(car)
	await frames(5)
	check(m.active.stage == 1, "stage 2 after getting in the target car")
	check(m.timer_left() > 0.0, "delivery timer running")
	car.global_transform = Transform3D(Basis(), m.active.drop + Vector3(0, 0.3, 0))
	car.linear_velocity = Vector3.ZERO
	await frames(30)
	check(not m.is_active(), "delivery completes the mission")
	check(game.money > money0, "reward paid ($%d -> $%d)" % [money0, game.money])
	check(m.index == 1, "story advances")
	game.player.exit_car()
	await frames(5)


func _test_race() -> void:
	print("mission: race")
	var m = game.missions
	m.start_cd = 0.0
	game.player.global_position = game.city.contact_points[1] + Vector3(0, 0.1, 0)
	await frames(10)
	check(m.is_active() and m.active.def.type == "race", "Dex's marker starts the race")
	if not m.is_active():
		return
	var start: Vector3 = m.active.start
	var car = game.traffic.spawn_car("sedan", Color.RED, Transform3D(Basis(), start + Vector3(0, 0.3, 0)))
	game.player.global_position = start + Vector3(2, 0.2, 0)
	game.player.enter_car(car)
	var guard := 0
	while m.is_active() and m.active.stage < 2 and guard < 400:
		await physics_frame
		guard += 1
	check(m.is_active() and m.active.stage == 2, "countdown finishes and the race starts")
	if not m.is_active():
		return
	var n: int = m.active.route.size()
	check(n == 8, "eight checkpoints")
	for i in n:
		var pt: Vector3 = game.city.nodev(m.active.route[i])
		car.global_transform = Transform3D(Basis(), pt + Vector3(0, 0.4, 0))
		car.linear_velocity = Vector3.ZERO
		await frames(4)
		if not m.is_active():
			break
	check(not m.is_active() and m.index == 2, "passing every checkpoint wins the race")
	game.player.exit_car()
	await frames(5)


func _test_explosion() -> void:
	print("explosions")
	var p = game.player
	var xf := Transform3D(Basis(), p.global_position + Vector3(30, 0.3, 0))
	var a = game.traffic.spawn_car("van", Color.GREEN, xf)
	var b = game.traffic.spawn_car("compact", Color.BLUE, xf.translated(Vector3(4.5, 0, 0)))
	await frames(20)
	a.damage(500)
	check(a.dead, "a car explodes at zero health")
	await frames(30)
	check(b.health < 100.0, "the blast damages a car next to it (%.0f)" % b.health)
	check(not p.dead, "player 30 m away survives")
	await frames(60)


func _test_long_run() -> void:
	print("long run (60 s of game time)")
	var p = game.player
	var car = game.traffic.spawn_car("sedan", Color.WHITE, Transform3D(Basis(), game.city.node_pos(4, 4) + Vector3(game.city.LANE_OFF, 0.3, -20)))
	p.global_position = car.global_position + Vector3(2, 0, 0)
	p.enter_car(car)
	Input.action_press("move_forward")
	var bad := 0
	for i in 3600:
		await physics_frame
		if i % 90 == 0:
			Input.action_press("move_left") if (i / 90) % 3 == 0 else Input.action_release("move_left")
		if i % 60 == 0:
			for c in game.all_cars():
				if is_instance_valid(c) and not c.global_position.is_finite():
					bad += 1
	Input.action_release("move_forward")
	Input.action_release("move_left")
	check(bad == 0, "no car ends up with an invalid position")
	check(game.traffic.agents.size() >= 15, "traffic keeps flowing (%d agents)" % game.traffic.agents.size())
	check(game.peds.peds.size() >= 15, "pedestrians keep spawning (%d)" % game.peds.peds.size())
	var moved := 0
	var snap := {}
	for c in game.traffic.agents.keys():
		snap[c] = c.global_position
	await frames(120)
	for c in snap:
		if is_instance_valid(c) and c.global_position.distance_to(snap[c]) > 3.0:
			moved += 1
	check(moved > snap.size() / 3, "most traffic is moving (%d of %d)" % [moved, snap.size()])


func _test_crew_switch() -> void:
	print("crew switch")
	var p = game.player
	if p.in_car:
		p.exit_car()
	game.police.reset()
	await frames(5)
	var here: Vector3 = p.global_position
	var there: Vector3 = p.partner_pos
	var name0: String = p.crew[p.hero].name
	check(p.switch_hero(), "can switch characters with no heat")
	await frames(3)
	check(p.crew[p.hero].name != name0, "now playing %s" % p.crew[p.hero].name)
	check(p.global_position.distance_to(there) < 1.0, "the camera jumps to the other character")
	check(p.partner_pos.distance_to(here) < 1.0, "the first character waits where they were")
	check(is_instance_valid(p.partner_model) and p.partner_model.is_inside_tree(), "the waiting partner is visible in the world")
	game.police.add_heat(10)
	check(not p.switch_hero(), "switching is blocked while wanted")
	game.police.reset()
	# Cole is tough
	p.hero = 1
	var hp0: float = p.health
	p.take_damage(20.0)
	check(absf((hp0 - p.health) - 15.0) < 0.01, "Cole takes 25% less damage")
	p.heal(100)


func _test_wildlife() -> void:
	print("wildlife")
	var w = game.wildlife
	check(w.gators.size() >= 6, "alligators in the wetlands (%d)" % w.gators.size())
	check(w.flamingos.size() >= 6, "flamingos placed (%d)" % w.flamingos.size())
	var p = game.player
	var g = w.gators[0]
	p.global_position = g.global_position + Vector3(6.0, 0.3, 0.0)
	p.velocity = Vector3.ZERO
	var hp0: float = p.health
	await frames(150)
	check(g.state != g.IDLE or p.health < hp0, "a gator charges a player on foot")
	check(p.health < hp0, "and bites (%.0f -> %.0f)" % [hp0, p.health])
	g.take_hit(500.0, p, g.global_position)
	check(g.state == g.DEAD, "gators can be shot")
	p.heal(100)
	var f = w.flamingos[0]
	p.global_position = f.global_position + Vector3(3.0, 0.3, 0.0)
	await frames(30)
	check(f.state != f.STAND, "flamingos take off when you walk up")


func _test_stunt_and_feed() -> void:
	print("stunts and the Chirp feed")
	var p = game.player
	var car = game.traffic.spawn_car("sport", Color.YELLOW, Transform3D(Basis(), Vector3(-380, 14.0, -40)))
	p.global_position = car.global_position + Vector3(2, 0, 0)
	p.enter_car(car)
	var money0: int = game.money
	car.linear_velocity = Vector3(0, 6.0, -22.0)
	await frames(240)
	check(game.stats.stunts >= 1, "a long jump scores a stunt bonus")
	check(game.money > money0, "stunt bonus paid ($%d -> $%d)" % [money0, game.money])
	check(game.hud.posts.size() >= 1, "the Chirp feed has posts (%d)" % game.hud.posts.size())
	p.exit_car()


func _test_night() -> void:
	print("day and night")
	game.hour = 22.0
	game._update_time(0.0)
	check(game.night > 0.9, "22:00 is night (%.2f)" % game.night)
	check(game.city.lamp_lights[0].visible, "street lights on at night")
	game.hour = 12.0
	game._update_time(0.0)
	check(game.night < 0.05, "noon is day")
	check(not game.city.lamp_lights[0].visible, "street lights off by day")
