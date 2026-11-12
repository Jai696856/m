# Screenshots of hero abilities mid-effect (needs a display):
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s tests/fx_shots.gd -- <out_dir> [hero,keys]
extends SceneTree

const TYPES := ["blue", "green", "gold", "violet", "kitsune", "prism", "shadow", "frost", "lantern", "mask"]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://"
	var keys: Array = ["mage", "sora", "kenta", "mecha", "rei", "miko", "ice", "saya", "samurai", "ichika", "gen", "lumi"]
	if args.size() > 1:
		keys = Array(args[1].split(","))
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in range(2):
		await process_frame
	main.save = ConfigFile.new()
	main.progress.save = main.save
	main.sfx.muted = true
	main.save.set_value("settings", "tutorial_seen", true)
	main.menu.visible = false
	for k in keys:
		main.new_game("normal", 0, "sandbox")
		main.ui.set_hud_visible(false)
		main.ui.sandbox_panel.visible = false
		main.ui.banner_box.visible = false
		var c: Vector3 = main.pos_at(main.path_len * 0.45)
		var h = null
		for x in range(-30, 26, 2):
			for z in range(-17, 18, 2):
				if h == null and main.valid_spot(float(x), float(z)) and Vector2(x, z).distance_to(Vector2(c.x, c.z)) < 6.0:
					h = main.place_hero(k, float(x), float(z))
		for t in range(3):
			main.buy_upgrade(h, 0)
		main.select_hero(null)
		for i in range(50):
			main.spawn_enemy(TYPES[i % TYPES.size()], main.path_len * (0.25 + 0.4 * i / 50.0))
		main.spawn_enemy("oni", main.path_len * 0.5)
		main.cam_target = c
		main.cam_dist = 36.0
		main.cam_pitch = 0.7
		main.cam_yaw = 0.2
		for i in range(4):
			await process_frame
		main.use_ability(h)
		var shots := [10, 20, 30]
		for i in range(31):
			await process_frame
			if shots.has(i + 1):
				root.get_texture().get_image().save_png("%s/%s_%d.png" % [out, k, shots.find(i + 1)])
		print("saved ", k)
	main.queue_free()
	await process_frame
	quit(0)
