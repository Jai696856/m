extends Control
## One choice in the icon kit: an icon or a colour swatch, with a lock when it is not earned yet.

const Skins = preload("res://scripts/skins.gd")
const DARK := Color(0.05, 0.03, 0.12)

var kind := "icon"  # icon, c1, c2
var idx := 0
var cb: Callable
var hover := false


func setup(p_kind: String, p_idx: int, p_cb: Callable, side: float):
	kind = p_kind
	idx = p_idx
	cb = p_cb
	custom_minimum_size = Vector2(side, side)
	return self


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _set_hover(on: bool) -> void:
	hover = on
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		cb.call(kind, idx)
		accept_event()


func locked() -> bool:
	var list: Array = Skins.ICONS if kind == "icon" else Skins.COLORS
	return not Save.unlocked(list[idx].req)


func _draw() -> void:
	var key := "icon" if kind == "icon" else kind
	var sel := int(Save.data.skin[key]) == idx
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.45)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(4)
	sb.border_color = Color.WHITE if sel else (Color(1, 1, 1, 0.35) if hover else Color(1, 1, 1, 0.08))
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var c := size * 0.5
	if kind == "icon":
		Skins.draw_icon(self, c, 0.0, Vector2.ONE * size.x / 30.0 * 0.6, idx, Save.c1(), Save.c2())
	else:
		draw_circle(c, size.x * 0.32, DARK)
		draw_circle(c, size.x * 0.32 - 3.0, Color(Skins.COLORS[idx].hex))
	if locked():
		draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(0.02, 0.01, 0.06, 0.7))
		var s := size.x * 0.16
		draw_arc(c - Vector2(0, s * 0.3), s * 0.75, PI, TAU, 12, Color(1, 1, 1, 0.85), s * 0.32, true)
		draw_rect(Rect2(c + Vector2(-s, -s * 0.25), Vector2(s * 2.0, s * 1.6)), Color(1, 1, 1, 0.85))
		draw_circle(c + Vector2(0, s * 0.5), s * 0.25, DARK)
