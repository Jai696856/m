# Headless smoke test: plays the game end to end without a window.
#   godot --headless --path . -s tests/smoke_test.gd
# Covers every map, every game mode, spirit modifiers, hero abilities, pause,
# saving, a full 40-round game, and walks a physics body along the track.
# Exits with code 1 on any failure.
extends SceneTree

var failures: Array = []

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		printerr("FAIL: ", msg)

func _initialize() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	main.sfx.muted = true
	main.SAVE_PATH  # constant exists
	main.save = ConfigFile.new()  # don't touch the player's real save

	await _test_all_maps(main)
	await _test_modes(main)
	await _test_modifiers(main)
	await _test_abilities(main)
	await _test_pause(main)
	await _test_full_game(main)
	await _traverse(main)

	main.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("SMOKE TEST PASSED")
		quit(0)
	else:
		print("SMOKE TEST FAILED (%d):" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)

func _run_rounds(main, n: int) -> void:
	for r in range(n):
		if main.over:
			return
		main.start_round()
		var steps := 0
		while main.running and steps < 60000:
			main._step(1.0 / 60.0)
			steps += 1
		check(not main.running, "round %d finished on %s" % [main.round_num, main.current_map()["name"]])
		await process_frame

# Valid build spots within reach of the track, like a player would choose.
func _find_spots(main, n: int) -> Array:
	var out: Array = []
	for x in range(-34, 30, 2):
		for z in range(-20, 21, 2):
			if main.valid_spot(float(x), float(z)) and main.dist_to_path(float(x), float(z)) < 6.0:
				var far := true
				for o in out:
					if o.distance_to(Vector2(x, z)) < 3.0:
						far = false
				if far:
					out.append(Vector2(x, z))
					if out.size() >= n:
						return out
	return out

# Every map: valid track, path built, room for heroes, a short game plays out.
func _test_all_maps(main) -> void:
	var maps: Array = main.Maps.MAPS
	check(maps.size() >= 46, "at least 46 maps (got %d)" % maps.size())
	var ids := {}
	var lengths := {}
	for i in range(maps.size()):
		main.load_map(i)
		await process_frame
		var m: Dictionary = maps[i]
		check(not ids.has(m["id"]), "unique map id %s" % m["id"])
		ids[m["id"]] = true
		var track = main.level.track
		check(track.validate(), "%s: track validates" % m["name"])
		check(track.tiles.size() == track.cells.size() - 2, "%s: one tile per inner cell" % m["name"])
		check(main.path_len > 60.0, "%s: path length %.0f" % [m["name"], main.path_len])
		var spots := _find_spots(main, 40)
		check(spots.size() >= 25, "%s: room for heroes (%d spots)" % [m["name"], spots.size()])
		lengths[m["tier"]] = lengths.get(m["tier"], []) + [main.path_len]
		# Short game: two heroes, three rounds.
		main.new_game("normal", i, "standard")
		main.cash = 5000.0
		for s in spots.slice(0, 2):
			main.place_hero("ninja", s.x, s.y)
		await _run_rounds(main, 3)
		check(main.lives == 150, "%s: early rounds held (lives %d)" % [m["name"], main.lives])
	for t in lengths:
		var arr: Array = lengths[t]
		var avg := 0.0
		for v in arr:
			avg += v
		print("tier %s: %d maps, avg path %.0f" % [t, arr.size(), avg / arr.size()])
	print("maps: %d checked" % maps.size())

