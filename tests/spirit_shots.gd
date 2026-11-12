# Renders the home with Continue, Shrine Blessings, the Spirit Almanac, map select with all modes, and the new spirits on the track (needs a display):
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s tests/spirit_shots.gd -- <out_dir>
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
	main.save.set_value("settings", "tutorial_seen", true)
	for k in main.Defs.ORDER:
		if k != "dragon":
			main.progress.add_to_set("spirits_seen", k)
	main.progress.add_xp(6000.0)
	for id in ["cash_1", "cash_2", "range", "rate", "focus"]:
		main.progress.buy_blessing(id)
	main.save.set_value("run", "data", {"map": 5, "diff": "normal", "mode": "standard", "round": 17, "cash": 1200.0, "lives": 130.0, "heroes": []})
	main.to_home()
	for i in range(30):
		await process_frame
	_save(out + "/home_continue.png")
	main.menu._open("blessings")
	for i in range(10):
		await process_frame
	_save(out + "/blessings.png")
	main.menu._open("almanac")
	for i in range(20):
		await process_frame
	_save(out + "/almanac.png")
	main.menu.show_home()
	main.ui.show_map_select()
	main.ui._pick_diff("nightmare")
	main.ui._pick_mode("boss_rush")
	for i in range(10):
		await process_frame
	_save(out + "/map_select.png")
	main.ui.start_screen.visible = false
	main.new_game("normal", 0, "sandbox")
	var d := 6.0
	for k in ["kitsune", "crane", "lantern", "kitsune", "crane", "lantern", "shogun"]:
		main.spawn_enemy(k, d)
		d += 5.0
	main.cam_dist = 34.0
	for i in range(40):
		await process_frame
	_save(out + "/new_spirits.png")
	main.queue_free()
	await process_frame
	quit(0)

func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
