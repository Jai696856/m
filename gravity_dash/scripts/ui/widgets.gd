extends Control

const FONT = preload("res://fonts/Fredoka-Bold.ttf")
const Skins = preload("res://scripts/skins.gd")
const DARK:= Color(0.05, 0.03, 0.12)

var kind:= "progress"
var world: Node = null
var value:= -1
var color:= Color("ffc94d")
var lv: Dictionary = {}
var idx:= 0
var t:= 0.0
var pop:= 0.0
var ready_glow:= false

func _ready() -> void:
	if kind != "row":
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == "wallet":
		Save.changed.connect(queue_redraw)

func _process(delta: float) -> void:
	if kind == "row":
		return
	t += delta
	pop = maxf(0.0, pop - delta * 3.0)
	queue_redraw()

func _text(s: String, at: Vector2, fs: int, col: Color, align:= HORIZONTAL_ALIGNMENT_LEFT, width:= -1.0) -> void:
	draw_string_outline(FONT, at, s, align, width, fs, maxi(5, int(fs * 0.26)), DARK)
	draw_string(FONT, at, s, align, width, fs, col)

func _bar(r: Rect2, p: float, col: Color) -> void:
	var sb:= StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.5)
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	sb.border_color = DARK
	sb.set_border_width_all(3)
	draw_style_box(sb, r)
	if p > 0.0:
		var f:= StyleBoxFlat.new()
		f.bg_color = col
		f.set_corner_radius_all(int(r.size.y * 0.5) - 3)
		var inner:= r.grow(-3.0)
		inner.size.x = maxf(inner.size.y, inner.size.x * minf(1.0, p))
		draw_style_box(f, inner)

