extends SceneTree
## Proves every main, trial and featured level (and a week of dailies) can be finished.
## godot --headless --path gravity-dash-godot -s res://tools/check_levels.gd

func _init() -> void:
	var L = load("res://scripts/levels.gd")
	var params: Array = []
	for i in L.main_count():
		params.append(L.main_params(i))
	for t in L.TRIALS.size():
		for j in 3:
			params.append(L.trial_params(t, j))
	for i in L.FEATURED.size():
		params.append(L.featured_params(i))
	for d in 7:
		params.append(L.daily_params("2026-11-%02d" % (10 + d)))
	params.append(L.weekly_params("2026-W47"))
	params.append(L.event_params("2026-W47"))
	var ok := true
	var offsets := {}
	for p in params:
		var t0 := Time.get_ticks_msec()
		var lv: Dictionary = L.build_verified(p)
		var dt := Time.get_ticks_msec() - t0
		var secs: float = float(lv.end) / float(lv.speed)
		print("%-26s %-16s %s  tier %d  %3.0fs  %4d objs  %3d presses  %5d ms" % [
			p.key, p.name, "OK  " if lv.verified else "FAIL", p.tier, secs, lv.objs.size(), lv.solution.size(), dt])
		if not lv.verified:
			ok = false
		elif int(lv.attempt) > 0 and not str(p.key).begins_with("daily") and not str(p.key).begins_with("weekly") and not str(p.key).begins_with("event"):
			offsets[p.key] = int(lv.attempt)
	print("OFFSETS ", JSON.stringify(offsets))
	print("ALL LEVELS BEATABLE" if ok else "SOME LEVELS ARE IMPOSSIBLE")
	quit(0 if ok else 1)
