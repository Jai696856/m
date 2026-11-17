extends SceneTree
## Proves every level can be finished.
## godot --headless --path gravity-dash-godot -s res://tools/check_levels.gd

func _init() -> void:
	var Levels = load("res://scripts/levels.gd")
	var Sim = load("res://scripts/sim.gd")
	var ok := true
	for i in Levels.DEFS.size():
		var lv: Dictionary = Levels.build(i)
		var t0 := Time.get_ticks_msec()
		var r: Dictionary = Sim.solve(lv)
		var secs: float = float(lv.end) / float(lv.speed)
		print("%2d %-15s %s  %4.0fs long  %5d objects  %d flips in solution  (%d ms)" % [
			i + 1, lv.def.name, "OK  " if r.ok else "FAIL", secs, lv.objs.size(), r.path.size(), Time.get_ticks_msec() - t0])
		if not r.ok:
			print("    got stuck at x=%d of %d" % [int(r.far), int(r.end)])
			ok = false
	print("ALL LEVELS BEATABLE" if ok else "SOME LEVELS ARE IMPOSSIBLE")
	quit(0 if ok else 1)
