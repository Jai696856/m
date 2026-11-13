# All 2D interface, built from code: HUD, hero shop, upgrade panel, boss bar,
# banners, and the start / game-over screens.
extends CanvasLayer

const Defs = preload("res://scripts/defs.gd")
const Models = preload("res://scripts/models.gd")
const Maps = preload("res://scripts/maps.gd")
const Icons = preload("res://scripts/icons.gd")
const LevelScript = preload("res://scripts/level/level.gd")
const GameModes := ["standard", "half_cash", "fortified", "deflation", "rush", "one_class", "boss_rush", "sandbox"]

# Palette: deep navy surfaces, soft accents, one ink colour for text shadows.
const INK := Color(0.06, 0.08, 0.16)
const NAVY := Color(0.075, 0.1, 0.19, 0.94)
const SURFACE := Color(0.13, 0.165, 0.29)
const TILE := Color(0.15, 0.19, 0.33)
const CARD := Color(0.13, 0.165, 0.29)
const TEXT := Color(0.93, 0.95, 1.0)
const MUTED := Color(0.62, 0.68, 0.82)
const BLUE := Color(0.29, 0.5, 0.95)
const PINK := Color(1.0, 0.4, 0.62)
const GREEN := Color(0.2, 0.78, 0.5)
const GOLD := Color(1.0, 0.78, 0.26)
const ORANGE := Color(1.0, 0.56, 0.24)
const VIOLET := Color(0.55, 0.44, 1.0)
const RED := Color(0.94, 0.33, 0.38)
const GREY := Color(0.33, 0.37, 0.5)
const CASH := Color(1.0, 0.82, 0.3)

# An icon from the shared set (scripts/icons.gd), tinted, with a soft drop shadow.
class HudIcon extends Control:
	const IconSet = preload("res://scripts/icons.gd")
	var kind := "heart"
	var col := Color.WHITE
	var shadow := true

	func _init(k: String, px: float, c: Color) -> void:
		kind = k
		col = c
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_kind(k: String) -> void:
		kind = k
		queue_redraw()

	func _draw() -> void:
		var px := int(clampf(maxf(size.x, size.y) * 2.0, 32.0, 256.0))
		var t: Texture2D = IconSet.tex(kind, Color.WHITE, px)
		if shadow:
			draw_texture_rect(t, Rect2(Vector2(0, size.y * 0.07), size), false, Color(0.05, 0.07, 0.15, 0.35))
		draw_texture_rect(t, Rect2(Vector2.ZERO, size), false, col)

# Minimap preview of a map's track, drawn from its route.
class MapThumb extends Control:
	var map: Dictionary
	var theme_cols: Dictionary

	func _init(m: Dictionary, t: Dictionary) -> void:
		map = m
		theme_cols = t
		custom_minimum_size = Vector2(190, 92)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _c(hex: int) -> Color:
		return Color.hex((hex << 8) | 0xff)

	func _draw() -> void:
		var s := size
		var ink := Color(0.12, 0.08, 0.16)
		draw_rect(Rect2(Vector2.ZERO, s), _c(theme_cols["grass"]))
		var cw := s.x / 17.0
		var ch := s.y / 11.0
		var sea := _c(theme_cols["sea"])
		var sand := _c(theme_cols["sand"])
		match map.get("shore", "none"):
			"left":
				draw_rect(Rect2(0, 0, cw * 0.9, s.y), sea)
				draw_rect(Rect2(cw * 0.9, 0, cw * 0.35, s.y), sand)
			"top":
				draw_rect(Rect2(0, 0, s.x, ch * 0.7), sea)
				draw_rect(Rect2(0, ch * 0.7, s.x, ch * 0.3), sand)
			"bottom":
				draw_rect(Rect2(0, s.y - ch * 0.7, s.x, ch * 0.7), sea)
				draw_rect(Rect2(0, s.y - ch, s.x, ch * 0.3), sand)
		var tint: Array = theme_cols["stone"]
		var stone := Color(0.75 * tint[0], 0.74 * tint[1], 0.71 * tint[2])
		var route: Array = map["route"]
		var cells: Array = [route[0]]
		for i in range(1, route.size()):
			var a: Vector2i = route[i - 1]
			var b: Vector2i = route[i]
			var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
			var c := a
			while c != b:
				c += step
				cells.append(c)
		for c in cells:
			draw_rect(Rect2((c.x + 1) * cw - 0.5, (c.y + 1) * ch - 0.5, cw + 1.0, ch + 1.0), stone)
		var first: Vector2i = cells[1]
		var last: Vector2i = cells[cells.size() - 2]
		draw_circle(Vector2((first.x + 1.5) * cw, (first.y + 1.5) * ch), minf(cw, ch) * 0.45, Color(0.6, 0.35, 1.0))
		draw_rect(Rect2((last.x + 1.2) * cw, (last.y + 1.2) * ch, cw * 0.6, ch * 0.6), Color(0.9, 0.25, 0.25))
		draw_rect(Rect2(Vector2.ZERO, s), ink, false, 2.0)

var game
var cash_dirty := true
var font: Font
var font_bold: Font

var root: Control
var lives_lbl: Label
var cash_lbl: Label
var round_box: Control
var round_lbl: Label
var shop: PanelContainer
var shop_scroll: ScrollContainer
var shop_grid: GridContainer
var shop_title: Label
var shop_buttons := {}
var play_btn: Button
var play_icon: HudIcon
var speed_lbl: Label
var auto_btn: Button
var mute_btn: Button
var panel: PanelContainer
var panel_box: VBoxContainer
var pops_lbl: Label
var buy_buttons: Array = []
var boss_box: VBoxContainer
var boss_lbl: Label
var boss_bar: ProgressBar
var banner_box: VBoxContainer
var banner_lbl: Label
var banner_sub: Label
var banner_tween: Tween
var start_screen: Control
var end_screen: Control
var end_title: Label
var end_text: Label
var freeplay_btn: Button
var diff := "normal"
var sel_mode := "standard"
var sel_map := 0
var sel_tier := "beginner"
var menu_card: PanelContainer
var map_grid: GridContainer
var map_cards := {}
var tier_buttons := {}
var mode_buttons := {}
var sel_lbl: Label
var mode_lbl: Label
var medal_lbl: Label
const GEM := Color(0.45, 0.9, 1.0)
var pause_screen: Control
var ability_bar: HBoxContainer
var ability_buttons: Array = []
var power_bar: VBoxContainer
var power_buttons: Array = []
var map_info_lbl: Label
var hud_box: HBoxContainer
var controls_box: HBoxContainer
var next_box: HBoxContainer
var sandbox_panel: PanelContainer
var sb_camo := false
var sb_fort := false
var sb_regrow := false
var sb_toggles := {}
var toast_box: VBoxContainer
var pause_btn: Button
var cancel_btn: Button
var shop_class := 0
var class_tabs: Array = []
var class_lbl: Label
var diff_buttons := {}
var portraits := {}
var portrait_vps: Array = []
var ui_timer := 0.0
var portrait := false

