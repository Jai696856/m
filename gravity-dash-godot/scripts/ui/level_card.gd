extends Control
## The big level card on the level select and list screens. Click it to play.

signal chosen

const FONT = preload("res://fonts/Fredoka-Bold.ttf")
const Skins = preload("res://scripts/skins.gd")
const Levels = preload("res://scripts/levels.gd")
const DARK := Color(0.05, 0.03, 0.12)
const MECH_NAMES := {"saw": "Saws", "orb": "Orbs", "pad": "Pads", "portal": "Portals", "speed": "Speed", "mini": "Mini", "dual": "Dual"}

var lv: Dictionary = {}
var subtitle := ""
var hover := false
var slide := 0.0:
	set(v):
		slide = v
		queue_redraw()
var _tw: Tween


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	resized.connect(_center_pivot)
	_center_pivot()


func _center_pivot() -> void:
	pivot_offset = size * 0.5


func _hover(on: bool) -> void:
	hover = on
	_bounce(1.03 if on else 1.0)
	queue_redraw()


func _bounce(target: float) -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2.ONE * target, 0.18)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_bounce(0.96)
		else:
			_bounce(1.03 if hover else 1.0)
			if Rect2(Vector2.ZERO, size).has_point(e.position):
				Audio.sfx("click")
				chosen.emit()
		accept_event()


func set_level(l: Dictionary, dir: int, sub := "") -> void:
	lv = l
	subtitle = sub
	if dir != 0:
		slide = 240.0 * dir
		modulate.a = 0.0
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "slide", 0.0, 0.25)
		tw.tween_property(self, "modulate:a", 1.0, 0.2)
	queue_redraw()


func _text(s: String, at: Vector2, fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(FONT, at, s, align, width, fs, maxi(6, int(fs * 0.24)), DARK)
	draw_string(FONT, at, s, align, width, fs, col)


static func fmt_time(sec: float) -> String:
	if sec <= 0.0:
		return "-"
	return "%d:%04.1f" % [int(sec) / 60, fmod(sec, 60.0)]


func _bar(r: Rect2, pct: int, col: Color) -> void:
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0, 0, 0, 0.5)
	bsb.set_corner_radius_all(int(r.size.y * 0.5))
	bsb.border_color = DARK
	bsb.set_border_width_all(3)
	draw_style_box(bsb, r)
	if pct > 0:
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = col
		fsb.set_corner_radius_all(int(r.size.y * 0.5) - 3)
		var fw := maxf(r.size.y - 6.0, (r.size.x - 6) * pct / 100.0)
		draw_style_box(fsb, Rect2(r.position + Vector2(3, 3), Vector2(fw, r.size.y - 6)))
	_text("%d%%" % pct, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 8), 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw() -> void:
	if lv.is_empty():
		return
	draw_set_transform(Vector2(slide, 0), 0.0, Vector2.ONE)
	var p: Dictionary = lv.p
	var key: String = p.key
	var tier: int = p.tier
	var tc := Color(Skins.TIER_COLORS[tier])
	var w := size.x
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.09, 0.8)
	sb.set_corner_radius_all(24)
	sb.border_color = tc if hover else tc.darkened(0.3)
	sb.set_border_width_all(5)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_offset = Vector2(0, 6)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))

	Skins.draw_face(self, Vector2(125, 125), 66.0, tier)
	_text(Skins.TIER_NAMES[tier], Vector2(25, 240), 30, tc, HORIZONTAL_ALIGNMENT_CENTER, 200)
	_text(subtitle, Vector2(250, 66), 22, Color(1, 1, 1, 0.6))
	_text(str(p.name), Vector2(250, 120), 52, Color.WHITE)

	# Star reward and coins
	Skins.symbol(self, "star", Vector2(w - 50, 56), 20.0)
	_text(str(p.stars), Vector2(w - 140, 66), 30, Color("ffe08a"), HORIZONTAL_ALIGNMENT_RIGHT, 60)
	var coins: Array = Save.coins_of(key)
	for i in 3:
		var c := Vector2(w - 140 + i * 34, 104)
		if coins[i]:
			Skins.symbol(self, "coin", c, 13.0)
		else:
			draw_circle(c, 13.0, Color(0, 0, 0, 0.4))
			draw_arc(c, 12.0, 0, TAU, 20, Color(1, 1, 1, 0.3), 2.0, true)

	var best := Save.best(key)
	var practice := int(Save.level(key).practice) if Save.has_level(key) else 0
	_text("Normal", Vector2(250, 166), 20, Color(1, 1, 1, 0.7))
	_bar(Rect2(340, 148, w - 380, 28), best, tc)
	_text("Practice", Vector2(250, 206), 20, Color(1, 1, 1, 0.7))
	_bar(Rect2(340, 188, w - 380, 28), practice, Color("7ee04a"))

	var secs: float = float(lv.end) / float(lv.speed)
	var rec := Save.level(key) if Save.has_level(key) else {}
	var line := "%s (%ds)     Attempts %d     Best time %s" % [Levels.length_name(secs), int(secs), int(rec.get("attempts", 0)), fmt_time(float(rec.get("time", 0.0)))]
	_text(line, Vector2(250, 252), 19, Color(1, 1, 1, 0.75))
	# Mechanic chips
	var x := 250.0
	var mech: Array = Levels._mech(p)
	for m in mech:
		var label: String = MECH_NAMES.get(m, m)
		var tw := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 18
		var chip := StyleBoxFlat.new()
		chip.bg_color = Color(1, 1, 1, 0.12)
		chip.set_corner_radius_all(10)
		draw_style_box(chip, Rect2(x, 266, tw, 24))
		draw_string(FONT, Vector2(x + 9, 284), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.85))
		x += tw + 8
	if Save.is_done(key):
		_text("COMPLETE", Vector2(w - 230, 150 - 20), 22, Color("8ee53f"), HORIZONTAL_ALIGNMENT_RIGHT, 200)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
