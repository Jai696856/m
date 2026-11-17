extends Control
## Small drawn widgets, picked with `kind`:
##  "progress"  the in-game progress bar (reads the world, or shows `value`)
##  "preview"   the big bobbing cube in the icon kit
##  "row"       one level row on the statistics screen

const FONT = preload("res://fonts/Fredoka-Bold.ttf")
const Skins = preload("res://scripts/skins.gd")
const DARK := Color(0.05, 0.03, 0.12)

var kind := "progress"
var world: Node = null
var value := -1
var color := Color("ffc94d")
var lv: Dictionary = {}
var idx := 0
var t := 0.0
var pop := 0.0


func _ready() -> void:
	if kind != "row":
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if kind == "row":
		return
	t += delta
	pop = maxf(0.0, pop - delta * 3.0)
	queue_redraw()


func _text(s: String, at: Vector2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(FONT, at, s, align, width, fs, maxi(5, int(fs * 0.26)), DARK)
	draw_string(FONT, at, s, align, width, fs, col)


func _bar(r: Rect2, p: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.5)
	sb.set_corner_radius_all(int(r.size.y * 0.5))
	sb.border_color = DARK
	sb.set_border_width_all(3)
	draw_style_box(sb, r)
	if p > 0.0:
		var f := StyleBoxFlat.new()
		f.bg_color = col
		f.set_corner_radius_all(int(r.size.y * 0.5) - 3)
		var inner := r.grow(-3.0)
		inner.size.x = maxf(inner.size.y, inner.size.x * p)
		draw_style_box(f, inner)


func _draw() -> void:
	match kind:
		"progress":
			var p: int = value if value >= 0 else (world.pct() if world else 0)
			_bar(Rect2(0, 4, size.x - 78, size.y - 8), p / 100.0, color)
			_text("%d%%" % p, Vector2(size.x - 70, size.y * 0.5 + 9), 26, Color.WHITE)
		"preview":
			var c := size * 0.5 + Vector2(0, sin(t * 2.2) * 8.0)
			var sq := sin(pop * PI) * 0.25
			draw_circle(Vector2(size.x * 0.5, size.y - 14), size.x * 0.26, Color(0, 0, 0, 0.25))
			var spin := (1.0 - pop) * TAU if pop > 0.0 else 0.0
			Skins.draw_icon(self, c, spin, Vector2(1.0 + sq, 1.0 - sq) * size.x / 30.0 * 0.55, Save.icon(), Save.c1(), Save.c2())
		"row":
			var d: Dictionary = lv.def
			var tier: int = d.tier
			var tc := Color(Skins.TIER_COLORS[tier])
			Skins.draw_face(self, Vector2(22, size.y * 0.5), 15.0, tier)
			_text(str(d.name), Vector2(50, size.y * 0.5 + 9), 22, Color("8ee53f") if Save.is_done(idx) else Color.WHITE)
			_bar(Rect2(250, size.y * 0.5 - 10, 150, 20), Save.best(idx) / 100.0, tc)
			_text("%d%%" % Save.best(idx), Vector2(408, size.y * 0.5 + 9), 20, Color.WHITE)
			_text("%d tries" % Save.level_attempts(idx), Vector2(size.x - 100, size.y * 0.5 + 9), 18, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, 96)
