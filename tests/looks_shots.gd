# Renders the main menu and a close-up line-up of upgrade looks (needs a display):
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s tests/looks_shots.gd -- <out_dir>
extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://"
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in range(2):
		await process_frame
	main.save = ConfigFile.new()
	main.progress.save = main.save
	main.progress.add_xp(900.0)
	main.to_home()
	for i in range(120):
		await process_frame
	_save(out + "/home.png")
	main.menu._open("heroes")
	for i in range(10):
		await process_frame
	_save(out + "/heroes.png")

	# Line-up: rows = paths 1-3 maxed (tier 4), columns = three heroes, plus tier 0-3 progression.
	main.menu.visible = false
	main.new_game("easy", 0, "sandbox")
	main.ui.set_hud_visible(false)
	var x0 := 14.0
	var z0 := -9.0
	var heroes := ["ninja", "mage", "ice"]
	for p in range(3):
		for c in range(3):
			var h = main.place_hero(heroes[c], x0 + c * 3.2, z0 + p * 3.4)
			if h == null:
				continue
			for t in range(4):
				main.buy_upgrade(h, p)
	# tier progression on path 1 for Hana
	for t in range(5):
		var h2 = main.place_hero("miko", x0 + 10.0, z0 + t * 2.6 - 1.0)
		if h2 == null:
			continue
		for i in range(t):
			main.buy_upgrade(h2, 1)
	main.select_hero(null)
	main.cam_target = Vector3(x0 + 5.0, 0, z0 + 3.4)
	main.cam_dist = 24.0
	main.cam_pitch = 0.75
	main.cam_yaw = 0.0
	main.attract = false
	for i in range(60):
		main.cam_target = Vector3(x0 + 5.0, 0, z0 + 3.4)
		main.cam_dist = 24.0
		await process_frame
	_save(out + "/looks.png")
	print("heroes placed: ", main.heroes.size())
	main.queue_free()
	await process_frame
	quit(0)

func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