func _test_modes(main) -> void:
	for m in main.MODE_ORDER:
		main.new_game("normal", 0, m)
		match m:
			"deflation":
				check(main.cash == 20000.0, "deflation starts with $20,000")
			"sandbox":
				check(main.cash > 1.0e8 and main.lives > 1.0e8, "sandbox has unlimited money and lives")
			_:
				check(main.cash == 650.0, "%s starts with $650" % m)
		var spots := _find_spots(main, 3)
		for s in spots:
			main.place_hero("miko", s.x, s.y)
		var before: float = main.cash
		await _run_rounds(main, 2)
		match m:
			"deflation":
				check(main.cash == before, "deflation earns nothing (%.0f -> %.0f)" % [before, main.cash])
			"half_cash":
				check(absf(main.cash_earned - (main.cash - before)) < 0.01 and main.cash_earned > 0.0, "half cash still earns something")
		if m == "fortified":
			var e = main.spawn_enemy("pink", 1.0)
			check(e.fortified and e.hp == 2.0, "fortified mode doubles spirit health")
			main._remove_enemy(e)
		if m == "rush":
			while main.running:
				main._step(1.0 / 60.0)
			var r0: int = main.round_num
			for i in range(10):
				main._step(1.0 / 60.0)
			check(main.running and main.round_num == r0 + 1, "rush starts the next round by itself (%d -> %d)" % [r0, main.round_num])
		print("mode %s ok (round %d, cash %d)" % [m, main.round_num, main.cash])

func _test_modifiers(main) -> void:
	main.new_game("normal", 0, "standard")
	var f = main.spawn_enemy("mask", 5.0, false, true)
	check(f.fortified and f.hp == 20.0, "fortified mask has 20 hp (got %.0f)" % f.hp)
	var kids: Array = main.pop_enemy(f, null)
	check(kids.size() == 2 and not kids[0].fortified, "fortified mask's prism children are not fortified")
	var r = main.spawn_enemy("pink", 5.0, false, false, true, "gold")
	check(r.regrow, "regrow flag set")
	for i in range(int(main.REGROW_DELAY * 60.0) + 5):
		main._step(1.0 / 60.0)
	check(r.type == "blue", "regrowing pink grows back into blue (got %s)" % r.type)
	for i in range(int(main.REGROW_DELAY * 60.0 * 3.0) + 20):
		main._step(1.0 / 60.0)
	check(r.type == "gold", "regrow stops at its original layer (got %s)" % r.type)
	# Damage resets the regrow timer.
	r.regrow_t = 0.1
	main.damage_enemy(r, 0.0, {"type": "magic"})
	check(r.regrow_t == main.REGROW_DELAY, "damage resets the regrow timer")
	var regrow_rounds := 0
	var fort_rounds := 0
	for rr in range(16, 41):
		var any_regrow := false
		var any_fort := false
		for s in main.build_round(rr):
			any_regrow = any_regrow or s.get("regrow", false)
			any_fort = any_fort or s.get("fort", false)
		regrow_rounds += int(any_regrow)
		fort_rounds += int(any_fort)
	check(regrow_rounds >= 3, "regrowing spirits appear in later rounds (%d rounds)" % regrow_rounds)
	check(fort_rounds >= 2, "fortified masks appear in later rounds (%d rounds)" % fort_rounds)
	print("rounds 16-40: %d with regrow groups, %d with fortified groups" % [regrow_rounds, fort_rounds])
	for e in main.enemies.duplicate():
		main._remove_enemy(e)
	main.enemies.clear()

func _test_abilities(main) -> void:
	main.new_game("normal", 0, "standard")
	main.cash = 1.0e7
	var spots := _find_spots(main, 7)
	var hs: Array = []
	for i in range(7):
		var k: String = main.Defs.HERO_ORDER[i]
		var h = main.place_hero(k, spots[i].x, spots[i].y)
		check(h.ability_cd < 0.0, "%s ability locked at first" % k)
		for t in range(3):
			main.buy_upgrade(h, 0)
		check(h.ability_cd == 0.0, "%s ability unlocked at tier 3" % k)
		hs.append(h)
	check(main.ability_heroes().size() == 7, "ability bar lists 7 heroes")
	for j in range(12):
		main.spawn_enemy(["pink", "mask", "oni"][j % 3], 10.0 + j * 4.0)
	for h in hs:
		main.use_ability(h)
		check(h.ability_cd > 0.0, "%s ability goes on cooldown" % h.key)
		main.use_ability(h)  # second use is ignored while cooling
		for i in range(20):
			main._step(1.0 / 60.0)
	check(main.encore_t > 0.0, "Encore! buff is active")
	var cd_before: float = hs[0].ability_cd
	for i in range(120):
		main._step(1.0 / 60.0)
	check(hs[0].ability_cd < cd_before, "cooldowns tick down")
	for e in main.enemies.duplicate():
		main._remove_enemy(e)
	main.enemies.clear()
	print("abilities ok")

