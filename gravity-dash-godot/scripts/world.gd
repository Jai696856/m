extends Node2D
## Runs and draws a level, and doubles as the animated backdrop behind the menus.
## World units: the playfield is 400 high (ceiling at 40, floor at 360); it is scaled to fit the window.

signal died(pct: int, new_best: bool)
signal won(result: Dictionary)
signal win_panel_ready

const Sim = preload("res://scripts/sim.gd")
const Skins = preload("res://scripts/skins.gd")
const FONT = preload("res://fonts/Fredoka-Bold.ttf")
const H := 400.0
const PS := 30.0
const T := 40.0
const DARK := Color(0.04, 0.024, 0.11)
const ROSE := Color(1.0, 0.36, 0.54)
const ROSE_GLOW := Color(1.0, 0.18, 0.42)
const WIN_TEXT := "LEVEL COMPLETE!"

var mode := "menu"  # menu, play, paused, dead, win
var lv: Dictionary = {}
var s
var prev
var pending := false
var autopilot: Dictionary = {}
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
var sky_a := Color("1d1252")
var sky_b := Color("43207a")
var accent := Color("ffc94d")
var glow := Color("ff9e3d")
var menu_g := 1.0
var menu_y := 330.0
var menu_vy := 0.0
var menu_flip := 1.4
var menu_frame := 0
var shapes: Array = []
var _shx := 0.0
var _shy := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900
	for i in 14:
		shapes.append({"x": rng.randf() * 2400.0, "y": 60.0 + rng.randf() * 280.0, "s": 30.0 + rng.randf() * 90.0,
			"sp": rng.randf_range(-0.3, 0.3), "d": 0.12 + rng.randf() * 0.25})
	s = Sim.State.new()
	prev = s.copy()


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


func start(level: Dictionary) -> void:
	lv = level
	var d: Dictionary = lv.def
	sky_a = Color(d.sky[0])
	sky_b = Color(d.sky[1])
	accent = Color(d.accent)
	glow = Color(d.glow)
	attempts = 1
	level_time = 0.0
	reset_run()


func reset_run() -> void:
	s = Sim.State.new()
	prev = s.copy()
	rot = 0.0
	rot_target = 0.0
	squash = 0.0
	flash = 0.0
	flips = 0
	pending = false
	trail.clear()
	parts.clear()
	rings.clear()
	mode = "play"
	Save.add_stat("attempts", 1)
	Save.add_level_attempt(int(lv.i))
	Audio.play_level(int(lv.i))


func set_paused(p: bool) -> void:
	if p and mode == "play":
		mode = "paused"
		Audio.pause_music(true)
	elif not p and mode == "paused":
		mode = "play"
		Audio.pause_music(false)


func pct() -> int:
	if lv.is_empty():
		return 0
	return clampi(int(float(s.x) / float(lv.end) * 100.0), 0, 100)


func _unhandled_input(e: InputEvent) -> void:
	if mode != "play":
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		pending = true
		get_viewport().set_input_as_handled()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_SPACE, KEY_UP, KEY_W, KEY_DOWN, KEY_S]:
		pending = true
		get_viewport().set_input_as_handled()


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
	Save.add_stat("distance", float(lv.speed) * Sim.DT / T)
	if s.flipped:
		flips += 1
		Save.add_stat("flips", 1)
		rot_target += PI
		Audio.sfx("flip_up" if s.g < 0.0 else "flip_down")
		_puff(-s.g)
	if not was_ground and s.ground and not s.dead:
		squash = 1.0
		_puff(s.g)
	if s.f % 3 == 0:
		trail.append(Vector3(s.x, s.y, s.g))
		if trail.size() > 14:
			trail.pop_front()
	if s.dead:
		_die()
	elif s.won:
		_win()


func _die() -> void:
	mode = "dead"
	dead_t = 1.0
	shake = 14.0
	Audio.stop_music()
	Audio.sfx("die")
	var p := pct()
	var nb: bool = Save.record_progress(int(lv.i), p)
	Save.add_stat("deaths", 1)
	Save.save_data()
	var center := Vector2(s.x + PS * 0.5, s.y + PS * 0.5)
	_burst(center, 42, [Save.c1(), Save.c2(), Color.WHITE], 460.0, 0.0)
	rings.append({"p": center, "r": 6.0, "v": 380.0, "w": 6.0, "life": 0.45, "max": 0.45, "col": Save.c1()})
	died.emit(p, nb)