func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	font = load("res://fonts/Fredoka-SemiBold.ttf") as Font
	font_bold = load("res://fonts/Fredoka-Bold.ttf") as Font
	if font:
		theme.default_font = font
	theme.default_font_size = 18
	# Tooltips match the panels
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(0.05, 0.07, 0.14, 0.96)
	tip.set_corner_radius_all(8)
	tip.set_content_margin_all(8)
	theme.set_stylebox("panel", "TooltipPanel", tip)
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_font_size("font_size", "TooltipLabel", 14)
	root.theme = theme
	add_child(root)
	for k in Defs.HERO_ORDER:
		portraits[k] = _make_portrait(k)
	get_tree().create_timer(1.5).timeout.connect(_freeze_portraits)
	_build_hud()
	_build_shop()
	_build_controls()
	_build_panel()
	_build_boss()
	_build_banner()
	_build_abilities()
	_build_powers()
	_build_start()
	_build_end()
	_build_pause()
	_build_sandbox()
	_build_toasts()
	get_viewport().size_changed.connect(_layout)
	_layout()
	update_hud()

# ---------------------------------------------------------------------
# Style helpers
# ---------------------------------------------------------------------
## Flat rounded surface with a hairline edge and a soft shadow.
func sb(bg: Color, radius: int = 14, border: int = 3, shadow: bool = true, margin: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = Color(1, 1, 1, 0.1) if bg.get_luminance() < 0.5 else Color(0, 0, 0, 0.12)
	s.set_border_width_all(mini(border, 2) if border < 4 else 3)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.anti_aliasing_size = 1.2
	if shadow:
		s.shadow_color = Color(0.02, 0.03, 0.08, 0.28)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 3)
	return s

## Button face: flat colour with a darker lip along the bottom.
func bsb(bg: Color, radius: int = 12, lip: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = bg.darkened(0.28)
	s.border_width_bottom = lip
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(8)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.anti_aliasing_size = 1.2
	s.shadow_color = Color(0.02, 0.03, 0.08, 0.22)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0, 2)
	return s

# Clean rounded text. `outline` is the old chunky outline width; it now maps to a thin
# dark edge that keeps text readable over the 3D scene (0 = none, for text on panels).
func lbl(text: String, size: int = 16, color: Color = Color.WHITE, outline: int = 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if size >= 24 and font_bold:
		l.add_theme_font_override("font", font_bold)
	if outline > 0:
		l.add_theme_constant_override("outline_size", clampi(int(round(outline * 0.5)), 2, 5))
		l.add_theme_color_override("font_outline_color", Color(INK, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Secondary text on a panel (the name is historical: panels used to be light).
func dark_lbl(text: String, size: int = 14) -> Label:
	return lbl(text, size, TEXT, 0)

func btn(text: String, bg: Color, size: int = 20, radius: int = 12) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_constant_override("outline_size", 3)
	b.add_theme_color_override("font_outline_color", Color(INK, 0.45))
	b.add_theme_constant_override("h_separation", 8)
	_set_btn_bg(b, bg, radius)
	var dis := bsb(GREY.darkened(0.15), radius)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.72, 0.75, 0.85))
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("icon_disabled_color", Color(0.72, 0.75, 0.85))
	return b

func _set_btn_bg(b: Button, bg: Color, radius: int = 12) -> void:
	b.add_theme_stylebox_override("normal", bsb(bg, radius))
	b.add_theme_stylebox_override("hover", bsb(bg.lightened(0.1), radius))
	var pressed := bsb(bg.darkened(0.1), radius, 1)
	pressed.content_margin_top = 10
	b.add_theme_stylebox_override("pressed", pressed)

func round_btn(bg: Color, px: int) -> Button:
	var b := btn("", bg, 16, px / 2)
	b.custom_minimum_size = Vector2(px, px)
	return b

func centered(parent: Control, child: Control) -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(child)
	parent.add_child(cc)

func panel_of(bg: Color = NAVY, radius: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, radius, 2, true, 12))
	return p

# ---------------------------------------------------------------------
# Portraits: each hero rendered once in its own little 3D world
# ---------------------------------------------------------------------
func _make_portrait(k: String) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(160, 160)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.97, 0.95)
	env.ambient_light_energy = 0.8
	we.environment = env
	vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	light.light_energy = 1.1
	vp.add_child(light)
	var m: Dictionary = Models.build_hero(k)
	(m["body"] as Node3D).rotation.y = 0.35
	vp.add_child(m["root"])
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.position = Vector3(0.9, 2.15, 5.0)
	cam.look_at(Vector3(0, 1.47, 0), Vector3.UP)
	cam.make_current()
	portrait_vps.append(vp)
	return vp.get_texture()

## A spirit rendered once into a small texture (used by the Almanac).
var spirit_portraits := {}

func spirit_portrait(k: String) -> Texture2D:
	if spirit_portraits.has(k):
		return spirit_portraits[k]
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.97, 0.95)
	env.ambient_light_energy = 0.8
	we.environment = env
	vp.add_child(we)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	light.light_energy = 1.1
	vp.add_child(light)
	var node: Node3D = Models.build_enemy(k, false, game.rainbow_mat, game.rainbow_camo)
	node.rotation.y = 0.5
	vp.add_child(node)
	var s: float = float(Defs.ENEMIES[k]["size"])
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	cam.position = Vector3(0.0, s * 0.6, s * 6.2)
	cam.look_at(Vector3(0, s * 0.1, 0), Vector3.UP)
	cam.make_current()
	spirit_portraits[k] = vp.get_texture()
	return spirit_portraits[k]

