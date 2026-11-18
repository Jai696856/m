extends SceneTree
## Clicks through every screen, buys something, plays a level to the end with the solver's recorded inputs,
## and saves screenshots to the folder given after "--". A crash, an unexpected death or a missing results
## panel fails the run. Uses a throwaway save (it erases progress first).
## xvfb-run godot --path gravity-dash-godot -s res://tools/tour.gd -- /tmp/shots [main level index]

var main
var out := "/tmp/shots"
var level := 4


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
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("shot ", name)


func _visit(fn: Callable, name: String, wait := 0.5) -> void:
	main.busy = false
	fn.call()
	await _wait(wait)
	await _shot(name)


func _run() -> void:
	var save = root.get_node("Save")
	save.reset_all()
	await _wait(1.0)
	await _shot("01_menu")
	main.page = level
	await _visit(main.show_levels, "02_levels")
	await _visit(main.hub.show_hub, "03_hub")
	main.shops.kit_tab = "icon"
	await _visit(main.shops.show_icons, "04_icons")
	save.give("shards", 2000)
	save.give("prisms", 20)
	await _visit(main.shops.show_market, "05_market")
	main.shops.shop_id = "bazaar"
	await _visit(main.shops.show_shop, "06_shop")
	main.shops._buy("icon", 17, main.label(""))
	main.shops._buy("extra", 0, main.label(""))
	print("bought cat icon: ", save.owns("icon", 17), "  glow: ", save.has_extra("glow"))
	save.set_skin("icon", 17)
	save.set_skin("glow", true)
	main.shops.kit_tab = "trail"
	await _visit(main.shops.show_icons, "07_icons_trails")
	await _visit(main.hub.show_quests, "08_quests")
	await _visit(main.hub.show_chests, "09_chests")
	main.busy = false
	print("chest: ", save.open_chest("small"))
	await _visit(main.hub.show_paths, "10_paths")
	await _visit(main.hub.show_map, "11_map", 0.8)
	await _visit(main.hub.show_forge, "12_forge")
	await _visit(main.hub.show_daily, "13_daily")
	await _visit(main.hub.show_trials, "14_trials")
	await _visit(main.shops.show_achievements, "15_achievements")
	await _visit(main.shops.show_stats, "16_stats")
	await _visit(main.show_settings, "17_settings")
	await _visit(main.show_codes, "18_codes")
	print("code FLIP: ", save.redeem_code("flip"))

	# Play a main level with the solver's inputs
	var Levels = load("res://scripts/levels.gd")
	var p: Dictionary = Levels.main_params(level)
	main.busy = false
	main.playing = p
	main.play_practice = false
	main.back_to = main.show_levels
	main._start_now()
	var lv: Dictionary = main.cache[p.key]
	print("level %s verified=%s coins=%d shards=%d" % [p.name, lv.verified, lv.coins.size(), lv.shards.size()])
	var frames := {}
	for f in lv.solution:
		frames[f] = true
	main.world.autopilot = frames
	var deaths := [0]
	main.world.died.connect(func(_p, _b): deaths[0] += 1)
	await _wait(3.0)
	await _shot("19_play")
	main._pause()
	await _wait(0.4)
	await _shot("20_pause")
	main._resume()
	var limit := 150.0
	var mid_shot := false
	while main.world.mode != "win" and limit > 0.0:
		await _wait(0.25)
		limit -= 0.25
		if not mid_shot and main.world.pct() > 55:
			mid_shot = true
			await _shot("21_play_mid")
	if main.world.mode != "win":
		push_error("level was not finished (mode %s, deaths %d)" % [main.world.mode, deaths[0]])
		quit(1)
		return
	await _wait(1.25)
	await _shot("22_win_text")
	await _wait(1.8)
	await _shot("23_results")
	if main.win_box == null:
		push_error("results panel missing")
		quit(1)
		return
	print("result: ", main.result)
	print("TOUR OK  deaths=%d  shards=%d  prisms=%d  coins=%d" % [deaths[0], save.shards(), save.prisms(), int(save.stat("coins"))])
	quit(0)
