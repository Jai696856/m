extends SceneTree
# Headless check: death pause is short and a tap skips it.
func _initialize() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	main.play_main(0, false)
	await _frames(90)
	var w = main.world
	assert(w.mode == "play", "level did not start: " + w.mode)
	w._die()
	assert(w.dead_t == 0.5, "death pause should be 0.5s")
	var tap:= InputEventKey.new()
	tap.keycode = KEY_SPACE
	tap.pressed = true
	w._unhandled_input(tap)
	assert(w.mode == "dead" and w.dead_t > 0.3, "tap during lockout must not skip")
	await create_timer(0.25).timeout
	w._unhandled_input(tap)
	await _frames(3)
	assert(w.mode == "play" and w.attempts == 2, "tap after lockout should restart: %s %d" % [w.mode, w.attempts])
	var bar = main.screen.get_children().filter(func(c): return c.get("kind") == "progress")
	assert(bar.size() == 1, "progress bar missing")
	print("RETRY_TEST_OK")
	quit()

func _frames(n: int) -> void:
	for i in n:
		await process_frame