func _freeze_portraits() -> void:
	# Portraits never change, so stop re-rendering them every frame.
	for vp in portrait_vps:
		(vp as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED

func _portrait_rect(k: String, px: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = portraits[k]
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

# ---------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------
func _build_hud() -> void:
	var hud := HBoxContainer.new()
	hud_box = hud
	hud.add_theme_constant_override("separation", 18)
	hud.position = Vector2(14, 10)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	hud.add_theme_constant_override("separation", 10)
	for which in ["lives", "cash"]:
		var pill := PanelContainer.new()
		var st := sb(Color(NAVY, 0.88), 22, 2, true, 6)
		st.content_margin_left = 12
		st.content_margin_right = 16
		pill.add_theme_stylebox_override("panel", st)
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(pill)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.add_child(h)
		if which == "lives":
			h.add_child(HudIcon.new("heart", 28, Color(1, 0.35, 0.45)))
			lives_lbl = lbl("150", 28, Color.WHITE, 0)
			h.add_child(lives_lbl)
		else:
			h.add_child(HudIcon.new("coin", 28, CASH))
			cash_lbl = lbl("650", 28, Color.WHITE, 0)
			h.add_child(cash_lbl)

	var rp := PanelContainer.new()
	var rst := sb(Color(NAVY, 0.88), 16, 2, true, 8)
	rst.content_margin_left = 14
	rst.content_margin_right = 14
	rp.add_theme_stylebox_override("panel", rst)
	round_box = rp
	rp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rp.anchor_left = 1.0
	rp.anchor_right = 1.0
	rp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	rp.offset_top = 8
	root.add_child(rp)
	var rv := VBoxContainer.new()
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.add_theme_constant_override("separation", 0)
	rp.add_child(rv)
	var rh := HBoxContainer.new()
	rh.alignment = BoxContainer.ALIGNMENT_END
	rh.add_theme_constant_override("separation", 8)
	rh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.add_child(rh)
	var cap := lbl("ROUND", 15, MUTED, 0)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rh.add_child(cap)
	round_lbl = lbl("0/40", 28, Color.WHITE, 0)
	rh.add_child(round_lbl)
	map_info_lbl = lbl("", 12, MUTED, 0)
	map_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(map_info_lbl)
	# Next-round preview: coloured dots with counts
	next_box = HBoxContainer.new()
	next_box.alignment = BoxContainer.ALIGNMENT_END
	next_box.add_theme_constant_override("separation", 4)
	next_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rv.add_child(next_box)

func _build_shop() -> void:
	shop = panel_of(NAVY)
	root.add_child(shop)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	shop.add_child(v)
	shop_title = lbl("HEROES", 26, GOLD, 10)
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(shop_title)
	# Class tabs: five classes of three heroes
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tabs)
	for i in range(Defs.CLASSES.size()):
		var c: Dictionary = Defs.CLASSES[i]
		var tb := btn(str(i + 1), Defs.col(c["color"]).darkened(0.25), 14, 8)
		tb.custom_minimum_size = Vector2(34 if Defs.CLASSES.size() <= 5 else 28, 30)
		tb.text = ""
		tb.icon = Icons.tex(Icons.CLASS_ICONS.get(c["id"], "star"), Color.WHITE, 40)
		tb.add_theme_constant_override("icon_max_width", 20 if Defs.CLASSES.size() <= 5 else 15)
		tb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.tooltip_text = "%s (key %d)" % [c["name"], i + 1]
		tb.pressed.connect(select_class.bind(i))
		tabs.add_child(tb)
		class_tabs.append(tb)
	class_lbl = lbl("", 16, Color.WHITE, 6)
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(class_lbl)
	shop_scroll = ScrollContainer.new()
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(shop_scroll)
	shop_grid = GridContainer.new()
	shop_grid.columns = 2
	shop_grid.add_theme_constant_override("h_separation", 6)
	shop_grid.add_theme_constant_override("v_separation", 6)
	shop_scroll.add_child(shop_grid)
	var hint_text := "1-5: class  Z-B: hero\nSpace: play  Drag: rotate"
	if DisplayServer.is_touchscreen_available():
		hint_text = "Tap a hero, then tap grass\nDrag: rotate  Pinch: zoom"
	var hint := lbl(hint_text, 11, Color(0.8, 0.88, 1.0), 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.name = "Hint"
	v.add_child(hint)
	rebuild_shop()

func rebuild_shop() -> void:
	for c in shop_grid.get_children():
		c.queue_free()
	shop_buttons.clear()
	var i := 0
	var cls: Dictionary = Defs.CLASSES[shop_class]
	class_lbl.text = cls["name"]
	for j in range(class_tabs.size()):
		var col: Color = Defs.col(Defs.CLASSES[j]["color"])
		_set_btn_bg(class_tabs[j], col if j == shop_class else col.darkened(0.45), 8)
	for k in cls["heroes"]:
		var h: Dictionary = Defs.HEROES[k]
		var b := btn("", TILE, 14, 10)
		b.custom_minimum_size = Vector2(96, 116)
		b.tooltip_text = "%s - %s\n%s" % [h["name"], h["role"], h["desc"]]
		var key: String = k
		b.pressed.connect(func() -> void: game.begin_placing(key))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 3
		v.offset_right = -3
		v.offset_top = 2
		v.offset_bottom = -3
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", -4)
		b.add_child(v)
		var pic := _portrait_rect(k, 84)
		pic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(pic)
		var cost := lbl("$%d" % game.hero_price(k), 20, CASH, 8)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cost)
		var num := lbl(["Z", "X", "C", "V", "B"][i] if i < 5 else "", 13, Color.WHITE, 6)
		num.position = Vector2(6, 2)
		b.add_child(num)
		if game.class_blocked(k):
			cost.text = "CLOSED"
			cost.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
			pic.modulate = Color(0.25, 0.25, 0.35)
			b.tooltip_text = "One Class mode: only %s heroes can join" % Defs.hero_class(game.heroes[0].key)["name"]
		elif not game.hero_available(k):
			# Locked until the player reaches the hero's level
			cost.text = "LV %d" % int(Defs.UNLOCK_LEVEL[k])
			cost.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
			pic.modulate = Color(0.25, 0.25, 0.35)
			b.tooltip_text = "%s - %s\nJoins at player level %d" % [h["name"], h["role"], int(Defs.UNLOCK_LEVEL[k])]
		shop_grid.add_child(b)
		shop_buttons[k] = b
		i += 1
	refresh()

## Keep the UI clear of notches, rounded corners and the home indicator on iOS/Android.
func _apply_safe_area() -> void:
	if not (OS.has_feature("mobile") or OS.get_name() in ["iOS", "Android"]):
		return
	var win := get_window()
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0:
		return
	var view := root.get_viewport_rect().size
	var k := Vector2(view.x / maxf(1.0, win.size.x), view.y / maxf(1.0, win.size.y))
	var left := clampf(safe.position.x * k.x, 0.0, 80.0)
	var top := clampf(safe.position.y * k.y, 0.0, 80.0)
	var right := clampf((screen.x - safe.end.x) * k.x, 0.0, 80.0)
	var bottom := clampf((screen.y - safe.end.y) * k.y, 0.0, 80.0)
	root.offset_left = left
	root.offset_top = top
	root.offset_right = -right
	root.offset_bottom = -bottom

func select_class(i: int) -> void:
	shop_class = clampi(i, 0, Defs.CLASSES.size() - 1)
	rebuild_shop()

func _build_controls() -> void:
	var h := HBoxContainer.new()
	controls_box = h
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(h)
	# Touch-friendly buttons: cancel placement (instead of right-click) and pause (instead of Esc)
	cancel_btn = round_btn(RED, 58)
	cancel_btn.text = "X"
	cancel_btn.add_theme_font_size_override("font_size", 26)
	cancel_btn.tooltip_text = "Cancel placing"
	cancel_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	cancel_btn.visible = false
	cancel_btn.pressed.connect(func() -> void: game.cancel_placing())
	h.add_child(cancel_btn)
	pause_btn = round_btn(BLUE, 58)
	pause_btn.text = "II"
	pause_btn.add_theme_font_size_override("font_size", 22)
	pause_btn.tooltip_text = "Pause"
	pause_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	pause_btn.pressed.connect(func() -> void: game.toggle_pause())
	h.add_child(pause_btn)
	mute_btn = round_btn(BLUE, 58)
	mute_btn.text = "SFX"
	mute_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	mute_btn.pressed.connect(func() -> void: game.toggle_mute())
	h.add_child(mute_btn)
	auto_btn = round_btn(BLUE, 58)
	auto_btn.text = "AUTO"
	auto_btn.add_theme_font_size_override("font_size", 14)
	auto_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	auto_btn.pressed.connect(func() -> void: game.toggle_auto())
	h.add_child(auto_btn)
	play_btn = round_btn(GREEN, 86)
	play_btn.pressed.connect(func() -> void: game.on_play())
	play_icon = HudIcon.new("play", 64, Color.WHITE)
	centered(play_btn, play_icon)
	speed_lbl = lbl("", 16, Color.WHITE, 6)
	speed_lbl.position = Vector2(56, 58)
	play_btn.add_child(speed_lbl)
	h.add_child(play_btn)
	h.anchor_left = 1.0
	h.anchor_right = 1.0
	h.anchor_top = 1.0
	h.anchor_bottom = 1.0
	h.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	h.grow_vertical = Control.GROW_DIRECTION_BEGIN
	h.offset_right = -14
	h.offset_bottom = -12

func _build_panel() -> void:
	panel = panel_of(NAVY)
	panel.visible = false
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 12
	panel.offset_bottom = -12
	root.add_child(panel)
	panel_box = VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 8)
	panel.add_child(panel_box)

