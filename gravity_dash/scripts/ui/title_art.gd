extends Control

const FONT = preload("res://fonts/Fredoka-Bold.ttf")
const DARK:= Color(0.05, 0.03, 0.12)

var t:= 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var fs:= 108
	var mid:= size.y * 0.5 + 4.0
	_word("GRAVITY", mid - 4.0, fs, Color("ffd34d"), Color("ff8a3d"), false)
	_word("DASH", mid + 10.0, fs, Color("5ce1ff"), Color("4d7bff"), true)

func _word(w: String, line_y: float, fs: int, ca: Color, cb: Color, flip: bool) -> void:
	var widths: Array = []
	var total:= 0.0
	for ch in w:
		var cw:= FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 2.0
		widths.append(cw)
		total += cw
	var x:= size.x * 0.5 - total * 0.5
	for i in w.length():
		var bob:= sin(t * 2.6 + i * 0.55) * 5.0
		var col:= ca.lerp(cb, float(i) / maxf(1.0, w.length() - 1.0))
		draw_set_transform(Vector2(x, line_y + bob), 0.0, Vector2(1, -1) if flip else Vector2.ONE)
		draw_string_outline(FONT, Vector2.ZERO, w[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 24, DARK)
		draw_string(FONT, Vector2.ZERO, w[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		x += widths[i]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