func _test_pause(main) -> void:
	main.new_game("normal", 0, "standard")
	main.start_round()
	for i in range(30):
		main._step(1.0 / 60.0)
	main.toggle_pause()
	check(main.paused, "game pauses")
	var t: float = main.round_time
	for i in range(10):
		await process_frame
	check(main.round_time == t, "paused game does not advance")
	main.toggle_pause()
	check(not main.paused, "game resumes")
	main.to_menu()
	check(main.over, "returning to the menu ends the game")

func _test_full_game(main) -> void:
	main.new_game("easy", 0, "standard")
	main.cash = 1.0e7
	var spots := _find_spots(main, 14)
	var picks := ["mecha", "mage", "samurai", "miko", "ice", "ninja", "mecha", "mage", "samurai", "idol", "miko", "ninja", "mecha", "mage"]
	for i in range(mini(spots.size(), picks.size())):
		var h = main.place_hero(picks[i], spots[i].x, spots[i].y)
		for t in range(4):
			main.buy_upgrade(h, 0)
		for t in range(2):
			main.buy_upgrade(h, 1)
	var key: String = main._save_key()
	await _run_rounds(main, 41)
	print("full game: round %d, lives %d, over=%s" % [main.round_num, main.lives, main.over])
	check(main.round_num >= 40, "reached round 40")
	check(main.has_medal(0, "easy", "standard"), "winning saves a medal")
	check(main.best_round(0, "easy", "standard") >= 40, "best round saved")
	check(key.begins_with("sakura_shore|easy|standard"), "save key format")
	# Sandbox never awards medals.
	main.new_game("easy", 1, "sandbox")
	main.round_num = 40
	main.victory()
	check(not main.has_medal(1, "easy", "sandbox"), "sandbox awards no medal")

# Walks a CharacterBody3D through every tile centre and checks it never gets stuck,
# falls through the floor, or escapes over a wall.
func _traverse(main) -> void:
	main.load_map(0)
	await process_frame
	var body := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.6
	cs.shape = cap
	body.add_child(cs)
	main.add_child(body)
	var track = main.level.track
	var cells: Array = track.cells
	body.global_position = track.cell_to_world(cells[1]) + Vector3(0, 1.2, 0)
	await physics_frame
	var stuck := 0
	for i in range(2, cells.size() - 1):
		var target: Vector3 = track.cell_to_world(cells[i])
		var frames := 0
		while Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(target.x, target.z)) > 0.4 and frames < 240:
			var d := Vector3(target.x - body.global_position.x, 0, target.z - body.global_position.z).normalized()
			body.velocity = d * 8.0 + Vector3(0, body.velocity.y - 20.0 / 60.0, 0)
			body.move_and_slide()
			await physics_frame
			frames += 1
		if frames >= 240:
			stuck += 1
			check(false, "body got stuck before cell %s (at %s)" % [cells[i], body.global_position])
			body.global_position = target + Vector3(0, 1.2, 0)
		check(body.global_position.y > 0.3, "body stayed on the track floor at cell %s" % cells[i])
		check(track.is_track_cell(track.world_to_cell(body.global_position)), "body stayed inside the track at %s" % cells[i])
	print("traversal: %d cells walked, stuck %d times" % [cells.size() - 3, stuck])
	var mid: Vector3 = track.cell_to_world(Vector2i(6, 1))
	body.global_position = mid + Vector3(0, 1.2, 0)
	await physics_frame
	for f in range(60):
		body.velocity = Vector3(0, body.velocity.y - 20.0 / 60.0, 8.0)
		body.move_and_slide()
		await physics_frame
	check(body.global_position.z - mid.z < 1.6, "barrier stops a body leaving the track")
	body.queue_free()