func _draw() -> void:
	match kind:
		"progress":
			var p: int = value if value >= 0 else (world.pct() if world else 0)
			if Save.setting("percent") or value >= 0:
				_bar(Rect2(0, 4, size.x - 78, size.y - 8), p / 100.0, color)
				_text("%d%%" % p, Vector2(size.x - 70, size.y * 0.5 + 9), 26, Color.WHITE)
		"preview":
			var c:= size * 0.5 + Vector2(0, sin(t * 2.2) * 8.0)
			var sq:= sin(pop * PI) * 0.25
			draw_circle(Vector2(size.x * 0.5, size.y - 14), size.x * 0.26, Color(0, 0, 0, 0.25))
			var spin:= (1.0 - pop) * TAU if pop > 0.0 else 0.0
			Skins.draw_icon(self, c, spin, Vector2(1.0 + sq, 1.0 - sq) * size.x / 30.0 * 0.5, Save.icon(), Save.c1(), Save.c2())
		"row":
			var p: Dictionary = lv.p
			var tier: int = p.tier
			var tc:= Color(Skins.TIER_COLORS[tier])
			var key: String = p.key
			Skins.draw_face(self, Vector2(22, size.y * 0.5), 15.0, tier)
			_text(str(p.name), Vector2(50, size.y * 0.5 + 9), 22, Color("8ee53f") if Save.is_done(key) else Color.WHITE)
			_bar(Rect2(250, size.y * 0.5 - 10, 130, 20), Save.best(key) / 100.0, tc)
			_text("%d%%" % Save.best(key), Vector2(388, size.y * 0.5 + 9), 20, Color.WHITE)
			var coins: Array = Save.coins_of(key)
			for i in 3:
				var c:= Vector2(448 + i * 20, size.y * 0.5)
				if coins[i]:
					Skins.symbol(self, "coin", c, 8.0)
				else:
					draw_arc(c, 7.0, 0, TAU, 14, Color(1, 1, 1, 0.3), 1.5)
		"wallet":
			Skins.symbol(self, "shard", Vector2(16, size.y * 0.5), 13.0)
			_text(str(Save.shards()), Vector2(36, size.y * 0.5 + 10), 28, Color("bdf1ff"))
			var w:= FONT.get_string_size(str(Save.shards()), HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			Skins.symbol(self, "prism", Vector2(64 + w, size.y * 0.5), 13.0)
			_text(str(Save.prisms()), Vector2(84 + w, size.y * 0.5 + 10), 28, Color("ffc4fb"))
		"keeper":
			_draw_keeper()
		"chest":
			_draw_chest()

func _draw_keeper() -> void:
	var c:= Vector2(size.x * 0.5, size.y * 0.55)
	var bob:= sin(t * 2.0) * 4.0
	var s:= minf(size.x, size.y) * 0.36
	c.y += bob
	match idx:
		0:
			var body:= Rect2(c - Vector2(s, s), Vector2(s * 2.0, s * 2.0))
			draw_rect(body.grow(5.0), DARK)
			draw_rect(body, Color("d38f4f"))
			draw_rect(Rect2(body.position, Vector2(body.size.x, s * 0.4)), Color("b5793f"))
			draw_line(c + Vector2(-s, -s * 0.2), c + Vector2(s, -s * 0.2), Color("8a5a2b"), 4.0)
			for sx in [-0.4, 0.4]:
				draw_circle(c + Vector2(sx * s, s * 0.15), s * 0.18, DARK)
				draw_circle(c + Vector2(sx * s + s * 0.05, s * 0.1), s * 0.06, Color.WHITE)
			draw_arc(c + Vector2(0, s * 0.45), s * 0.3, 0.3, PI - 0.3, 12, DARK, 4.0)
			draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 1.6), Vector2(s * 1.4, s * 0.5)).grow(4.0), DARK)
			draw_rect(Rect2(c + Vector2(-s * 0.7, -s * 1.6), Vector2(s * 1.4, s * 0.5)), Color("ff5c5c"))
		1:
			var pts:= PackedVector2Array()
			for k in 24:
				var a:= k * TAU / 24.0
				pts.append(c + Vector2(cos(a) * s, sin(a) * s * 0.9))
			draw_colored_polygon(pts, Color("ff7af0"))
			draw_polyline(Skins.closed(pts), DARK, 5.0, true)
			for k in 3:
				var cols:= [Color("5ce1ff"), Color("ffd34d"), Color("7ee04a")]
				draw_line(c + Vector2(-s * 0.9, -s * 0.2 + k * s * 0.3), c + Vector2(-s * 1.8, -s * 0.4 + k * s * 0.35 + sin(t * 4 + k) * 6), cols[k], 9.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.85, -s * 0.1), c + Vector2(s * 1.45, s * 0.05), c + Vector2(s * 0.85, s * 0.25)]), Color("ffb62e"))
			draw_circle(c + Vector2(s * 0.35, -s * 0.25), s * 0.2, Color.WHITE)
			draw_circle(c + Vector2(s * 0.4, -s * 0.25), s * 0.1, DARK)
		2:
			var body:= Rect2(c - Vector2(s * 0.85, s * 1.1), Vector2(s * 1.7, s * 2.2))
			draw_rect(body.grow(5.0), DARK)
			draw_rect(body, Color("3a3f5c"))
			var thump:= 1.0 + Audio.beat_pulse() * 0.12
			draw_circle(c + Vector2(0, s * 0.35), s * 0.55 * thump, DARK)
			draw_circle(c + Vector2(0, s * 0.35), s * 0.45 * thump, Color("5c6491"))
			draw_circle(c + Vector2(0, s * 0.35), s * 0.18, DARK)
			draw_circle(c + Vector2(0, -s * 0.6), s * 0.25, DARK)
			draw_circle(c + Vector2(0, -s * 0.6), s * 0.17, Color("5ce1ff"))
			draw_circle(c + Vector2(-s * 0.45, -s * 0.85), s * 0.07, Color("7ee04a"))
		3:
			var glow:= 0.6 + sin(t * 3.0) * 0.2
			draw_circle(c, s * 1.2, Color(0.8, 0.5, 1.0, 0.12 * glow))
			draw_rect(Rect2(c + Vector2(-s * 0.6, -s * 1.1), Vector2(s * 1.2, s * 0.25)).grow(4.0), DARK)
			draw_rect(Rect2(c + Vector2(-s * 0.6, -s * 1.1), Vector2(s * 1.2, s * 0.25)), Color("d4af37"))
			var glass:= PackedVector2Array([c + Vector2(-s * 0.55, -s * 0.85), c + Vector2(s * 0.55, -s * 0.85), c + Vector2(s * 0.7, s * 0.8), c + Vector2(-s * 0.7, s * 0.8)])
			draw_colored_polygon(glass, Color(0.75, 0.55, 1.0, 0.85))
			draw_polyline(Skins.closed(glass), DARK, 5.0, true)
			draw_circle(c + Vector2(0, s * 0.05), s * 0.35 * glow, Color("fff1a8"))
			for sx in [-0.2, 0.2]:
				draw_circle(c + Vector2(sx * s, -s * 0.05), s * 0.07, DARK)

func _draw_chest() -> void:
	var c:= size * 0.5
	var wig:= sin(t * 18.0) * 0.06 if ready_glow and fmod(t, 1.6) < 0.5 else 0.0
	var s:= minf(size.x, size.y) * (0.42 if idx == 1 else 0.34)
	if ready_glow:
		draw_circle(c, s * 1.4, Color(1, 0.85, 0.3, 0.15 + sin(t * 3.0) * 0.06))
	draw_set_transform(c, wig, Vector2.ONE)
	var base:= Color("d38f4f") if idx == 0 else Color("8a5cff")
	var trim:= Color("ffd34d")
	draw_rect(Rect2(-s, -s * 0.2, s * 2.0, s * 1.1).grow(5.0), DARK)
	draw_rect(Rect2(-s, -s * 0.2, s * 2.0, s * 1.1), base)
	draw_rect(Rect2(-s * 1.05, -s * 0.85, s * 2.1, s * 0.65).grow(5.0), DARK)
	draw_rect(Rect2(-s * 1.05, -s * 0.85, s * 2.1, s * 0.65), base.lightened(0.15))
	draw_rect(Rect2(-s * 0.18, -s * 0.5, s * 0.36, s * 0.55), trim)
	draw_rect(Rect2(-s, s * 0.35, s * 2.0, s * 0.12), trim)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