func _build_boss() -> void:
	boss_box = VBoxContainer.new()
	boss_box.visible = false
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.anchor_left = 0.5
	boss_box.anchor_right = 0.5
	boss_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_box.offset_top = 14
	boss_box.custom_minimum_size = Vector2(440, 0)
	root.add_child(boss_box)
	boss_lbl = lbl("ONI LORD", 22, Color.WHITE, 10)
	boss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_lbl)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(440, 22)
	boss_bar.show_percentage = false
	boss_bar.add_theme_stylebox_override("background", sb(Color(0.2, 0.12, 0.28), 11, 3, false, 0))
	boss_bar.add_theme_stylebox_override("fill", sb(Color(0.62, 0.3, 1.0), 11, 3, false, 0))
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.add_child(boss_bar)

func _build_banner() -> void:
	banner_box = VBoxContainer.new()
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.anchor_left = 0.0
	banner_box.anchor_right = 1.0
	banner_box.anchor_top = 0.3
	banner_box.anchor_bottom = 0.3
	banner_box.modulate.a = 0.0
	root.add_child(banner_box)
	banner_lbl = lbl("", 84, Color.WHITE, 22)
	banner_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	banner_lbl.add_theme_constant_override("shadow_offset_y", 8)
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner_lbl)
	banner_sub = lbl("", 30, GOLD, 12)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner_sub)

func _overlay() -> Dictionary:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.12, 0.62)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var card := panel_of(NAVY, 26)
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	return {"shade": shade, "box": v, "card": card}

func _title(v: VBoxContainer, a: String, b: String) -> Label:
	var t1 := lbl(a, 64, Color.WHITE, 0)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)
	if b != "":
		var t2 := lbl(b, 30, GOLD, 0)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t2)
	return t1

func _build_start() -> void:
	var o := _overlay()
	start_screen = o["shade"]
	menu_card = o["card"]
	var v: VBoxContainer = o["box"]
	v.add_theme_constant_override("separation", 8)
	var t1 := lbl("CHOOSE A MAP", 40, Color.WHITE, 0)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)
	# Tier tabs + medal count
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t in Maps.TIERS:
		var key: String = t
		var b := btn(key.to_upper(), BLUE, 18)
		b.custom_minimum_size = Vector2(150, 40)
		b.pressed.connect(func() -> void: _pick_tier(key))
		tabs.add_child(b)
		tier_buttons[key] = b
	medal_lbl = lbl("", 16, GOLD, 6)
	tabs.add_child(medal_lbl)
	# Map grid
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	map_grid = GridContainer.new()
	map_grid.columns = 5
	map_grid.add_theme_constant_override("h_separation", 8)
	map_grid.add_theme_constant_override("v_separation", 8)
	map_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(map_grid)
	# Selected map, difficulty, mode
	sel_lbl = lbl("", 26, Color.WHITE, 10)
	sel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sel_lbl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for d in [["easy", "EASY"], ["normal", "NORMAL"], ["hard", "HARD"], ["nightmare", "NIGHTMARE"]]:
		var key: String = d[0]
		var b := btn(d[1], TILE, 16)
		b.custom_minimum_size = Vector2(100, 40)
		if key == "nightmare":
			b.tooltip_text = "One life and 20% higher prices. For true guardians."
		b.pressed.connect(func() -> void: _pick_diff(key))
		row.add_child(b)
		diff_buttons[key] = b
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 5)
	v.add_child(mode_row)
	for m in GameModes:
		var key2: String = m
		var b2 := btn(String(game.MODES[key2]["name"]).to_upper(), TILE, 14)
		b2.custom_minimum_size = Vector2(0, 40)
		b2.tooltip_text = game.MODES[key2]["desc"]
		b2.icon = Icons.tex(Icons.MODE_ICONS.get(key2, "star"), Color.WHITE, 40)
		b2.add_theme_constant_override("icon_max_width", 18)
		b2.pressed.connect(func() -> void: _pick_mode(key2))
		mode_row.add_child(b2)
		mode_buttons[key2] = b2
	mode_lbl = lbl("", 14, Color(0.8, 0.9, 1.0), 0)
	mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(mode_lbl)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 14)
	v.add_child(bottom)
	var back := btn("BACK", BLUE, 26, 18)
	back.custom_minimum_size = Vector2(150, 58)
	back.pressed.connect(_on_back_home)
	bottom.add_child(back)
	var start := btn("START!", GREEN, 34, 18)
	start.custom_minimum_size = Vector2(220, 58)
	start.pressed.connect(_on_start)
	bottom.add_child(start)
	sel_map = game.map_index
	_pick_diff("normal")
	_pick_mode("standard")
	_pick_tier(String(Maps.MAPS[sel_map]["tier"]))

func _pick_tier(t: String) -> void:
	sel_tier = t
	for key in tier_buttons:
		_set_btn_bg(tier_buttons[key], PINK if key == t else BLUE)
	for c in map_grid.get_children():
		c.queue_free()
	map_cards.clear()
	for i in range(Maps.MAPS.size()):
		var m: Dictionary = Maps.MAPS[i]
		if m["tier"] != t:
			continue
		var card := btn("", TILE, 14, 10)
		card.custom_minimum_size = Vector2(206, 150)
		var idx: int = i
		card.pressed.connect(func() -> void: _pick_map(idx))
		var cv := VBoxContainer.new()
		cv.set_anchors_preset(Control.PRESET_FULL_RECT)
		cv.offset_left = 6
		cv.offset_right = -6
		cv.offset_top = 5
		cv.offset_bottom = -4
		cv.add_theme_constant_override("separation", 2)
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cv)
		var thumb := MapThumb.new(m, LevelScript.THEMES[m["theme"]])
		thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(thumb)
		var nm := lbl(m["name"], 15, Color.WHITE, 6)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(nm)
		var medals := HBoxContainer.new()
		medals.alignment = BoxContainer.ALIGNMENT_CENTER
		medals.add_theme_constant_override("separation", 4)
		medals.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(medals)
		var medal_cols := {"easy": Color(0.8, 0.5, 0.25), "normal": Color(0.8, 0.82, 0.86), "hard": Color(1.0, 0.8, 0.2), "nightmare": Color(0.75, 0.35, 1.0)}
		for d in ["easy", "normal", "hard", "nightmare"]:
			var won := false
			for mode in GameModes:
				if game.has_medal(i, d, mode):
					won = true
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2(16, 16)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dot.add_theme_stylebox_override("panel", sb(medal_cols[d] if won else Color(0.25, 0.3, 0.4), 8, 2, false, 0))
			medals.add_child(dot)
		map_grid.add_child(card)
		map_cards[i] = card
	_refresh_menu()

