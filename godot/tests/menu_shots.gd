# Renders the main menu and its screens (needs a display, e.g. xvfb-run):
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
	main.progress.add_xp(900.0)
	main.progress.add("pops", 1500.0)
	main.progress.add("wins", 2.0)
	main.to_home()
	for i in range(150):
		await process_frame
	_save(out + "/home.png")
	for s in ["heroes", "achievements"]:
		main.menu._open(s)
		for i in range(15):
			await process_frame
		_save("%s/%s.png" % [out, s])
	main.menu.show_home()
	main.start_daily()
	main.cash = 1.0e6
	for i in range(8):
		await process_frame
	main.ui.toast("ACHIEVEMENT UNLOCKED", "Full Squad")
	main.start_round()
	for i in range(40):
		await process_frame
	_save(out + "/daily_game.png")
	main.queue_free()
	await process_frame
	quit(0)

func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
