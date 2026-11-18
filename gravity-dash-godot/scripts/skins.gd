extends RefCounted
## Drawing: cube icons, difficulty faces and the symbols used on buttons and tiles.
## Icons are drawn with code in a 30 x 30 box centred on the origin. Item data lives in catalog.gd.

const DARK := Color(0.05, 0.03, 0.12)

const TIER_NAMES := ["Easy", "Normal", "Hard", "Harder", "Insane", "Demon"]
const TIER_COLORS := ["49b6ff", "5fd35a", "ffb62e", "ff5a3c", "ff4fd8", "a64dff"]

static func poly(flat: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		p.append(Vector2(flat[i], flat[i + 1]))
	return p


static func closed(p: PackedVector2Array) -> PackedVector2Array:
	var c := p.duplicate()
	c.append(p[0])
	return c


static func star(c: Vector2, ro: float, ri: float, n := 5) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in n * 2:
		var a := -PI / 2.0 + k * PI / n
		var r := ro if k % 2 == 0 else ri
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p


## Draws icon `id` centred at `pos`. Leaves the canvas transform reset to identity.
static func draw_icon(ci: CanvasItem, pos: Vector2, rot: float, scl: Vector2, id: int, c1: Color, c2: Color) -> void:
	ci.draw_set_transform(pos, rot, scl)
	ci.draw_rect(Rect2(-17, -17, 34, 34), DARK)
	ci.draw_rect(Rect2(-15, -15, 30, 30), c1)
	match id:
		0:
			ci.draw_rect(Rect2(-10, -10, 20, 20), DARK)
			ci.draw_rect(Rect2(-8, -8, 16, 16), c2)
			ci.draw_rect(Rect2(-4, -4, 8, 8), DARK)
		1:
			ci.draw_rect(Rect2(-10, -9, 7, 8), DARK)
			ci.draw_rect(Rect2(3, -9, 7, 8), DARK)
			ci.draw_rect(Rect2(-8, -8, 3, 3), c2)
			ci.draw_rect(Rect2(5, -8, 3, 3), c2)
			ci.draw_arc(Vector2(0, 0), 9.0, 0.4, PI - 0.4, 12, DARK, 3.5)
		2:
			ci.draw_colored_polygon(poly([0, -13, 13, 0, 0, 13, -13, 0]), DARK)
			ci.draw_colored_polygon(poly([0, -9, 9, 0, 0, 9, -9, 0]), c2)
			ci.draw_rect(Rect2(-2.5, -2.5, 5, 5), DARK)
		3:
			ci.draw_rect(Rect2(-15, -7, 30, 11), DARK)
			ci.draw_rect(Rect2(-12, -5, 24, 7), c2)
			ci.draw_rect(Rect2(-15, 8, 30, 3), DARK)
		4:
			ci.draw_circle(Vector2.ZERO, 11.5, DARK)
			ci.draw_circle(Vector2.ZERO, 8.5, c2)
			ci.draw_circle(Vector2.ZERO, 4.0, DARK)
		5:
			ci.draw_rect(Rect2(-4.5, -12.5, 9, 25), DARK)
			ci.draw_rect(Rect2(-12.5, -4.5, 25, 9), DARK)
			ci.draw_rect(Rect2(-2, -10, 4, 20), c2)
			ci.draw_rect(Rect2(-10, -2, 20, 4), c2)
		6:
			ci.draw_rect(Rect2(-15, -15, 15, 15), c2)
			ci.draw_rect(Rect2(0, 0, 15, 15), c2)
			ci.draw_rect(Rect2(-6, -6, 12, 12), DARK)
			ci.draw_rect(Rect2(-3, -3, 6, 6), c1)
		7:
			ci.draw_rect(Rect2(-12, -12, 24, 24), DARK)
			ci.draw_rect(Rect2(-9, -9, 18, 18), c2)
			ci.draw_rect(Rect2(-6, -6, 12, 12), DARK)
			ci.draw_rect(Rect2(-3, -3, 6, 6), c2)
		8:
			ci.draw_colored_polygon(poly([-12, -12, -2, -7, -2, -4, -12, -8]), DARK)
			ci.draw_colored_polygon(poly([12, -12, 2, -7, 2, -4, 12, -8]), DARK)
			ci.draw_rect(Rect2(-10, -4, 7, 7), DARK)
			ci.draw_rect(Rect2(3, -4, 7, 7), DARK)
			ci.draw_rect(Rect2(-8, -2, 3, 3), c2)
			ci.draw_rect(Rect2(5, -2, 3, 3), c2)
			ci.draw_rect(Rect2(-7, 7, 14, 3.5), DARK)
		9:
			var b := poly([3, -13, -8, 2, -1, 2, -4, 13, 8, -3, 1, -3])
			ci.draw_colored_polygon(b, c2)
			ci.draw_polyline(closed(b), DARK, 2.0)
		10:
			for sx in [-6.0, 6.0]:
				ci.draw_circle(Vector2(sx, -3), 6.5, DARK)
				ci.draw_circle(Vector2(sx, -3), 4.8, c2)
				ci.draw_circle(Vector2(sx + 1.2, -2), 2.2, DARK)
			ci.draw_colored_polygon(poly([-15, 15, -15, 9, -10, 13, -5, 9, 0, 13, 5, 9, 10, 13, 15, 9, 15, 15]), DARK)
		11:
			ci.draw_circle(Vector2(-5, -3), 7.5, DARK)
			ci.draw_circle(Vector2(5, -3), 7.5, DARK)
			ci.draw_colored_polygon(poly([-12.5, -1, 12.5, -1, 0, 13]), DARK)
			ci.draw_circle(Vector2(-5, -3), 5.5, c2)
			ci.draw_circle(Vector2(5, -3), 5.5, c2)
			ci.draw_colored_polygon(poly([-10, -1, 10, -1, 0, 10]), c2)
		12:
			var st := star(Vector2(0, 1), 13.0, 5.5)
			ci.draw_colored_polygon(st, c2)
			ci.draw_polyline(closed(st), DARK, 2.0)
		13:
			ci.draw_colored_polygon(poly([15, -15, 15, 15, -15, 15]), c2)
			ci.draw_line(Vector2(-15, 15), Vector2(15, -15), DARK, 3.0)
			ci.draw_rect(Rect2(-10, -10, 7, 7), DARK)
			ci.draw_rect(Rect2(3, 3, 7, 7), DARK)
		14:
			for gx in 3:
				for gy in 3:
					ci.draw_circle(Vector2(-9 + gx * 9, -9 + gy * 9), 3.2, c2 if (gx + gy) % 2 == 0 else DARK)
		15:
			var cr := poly([-12, 9, -12, -7, -6, -1, 0, -12, 6, -1, 12, -7, 12, 9])
			ci.draw_colored_polygon(cr, c2)
			ci.draw_polyline(closed(cr), DARK, 2.0)
			ci.draw_circle(Vector2(0, 4), 2.6, DARK)
			ci.draw_circle(Vector2(-7, 5), 1.8, DARK)
			ci.draw_circle(Vector2(7, 5), 1.8, DARK)
		16:
			ci.draw_rect(Rect2(-11, -9, 22, 13), DARK)
			ci.draw_rect(Rect2(-9, -7, 7, 7), c2)
			ci.draw_rect(Rect2(2, -7, 7, 7), c2)
			ci.draw_rect(Rect2(-6, -5, 3, 3), DARK)
			ci.draw_rect(Rect2(5, -5, 3, 3), DARK)
			for k in 4:
				ci.draw_rect(Rect2(-8 + k * 4.5, 7, 3, 5), DARK)
		17:
			ci.draw_colored_polygon(poly([-15, -15, -6, -15, -15, -6]), DARK)
			ci.draw_colored_polygon(poly([15, -15, 6, -15, 15, -6]), DARK)
			ci.draw_colored_polygon(poly([-10, -3, -4, -6, -4, -1]), DARK)
			ci.draw_colored_polygon(poly([10, -3, 4, -6, 4, -1]), DARK)
			ci.draw_colored_polygon(poly([-3, 3, 3, 3, 0, 6]), c2)
			ci.draw_line(Vector2(0, 6), Vector2(-4, 9), DARK, 1.5)
			ci.draw_line(Vector2(0, 6), Vector2(4, 9), DARK, 1.5)
		18:
			for sx in [-6.5, 6.5]:
				ci.draw_circle(Vector2(sx, -3), 7.0, DARK)
				ci.draw_circle(Vector2(sx, -3), 5.5, c2)
				ci.draw_circle(Vector2(sx, -3), 2.5, DARK)
			ci.draw_colored_polygon(poly([-3, 5, 3, 5, 0, 11]), DARK)
		19:
			ci.draw_rect(Rect2(-11, -12, 22, 17), c2)
			ci.draw_rect(Rect2(-7, 5, 14, 6), c2)
			ci.draw_rect(Rect2(-8, -6, 6, 6), DARK)
			ci.draw_rect(Rect2(2, -6, 6, 6), DARK)
			ci.draw_rect(Rect2(-1.5, 1, 3, 3), DARK)
			for k in 3:
				ci.draw_rect(Rect2(-5 + k * 4, 7, 2, 4), DARK)
		20:
			for row in [-5.0, 5.0]:
				var w := PackedVector2Array()
				for k in 13:
					w.append(Vector2(-14 + k * 2.33, row + sin(k * 0.9) * 4.0))
				ci.draw_polyline(w, DARK, 5.0, true)
				ci.draw_polyline(w, c2, 2.5, true)
		21:
			var hx := poly([0, -12, 11, -5, 11, 6, 0, 13, -11, 6, -11, -5])
			ci.draw_colored_polygon(hx, c2)
			ci.draw_polyline(closed(hx), DARK, 2.0)
			ci.draw_line(Vector2(-11, -5), Vector2(11, -5), DARK, 1.5)
			ci.draw_line(Vector2(-5, -5), Vector2(0, 13), DARK, 1.5)
			ci.draw_line(Vector2(5, -5), Vector2(0, 13), DARK, 1.5)
		22:
			for k in 8:
				var a := k * PI / 4.0
				ci.draw_line(Vector2(cos(a), sin(a)) * 8.0, Vector2(cos(a), sin(a)) * 13.0, DARK, 3.0)
			ci.draw_circle(Vector2.ZERO, 8.0, DARK)
			ci.draw_circle(Vector2.ZERO, 6.5, c2)
		23:
			ci.draw_circle(Vector2(0, 0), 10.5, DARK)
			ci.draw_circle(Vector2(0, 0), 9.0, c2)
			ci.draw_circle(Vector2(5, -4), 8.0, c1)
		24:
			var lf := poly([-11, 11, -9, -2, -2, -10, 11, -12, 9, 1, 1, 9])
			ci.draw_colored_polygon(lf, c2)
			ci.draw_polyline(closed(lf), DARK, 2.0)
			ci.draw_line(Vector2(-11, 11), Vector2(7, -8), DARK, 1.5)
		25:
			ci.draw_circle(Vector2(0, -1), 10.0, DARK)
			ci.draw_circle(Vector2(0, -1), 8.0, Color.WHITE)
			ci.draw_circle(Vector2(1, -1), 5.0, c2)
			ci.draw_circle(Vector2(1, -1), 2.5, DARK)
			ci.draw_rect(Rect2(-6, 11, 12, 2.5), DARK)
		26:
			var sp := PackedVector2Array()
			for k in 40:
				var a := k * 0.42
				sp.append(Vector2(cos(a), sin(a)) * (1.0 + k * 0.3))
			ci.draw_polyline(sp, DARK, 4.0, true)
			ci.draw_polyline(sp, c2, 2.0, true)
		27:
			var lines := [[-12, -8, -2, -8, -2, 0], [12, -10, 4, -10, 4, 6, 12, 6], [-12, 8, -6, 8, -6, 12]]
			for l in lines:
				ci.draw_polyline(poly(l), DARK, 2.5)
			for dot in [Vector2(-2, 0), Vector2(12, 6), Vector2(-6, 12), Vector2(-12, -8)]:
				ci.draw_circle(dot, 2.5, c2)
			ci.draw_rect(Rect2(-4, -4, 8, 8), DARK)
			ci.draw_rect(Rect2(-2, -2, 4, 4), c2)
		28:
			ci.draw_rect(Rect2(-15, -15, 30, 30), DARK)
			ci.draw_circle(Vector2.ZERO, 10.0, c2)
			ci.draw_circle(Vector2.ZERO, 7.0, DARK)
			ci.draw_circle(Vector2(2, -2), 2.5, c1)
		29:
			var tri := poly([0, -12, 12, 10, -12, 10])
			ci.draw_colored_polygon(tri, DARK)
			ci.draw_colored_polygon(poly([0, -8, 8, 7, -8, 7]), c2)
			var cols := [Color("ff5c5c"), Color("ffd34d"), Color("5ce1a0"), Color("5c9dff")]
			for k in 4:
				ci.draw_line(Vector2(4, -2 + k * 3), Vector2(15, -6 + k * 5), cols[k], 2.0)
		30:
			ci.draw_colored_polygon(poly([-14, 10, 2, -6, 8, 0]), Color(c2, 0.6))
			ci.draw_colored_polygon(poly([-12, 13, 0, 0, 5, 4]), Color(c2, 0.35))
			ci.draw_circle(Vector2(5, -3), 7.5, DARK)
			ci.draw_circle(Vector2(5, -3), 5.5, c2)
		31:
			var cr := poly([-12, 3, -12, -9, -6, -3, 0, -13, 6, -3, 12, -9, 12, 3])
			ci.draw_colored_polygon(cr, c2)
			ci.draw_polyline(closed(cr), DARK, 2.0)
			var gem := poly([0, 4, 6, 9, 0, 14, -6, 9])
			ci.draw_colored_polygon(gem, Color("5ce1ff"))
			ci.draw_polyline(closed(gem), DARK, 1.5)
		32:
			var saw := star(Vector2.ZERO, 13.0, 9.0, 8)
			ci.draw_colored_polygon(saw, c2)
			ci.draw_polyline(closed(saw), DARK, 2.0)
			ci.draw_circle(Vector2.ZERO, 3.5, DARK)
		33:
			ci.draw_circle(Vector2.ZERO, 12.0, DARK)
			ci.draw_circle(Vector2.ZERO, 10.0, c2)
			ci.draw_circle(Vector2.ZERO, 6.5, DARK)
			ci.draw_circle(Vector2.ZERO, 4.0, c1)
		34:
			for k in 3:
				var ox := -9.0 + k * 7.0
				ci.draw_polyline(poly([ox, -9, ox + 6, 0, ox, 9]), DARK, 5.0)
				ci.draw_polyline(poly([ox, -9, ox + 6, 0, ox, 9]), c2, 2.5)
		35:
			ci.draw_rect(Rect2(-8, -8, 16, 16), DARK)
			ci.draw_rect(Rect2(-6, -6, 12, 12), c2)
			ci.draw_rect(Rect2(-3, -3, 6, 6), DARK)
		36:
			ci.draw_colored_polygon(poly([-7, -13, -1, -5, -5, -5, -5, 2, -9, 2, -9, -5, -13, -5]), c2)
			ci.draw_colored_polygon(poly([7, 13, 13, 5, 9, 5, 9, -2, 5, -2, 5, 5, 1, 5]), c2)
			ci.draw_polyline(closed(poly([-7, -13, -1, -5, -5, -5, -5, 2, -9, 2, -9, -5, -13, -5])), DARK, 1.5)
			ci.draw_polyline(closed(poly([7, 13, 13, 5, 9, 5, 9, -2, 5, -2, 5, 5, 1, 5])), DARK, 1.5)
		37:
			for sp in [[Vector2(-6, -5), 6.0], [Vector2(6, -2), 5.0], [Vector2(-2, 8), 4.5]]:
				var st := star(sp[0], sp[1], sp[1] * 0.45)
				ci.draw_colored_polygon(st, c2)
				ci.draw_polyline(closed(st), DARK, 1.5)
		38:
			ci.draw_colored_polygon(poly([0, -12, 8, -2, 3, -2, 3, 10, -3, 10, -3, -2, -8, -2]), c2)
			ci.draw_line(Vector2(-12, 12), Vector2(12, -12), DARK, 4.0)
			ci.draw_line(Vector2(-12, 12), Vector2(12, -12), Color("ff4a4a"), 2.0)
		39:
			ci.draw_colored_polygon(poly([-15, 5, 5, -15, 11, -15, -15, 11]), Color(1, 1, 1, 0.45))
			ci.draw_colored_polygon(poly([-3, 15, 15, -3, 15, 3, 3, 15]), Color(1, 1, 1, 0.3))
			ci.draw_rect(Rect2(-6, -6, 12, 12), DARK)
			ci.draw_rect(Rect2(-4, -4, 8, 8), c2)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A round face that shows how hard a level is (bigger tier = angrier face).
static func draw_face(ci: CanvasItem, c: Vector2, r: float, tier: int) -> void:
	var col := Color(TIER_COLORS[tier])
	if tier == 5:
		for sx in [-1.0, 1.0]:
			var horn := PackedVector2Array([c + Vector2(sx * r * 0.45, -r * 0.75), c + Vector2(sx * r * 1.1, -r * 1.3), c + Vector2(sx * r * 0.9, -r * 0.35)])
			ci.draw_colored_polygon(horn, DARK)
			var inner := PackedVector2Array([c + Vector2(sx * r * 0.55, -r * 0.7), c + Vector2(sx * r * 1.0, -r * 1.12), c + Vector2(sx * r * 0.85, -r * 0.45)])
			ci.draw_colored_polygon(inner, Color("ff3d3d"))
	ci.draw_circle(c, r + r * 0.09, DARK)
	ci.draw_circle(c, r, col)
	ci.draw_circle(c + Vector2(-r * 0.32, -r * 0.38), r * 0.26, Color(1, 1, 1, 0.22))
	var lx := c.x - r * 0.34
	var rx := c.x + r * 0.34
	var ey := c.y - r * 0.1
	var e := r * 0.13
	var lw := maxf(2.0, r * 0.09)
	var eye := DARK
	if tier >= 4:
		eye = Color("ffe14d") if tier == 5 else Color.WHITE
		ci.draw_circle(Vector2(lx, ey), e * 1.35, DARK)
		ci.draw_circle(Vector2(rx, ey), e * 1.35, DARK)
	ci.draw_circle(Vector2(lx, ey), e, eye)
	ci.draw_circle(Vector2(rx, ey), e, eye)
	if tier >= 3:
		ci.draw_line(Vector2(lx - r * 0.2, ey - r * 0.32), Vector2(lx + r * 0.18, ey - r * 0.16), DARK, lw)
		ci.draw_line(Vector2(rx + r * 0.2, ey - r * 0.32), Vector2(rx - r * 0.18, ey - r * 0.16), DARK, lw)
	match tier:
		0:
			ci.draw_arc(c + Vector2(0, r * 0.05), r * 0.48, 0.25, PI - 0.25, 16, DARK, lw)
		1:
			ci.draw_arc(c + Vector2(0, r * 0.12), r * 0.38, 0.5, PI - 0.5, 16, DARK, lw)
		2:
			ci.draw_line(c + Vector2(-r * 0.3, r * 0.45), c + Vector2(r * 0.3, r * 0.45), DARK, lw)
		3:
			ci.draw_arc(c + Vector2(0, r * 0.82), r * 0.36, PI + 0.6, TAU - 0.6, 16, DARK, lw)
		4:
			ci.draw_rect(Rect2(c.x - r * 0.38, c.y + r * 0.32, r * 0.76, r * 0.3), DARK)
			for k in 4:
				ci.draw_rect(Rect2(c.x - r * 0.32 + k * r * 0.17, c.y + r * 0.34, r * 0.1, r * 0.12), Color.WHITE)
		5:
			var grin := PackedVector2Array()
			for k in 9:
				var gx := -r * 0.5 + k * r * 0.125
				grin.append(c + Vector2(gx, r * (0.32 if k % 2 == 0 else 0.46)))
			grin.append(c + Vector2(r * 0.4, r * 0.62))
			grin.append(c + Vector2(-r * 0.4, r * 0.62))
			ci.draw_colored_polygon(grin, DARK)


## Symbols for buttons, hub tiles and currencies, drawn white with a dark outline (or in colour for currencies).
## c is the centre and s the half-size.
static func symbol(ci: CanvasItem, n: String, c: Vector2, s: float, col := Color.WHITE) -> void:
	var w := maxf(2.0, s * 0.16)
	match n:
		"play":
			_shape(ci, PackedVector2Array([c + Vector2(-0.55, -0.8) * s, c + Vector2(0.85, 0) * s, c + Vector2(-0.55, 0.8) * s]), col)
		"left", "back":
			_shape(ci, PackedVector2Array([c + Vector2(-0.8, 0) * s, c + Vector2(0.15, -0.75) * s, c + Vector2(0.15, -0.3) * s,
				c + Vector2(0.8, -0.3) * s, c + Vector2(0.8, 0.3) * s, c + Vector2(0.15, 0.3) * s, c + Vector2(0.15, 0.75) * s]), col)
		"right":
			_shape(ci, PackedVector2Array([c + Vector2(0.8, 0) * s, c + Vector2(-0.15, 0.75) * s, c + Vector2(-0.15, 0.3) * s,
				c + Vector2(-0.8, 0.3) * s, c + Vector2(-0.8, -0.3) * s, c + Vector2(-0.15, -0.3) * s, c + Vector2(-0.15, -0.75) * s]), col)
		"pause":
			_bar(ci, Rect2(c + Vector2(-0.6, -0.7) * s, Vector2(0.4, 1.4) * s), col)
			_bar(ci, Rect2(c + Vector2(0.2, -0.7) * s, Vector2(0.4, 1.4) * s), col)
		"list":
			for k in 3:
				_bar(ci, Rect2(c + Vector2(-0.75, -0.65 + k * 0.5) * s, Vector2(1.5, 0.3) * s), col)
		"chart":
			var hs := [0.6, 1.1, 1.6]
			for k in 3:
				var h: float = hs[k]
				_bar(ci, Rect2(c + Vector2(-0.8 + k * 0.6, 0.8 - h) * s, Vector2(0.4, h) * s), col)
		"restart":
			ci.draw_arc(c, s * 0.62, 0.9, TAU - 0.3, 24, DARK, s * 0.42, true)
			ci.draw_arc(c, s * 0.62, 0.9, TAU - 0.3, 24, col, s * 0.24, true)
			var tip := c + Vector2(cos(0.9), sin(0.9)) * s * 0.62
			_shape(ci, PackedVector2Array([tip + Vector2(-0.45, -0.1) * s, tip + Vector2(0.4, -0.35) * s, tip + Vector2(0.15, 0.5) * s]), col)
		"music":
			ci.draw_line(c + Vector2(0.35, 0.5) * s, c + Vector2(0.35, -0.75) * s, DARK, s * 0.36)
			ci.draw_circle(c + Vector2(0.05, 0.5) * s, s * 0.36, DARK)
			ci.draw_line(c + Vector2(0.35, 0.5) * s, c + Vector2(0.35, -0.75) * s, col, s * 0.16)
			ci.draw_circle(c + Vector2(0.05, 0.5) * s, s * 0.24, col)
			_shape(ci, PackedVector2Array([c + Vector2(0.35, -0.8) * s, c + Vector2(0.85, -0.45) * s, c + Vector2(0.35, -0.3) * s]), col)
		"sound":
			_shape(ci, PackedVector2Array([c + Vector2(-0.8, -0.3) * s, c + Vector2(-0.35, -0.3) * s, c + Vector2(0.15, -0.75) * s,
				c + Vector2(0.15, 0.75) * s, c + Vector2(-0.35, 0.3) * s, c + Vector2(-0.8, 0.3) * s]), col)
			ci.draw_arc(c + Vector2(0.15, 0) * s, s * 0.5, -0.8, 0.8, 10, col, s * 0.16, true)
		"grid":
			for gx in 2:
				for gy in 2:
					_bar(ci, Rect2(c + Vector2(-0.75 + gx * 0.85, -0.75 + gy * 0.85) * s, Vector2(0.65, 0.65) * s), col)
		"gear":
			var pts := PackedVector2Array()
			for k in 16:
				var a := k * TAU / 16.0
				pts.append(c + Vector2(cos(a), sin(a)) * s * (0.85 if k % 2 == 0 else 0.62))
			_shape(ci, pts, col)
			ci.draw_circle(c, s * 0.25, DARK)
		"medal":
			_shape(ci, PackedVector2Array([c + Vector2(-0.5, -0.9) * s, c + Vector2(-0.1, -0.9) * s, c + Vector2(0.1, -0.2) * s, c + Vector2(-0.2, -0.2) * s]), Color("ff5c8a"))
			_shape(ci, PackedVector2Array([c + Vector2(0.5, -0.9) * s, c + Vector2(0.1, -0.9) * s, c + Vector2(-0.1, -0.2) * s, c + Vector2(0.2, -0.2) * s]), Color("5ce1ff"))
			ci.draw_circle(c + Vector2(0, 0.3) * s, s * 0.6, DARK)
			ci.draw_circle(c + Vector2(0, 0.3) * s, s * 0.48, Color("ffd34d"))
			var st := star(c + Vector2(0, 0.3) * s, s * 0.3, s * 0.13)
			ci.draw_colored_polygon(st, Color("ffaa2e"))
		"lock", "unlock":
			var open := n == "unlock"
			ci.draw_arc(c + Vector2(0.2 if open else 0.0, -0.25) * s, s * 0.45, PI, TAU, 14, DARK, s * 0.34, true)
			ci.draw_arc(c + Vector2(0.2 if open else 0.0, -0.25) * s, s * 0.45, PI, TAU, 14, Color("ffd34d") if open else col, s * 0.18, true)
			var body := Rect2(c + Vector2(-0.7, -0.2) * s, Vector2(1.4, 1.0) * s)
			ci.draw_rect(body.grow(s * 0.08), DARK)
			ci.draw_rect(body, Color("ffd34d") if open else col)
			ci.draw_circle(c + Vector2(0, 0.25) * s, s * 0.13, DARK)
		"door":
			ci.draw_rect(Rect2(c + Vector2(-0.6, -0.85) * s, Vector2(1.2, 1.7) * s).grow(s * 0.08), DARK)
			ci.draw_rect(Rect2(c + Vector2(-0.6, -0.85) * s, Vector2(1.2, 1.7) * s), Color("8a5cff"))
			ci.draw_rect(Rect2(c + Vector2(-0.4, -0.65) * s, Vector2(0.8, 1.5) * s), Color("2b1a5c"))
			ci.draw_circle(c + Vector2(0.25, 0.1) * s, s * 0.09, Color("ffd34d"))
		"shard":
			var d := PackedVector2Array([c + Vector2(0, -1) * s, c + Vector2(0.62, -0.2) * s, c + Vector2(0, 1) * s, c + Vector2(-0.62, -0.2) * s])
			ci.draw_colored_polygon(d, Color("5ce1ff"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -1) * s, c + Vector2(0.62, -0.2) * s, c + Vector2(0, -0.2) * s]), Color("c4f4ff"))
			ci.draw_polyline(closed(d), DARK, maxf(1.5, s * 0.14), true)
		"prism":
			var t := PackedVector2Array([c + Vector2(0, -0.95) * s, c + Vector2(0.9, 0.75) * s, c + Vector2(-0.9, 0.75) * s])
			ci.draw_colored_polygon(t, Color("ff7af0"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.95) * s, c + Vector2(0.2, 0.75) * s, c + Vector2(-0.9, 0.75) * s]), Color("b98cff"))
			ci.draw_polyline(closed(t), DARK, maxf(1.5, s * 0.14), true)
		"coin":
			ci.draw_circle(c, s, DARK)
			ci.draw_circle(c, s * 0.82, Color("ffd34d"))
			ci.draw_circle(c, s * 0.55, Color("ffaa2e"))
			var st := star(c, s * 0.42, s * 0.18)
			ci.draw_colored_polygon(st, Color("fff1a8"))
		"star":
			var st := star(c, s, s * 0.45)
			ci.draw_colored_polygon(st, Color("ffd34d"))
			ci.draw_polyline(closed(st), DARK, maxf(1.5, s * 0.14), true)
		# ----- hub tiles -----
		"forge":
			ci.draw_line(c + Vector2(-0.7, 0.7) * s, c + Vector2(0.3, -0.3) * s, DARK, s * 0.42)
			ci.draw_line(c + Vector2(-0.7, 0.7) * s, c + Vector2(0.3, -0.3) * s, Color("c98a4b"), s * 0.24)
			_shape(ci, PackedVector2Array([c + Vector2(0.0, -0.75) * s, c + Vector2(0.75, -0.75) * s, c + Vector2(0.75, 0.0) * s, c + Vector2(0.35, 0.05) * s, c + Vector2(-0.05, -0.35) * s]), Color("b8c4d6"))
			var sp := star(c + Vector2(-0.45, -0.5) * s, s * 0.28, s * 0.1, 4)
			ci.draw_colored_polygon(sp, Color("ffd34d"))
		"saved":
			_shape(ci, PackedVector2Array([c + Vector2(-0.85, -0.55) * s, c + Vector2(-0.25, -0.55) * s, c + Vector2(-0.1, -0.35) * s,
				c + Vector2(0.85, -0.35) * s, c + Vector2(0.85, 0.7) * s, c + Vector2(-0.85, 0.7) * s]), Color("ffc94d"))
			ci.draw_rect(Rect2(c + Vector2(-0.85, -0.15) * s, Vector2(1.7, 0.08) * s), Color(DARK, 0.4))
			var st := star(c + Vector2(0, 0.28) * s, s * 0.3, s * 0.13)
			ci.draw_colored_polygon(st, Color.WHITE)
		"scores":
			var pod := [[-0.75, 0.05, Color("b8c4d6")], [-0.25, -0.35, Color("ffd34d")], [0.25, 0.25, Color("ff9a5c")]]
			for pd in pod:
				var r := Rect2(c + Vector2(pd[0], pd[1]) * s, Vector2(0.5, 0.75 - pd[1]) * s)
				ci.draw_rect(r.grow(s * 0.06), DARK)
				ci.draw_rect(r, pd[2])
			var st := star(c + Vector2(0, -0.7) * s, s * 0.25, s * 0.11)
			ci.draw_colored_polygon(st, Color("ffd34d"))
			ci.draw_polyline(closed(st), DARK, 1.5, true)
		"quests":
			_shape(ci, PackedVector2Array([c + Vector2(-0.6, -0.85) * s, c + Vector2(0.6, -0.85) * s, c + Vector2(0.6, 0.85) * s, c + Vector2(-0.6, 0.85) * s]), Color("f4e9d0"))
			for k in 3:
				var y := -0.45 + k * 0.45
				ci.draw_polyline(PackedVector2Array([c + Vector2(-0.4, y) * s, c + Vector2(-0.28, y + 0.12) * s, c + Vector2(-0.1, y - 0.12) * s]), Color("3fb34f"), s * 0.12)
				ci.draw_line(c + Vector2(0.05, y) * s, c + Vector2(0.45, y) * s, Color(DARK, 0.6), s * 0.1)
		"ghost":
			var gp := PackedVector2Array()
			for k in 13:
				var a := PI + k * PI / 12.0
				gp.append(c + Vector2(cos(a), sin(a) * 1.0) * s * 0.7 + Vector2(0, -0.1) * s)
			gp.append(c + Vector2(0.7, 0.8) * s)
			for k in 4:
				gp.append(c + Vector2(0.35 - k * 0.35, 0.8 + (0.0 if k % 2 == 0 else -0.25)) * s)
			_shape(ci, gp, Color(1, 1, 1, 0.9))
			ci.draw_circle(c + Vector2(-0.25, -0.15) * s, s * 0.12, DARK)
			ci.draw_circle(c + Vector2(0.25, -0.15) * s, s * 0.12, DARK)
		"map":
			_shape(ci, PackedVector2Array([c + Vector2(-0.85, -0.6) * s, c + Vector2(-0.3, -0.8) * s, c + Vector2(0.3, -0.6) * s,
				c + Vector2(0.85, -0.8) * s, c + Vector2(0.85, 0.6) * s, c + Vector2(0.3, 0.8) * s, c + Vector2(-0.3, 0.6) * s, c + Vector2(-0.85, 0.8) * s]), Color("e9d9b0"))
			var dash := PackedVector2Array([c + Vector2(-0.6, 0.45) * s, c + Vector2(-0.2, 0.0) * s, c + Vector2(0.2, 0.2) * s, c + Vector2(0.55, -0.4) * s])
			ci.draw_polyline(dash, Color("d9534f"), s * 0.1, true)
			ci.draw_line(c + Vector2(0.45, -0.55) * s, c + Vector2(0.65, -0.25) * s, Color("d9534f"), s * 0.12)
			ci.draw_line(c + Vector2(0.65, -0.55) * s, c + Vector2(0.45, -0.25) * s, Color("d9534f"), s * 0.12)
		"daily":
			for k in 8:
				var a := k * PI / 4.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.55, c + Vector2(cos(a), sin(a)) * s * 0.9, DARK, s * 0.22)
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.55, c + Vector2(cos(a), sin(a)) * s * 0.85, Color("ffb62e"), s * 0.12)
			ci.draw_circle(c, s * 0.52, DARK)
			ci.draw_circle(c, s * 0.42, Color("ffd34d"))
		"weekly":
			ci.draw_rect(Rect2(c + Vector2(-0.8, -0.6) * s, Vector2(1.6, 1.4) * s).grow(s * 0.07), DARK)
			ci.draw_rect(Rect2(c + Vector2(-0.8, -0.6) * s, Vector2(1.6, 1.4) * s), Color.WHITE)
			ci.draw_rect(Rect2(c + Vector2(-0.8, -0.6) * s, Vector2(1.6, 0.4) * s), Color("ff5c8a"))
			for k in 7:
				ci.draw_rect(Rect2(c + Vector2(-0.68 + (k % 4) * 0.36, 0.0 + (k / 4) * 0.36) * s, Vector2(0.22, 0.22) * s), Color(DARK, 0.7) if k != 5 else Color("ff5c8a"))
		"event":
			_shape(ci, PackedVector2Array([c + Vector2(0.2, -0.95) * s, c + Vector2(-0.55, 0.15) * s, c + Vector2(-0.05, 0.15) * s,
				c + Vector2(-0.25, 0.95) * s, c + Vector2(0.6, -0.2) * s, c + Vector2(0.1, -0.2) * s]), Color("ffe14d"))
		"trials":
			ci.draw_rect(Rect2(c + Vector2(-0.8, -0.2) * s, Vector2(0.3, 1.0) * s).grow(s * 0.06), DARK)
			ci.draw_rect(Rect2(c + Vector2(0.5, -0.2) * s, Vector2(0.3, 1.0) * s).grow(s * 0.06), DARK)
			ci.draw_rect(Rect2(c + Vector2(-0.8, -0.2) * s, Vector2(0.3, 1.0) * s), Color("8a8a99"))
			ci.draw_rect(Rect2(c + Vector2(0.5, -0.2) * s, Vector2(0.3, 1.0) * s), Color("8a8a99"))
			ci.draw_arc(c + Vector2(0, -0.2) * s, s * 0.65, PI, TAU, 16, DARK, s * 0.36, true)
			ci.draw_arc(c + Vector2(0, -0.2) * s, s * 0.65, PI, TAU, 16, Color("8a8a99"), s * 0.2, true)
			var fl := PackedVector2Array([c + Vector2(0, -0.55) * s, c + Vector2(0.28, 0.0) * s, c + Vector2(0.12, 0.6) * s,
				c + Vector2(-0.12, 0.6) * s, c + Vector2(-0.28, 0.0) * s])
			ci.draw_colored_polygon(fl, Color("ff6a2e"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.15) * s, c + Vector2(0.12, 0.2) * s, c + Vector2(0, 0.6) * s, c + Vector2(-0.12, 0.2) * s]), Color("ffd34d"))
		"featured":
			var st := star(c, s * 0.95, s * 0.42)
			ci.draw_colored_polygon(st, Color("ffd34d"))
			ci.draw_polyline(closed(st), DARK, s * 0.14, true)
		"bonus":
			ci.draw_rect(Rect2(c + Vector2(-0.85, -0.25) * s, Vector2(1.7, 1.05) * s).grow(s * 0.07), DARK)
			ci.draw_rect(Rect2(c + Vector2(-0.85, -0.25) * s, Vector2(1.7, 1.05) * s), Color("b5793f"))
			ci.draw_rect(Rect2(c + Vector2(-0.9, -0.75) * s, Vector2(1.8, 0.5) * s).grow(s * 0.07), DARK)
			ci.draw_rect(Rect2(c + Vector2(-0.9, -0.75) * s, Vector2(1.8, 0.5) * s), Color("d38f4f"))
			ci.draw_rect(Rect2(c + Vector2(-0.15, -0.45) * s, Vector2(0.3, 0.45) * s), Color("ffd34d"))
		"paths":
			var nodes := [Vector2(-0.7, 0.6), Vector2(-0.2, 0.1), Vector2(0.35, 0.4), Vector2(0.7, -0.5)]
			for k in 3:
				ci.draw_line(c + nodes[k] * s, c + nodes[k + 1] * s, DARK, s * 0.22)
				ci.draw_line(c + nodes[k] * s, c + nodes[k + 1] * s, Color("ffe08a"), s * 0.1)
			var cols := [Color("5ce1ff"), Color("ff7af0"), Color("7ee04a"), Color("ffd34d")]
			for k in 4:
				ci.draw_circle(c + nodes[k] * s, s * 0.22, DARK)
				ci.draw_circle(c + nodes[k] * s, s * 0.15, cols[k])
		"packs":
			var cols := [Color("ff7af0"), Color("5ce1ff"), Color("ffc94d")]
			for k in 3:
				var o := Vector2(-0.45 + k * 0.3, -0.45 + k * 0.3) * s
				ci.draw_rect(Rect2(c + o - Vector2(0.45, 0.4) * s, Vector2(0.9, 0.8) * s).grow(s * 0.06), DARK)
				ci.draw_rect(Rect2(c + o - Vector2(0.45, 0.4) * s, Vector2(0.9, 0.8) * s), cols[k])
		"search":
			ci.draw_line(c + Vector2(0.25, 0.25) * s, c + Vector2(0.85, 0.85) * s, DARK, s * 0.4)
			ci.draw_line(c + Vector2(0.25, 0.25) * s, c + Vector2(0.85, 0.85) * s, Color("c98a4b"), s * 0.22)
			ci.draw_circle(c + Vector2(-0.15, -0.15) * s, s * 0.6, DARK)
			ci.draw_circle(c + Vector2(-0.15, -0.15) * s, s * 0.46, Color("bdeeff"))
		"shop":
			ci.draw_rect(Rect2(c + Vector2(-0.8, -0.2) * s, Vector2(1.6, 1.0) * s).grow(s * 0.07), DARK)
			ci.draw_rect(Rect2(c + Vector2(-0.8, -0.2) * s, Vector2(1.6, 1.0) * s), Color("f4e9d0"))
			for k in 4:
				var r := Rect2(c + Vector2(-0.9 + k * 0.45, -0.75) * s, Vector2(0.45, 0.5) * s)
				ci.draw_rect(r.grow(s * 0.04), DARK)
				ci.draw_rect(r, Color("ff5c5c") if k % 2 == 0 else Color.WHITE)
			ci.draw_rect(Rect2(c + Vector2(-0.25, 0.2) * s, Vector2(0.5, 0.6) * s), Color("8a5cff"))


static func _shape(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_polyline(closed(pts), DARK, 7.0, true)
	ci.draw_colored_polygon(pts, col)


static func _bar(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_rect(r.grow(3.0), DARK)
	ci.draw_rect(r, col)
