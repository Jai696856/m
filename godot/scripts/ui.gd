# All 2D interface, built from code: HUD, hero shop, upgrade panel, boss bar,
# banners, and the start / game-over screens.
extends CanvasLayer

const Defs = preload("res://scripts/defs.gd")
const Models = preload("res://scripts/models.gd")
const Maps = preload("res://scripts/maps.gd")
const LevelScript = preload("res://scripts/level/level.gd")
const GameModes := ["standard", "half_cash", "fortified", "deflation", "rush", "sandbox"]

const INK := Color(0.12, 0.08, 0.16)
const NAVY := Color(0.1, 0.17, 0.29, 0.9)
const TILE := Color(0.6, 0.84, 1.0)
const CARD := Color(0.93, 0.97, 1.0)
const PINK := Color(1.0, 0.435, 0.682)
const GREEN := Color(0.36, 0.86, 0.3)
const GOLD := Color(1.0, 0.8, 0.2)
const ORANGE := Color(1.0, 0.6, 0.15)
const VIOLET := Color(0.54, 0.36, 1.0)
const CASH := Color(1.0, 0.86, 0.3)

# Small vector icons drawn in code (heart, coin, play, fast-forward).
class HudIcon extends Control:
	var kind := "heart"
	var col := Color.WHITE

	func _init(k: String, px: float, c: Color) -> void:
		kind = k
		col = c
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_kind(k: String) -> void:
		kind = k
		queue_redraw()

	func _draw() -> void:
		var ink := Color(0.12, 0.08, 0.16)
		var s := size
		var c := s * 0.5
		match kind:
			"heart":
				var pts := PackedVector2Array()
				for i in range(48):
					var t := TAU * i / 48.0
					var x := 16.0 * pow(sin(t), 3)
					var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
					pts.append(c + Vector2(x, y + 2.0) * (s.x / 38.0))
				draw_colored_polygon(pts, col)
				pts.append(pts[0])
				draw_polyline(pts, ink, 3.0, true)
				draw_circle(c + Vector2(-s.x * 0.17, -s.y * 0.12), s.x * 0.07, Color(1, 1, 1, 0.7))
			"coin":
				draw_circle(c, s.x * 0.47, ink)
				draw_circle(c, s.x * 0.41, col)
				draw_circle(c, s.x * 0.27, col.darkened(0.18))
				draw_circle(c + Vector2(-s.x * 0.14, -s.y * 0.14), s.x * 0.07, Color(1, 1, 1, 0.8))
			"play":
				var tri := PackedVector2Array([c + Vector2(-0.2, -0.27) * s.x, c + Vector2(0.28, 0) * s.x, c + Vector2(-0.2, 0.27) * s.x])
				draw_colored_polygon(tri, col)
				tri.append(tri[0])
				draw_polyline(tri, ink, 3.0, true)
			"fast":
				for off in [-0.17, 0.13]:
					var t2 := PackedVector2Array([c + Vector2(off - 0.12, -0.24) * s.x, c + Vector2(off + 0.17, 0) * s.x, c + Vector2(off - 0.12, 0.24) * s.x])
					draw_colored_polygon(t2, col)
					t2.append(t2[0])
					draw_polyline(t2, ink, 3.0, true)

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

var root: Control
var lives_lbl: Label
var cash_lbl: Label
var round_box: VBoxContainer
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
var pause_screen: Control
var ability_bar: HBoxContainer
var ability_buttons: Array = []
var map_info_lbl: Label
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
	font = load("res://fonts/LuckiestGuy-Regular.ttf") as Font
	if font:
		theme.default_font = font
	theme.default_font_size = 18
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
	_build_start()
	_build_end()
	_build_pause()
	get_viewport().size_changed.connect(_layout)
	_layout()
	update_hud()

# ---------------------------------------------------------------------
# Style helpers
# ---------------------------------------------------------------------
func sb(bg: Color, radius: int = 14, border: int = 3, shadow: bool = true, margin: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = INK
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.3)
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, 4)
	return s

# Chunky cartoon text: white fill with a thick dark outline by default.
func lbl(text: String, size: int = 16, color: Color = Color.WHITE, outline: int = 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func dark_lbl(text: String, size: int = 14) -> Label:
	return lbl(text, size, INK, 0)

func btn(text: String, bg: Color, size: int = 20, radius: int = 12) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_constant_override("outline_size", 8)
	b.add_theme_color_override("font_outline_color", INK)
	_set_btn_bg(b, bg, radius)
	b.add_theme_stylebox_override("disabled", sb(Color(0.62, 0.64, 0.68), radius, 3, false))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.85, 0.85, 0.85))
	return b

