# Renders the main menu, the Heroes screen and a game with the new heroes (needs a display):
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s tests/menu_shots.gd -- <out_dir>
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
	main.progress.add_xp(2600.0)
	main.sfx.muted = true
	main.to_home()
	for i in range(90):
		await process_frame
	_save(out + "/home.png")
	main.menu._open("heroes")
	main.menu._pick_hero_class(3)
	for i in range(10):
		await process_frame
	_save(out + "/heroes.png")
	main.menu.show_home()
	main.progress.unlock_everything(main.Defs.HERO_ORDER)
	main.new_game("normal", 0, "standard")
	main.cash = 1.0e6
	var picks := ["ren", "kenta", "saya", "sora", "riku", "hina", "hiro", "nao"]
	var n := 0
	for x in range(-30, 26, 3):
		for z in range(-17, 18, 3):
			if n < picks.size() and main.valid_spot(float(x), float(z)) and main.dist_to_path(float(x), float(z)) < 4.5:
				var h = main.place_hero(picks[n], float(x), float(z))
				for t in range(3):
					main.buy_upgrade(h, n % 3)
				n += 1
	main.ui.select_class(3)
	main.round_num = 18
	main.start_round()
	for i in range(80):
		await process_frame
	_save(out + "/game_new_heroes.png")
	main.queue_free()
	await process_frame
	quit(0)

func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
