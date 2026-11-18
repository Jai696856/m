extends Node2D
## Runs and draws a level, and doubles as the animated backdrop behind the menus.
## World units: the playfield is 400 high (ceiling at 40, floor at 360); it is scaled to fit the window.

signal died(pct: int, new_best: bool)
signal won(result: Dictionary)
signal win_panel_ready
signal picked(kind: String)

const Sim = preload("res://scripts/sim.gd")
const Skins = preload("res://scripts/skins.gd")
const Levels = preload("res://scripts/levels.gd")
const FONT = preload("res://fonts/Fredoka-Bold.ttf")
const H := 400.0
const T := 40.0
const DARK := Color(0.04, 0.024, 0.11)
const ROSE := Color(1.0, 0.36, 0.54)
const WIN_TEXT := "LEVEL COMPLETE!"

var mode := "menu"  # menu, play, paused, dead, win
var lv: Dictionary = {}
var p: Dictionary = {}
var s
var prev
var pending := false
var autopilot: Dictionary = {}
var practice := false
var checkpoints: Array = []
var cp_timer := 0.0
var attempts := 1
var flips := 0
var level_time := 0.0
var dead_t := 0.0
var rot := 0.0
var rot_target := 0.0
var squash := 0.0
var shake := 0.0
var flash := 0.0
var trail: Array = []
var parts: Array = []
var rings: Array = []
var t := 0.0
var sc := 1.0
var view_w := 640.0
var off_y := 0.0
var vp := Vector2(1280, 720)
var cam_x := 0.0
var win_t := 0.0
var win_from := Vector2.ZERO
var win_fired := false
var firework_t := 0.0
var panel_sent := false
var pal: Dictionary = {}
var pal_target: Dictionary = {}
var color_i := 0
var coins_got := [false, false, false]
var shards_got: Dictionary = {}
var ghost := PackedVector2Array()
var rec := PackedVector2Array()
var menu_g := 1.0
var menu_y := 330.0
var menu_vy := 0.0
var menu_flip := 1.4
var menu_frame := 0
var show_cube := true
var hills: Array = []
var stars_bg: Array = []
var _shx := 0.0
var _shy := 0.0


func _ready() -> void:
	s = Sim.State.new()
	prev = s.copy()
	pal = Levels.palette(0.7)
	pal_target = pal.duplicate()
	_make_scenery(900)


