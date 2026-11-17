extends RefCounted
## Cube icons, colours and their unlock requirements, plus the difficulty faces.
## Everything is drawn with code in a 30 x 30 box centred on the origin.

const DARK := Color(0.05, 0.03, 0.12)

const TIER_NAMES := ["Easy", "Normal", "Hard", "Harder", "Insane", "Demon"]
const TIER_COLORS := ["49b6ff", "5fd35a", "ffb62e", "ff5a3c", "ff4fd8", "a64dff"]

const ICONS := [
	{"name": "Classic", "req": {}},
	{"name": "Smiley", "req": {}},
	{"name": "Diamond", "req": {}},
	{"name": "Visor", "req": {"stat": "flips", "n": 100, "text": "Flip gravity 100 times"}},
	{"name": "Ring", "req": {"stat": "attempts", "n": 50, "text": "Make 50 attempts"}},
	{"name": "Plus", "req": {"stat": "completions", "n": 1, "text": "Complete 1 level"}},
	{"name": "Checker", "req": {"stat": "completions", "n": 3, "text": "Complete 3 levels"}},
	{"name": "Target", "req": {"stat": "flips", "n": 500, "text": "Flip gravity 500 times"}},
	{"name": "Grump", "req": {"stat": "deaths", "n": 200, "text": "Crash 200 times"}},
	{"name": "Bolt", "req": {"stat": "stars", "n": 15, "text": "Collect 15 stars"}},
	{"name": "Ghost", "req": {"stat": "attempts", "n": 300, "text": "Make 300 attempts"}},
	{"name": "Heart", "req": {"stat": "perfect", "n": 1, "text": "Beat a level on its first attempt"}},
	{"name": "Star", "req": {"stat": "stars", "n": 40, "text": "Collect 40 stars"}},
	{"name": "Split", "req": {"stat": "completions", "n": 9, "text": "Complete 9 levels"}},
	{"name": "Dots", "req": {"stat": "flips", "n": 3000, "text": "Flip gravity 3,000 times"}},
	{"name": "Crown", "req": {"stat": "completions", "n": 18, "text": "Complete all 18 levels"}},
]

const COLORS := [
	{"hex": "ffc94d", "req": {}},
	{"hex": "5ce1ff", "req": {}},
	{"hex": "ff5c8a", "req": {}},
	{"hex": "7ee04a", "req": {}},
	{"hex": "ffffff", "req": {}},
	{"hex": "b07aff", "req": {}},
	{"hex": "ff8a3d", "req": {"stat": "stars", "n": 3, "text": "Collect 3 stars"}},
	{"hex": "3d6bff", "req": {"stat": "stars", "n": 6, "text": "Collect 6 stars"}},
	{"hex": "ff4fd8", "req": {"stat": "stars", "n": 10, "text": "Collect 10 stars"}},
	{"hex": "00e0b0", "req": {"stat": "stars", "n": 15, "text": "Collect 15 stars"}},
	{"hex": "ffe14d", "req": {"stat": "stars", "n": 20, "text": "Collect 20 stars"}},
	{"hex": "ff2e2e", "req": {"stat": "stars", "n": 30, "text": "Collect 30 stars"}},
	{"hex": "8a8a99", "req": {"stat": "stars", "n": 40, "text": "Collect 40 stars"}},
	{"hex": "2a2a3a", "req": {"stat": "stars", "n": 55, "text": "Collect 55 stars"}},
	{"hex": "c0ff3d", "req": {"stat": "stars", "n": 70, "text": "Collect 70 stars"}},
	{"hex": "ff9cf5", "req": {"stat": "stars", "n": 90, "text": "Collect 90 stars"}},
]


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
