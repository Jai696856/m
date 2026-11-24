# Renders a few real screenshots of the game (needs a display, e.g. xvfb-run).
#   xvfb-run godot --path . -s tests/screenshots.gd -- <out_dir>
extends SceneTree

const Util := preload("res://scripts/util.gd")

var game
var out := "user://shots"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var only := args[1] if args.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await _frames(5)
	game.hud.intro.visible = false
	paused = false
	game.time_flow = 0.0
	for shot in ["beach", "downtown", "drive", "night", "wanted", "swamp", "bank", "phone", "heli", "aerial", "bigmap", "highway", "intro"]:
		if only == "" or only == shot:
			await call("_shot_" + shot)
	quit()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(name: String) -> void:
	await _frames(2)
	var img := root.get_texture().get_image()
	img.save_jpg(out.path_join(name + ".jpg"), 0.9)
	print("saved ", name)


func _set_time(h: float) -> void:
	game.hour = h
	game._update_time(0.0)


func _place(pos: Vector3, yaw: float, pitch := -0.15) -> void:
	game.player.global_position = pos
	game.player.velocity = Vector3.ZERO
	game.player.model.rotation.y = yaw
	game.cam.yaw = yaw
	game.cam.pitch = pitch
	game.cam.mouse_idle = 0.0
	game.cam.snap()


func _shot_beach() -> void:
	_set_time(17.55)
	_place(Vector3(-336.0, 0.2, 10.0), deg_to_rad(65.0), -0.05)
	await _frames(40)
	await _save("01_sunset_beach")


func _shot_downtown() -> void:
	_set_time(11.0)
	var c: Vector3 = game.city.node_pos(4, 5)
	_place(c + Vector3(3, 0.1, 30), 0.0, 0.18)
	await _frames(40)
	await _save("02_downtown_day")


func _shot_drive() -> void:
	_set_time(16.5)
	var car = game.traffic.spawn_car("sport", Color(0.95, 0.2, 0.5), Transform3D(Basis(), game.city.node_pos(2, 6) + Vector3(game.city.LANE_OFF, 0.3, -12)))
	game.player.global_position = car.global_position + Vector3(2, 0.2, 0)
	game.player.enter_car(car)
	game.cam.yaw = 0.0
	game.cam.pitch = -0.2
	game.cam.mouse_idle = 5.0
	Engine.max_physics_steps_per_frame = 1
	Input.action_press("move_forward")
	await _frames(150)
	Input.action_release("move_forward")
	Engine.max_physics_steps_per_frame = 8
	await _save("03_driving")
	game.player.exit_car()


func _shot_night() -> void:
	_set_time(22.0)
	var c: Vector3 = game.city.block_center(3, 3)
	_place(Vector3(c.x - 26, 0.2, c.z - 36), deg_to_rad(-60.0), 0.05)
	await _frames(40)
	await _save("04_night_city")


func _shot_wanted() -> void:
	_set_time(17.6)
	var c: Vector3 = game.city.node_pos(3, 2)
	_place(c + Vector3(6, 0.1, 6), deg_to_rad(200.0), -0.12)
	game.police.add_heat(320)
	game.police.spawn_cd = 0.0
	await _frames(30)
	for car in game.police.cars:
		car.global_position = game.player.global_position + Vector3(randf_range(-14, 14), 0.3, randf_range(-22, -12)).rotated(Vector3.UP, game.cam.yaw)
		car.linear_velocity = Vector3.ZERO
	game.hud.objective = "Lose the cops."
	await _frames(40)
	await _save("05_wanted")


func _shot_swamp() -> void:
	_set_time(17.2)
	var w = game.wildlife
	var g = w.gators[0]
	var f = w.flamingos[0]
	g.global_position = f.global_position + Vector3(-4, 0, 3)
	g.body_node.rotation.y = 0.6
	_place(g.global_position + Vector3(9, 0.1, 9), atan2(9, 9), -0.18)
	game.post("gator")
	game.post("news")
	game.post("stunt", {"car": "Marlin GT"})
	await _frames(40)
	await _save("06_swamp")


func _shot_bank() -> void:
	_set_time(14.0)
	var it = game.interiors
	_place(it.bank.entrance + Vector3(1.5, 0.1, -6.0), 0.15, -0.12)
	it._rob_bank()
	await _frames(50)
	game.police.reset()
	await _save("07_bank_robbery")


func _shot_phone() -> void:
	_set_time(15.0)
	_place(game.interiors.store.counter_front + Vector3(0, 0.1, 10.0), 0.0, -0.1)
	game.phone.open()
	game.phone.show_screen("contacts")
	await _frames(30)
	await _save("08_phone")
	game.phone.close()


func _shot_heli() -> void:
	_set_time(20.6)
	var c: Vector3 = game.city.node_pos(4, 5)
	_place(c + Vector3(3, 0.1, 10), 0.4, 0.35)
	game.police.add_heat(400)
	game.police._spawn_heli(game.player.global_position)
	var h = game.police.heli
	h.global_position = game.player.global_position + Vector3(-6, 22, -22)
	h.angle = 0.0
	await _frames(25)
	await _save("09_heli")
	game.police.reset()


func _shot_aerial() -> void:
	_set_time(17.0)
	_place(Vector3(-150, 0.2, 520), 0.0, 0.0)
	await _frames(5)
	var c := Camera3D.new()
	game.add_child(c)
	c.far = 4000.0
	c.global_position = Vector3(-650, 520, 900)
	c.look_at(Vector3(160, 0, -150))
	c.current = true
	await _frames(40)
	await _save("10_island_aerial")
	c.queue_free()
	game.cam.cam.current = true


func _shot_bigmap() -> void:
	_set_time(15.0)
	_place(game.city.spawn_point, 0.0, -0.1)
	game.hud.show_map = true
	await _frames(20)
	await _save("11_full_map")
	game.hud.show_map = false


func _shot_highway() -> void:
	_set_time(17.4)
	var t = game.city.terrain
	var r: Array = t.hwy_at(t.hwy_length() * 0.27)
	var pos: Vector3 = r[0]
	var dir: Vector3 = r[1]
	var car = game.traffic.spawn_car("sport", Color(0.95, 0.2, 0.5), Transform3D(Util.look_basis(dir), pos + Vector3(-dir.z, 0, dir.x) * 3.5 + Vector3.UP * 0.3))
	game.player.global_position = car.global_position + Vector3(2, 0.2, 0)
	game.player.enter_car(car)
	game.cam.yaw = Util.yaw_of(dir)
	game.cam.pitch = -0.12
	game.cam.mouse_idle = 5.0
	Engine.max_physics_steps_per_frame = 1
	Input.action_press("move_forward")
	await _frames(110)
	Input.action_release("move_forward")
	Engine.max_physics_steps_per_frame = 8
	await _save("12_coastal_highway")
	game.player.exit_car()


func _shot_intro() -> void:
	game.police.reset()
	_set_time(18.3)
	_place(Vector3(-336.0, 0.2, 10.0), deg_to_rad(80.0), 0.02)
	game.hud.intro.visible = true
	await _frames(60)
	await _save("00_title")
