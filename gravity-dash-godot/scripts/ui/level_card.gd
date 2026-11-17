extends Control
## The big level card on the level select screen. Click it to play.

signal chosen

const FONT = preload("res://fonts/Fredoka-Bold.ttf")
const Skins = preload("res://scripts/skins.gd")
const DARK := Color(0.05, 0.03, 0.12)

var lv: Dictionary = {}
var idx := 0
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


func set_level(l: Dictionary, i: int, dir: int) -> void:
	lv = l
	idx = i
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


func _draw() -> void:
	if lv.is_empty():
		return
	draw_set_transform(Vector2(slide, 0), 0.0, Vector2.ONE)
	var d: Dictionary = lv.def
	var tier: int = d.tier
	var tc := Color(Skins.TIER_COLORS[tier])
	var w := size.x
	var h := size.y
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.02, 0.09, 0.78)
	sb.set_corner_radius_all(26)
	sb.border_color = tc if hover else tc.darkened(0.3)
	sb.set_border_width_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_offset = Vector2(0, 8)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))

	Skins.draw_face(self, Vector2(135, 135), 72.0, tier)
	_text(Skins.TIER_NAMES[tier], Vector2(35, 262), 32, tc, HORIZONTAL_ALIGNMENT_CENTER, 200)
	_text("LEVEL %d" % (idx + 1), Vector2(260, 78), 24, Color(1, 1, 1, 0.65))
	_text(str(d.name), Vector2(260, 140), 58, Color.WHITE)

	# Stars for beating it
	var star_c := Vector2(w - 70, 66)
	var st := Skins.star(star_c, 26.0, 11.0)
	draw_colored_polygon(st, Color("ffd34d") if Save.is_done(idx) else Color(1, 1, 1, 0.25))
	draw_polyline(Skins.closed(st), DARK, 4.0, true)
	_text(str(d.stars), Vector2(w - 150, 78), 34, Color("ffe08a"), HORIZONTAL_ALIGNMENT_RIGHT, 50)

	# Normal mode progress bar
	var best := Save.best(idx)
	_text("Normal Mode", Vector2(260, 200), 22, Color(1, 1, 1, 0.7))
	var bar := Rect2(260, 214, w - 300, 36)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0, 0, 0, 0.5)
	bsb.set_corner_radius_all(18)
	bsb.border_color = DARK
	bsb.set_border_width_all(4)
	draw_style_box(bsb, bar)
	if best > 0:
		var fsb := StyleBoxFlat.new()
		fsb.bg_color = tc
		fsb.set_corner_radius_all(14)
		var fw := maxf(28.0, (bar.size.x - 8) * best / 100.0)
		draw_style_box(fsb, Rect2(bar.position + Vector2(4, 4), Vector2(fw, bar.size.y - 8)))
	_text("%d%%" % best, Vector2(bar.position.x, bar.position.y + 27), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x)

	var secs := int(float(lv.end) / float(lv.speed))
	var line := "Attempts %d     Best time %s     %ds long" % [Save.level_attempts(idx), fmt_time(Save.best_time(idx)), secs]
	_text(line, Vector2(260, 296), 21, Color(1, 1, 1, 0.75))
	if Save.is_done(idx):
		_text("COMPLETE", Vector2(w - 230, 140), 26, Color("8ee53f"), HORIZONTAL_ALIGNMENT_RIGHT, 200)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