func _pick_map(i: int) -> void:
	sel_map = i
	_refresh_menu()

func _pick_diff(k: String) -> void:
	diff = k
	for key in diff_buttons:
		_set_btn_bg(diff_buttons[key], PINK if key == k else BLUE)
	_refresh_menu()

func _pick_mode(k: String) -> void:
	sel_mode = k
	for key in mode_buttons:
		_set_btn_bg(mode_buttons[key], PINK if key == k else BLUE)
	_refresh_menu()

func _refresh_menu() -> void:
	if sel_lbl == null:
		return
	for i in map_cards:
		_set_btn_bg(map_cards[i], GOLD if i == sel_map else TILE, 10)
	var m: Dictionary = Maps.MAPS[sel_map]
	var best: int = game.best_round(sel_map, diff, sel_mode)
	sel_lbl.text = "%s  -  %s  -  %s%s" % [String(m["name"]).to_upper(), String(m["tier"]).to_upper(), String(m["theme"]).to_upper(), ("  -  BEST ROUND %d" % best) if best > 0 else ""]
	if mode_lbl and game.MODES.has(sel_mode):
		mode_lbl.text = game.MODES[sel_mode]["desc"]
	var total := 0
	for i in range(Maps.MAPS.size()):
		for d in ["easy", "normal", "hard", "nightmare"]:
			if game.has_medal(i, d, "standard"):
				total += 1
	if medal_lbl:
		medal_lbl.text = "  MEDALS %d/%d" % [total, Maps.MAPS.size() * 4]

func show_menu() -> void:
	end_screen.visible = false
	pause_screen.visible = false
	_pick_tier(sel_tier)
	start_screen.visible = true

