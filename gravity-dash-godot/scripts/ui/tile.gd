extends Control
## A clickable square tile. Used three ways, picked with `kind`:
##   "hub"   a big menu tile with a drawn symbol and a label (greyed out with a lock when locked)
##   "item"  an icon kit / shop item (icon, colour, trail, death effect, theme or extra)
##   "color" a colour swatch

const FONT = preload("res://fonts/Fredoka-Bold.ttf")
const Skins = preload("res://scripts/skins.gd")
const Catalog = preload("res://scripts/catalog.gd")
const DARK := Color(0.05, 0.03, 0.12)

var kind := "hub"
var symbol := ""
var label := ""
var fill := Color("7ee04a")
var locked := false
var badge := ""
var item_kind := ""
var idx := 0
var selected := false
var price := ""
var cb: Callable
var hover := false
var _tw: Tween


func hub(p_symbol: String, p_label: String, p_fill: Color, p_locked: bool, p_cb: Callable, side := 170.0):
	kind = "hub"
	symbol = p_symbol
	label = p_label
	fill = p_fill
	locked = p_locked
	cb = p_cb
	custom_minimum_size = Vector2(side, side)
	return self


func item(p_kind: String, p_idx: int, p_cb: Callable, side := 72.0):
	kind = "item"
	item_kind = p_kind
	idx = p_idx
	cb = p_cb
	custom_minimum_size = Vector2(side, side)
	return self


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	resized.connect(func(): pivot_offset = size * 0.5)
	pivot_offset = custom_minimum_size * 0.5


func _set_hover(on: bool) -> void:
	hover = on
	if kind == "hub":
		if _tw:
			_tw.kill()
		_tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "scale", Vector2.ONE * (1.06 if on else 1.0), 0.16)
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if kind == "hub":
			Audio.sfx("deny" if locked else "click")
			cb.call()
		else:
			cb.call(item_kind, idx)
		accept_event()


func _draw() -> void:
	if kind == "hub":
		_draw_hub()
	else:
		_draw_item()


func _draw_hub() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var f := fill.darkened(0.55) if locked else fill
	if locked:
		f = Color(f.v * 0.4 + 0.15, f.v * 0.4 + 0.15, f.v * 0.4 + 0.17)
	var sb := StyleBoxFlat.new()
	sb.bg_color = f.darkened(0.25)
	sb.set_corner_radius_all(14)
	sb.border_color = DARK
	sb.set_border_width_all(5)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_offset = Vector2(4, 6)
	draw_style_box(sb, r)
	var top := StyleBoxFlat.new()
	top.bg_color = f
	top.set_corner_radius_all(9)
	draw_style_box(top, Rect2(7, 7, size.x - 14, size.y * 0.55))
	if hover and not locked:
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.border_color = Color.WHITE
		ring.set_border_width_all(4)
		ring.set_corner_radius_all(14)
		draw_style_box(ring, r)
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	Skins.symbol(self, symbol, c, size.x * 0.28, Color.WHITE)
	if locked:
		draw_rect(Rect2(6, 6, size.x - 12, size.y - 12), Color(0.1, 0.1, 0.14, 0.45))
		Skins.symbol(self, "lock", Vector2(size.x - 26, 28), 13.0, Color(0.8, 0.8, 0.85))
	var fs := int(size.x * 0.14)
	var base := Vector2(0, size.y - 16)
	draw_string_outline(FONT, base, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 8, DARK)
	draw_string(FONT, base, label, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(1, 1, 1, 0.6) if locked else Color.WHITE)
	if badge != "":
		draw_circle(Vector2(size.x - 14, 14), 14.0, DARK)
		draw_circle(Vector2(size.x - 14, 14), 11.0, Color("ff4a4a"))
		draw_string(FONT, Vector2(size.x - 28, 21), badge, HORIZONTAL_ALIGNMENT_CENTER, 28, 16, Color.WHITE)


