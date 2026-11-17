extends BaseButton
## A chunky outlined button that bounces when hovered and squashes when pressed.
## Icons are drawn with code: play, back, left, right, pause, restart, list, chart, cube, music, sound.

const FONT = preload("res://fonts/Fredoka-Bold.ttf")
const Skins = preload("res://scripts/skins.gd")
const DARK := Color(0.05, 0.03, 0.12)

var shape := "round"  # "round" or "circle"
var fill := Color("7ee04a")
var label := ""
var icon_name := ""
var font_size := 28
var crossed := false
var _tw: Tween


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(p_shape: String, p_fill: Color, p_icon: String, p_label: String, p_size: Vector2):
	shape = p_shape
	fill = p_fill
	icon_name = p_icon
	label = p_label
	custom_minimum_size = p_size
	size = p_size
	pivot_offset = p_size * 0.5
	return self


func _ready() -> void:
	resized.connect(_center_pivot)
	_center_pivot()
	mouse_entered.connect(_bounce.bind(1.08))
	mouse_exited.connect(_bounce.bind(1.0))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(_bounce.bind(0.88))
	button_up.connect(_on_up)
	pressed.connect(Audio.sfx.bind("click"))


func _center_pivot() -> void:
	pivot_offset = size * 0.5


func _on_up() -> void:
	_bounce(1.08 if is_hovered() else 1.0)


func _bounce(target: float) -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2.ONE * target, 0.18)


func _draw() -> void:
	var sz := size
	var c := sz * 0.5
	var f := fill.darkened(0.45) if disabled else fill
	if shape == "circle":
		var r := minf(sz.x, sz.y) * 0.5
		draw_circle(c + Vector2(0, 5), r, Color(0, 0, 0, 0.35))
		draw_circle(c, r, DARK)
		draw_circle(c, r - 5.0, f.darkened(0.3))
		draw_circle(c - Vector2(0, 3), r - 9.0, f)
		draw_arc(c - Vector2(0, 3), r - 16.0, PI * 1.15, PI * 1.6, 12, Color(1, 1, 1, 0.35), maxf(3.0, r * 0.07), true)
		if has_focus():
			draw_arc(c, r + 4.0, 0.0, TAU, 64, Color("5ce1ff"), 3.0, true)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = f
		sb.set_corner_radius_all(int(minf(sz.y * 0.3, 18.0)))
		sb.border_color = DARK
		sb.set_border_width_all(5)
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_offset = Vector2(0, 5)
		draw_style_box(sb, Rect2(Vector2.ZERO, sz))
		var hi := StyleBoxFlat.new()
		hi.bg_color = Color(1, 1, 1, 0.18)
		hi.set_corner_radius_all(int(minf(sz.y * 0.2, 12.0)))
		draw_style_box(hi, Rect2(8, 7, sz.x - 16, sz.y * 0.32))
		if has_focus():
			var ring := StyleBoxFlat.new()
			ring.draw_center = false
			ring.border_color = Color("5ce1ff")
			ring.set_border_width_all(3)
			ring.set_corner_radius_all(int(minf(sz.y * 0.3, 18.0)) + 4)
			ring.expand_margin_left = 5
			ring.expand_margin_right = 5
			ring.expand_margin_top = 5
			ring.expand_margin_bottom = 5
			draw_style_box(ring, Rect2(Vector2.ZERO, sz))
	var icon_c := c
	var text_x := 0.0
	if icon_name != "" and label != "":
		icon_c = Vector2(sz.y * 0.55, c.y)
		text_x = sz.y * 0.9
	if icon_name != "":
		_icon(icon_name, icon_c, minf(sz.x, sz.y) * (0.24 if label != "" else 0.27))
	if label != "":
		var w := sz.x - text_x
		var base := Vector2(text_x, c.y + font_size * 0.36)
		draw_string_outline(FONT, base, label, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, 9, DARK)
		draw_string(FONT, base, label, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, Color.WHITE)


func _shape(pts: PackedVector2Array) -> void:
	draw_polyline(Skins.closed(pts), DARK, 7.0, true)
	draw_colored_polygon(pts, Color.WHITE)


