# Close-up line-ups of every hero and every spirit for model review (needs a display):
#   xvfb-run -s "-screen 0 1280x720x24" godot --path . -s tests/model_shots.gd -- <out_dir> [per_page] [what]
# what: all (default) | heroes | spirits | face (a tight shot of the first four heroes)
extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://"
	var per_page := int(args[1]) if args.size() > 1 else 7
	var what: String = args[2] if args.size() > 2 else "all"
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
	main.ui.visible = false
	# A stage high above the map so nothing is in the way
	var stage := Node3D.new()
	stage.position = Vector3(0, 60, 0)
	main.add_child(stage)
	var floor_mesh: Node = main.Models.add(stage, main.Models.box(400, 0.2, 400), main.Models.soft(0x86c960), Vector3(0, -0.1, 0))
	var keys: Array = main.Defs.HERO_ORDER
	main.set_process(false)
	if what in ["all", "heroes", "face"]:
		var pages := int(ceil(float(keys.size()) / per_page)) if what != "face" else 1
		for page in range(pages):
			for c in stage.get_children():
				if c != floor_mesh:
					c.queue_free()
			var n := per_page if what != "face" else 4
			for i in range(n):
				var idx := page * per_page + i
				if idx >= keys.size():
					break
				var m: Dictionary = main.Models.build_hero(keys[idx])
				var r: Node3D = m["root"]
				r.position = Vector3((i - (n - 1) / 2.0) * 2.5, 0, 0)
				(m["body"] as Node3D).rotation.y = 0.3
				stage.add_child(r)
				if what != "face":
					# The same hero fully upgraded behind, and seen from the back
					var m2: Dictionary = main.Models.build_hero(keys[idx])
					for t in range(1, 5):
						main.Models.apply_upgrade_look(m2, idx % 3, t)
					(m2["root"] as Node3D).position = Vector3((i - (n - 1) / 2.0) * 2.5, 0, -3.2)
					(m2["body"] as Node3D).rotation.y = 0.3 if idx % 2 == 0 else PI + 0.5
					stage.add_child(m2["root"])
			if what == "face":
				main.camera.position = stage.position + Vector3(0.6, 2.6, 6.2)
				main.camera.look_at(stage.position + Vector3(0, 1.75, 0), Vector3.UP)
			else:
				var back := 6.0 + per_page
				main.camera.position = stage.position + Vector3(0, 0.5 * back, back)
				main.camera.look_at(stage.position + Vector3(0, 1.0, -1.5), Vector3.UP)
			for i in range(6):
				await process_frame
			_save("%s/%s_%d.png" % [out, "face" if what == "face" else "heroes", page])
	if what in ["all", "spirits"]:
		for c in stage.get_children():
			if c != floor_mesh:
				c.queue_free()
		var order: Array = main.Defs.ORDER
		for i in range(order.size()):
			var e: Node3D = main.Models.build_enemy(order[i], false, main.rainbow_mat, main.rainbow_camo)
			var s: float = main.Defs.ENEMIES[order[i]]["size"]
			e.position = Vector3((i % 8 - 3.5) * 2.9, s + 0.2, -3.8 if i < 8 else 1.2)
			e.rotation.y = 0.35
			stage.add_child(e)
		main.camera.position = stage.position + Vector3(0, 8.0, 15.0)
		main.camera.look_at(stage.position + Vector3(0, 1.0, -1.5), Vector3.UP)
		for i in range(6):
			await process_frame
		_save("%s/spirits.png" % out)
	main.queue_free()
	await process_frame
	quit(0)

func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
