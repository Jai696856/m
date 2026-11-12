# Screenshots of every screen for visual review (needs a display):
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s tests/ui_tour.gd -- <out_dir> [only,names]
extends SceneTree

var out := "user://"
var only: Array = []
var main: Node3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		only = Array(args[1].split(","))
	root.size = Vector2i(1280, 720)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait(2)
	main.save = ConfigFile.new()
	main.progress.save = main.save
	main.sfx.muted = true
	main.save.set_value("settings", "tutorial_seen", true)
	var p = main.progress
	p.unlock_everything(main.Defs.HERO_ORDER)
	p.add_gems(900)
	p.add("pops", 2600.0)
	p.add("wins", 3.0)
	for k in ["pink", "blue", "green", "gold", "violet", "shadow", "kitsune", "crane", "lantern", "oni"]:
		p.add_to_set("spirits_seen", k)
	for id in ["cash_1", "range", "focus"]:
		p.buy_blessing(id)
	for id in ["time_stop", "shrine_bomb", "cash_drop"]:
		p.buy_power(id)
	p.add_charm(main.Progress.charm_key("ninja", [3, 1, 0]))
	p.claim_login(main.Defs.HERO_ORDER)
	main.save.set_value("run", "data", {"map": 5, "diff": "normal", "mode": "standard", "round": 17, "cash": 1200.0, "lives": 130.0, "heroes": []})
	main.menu.login_shown = true
	main.to_home()
	await _wait(60)
	await _shot("home")
	for scr in ["heroes", "store", "blessings", "almanac", "achievements", "stats", "settings", "howto", "login"]:
		if _want(scr):
			main.menu._open(scr)
			await _wait(8)
			await _shot(scr)
	if _want("tree"):
		main.menu.open_tree("mage")
		await _wait(8)
		await _shot("tree")
	main.menu.show_home()
	if _want("maps"):
		main.ui.show_map_select()
		await _wait(8)
		await _shot("maps")
		main.ui.start_screen.visible = false
	# In game
	main.new_game("normal", 0, "standard")
	main.cash = 1.0e6
	var picks := ["ninja", "mage", "kenta", "komugi", "mecha", "idol", "ice", "samurai"]
	var n := 0
	for x in range(-30, 26, 3):
		for z in range(-17, 18, 3):
			if n < picks.size() and main.valid_spot(float(x), float(z)) and main.dist_to_path(float(x), float(z)) < 4.5:
				var h = main.place_hero(picks[n], float(x), float(z))
				for t in range(3):
					main.buy_upgrade(h, n % 3)
				n += 1
	main.round_num = 21
	main.start_round()
	await _wait(150)
	await _shot("game")
	main.select_hero(main.heroes[1])
	await _wait(5)
	await _shot("game_panel")
	if _want("game_close"):
		main.select_hero(null)
		var h0 = main.heroes[1]
		main.cam_target = Vector3(h0.x, 0, h0.z)
		main.cam_dist = 17.0
		main.cam_pitch = 0.5
		for j in range(8):
			main.spawn_enemy(["mask", "kitsune", "lantern", "crane", "prism", "gold", "shadow", "frost"][j], main.path_len * 0.04 + j * 1.6)
		await _wait(14)
		await _shot("game_close")
		main.cam_pitch = 0.9
		main._fit_camera()
	if _want("pause"):
		main.select_hero(null)
		main.toggle_pause()
		await _wait(5)
		await _shot("pause")
		main.toggle_pause()
	if _want("end"):
		main.victory()
		await _wait(5)
		await _shot("end")
	if _want("sandbox"):
		main.new_game("normal", 8, "sandbox")
		await _wait(30)
		await _shot("sandbox")
	main.queue_free()
	await process_frame
	quit(0)

func _want(name: String) -> bool:
	return only.is_empty() or only.has(name)

func _wait(n: int) -> void:
	for i in range(n):
		await process_frame

func _shot(name: String) -> void:
	if not _want(name):
		return
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)