func _build_end() -> void:
	var o := _overlay()
	end_screen = o["shade"]
	end_screen.visible = false
	var v: VBoxContainer = o["box"]
	end_title = _title(v, "GAME OVER", "")
	end_text = lbl("", 18, Color.WHITE, 6)
	end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(end_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	freeplay_btn = btn("FREEPLAY", GOLD, 28, 16)
	freeplay_btn.pressed.connect(_on_freeplay)
	row.add_child(freeplay_btn)
	var again := btn("RETRY", GREEN, 28, 16)
	again.pressed.connect(_on_retry)
	row.add_child(again)
	var maps_btn := btn("MAPS", BLUE, 28, 16)
	maps_btn.pressed.connect(_on_maps)
	row.add_child(maps_btn)
	var home_btn := btn("HOME", BLUE, 28, 16)
	home_btn.pressed.connect(_on_home)
	row.add_child(home_btn)

func _build_pause() -> void:
	var o := _overlay()
	pause_screen = o["shade"]
	pause_screen.visible = false
	var v: VBoxContainer = o["box"]
	_title(v, "PAUSED", "")
	for item in [["RESUME", GREEN, "_on_resume"], ["RESTART", GOLD, "_on_retry"], ["MAPS", BLUE, "_on_maps"], ["HOME", BLUE, "_on_home"], ["SOUND ON / OFF", BLUE, "_on_sound"]]:
		var b := btn(item[0], item[1], 26, 16)
		b.custom_minimum_size = Vector2(300, 54)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(Callable(self, item[2]))
		v.add_child(b)

func show_pause(on: bool) -> void:
	pause_screen.visible = on

func _on_start() -> void:
	start_screen.visible = false
	game.new_game(diff, sel_map, sel_mode)

func _on_freeplay() -> void:
	end_screen.visible = false
	game.continue_freeplay()

func _on_retry() -> void:
	end_screen.visible = false
	game.restart()

func _on_maps() -> void:
	game.to_menu()

func _on_home() -> void:
	end_screen.visible = false
	game.to_home()

func _on_back_home() -> void:
	start_screen.visible = false
	game.menu.show_home()

## Map select over the menu demo.
func show_map_select() -> void:
	game.menu.visible = false
	end_screen.visible = false
	pause_screen.visible = false
	_pick_tier(sel_tier)
	start_screen.visible = true

func set_hud_visible(on: bool) -> void:
	for c in [hud_box, round_box, shop, controls_box, ability_bar]:
		(c as Control).visible = on
	power_bar.visible = on and game.mode != "sandbox"
	if not on:
		panel.visible = false
		boss_box.visible = false
		if sandbox_panel:
			sandbox_panel.visible = false

# ---------------------------------------------------------------------
# Next-round preview
# ---------------------------------------------------------------------
func update_next_round() -> void:
	for c in next_box.get_children():
		c.queue_free()
	if game.attract or game.over:
		return
	var nxt: int = game.round_num + 1
	next_box.add_child(lbl("NEXT", 12, MUTED, 0))
	var list: Array = game.preview_round(nxt)
	for i in range(mini(list.size(), 5)):
		var type: String = list[i][0]
		var d: Dictionary = Defs.ENEMIES[type]
		var dot := Panel.new()
		var px := 18 if d.get("boss", false) else 13
		dot.custom_minimum_size = Vector2(px, px)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var col: Color = Color(1, 0.6, 0.9) if d.get("rainbow", false) else Defs.col(d["color"])
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", sb(col, px / 2, 0, false, 0))
		dot.tooltip_text = d["name"]
		next_box.add_child(dot)
		next_box.add_child(lbl("%d" % int(list[i][1]), 13, TEXT, 0))

# ---------------------------------------------------------------------
# Sandbox panel: spawn any spirit with any modifier
# ---------------------------------------------------------------------
func _build_sandbox() -> void:
	sandbox_panel = panel_of(NAVY, 14)
	sandbox_panel.visible = false
	sandbox_panel.position = Vector2(12, 64)
	root.add_child(sandbox_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	sandbox_panel.add_child(v)
	v.add_child(lbl("SANDBOX", 18, GOLD, 6))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for k in Defs.ORDER:
		var key: String = k
		var d: Dictionary = Defs.ENEMIES[key]
		var col: Color = Color(1, 0.6, 0.9) if d.get("rainbow", false) else Defs.col(d["color"])
		var b := btn({"crane": "CRANE", "shogun": "SHOGUN"}.get(key, String(d["name"]).split(" ")[0].to_upper()), col.darkened(0.15), 12, 8)
		b.custom_minimum_size = Vector2(70, 30)
		b.tooltip_text = "Spawn a %s" % d["name"]
		b.pressed.connect(func() -> void: game.sandbox_spawn(key, sb_camo, sb_fort, sb_regrow))
		grid.add_child(b)
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 4)
	v.add_child(toggles)
	for t in ["camo", "fort", "regrow"]:
		var key2: String = t
		var tb := btn({"camo": "VEILED", "fort": "FORTIFIED", "regrow": "REGROW"}[key2], BLUE, 11, 8)
		tb.custom_minimum_size = Vector2(70, 28)
		tb.pressed.connect(_toggle_sandbox.bind(key2))
		toggles.add_child(tb)
		sb_toggles[key2] = tb
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	v.add_child(row)
	var clear := btn("CLEAR", RED, 12, 8)
	clear.custom_minimum_size = Vector2(70, 28)
	clear.pressed.connect(func() -> void: game.sandbox_clear())
	row.add_child(clear)
	var skip := btn("ROUND +5", GOLD, 12, 8)
	skip.custom_minimum_size = Vector2(144, 28)
	skip.pressed.connect(func() -> void:
		game.round_num += 5
		update_hud()
		update_next_round())
	row.add_child(skip)

func _toggle_sandbox(key: String) -> void:
	match key:
		"camo":
			sb_camo = not sb_camo
		"fort":
			sb_fort = not sb_fort
		"regrow":
			sb_regrow = not sb_regrow
	var on: bool = {"camo": sb_camo, "fort": sb_fort, "regrow": sb_regrow}[key]
	_set_btn_bg(sb_toggles[key], PINK if on else BLUE, 8)

func show_sandbox(on: bool) -> void:
	sandbox_panel.visible = on

# ---------------------------------------------------------------------
# Toasts: achievements and level-ups slide in at the top
# ---------------------------------------------------------------------
func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.offset_top = 64
	toast_box.add_theme_constant_override("separation", 6)
	root.add_child(toast_box)

func toast(title: String, text: String) -> void:
	var p := panel_of(Color(0.075, 0.1, 0.19, 0.96), 14)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(340, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	var t := lbl(title, 16, GOLD, 6)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := lbl(text, 22, Color.WHITE, 8)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	toast_box.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	game.sfx.play("win" if title.begins_with("LEVEL") else "upgrade")

# ---------------------------------------------------------------------
# Tutorial coach: a card at the top of the screen with the current step
# ---------------------------------------------------------------------
var tut_box: PanelContainer
var tut_lbl: Label
var tut_step_lbl: Label

func show_tutorial(step: int, total: int, text: String) -> void:
	if tut_box == null:
		tut_box = panel_of(Color(NAVY, 0.96), 16)
		tut_box.anchor_left = 0.5
		tut_box.anchor_right = 0.5
		tut_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		tut_box.offset_top = 70
		tut_box.custom_minimum_size = Vector2(520, 0)
		root.add_child(tut_box)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		tut_box.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		tut_step_lbl = lbl("", 14, GOLD, 6)
		v.add_child(tut_step_lbl)
		tut_lbl = lbl("", 19, Color.WHITE, 7)
		tut_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tut_lbl.custom_minimum_size = Vector2(380, 0)
		v.add_child(tut_lbl)
		var skip := btn("SKIP", Color(0.45, 0.45, 0.6), 16, 10)
		skip.custom_minimum_size = Vector2(80, 40)
		skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		skip.pressed.connect(func() -> void: game.end_tutorial())
		h.add_child(skip)
	tut_box.visible = true
	tut_step_lbl.text = "TUTORIAL  %d / %d" % [step + 1, total]
	tut_lbl.text = text
	tut_box.modulate.a = 0.0
	tut_box.create_tween().tween_property(tut_box, "modulate:a", 1.0, 0.3)

func hide_tutorial() -> void:
	if tut_box:
		tut_box.visible = false

func _on_resume() -> void:
	game.toggle_pause()

func _on_sound() -> void:
	game.toggle_mute()

# ---------------------------------------------------------------------
# Ability bar: one round button per hero with an unlocked ability
# ---------------------------------------------------------------------
func _build_abilities() -> void:
	ability_bar = HBoxContainer.new()
	ability_bar.add_theme_constant_override("separation", 8)
	ability_bar.anchor_left = 0.5
	ability_bar.anchor_right = 0.5
	ability_bar.anchor_top = 1.0
	ability_bar.anchor_bottom = 1.0
	ability_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ability_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ability_bar.offset_bottom = -8
	root.add_child(ability_bar)

## The ability bar sits above the upgrade panel while a hero is selected.
func _place_ability_bar() -> void:
	var lift: float = panel.size.y + 22.0 if panel.visible and not portrait else 8.0
	ability_bar.offset_bottom = -lift
	ability_bar.offset_top = -lift - 58.0

func refresh_abilities() -> void:
	for c in ability_bar.get_children():
		c.queue_free()
	ability_buttons.clear()
	var keys := ["Q", "W", "E", "R", "T", "Y", "U", "I"]
	var list: Array = game.ability_heroes()
	for i in range(list.size()):
		var h = list[i]
		var b := round_btn(Color(0.95, 0.75, 0.2), 56)
		var ab: Dictionary = game.ABILITIES[h.key]
		b.tooltip_text = "%s [%s]\n%s" % [ab["name"], keys[i], ab["desc"]]
		var pic := _portrait_rect(h.key, 46)
		centered(b, pic)
		var cd := lbl("", 22, Color.WHITE, 8)
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(cd)
		var key_lbl := lbl(keys[i], 13, Color.WHITE, 6)
		key_lbl.position = Vector2(4, 0)
		b.add_child(key_lbl)
		b.pressed.connect(func() -> void: game.use_ability(h))
		ability_bar.add_child(b)
		ability_buttons.append([b, cd, h])
	_update_ability_cooldowns()

# ---------------------------------------------------------------------
# Power bar: gem-bought one-shot powers, down the left edge
# ---------------------------------------------------------------------
func _build_powers() -> void:
	power_bar = VBoxContainer.new()
	power_bar.add_theme_constant_override("separation", 4)
	power_bar.position = Vector2(12, 132)
	root.add_child(power_bar)

var charm_popup: PanelContainer

func refresh_powers() -> void:
	for c in power_bar.get_children():
		c.queue_free()
	power_buttons.clear()
	if charm_popup:
		charm_popup.visible = false
	if game.progress == null:
		return
	var nc: int = game.progress.charm_count()
	if nc > 0:
		var cb := round_btn(Color(0.95, 0.7, 0.2), 46)
		cb.tooltip_text = "Hero Charms (%d): place a pre-upgraded hero for free" % nc
		centered(cb, HudIcon.new("scroll", 28, Color(1, 0.95, 0.8)))
		var cl := lbl(str(nc), 13, Color.WHITE, 6)
		cl.position = Vector2(30, 26)
		cb.add_child(cl)
		cb.pressed.connect(toggle_charms)
		power_bar.add_child(cb)
	for pw in game.progress.POWERS:
		var id: String = pw[0]
		var n: int = game.progress.power_count(id)
		if n <= 0:
			continue
		var b := round_btn(Defs.col(pw[5]).darkened(0.15), 46)
		var hot: String = ["F", "G", "H", "J", "K", "L"][game.progress.POWERS.find(pw)]
		b.tooltip_text = "%s [%s] (x%d)\n%s\nUp to %d powers per game." % [pw[1], hot, n, pw[2], game.power_limit()]
		var ic := TextureRect.new()
		ic.texture = Icons.tex(pw[3], Color.WHITE, 64)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(28, 28)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		centered(b, ic)
		var cnt := lbl(str(n), 13, Color.WHITE, 6)
		cnt.position = Vector2(30, 26)
		b.add_child(cnt)
		b.pressed.connect(func() -> void: game.use_power(id))
		power_bar.add_child(b)
		power_buttons.append([b, id])
	_update_power_buttons()

func toggle_charms() -> void:
	if charm_popup and charm_popup.visible:
		charm_popup.visible = false
		return
	if charm_popup == null:
		charm_popup = panel_of(Color(0.12, 0.2, 0.35, 0.96), 14)
		charm_popup.position = Vector2(66, 132)
		root.add_child(charm_popup)
	for c in charm_popup.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	charm_popup.add_child(v)
	v.add_child(lbl("HERO CHARMS", 16, GOLD, 6))
	var ch: Dictionary = game.progress.charms()
	var keys := ch.keys()
	keys.sort()
	for key in keys:
		var cd: Dictionary = game.progress.parse_charm(key)
		var hk: String = cd["hero"]
		var b := btn("", TILE, 14, 8)
		b.custom_minimum_size = Vector2(230, 46)
		var h := HBoxContainer.new()
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		h.add_child(_portrait_rect(hk, 40))
		var l := lbl("%s  %s  x%d" % [Defs.HEROES[hk]["name"], game.charm_label(key), int(ch[key])], 15, Color.WHITE, 6)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
		var blocked: bool = game.class_blocked(hk)
		b.disabled = blocked or game.over
		var ckey: String = key
		b.pressed.connect(func() -> void:
			charm_popup.visible = false
			game.begin_charm(ckey))
		v.add_child(b)
	charm_popup.visible = true

func _update_power_buttons() -> void:
	for item in power_buttons:
		var b: Button = item[0]
		if not is_instance_valid(b):
			continue
		var ok: bool = game.can_use_power(item[1])
		b.disabled = not ok
		b.modulate = Color.WHITE if ok else Color(0.6, 0.6, 0.7)

func _update_ability_cooldowns() -> void:
	for item in ability_buttons:
		var b: Button = item[0]
		var cd: Label = item[1]
		var h = item[2]
		var ready: bool = h.ability_cd == 0.0
		b.disabled = not ready
		cd.text = "" if ready else str(int(ceil(h.ability_cd)))
		b.modulate = Color.WHITE if ready else Color(0.6, 0.6, 0.7)

# ---------------------------------------------------------------------
# Layout: shop on the right in landscape, along the bottom in portrait
# ---------------------------------------------------------------------
func _layout() -> void:
	# Phones held upright get a taller virtual canvas so the UI stays readable.
	var win := get_window()
	var wsize := Vector2(win.size)
	portrait = wsize.x < wsize.y * 0.9
	var want := Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
	if win.content_scale_size != want:
		win.content_scale_size = want
	_apply_safe_area()
	var hint: Control = shop.find_child("Hint", true, false)
	if game and game.menu:
		game.menu.layout(portrait)
	if menu_card:
		menu_card.custom_minimum_size = Vector2(690, 0) if portrait else Vector2(1180, 0)
		map_grid.columns = 3 if portrait else 5
	if portrait:
		shop.anchor_left = 0.0
		shop.anchor_right = 1.0
		shop.anchor_top = 1.0
		shop.anchor_bottom = 1.0
		shop.offset_left = 10
		shop.offset_right = -10
		shop.offset_top = -250
		shop.offset_bottom = -110
		shop_grid.columns = 3
		shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		shop_title.visible = false
		hint.visible = false
		panel.offset_bottom = -260
		round_box.offset_right = -14
		round_box.offset_top = 60
	else:
		shop.anchor_left = 1.0
		shop.anchor_right = 1.0
		shop.anchor_top = 0.0
		shop.anchor_bottom = 1.0
		shop.offset_left = -232
		shop.offset_right = -10
		shop.offset_top = 10
		shop.offset_bottom = -112
		shop_grid.columns = 2
		shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		shop_title.visible = true
		hint.visible = true
		panel.offset_bottom = -12
		round_box.offset_right = -246
		round_box.offset_top = 8

# ---------------------------------------------------------------------
# Runtime updates
# ---------------------------------------------------------------------
func _process(delta: float) -> void:
	if cash_dirty:
		cash_dirty = false
		update_hud()
		refresh()
	ui_timer -= delta
	if ui_timer <= 0.0:
		ui_timer = 0.25
		var h = game.selected
		if h != null and pops_lbl != null and is_instance_valid(pops_lbl) and h.stats["kind"] != "support":
			pops_lbl.text = "%s - Pops: %d" % [h.def["role"], h.pops]
		_update_ability_cooldowns()
		_update_power_buttons()
		_place_ability_bar()

func update_hud() -> void:
	if game.mode == "sandbox":
		lives_lbl.text = "INF"
		cash_lbl.text = "INF"
	else:
		lives_lbl.text = str(maxi(0, int(ceil(game.lives))))
		cash_lbl.text = str(int(floor(game.cash)))
	map_info_lbl.text = "%s - %s - %s" % [game.current_map()["name"], String(game.difficulty).capitalize(), game.MODES[game.mode]["name"]]
	round_lbl.text = "%d%s" % [game.round_num, "" if game.freeplay else "/%d" % game.max_round]
	if not game.running:
		play_icon.set_kind("play")
		speed_lbl.text = ""
		_set_btn_bg(play_btn, GREEN, 43)
	else:
		play_icon.set_kind("fast")
		speed_lbl.text = "" if game.speed == 1 else "x%d" % game.speed
		_set_btn_bg(play_btn, [GREEN, GREEN, GOLD, ORANGE][game.speed], 43)
	_set_btn_bg(auto_btn, VIOLET if game.auto_start else BLUE, 29)
	mute_btn.text = "OFF" if game.sfx.muted else "SFX"

func refresh() -> void:
	for k in shop_buttons:
		var b: Button = shop_buttons[k]
		var poor: bool = game.cash < game.hero_price(k) or not game.hero_available(k)
		b.modulate = Color(0.6, 0.6, 0.66, 0.8) if poor else Color.WHITE
		_set_btn_bg(b, GOLD if game.placing == k else TILE, 10)
	if cancel_btn:
		cancel_btn.visible = game.placing != ""
	for b in buy_buttons:
		if is_instance_valid(b):
			(b as Button).disabled = game.cash < int(b.get_meta("cost"))

func build_panel(h) -> void:
	for c in panel_box.get_children():
		c.queue_free()
	buy_buttons.clear()
	pops_lbl = null
	if h == null:
		panel.visible = false
		return
	panel.visible = true
	var def: Dictionary = h.def
	var support: bool = h.stats["kind"] == "support"

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	panel_box.add_child(head)
	var pic_bg := PanelContainer.new()
	pic_bg.add_theme_stylebox_override("panel", sb(TILE, 10, 3, false, 0))
	pic_bg.add_child(_portrait_rect(h.key, 58))
	head.add_child(pic_bg)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.add_theme_constant_override("separation", -2)
	head.add_child(names)
	names.add_child(lbl(def["name"], 28, Color.WHITE, 10))
	var info := "Income $%d / round" % int(h.stats["income"]) if support else "Pops: %d" % h.pops
	pops_lbl = lbl("%s - %s" % [def["role"], info], 14, Color(0.8, 0.9, 1.0), 0)
	names.add_child(pops_lbl)
	names.add_child(lbl(_stat_line(h), 13, GOLD, 0))
	if game._upgrades_need_xp():
		names.add_child(lbl("%s hero XP: %d" % [def["name"], int(game.progress.hero_xp(h.key))], 12, Color(0.75, 0.65, 1.0), 0))
	if h.ability_cd >= 0.0:
		var ab: Dictionary = game.ABILITIES[h.key]
		names.add_child(lbl("Ability: %s - %s" % [ab["name"], ab["desc"]], 12, Color(1, 0.85, 0.5), 0))
	if not support or float(h.stats.get("pulse_dmg", 0.0)) > 0.0:
		var pr := btn(String(h.priority).to_upper(), BLUE, 16)
		pr.tooltip_text = "Targeting (Tab)"
		pr.pressed.connect(func() -> void: game.cycle_priority(h))
		pr.icon = Icons.tex("target", Color.WHITE, 40)
		pr.add_theme_constant_override("icon_max_width", 18)
		pr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		head.add_child(pr)
	var sell := btn("SELL $%d" % int(h.spent * 0.7), RED, 16)
	sell.pressed.connect(func() -> void: game.sell_hero(h))
	sell.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(sell)
	var close := btn("", GREY, 16)
	close.icon = Icons.tex("x", Color.WHITE, 40)
	close.add_theme_constant_override("icon_max_width", 16)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func() -> void: game.select_hero(null))
	head.add_child(close)

	var paths: BoxContainer
	if portrait:
		paths = VBoxContainer.new()
	else:
		paths = HBoxContainer.new()
	paths.add_theme_constant_override("separation", 8)
	panel_box.add_child(paths)
	for p in range(3):
		var tier: int = h.tiers[p]
		var why: String = game.can_upgrade(h, p)
		var bg := CARD
		if why == "MAXED":
			bg = Color(0.3, 0.24, 0.1)
		elif why == "LOCKED":
			bg = Color(0.2, 0.16, 0.36)
		elif why != "":
			bg = Color(0.09, 0.11, 0.19)
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", sb(bg, 12, 3, false, 8))
		card.custom_minimum_size = Vector2(190, 0)
		paths.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		card.add_child(v)
		v.add_child(dark_lbl(String(def["path_names"][p]).to_upper(), 13))
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 4)
		v.add_child(pips)
		for i in range(4):
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(36, 10)
			pip.add_theme_stylebox_override("panel", sb(GREEN if i < tier else Color(1, 1, 1, 0.14), 5, 0, false, 0))
			pips.add_child(pip)
		if why == "LOCKED":
			# Not unlocked yet: spend this hero's XP to unlock it.
			var up_l: Array = def["paths"][p][tier]
			v.add_child(dark_lbl("LOCKED: " + String(up_l[0]), 15))
			var block: String = game.progress.unlock_blocker(h.key, p, tier + 1)
			var dl := dark_lbl(up_l[2], 12)
			dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dl.custom_minimum_size = Vector2(170, 34)
			dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
			v.add_child(dl)
			var xp_cost: int = game.progress.UNLOCK_COST[tier + 1]
			var ub := btn("UNLOCK %d XP" % xp_cost, VIOLET, 16)
			ub.disabled = block != ""
			ub.tooltip_text = block if block != "" else "Spend %s's hero XP to unlock this upgrade for good." % def["name"]
			var pi: int = p
			var ti: int = tier + 1
			ub.pressed.connect(func() -> void: game.unlock_upgrade(h.key, pi, ti))
			v.add_child(ub)
		elif why != "":
			var last: Array = def["paths"][p][3]
			v.add_child(dark_lbl(String(last[0]) if why == "MAXED" else "Path closed", 16))
			var d := dark_lbl("Fully upgraded!" if why == "MAXED" else "Only two paths, and only one past tier 2.", 12)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(d)
		else:
			var up: Array = def["paths"][p][tier]
			var cost: int = game.upgrade_price(h, p)
			v.add_child(dark_lbl(up[0], 16))
			var d2 := dark_lbl(up[2], 12)
			d2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d2.custom_minimum_size = Vector2(170, 34)
			d2.size_flags_vertical = Control.SIZE_EXPAND_FILL
			v.add_child(d2)
			var buy := btn("$%d" % cost, GREEN, 20)
			buy.set_meta("cost", cost)
			buy.disabled = game.cash < cost
			var path_index: int = p
			buy.pressed.connect(func() -> void: game.buy_upgrade(h, path_index))
			v.add_child(buy)
			buy_buttons.append(buy)