func _make_scenery(seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	hills.clear()
	for layer in 3:
		var pts: Array = []
		var x := 0.0
		var base: float = [250.0, 285.0, 318.0][layer]
		while x < 2400.0:
			var w := rng.randf_range(60.0, 180.0)
			var h := rng.randf_range(20.0, 110.0 - layer * 25.0)
			pts.append(Vector3(x, base - h, w))
			x += w
		hills.append({"pts": pts, "depth": [0.12, 0.25, 0.45][layer], "shade": [0.35, 0.6, 0.85][layer]})
	stars_bg.clear()
	for i in 40:
		stars_bg.append(Vector3(rng.randf() * 2400.0, rng.randf_range(50.0, 220.0), rng.randf_range(0.6, 1.8)))


# ---------- Flow ----------

func set_menu() -> void:
	mode = "menu"
	lv = {}
	parts.clear()
	rings.clear()
	trail.clear()
	flash = 0.0
	shake = 0.0
	menu_g = 1.0
	menu_y = 330.0
	menu_vy = 0.0
	rot = 0.0
	rot_target = 0.0
	practice = false
	Audio.busy_frame = false


func start(level: Dictionary, use_practice := false) -> void:
	lv = level
	p = lv.p
	practice = use_practice
	pal = Levels.palette(float(p.hue))
	pal_target = pal.duplicate()
	_make_scenery(int(p.seed))
	attempts = 1
	level_time = 0.0
	ghost = Save.ghost(p.key) if Save.setting("ghost") else PackedVector2Array()
	checkpoints.clear()
	reset_run()


func reset_run() -> void:
	s = Sim.State.new()
	if practice and not checkpoints.is_empty():
		s = checkpoints[-1].copy()
	prev = s.copy()
	rot = 0.0 if s.g > 0.0 else PI
	rot_target = rot
	squash = 0.0
	flash = 0.0
	flips = 0
	pending = false
	cp_timer = 0.0
	trail.clear()
	parts.clear()
	rings.clear()
	rec = PackedVector2Array()
	coins_got = [false, false, false]
	shards_got.clear()
	color_i = 0
	pal = Levels.palette(float(p.hue))
	pal_target = pal.duplicate()
	for c in lv.colors:
		if float(c.x) <= s.x:
			pal_target = Levels.palette(float(p.hue), float(c.shift))
			pal = pal_target.duplicate()
			color_i += 1
	mode = "play"
	Audio.busy_frame = true
	if not practice:
		Save.record_attempt(p.key)
		Audio.play_level(p)
	else:
		Audio.play_menu()


func set_paused(paused: bool) -> void:
	if paused and mode == "play":
		mode = "paused"
		Audio.pause_music(true)
	elif not paused and mode == "paused":
		mode = "play"
		Audio.pause_music(false)


func pct() -> int:
	if lv.is_empty():
		return 0
	return clampi(int(float(s.x) / float(lv.end) * 100.0), 0, 100)


func place_checkpoint() -> void:
	if not practice or mode != "play" or s.dead:
		return
	checkpoints.append(s.copy())
	Save.add_stat("checkpoints", 1)
	Audio.sfx("checkpoint")


func remove_checkpoint() -> void:
	if practice and not checkpoints.is_empty():
		checkpoints.pop_back()


func _unhandled_input(e: InputEvent) -> void:
	if mode != "play":
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pending = true
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo:
		if e.keycode in [KEY_SPACE, KEY_UP, KEY_W, KEY_DOWN, KEY_S]:
			pending = true
			get_viewport().set_input_as_handled()
		elif e.keycode == KEY_Z:
			place_checkpoint()
		elif e.keycode == KEY_X:
			remove_checkpoint()


func _physics_process(_delta: float) -> void:
	if mode != "play":
		return
	prev = s.copy()
	var was_ground: bool = s.ground
	var press := pending
	if not autopilot.is_empty():
		press = autopilot.has(s.f)
	pending = false
	Sim.step(s, lv, press)
	level_time += Sim.DT
	Save.add_stat("distance", float(lv.speed) * s.spd * Sim.DT / T)
	if s.flipped:
		flips += 1
		Save.add_stat("flips", 1)
		rot_target += PI
		if s.event in ["flip", ""]:
			Audio.sfx("flip_up" if s.g < 0.0 else "flip_down")
		_puff(-s.g)
	match s.event:
		"orb":
			Save.add_stat("orbs", 1)
			Audio.sfx("orb")
			rings.append({"p": Vector2(s.x + s.ps * 0.5, s.y + s.ps * 0.5), "r": 8.0, "v": 160.0, "w": 4.0, "life": 0.35, "max": 0.35, "col": Color("ffe14d")})
		"pad":
			Save.add_stat("pads", 1)
			Audio.sfx("pad")
		"portal", "speed", "size":
			Save.add_stat("portals", 1)
			Audio.sfx("portal")
	if not was_ground and s.ground and not s.dead:
		squash = 1.0
		_puff(s.g)
	if s.f % 3 == 0:
		trail.append(Vector3(s.x, s.y, s.ps))
		if trail.size() > 16:
			trail.pop_front()
	if s.f % 6 == 0 and not practice:
		rec.append(Vector2(s.x, s.y))
	_collect()
	_colors()
	if practice and Save.setting("auto_cp") and s.ground:
		cp_timer += Sim.DT
		if cp_timer > 2.5:
			cp_timer = 0.0
			checkpoints.append(s.copy())
	if s.dead:
		_die()
	elif s.won:
		_win()


func _collect() -> void:
	var c := Vector2(s.x + s.ps * 0.5, s.y + s.ps * 0.5)
	var reach: float = s.ps * 0.5 + 14.0
	if not practice:
		for i in lv.coins.size():
			if not coins_got[i] and c.distance_to(lv.coins[i]) < reach:
				coins_got[i] = true
				Audio.sfx("coin")
				picked.emit("coin")
				_burst(lv.coins[i], 18, [Color("ffd34d"), Color.WHITE], 220.0, 0.0)
	for i in lv.shards.size():
		if not shards_got.has(i) and c.distance_to(lv.shards[i]) < reach - 4.0:
			shards_got[i] = true
			if not practice:
				Audio.sfx("shard")
			picked.emit("shard")


func _colors() -> void:
	if color_i < lv.colors.size() and s.x >= float(lv.colors[color_i].x):
		pal_target = Levels.palette(float(p.hue), float(lv.colors[color_i].shift))
		color_i += 1


func _die() -> void:
	mode = "dead"
	dead_t = 0.55 if practice else 0.9
	if Save.setting("shake"):
		shake = 14.0
	if not practice:
		Audio.stop_music()
	Audio.sfx("die")
	var pc := pct()
	var nb: bool = Save.record_progress(p.key, pc, practice)
	if nb and not practice and rec.size() > 10:
		Save.save_ghost(p.key, rec)
	Save.add_stat("deaths", 1)
	Save.save_data()
	_death_effect(Vector2(s.x + s.ps * 0.5, s.y + s.ps * 0.5))
	died.emit(pc, nb)


func _win() -> void:
	mode = "win"
	win_t = 0.0
	win_fired = false
	panel_sent = false
	firework_t = 0.0
	win_from = Vector2(s.x, s.y)
	Audio.stop_music()
	Audio.busy_frame = false
	if not practice:
		Save.save_ghost(p.key, rec)
	var res: Dictionary = Save.record_complete(p, flips, level_time, coins_got, shards_got.size() if not practice else 0, practice)
	res["attempts"] = attempts
	res["flips"] = flips
	res["time"] = level_time
	res["coins"] = coins_got.duplicate()
	res["shards_picked"] = shards_got.size()
	won.emit(res)


# ---------- Update ----------

func _process(delta: float) -> void:
	t += delta
	vp = get_viewport_rect().size
	sc = minf(vp.y / H, vp.x / 640.0)
	view_w = vp.x / sc
	off_y = (vp.y - H * sc) * 0.5
	match mode:
		"play":
			Save.add_stat("time", delta)
		"dead":
			Save.add_stat("time", delta)
			dead_t -= delta
			if dead_t <= 0.0:
				attempts += 1
				reset_run()
		"win":
			_update_win(delta)
		"menu":
			_update_menu(delta)
	for k in pal:
		pal[k] = (pal[k] as Color).lerp(pal_target[k], minf(1.0, delta * 2.0))
	rot = lerpf(rot, rot_target, minf(1.0, delta * 14.0))
	squash = maxf(0.0, squash - delta * 6.0)
	shake = maxf(0.0, shake - delta * 40.0)
	flash = maxf(0.0, flash - delta * 1.6)
	for q in parts:
		var v: Vector2 = q.v
		if q.get("implode", false):
			v = (q.home - q.p) * 6.0
		v.y += float(q.g) * delta
		v *= pow(0.25, delta) if not q.get("implode", false) else 1.0
		q.v = v
		q.p = q.p + v * delta
		q.life = float(q.life) - delta
		q.rot = float(q.get("rot", 0.0)) + float(q.get("spin", 0.0)) * delta
	parts = parts.filter(func(q): return q.life > 0.0)
	for r in rings:
		r.r = float(r.r) + float(r.v) * delta
		r.life = float(r.life) - delta
	rings = rings.filter(func(r): return r.life > 0.0)
	queue_redraw()


func _update_menu(delta: float) -> void:
	cam_x += 230.0 * delta
	menu_flip -= delta
	if menu_flip <= 0.0:
		menu_flip = randf_range(0.8, 1.9)
		menu_g = -menu_g
		menu_vy = menu_g * 180.0
		rot_target += PI
	menu_vy = clampf(menu_vy + menu_g * Sim.G * delta, -Sim.VMAX, Sim.VMAX)
	menu_y += menu_vy * delta
	if menu_y > 330.0 or menu_y < 40.0:
		if absf(menu_vy) > 200.0:
			squash = 1.0
		menu_y = clampf(menu_y, 40.0, 330.0)
		menu_vy = 0.0
	menu_frame += 1
	if menu_frame % 4 == 0:
		trail.append(Vector3(cam_x + view_w * 0.28, menu_y, 30.0))
		if trail.size() > 16:
			trail.pop_front()
	pal_target = Levels.palette(fposmod(t * 0.012, 1.0))


func _update_win(delta: float) -> void:
	win_t += delta
	if win_t >= 0.7 and not win_fired:
		win_fired = true
		if Save.setting("flash"):
			flash = 1.0
		if Save.setting("shake"):
			shake = 12.0
		Audio.sfx("win")
		var gate := Vector2(float(lv.end) + 20.0, 200.0)
		_burst(gate, 90, [pal.accent, pal.glow, Color.WHITE, Save.c1(), Save.c2()], 560.0, 0.0)
		for k in 3:
			rings.append({"p": gate, "r": 10.0 + k * 8.0, "v": 560.0 - k * 130.0, "w": 10.0 - k * 2.5,
				"life": 1.0, "max": 1.0, "col": Color.WHITE if k == 0 else pal.accent})
	if win_fired and win_t < 3.6:
		firework_t -= delta
		if firework_t <= 0.0:
			firework_t = randf_range(0.14, 0.28)
			var at := Vector2(cam_x + randf_range(0.1, 0.9) * view_w, randf_range(70.0, 300.0))
			var hue := randf()
			_burst(at, 30, [Color.from_hsv(hue, 0.6, 1.0), Color.from_hsv(fposmod(hue + 0.1, 1.0), 0.4, 1.0), Color.WHITE], 300.0, 260.0)
			rings.append({"p": at, "r": 4.0, "v": 240.0, "w": 3.0, "life": 0.4, "max": 0.4, "col": Color.from_hsv(hue, 0.5, 1.0)})
			Audio.sfx("pop")
	if win_t >= 2.2 and not panel_sent:
		panel_sent = true
		win_panel_ready.emit()


func _burst(at: Vector2, n: int, cols: Array, speed: float, grav: float, shape := "rect") -> void:
	if Save.setting("low_detail"):
		n = n / 3
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(0.25, 1.0) * speed
		var life := randf_range(0.5, 1.1)
		parts.append({"p": at, "v": Vector2(cos(a), sin(a)) * sp, "life": life, "max": life, "shape": shape,
			"size": randf_range(3.0, 9.0), "col": cols[i % cols.size()], "g": grav, "rot": randf() * TAU, "spin": randf_range(-12.0, 12.0)})


func _death_effect(at: Vector2) -> void:
	var c1 := Save.c1()
	var c2 := Save.c2()
	match Save.skin("death"):
		1:
			_burst(at, 26, [c1, c2], 380.0, 600.0, "tri")
		2:
			for k in 4:
				rings.append({"p": at, "r": 4.0 + k * 6.0, "v": 420.0 - k * 70.0, "w": 8.0 - k, "life": 0.6, "max": 0.6, "col": c1 if k % 2 == 0 else c2})
		3:
			var cols := [Color("ff5c8a"), Color("ffd34d"), Color("5ce1ff"), Color("7ee04a"), Color("b07aff")]
			_burst(at, 50, cols, 420.0, 700.0, "rect")
		4:
			for i in 30:
				parts.append({"p": at + Vector2(randf_range(-40, 40), randf_range(-60, 0)), "v": Vector2(randf_range(-30, 30), randf_range(-80, 0)),
					"life": 1.0, "max": 1.0, "shape": "rect", "size": 5.0, "col": [c1, c2][i % 2], "g": 900.0, "rot": 0.0, "spin": 0.0})
		5:
			for i in 36:
				var a := randf() * TAU
				var from := at + Vector2(cos(a), sin(a)) * randf_range(60.0, 110.0)
				parts.append({"p": from, "v": Vector2.ZERO, "home": at, "implode": true, "life": 0.5, "max": 0.5, "shape": "rect",
					"size": 5.0, "col": [c1, c2, Color.WHITE][i % 3], "g": 0.0, "rot": 0.0, "spin": 0.0})
			rings.append({"p": at, "r": 2.0, "v": 300.0, "w": 6.0, "life": 0.5, "max": 0.5, "col": Color.WHITE})
		_:
			_burst(at, 42, [c1, c2, Color.WHITE], 460.0, 0.0)
			rings.append({"p": at, "r": 6.0, "v": 380.0, "w": 6.0, "life": 0.45, "max": 0.45, "col": c1})


func _puff(dir: float) -> void:
	if Save.setting("low_detail"):
		return
	var y: float = (s.y + s.ps) if dir > 0.0 else s.y
	for i in 8:
		parts.append({"p": Vector2(s.x + randf() * s.ps, y), "v": Vector2(randf_range(-180.0, -60.0), -dir * randf_range(30.0, 120.0)),
			"life": 0.35, "max": 0.35, "shape": "rect", "size": randf_range(3.0, 6.0), "col": Color(1, 1, 1, 0.7), "g": 0.0, "rot": 0.0, "spin": 0.0})


# ---------- Drawing ----------

func _tf(cam: float) -> void:
	draw_set_transform(Vector2(-cam * sc + _shx * sc, off_y + _shy * sc), 0.0, Vector2(sc, sc))


func _screen(q: Vector2) -> Vector2:
	return Vector2((q.x - cam_x + _shx) * sc, (q.y + _shy) * sc + off_y)


func _text(txt: String, at: Vector2, size: int, col: Color) -> void:
	draw_string_outline(FONT, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.28), Color(DARK, col.a))
	draw_string(FONT, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw() -> void:
	var pulse: float = Audio.beat_pulse()
	var low: bool = Save.setting("low_detail")
	var ix: float = s.x
	var iy: float = s.y
	if mode == "play":
		var a := Engine.get_physics_interpolation_fraction()
		ix = lerpf(prev.x, s.x, a)
		iy = lerpf(prev.y, s.y, a)
	if mode in ["play", "dead", "paused"]:
		cam_x = minf(ix - view_w * 0.28, float(lv.end) + 160.0 - view_w)
	_shx = randf_range(-shake, shake) * 0.5 if shake > 0.0 else 0.0
	_shy = randf_range(-shake, shake) * 0.5 if shake > 0.0 else 0.0
	var y_top := -off_y / sc - 20.0
	var y_bot := H + off_y / sc + 20.0
	var sky_a: Color = pal.sky_a
	var sky_b: Color = pal.sky_b
	var accent: Color = pal.accent

	# Sky gradient, stars and three layers of geometric hills
	_tf(0.0)
	draw_rect(Rect2(-40, y_top, view_w + 80, y_bot - y_top), sky_a)
	draw_polygon(PackedVector2Array([Vector2(-40, 40), Vector2(view_w + 40, 40), Vector2(view_w + 40, 330), Vector2(-40, 330)]),
		PackedColorArray([sky_a, sky_a, sky_b, sky_b]))
	if not low:
		for st in stars_bg:
			var sx := fposmod(st.x - cam_x * 0.05, 2400.0) - 100.0
			if sx < view_w + 20.0:
				draw_rect(Rect2(sx, st.y, st.z, st.z), Color(1, 1, 1, 0.25 + 0.2 * sin(t * 2.0 + st.x)))
		for layer in hills:
			var col: Color = sky_a.lerp(pal.hill, layer.shade)
			var off := fposmod(cam_x * float(layer.depth), 2400.0)
			for pass_i in 2:
				for h in layer.pts:
					var hx: float = h.x - off + pass_i * 2400.0
					if hx > view_w + 10.0 or hx + h.z < -10.0:
						continue
					draw_rect(Rect2(hx, h.y, h.z + 1.0, 360.0 - h.y), col)
					draw_rect(Rect2(hx, h.y, h.z + 1.0, 3.0), col.lightened(0.12))

	_tf(cam_x)
	if not lv.is_empty():
		_draw_level(pulse)
	_draw_bands(pulse, y_top, y_bot)

	if not lv.is_empty():
		var gate_x: float = lv.end
		if gate_x < cam_x + view_w + 100.0:
			for k in 6:
				var c := Color("ffc94d") if k % 2 == 0 else Color("5ce1ff")
				if win_fired:
					c = c.lerp(Color.WHITE, flash)
				draw_rect(Rect2(gate_x + k * 14.0, 40, 8, 320), Color(c, 0.55 - k * 0.07))
		if practice:
			for cp in checkpoints:
				var cc := Vector2(cp.x + cp.ps * 0.5, cp.y + cp.ps * 0.5)
				draw_colored_polygon(PackedVector2Array([cc + Vector2(0, -12), cc + Vector2(9, 0), cc + Vector2(0, 12), cc + Vector2(-9, 0)]), Color("7ee04a"))
				draw_polyline(Skins.closed(PackedVector2Array([cc + Vector2(0, -12), cc + Vector2(9, 0), cc + Vector2(0, 12), cc + Vector2(-9, 0)])), DARK, 2.0)
		if ghost.size() > 2 and mode in ["play", "paused", "dead"] and not practice:
			var gi := clampi(int(prev.f / 6.0), 0, ghost.size() - 1)
			var gp: Vector2 = ghost[gi]
			var gc := Color("ffd34d") if Save.has_extra("ghost_gold") else Color(1, 1, 1)
			draw_rect(Rect2(gp, Vector2(30, 30)), Color(gc, 0.18))
			draw_rect(Rect2(gp, Vector2(30, 30)), Color(gc, 0.55), false, 2.0)

	_draw_player(ix, iy)

	for q in parts:
		var a := clampf(float(q.life) / float(q.max), 0.0, 1.0)
		var c: Color = q.col
		var sz: float = q.size
		var pp: Vector2 = q.p
		var col := Color(c, c.a * a)
		if q.shape == "tri":
			var r: float = q.rot
			var tri := PackedVector2Array()
			for k in 3:
				tri.append(pp + Vector2(cos(r + k * TAU / 3.0), sin(r + k * TAU / 3.0)) * sz)
			draw_colored_polygon(tri, col)
		else:
			draw_rect(Rect2(pp - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
	for r in rings:
		var a := clampf(float(r.life) / float(r.max), 0.0, 1.0)
		draw_arc(r.p, r.r, 0.0, TAU, 48, Color(r.col, a), float(r.w) * a + 1.0, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not lv.is_empty() and mode != "win" and Save.setting("attempt_text"):
		var ax := _screen(Vector2(320.0, 150.0))
		if ax.x > -400.0:
			_text(("Practice" if practice else "Attempt %d" % attempts), ax, int(30 * sc), Color(1, 1, 1, 0.92))
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 1, 1, flash * 0.55))
	if mode == "win" and win_t > 0.75:
		_draw_win_text()


func _draw_level(pulse: float) -> void:
	var o: Array = lv.objs
	var x0 := cam_x - float(lv.max_w)
	var x1 := cam_x + view_w + 40.0
	var first := Sim.first_idx(o, x0)
	var accent: Color = pal.accent
	var block_fill: Color = pal.ground.lerp(pal.sky_a, 0.3)
	var line_col := Color(accent, 0.12)
	var i := first
	while i < o.size():
		var b: Dictionary = o[i]
		i += 1
		if b.x > x1:
			break
		if b.k != 0:
			continue
		var r := Rect2(b.x, b.y, b.w, b.h)
		draw_rect(r, block_fill)
		draw_rect(Rect2(r.position, Vector2(r.size.x, minf(6.0, r.size.y))), Color(accent, 0.18))
		var lx: float = b.x + T
		while lx < r.end.x:
			draw_line(Vector2(lx, r.position.y), Vector2(lx, r.end.y), line_col, 1.0)
			lx += T
		draw_rect(r.grow(-1.0), Color(accent, 0.75 + pulse * 0.25), false, 2.0)
	var used: Dictionary = s.used
	i = first
	while i < o.size():
		var b: Dictionary = o[i]
		i += 1
		if b.x > x1:
			break
		match int(b.k):
			1:
				var bx: float = b.x
				var by: float = b.y
				var pts: PackedVector2Array
				if b.up:
					pts = PackedVector2Array([Vector2(bx + 3, by + T), Vector2(bx + T * 0.5, by + 3), Vector2(bx + T - 3, by + T)])
				else:
					pts = PackedVector2Array([Vector2(bx + 3, by), Vector2(bx + T * 0.5, by + T - 3), Vector2(bx + T - 3, by)])
				draw_colored_polygon(pts, DARK)
				draw_polyline(Skins.closed(pts), ROSE.lerp(Color.WHITE, pulse * 0.25), 2.5, true)
			2:
				var c := Vector2(b.cx, b.cy)
				var rr: float = b.r
				var pts := PackedVector2Array()
				for k in 24:
					var ang := t * 7.0 + k * PI / 12.0
					pts.append(c + Vector2(cos(ang), sin(ang)) * (rr if k % 2 == 0 else rr * 0.76))
				draw_colored_polygon(pts, DARK)
				draw_polyline(Skins.closed(pts), ROSE, 2.5, true)
				draw_circle(c, rr * 0.34, ROSE)
				draw_circle(c, rr * 0.16, DARK)
			3:
				var c := Vector2(b.cx, b.cy)
				var on := not used.has(b.id)
				var col := Color("ffe14d") if on else Color(1, 1, 1, 0.25)
				draw_arc(c, 14.0 + pulse * 3.0, 0.0, TAU, 24, Color(col, 0.5), 3.0, true)
				draw_circle(c, 11.0, DARK)
				draw_circle(c, 8.5, col)
				draw_circle(c + Vector2(-3, -3), 2.5, Color(1, 1, 1, 0.7))
			4:
				# A big launch pad: a glowing dome on the lane with a bouncing arrow showing where it throws you.
				var on := not used.has(b.id)
				var col := Color("ff7af0") if on else Color(1, 1, 1, 0.3)
				var dir := -1.0 if b.up else 1.0
				var lane: float = 360.0 if b.up else 40.0
				var cx: float = b.x + 14.0
				var dome := PackedVector2Array()
				for k in 17:
					var a := PI * k / 16.0
					dome.append(Vector2(cx - cos(a) * 30.0, lane + dir * sin(a) * 24.0))
				if on:
					draw_colored_polygon(dome, Color(col, 0.35 + pulse * 0.25))
					draw_polyline(dome, Color(col, 0.8), 2.0, true)
				draw_rect(Rect2(cx - 26.0, lane - (16.0 if b.up else 0.0), 52.0, 16.0), DARK)
				draw_rect(Rect2(cx - 23.0, lane - (13.0 if b.up else -3.0), 46.0, 10.0), col)
				draw_rect(Rect2(cx - 23.0, lane - (13.0 if b.up else -3.0), 46.0, 3.0), Color(1, 1, 1, 0.5))
				var hop := absf(sin(t * 5.0)) * 6.0
				for k in 2:
					var ay := lane + dir * (34.0 + k * 13.0 + hop)
					draw_polyline(PackedVector2Array([Vector2(cx - 11, ay - dir * 7), Vector2(cx, ay + dir * 3), Vector2(cx + 11, ay - dir * 7)]),
						Color(col, 0.9 - k * 0.35), 4.0, true)
			5, 6, 7:
				_draw_portal(b)


func _draw_portal(b: Dictionary) -> void:
	var col: Color
	var label := ""
	match int(b.k):
		5:
			col = Color("ffc94d") if int(b.dir) > 0 else Color("5ce1ff")
		6:
			col = Color("7ee04a")
			var m: float = b.mul
			label = ">" if m < 0.95 else (">>" if m < 1.1 else (">>>" if m < 1.25 else ">>>>"))
		7:
			col = Color("ff7af0") if b.mini else Color("b07aff")
	var cx: float = b.x + 8.0
	var pts := PackedVector2Array()
	for k in 33:
		var a := k * TAU / 32.0
		pts.append(Vector2(cx + cos(a) * 16.0, 200.0 + sin(a) * 120.0))
	draw_polyline(pts, Color(col, 0.35), 12.0, true)
	draw_polyline(pts, col, 4.0, true)
	var mid := Vector2(cx, 200)
	match int(b.k):
		5:
			var d := float(b.dir)
			draw_colored_polygon(PackedVector2Array([mid + Vector2(-9, -8 * d), mid + Vector2(9, -8 * d), mid + Vector2(0, 10 * d)]), col)
		6:
			draw_string_outline(FONT, mid + Vector2(-20, 8), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 22, 5, DARK)
			draw_string(FONT, mid + Vector2(-20, 8), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 22, col)
		7:
			var sz := 8.0 if b.mini else 16.0
			draw_rect(Rect2(mid - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)


func _draw_bands(pulse: float, y_top: float, y_bot: float) -> void:
	var bl := cam_x - 40.0
	var bw := view_w + 80.0
	var ground: Color = pal.ground
	var accent: Color = pal.accent
	draw_rect(Rect2(bl, y_top, bw, 40.0 - y_top), ground)
	draw_rect(Rect2(bl, 360.0, bw, y_bot - 360.0), ground)
	var tile := Color(accent, 0.08)
	var x := floorf(bl / T) * T
	while x < bl + bw:
		draw_rect(Rect2(x + 4, 366, T - 8, T - 12), tile)
		draw_rect(Rect2(x + 4, 6, T - 8, T - 12), tile)
		x += T
	draw_line(Vector2(bl, 360), Vector2(bl + bw, 360), Color(accent, 0.85 + pulse * 0.15), 3.0)
	draw_line(Vector2(bl, 40), Vector2(bl + bw, 40), Color(accent, 0.85 + pulse * 0.15), 3.0)
	# Coins and shards sit in front of the bands so ceiling-hugging ones stay visible.
	if not lv.is_empty():
		for i in lv.shards.size():
			if shards_got.has(i):
				continue
			var c: Vector2 = lv.shards[i]
			if c.x < cam_x - 20 or c.x > cam_x + view_w + 20:
				continue
			Skins.symbol(self, "shard", c + Vector2(0, sin(t * 3.0 + i) * 2.0), 7.0)
		for i in lv.coins.size():
			var c: Vector2 = lv.coins[i]
			if c.x < cam_x - 30 or c.x > cam_x + view_w + 30:
				continue
			var got_before: bool = Save.coins_of(p.key)[i]
			var spin := absf(cos(t * 3.0 + i))
			draw_set_transform(Vector2((c.x - cam_x + _shx) * sc, (c.y + _shy) * sc + off_y), 0.0, Vector2(sc * maxf(0.25, spin), sc))
			if coins_got[i]:
				pass
			elif got_before or practice:
				draw_circle(Vector2.ZERO, 13.0, Color(1, 1, 1, 0.25))
				draw_circle(Vector2.ZERO, 9.0, Color(0.6, 0.6, 0.7, 0.35))
			else:
				Skins.symbol(self, "coin", Vector2.ZERO, 13.0)
			_tf(cam_x)


func _draw_trail(c1: Color, c2: Color, k: float) -> void:
	var style: int = Save.skin("trail")
	var n := trail.size()
	if n < 2 or style == 0:
		return
	for i in n:
		var tr: Vector3 = trail[i]
		var f := float(i + 1) / n
		var half: float = tr.z * 0.5
		var c := Vector2(tr.x + half, tr.y + half)
		match style:
			1:
				var sz := tr.z * (0.35 + 0.5 * f) * k
				draw_rect(Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(c1, f * 0.32))
			2:
				if i > 0:
					var q: Vector3 = trail[i - 1]
					draw_line(Vector2(q.x + q.z * 0.5, q.y + q.z * 0.5), c, Color(c1, f * 0.6), tr.z * 0.5 * f * k)
			3:
				var tw := Skins.star(c + Vector2(sin(i * 7.0) * 6, cos(i * 5.0) * 6), 5.0 * f, 2.0 * f, 4)
				draw_colored_polygon(tw, Color(c2, f))
			4:
				if i > 0:
					var q: Vector3 = trail[i - 1]
					draw_line(Vector2(q.x + q.z * 0.5, q.y + q.z * 0.5), c, Color.from_hsv(fposmod(t * 0.5 + i * 0.06, 1.0), 0.7, 1.0, f * 0.8), tr.z * 0.45 * k)
			5:
				draw_arc(c + Vector2(0, sin(t * 4.0 + i) * 4.0), 3.0 + 6.0 * (1.0 - f), 0.0, TAU, 12, Color(c2, f * 0.7), 1.5, true)
			6:
				for j in 2:
					draw_rect(Rect2(c + Vector2(randf_range(-8, 8), randf_range(-8, 8)), Vector2(3, 3)), Color([c1, c2][j], f * 0.8))
			7:
				var fc := Color("ffd34d").lerp(Color("ff4a2e"), 1.0 - f)
				draw_circle(c + Vector2(0, -(1.0 - f) * 10.0 * signf(s.g)), 3.0 + 7.0 * f * k, Color(fc, f * 0.6))
			8:
				draw_circle(c, 2.0 + 3.0 * f, Color(Color("bdeeff"), f * 0.7))
				draw_circle(c + Vector2(randf_range(-10, 0), randf_range(-6, 6)), 1.5, Color(1, 1, 1, f))


func _draw_player(ix: float, iy: float) -> void:
	if mode == "dead" or (mode == "win" and win_fired) or (mode == "menu" and not show_cube):
		return
	var c1: Color = Save.c1()
	var c2: Color = Save.c2()
	var g: float = s.g
	var ps: float = s.ps
	var px := ix
	var py := iy
	var spin := rot
	var k := 1.0
	if mode == "menu":
		px = cam_x + view_w * 0.28
		py = menu_y
		g = menu_g
		ps = 30.0
	elif mode == "win":
		var f := clampf(win_t / 0.7, 0.0, 1.0)
		var q := win_from.lerp(Vector2(float(lv.end) + 5.0, 185.0), ease(f, 2.2))
		px = q.x
		py = q.y
		spin = rot + win_t * win_t * 30.0
		k = 1.0 - f * 0.75
	_draw_trail(c1, c2, k)
	var center := Vector2(px + ps * 0.5, py + ps * 0.5)
	if Save.data.skin.get("glow", false) and Save.has_extra("glow"):
		draw_circle(center, 30.0 * k * ps / 30.0, Color(c1, 0.12))
		draw_circle(center, 22.0 * k * ps / 30.0, Color(c1, 0.16))
	var sq := squash * 0.22
	var scl := ps / 30.0
	Skins.draw_icon(self, _screen(center), spin, Vector2(sc * k * scl * (1.0 + sq), sc * k * scl * (1.0 - sq)), Save.icon(), c1, c2)
	_tf(cam_x)
	if mode == "play" or mode == "menu" or mode == "paused":
		var ax := center.x
		var ay := (py - 12.0) if g > 0.0 else (py + ps + 12.0)
		draw_colored_polygon(PackedVector2Array([Vector2(ax - 6, ay - 4 * g), Vector2(ax + 6, ay - 4 * g), Vector2(ax, ay + 4 * g)]), Color(c1, 0.6))


## The big letter-by-letter "LEVEL COMPLETE!" that slams in, then rises to make room for the results.
func _draw_win_text() -> void:
	var text := "PRACTICE COMPLETE!" if practice else WIN_TEXT
	var fs := int(84.0 * vp.y / 720.0)
	var widths: Array = []
	var total := 0.0
	for ch in text:
		var w := FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w
	var settle := clampf((win_t - 2.2) / 0.5, 0.0, 1.0)
	var base_y := lerpf(vp.y * 0.5, vp.y * 0.15, ease(settle, -2.0))
	var x := vp.x * 0.5 - total * 0.5
	var n := text.length()
	for i in n:
		var w: float = widths[i]
		var lt := win_t - 0.75 - i * 0.045
		if lt > 0.0:
			var kk := clampf(lt / 0.3, 0.0, 1.0)
			var scl := lerpf(3.2, 1.0, ease(kk, 0.35))
			var bob := sin(win_t * 4.0 + i * 0.6) * 4.0 * (1.0 - settle * 0.5)
			var col := Color("ffe14d").lerp(Color("ff8a3d"), float(i) / (n - 1))
			draw_set_transform(Vector2(x + w * 0.5, base_y + bob), 0.0, Vector2(scl, scl))
			var q := Vector2(-w * 0.5, fs * 0.35)
			draw_string_outline(FONT, q, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.26), Color(DARK, kk))
			draw_string(FONT, q, text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, kk))
		x += w
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