func _set_btn_bg(b: Button, bg: Color, radius: int = 12) -> void:
	b.add_theme_stylebox_override("normal", sb(bg, radius))
	b.add_theme_stylebox_override("hover", sb(bg.lightened(0.15), radius))
	b.add_theme_stylebox_override("pressed", sb(bg.darkened(0.15), radius, 3, false))

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
	p.add_theme_stylebox_override("panel", sb(bg, radius, 3, true, 10))
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
	cam.position = Vector3(0.9, 2.4, 5.0)
	cam.look_at(Vector3(0, 1.7, 0), Vector3.UP)
	cam.make_current()
	portrait_vps.append(vp)
	return vp.get_texture()

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
	hud.add_theme_constant_override("separation", 18)
	hud.position = Vector2(14, 10)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	for which in ["lives", "cash"]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(h)
		if which == "lives":
			h.add_child(HudIcon.new("heart", 38, Color(1, 0.25, 0.35)))
			lives_lbl = lbl("150", 36, Color.WHITE, 12)
			h.add_child(lives_lbl)
		else:
			h.add_child(HudIcon.new("coin", 36, CASH))
			cash_lbl = lbl("650", 36, Color.WHITE, 12)
			h.add_child(cash_lbl)

	round_box = VBoxContainer.new()
	round_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_box.add_theme_constant_override("separation", -6)
	round_box.anchor_left = 1.0
	round_box.anchor_right = 1.0
	round_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	round_box.offset_top = 8
	root.add_child(round_box)
	var cap := lbl("ROUND", 18, Color.WHITE, 8)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	round_box.add_child(cap)
	round_lbl = lbl("0/40", 36, Color.WHITE, 12)
	round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	round_box.add_child(round_lbl)
	map_info_lbl = lbl("", 13, Color.WHITE, 6)
	map_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	round_box.add_child(map_info_lbl)

func _build_shop() -> void:
	shop = panel_of(NAVY)
	root.add_child(shop)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	shop.add_child(v)
	shop_title = lbl("HEROES", 26, GOLD, 10)
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(shop_title)
	shop_scroll = ScrollContainer.new()
	shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(shop_scroll)
	shop_grid = GridContainer.new()
	shop_grid.columns = 2
	shop_grid.add_theme_constant_override("h_separation", 6)
	shop_grid.add_theme_constant_override("v_separation", 6)
	shop_scroll.add_child(shop_grid)
	var hint := lbl("Drag: rotate  Wheel: zoom\n1-7: heroes  Space: play", 11, Color(0.8, 0.88, 1.0), 0)
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
	for k in Defs.HERO_ORDER:
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
		var cost := lbl("$%d" % game.price(h["cost"]), 20, CASH, 8)
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cost)
		var num := lbl(str(i + 1), 13, Color.WHITE, 6)
		num.position = Vector2(6, 2)
		b.add_child(num)
		shop_grid.add_child(b)
		shop_buttons[k] = b
		i += 1
	refresh()

func _build_controls() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(h)
	mute_btn = round_btn(Color(0.35, 0.5, 0.75), 58)
	mute_btn.text = "SFX"
	mute_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	mute_btn.pressed.connect(func() -> void: game.toggle_mute())
	h.add_child(mute_btn)
	auto_btn = round_btn(Color(0.35, 0.5, 0.75), 58)
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
	shade.color = Color(0.05, 0.15, 0.3, 0.55)
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
	var t1 := lbl(a, 76, Color.WHITE, 22)
	t1.add_theme_color_override("font_shadow_color", PINK)
	t1.add_theme_constant_override("shadow_offset_y", 7)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)
	if b != "":
		var t2 := lbl(b, 36, GOLD, 14)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t2)
	return t1

func _build_start() -> void:
	var o := _overlay()
	start_screen = o["shade"]
	menu_card = o["card"]
	var v: VBoxContainer = o["box"]
	v.add_theme_constant_override("separation", 8)
	var t1 := lbl("SAKURA SPIRIT DEFENSE", 46, Color.WHITE, 16)
	t1.add_theme_color_override("font_shadow_color", PINK)
	t1.add_theme_constant_override("shadow_offset_y", 5)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)
	# Tier tabs + medal count
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t in Maps.TIERS:
		var key: String = t
		var b := btn(key.to_upper(), Color(0.35, 0.5, 0.75), 18)
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
	for d in [["easy", "EASY"], ["normal", "NORMAL"], ["hard", "HARD"]]:
		var key: String = d[0]
		var b := btn(d[1], TILE, 16)
		b.custom_minimum_size = Vector2(100, 40)
		b.pressed.connect(func() -> void: _pick_diff(key))
		row.add_child(b)
		diff_buttons[key] = b
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(16, 0)
	row.add_child(sep)
	for m in GameModes:
		var key2: String = m
		var b2 := btn(String(game.MODES[key2]["name"]).to_upper(), TILE, 14)
		b2.custom_minimum_size = Vector2(0, 40)
		b2.tooltip_text = game.MODES[key2]["desc"]
		b2.pressed.connect(func() -> void: _pick_mode(key2))
		row.add_child(b2)
		mode_buttons[key2] = b2
	mode_lbl = lbl("", 14, Color(0.8, 0.9, 1.0), 0)
	mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(mode_lbl)
	var start := btn("START!", GREEN, 34, 18)
	start.custom_minimum_size = Vector2(220, 58)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_on_start)
	v.add_child(start)
	sel_map = game.map_index
	_pick_diff("normal")
	_pick_mode("standard")
	_pick_tier(String(Maps.MAPS[sel_map]["tier"]))

