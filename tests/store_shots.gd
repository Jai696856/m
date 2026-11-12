# Renders the home with quests, the Store, a skinned tree, and a farm game (needs a display):
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s tests/store_shots.gd -- <out_dir>
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
	main.sfx.muted = true
	main.progress.unlock_everything(main.Defs.HERO_ORDER)
	main.progress.add_gems(900)
	main.progress.add("pops", 600.0)
	main.to_home()
	for i in range(90):
		await process_frame
	_save(out + "/home_quests.png")
	main.menu._open("store")
	for i in range(10):
		await process_frame
	_save(out + "/store.png")
	for i in range(3):
		main.progress.add_charm(main.Progress.charm_key(["ninja", "mage", "kenta"][i], [[3, 1, 0], [0, 2, 3], [4, 0, 2]][i]))
	for id in ["time_stop", "shrine_bomb", "cash_drop", "golden_touch"]:
		main.progress.buy_power(id)
	main.progress.buy_skin("komugi", 1)
	main.menu.open_tree("komugi")
	for i in range(10):
		await process_frame
	_save(out + "/tree_skins.png")
	main.menu.show_home()
	main.save.set_value("settings", "tutorial_seen", false)
	main.new_game("normal", 0, "standard")
	main.cash = 1.0e6
	var picks := ["komugi", "komugi", "ninja", "mage", "kenta", "hina"]
	var n := 0
	for x in range(-30, 26, 3):
		for z in range(-17, 18, 3):
			if n < picks.size() and main.valid_spot(float(x), float(z)) and main.dist_to_path(float(x), float(z)) < 4.5:
				var h = main.place_hero(picks[n], float(x), float(z))
				for t in range(2 + n % 2):
					main.buy_upgrade(h, n % 3)
				n += 1
	for h in main.heroes:
		if h.key == "komugi":
			for i in range(4):
				main._grow_crop(h, main.eff(h))
	main.ui.select_class(4)
	main.round_num = 12
	main.start_round()
	for i in range(70):
		await process_frame
	_save(out + "/game_farm.png")
	main.ui.toggle_charms()
	for i in range(5):
		await process_frame
	_save(out + "/game_charms.png")
	main.queue_free()
	await process_frame
	quit(0)

func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
