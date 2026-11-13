# Renders clean promo stills of the menu village with a hero line-up (needs a display):
#   xvfb-run -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 -s tools/key_shot.gd -- <out_dir>
extends SceneTree

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1920, 1080)
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	for i in range(2):
		await process_frame
	main.save = ConfigFile.new()
	main.progress.save = main.save
	main.sfx.muted = true
	main.menu.login_shown = true
	main.load_map(0)
	main.to_home()
	main.menu.visible = false
	main.ui.visible = false
	var shots := [
		["village", ["ninja", "miko", "mage", "ice", "samurai", "mecha", "idol"], Vector3(0, 9.5, 19.0), Vector3(0, 2.0, -1.0)],
		["lineup", ["kaito", "lumi", "mage", "ninja", "komugi", "samurai", "sora"], Vector3(0.5, 4.6, 12.6), Vector3(0, 2.2, 0.5)],
	]
	for s in shots:
		main.hub.set_heroes(s[1])
		main.hub.camera.position = s[2]
		main.hub.camera.look_at(main.hub.global_position + (s[3] as Vector3), Vector3.UP)
		for i in range(40):
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [out, s[0]])
		print("saved ", s[0])
	main.queue_free()
	await process_frame
	quit(0)
