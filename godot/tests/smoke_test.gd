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
	main.progress.save = main.save

	await _test_hero_levels(main)
	await _test_unlocks_and_looks(main)
	main.progress.unlock_everything(main.Defs.HERO_ORDER)
	await _test_menu_and_progress(main)
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

# Heroes join at player levels; the shop groups them into 5 classes of 3.
func _test_hero_levels(main) -> void:
	check(main.Defs.HERO_ORDER.size() == 15, "15 heroes")
	var seen := {}
	for c in main.Defs.CLASSES:
		check((c["heroes"] as Array).size() == 3, "class %s has 3 heroes" % c["name"])
		for k in c["heroes"]:
			seen[k] = true
			check(main.Defs.HEROES.has(k) and main.ABILITIES.has(k) and main.Defs.UNLOCK_LEVEL.has(k), "%s has data, an ability and an unlock level" % k)
	check(seen.size() == 15 and main.Defs.CLASSES.size() == 5, "5 classes cover all 15 heroes")
	main.new_game("normal", 0, "standard")
	main.cash = 1.0e6
	check(main.progress.level() == 1, "fresh save starts at level 1")
	var spots := _find_spots(main, 2)
	check(main.place_hero("nao", spots[0].x, spots[0].y) == null, "a level 13 hero can't be placed at level 1")
	check(main.place_hero("ninja", spots[0].x, spots[0].y) != null, "a level 1 hero can be placed")
	main.ui.select_class(4)
	check(main.ui.shop_buttons.has("nao") and not main.ui.shop_buttons.has("ninja"), "shop shows the selected class")
	main.ui.select_class(0)
	main.new_game("normal", 0, "sandbox")
	check(main.place_hero("nao", spots[1].x, spots[1].y) != null, "sandbox can use every hero")
	main.progress.add_xp(1000.0)
	check(main.progress.level() >= 4, "levelling up (now %d)" % main.progress.level())
	main.new_game("normal", 0, "standard")
	check(main.hero_available("idol") and not main.hero_available("nao"), "heroes unlock as you level up")
	main.progress.save.set_value("progress", "xp", 0.0)

# Hero XP gates upgrades past tier 1; every upgrade changes the hero's look.
func _test_unlocks_and_looks(main) -> void:
	main.new_game("normal", 0, "standard")
	main.cash = 1.0e6
	var spots := _find_spots(main, 3)
	var h = main.place_hero("ninja", spots[0].x, spots[0].y)
	var parts0: int = (h.model["root"] as Node3D).find_children("*", "MeshInstance3D", true, false).size()
	main.buy_upgrade(h, 0)
	check(h.tiers[0] == 1, "tier 1 is free to buy")
	var parts1: int = (h.model["root"] as Node3D).find_children("*", "MeshInstance3D", true, false).size()
	check(parts1 > parts0, "tier 1 adds visible parts (%d -> %d)" % [parts0, parts1])
	main.buy_upgrade(h, 0)
	check(h.tiers[0] == 1 and main.can_upgrade(h, 0) == "LOCKED", "tier 2 is locked without hero XP")
	check(not main.unlock_upgrade("ninja", 0, 3), "can't unlock tier 3 before tier 2")
	check(not main.unlock_upgrade("ninja", 0, 2), "can't unlock without enough XP")
	main.progress.add_hero_xp("ninja", 300.0)
	check(main.unlock_upgrade("ninja", 0, 2), "unlocking tier 2 with XP works")
	check(main.progress.hero_xp("ninja") == 50.0, "unlocking spends hero XP (%.0f left)" % main.progress.hero_xp("ninja"))
	main.buy_upgrade(h, 0)
	check(h.tiers[0] == 2, "an unlocked upgrade can be bought")
	check(main.progress.is_unlocked("unlock_1"), "Fresh Training achievement unlocks")
	# Hero XP is earned in play
	var xp0: float = main.progress.hero_xp("ninja")
	await _run_rounds(main, 2)
	check(main.progress.hero_xp("ninja") > xp0, "heroes earn XP in play (%.0f -> %.0f)" % [xp0, main.progress.hero_xp("ninja")])
	# Looks: every path and tier adds parts, tier 3 tints the outfit, path 3 adds spinning orbs
	for p in range(3):
		main.new_game("normal", 0, "sandbox")
		var hh = main.place_hero("miko", spots[1].x, spots[1].y)
		var torso: MeshInstance3D = hh.model["outfit_parts"][1]
		var before_col: Color = (torso.material_override as StandardMaterial3D).albedo_color
		var counts: Array = []
		for t in range(4):
			if p != 0 and t >= 2:
				pass
			main.buy_upgrade(hh, p)
			counts.append((hh.model["root"] as Node3D).find_children("*", "MeshInstance3D", true, false).size())
		check(hh.tiers[p] == 4, "sandbox ignores upgrade locks (path %d tier %d)" % [p + 1, hh.tiers[p]])
		var grows := true
		for i in range(1, counts.size()):
			if counts[i] <= counts[i - 1] and not (p == 0 and i == 2):
				grows = false
		check(grows, "path %d: each tier adds visible parts %s" % [p + 1, counts])
		var after_col: Color = (torso.material_override as StandardMaterial3D).albedo_color
		check(not after_col.is_equal_approx(before_col), "path %d tier 3 tints the outfit" % (p + 1))
		if p == 2:
			check((hh.model["spinners"] as Array).size() >= 2, "mystic path adds orbiting parts")
	print("unlocks and looks ok")

