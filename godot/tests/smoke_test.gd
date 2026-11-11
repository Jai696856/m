# Headless smoke test: plays the game end to end without a window.
#   godot --headless --path . -s tests/smoke_test.gd
# Places every hero, buys every upgrade path, runs rounds (incl. bosses),
# sells, and walks a physics body along the whole track to prove it is
# traversable. Exits with code 1 on any failure.
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

	# --- Track structure -------------------------------------------------
	var track = main.level.track
	check(track.validate(), "track route validates")
	check(track.tiles.size() == track.cells.size() - 2, "one tile per inner cell")
	check(main.path_len > 150.0, "spirit path is long enough (%.1f)" % main.path_len)

	# --- Start a game and place one of each hero --------------------------
	main.new_game("normal")
	main.cash = 1_000_000.0
	var placed := {}
	for k in main.Defs.HERO_ORDER:
		var spot = _find_spot(main)
		check(spot != null, "found a valid build spot for %s" % k)
		if spot == null:
			continue
		var h = main.place_hero(k, spot.x, spot.y)
		check(h != null, "placed %s" % k)
		placed[k] = h
	# Upgrades: path 0 to tier 4 and path 1 to tier 2 on every hero; the third path must be locked.
	for k in placed:
		var h = placed[k]
		for i in range(4):
			main.buy_upgrade(h, 0)
		for i in range(2):
			main.buy_upgrade(h, 1)
		check(h.tiers == [4, 2, 0], "%s upgrade tiers %s" % [k, h.tiers])
		check(main.can_upgrade(h, 2) != "", "%s third path locked" % k)
		check(main.can_upgrade(h, 1) != "", "%s second path capped at tier 2" % k)

	# --- Play rounds, including the round-25 and round-40 bosses ----------
	var rounds_ok := true
	for r in range(42):
		if main.over:
			break
		main.cash = maxf(main.cash, 50000.0)
		main.start_round()
		var steps := 0
		while main.running and steps < 60000:
			main._step(1.0 / 60.0)
			steps += 1
		if main.running:
			rounds_ok = false
			check(false, "round %d never finished" % main.round_num)
			break
		if r % 10 == 0:
			print("round %d done, lives %d, enemies %d, projectiles %d" % [main.round_num, main.lives, main.enemies.size(), main.projectiles.size()])
		await process_frame
	check(rounds_ok, "all rounds completed")
	check(main.round_num >= 40, "reached round 40 (got %d)" % main.round_num)
	print("final round %d, lives %d, over=%s" % [main.round_num, main.lives, main.over])

	# --- Sell everything ---------------------------------------------------
	for k in placed:
		main.sell_hero(placed[k])
	check(main.heroes.is_empty(), "all heroes sold")

	# --- Physics: drive a body along the whole track ----------------------
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

func _find_spot(main) -> Variant:
	for x in range(-34, 34, 2):
		for z in range(-20, 21, 2):
			if main.valid_spot(float(x), float(z)):
				return Vector2(x, z)
	return null

# Walks a CharacterBody3D through every tile centre and checks it never gets stuck,
# falls through the floor, or escapes over a wall.
func _traverse(main) -> void:
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
	var start: Vector3 = track.cell_to_world(cells[1])
	body.global_position = start + Vector3(0, 1.2, 0)
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
		check(body.global_position.y > 0.3, "body stayed on the track floor at cell %s (y=%.2f)" % [cells[i], body.global_position.y])
		var c: Vector2i = track.world_to_cell(body.global_position)
		check(track.is_track_cell(c), "body stayed inside the track at %s" % cells[i])
	print("traversal: %d cells walked, stuck %d times" % [cells.size() - 3, stuck])
	# A body pushed sideways into a wall must be stopped by the barrier.
	var mid: Vector3 = track.cell_to_world(Vector2i(6, 1))
	body.global_position = mid + Vector3(0, 1.2, 0)
	await physics_frame
	for f in range(60):
		body.velocity = Vector3(0, body.velocity.y - 20.0 / 60.0, 8.0)
		body.move_and_slide()
		await physics_frame
	check(body.global_position.z - mid.z < 1.6, "barrier stops a body leaving the track (dz=%.2f)" % (body.global_position.z - mid.z))
