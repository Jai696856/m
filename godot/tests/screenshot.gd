# Renders screenshots of the real game (needs a display, e.g. xvfb-run):
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s tests/screenshot.gd -- <out_dir>
extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://"
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in range(90):
		await process_frame
	_save(out + "/godot_start.png")

	main.ui.start_screen.visible = false
	main.new_game("normal")
	main.sfx.muted = true
	main.cash = 100000.0
	var spots := [
		["ninja", -14.0, -8.0], ["miko", 0.0, -4.5], ["mage", -6.0, 8.0], ["ice", 14.0, -4.5],
		["samurai", 22.0, 0.0], ["mecha", -16.0, 9.0], ["idol", 8.0, 8.0], ["ninja", 24.0, 12.0],
	]
	for s in spots:
		if main.valid_spot(s[1], s[2]):
			var h = main.place_hero(s[0], s[1], s[2])
			main.buy_upgrade(h, 0)
			main.buy_upgrade(h, 0)
		else:
			print("spot not valid: ", s)
	main.round_num = 24
	main.start_round()
	for i in range(240):
		await process_frame
	_save(out + "/godot_play.png")
	main.select_hero(main.heroes[1])
	for i in range(20):
		await process_frame
	_save(out + "/godot_panel.png")
	main.queue_free()
	await process_frame
	quit(0)

func _save(path: String) -> void:
	var img := root.get_texture().get_image()
	var err := img.save_png(path)
	print("saved ", path, " err=", err, " size=", img.get_size())