# Main menu, attract demo, daily challenge, settings, XP, achievements, sandbox tools.
func _test_menu_and_progress(main) -> void:
	main.to_home()
	check(main.attract and main.menu.visible and main.hub.visible, "starts in the main menu over the village scene")
	check(main.hub.camera.current, "the village camera is active in the menu")
	check(not main.level.visible, "the game board is hidden behind the menu")
	check(not main.ui.hud_box.visible and not main.ui.shop.visible, "HUD is hidden behind the menu")
	check(main.hub.heroes.size() >= 3, "village shows the player's heroes (%d)" % main.hub.heroes.size())
	check(main.heroes.is_empty() and main.enemies.is_empty(), "no game runs behind the menu")
	main.menu.refresh()
	check(main.menu.level_lbl.text == str(main.progress.level()), "menu shows the player level")
	main.menu._open("heroes")
	main.menu._open("achievements")
	main.menu._open("stats")
	main.menu._open("settings")
	main.menu._open("howto")
	main.menu.show_home()
	main.ui.show_map_select()
	check(main.ui.start_screen.visible and not main.menu.visible, "PLAY opens map select")
	main.ui._on_back_home()
	check(main.menu.visible and not main.ui.start_screen.visible, "BACK returns to the main menu")
	# Settings
	main.set_setting("shake", false)
	check(main.shake_mul() == 0.0, "camera shake can be turned off")
	main.set_setting("shake", true)
	main.set_setting("shadows", false)
	check(not main.sun.shadow_enabled, "shadows can be turned off")
	main.set_setting("shadows", true)
	main.set_setting("sound", false)
	check(main.sfx.muted, "sound setting mutes")
	main.set_setting("sound", true)
	main.sfx.muted = true
	# Daily challenge
	var d: Dictionary = main.progress.daily()
	check(d["map"] >= 0 and d["map"] < main.Maps.MAPS.size(), "daily challenge picks a map")
	check(d == main.progress.daily(), "daily challenge is stable within a day")
	main.start_daily()
	check(main.daily_active and not main.attract and main.map_index == d["map"] and main.mode == d["mode"], "daily challenge starts its game")
	check(main.ui.hud_box.visible, "HUD is shown in a real game")
	check(main.camera.current and not main.hub.visible and main.level.visible, "the game camera and board return for a real game")
	# Progress during a real game
	main.cash = 1.0e6
	var spots := _find_spots(main, 7)
	for i in range(mini(7, spots.size())):
		var h = main.place_hero(main.Defs.HERO_ORDER[i], spots[i].x, spots[i].y)
		for t in range(4):
			main.buy_upgrade(h, 0)
		main.use_ability(h)
	check(main.progress.get_stat("heroes_placed") >= 7, "heroes placed are counted")
	check(main.progress.get_stat("tier4") >= 7, "tier 4 upgrades are counted")
	check(main.progress.is_unlocked("full_squad"), "Full Squad achievement unlocks")
	check(main.progress.is_unlocked("ability_1"), "Special Move achievement unlocks")
	var lv: int = main.progress.level()
	await _run_rounds(main, 3)
	check(main.progress.get_stat("pops") > 0 and main.progress.is_unlocked("first_pop"), "pops count and First Pop unlocks")
	check(main.progress.xp() > 0.0, "XP is earned (%.0f)" % main.progress.xp())
	main.round_num = 40
	main.victory()
	check(main.progress.get_stat("wins") == 1 and main.progress.is_unlocked("first_win"), "a win is recorded")
	check(main.progress.get_stat("daily_wins") == 1, "the daily challenge win is recorded")
	check(main.progress.daily()["done"], "daily challenge marked done")
	check(main.progress.level() >= lv, "winning keeps or raises the level (%d -> %d)" % [lv, main.progress.level()])
	print("progress: level %d, %d xp, %d/%d achievements" % [main.progress.level(), main.progress.xp(), main.progress.unlocked_count(), main.progress.ACHIEVEMENTS.size()])
	# Next-round preview
	var prev: Array = main.preview_round(25)
	check(not prev.is_empty() and prev[0][0] == "oni", "round 25 preview leads with the boss")
	# Sandbox tools
	main.new_game("normal", 0, "sandbox")
	check(main.ui.sandbox_panel.visible, "sandbox panel shows in sandbox mode")
	main.sandbox_spawn("prism", true, true, false)
	check(main.enemies.size() == 1 and main.enemies[0].camo and main.enemies[0].fortified, "sandbox spawns spirits with modifiers")
	main.sandbox_clear()
	check(main.enemies.is_empty(), "sandbox clear removes spirits")
	var wins_before: float = main.progress.get_stat("wins")
	main.round_num = 40
	main.victory()
	check(main.progress.get_stat("wins") == wins_before, "sandbox wins do not count")
	# Home from a game, and reset
	main.to_home()
	check(main.attract and main.menu.visible and main.hub.visible, "HOME returns to the main menu")
	main.reset_progress()
	check(main.progress.xp() == 0.0 and main.progress.unlocked_count() == 0, "progress reset clears XP and achievements")
	check(not main.progress.upgrade_unlocked("ninja", 0, 2), "progress reset re-locks upgrades")
	main.progress.unlock_everything(main.Defs.HERO_ORDER)

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
	var n_heroes: int = main.Defs.HERO_ORDER.size()
	var spots := _find_spots(main, n_heroes)
	check(spots.size() >= n_heroes, "room for %d heroes (%d spots)" % [n_heroes, spots.size()])
	var hs: Array = []
	for i in range(mini(n_heroes, spots.size())):
		var k: String = main.Defs.HERO_ORDER[i]
		var h = main.place_hero(k, spots[i].x, spots[i].y)
		check(h.ability_cd < 0.0, "%s ability locked at first" % k)
		for t in range(3):
			main.buy_upgrade(h, 0)
		check(h.ability_cd == 0.0, "%s ability unlocked at tier 3" % k)
		hs.append(h)
	check(main.ability_heroes().size() == mini(8, hs.size()), "ability bar lists up to 8 heroes (%d)" % main.ability_heroes().size())
	for j in range(12):
		main.spawn_enemy(["pink", "mask", "oni"][j % 3], 10.0 + j * 4.0)
	var lives0: float = main.lives
	for h in hs:
		main.use_ability(h)
		check(h.ability_cd > 0.0, "%s ability goes on cooldown" % h.key)
		main.use_ability(h)  # second use is ignored while cooling
		for i in range(20):
			main._step(1.0 / 60.0)
	check(main.encore_t > 0.0, "Encore! buff is active")
	check(main.lives >= lives0 + 25.0 or main.lives > lives0, "Blessing restores lives")
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
	check(main.attract and main.ui.start_screen.visible, "MAPS leaves the game for map select over the demo")

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