func _win() -> void:
	mode = "win"
	win_t = 0.0
	win_fired = false
	panel_sent = false
	firework_t = 0.0
	win_from = Vector2(s.x, s.y)
	Audio.stop_music()
	var res: Dictionary = Save.record_complete(int(lv.i), flips, level_time)
	res["attempts"] = attempts
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
	rot = lerpf(rot, rot_target, minf(1.0, delta * 14.0))
	squash = maxf(0.0, squash - delta * 6.0)
	shake = maxf(0.0, shake - delta * 40.0)
	flash = maxf(0.0, flash - delta * 1.6)
	var drag := pow(0.25, delta)
	for p in parts:
		var v: Vector2 = p.v
		v.y += float(p.g) * delta
		v *= drag
		p.v = v
		p.p = p.p + v * delta
		p.life = float(p.life) - delta
	parts = parts.filter(func(p): return p.life > 0.0)
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
		trail.append(Vector3(cam_x + view_w * 0.28, menu_y, menu_g))
		if trail.size() > 14:
			trail.pop_front()
	var hue := fposmod(t * 0.018, 1.0)
	sky_a = Color.from_hsv(hue, 0.75, 0.2)
	sky_b = Color.from_hsv(fposmod(hue + 0.06, 1.0), 0.7, 0.42)
	accent = Color.from_hsv(fposmod(hue + 0.5, 1.0), 0.55, 1.0)
	glow = Color.from_hsv(fposmod(hue + 0.5, 1.0), 0.85, 1.0)


func _update_win(delta: float) -> void:
	win_t += delta
	if win_t >= 0.7 and not win_fired:
		win_fired = true
		flash = 1.0
		shake = 12.0
		Audio.sfx("win")
		var gate := Vector2(float(lv.end) + 20.0, 200.0)
		_burst(gate, 90, [accent, glow, Color.WHITE, Save.c1(), Save.c2()], 560.0, 0.0)
		for k in 3:
			rings.append({"p": gate, "r": 10.0 + k * 8.0, "v": 560.0 - k * 130.0, "w": 10.0 - k * 2.5,
				"life": 1.0, "max": 1.0, "col": Color.WHITE if k == 0 else accent})
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


func _burst(at: Vector2, n: int, cols: Array, speed: float, grav: float) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(0.25, 1.0) * speed
		var life := randf_range(0.5, 1.1)
		parts.append({"p": at, "v": Vector2(cos(a), sin(a)) * sp, "life": life, "max": life,
			"size": randf_range(3.0, 9.0), "col": cols[i % cols.size()], "g": grav})


func _puff(dir: float) -> void:
	var y: float = (s.y + PS) if dir > 0.0 else s.y
	for i in 8:
		parts.append({"p": Vector2(s.x + randf() * PS, y), "v": Vector2(randf_range(-180.0, -60.0), -dir * randf_range(30.0, 120.0)),
			"life": 0.35, "max": 0.35, "size": randf_range(3.0, 6.0), "col": Color(1, 1, 1, 0.8), "g": 0.0})


# ---------- Drawing ----------

func _tf(cam: float) -> void:
	draw_set_transform(Vector2(-cam * sc + _shx * sc, off_y + _shy * sc), 0.0, Vector2(sc, sc))


func _screen(p: Vector2) -> Vector2:
	return Vector2((p.x - cam_x + _shx) * sc, (p.y + _shy) * sc + off_y)