func _draw_item() -> void:
	var owned := Save.owns(item_kind, idx)
	var sel := _is_selected()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(4)
	sb.border_color = Color.WHITE if sel else (Color(1, 1, 1, 0.35) if hover else Color(1, 1, 1, 0.08))
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var c := size * 0.5
	var l: Array = Catalog.list(item_kind)
	match item_kind:
		"icon":
			Skins.draw_icon(self, c, 0.0, Vector2.ONE * size.x / 30.0 * 0.58, idx, Save.c1(), Save.c2())
		"color":
			draw_circle(c, size.x * 0.32, DARK)
			draw_circle(c, size.x * 0.32 - 3.0, Color(l[idx].hex))
		"trail", "death", "theme", "extra":
			var sym: String = {"trail": "featured", "death": "event", "theme": "music", "extra": "gear"}[item_kind]
			if item_kind == "trail":
				_trail_preview(c, idx)
			elif item_kind == "death":
				_death_preview(c, idx)
			else:
				Skins.symbol(self, sym, c - Vector2(0, 8), size.x * 0.2)
			var nm: String = l[idx].name
			draw_string_outline(FONT, Vector2(2, size.y - 8), nm, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, 13, 4, DARK)
			draw_string(FONT, Vector2(2, size.y - 8), nm, HORIZONTAL_ALIGNMENT_CENTER, size.x - 4, 13, Color.WHITE)
	if not owned:
		var src: Dictionary = l[idx].src
		draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(0.02, 0.01, 0.06, 0.3 if src.has("shop") else 0.62))
		if src.has("shop"):
			Skins.symbol(self, "shard" if src.cur == "shards" else "prism", Vector2(16, size.y - 16), 8.0)
			draw_string_outline(FONT, Vector2(26, size.y - 9), str(src.price), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, DARK)
			draw_string(FONT, Vector2(26, size.y - 9), str(src.price), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
		else:
			Skins.symbol(self, "lock", c, size.x * 0.17, Color(1, 1, 1, 0.85))


func _is_selected() -> bool:
	match item_kind:
		"icon":
			return Save.skin("icon") == idx
		"trail":
			return Save.skin("trail") == idx
		"death":
			return Save.skin("death") == idx
		"theme":
			return Save.skin("theme") == idx
		"color":
			return selected
		"extra":
			return Save.has_extra(Catalog.EXTRAS[idx].id)
	return false


func _trail_preview(c: Vector2, i: int) -> void:
	var col := Save.c1()
	for k in 5:
		var q := c + Vector2(-20 + k * 8, -8 + sin(k) * 3)
		match i:
			0:
				pass
			2, 4:
				draw_line(q, q + Vector2(8, 0), Color.from_hsv(k * 0.15, 0.7, 1.0) if i == 4 else Color(col, 0.2 + k * 0.15), 5.0)
			3, 8:
				draw_colored_polygon(Skins.star(q, 4.0, 1.6, 4), Color(Save.c2(), 0.4 + k * 0.12))
			5:
				draw_arc(q, 3.0, 0, TAU, 10, Color(Save.c2(), 0.8), 1.5)
			7:
				draw_circle(q, 2.0 + k, Color(Color("ffd34d").lerp(Color("ff4a2e"), 1.0 - k / 5.0), 0.7))
			_:
				draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), Color(col, 0.2 + k * 0.15))
	Skins.draw_icon(self, c + Vector2(22, -8), 0.0, Vector2.ONE * 0.4, Save.icon(), Save.c1(), Save.c2())


func _death_preview(c: Vector2, i: int) -> void:
	var cols := [Save.c1(), Save.c2(), Color.WHITE]
	var rng := RandomNumberGenerator.new()
	rng.seed = i + 3
	match i:
		2:
			draw_arc(c - Vector2(0, 8), 14.0, 0, TAU, 24, Save.c1(), 3.0)
			draw_arc(c - Vector2(0, 8), 8.0, 0, TAU, 24, Save.c2(), 2.0)
		5:
			for k in 8:
				var a := k * TAU / 8.0
				draw_line(c - Vector2(0, 8) + Vector2(cos(a), sin(a)) * 16.0, c - Vector2(0, 8) + Vector2(cos(a), sin(a)) * 8.0, Save.c1(), 2.0)
		_:
			for k in 10:
				var q := c - Vector2(0, 8) + Vector2(rng.randf_range(-18, 18), rng.randf_range(-14, 14))
				var col: Color = Color.from_hsv(rng.randf(), 0.6, 1.0) if i == 3 else cols[k % 3]
				if i == 1:
					draw_colored_polygon(PackedVector2Array([q, q + Vector2(6, 2), q + Vector2(2, 6)]), col)
				else:
					draw_rect(Rect2(q, Vector2(4, 4)), col)