func _pick_tier(t: String) -> void:
	sel_tier = t
	for key in tier_buttons:
		_set_btn_bg(tier_buttons[key], PINK if key == t else Color(0.35, 0.5, 0.75))
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
		var medal_cols := {"easy": Color(0.8, 0.5, 0.25), "normal": Color(0.8, 0.82, 0.86), "hard": Color(1.0, 0.8, 0.2)}
		for d in ["easy", "normal", "hard"]:
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
		_set_btn_bg(diff_buttons[key], PINK if key == k else Color(0.35, 0.5, 0.75))
	_refresh_menu()

func _pick_mode(k: String) -> void:
	sel_mode = k
	for key in mode_buttons:
		_set_btn_bg(mode_buttons[key], PINK if key == k else Color(0.35, 0.5, 0.75))
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
		for d in ["easy", "normal", "hard"]:
			if game.has_medal(i, d, "standard"):
				total += 1
	if medal_lbl:
		medal_lbl.text = "  MEDALS %d/%d" % [total, Maps.MAPS.size() * 3]

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
	var maps_btn := btn("MAPS", Color(0.35, 0.5, 0.75), 28, 16)
	maps_btn.pressed.connect(_on_maps)
	row.add_child(maps_btn)

func _build_pause() -> void:
	var o := _overlay()
	pause_screen = o["shade"]
	pause_screen.visible = false
	var v: VBoxContainer = o["box"]
	_title(v, "PAUSED", "")
	for item in [["RESUME", GREEN, "_on_resume"], ["RESTART", GOLD, "_on_retry"], ["MAPS", Color(0.35, 0.5, 0.75), "_on_maps"], ["SOUND ON / OFF", Color(0.35, 0.5, 0.75), "_on_sound"]]:
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
	ability_bar.offset_bottom = -14
	root.add_child(ability_bar)

func refresh_abilities() -> void:
	for c in ability_bar.get_children():
		c.queue_free()
	ability_buttons.clear()
	var keys := ["Q", "W", "E", "R", "T", "Y", "U", "I"]
	var list: Array = game.ability_heroes()
	for i in range(list.size()):
		var h = list[i]
		var b := round_btn(Color(0.95, 0.75, 0.2), 66)
		var ab: Dictionary = game.ABILITIES[h.key]
		b.tooltip_text = "%s [%s]\n%s" % [ab["name"], keys[i], ab["desc"]]
		var pic := _portrait_rect(h.key, 54)
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
	var hint: Control = shop.find_child("Hint", true, false)
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
		shop_grid.columns = Defs.HERO_ORDER.size()
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
	_set_btn_bg(auto_btn, VIOLET if game.auto_start else Color(0.35, 0.5, 0.75), 29)
	mute_btn.text = "OFF" if game.sfx.muted else "SFX"

func refresh() -> void:
	for k in shop_buttons:
		var b: Button = shop_buttons[k]
		var poor: bool = game.cash < game.price(Defs.HEROES[k]["cost"])
		b.modulate = Color(0.6, 0.6, 0.66, 0.8) if poor else Color.WHITE
		_set_btn_bg(b, GOLD if game.placing == k else TILE, 10)
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
	if h.ability_cd >= 0.0:
		var ab: Dictionary = game.ABILITIES[h.key]
		names.add_child(lbl("Ability: %s - %s" % [ab["name"], ab["desc"]], 12, Color(1, 0.85, 0.5), 0))
	if not support or float(h.stats.get("pulse_dmg", 0.0)) > 0.0:
		var pr := btn(String(h.priority).to_upper(), Color(0.35, 0.5, 0.75), 16)
		pr.tooltip_text = "Targeting (Tab)"
		pr.pressed.connect(func() -> void: game.cycle_priority(h))
		head.add_child(pr)
	var sell := btn("SELL $%d" % int(h.spent * 0.7), Color(0.92, 0.3, 0.3), 16)
	sell.pressed.connect(func() -> void: game.sell_hero(h))
	head.add_child(sell)
	var close := btn("X", Color(0.35, 0.5, 0.75), 16)
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
			bg = Color(1, 0.93, 0.6)
		elif why != "":
			bg = Color(0.62, 0.66, 0.74)
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
			pip.add_theme_stylebox_override("panel", sb(GREEN if i < tier else Color(0.8, 0.84, 0.9), 5, 2, false, 0))
			pips.add_child(pip)
		if why != "":
			var last: Array = def["paths"][p][3]
			v.add_child(dark_lbl(String(last[0]) if why == "MAXED" else "Path closed", 16))
			var d := dark_lbl("Fully upgraded!" if why == "MAXED" else "Only two paths, and only one past tier 2.", 12)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(d)
		else:
			var up: Array = def["paths"][p][tier]
			var cost: int = game.price(up[1])
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
