# Renders screenshots of the real game (needs a display, e.g. xvfb-run):
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s tests/screenshot.gd -- <out_dir>
# Saves the map menu, one map of every theme mid-game, and the pause menu.
extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://"
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.save = ConfigFile.new()
	main.sfx.muted = true
	for i in range(60):
		await process_frame
	_save(out + "/menu.png")

	var maps: Array = main.Maps.MAPS
	var done := {}
	for i in range(maps.size()):
		var theme: String = maps[i]["theme"]
		if done.has(theme):
			continue
		done[theme] = true
		main.ui.start_screen.visible = false
		main.new_game("normal", i, "standard")
		main.cash = 1.0e6
		var picks := ["ninja", "miko", "mage", "ice", "samurai", "mecha", "idol"]
		var n := 0
		for x in range(-30, 26, 3):
			for z in range(-17, 18, 3):
				if n < picks.size() and main.valid_spot(float(x), float(z)) and main.dist_to_path(float(x), float(z)) < 4.5:
					var h = main.place_hero(picks[n], float(x), float(z))
					for t in range(3):
						main.buy_upgrade(h, 0)
					n += 1
		main.round_num = 21
		main.start_round()
		for f in range(70):
			await process_frame
		_save("%s/theme_%s.png" % [out, theme])
		print("theme ", theme, " map ", maps[i]["name"], " heroes ", n)
	main.toggle_pause()
	for f in range(10):
		await process_frame
	_save(out + "/pause.png")
	main.queue_free()
	await process_frame
	quit(0)

func _save(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path)
