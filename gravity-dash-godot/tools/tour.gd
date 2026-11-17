extends SceneTree
## Clicks through every screen, plays a level to the end with the solver's recorded inputs,
## and saves screenshots to the folder given after "--": a crash, an unexpected death or a
## missing results panel fails the run.
## xvfb-run godot --path gravity-dash-godot -s res://tools/tour.gd -- /tmp/shots [level]

var main
var out := "/tmp/shots"
var level := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		level = int(args[1])
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _run() -> void:
	await _wait(1.0)
	await _shot("1_menu")
	main._show_levels()
	main.page = level
	main._refresh_card(0)
	await _wait(0.6)
	await _shot("2_levels")
	main._show_icons()
	await _wait(0.5)
	main._pick("icon", 3)  # locked on a fresh save: shows the requirement
	await _wait(0.3)
	await _shot("3_icons")
	main._show_stats()
	await _wait(0.5)
	await _shot("4_stats")

	var Sim = load("res://scripts/sim.gd")
	var sol: Dictionary = Sim.solve(main.levels[level])
	var frames := {}
	for f in sol.path:
		frames[f] = true
	main._start_level(level)
	main.world.autopilot = frames
	await _wait(2.5)
	await _shot("5_play")
	main._pause()
	await _wait(0.4)
	await _shot("6_pause")
	main._resume()
	var deaths := 0
	main.world.died.connect(func(_p, _b): deaths += 1)
	var limit := 120.0
	while main.world.mode != "win" and limit > 0.0:
		await _wait(0.25)
		limit -= 0.25
	if main.world.mode != "win":
		push_error("level was not finished (mode %s, deaths %d)" % [main.world.mode, deaths])
		quit(1)
		return
	await _wait(1.25)
	await _shot("7_win_text")
	await _wait(1.6)
	await _shot("8_results")
	if main.win_box == null:
		push_error("results panel missing")
		quit(1)
		return
	print("TOUR OK  deaths=%d  attempts=%d  flips=%d" % [deaths, main.world.attempts, main.world.flips])
	quit(0)