func _stat_line(h) -> String:
	var s: Dictionary = game.eff(h)
	if s["kind"] == "support":
		var line := "Range %.1f  -  Income $%d / round" % [float(s["range"]), int(s["income"])]
		if float(s.get("pulse_dmg", 0.0)) > 0.0:
			line += "  -  Wave dmg %d" % int(s["pulse_dmg"])
		return line
	var dmg := float(s.get("dmg", 0.0))
	if s["kind"] == "pulse":
		return "Freeze %.1fs  -  Dmg %d  -  Range %.1f  -  %.2f/s" % [float(s["freeze"]), int(dmg), float(s["range"]), 1.0 / float(s["rate"])]
	return "Dmg %d  -  Pierce %d  -  Range %.1f  -  %.2f/s%s" % [int(dmg), int(s["pierce"]), minf(float(s["range"]), 99.0), 1.0 / float(s["rate"]), "  -  sees veiled" if s.get("camo", false) else ""]

func banner(text: String, sub: String = "") -> void:
	banner_lbl.text = text
	banner_sub.text = sub
	banner_sub.visible = sub != ""
	if banner_tween:
		banner_tween.kill()
	banner_box.modulate.a = 0.0
	banner_box.scale = Vector2(1.15, 1.15)
	banner_box.pivot_offset = banner_box.size / 2.0
	banner_tween = create_tween()
	banner_tween.set_parallel(true)
	banner_tween.tween_property(banner_box, "modulate:a", 1.0, 0.25)
	banner_tween.tween_property(banner_box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.chain().tween_property(banner_box, "modulate:a", 0.0, 0.4).set_delay(1.2)

func show_boss(boss_name: String, frac: float) -> void:
	boss_box.visible = true
	boss_lbl.text = boss_name
	boss_bar.value = frac * 100.0

func hide_boss() -> void:
	boss_box.visible = false

func show_end(won: bool, text: String) -> void:
	end_title.text = "VICTORY!" if won else "GAME OVER"
	end_text.text = text
	freeplay_btn.visible = won
	end_screen.visible = true