func _text(txt: String, at: Vector2, size: int, col: Color, center := false) -> void:
	var w := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at - Vector2(w * 0.5 if center else 0.0, 0.0)
	draw_string_outline(FONT, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.28), Color(DARK, col.a))
	draw_string(FONT, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw() -> void:
	var pulse: float = Audio.beat_pulse()
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

	# Sky, drifting outlines and a parallax grid
	_tf(0.0)
	draw_rect(Rect2(-40, y_top, view_w + 80, y_bot - y_top), sky_a)
	draw_polygon(PackedVector2Array([Vector2(-40, 40), Vector2(view_w + 40, 40), Vector2(view_w + 40, 200), Vector2(-40, 200)]),
		PackedColorArray([sky_a, sky_a, sky_b, sky_b]))
	draw_polygon(PackedVector2Array([Vector2(-40, 200), Vector2(view_w + 40, 200), Vector2(view_w + 40, 360), Vector2(-40, 360)]),
		PackedColorArray([sky_b, sky_b, sky_a, sky_a]))
	var out_col := Color(accent, 0.08 + pulse * 0.06)
	for sh in shapes:
		var px := fposmod(float(sh.x) - cam_x * float(sh.d), 2400.0) - 200.0
		if px > view_w + 200.0:
			continue
		var ang: float = t * float(sh.sp) + float(sh.x)
		var hs: float = float(sh.s) * 0.5
		var pts := PackedVector2Array()
		for k in 5:
			var aa := ang + PI * 0.25 + k * PI * 0.5
			pts.append(Vector2(px, sh.y) + Vector2(cos(aa), sin(aa)) * hs * 1.4142)
		draw_polyline(pts, out_col, 2.0, true)
	var gx := -fposmod(cam_x * 0.5, 80.0)
	var grid_col := Color(1, 1, 1, 0.045)
	while gx < view_w:
		draw_line(Vector2(gx, 40), Vector2(gx, 360), grid_col, 1.0)
		gx += 80.0
	for gy in [120.0, 200.0, 280.0]:
		draw_line(Vector2(0, gy), Vector2(view_w, gy), grid_col, 1.0)

	_tf(cam_x)
	if not lv.is_empty():
		_draw_level(pulse)
	_draw_bands(pulse, y_top, y_bot)

	if not lv.is_empty():
		# Finish gate
		var gate_x: float = lv.end
		if gate_x < cam_x + view_w + 100.0:
			var bright := 1.0 if win_fired else 0.0
			for k in 6:
				var c := Color("ffc94d") if k % 2 == 0 else Color("5ce1ff")
				c = c.lerp(Color.WHITE, bright * flash)
				draw_rect(Rect2(gate_x + k * 14.0, 40, 8, 320), Color(c, 0.55 - k * 0.07))
			draw_rect(Rect2(gate_x - 6.0, 40, 6, 320), Color(1, 1, 1, 0.25 + pulse * 0.3))

	_draw_player(ix, iy)

	# Particles and shock rings
	for p in parts:
		var a := clampf(float(p.life) / float(p.max), 0.0, 1.0)
		var c: Color = p.col
		var sz: float = p.size
		var pp: Vector2 = p.p
		draw_rect(Rect2(pp - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(c, c.a * a))
	for r in rings:
		var a := clampf(float(r.life) / float(r.max), 0.0, 1.0)
		draw_arc(r.p, r.r, 0.0, TAU, 48, Color(r.col, a), float(r.w) * a + 1.0, true)

	# Screen-space text and effects
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not lv.is_empty() and mode != "win":
		var ax := _screen(Vector2(320.0, 150.0))
		if ax.x > -400.0:
			_text("Attempt %d" % attempts, ax, int(30 * sc), Color(1, 1, 1, 0.92))
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(1, 1, 1, flash * 0.55))
	if mode == "win" and win_t > 0.75:
		_draw_win_text()


func _draw_level(pulse: float) -> void:
	var o: Array = lv.objs
	var x0 := cam_x - float(lv.max_w)
	var x1 := cam_x + view_w + 40.0
	var first := Sim.first_idx(o, x0)
	var line_col := Color(accent, 0.16)
	var edge_glow := Color(glow, 0.22 + pulse * 0.2)
	var i := first
	while i < o.size():
		var b: Dictionary = o[i]
		i += 1
		if b.x > x1:
			break
		if b.k != 0:
			continue
		var r := Rect2(b.x, b.y, b.w, b.h)
		draw_rect(r, Color(DARK, 0.92))
		var lx: float = b.x + T
		while lx < r.end.x:
			draw_line(Vector2(lx, r.position.y), Vector2(lx, r.end.y), line_col, 1.0)
			lx += T
		var ly: float = b.y + T
		while ly < r.end.y:
			draw_line(Vector2(r.position.x, ly), Vector2(r.end.x, ly), line_col, 1.0)
			ly += T
		draw_rect(r.grow(-1.0), edge_glow, false, 7.0)
		draw_rect(r.grow(-1.0), accent, false, 2.5)
	var spike_glow := Color(ROSE_GLOW, 0.3 + pulse * 0.25)
	i = first
	while i < o.size():
		var b: Dictionary = o[i]
		i += 1
		if b.x > x1:
			break
		if b.k == 1:
			var bx: float = b.x
			var by: float = b.y
			var pts: PackedVector2Array
			if b.up:
				pts = PackedVector2Array([Vector2(bx + 2, by + T), Vector2(bx + T * 0.5, by + 2), Vector2(bx + T - 2, by + T)])
			else:
				pts = PackedVector2Array([Vector2(bx + 2, by), Vector2(bx + T * 0.5, by + T - 2), Vector2(bx + T - 2, by)])
			draw_colored_polygon(pts, DARK)
			var cl := Skins.closed(pts)
			draw_polyline(cl, spike_glow, 6.0, true)
			draw_polyline(cl, ROSE, 2.5, true)
		elif b.k == 2:
			var c := Vector2(b.cx, b.cy)
			var rr: float = b.r
			var pts := PackedVector2Array()
			for k in 24:
				var ang := t * 7.0 + k * PI / 12.0
				pts.append(c + Vector2(cos(ang), sin(ang)) * (rr if k % 2 == 0 else rr * 0.76))
			draw_colored_polygon(pts, DARK)
			var cl := Skins.closed(pts)
			draw_polyline(cl, spike_glow, 6.0, true)
			draw_polyline(cl, ROSE, 2.5, true)
			draw_circle(c, rr * 0.34, ROSE)
			draw_circle(c, rr * 0.16, DARK)


func _draw_bands(pulse: float, y_top: float, y_bot: float) -> void:
	var bl := cam_x - 40.0
	var bw := view_w + 80.0
	draw_rect(Rect2(bl, y_top, bw, 40.0 - y_top), DARK)
	draw_rect(Rect2(bl, 360.0, bw, y_bot - 360.0), DARK)
	var tile := Color(accent, 0.14)
	var x := floorf(bl / T) * T
	while x < bl + bw:
		draw_line(Vector2(x, 360), Vector2(x, 400), tile, 1.0)
		draw_line(Vector2(x, 0), Vector2(x, 40), tile, 1.0)
		x += T
	draw_line(Vector2(bl, 400), Vector2(bl + bw, 400), tile, 1.0)
	draw_line(Vector2(bl, 0), Vector2(bl + bw, 0), tile, 1.0)
	var g := Color(glow, 0.28 + pulse * 0.3)
	draw_line(Vector2(bl, 360), Vector2(bl + bw, 360), g, 9.0)
	draw_line(Vector2(bl, 40), Vector2(bl + bw, 40), g, 9.0)
	draw_line(Vector2(bl, 360), Vector2(bl + bw, 360), accent, 3.0)
	draw_line(Vector2(bl, 40), Vector2(bl + bw, 40), accent, 3.0)


func _draw_player(ix: float, iy: float) -> void:
	if mode == "dead" or (mode == "win" and win_fired):
		return
	var c1: Color = Save.c1()
	var c2: Color = Save.c2()
	var g: float = s.g
	var px := ix
	var py := iy
	var spin := rot
	var k := 1.0
	if mode == "menu":
		px = cam_x + view_w * 0.28
		py = menu_y
		g = menu_g
	elif mode == "win":
		var f := clampf(win_t / 0.7, 0.0, 1.0)
		var p := win_from.lerp(Vector2(float(lv.end) + 5.0, 185.0), ease(f, 2.2))
		px = p.x
		py = p.y
		spin = rot + win_t * win_t * 30.0
		k = 1.0 - f * 0.75
	for i in trail.size():
		var tr: Vector3 = trail[i]
		var f := float(i + 1) / trail.size()
		var sz := PS * (0.35 + 0.5 * f) * k
		draw_rect(Rect2(tr.x + (PS - sz) * 0.5, tr.y + (PS - sz) * 0.5, sz, sz), Color(c1, f * 0.32))
	var center := Vector2(px + PS * 0.5, py + PS * 0.5)
	draw_circle(center, 26.0 * k, Color(c1, 0.14))
	var sq := squash * 0.22
	Skins.draw_icon(self, _screen(center), spin, Vector2(sc * k * (1.0 + sq), sc * k * (1.0 - sq)), Save.icon(), c1, c2)
	_tf(cam_x)
	if mode == "play" or mode == "menu" or mode == "paused":
		var ax := center.x
		var ay := (py - 12.0) if g > 0.0 else (py + PS + 12.0)
		draw_colored_polygon(PackedVector2Array([Vector2(ax - 6, ay - 4 * g), Vector2(ax + 6, ay - 4 * g), Vector2(ax, ay + 4 * g)]), Color(c1, 0.6))


## The big letter-by-letter "LEVEL COMPLETE!" that slams in, then rises to make room for the results.
func _draw_win_text() -> void:
	var fs := int(84.0 * vp.y / 720.0)
	var widths: Array = []
	var total := 0.0
	for ch in WIN_TEXT:
		var w := FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		widths.append(w)
		total += w
	var settle := clampf((win_t - 2.2) / 0.5, 0.0, 1.0)
	var base_y := lerpf(vp.y * 0.5, vp.y * 0.17, ease(settle, -2.0))
	var x := vp.x * 0.5 - total * 0.5
	var n := WIN_TEXT.length()
	for i in n:
		var w: float = widths[i]
		var lt := win_t - 0.75 - i * 0.045
		if lt > 0.0:
			var k := clampf(lt / 0.3, 0.0, 1.0)
			var scl := lerpf(3.2, 1.0, ease(k, 0.35))
			var bob := sin(win_t * 4.0 + i * 0.6) * 4.0 * (1.0 - settle * 0.5)
			var col := Color("ffe14d").lerp(Color("ff8a3d"), float(i) / (n - 1))
			draw_set_transform(Vector2(x + w * 0.5, base_y + bob), 0.0, Vector2(scl, scl))
			var p := Vector2(-w * 0.5, fs * 0.35)
			draw_string_outline(FONT, p, WIN_TEXT[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.26), Color(DARK, k))
			draw_string(FONT, p, WIN_TEXT[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, k))
		x += w
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
