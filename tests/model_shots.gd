# Close-up line-ups of every hero and every spirit for model review (needs a display):
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s tests/model_shots.gd -- <out_dir>
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
	main.menu.visible = false
	main.new_game("easy", 0, "sandbox")
	main.ui.set_hud_visible(false)
	main.ui.sandbox_panel.visible = false
	# A stage far from the map so nothing is in the way
	var stage := Node3D.new()
	stage.position = Vector3(0, 60, 0)
	main.ui.visible = false
	main.add_child(stage)
	var floor_mesh: Node = main.Models.add(stage, main.Models.box(400, 0.2, 400), main.Models.toon(0x9bd85a, 1.0, false), Vector3(0, -0.1, 0))
	var keys: Array = main.Defs.HERO_ORDER
	for page in range(3):
		for c in stage.get_children():
			if c != floor_mesh:
				c.queue_free()
		for i in range(7):
			var idx := page * 7 + i
			if idx >= keys.size():
				break
			var m: Dictionary = main.Models.build_hero(keys[idx])
			var r: Node3D = m["root"]
			r.position = Vector3((i - 3) * 2.5, 0, 0)
			(m["body"] as Node3D).rotation.y = 0.3
			stage.add_child(r)
			# The same hero fully upgraded behind
			var m2: Dictionary = main.Models.build_hero(keys[idx])
			for t in range(1, 5):
				main.Models.apply_upgrade_look(m2, idx % 3, t)
			(m2["root"] as Node3D).position = Vector3((i - 3) * 2.5, 0, -3.2)
			(m2["body"] as Node3D).rotation.y = 0.3
			stage.add_child(m2["root"])
		main.camera.position = stage.position + Vector3(0, 6.5, 13.0)
		main.camera.look_at(stage.position + Vector3(0, 1.0, -1.5), Vector3.UP)
		main.set_process(false)
		for i in range(6):
			await process_frame
		_save("%s/heroes_%d.png" % [out, page])
	for c in stage.get_children():
		if c != floor_mesh:
			c.queue_free()
	var order: Array = main.Defs.ORDER
	for i in range(order.size()):
		var e: Node3D = main.Models.build_enemy(order[i], false, main.rainbow_mat, main.rainbow_camo)
		var s: float = main.Defs.ENEMIES[order[i]]["size"]
		e.position = Vector3((i % 8 - 3.5) * 2.6, s + 0.2, -3.6 if i < 8 else 1.0)
		e.rotation.y = 0.35
		stage.add_child(e)
	for i in range(6):
		await process_frame
	_save("%s/spirits.png" % out)
	main.queue_free()
	await process_frame
	quit(0)

func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