func _bar(r: Rect2) -> void:
	draw_rect(r.grow(3.0), DARK)
	draw_rect(r, Color.WHITE)


func _icon(n: String, c: Vector2, s: float) -> void:
	match n:
		"play":
			_shape(PackedVector2Array([c + Vector2(-0.55, -0.8) * s, c + Vector2(0.85, 0) * s, c + Vector2(-0.55, 0.8) * s]))
		"left", "back":
			_shape(PackedVector2Array([c + Vector2(-0.8, 0) * s, c + Vector2(0.15, -0.75) * s, c + Vector2(0.15, -0.3) * s,
				c + Vector2(0.8, -0.3) * s, c + Vector2(0.8, 0.3) * s, c + Vector2(0.15, 0.3) * s, c + Vector2(0.15, 0.75) * s]))
		"right":
			_shape(PackedVector2Array([c + Vector2(0.8, 0) * s, c + Vector2(-0.15, 0.75) * s, c + Vector2(-0.15, 0.3) * s,
				c + Vector2(-0.8, 0.3) * s, c + Vector2(-0.8, -0.3) * s, c + Vector2(-0.15, -0.3) * s, c + Vector2(-0.15, -0.75) * s]))
		"pause":
			_bar(Rect2(c + Vector2(-0.6, -0.7) * s, Vector2(0.4, 1.4) * s))
			_bar(Rect2(c + Vector2(0.2, -0.7) * s, Vector2(0.4, 1.4) * s))
		"list":
			for k in 3:
				_bar(Rect2(c + Vector2(-0.75, -0.65 + k * 0.5) * s, Vector2(1.5, 0.3) * s))
		"chart":
			var hs := [0.6, 1.1, 1.6]
			for k in 3:
				var h: float = hs[k]
				_bar(Rect2(c + Vector2(-0.8 + k * 0.6, 0.8 - h) * s, Vector2(0.4, h) * s))
		"restart":
			draw_arc(c, s * 0.62, 0.9, TAU - 0.3, 24, DARK, s * 0.42, true)
			draw_arc(c, s * 0.62, 0.9, TAU - 0.3, 24, Color.WHITE, s * 0.24, true)
			var tip := c + Vector2(cos(0.9), sin(0.9)) * s * 0.62
			_shape(PackedVector2Array([tip + Vector2(-0.45, -0.1) * s, tip + Vector2(0.4, -0.35) * s, tip + Vector2(0.15, 0.5) * s]))
		"cube":
			Skins.draw_icon(self, c, 0.0, Vector2.ONE * s / 15.0 * 0.95, Save.icon(), Save.c1(), Save.c2())
		"music":
			draw_line(c + Vector2(0.35, 0.5) * s, c + Vector2(0.35, -0.75) * s, DARK, s * 0.36)
			draw_circle(c + Vector2(0.05, 0.5) * s, s * 0.36, DARK)
			draw_line(c + Vector2(0.35, 0.5) * s, c + Vector2(0.35, -0.75) * s, Color.WHITE, s * 0.16)
			draw_circle(c + Vector2(0.05, 0.5) * s, s * 0.24, Color.WHITE)
			_shape(PackedVector2Array([c + Vector2(0.35, -0.8) * s, c + Vector2(0.85, -0.45) * s, c + Vector2(0.35, -0.3) * s]))
		"sound":
			_shape(PackedVector2Array([c + Vector2(-0.8, -0.3) * s, c + Vector2(-0.35, -0.3) * s, c + Vector2(0.15, -0.75) * s,
				c + Vector2(0.15, 0.75) * s, c + Vector2(-0.35, 0.3) * s, c + Vector2(-0.8, 0.3) * s]))
			if not crossed:
				draw_arc(c + Vector2(0.15, 0) * s, s * 0.5, -0.8, 0.8, 10, Color.WHITE, s * 0.16, true)
	if crossed:
		draw_line(c + Vector2(-0.85, -0.85) * s, c + Vector2(0.85, 0.85) * s, DARK, s * 0.4)
		draw_line(c + Vector2(-0.85, -0.85) * s, c + Vector2(0.85, 0.85) * s, Color("ff4a4a"), s * 0.2)
